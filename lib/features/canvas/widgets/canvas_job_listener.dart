// CanvasJobListener：jobsRegistry → 画布副作用的唯一接线点。
// 纯决策在 CanvasJobEffects.diff；本 widget 只负责 ref.listen + 执行副作用，
// 可在 widget test 中独立 pump（无 DB 依赖）。
//
// 【按 job 所在画布刷新，不只当前画布】节点控制器按画布分族，当前画布之外的那几份也可能活着：
// 状态栏的任务弹层开着时，为每个 job 去 job 所在画布的控制器里找源节点（任务名、「定位」都靠它），
// 别的画布的控制器因此一直被保活。那张画布上的 job 落了产物却没人让它的控制器失效，「定位」过去
// 看到的就是旧节点表：产物卡还在「等待中」、大纲没有子行、历史页是空的。所以注册表里出现过 job 的
// 每一张画布都单独过一遍 diff（判据与当前画布同一份）。没人 watch 的画布 invalidate 是空操作
// （Riverpod：对还没初始化的 provider 调 invalidate 不生效），不用先判断。
//
// 【这里不弹通知】生成完成 / 失败的通知卡在应用级的 JobNotificationListener
// （features/notifications，挂在 ToastLayer 里）：它不随当前画布走，切走画布、换了项目
// 照样通知。这里再弹一次，失败就会出两张卡。本 widget 只管画布这一侧的刷新。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generation/models/job_state.dart';
import '../../generation/providers/batch_results_controller.dart';
import '../../generation/providers/jobs_registry.dart';
import '../providers/canvas_nodes_controller.dart';
import '../util/canvas_job_effects.dart';

class CanvasJobListener extends ConsumerWidget {
  const CanvasJobListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<List<JobState>>(jobsRegistryProvider, (prev, next) {
      final List<JobState> before = prev ?? const <JobState>[];
      final Set<String> canvases = <String>{for (final JobState j in next) j.canvasId};
      for (final String canvasId in canvases) {
        final CanvasJobEffect effect = CanvasJobEffects.diff(
          prev: before,
          next: next,
          canvasId: canvasId,
        );
        if (effect.shouldReloadNodes) {
          ref.invalidate(canvasNodesControllerProvider(canvasId));
        }
        // 终态定点刷新批量网格（autoDispose family：未被 watch 时 invalidate 为 no-op）。
        for (final String nodeId in effect.invalidateBatchNodes) {
          ref.invalidate(batchResultsControllerProvider(nodeId));
        }
      }
    });
    return child;
  }
}
