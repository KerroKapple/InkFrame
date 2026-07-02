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
    String? sourceNodeId,
    String? resultNodeId,
  }) = JobQueued;

  /// 已取到 slot，正在调 Provider.submit——pending → submitted。
  const factory JobState.submitting({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? sourceNodeId,
    String? resultNodeId,
  }) = JobSubmitting;

  /// 轮询中，progress ∈ [0,1]——polling 状态。Provider 不提供进度时 progress=0。
  const factory JobState.running({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? sourceNodeId,
    String? resultNodeId,
    @Default(0.0) double progress,
  }) = JobRunning;

  /// 终态：成功 + 落盘后的 canvas 相对路径（image_url / video_url）。
  const factory JobState.succeeded({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? sourceNodeId,
    String? resultNodeId,
    required String artifactPath,
  }) = JobSucceeded;

  /// 终态：失败，错误已映射为 InkError 子类。UI 通过 error.messageKey 走 l10n。
  const factory JobState.failed({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? sourceNodeId,
    String? resultNodeId,
    required InkError error,
  }) = JobFailed;

  /// 终态：用户主动取消 / 应用退出取消。
  const factory JobState.cancelled({
    required String jobId,
    required String providerId,
    required String canvasId,
    String? sourceNodeId,
    String? resultNodeId,
  }) = JobCancelled;
}

extension JobStateX on JobState {
  String get canvasId => switch (this) {
        JobQueued(:final canvasId) => canvasId,
        JobSubmitting(:final canvasId) => canvasId,
        JobRunning(:final canvasId) => canvasId,
        JobSucceeded(:final canvasId) => canvasId,
        JobFailed(:final canvasId) => canvasId,
        JobCancelled(:final canvasId) => canvasId,
      };

  String get jobId => switch (this) {
        JobQueued(:final jobId) => jobId,
        JobSubmitting(:final jobId) => jobId,
        JobRunning(:final jobId) => jobId,
        JobSucceeded(:final jobId) => jobId,
        JobFailed(:final jobId) => jobId,
        JobCancelled(:final jobId) => jobId,
      };

  String get providerId => switch (this) {
        JobQueued(:final providerId) => providerId,
        JobSubmitting(:final providerId) => providerId,
        JobRunning(:final providerId) => providerId,
        JobSucceeded(:final providerId) => providerId,
        JobFailed(:final providerId) => providerId,
        JobCancelled(:final providerId) => providerId,
      };

  /// 发起该 job 的 config 节点 id（用于 Inspector 按节点回读进度）。可为 null。
  String? get sourceNodeId => switch (this) {
        JobQueued(:final sourceNodeId) => sourceNodeId,
        JobSubmitting(:final sourceNodeId) => sourceNodeId,
        JobRunning(:final sourceNodeId) => sourceNodeId,
        JobSucceeded(:final sourceNodeId) => sourceNodeId,
        JobFailed(:final sourceNodeId) => sourceNodeId,
        JobCancelled(:final sourceNodeId) => sourceNodeId,
      };

  /// 该 job 的 result 节点 id（批量网格定点刷新用）。可为 null。
  String? get resultNodeId => switch (this) {
        JobQueued(:final resultNodeId) => resultNodeId,
        JobSubmitting(:final resultNodeId) => resultNodeId,
        JobRunning(:final resultNodeId) => resultNodeId,
        JobSucceeded(:final resultNodeId) => resultNodeId,
        JobFailed(:final resultNodeId) => resultNodeId,
        JobCancelled(:final resultNodeId) => resultNodeId,
      };

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
