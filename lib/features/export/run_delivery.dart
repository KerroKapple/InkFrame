// 发起一次交付的**唯一**入口（P6 §3）。
//
// 三个调用方共用它：标签栏主按钮、结果条的「重试」，以及将来的 ⌘K 动作。
// 与 open_export_dialog.dart 同样的理由——门控判据与 projectId 来源必须同源，
// 否则「按钮亮着但点了没反应」或「绕过检查项直接写盘」这两件事里必有一件会发生。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/models/shell_state.dart';
import '../shell/providers/active_project.dart';
import 'models/delivery_plan.dart';
import 'providers/delivery_controller.dart';
import 'providers/delivery_plan_provider.dart';
import 'util/delivery_preflight.dart';

/// 跑一次交付。按钮已经按同一批判据禁用过了，这里再校验一遍（§3.1 二次校验）：
/// 按下的那一瞬间序列可能已经变了。
Future<void> runDeliveryForCanvas(WidgetRef ref, String canvasId) async {
  final ProjectRef? project = ref.read(activeProjectProvider);
  if (project == null) return; // 没有项目上下文：静默不跑（与导出对话框同款）
  final DeliveryPlan plan = ref.read(deliveryPlanProvider(canvasId));
  if (plan.isEmpty) return; // 一条镜都没有：没什么可交付
  final DeliveryPreflight preflight =
      ref.read(deliveryPreflightProvider(canvasId));
  if (!preflight.canDeliver) return; // 有阻断项
  await ref
      .read(deliveryControllerProvider.notifier)
      .run(projectId: project.id, plan: plan);
}
