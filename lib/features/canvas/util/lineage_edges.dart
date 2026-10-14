// 画布上「画出来的连线」集合的两个纯函数：推导产出线 + 端口占用。
//
// 产出线（lineage）：result 节点由哪个 config 生成，这件事只存在 nodes.source_node_id
// 里——生成路径不建 edges 行，示例项目也不建，于是画布上「这张图是谁出的」一条线都
// 看不见。这里从节点表推导，**只用于画**：不落库、不迁移、不进 hitTestEdge（点不中、
// 删不掉；要断开就删 result 节点本身）。两点之间已经有任意一条存量边（任一方向、
// 任一类型）就不再推导，免得同一对节点之间叠两条线。
//
// 端口占用：哪些节点的入口 / 出口这一侧真挂着画出来的线（存量边 + 产出线，两端都在
// 传入的可见节点集里）。NodeCard 据此决定端口常驻；没连线的端口只在悬停 / 选中 /
// 连线模式时出现，不再满屏悬空的小圆点。
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';

/// 一条推导出来的产出线：config（[sourceNodeId]）→ result（[targetNodeId]）。
typedef LineageEdge = ({String sourceNodeId, String targetNodeId});

/// 端口占用：[inbound] = 入口一侧挂着线的节点 id，[outbound] = 出口一侧挂着线的节点 id。
typedef PortSides = ({Set<String> inbound, Set<String> outbound});

/// 从 [nodes] 推导产出线：每个 source_node_id 指向 [nodes] 里另一个节点的节点，各一条。
///
/// [nodes] 应是**可见**节点集——折叠道里的端点不画，线也不该画；[edges] 是存量边。
/// 源节点不在 [nodes] 里（已删 / 别的画布 / 折叠隐藏）、指向自己、或这一对节点之间
/// 已有存量边，都不推导。
List<LineageEdge> deriveLineageEdges({
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
}) {
  if (nodes.isEmpty) return const <LineageEdge>[];
  final Set<String> ids = <String>{for (final CanvasNode n in nodes) n.id};
  final Set<(String, String)> linked = <(String, String)>{
    for (final CanvasEdge e in edges) _pair(e.sourceNodeId, e.targetNodeId),
  };
  final List<LineageEdge> out = <LineageEdge>[];
  for (final CanvasNode n in nodes) {
    final String? source = n.sourceNodeId;
    if (source == null || source == n.id || !ids.contains(source)) continue;
    if (linked.contains(_pair(source, n.id))) continue;
    out.add((sourceNodeId: source, targetNodeId: n.id));
  }
  return out;
}

/// 端口占用：存量边与产出线都算，但只算两端都在 [nodes]（可见集）里的——一端在
/// 折叠道里的线画不出来，不能让另一端的端口悬着。
PortSides connectedPortSides({
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
  required List<LineageEdge> lineage,
}) {
  final Set<String> ids = <String>{for (final CanvasNode n in nodes) n.id};
  final Set<String> inbound = <String>{};
  final Set<String> outbound = <String>{};
  void mark(String source, String target) {
    if (!ids.contains(source) || !ids.contains(target)) return;
    outbound.add(source);
    inbound.add(target);
  }

  for (final CanvasEdge e in edges) {
    mark(e.sourceNodeId, e.targetNodeId);
  }
  for (final LineageEdge l in lineage) {
    mark(l.sourceNodeId, l.targetNodeId);
  }
  return (inbound: inbound, outbound: outbound);
}

/// 无序对：任一方向的存量边都算「这两点已经连着」。
(String, String) _pair(String a, String b) =>
    a.compareTo(b) <= 0 ? (a, b) : (b, a);
