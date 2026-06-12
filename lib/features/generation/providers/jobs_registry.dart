// JobsRegistry：JobQueue 面板 / Inspector 共享的 UI 端 job 列表。
//
// 内存镜像，不持久化（持久化在 jobs 表）。生成 controller 在状态变化时
// upsert，本 notifier 暴露给 widget 层读。
//
// 列表顺序：按插入顺序追加（FIFO），保持与 JobQueueService 调度一致的视觉感。
//
// 保留策略：本 provider keepAlive，应用全程存活。终态条目（succeeded/failed/
// cancelled）超过 [kJobsRegistryMaxTerminal] 时自动剔除最旧终态，防止长会话
// 无界增长；活跃条目永不被剔除。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/job_state.dart';

/// 终态条目保留上限——超出后按插入序剔除最旧终态。
const int kJobsRegistryMaxTerminal = 50;

final jobsRegistryProvider =
    NotifierProvider<JobsRegistry, List<JobState>>(
  JobsRegistry.new,
  name: 'jobsRegistryProvider',
);

class JobsRegistry extends Notifier<List<JobState>> {
  @override
  List<JobState> build() => const <JobState>[];

  /// 写入或更新一个 jobId 的状态。新 job 追加到尾部。
  /// 值相等的重复 upsert 直接跳过，不触发通知。
  void upsert(JobState job) {
    final idx = state.indexWhere((e) => e.jobId == job.jobId);
    if (idx >= 0 && state[idx] == job) return;
    final next = List<JobState>.of(state);
    if (idx < 0) {
      next.add(job);
    } else {
      next[idx] = job;
    }
    _evictTerminalOverflow(next);
    state = List<JobState>.unmodifiable(next);
  }

  /// 终态条目超限时就地剔除最旧终态（列表前部即最旧）。
  void _evictTerminalOverflow(List<JobState> list) {
    var excess =
        list.where((e) => e.isTerminal).length - kJobsRegistryMaxTerminal;
    if (excess <= 0) return;
    list.removeWhere((e) {
      if (excess <= 0 || !e.isTerminal) return false;
      excess--;
      return true;
    });
  }

  /// 从列表移除一个 jobId（通常用于用户手动消除某个终态条目）。
  void remove(String jobId) {
    if (!state.any((e) => e.jobId == jobId)) return;
    state = List<JobState>.unmodifiable(
      state.where((e) => e.jobId != jobId),
    );
  }

  /// 一键清掉所有终态条目（succeeded / failed / cancelled）。
  void clearTerminated() {
    final remaining = state.where((e) => !e.isTerminal).toList();
    if (remaining.length == state.length) return;
    state = List<JobState>.unmodifiable(remaining);
  }

  /// 某画布的活跃任务（非终态），按插入序——CanvasRenderQueue 消费。
  List<JobState> forCanvas(String canvasId) =>
      state.where((e) => e.canvasId == canvasId && !e.isTerminal).toList();
}
