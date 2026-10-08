// 交付计划与交付前检查的 provider（P6）。
//
// 面板与**标签栏主按钮**都要这两样（按钮要知道能不能点、Tooltip 写哪条阻断原因），
// 所以它们住在一个 provider 里而不是在面板 build 里算一遍、按钮再算一遍。
//
// 门控（任务书 §5 的门控回归）：`ShellState.project == null` 时
// [deliveryPlanProvider] 直接给空计划，**不 watch 交付设置**（那一支会去读 projects 表）
// ——面板此时显示「请先打开一个项目」，没有理由碰仓储。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/delivery.dart';
import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/models/style_lane.dart';
import '../../canvas/providers/canvas_lanes_controller.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../../sequence/models/sequence_lens.dart';
import '../../sequence/providers/sequence_lens_provider.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/active_project.dart';
import '../models/delivery_plan.dart';
import '../models/delivery_settings.dart';
import '../util/delivery_preflight.dart';
import 'delivery_settings_controller.dart';

final deliveryPlanProvider = Provider.autoDispose.family<DeliveryPlan, String>(
  (ref, canvasId) {
    final ProjectRef? project = ref.watch(activeProjectProvider);
    if (project == null) return DeliveryPlan.empty;
    final DeliverySettings settings =
        ref.watch(deliverySettingsProvider(project.id)).valueOrNull ??
            DeliverySettings.defaults;
    final SequenceLens lens = ref.watch(sequenceLensProvider(canvasId));
    final List<CanvasNode> nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
            const <CanvasNode>[];
    final List<StyleLane> lanes =
        ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull ??
            const <StyleLane>[];
    return buildDeliveryPlan(
      projectName: project.name,
      lens: lens,
      nodes: nodes,
      settings: settings,
      laneStylePrompts: <String, String>{
        for (final StyleLane l in lanes) l.id: l.stylePrompt,
      },
    );
  },
  name: 'deliveryPlanProvider',
);

/// 交付目录的绝对路径（底部摘要的「输出」行）。projectId 非法时为 null。
final deliveryOutputDirPathProvider = Provider.family<String?, String>(
  (ref, projectId) {
    try {
      return ref
          .watch(fileResolverServiceProvider)
          .resolveInProject(
            projectId: projectId,
            relativePath: kDeliveryOutputDirRelative,
          )
          .path;
    } on PathSecurityError {
      return null;
    }
  },
  name: 'deliveryOutputDirPathProvider',
);

/// 交付目录可不可写（检查第 5 条的数据源）。试建目录 + 写探针文件再删。
final deliveryOutputWritableProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, projectId) =>
      ref.watch(deliveryServiceProvider).probeWritable(projectId: projectId),
  name: 'deliveryOutputWritableProvider',
);

final deliveryPreflightProvider =
    Provider.autoDispose.family<DeliveryPreflight, String>(
  (ref, canvasId) {
    final ProjectRef? project = ref.watch(activeProjectProvider);
    // 探测还没回来时当「可写」：这一条只负责**提前**警告，真写不进去的时候
    // 交付本身会报 LocalIOError。先画一个 ✕ 再翻成 ✓ 更难看。
    final bool writable = project != null &&
        (ref.watch(deliveryOutputWritableProvider(project.id)).valueOrNull ??
            true);
    return runDeliveryPreflight(
      plan: ref.watch(deliveryPlanProvider(canvasId)),
      hasProject: project != null,
      outputWritable: writable,
    );
  },
  name: 'deliveryPreflightProvider',
);
