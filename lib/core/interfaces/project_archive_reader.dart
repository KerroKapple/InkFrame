// ProjectArchiveReader 契约：LB-11 项目导出的专用只读读侧（全保真）。
//
// 与常规仓储 list 方法的关键差异：**不过滤 deleted_at**。导出必须保证 FK 闭包
// （jobs.source_node_id / batch_results.node_id 可能指向软删节点），软删行连
// deleted_at 一起进包，LB-12 导入后回收站语义原样恢复。
abstract class ProjectArchiveReader {
  /// 项目行（按 PK，单行；不存在 → null）。
  Future<Map<String, Object?>?> projectRow(String projectId);

  /// 项目下全部画布（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> canvasRows(String projectId);

  /// 项目全画布下全部节点（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> nodeRows(String projectId);

  /// 项目全画布下全部连线（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> edgeRows(String projectId);

  /// 项目全画布下全部泳道（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> laneRows(String projectId);

  /// 项目角色（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> characterRows(String projectId);

  /// 项目提示词预设（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> presetRows(String projectId);

  /// 拥有 ≥1 success slot 的 jobs 行（跨画布，含软删画布下的），created_at ASC。
  Future<List<Map<String, Object?>>> successJobRows(String projectId);

  /// 上述 jobs 的全部 batch_results 行（含失败 slot），job_id + slot_index ASC。
  Future<List<Map<String, Object?>>> batchResultRows(String projectId);
}
