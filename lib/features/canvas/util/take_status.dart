// 一个 result 节点在同源兄弟里的 take 状态：第几个 take、一共几个、是不是当前、是不是固定、是不是「未采用」。
//
// 画布卡片（描边 / 图钉 / 半透明 / 状态行）、导出对话框（行尾「固定 / 未采用 / 旧 take」）、检查器历史页
//（「当前」徽标 + 图钉）、节点右键菜单与产物检查器的「设为当前」（是当前就打勾置灰）共用这一个判据，
// 几处不会各算一遍走岔。
//
// 「当前」只认 util/node_artifacts.dart 的 currentResultFor（固定的 ?? 最新的），号只认 util/take_numbers.dart 的
// takeNumbersOn——这里只是把这两个判官的结论拼成一份记录，不另立规则。
//
// 记录（record）是结构相等的：卡片按 `select` 订阅它，兄弟的状态不变就不重建。
import '../models/canvas_node.dart';
import '../models/canvas_node_take.dart';
import 'node_artifacts.dart';
import 'take_numbers.dart';

/// [number]：take 号（最早的是 take 1）；名下只有一个时为 null（「成片」，两处都不写号）。
/// [total]：同源名下有产物的 result 个数（= resultsFor 的个数）。
/// [current]：它是这一镜的当前 take（固定的 ?? 最新的）。
/// [pinned]：它是当前、且当前是被固定的（固定 id 指向它且它还活着）。
/// [notAdopted]：比当前新、但当前是固定的——新出来的 take 没有顶替固定的那张。
typedef ResultTakeStatus = ({int? number, int total, bool current, bool pinned, bool notAdopted});

/// result 节点 [result] 在同源兄弟里的状态；不是 result / 没有来源（孤儿）/ 没有产物 url（生成中、失败的占位）/
/// 不在 [nodes] 里 ⇒ null。
///
/// [pinnedResultId] 与 currentResultFor 同语义：不给 ⇒ 去 [nodes] 里按 id 找来源配置节点读它的固定 id；
/// 调用方手里的 [nodes] 不含配置节点（导出对话框的行只有视频产物）时必须显式传。
/// 固定 id 指向已删 / 不合格的产物 ⇒ 当前回落最新，此时谁都不是 pinned、谁都不是 notAdopted。
ResultTakeStatus? resultTakeStatusOf(
  CanvasNode result,
  List<CanvasNode> nodes, {
  String? pinnedResultId,
}) {
  if (result.role != NodeRole.result) return null;
  final String? source = result.sourceNodeId;
  if (source == null) return null;
  if (result.imageUrl == null && result.videoUrl == null) return null;
  // 新 → 旧。
  final List<CanvasNode> siblings = resultsFor(sourceNodeId: source, nodes: nodes);
  final int index = siblings.indexWhere((CanvasNode n) => n.id == result.id);
  if (index < 0) return null;
  final String? pin = pinnedResultId ?? _configPinOf(source, nodes);
  final CanvasNode? current = currentResultFor(
    sourceNodeId: source,
    nodes: siblings,
    pinnedResultId: pin,
  );
  // currentResultFor 只在固定的那张还在候选里时才返回它——所以「当前 == 固定 id」就是「固定且活着」。
  final bool pinLive = current != null && current.id == pin;
  final int currentIndex =
      current == null ? -1 : siblings.indexWhere((CanvasNode n) => n.id == current.id);
  final bool isCurrent = index == currentIndex;
  return (
    // 号走 takeNumbersOn（传同源兄弟就够：它按来源分桶，别的来源不影响这一桶的号）。
    number: takeNumbersOn(siblings)[result.id],
    total: siblings.length,
    current: isCurrent,
    pinned: isCurrent && pinLive,
    // siblings 新 → 旧：下标比当前小 = 比当前新。没固定时当前就是最新，自然没有比它新的。
    notAdopted: pinLive && index < currentIndex,
  );
}

/// [nodes] 里 id == [sourceNodeId] 的配置节点固定的产物 id；找不到配置节点 / 没固定 ⇒ null。
String? _configPinOf(String sourceNodeId, List<CanvasNode> nodes) {
  for (final CanvasNode n in nodes) {
    if (n.id == sourceNodeId && n.role == NodeRole.config) return n.pinnedResultId;
  }
  return null;
}
