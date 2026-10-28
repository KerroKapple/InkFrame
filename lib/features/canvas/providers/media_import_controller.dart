// MediaImportController：把一批图片 / 视频导进画布——建壳节点 → 逐个复制 → 回写 url。
//
// 后续四个入口（Ctrl U、OS 拖入、粘贴图片、跨画布素材）共用这一条路；本控制器不进撤销栈、
// 不出提示，返回建成的节点 id 与跳过的文件，由入口决定怎么提示、怎么撤销。
//
// 流程（同一批内按顺序复制，不并行，避免磁盘抖动）：
//   ① 扩展名不在白名单 ⇒ 记 unsupported 跳过，不建节点；
//   ② 先等节点控制器加载完，再把其余文件的壳全部建好（用户一次看到全部占位），进度记 0；
//   ③ 逐个 copyIntoCanvas，进度每变化 ≥ 1% 才写 state；
//   ④ 成功 ⇒ 组 patch：图片 {image_url, width?, height?}；视频再抽首帧到 imports/<同 uuid>.jpg，
//      {video_url, thumbnail_url?, duration_ms?, width?, height?}，抽帧失败吞掉只记 warn；
//   ⑤ 回写：一律先直写仓储拿行数；返回 0（壳在复制途中被删了，PG 的 patchTypeConfig 写不进
//      软删行）⇒ 一个事务里 restore → patch → softDelete，删了的卡照常带上 url（撤销删除时库里
//      是完整的）；行已硬删 ⇒ 按失败走。库落定后，这张卡还在节点控制器内存里 ⇒ 再
//      patchTypeConfigMany 同步内存（失败只记 warn，不回滚导入）；
//   ⑥ 失败（复制失败，或 ④⑤ 写库失败）⇒ discard 已复制的文件与已抽出的首帧 + 硬删壳，
//      按原因记 skip；
//   ⑦ 不论成败，从 state 去掉这张卡的进度。
//
// 「复制中」只由本控制器的内存进度表达（canvasId → {nodeId: 0..1}），不写 nodes.status。
// 非 autoDispose：导入比画面活得久——关画布中途复制继续，节点控制器已释放时直写仓储。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/file_resolver.dart';
import '../../../core/di/logger.dart';
import '../../../core/di/media_import.dart';
import '../../../core/di/repositories.dart';
import '../../../core/di/thumbnail.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/media_import_service.dart';
import '../../../core/interfaces/thumbnail_service.dart';
import '../models/canvas_node.dart';
import '../util/drop_placement.dart';
import 'canvas_nodes_controller.dart';

/// 导入一个文件：源文件绝对路径 + 落点（左上角世界坐标 + 归属泳道）。
typedef MediaImportRequest = ({String path, NodePlacement placement});

/// 某个文件没导进来的原因。空文件记作 unreadable。
enum MediaImportSkipReason { unsupported, unreadable, copyFailed }

typedef MediaImportSkip = ({String fileName, MediaImportSkipReason reason});

/// 一批导入的结果：建成的节点 id（顺序 = 请求顺序）+ 跳过的文件。
typedef MediaImportBatchResult = ({List<String> nodeIds, List<MediaImportSkip> skipped});

/// 节点 label 的上限（库约束 chk_node_label_len：char_length(label) <= 200，按字符计）。
const int kImportLabelMaxChars = 200;

/// 日志 module 名（内部标识，English-only）。
const String kMediaImportControllerLogModule = 'canvas.media_import';

/// 进度至少变化这么多才写 state（避免一张卡的进度每跳一点就通知一次）。
const double _kProgressStep = 0.01;

final mediaImportControllerProvider =
    NotifierProviderFamily<MediaImportController, Map<String, double>, String>(
  MediaImportController.new,
  name: 'mediaImportControllerProvider',
);

/// 截到 [kImportLabelMaxChars] 个字符：按 rune 截（库按 char_length 计），不按 UTF-16 单元，
/// 不会把一个 emoji 截成半个代理对。
String clipImportLabel(String name) {
  final List<int> runes = name.runes.toList(growable: false);
  if (runes.length <= kImportLabelMaxChars) return name;
  return String.fromCharCodes(runes.take(kImportLabelMaxChars));
}

/// 已建好壳、等着复制的一个文件。
typedef _Pending = ({String nodeId, String path, String fileName});

class MediaImportController extends FamilyNotifier<Map<String, double>, String> {
  @override
  Map<String, double> build(String canvasId) => const <String, double>{};

  /// 导入一批文件到本画布（family 参数 = canvasId）。
  ///
  /// 全部跳过 / 全部失败 ⇒ nodeIds 为空，画布上什么也不剩。节点控制器加载失败 ⇒ 它的
  /// InkError 原样上抛（此时一个壳都还没建）。
  Future<MediaImportBatchResult> importFiles({
    required String projectId,
    required List<MediaImportRequest> requests,
  }) async {
    final String canvasId = arg;
    final MediaImportService service = ref.read(mediaImportServiceProvider);
    final List<MediaImportSkip> skipped = <MediaImportSkip>[];

    // ① 白名单。
    final List<({MediaImportRequest request, MediaImportKind kind, String fileName})>
        accepted = <({MediaImportRequest request, MediaImportKind kind, String fileName})>[];
    for (final MediaImportRequest r in requests) {
      final String fileName = importOriginalName(r.path);
      final MediaImportKind? kind = mediaImportKindOf(r.path);
      if (kind == null) {
        skipped.add((fileName: fileName, reason: MediaImportSkipReason.unsupported));
        continue;
      }
      accepted.add((request: r, kind: kind, fileName: fileName));
    }
    if (accepted.isEmpty) {
      return (nodeIds: const <String>[], skipped: skipped);
    }

    // ② 先等节点控制器加载完再插壳——加载中插进去的节点会被随后完成的 build 覆盖掉。
    // 建壳期间挂一个订阅，免得 autoDispose 的节点控制器在两次 await 之间被释放。
    final nodesProvider = canvasNodesControllerProvider(canvasId);
    final List<_Pending> pending = <_Pending>[];
    final ProviderSubscription<AsyncValue<List<CanvasNode>>> keepAlive =
        ref.listen<AsyncValue<List<CanvasNode>>>(nodesProvider, (_, _) {});
    try {
      await ref.read(nodesProvider.future);
      final CanvasNodesController nodes = ref.read(nodesProvider.notifier);
      for (final a in accepted) {
        try {
          final CanvasNode shell = await nodes.addImportShell(
            label: clipImportLabel(a.fileName),
            type: a.kind == MediaImportKind.image
                ? CanvasNodeType.image
                : CanvasNodeType.video,
            projectId: projectId,
            laneId: a.request.placement.laneId,
            position: a.request.placement.world,
            originalName: a.fileName,
          );
          pending.add((nodeId: shell.id, path: a.request.path, fileName: a.fileName));
          state = <String, double>{...state, shell.id: 0.0};
        } on InkError catch (e) {
          // 壳没建成：不复制，记 copyFailed（库里没有这一行，磁盘上也没东西）。
          _warn('media_import.shell_create_failed', <String, Object?>{
            'code': e.code.name,
          });
          skipped.add((fileName: a.fileName, reason: MediaImportSkipReason.copyFailed));
        }
      }
    } finally {
      keepAlive.close();
    }

    // ③–⑦ 逐个复制（顺序，不并行）。
    final List<String> nodeIds = <String>[];
    for (final _Pending item in pending) {
      final MediaImportSkipReason? failure = await _importOne(
        projectId: projectId,
        canvasId: canvasId,
        service: service,
        item: item,
      );
      if (failure == null) {
        nodeIds.add(item.nodeId);
      } else {
        skipped.add((fileName: item.fileName, reason: failure));
      }
    }
    return (nodeIds: nodeIds, skipped: skipped);
  }

  /// 复制一个文件并回写；成功返回 null，失败返回跳过原因（壳与文件已清掉）。
  Future<MediaImportSkipReason?> _importOne({
    required String projectId,
    required String canvasId,
    required MediaImportService service,
    required _Pending item,
  }) async {
    final List<String> written = <String>[];
    try {
      final ImportedMedia media;
      try {
        media = await service.copyIntoCanvas(
          projectId: projectId,
          canvasId: canvasId,
          sourcePath: item.path,
          onProgress: (double f) => _report(item.nodeId, f),
        );
      } on LocalIOError catch (e) {
        // 服务保证复制失败不留文件，这里只删壳。
        await _discardShell(canvasId, item.nodeId);
        return _skipReasonOf(e);
      }
      written.add(media.relativePath);

      final Map<String, Object?> patch;
      if (media.kind == MediaImportKind.image) {
        patch = <String, Object?>{
          'image_url': media.relativePath,
          if (media.width case final int w) 'width': w,
          if (media.height case final int h) 'height': h,
        };
      } else {
        patch = <String, Object?>{'video_url': media.relativePath};
        final String? thumb = await _extractFirstFrame(
          projectId: projectId,
          canvasId: canvasId,
          videoRelativePath: media.relativePath,
          patch: patch,
        );
        if (thumb != null) written.add(thumb);
      }

      try {
        await _writeBack(canvasId, item.nodeId, patch);
      } on InkError catch (e) {
        _warn('media_import.write_back_failed', <String, Object?>{
          'code': e.code.name,
        });
        for (final String rel in written) {
          await service.discard(
            projectId: projectId,
            canvasId: canvasId,
            relativePath: rel,
          );
        }
        await _discardShell(canvasId, item.nodeId);
        return MediaImportSkipReason.copyFailed;
      }
      return null;
    } finally {
      _clearProgress(item.nodeId);
    }
  }

  /// 视频抽首帧到 `imports/<同 uuid>.jpg`，顺带探时长 / 宽高写进 [patch]；返回首帧相对路径。
  /// 没有抽帧服务 / 抽帧失败 ⇒ null（吞掉，只记 warn；视频照常可用，只是没有缩略图）。
  Future<String?> _extractFirstFrame({
    required String projectId,
    required String canvasId,
    required String videoRelativePath,
    required Map<String, Object?> patch,
  }) async {
    final ThumbnailService? thumbnail = ref.read(thumbnailServiceProvider);
    if (thumbnail == null) return null;
    final FileResolverService resolver = ref.read(fileResolverServiceProvider);
    final String thumbRel = '${p.posix.withoutExtension(videoRelativePath)}.jpg';
    try {
      final File video = resolver.resolve(
        projectId: projectId,
        canvasId: canvasId,
        relativePath: videoRelativePath,
      );
      final File destination = resolver.resolve(
        projectId: projectId,
        canvasId: canvasId,
        relativePath: thumbRel,
      );
      final VideoProbeResult probe = await thumbnail.extractFirstFrame(
        videoPath: video.path,
        destination: destination,
      );
      patch['thumbnail_url'] = thumbRel;
      // 探针的 null 字段不写键（与 job_media_persister 同口径，防 0 / null 垃圾键）。
      if (probe.durationMs case final int ms when ms > 0) patch['duration_ms'] = ms;
      if (probe.width case final int w when w > 0) patch['width'] = w;
      if (probe.height case final int h when h > 0) patch['height'] = h;
      return thumbRel;
    } on ThumbnailError catch (e) {
      _warn('media_import.thumbnail_failed', <String, Object?>{
        'path': videoRelativePath,
        'reason': e.reason,
      });
    } on FileSystemException catch (e) {
      _warn('media_import.thumbnail_io_failed', <String, Object?>{
        'path': videoRelativePath,
        'reason': e.message,
      });
    } on PathSecurityError {
      _warn('media_import.thumbnail_unsafe_path', <String, Object?>{
        'path': videoRelativePath,
      });
    }
    return null;
  }

  /// ⑤ 回写 url。见文件头。
  Future<void> _writeBack(
    String canvasId,
    String nodeId,
    Map<String, Object?> patch,
  ) async {
    // 库是准绳：一律先直写仓储拿行数。不先走 patchTypeConfigMany——它不看行数，壳行已软删
    // （removeNode 排在回写前面、或被清扫收走）时写 0 行也照样「成功」，内存显示成图、
    // 库里却没有 url，重开画布卡片就没了。
    final repo = await ref.read(nodeRepositoryProvider.future);
    if (await repo.patchTypeConfig(nodeId, patch) == 0) {
      // 软删的行写不进去：在一个事务里先复原、写、再删回去。
      final uow = await ref.read(unitOfWorkProvider.future);
      final bool written = await uow.run((scope) async {
        if (await scope.nodes.restore(nodeId) == 0) return false;
        if (await scope.nodes.patchTypeConfig(nodeId, patch) == 0) return false;
        await scope.nodes.softDelete(nodeId);
        return true;
      });
      if (!written) {
        // 行已被硬删：没有可写的地方，按失败走（清掉文件）。
        throw const LocalIOError(
          extra: <String, Object?>{
            'reason': kImportReasonCopyFailed,
            'op': 'write_back',
            'node_gone': true,
          },
        );
      }
    }

    // 库已落定；这张卡还在节点控制器内存里 ⇒ 再 patch 一次同步内存（同一个 patch 写两次幂等）。
    // 这一步失败只是内存没跟上（重开画布即恢复），库里的 url 已在，不能当导入失败去删文件和壳。
    final nodesProvider = canvasNodesControllerProvider(canvasId);
    if (!ref.exists(nodesProvider)) return;
    final List<CanvasNode>? live = ref.read(nodesProvider).valueOrNull;
    if (live == null || !live.any((CanvasNode n) => n.id == nodeId)) return;
    try {
      await ref
          .read(nodesProvider.notifier)
          .patchTypeConfigMany(<String, Map<String, Object?>>{nodeId: patch});
    } on InkError catch (e) {
      _warn('media_import.memory_sync_failed', <String, Object?>{
        'node_id': nodeId,
        'code': e.code.name,
      });
    }
  }

  /// 删掉复制失败的壳：节点控制器在 ⇒ discardImportShell（同步移出内存）；已释放 ⇒ 直接硬删。
  /// 删不掉只记 warn——空壳会在下次启动被 softDeleteEmptyOrphanResults 收进回收站。
  Future<void> _discardShell(String canvasId, String nodeId) async {
    final nodesProvider = canvasNodesControllerProvider(canvasId);
    try {
      if (ref.exists(nodesProvider)) {
        await ref.read(nodesProvider.notifier).discardImportShell(nodeId);
      } else {
        final repo = await ref.read(nodeRepositoryProvider.future);
        await repo.hardDelete(nodeId);
      }
    } on InkError catch (e) {
      _warn('media_import.shell_discard_failed', <String, Object?>{
        'node_id': nodeId,
        'code': e.code.name,
      });
    }
  }

  MediaImportSkipReason _skipReasonOf(LocalIOError e) {
    final Object? reason = e.extra['reason'];
    if (reason == kImportReasonUnreadable || reason == kImportReasonEmpty) {
      return MediaImportSkipReason.unreadable;
    }
    // copy_failed，以及本该在 ① 滤掉的 unsupported。
    return MediaImportSkipReason.copyFailed;
  }

  void _report(String nodeId, double fraction) {
    final double? previous = state[nodeId];
    if (previous == null) return;
    final double next = fraction.clamp(0.0, 1.0).toDouble();
    final bool reachedEnd = next >= 1.0 && previous < 1.0;
    if (next - previous < _kProgressStep && !reachedEnd) return;
    state = <String, double>{...state, nodeId: next};
  }

  void _clearProgress(String nodeId) {
    if (!state.containsKey(nodeId)) return;
    state = <String, double>{
      for (final MapEntry<String, double> e in state.entries)
        if (e.key != nodeId) e.key: e.value,
    };
  }

  void _warn(String msg, Map<String, Object?> extra) {
    ref.read(loggerProvider).warn(kMediaImportControllerLogModule, msg, extra: extra);
  }
}
