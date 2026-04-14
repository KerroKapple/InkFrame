// BatchResultRepository 契约：batch_results 表——批量生成 slot。
abstract class BatchResultRepository {
  Future<String> create({
    required String nodeId,
    required String jobId,
    required int slotIndex,
    required String status,
  });

  Future<Map<String, Object?>?> findById(String id);

  /// 按 (node_id, slot_index) 定位。
  Future<Map<String, Object?>?> findBySlot(String nodeId, int slotIndex);

  /// 某批量结果节点下所有 slot，slot_index ASC。
  Future<List<Map<String, Object?>>> listByNode(String nodeId);

  Future<int> update(String id, Map<String, Object?> patch);

  /// 标记为已提升：promoted = true + promoted_node_id。
  Future<int> markPromoted({required String id, required String promotedNodeId});

  Future<int> hardDelete(String id);
}
