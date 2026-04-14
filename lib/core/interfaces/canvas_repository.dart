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

  Future<int> update(String id, Map<String, Object?> patch);
  Future<int> softDelete(String id);
  Future<int> restore(String id);
  Future<int> hardDelete(String id);
}
