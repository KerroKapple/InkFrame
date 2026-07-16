// ProjectArchiveReader 契约：LB-11 项目导出的专用只读读侧（全保真）。
//
// 与常规仓储 list 方法的关键差异：**不过滤 deleted_at**。导出必须保证 FK 闭包
// （jobs.source_node_id / batch_results.node_id 可能指向软删节点），软删行连
// deleted_at 一起进包，LB-12 导入后回收站语义原样恢复。
//
// 单方法快照读：9 张表必须出自同一事务快照（REPEATABLE READ）——分次读会在
// 导出期间的并发写（JobQueue 在跑）下产生悬空引用（如 slot 属于未入选的 job），
// 恰好破坏本接口要保证的 FK 闭包（#188 评审 P2-3）。

/// 一次项目快照的全部行集。project 为 null 时项目不存在（其余字段为空列表）。
typedef ProjectArchiveSnapshot = ({
  Map<String, Object?>? project,
  List<Map<String, Object?>> canvases,
  List<Map<String, Object?>> nodes,
  List<Map<String, Object?>> edges,
  List<Map<String, Object?>> lanes,
  List<Map<String, Object?>> characters,
  List<Map<String, Object?>> presets,
  List<Map<String, Object?>> jobs,
  List<Map<String, Object?>> batchResults,
});

abstract class ProjectArchiveReader {
  /// 同一事务快照内读出整项目（含软删行）：
  /// - canvases/nodes/edges/lanes：项目全画布（含软删），created_at,id ASC
  /// - characters/presets：项目级（含软删），created_at,id ASC
  /// - jobs：拥有 ≥1 success slot 的 jobs（跨画布，含软删画布下的），created_at,id ASC
  /// - batchResults：上述 jobs 的全部 slot 行（含失败 slot），job_id,slot_index ASC
  Future<ProjectArchiveSnapshot> snapshot(String projectId);
}
