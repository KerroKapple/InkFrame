// 产物落点（画布重设计：成片不再全叠在世界原点）。
//
// 生成路径预建 result 节点时原来不给坐标 ⇒ NodeRepository 默认 (0,0)：每次生成的
// 成片都叠在世界原点，还常常正压在示例 config 卡上。现在统一排在 config 卡右侧一列：
//
//   x = config.x + 卡宽 + kResultColumnGap
//   y = config.y + k × (卡高 + kResultRowGap)
//
// k = 这一列里**第一个空着的格**（[nextResultSlot]）：第一个产物与 config 顶对齐，之后逐个往下排。
// 不按「现存产物数」取：删掉中间一张后数目变小，下一个产物会正好叠在最后一张上。被用户拖离格位的
// 产物不占格。每个产物都单独占一格、都在 config 出口右侧——产出线（lineage_edges.dart）不会从
// 别的产物卡底下穿过去。卡片尺寸按渲染尺寸 kNodeCardSize（DB 的 size 列不驱动渲染）。
//
// 生成路径（GenerationController）与示例项目（CanvasBootstrapController）共用这一条规则。
import 'dart:ui';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../models/canvas_node.dart';

/// config 卡（左上角在 [configPosition]，世界坐标）名下第 [index] 个产物的左上角世界坐标。
Offset resultNodePosition({
  required Offset configPosition,
  required int index,
}) =>
    Offset(
      configPosition.dx + kNodeCardSize.width + kResultColumnGap,
      configPosition.dy + index * (kNodeCardSize.height + kResultRowGap),
    );

/// [configNodeId] 名下现存产物数。
///
/// [rows] 是 `NodeRepository.listByCanvas` 的原始行（本就滤掉了软删；这里再按
/// deleted_at 兜一道，换个行来源也不会把回收站里的产物数进去）。只数
/// node_role = result 且 source_node_id 指向 [configNodeId] 的行。
int liveResultCount(
  Iterable<Map<String, Object?>> rows,
  String configNodeId,
) {
  var count = 0;
  for (final Map<String, Object?> row in rows) {
    if (row[NodeCol.deletedAt] != null) continue;
    if (row[NodeCol.nodeRole] != NodeRole.result.name) continue;
    if (row.optId(NodeCol.sourceNodeId) != configNodeId) continue;
    count++;
  }
  return count;
}

/// [configNodeId] 名下下一个产物该落的格（[resultNodePosition] 的 index）：格位上（容差 1px）已经有现存
/// 产物的格算占用，取最小的空格。删掉中间的产物，它那一格就空出来、下一个产物补进去；被用户拖离格位的
/// 产物不占格。[rows] 的口径同 [liveResultCount]。
int nextResultSlot(
  Iterable<Map<String, Object?>> rows, {
  required String configNodeId,
  required Offset configPosition,
}) {
  const double tolerance = 1;
  final double columnX = resultNodePosition(configPosition: configPosition, index: 0).dx;
  final double pitch = kNodeCardSize.height + kResultRowGap;
  final Set<int> taken = <int>{};
  for (final Map<String, Object?> row in rows) {
    if (row[NodeCol.deletedAt] != null) continue;
    if (row[NodeCol.nodeRole] != NodeRole.result.name) continue;
    if (row.optId(NodeCol.sourceNodeId) != configNodeId) continue;
    final double? x = row.optDouble(NodeCol.positionX);
    final double? y = row.optDouble(NodeCol.positionY);
    if (x == null || y == null || (x - columnX).abs() > tolerance) continue;
    final double k = (y - configPosition.dy) / pitch;
    final int slot = k.round();
    if (slot >= 0 && (k - slot).abs() * pitch <= tolerance) taken.add(slot);
  }
  var next = 0;
  while (taken.contains(next)) {
    next++;
  }
  return next;
}
