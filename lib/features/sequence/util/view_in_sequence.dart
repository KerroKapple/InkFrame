// 「在序列中查看 / 定位」：切到序列标签，把播放头跳到给定节点所在的那一镜。
//
// 两个入口共用这一份：外壳标签栏画布标签右侧的「在序列中查看」（看选中集），与画布节点右键菜单的
// 「在序列中定位」（看菜单的目标集）。PR-8b 从 shell_tab_bar.dart 原样搬出来（_viewInSequence /
// shotIndexForSelection），逻辑与临时保活订阅一行没改；只多了一个可选的 [nodeIds]——不给就是选中集，
// 与原来逐字相同。
//
// 跳哪一镜的判据（shotIndexForSelection）在 shot_index.dart：纯函数，大纲 / ⌘K 的镜号也用同一个判据，
// 用它的地方不必为此 import 这份要 ref、要切外壳标签的文件。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../../canvas/providers/canvas_selection_controller.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../providers/sequence_lens_provider.dart';
import '../providers/sequence_playhead.dart';
import 'shot_index.dart';

/// 切到序列标签；[nodeIds]（不给 = [canvasId] 的选中集）里有节点在叙事链上 ⇒ 播放头跳到链序最靠前的
/// 那一镜。跳镜头走 selectShot——seekToken 自增，与点链表行同一个「用户 seek」入口，监视器据此换镜。
/// 都不在链上 ⇒ 只切标签，播放头不动。
///
/// 【临时订阅撑过这一帧】播放头是 autoDispose：序列标签第一次露面之前没有任何订阅者，裸 read
/// 写进去的值会在下一帧开头被 ProviderScope 回收——随后才 build 的序列屏订阅到的是一个全新的
/// 0 镜播放头，跳转等于没发生。listenManual 挂到这一帧画完（序列屏已经订阅上）再放手。
void viewInSequence(
  WidgetRef ref, {
  required String canvasId,
  Set<String>? nodeIds,
}) {
  final int index = shotIndexForSelection(
    ref.read(sequenceLensProvider(canvasId)),
    selection: nodeIds ?? ref.read(canvasSelectionControllerProvider(canvasId)),
    nodes: ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[],
  );
  ref.read(shellControllerProvider.notifier).goTab(ShellTab.sequence);
  if (index < 0) return;
  final ProviderSubscription<SequencePlayhead> hold =
      ref.listenManual<SequencePlayhead>(sequencePlayheadProvider(canvasId), (_, _) {});
  ref.read(sequencePlayheadProvider(canvasId).notifier).selectShot(index);
  WidgetsBinding.instance.addPostFrameCallback((_) => hold.close());
}
