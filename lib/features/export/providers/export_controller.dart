// ExportController — 视频导出编排（导出 UI 首切片，features/export 模块首件）。
//
// 路径根换算：result 节点 type_config.video_url 是**画布根**相对路径
// （FileResolverService.resolve(projectId, canvasId, rel) 语义），而
// VideoExportService.concat 收**项目根**相对路径——此处统一补
// `canvases/<canvasId>/` 前缀（projectRelativeVideoPath）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/video_export.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/video_export_service.dart';
import '../../canvas/models/canvas_node.dart';

/// 导出状态机：idle / busy / success / failure。
sealed class ExportVideoState {
  const ExportVideoState();
}

class ExportVideoIdle extends ExportVideoState {
  const ExportVideoIdle();
}

class ExportVideoBusy extends ExportVideoState {
  const ExportVideoBusy({this.progress});

  /// 0..1 导出进度；null = 分母未知（indeterminate）。
  final double? progress;
}

class ExportVideoSuccess extends ExportVideoState {
  const ExportVideoSuccess(this.relativePath);

  /// 导出产物的项目根相对路径（`exports/<name>.mp4`）。
  final String relativePath;
}

class ExportVideoFailure extends ExportVideoState {
  const ExportVideoFailure(this.error);
  final InkError error;
}

/// 画布相对 video_url → concat 的项目根相对路径。
String projectRelativeVideoPath({
  required String canvasId,
  required String videoUrl,
}) =>
    'canvases/$canvasId/$videoUrl';

final exportControllerProvider =
    AutoDisposeNotifierProvider<ExportController, ExportVideoState>(
  ExportController.new,
  name: 'exportControllerProvider',
);

class ExportController extends AutoDisposeNotifier<ExportVideoState> {
  ExportCancelToken? _token;

  /// dispose 后禁写 state：应用退出期 container.dispose() 与在途导出并发时，
  /// 迟到的进度/收敛回调对已回收 notifier 写 state 会抛（评审 P1-2 触发面 c）。
  bool _alive = true;

  @override
  ExportVideoState build() {
    _alive = true;
    // 退出期兜底：keepAlive 挂起的导出随 container.dispose() 一并取消，
    // kill 掉 ffmpeg 子进程——否则应用退出后孤儿进程继续写盘（评审 P2-7）。
    ref.onDispose(() {
      _alive = false;
      _token?.cancel();
    });
    return const ExportVideoIdle();
  }

  bool get isBusy => state is ExportVideoBusy;

  /// 取消进行中的导出；非 busy 期为 no-op。
  void cancelExport() => _token?.cancel();

  /// 按给定顺序导出 [nodes]（video result 节点）。
  /// videoUrl / canvasId 缺失的节点跳过（UI 入口已过滤，这里防御性兜底）。
  Future<void> export({
    required String projectId,
    required List<CanvasNode> nodes,
    String? outputBaseName,
  }) async {
    if (isBusy) return;
    final inputs = <String>[
      for (final n in nodes)
        if (n.canvasId != null && n.videoUrl != null)
          projectRelativeVideoPath(
            canvasId: n.canvasId!,
            videoUrl: n.videoUrl!,
          ),
    ];
    // 进度分母 = 所选输入总时长；任一缺失 → null（indeterminate）。
    int? totalMs = 0;
    for (final n in nodes) {
      if (n.canvasId == null || n.videoUrl == null) continue;
      final d = n.durationMs;
      if (d == null || d <= 0) {
        totalMs = null;
        break;
      }
      totalMs = totalMs! + d;
    }
    final service = ref.read(videoExportServiceProvider);
    // 导出期间挂起 autoDispose：对话框中途关闭也把状态机走完。
    final link = ref.keepAlive();
    final token = ExportCancelToken();
    _token = token;
    state = const ExportVideoBusy();
    try {
      final out = await service.concat(
        projectId: projectId,
        inputRelativePaths: inputs,
        outputBaseName: outputBaseName,
        totalDurationMs: totalMs,
        onProgress: (progress) {
          if (_alive && state is ExportVideoBusy) {
            state = ExportVideoBusy(progress: progress);
          }
        },
        cancelToken: token,
      );
      if (_alive) state = ExportVideoSuccess(out);
    } on CancelledError {
      // 用户主动取消不是失败：回 idle，对话框回到可编辑态。
      if (_alive) state = const ExportVideoIdle();
    } on InkError catch (e) {
      if (_alive) state = ExportVideoFailure(e);
    } on PathSecurityError catch (e, st) {
      // 理论上被 UI 预校验挡住；防御性翻译为 invalidParameter。
      if (_alive) {
        state = ExportVideoFailure(
          ProviderError(
            code: InkErrorCode.invalidParameter,
            cause: e,
            stackTrace: st,
            extra: const <String, Object?>{'reason': 'path_security'},
          ),
        );
      }
    } finally {
      _token = null;
      link.close();
    }
  }
}
