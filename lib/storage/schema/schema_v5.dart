// Schema v=5 — jobs(canvas_id, created_at DESC) 复合索引。
//
// 真相源；`lib/storage/schema/005_jobs_canvas_created_idx.sql` 是文档镜像。
// 生命周期：MigrationRunner 在 schema_version = 4 时于单事务内执行本 SQL，
// 并在同事务 UPSERT schema_version.version = 5。
//
// 动机：JobRepository.listByCanvas 按 canvas_id 过滤 + created_at DESC 排序
// （生成面板 / Inspector 取某画布 job 列表）。v1 只有 idx_jobs_canvas_id
// 单列索引，排序仍需额外 sort；复合索引让"过滤+排序"走同一索引，消除排序开销。
// IF NOT EXISTS 幂等（重跑安全）。

const String kSchemaV5 = r'''
CREATE INDEX IF NOT EXISTS idx_jobs_canvas_created
  ON jobs(canvas_id, created_at DESC);
''';
