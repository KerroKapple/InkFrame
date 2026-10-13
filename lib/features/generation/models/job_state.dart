// JobState：generation slice UI 端聚合状态机（PRD §10.7 配套）。
//
// 与 core/models/job_status.dart 区分：
//   - JobStatus 是 Provider.poll **单次返回**的瞬时状态（in_progress/success/failure）
//   - JobState 是 JobQueueService → Inspector / JobQueue 面板 / Toast 消费的
//     **完整 UI 状态机**，覆盖入队、提交、运行、终态。
//
// 状态机：
//
//   queued ──► submitting ──► running(progress) ──► succeeded(artifactPath)
//                              │             │
//                              │             └──► cancelled
//                              └──► failed(error)
//
// 不持久化——持久化在 jobs 表（lib/storage/repositories/postgres_job_repository.dart）。
// 本 sealed 仅供 Riverpod ViewModel 推 UI 用。
//
// 【六个变体为什么都带 projectId，且为什么可空】jobsRegistry 是全 app 级内存
// 镜像；条目只带 canvasId 时，任何消费方都只能把"有新产物"当**全局**事实用
// （画廊脏标记因此会被别的项目的 job 置脏，见 shell/providers/gallery_dirty.dart）。
// projectId 与 GenerationTask 同源——都取自 config 节点行的 project_id，
// 节点读路径统一 JOIN canvases 带出，生产里恒非空；类型可空只是因为
// RowReader 证明不了这件事。拿不到就如实留 null，不回填一个猜的值，
// 兜底怎么兜由消费方各自决定（画廊脏标记：退回全局语义，宁多刷不漏刷）。

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/errors/ink_error.dart';

part 'job_state.freezed.dart';

@freezed
sealed class JobState with _$JobState {
  /// 已提交到 JobQueueService 但尚未拿到 provider slot——pending → pending。
  const factory JobState.queued({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? projectId,
    String? sourceNodeId,
    String? resultNodeId,
  }) = JobQueued;

  /// 已取到 slot，正在调 Provider.submit——pending → submitted。
  const factory JobState.submitting({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? projectId,
    String? sourceNodeId,
    String? resultNodeId,
  }) = JobSubmitting;

  /// 轮询中，progress ∈ [0,1]——polling 状态。Provider 不提供进度时 progress=0。
  const factory JobState.running({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? projectId,
    String? sourceNodeId,
    String? resultNodeId,
    @Default(0.0) double progress,
  }) = JobRunning;

  /// 终态：成功 + 落盘后的 canvas 相对路径（image_url / video_url）。
  const factory JobState.succeeded({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? projectId,
    String? sourceNodeId,
    String? resultNodeId,
    required String artifactPath,
  }) = JobSucceeded;

  /// 终态：失败，错误已映射为 InkError 子类。UI 通过 error.messageKey 走 l10n。
  const factory JobState.failed({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? projectId,
    String? sourceNodeId,
    String? resultNodeId,
    required InkError error,
  }) = JobFailed;

  /// 终态：用户主动取消 / 应用退出取消。
  const factory JobState.cancelled({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? projectId,
    String? sourceNodeId,
    String? resultNodeId,
  }) = JobCancelled;
}

extension JobStateX on JobState {
  // 【这里刻意没有 jobId / providerId / canvasId / projectId / sourceNodeId /
  // resultNodeId 的访问器，别再补回来】六个变体都带这六个字段、且类型一致，
  // freezed 3 因此把它们生成成**共享 mixin 上的实例 getter**——见
  // job_state.freezed.dart 的 `mixin _$JobState { String get jobId; ... }`，
  // 由上面的 `sealed class JobState with _$JobState` 直接带上。
  //
  // 而 Dart 的成员解析规则是**实例成员优先于扩展成员**：只要接收者的静态类型上
  // 有同名实例成员，扩展里的同名成员就永远不会被选中——不是"被覆盖"，是根本
  // 不可达。在这个扩展里再手写一遍六臂 switch，写出来的就是死代码，而且两道
  // 常规防线都看不见它：analyzer 没有"扩展成员被遮蔽"这条诊断，单测也照常绿
  // （测到的是生成码那一份）。本仓库为此真实留过 5 个这样的 getter。
  //
  // 加新的共享字段时同理——不要在这里补 getter，直接从 mixin 来。
  // 回归闸：test/quality/no_shadowed_extension_member_test.dart。
  //
  // 反过来说，下面这几个成员必须留在扩展里：它们是跨变体的**派生判据**，
  // 不是字段，freezed 不生成。

  /// 是否处于终态——UI 用来决定能否取消 / 重试。
  bool get isTerminal => switch (this) {
        JobQueued() || JobSubmitting() || JobRunning() => false,
        JobSucceeded() || JobFailed() || JobCancelled() => true,
      };

  /// 是否正在活跃（pending/running，未到终态）——JobQueue 面板筛选用。
  bool get isActive => !isTerminal;

  /// 是否可重试（仅 failed + InkError.retryable=true）。
  bool get isRetryable => switch (this) {
        JobFailed(:final error) => error.retryable,
        _ => false,
      };

  /// 是否可取消（pending/running 才允许）。
  bool get isCancellable => switch (this) {
        JobQueued() || JobSubmitting() || JobRunning() => true,
        _ => false,
      };

  /// 当前进度 ∈ [0,1]。非 running 状态返回 0/1 哨兵值供进度条直接消费。
  double get progressValue => switch (this) {
        JobQueued() => 0.0,
        JobSubmitting() => 0.0,
        JobRunning(:final progress) => progress.clamp(0.0, 1.0),
        JobSucceeded() => 1.0,
        JobFailed() => 0.0,
        JobCancelled() => 0.0,
      };
}
