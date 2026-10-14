// 一个节点在序列的哪一镜：纯函数，不碰 ref、不碰外壳。
//
// 判据只有一份（[_shotIndexOfNode]，与 sequence_builder 的折叠同一口径），几处共用：
//   - 「在序列中查看 / 定位」跳到哪一镜、节点右键菜单的「在序列中定位」可不可点：[shotIndexForSelection]
//     （view_in_sequence.dart 与 canvas/widgets/create_node_menu.dart）；
//   - 镜号：[shotIndexByNode] 一次给出每个节点所在那一镜——左栏大纲行首的镜号、⌘K 镜头组的「序列 NNN」由它来
//     （经 canvas/util/outline_model.dart 的 sequenceShotNumbers），与序列视图、画廊的序号是同一个数。
//
// 从 view_in_sequence.dart 拆出来：那份要 ref、要切外壳标签，canvas/util 的纯函数不该为了一个判据把外壳
// 控制器连带 import 进来。
import '../../canvas/models/canvas_node.dart';
import '../../storyboard/models/sequence_shot.dart';
import '../models/sequence_lens.dart';

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
