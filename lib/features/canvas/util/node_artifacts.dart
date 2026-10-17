// 节点 → 产物的查找（EX-1′ 首建，SB-6 序列预览消费）。
//
// 画布上一个 config/shot 节点可以被重跑很多次，每次落一个 result 节点。
// 「这一镜现在是哪张图/哪段视频」= 该节点的**当前 take** = 固定的 ?? 最新的：
// 配置节点 type_config.pinned_result_id 指向的产物还在候选里就用它，否则用名下
// **最新**的那个 result（[currentResultFor]）。全仓「这一镜用哪张」只认这一个判官——
// 序列播放 / 交付计划、导出默认勾选、画廊血缘、⌘K 镜头组、左栏大纲、新建菜单都走它。
// 固定的产物被软删后 listByCanvas 不再返回它，判据自然回落最新；撤销删除后又找得到、
// 自然回来——所以删产物时不清 pinned_result_id。
//
// 关键陷阱：`NodeRepository.listByCanvas` 的 ORDER BY 是
// `z_index ASC, created_at ASC`，**主序是 z_index**——用户把某个节点拖到最上层
// 就会改变它在列表里的位置。所以「取最新」绝不能取候选里的列表序末位，必须
// 按 created_at 比。这条是卡面点名的坑，本文件的存在意义就是把它收敛到一处。

import '../models/canvas_node.dart';
import '../models/canvas_node_take.dart';

/// 取 [sourceNodeId] 名下的全部 result 产物，**新→旧**排序。
///
/// 候选条件：`sourceNodeId` 匹配 + `role == result` + 产物 url 非空
/// （图片看 image_url、视频看 video_url，两者都空视为「生成中/失败」的占位节点）。
/// [accept] 可再收窄（EX-1′ 只要 video）。
///
/// 时间戳缺失的排在有时间戳的之后，组内保持**候选列表原序**——本地乐观新增
/// 的节点尚未落库、天然没有 created_at，这条路径要能出确定结果。
List<CanvasNode> resultsFor({
  required String sourceNodeId,
  required List<CanvasNode> nodes,
  bool Function(CanvasNode node)? accept,
}) {
  final stamped = <CanvasNode>[];
  final unstamped = <CanvasNode>[];
  for (final n in nodes) {
    if (n.role != NodeRole.result) continue;
    if (n.sourceNodeId != sourceNodeId) continue;
    if (n.imageUrl == null && n.videoUrl == null) continue;
    if (accept != null && !accept(n)) continue;
    (n.createdAt == null ? unstamped : stamped).add(n);
  }
  // 稳定排序：createdAt 相同的保持候选列表原序。
  stamped.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  // 全缺时间戳时「最新」= 候选列表序末位，故这一组整体反转。
  return <CanvasNode>[...stamped, ...unstamped.reversed];
}

/// 取 [sourceNodeId] 的**当前 take**：固定的（仍在 [resultsFor] 的候选里）?? 最新的；
/// 没有产物则 null。没有固定时就是 [resultsFor] 的头一个。
///
/// 固定的必须满足 [resultsFor] 的全部候选条件（role == result、sourceNodeId 相符、
/// 产物 url 非空、过 [accept]）——固定 id 指向别的配置的产物 / 配置节点 / 生成中或
/// 失败的占位 / 被 [accept] 刷掉的产物、或已被软删（不在 [nodes] 里）时一律回落最新，
/// 绝不返回「错误的那张」。
///
/// [pinnedResultId] 不给时，在 [nodes] 里按 id == [sourceNodeId] 找配置节点读它的
/// 固定 id；调用方手里的 [nodes] 不含配置节点（分桶 / 只给候选）时必须显式传。
/// 显式传了就不再去 [nodes] 里找。
CanvasNode? currentResultFor({
  required String sourceNodeId,
  required List<CanvasNode> nodes,
  bool Function(CanvasNode node)? accept,
  String? pinnedResultId,
}) {
  final List<CanvasNode> all = resultsFor(
    sourceNodeId: sourceNodeId,
    nodes: nodes,
    accept: accept,
  );
  if (all.isEmpty) return null;
  final String? pin = pinnedResultId ?? _configPinOf(sourceNodeId, nodes);
  if (pin != null) {
    for (final CanvasNode n in all) {
      if (n.id == pin) return n;
    }
  }
  return all.first;
}

/// [nodes] 里 id == [sourceNodeId] 的配置节点固定的产物 id；找不到配置节点 / 没固定为 null。
String? _configPinOf(String sourceNodeId, List<CanvasNode> nodes) {
  for (final CanvasNode n in nodes) {
    if (n.id == sourceNodeId && n.role == NodeRole.config) return n.pinnedResultId;
  }
  return null;
}
