// Schema v=5 — jobs(canvas_id, created_at DESC) 复合索引。
//
// 真相源；`lib/storage/schema/005_jobs_canvas_created_idx.sql` 是文档镜像。
// 生命周期：MigrationRunner 在 schema_version = 4 时于单事务内执行本 SQL，
// 并在同事务 UPSERT schema_version.version = 5。
//
// 动机（当初）：JobRepository.listByCanvas 按 canvas_id 过滤 + created_at DESC
// 排序。v1 只有 idx_jobs_canvas_id 单列索引，排序仍需额外 sort；复合索引让
// "过滤+排序"走同一索引，消除排序开销。IF NOT EXISTS 幂等（重跑安全）。
//
// 动机（现在）：listByCanvas 已退役（零生产调用点，见 JobRepository 头注），
// 但本索引**不是**跟着死的——purgePerCanvasCap 的
// `ROW_NUMBER() OVER (PARTITION BY canvas_id ORDER BY created_at DESC)`
// 正好是同一组 (canvas_id, created_at DESC)，而它每次启动都跑。
// 别因为"建它的那个方法没了"就去加一条 DROP INDEX 迁移。
// 另外：已发布的迁移不可改（ADR-0012），这里只改注释，SQL 一字不动。

const String kSchemaV5 = r'''
CREATE INDEX IF NOT EXISTS idx_jobs_canvas_created
  ON jobs(canvas_id, created_at DESC);
''';
