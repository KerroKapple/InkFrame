// 某 job 的当前进度投影（对比浮层的 generating slot 用）。
//
// 单独成 provider 而不是在 widget 里遍历 jobsRegistry：注册表任何一条 job 变动都会
// 通知所有监听者，走 family 后只有本 job 的值真变了才重建那一格。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/job_state.dart';
import 'jobs_registry.dart';

/// jobId → 进度 ∈ [0,1]。注册表里没有这条 job（进程重启后读库的历史 slot）时为 null。
final batchJobProgressProvider = Provider.autoDispose.family<double?, String>((
  ref,
  jobId,
) {
  for (final JobState job in ref.watch(jobsRegistryProvider)) {
    if (job.jobId == jobId) return job.progressValue;
  }
  return null;
}, name: 'batchJobProgressProvider');
