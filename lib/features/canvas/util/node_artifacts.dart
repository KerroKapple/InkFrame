// 节点 → 产物的查找（EX-1′ 首建，SB-6 序列预览消费）。
//
// 画布上一个 config/shot 节点可以被重跑很多次，每次落一个 result 节点。
// 「这一镜现在是哪张图/哪段视频」= 该节点名下**最新**的那个 result。
//
// 关键陷阱：`NodeRepository.listByCanvas` 的 ORDER BY 是
// `z_index ASC, created_at ASC`，**主序是 z_index**——用户把某个节点拖到最上层
// 就会改变它在列表里的位置。所以「取最新」绝不能取候选里的列表序末位，必须
// 按 created_at 比。这条是卡面点名的坑，本文件的存在意义就是把它收敛到一处。

import '../models/canvas_node.dart';

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

/// 取 [sourceNodeId] 名下**最新**的 result 产物；没有则 null。
/// 语义与 [resultsFor] 一致，只取头一个。
CanvasNode? latestResultFor({
  required String sourceNodeId,
  required List<CanvasNode> nodes,
  bool Function(CanvasNode node)? accept,
}) {
  final all = resultsFor(
    sourceNodeId: sourceNodeId,
    nodes: nodes,
    accept: accept,
  );
  return all.isEmpty ? null : all.first;
}
