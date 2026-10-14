// 「在序列中查看 / 定位」：切到序列标签，把播放头跳到给定节点所在的那一镜。
//
// 两个入口共用这一份：外壳标签栏画布标签右侧的「在序列中查看」（看选中集），与画布节点右键菜单的
// 「在序列中定位」（看菜单的目标集）。PR-8b 从 shell_tab_bar.dart 原样搬出来（_viewInSequence /
// shotIndexForSelection），逻辑与临时保活订阅一行没改；只多了一个可选的 [nodeIds]——不给就是选中集，
// 与原来逐字相同。
//
// 「一个节点在哪一镜」的判据（[_shotIndexOfNode]）也给镜号用：[shotIndexByNode] 一次给出每个节点所在那一镜，
// 左栏大纲的镜号、⌘K 镜头组的「序列 NNN」由它来（经 canvas/util/outline_model.dart 的 sequenceShotNumbers），
// 与序列视图、画廊的序号是同一个数——折叠规则不另写第二份。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../../canvas/providers/canvas_selection_controller.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../../storyboard/models/sequence_shot.dart';
import '../models/sequence_lens.dart';
import '../providers/sequence_lens_provider.dart';
import '../providers/sequence_playhead.dart';

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

/// 「在序列中查看」该跳到哪一镜：选中节点里链序最靠前的那一镜；没选中 / 都不在链上 ⇒ -1。
///
/// 一个节点「在」哪一镜（与 sequence_builder 的折叠同一口径）：
///   - 它自己就是那一镜（shot.nodeId）；
///   - 那一镜放的就是它（shot.artifactNodeId——选中的正是那张成片）；
///   - 产物节点归到它的来源配置节点；配置节点若把产物借给了前面的 shot（折叠，不单独成镜），
///     就落在借走它产物的那一镜上。
int shotIndexForSelection(
  SequenceLens lens, {
  required Set<String> selection,
  required List<CanvasNode> nodes,
}) {
  if (selection.isEmpty || lens.shots.isEmpty) return -1;
  final Map<String, CanvasNode> byId = <String, CanvasNode>{for (final CanvasNode n in nodes) n.id: n};
  int best = -1;
  for (final String id in selection) {
    final int i = _shotIndexOfNode(lens, id, byId);
    if (i >= 0 && (best < 0 || i < best)) best = i;
  }
  return best;
}

/// 每个节点所在那一镜的下标（0 起）：逐个节点问 [shotIndexForSelection] 用的同一个判据（[_shotIndexOfNode]），
/// 不另写折叠规则。不在任何一镜里的节点（不在叙事链上，或折叠时被跳过的，见 sequence_builder）不在表里。
Map<String, int> shotIndexByNode(SequenceLens lens, {required List<CanvasNode> nodes}) {
  if (lens.shots.isEmpty) return const <String, int>{};
  final Map<String, CanvasNode> byId = <String, CanvasNode>{for (final CanvasNode n in nodes) n.id: n};
  final Map<String, int> out = <String, int>{};
  for (final CanvasNode n in nodes) {
    final int i = _shotIndexOfNode(lens, n.id, byId);
    if (i >= 0) out[n.id] = i;
  }
  return out;
}

int _shotIndexOfNode(SequenceLens lens, String id, Map<String, CanvasNode> byId) {
  final CanvasNode? node = byId[id];
  final String owner = node != null && node.role == NodeRole.result ? (node.sourceNodeId ?? id) : id;
  for (int i = 0; i < lens.shots.length; i++) {
    final SequenceShot shot = lens.shots[i];
    if (shot.nodeId == owner || shot.artifactNodeId == id) return i;
    final String? artifact = shot.artifactNodeId;
    if (artifact != null && byId[artifact]?.sourceNodeId == owner) return i;
  }
  return -1;
}
