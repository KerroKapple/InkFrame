// NodeRepository 契约：nodes 表 + type_config JSONB。
abstract class NodeRepository {
  /// 创建节点。typeConfig 为 JSONB 结构（PRD §4.4），由调用方保证字段正确。
  Future<String> create({
    required String canvasId,
    required String type,
    required String nodeRole,
    String label = '',
    String? sourceNodeId,
    String? laneId,
    double positionX = 0,
    double positionY = 0,
    double width = 240,
    double height = 240,
    int zIndex = 0,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  });

  Future<Map<String, Object?>?> findById(String id);

  /// 画布下未删除节点。
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId);

  /// 仅孤儿 result（source_node_id IS NULL 且 node_role='result'）。
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId);

  Future<int> update(String id, Map<String, Object?> patch);

  /// 仅修改 type_config：jsonb_set 级路径覆盖。patch 合并到 type_config 顶层。
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch);

  Future<int> softDelete(String id);
  Future<int> restore(String id);
  Future<int> hardDelete(String id);
}
