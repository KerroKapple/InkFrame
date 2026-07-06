// nodeActiveJobProvider：某节点当前活跃（非终态）的生成 job——节点卡按节点回读
// 实时进度。无活跃 job 返回 null；多个活跃取最近插入的一个（与
// JobsRegistry.activeForSourceNode 同语义）。
//
// 复用 JobState 的值相等：仅当本节点的活跃 job 真正变化（进度/状态翻转）时才
// 触发监听者（节点卡）重建，其它节点的 job 变化不连带本卡片。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';

final nodeActiveJobProvider =
    Provider.autoDispose.family<JobState?, String>((ref, nodeId) {
  final jobs = ref.watch(jobsRegistryProvider);
  JobState? found;
  for (final e in jobs) {
    if (e.sourceNodeId == nodeId && !e.isTerminal) found = e;
  }
  return found;
}, name: 'nodeActiveJobProvider');
