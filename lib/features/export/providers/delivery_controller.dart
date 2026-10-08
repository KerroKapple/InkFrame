// 交付执行流程（P6 §3）：计划 → 拷媒体 + 写工程文件 + 写 metadata.json。
//
// **app-scoped（非 autoDispose、非 family）**：交付期间整个标签条被锁住，同一时刻
// 只可能有一次交付；把它做成全局单例，「锁标签 / ⌘K 不开 / 设置不开」三处才有
// 一个共同的判据可问（[deliveryBusyProvider]），不必各自去猜是哪个画布在交付。
//
// 关窗时：container.dispose() → 这里的 onDispose → 取消令牌 → 服务清掉半写的
// `.partial`，媒体保留（稿 §3）。不劫持关窗按钮，不等交付跑完。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/clock.dart';
import '../../../core/di/delivery.dart';
import '../../../core/di/file_resolver.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/delivery_service.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/video_export_service.dart'
    show ExportCancelToken;
import '../models/delivery_plan.dart';
import '../models/delivery_writer_registry.dart';
import '../util/delivery_metadata.dart';
import 'delivery_writers.dart';

/// metadata.json 的文件名——协议字面量，不随 UI 语言变。
const String kDeliveryMetadataFileName = 'metadata.json';

sealed class DeliveryState {
  const DeliveryState();
}

final class DeliveryIdle extends DeliveryState {
  const DeliveryIdle();
}

final class DeliveryRunning extends DeliveryState {
  const DeliveryRunning({required this.done, required this.total});

  /// 已拷完的媒体数 / 媒体总数（稿的「交付中 3/8」）。全是占位镜时 total 为 0。
  final int done;
  final int total;

  double? get fraction => total <= 0 ? null : done / total;

  /// 值相等：进度回调每次都造新对象，不按值比就会在同一个 0/N 上重复唤醒
  /// 整条标签栏（与 ShellNavigator.updateShouldNotify 同一个理由）。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryRunning && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);
}

final class DeliverySucceeded extends DeliveryState {
  const DeliverySucceeded(this.outcome);
  final DeliveryOutcome outcome;
}

final class DeliveryFailed extends DeliveryState {
  const DeliveryFailed(this.error);
  final InkError error;
}

final deliveryControllerProvider =
    NotifierProvider<DeliveryController, DeliveryState>(
  DeliveryController.new,
  name: 'deliveryControllerProvider',
);

/// 交付在途吗。锁标签条 / ⌘K / 设置浮层三处共用这一个判据。
final deliveryBusyProvider = Provider<bool>(
  (ref) => ref.watch(deliveryControllerProvider) is DeliveryRunning,
  name: 'deliveryBusyProvider',
);

class DeliveryController extends Notifier<DeliveryState> {
  ExportCancelToken? _token;

  /// dispose 后禁写 state：退出期 container.dispose() 与在途交付并发时，
  /// 迟到的进度回调对已回收的 notifier 写 state 会抛（与 ExportController 同款）。
  bool _alive = true;

  @override
  DeliveryState build() {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _token?.cancel();
    });
    return const DeliveryIdle();
  }

  /// riverpod 默认是 `!identical(previous, next)`：进度回调每次都造新
  /// DeliveryRunning，不覆写就会在同一个 0/N 上重复唤醒订阅者（标签栏、主按钮）。
  @override
  bool updateShouldNotify(DeliveryState previous, DeliveryState next) =>
      previous != next;

  bool get isBusy => state is DeliveryRunning;

  /// 中断在途交付（关窗路径；Esc **不**走这里，稿 §3：Esc 不中断）。
  void cancel() => _token?.cancel();

  /// 关掉结果条。在途时不动（结果条下次交付时自会被替换）。
  void dismissResult() {
    if (!isBusy) state = const DeliveryIdle();
  }

  /// 跑一次交付。[plan] 由面板按当前序列与设置算好。
  Future<void> run({
    required String projectId,
    required DeliveryPlan plan,
  }) async {
    if (isBusy) return;
    final DeliveryProjectWriter? writer =
        ref.read(deliveryWriterRegistryProvider).forTarget(plan.settings.target);
    if (writer == null) {
      // 界面已经把没有写出器的段禁掉了，这里是防御性兜底。
      state = const DeliveryFailed(
        ProviderError(
          code: InkErrorCode.invalidParameter,
          extra: <String, Object?>{'reason': 'delivery_writer_missing'},
        ),
      );
      return;
    }

    final DeliveryPlan effective = plan.settings.relativePaths
        ? plan.withMediaDir(null)
        : plan.withMediaDir(_exportsDirPath(projectId));

    final List<DeliveryMediaCopy> media = <DeliveryMediaCopy>[
      for (final DeliveryShotPlan s in effective.shots)
        if (!s.isPlaceholder &&
            s.fileName != null &&
            s.sourceRelativePath != null)
          DeliveryMediaCopy(
            sourceRelativePath: s.sourceRelativePath!,
            fileName: s.fileName!,
          ),
    ];
    final List<DeliveryTextFile> texts = <DeliveryTextFile>[
      DeliveryTextFile(
        fileName: '${effective.projectFileBaseName}.${writer.fileExtension}',
        contents: writer.write(effective),
      ),
      DeliveryTextFile(
        fileName: kDeliveryMetadataFileName,
        contents: buildDeliveryMetadataJson(
          plan: effective,
          exportedAt: ref.read(clockProvider).nowUtc(),
        ),
      ),
    ];

    final ExportCancelToken token = ExportCancelToken();
    _token = token;
    state = DeliveryRunning(done: 0, total: media.length);
    try {
      final DeliveryOutcome outcome =
          await ref.read(deliveryServiceProvider).deliver(
                projectId: projectId,
                media: media,
                textFiles: texts,
                cancelToken: token,
                onProgress: (int done, int total) {
                  if (_alive && state is DeliveryRunning) {
                    state = DeliveryRunning(done: done, total: total);
                  }
                },
              );
      if (_alive) state = DeliverySucceeded(outcome);
    } on CancelledError {
      // 用户主动中断（关窗）不是失败：回到空态，不弹错误条。
      if (_alive) state = const DeliveryIdle();
    } on InkError catch (e) {
      if (_alive) state = DeliveryFailed(e);
    } finally {
      _token = null;
    }
  }

  /// 交付目录的绝对路径。解析不出来（projectId 非法）时退回相对引用——
  /// 写一个半截绝对路径进 EDL 比写文件名糟得多。
  String? _exportsDirPath(String projectId) {
    try {
      return ref
          .read(fileResolverServiceProvider)
          .resolveInProject(
            projectId: projectId,
            relativePath: kDeliveryOutputDirRelative,
          )
          .path;
    } on PathSecurityError {
      return null;
    }
  }
}
