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

  /// 项目内全部成功 slot（跨画布，画廊读侧）：JOIN nodes/canvases 过滤软删，
  /// 行内附 join 派生列 canvas_id / project_id，created_at DESC。
  Future<List<Map<String, Object?>>> listSuccessByProject(String projectId);

  Future<int> update(String id, Map<String, Object?> patch);

  /// 单 job 收敛：该 job 下仍 generating 态的 slot 一次性置 [toStatus]
  /// （可附 errorCode，写 completed_at）。已终态 slot 不动（部分成功语义）。
  /// 返回受影响行数。
  Future<int> finalizePendingByJob(
    String jobId, {
    required String toStatus,
    String? errorCode,
  });

  /// 启动孤儿回收：全表仍 generating 态的 slot 置 [toStatus]（启动期无并发）。
  /// 返回受影响行数。
  Future<int> finalizeAllPending({
    required String toStatus,
    String? errorCode,
  });

  /// 标记为已提升：promoted = true + promoted_node_id。
  Future<int> markPromoted({required String id, required String promotedNodeId});

  Future<int> hardDelete(String id);

  /// 磁盘孤儿回收的引用集来源（LB-13）：返回全表所有非空 output_url
  /// （画布相对路径）。只读，不分状态、不分节点软删。
  Future<List<String>> listAllOutputUrls();
}
