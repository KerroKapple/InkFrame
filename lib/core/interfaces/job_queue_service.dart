/// JobQueueService：提交生成任务、调度并发、暴露状态流（PRD §10.7）。
///
/// 实现需保证：
/// - 全局并发上限（来自性能档位 maxConcurrentJobs）
/// - per-provider 并发上限（来自 ProviderCapabilities.maxConcurrentJobs）
/// - 同步 / 异步 Provider 上层无差别消费（按 ADR-0004）
///
/// 本接口不持久化 jobs 表（b2 子步实现）；不写盘（b3 子步实现）。
library;

import '../models/generation_task.dart';
import '../models/job_status.dart';

/// 提交后的任务句柄——拿到即可订阅状态流或等待终态。
abstract class JobHandle {
  /// 业务侧 jobId（与 GenerationTask.jobId 一致）。
  String get jobId;

  /// 状态推送：inProgress(0..1) → success / failure 后流关闭。
  ///
  /// 每次访问返回一条新流：订阅时先重放最近一次状态（last-value cache），
  /// 再接收后续推送；终态后订阅也能收到终态并立即 done。
  Stream<JobStatus> get status;

  /// 终态 Future——success / failure 任一返回，cancelled 也归 failure。
  Future<JobStatus> get done;
}

abstract class JobQueueService {
  /// 启动初始化：扫描 jobs 表把卡在 pending/submitted/polling 的任务标
  /// cancelledOnExit（pending 行也回收——上次会话建行后未跑完即退出）。
  ///
  /// 必须在 app 启动早期调用（在用户能 submit 新任务之前）。
  /// 未注入 JobRepository 的实现允许 no-op。
  Future<void> init();

  /// 提交生成任务，立即返回 JobHandle。
  ///
  /// 真实 Provider 调用、轮询、状态推进在后台异步执行。
  /// 同 jobId 重复 submit 抛 [StateError]。
  ///
  /// **前置条件**：调用方需先在 jobs 表创建 status='pending' 的行（PRD §10.3）。
  Future<JobHandle> submit(GenerationTask task);

  /// 取消任务。pending 直接踢出队列；running 调 Provider.cancel（若支持）。
  ///
  /// 不存在的 jobId 静默 no-op（idempotent）。
  Future<void> cancel(String jobId);

  /// 释放所有内部资源（关 stream、停调度器）。
  void dispose();
}
