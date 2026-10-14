// CanvasJobListener：jobsRegistry → 画布副作用的唯一接线点。
// 纯决策在 CanvasJobEffects.diff；本 widget 只负责 ref.listen + 执行副作用，
// 可在 widget test 中独立 pump（无 DB 依赖）。
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
import '../providers/current_canvas_id.dart';
import '../util/canvas_job_effects.dart';

class CanvasJobListener extends ConsumerWidget {
  const CanvasJobListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    ref.listen<List<JobState>>(jobsRegistryProvider, (prev, next) {
      if (canvasId == null) return;
      final effect = CanvasJobEffects.diff(
        prev: prev ?? const <JobState>[],
        next: next,
        canvasId: canvasId,
      );
      if (effect.shouldReloadNodes) {
        ref.invalidate(canvasNodesControllerProvider(canvasId));
      }
      // 终态定点刷新批量网格（autoDispose family：未被 watch 时 invalidate 为 no-op）。
      for (final nodeId in effect.invalidateBatchNodes) {
        ref.invalidate(batchResultsControllerProvider(nodeId));
      }
    });
    return child;
  }
}
