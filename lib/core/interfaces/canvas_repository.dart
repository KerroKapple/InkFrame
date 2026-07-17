// CanvasRepository 契约：canvases 表。
abstract class CanvasRepository {
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  });

  Future<Map<String, Object?>?> findById(String id);

  /// 按项目列出未删除画布，created_at ASC。
  Future<List<Map<String, Object?>>> listByProject(String projectId);

  /// 批量版：一次查询取多个项目的未删除画布（project_id ASC, created_at ASC）。
  /// 列表装配走这里，杜绝每项目一查的 N+1。
  Future<List<Map<String, Object?>>> listByProjects(List<String> projectIds);

  Future<int> update(String id, Map<String, Object?> patch);
  Future<int> softDelete(String id);
  /// 项目下回收站画布（deleted_at IS NOT NULL），deleted_at DESC（LB-15 读侧）。
  Future<List<Map<String, Object?>>> listTrashedByProject(String projectId);

  Future<int> restore(String id);
  Future<int> hardDelete(String id);
}
