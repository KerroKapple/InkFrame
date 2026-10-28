// 软删一批节点连同它们的入 / 出边——批量删节点（CanvasNodesController.removeNodes）与
// 删除泳道和内容（CanvasLanesController.deleteLaneWithContents）共用的唯一实现。
//
// 只依赖 RepositoryScope：调用方在自己的 uow.run 里调用，事务边界归调用方。
// 放在 canvas/util 而不是 storage/：「删节点带走它的边」是画布的删除语义，storage/ 只放具体的
// postgres 实现；这里只拼接抽象仓储，不碰 SQL。
import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/interfaces/unit_of_work.dart';

/// 在 [scope] 里软删 [nodeIds] 及其全部入 / 出边，返回「节点 → 归它的边 id」（键序 = [nodeIds] 的顺序）。
///
/// 分两段：**先**按 [nodeIds] 顺序列完全部入 / 出边并去重（同一条边只归第一个列到它的节点），
/// **再**统一软删——先全部边、后全部节点。交错着「列一张删一张」的话，后面那张已经列不到本事务
/// 刚软删的边，去重形同虚设。[nodeIds] 里的重复 id 只算一次。
Future<Map<String, List<String>>> softDeleteNodesWithEdges(
  RepositoryScope scope,
  Iterable<String> nodeIds,
) async {
  // 第一段：只读——列边、去重、归属。
  final seen = <String>{};
  final planned = <String, List<String>>{};
  for (final id in nodeIds) {
    if (planned.containsKey(id)) continue;
    final outgoing = await scope.edges.listOutgoing(id);
    final incoming = await scope.edges.listIncoming(id);
    final mine = <String>[];
    for (final r in <Map<String, Object?>>[...outgoing, ...incoming]) {
      final eid = r.reqId(EdgeCol.id);
      if (seen.add(eid)) mine.add(eid);
    }
    planned[id] = mine;
  }
  // 第二段：写——先边后节点。
  for (final edgeIds in planned.values) {
    for (final eid in edgeIds) {
      await scope.edges.softDelete(eid);
    }
  }
  for (final id in planned.keys) {
    await scope.nodes.softDelete(id);
  }
  return planned;
}
