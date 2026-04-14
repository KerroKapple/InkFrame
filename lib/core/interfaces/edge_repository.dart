// EdgeRepository 契约：edges 表（data / narrative / generation_source）。
abstract class EdgeRepository {
  /// 创建连线。若 (source, target, type) 已存在则抛 UniqueViolationException（CHECK 约束）。
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  });

  Future<Map<String, Object?>?> findById(String id);

  /// 列出画布下未软删除连线。
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId);

  /// 列出某节点所有出边。
  Future<List<Map<String, Object?>>> listOutgoing(String sourceNodeId);

  /// 列出某节点所有入边。
  Future<List<Map<String, Object?>>> listIncoming(String targetNodeId);

  Future<int> update(String id, Map<String, Object?> patch);
  Future<int> softDelete(String id);
  Future<int> restore(String id);
  Future<int> hardDelete(String id);
}
