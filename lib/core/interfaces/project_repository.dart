// ProjectRepository 契约：projects 表的 CRUD + 软删除。
//
// 返回 `Map<String, Object?>` 原始行——T2 scope 不造 freezed model，
// 下游（T3 service 层）各自定义 model 并在 service 层做 mapping。
// 这样分层边界清晰：repository 只管 SQL，service 管语义。
abstract class ProjectRepository {
  /// 插入一行；返回数据库生成的主键 id。
  Future<String> create({required String name, String? coverNodeId});

  /// 按 id 读取；不存在或已软删除 → null。
  Future<Map<String, Object?>?> findById(String id);

  /// 列出所有未软删除项目，按 created_at DESC。
  Future<List<Map<String, Object?>>> listAll();

  /// 列出回收站（deleted_at IS NOT NULL）。
  Future<List<Map<String, Object?>>> listTrashed();

  /// 更新任意字段（updated_at 会由 BaseRepository 注入）；返回受影响行数。
  Future<int> update(String id, Map<String, Object?> patch);

  /// 软删除（写 deleted_at）；返回受影响行数。
  Future<int> softDelete(String id);

  /// 从回收站恢复（清 deleted_at）。
  Future<int> restore(String id);

  /// 物理删除；级联清除关联画布及其子数据。
  Future<int> hardDelete(String id);
}
