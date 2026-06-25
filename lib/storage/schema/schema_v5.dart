// Schema v=5 — jobs 复合索引 idx_jobs_canvas_created（深评 P1-5c 性能定点）。
//
// 真相源；`lib/storage/schema/005_jobs_canvas_created_index.sql` 是文档镜像，不参与运行时加载。
// 生命周期：MigrationRunner 在 schema_version = 4 时于单事务内执行本 SQL，
// 并在同事务 UPSERT schema_version.version = 5。
//
// 背景：jobs 的热查询按 canvas 过滤并以 created_at 排序——
//   - purgePerCanvasCap：PARTITION BY canvas_id ORDER BY created_at DESC
//   - 按画布列举 job 历史
// v1 仅有单列 idx_jobs_canvas_id，过滤后排序仍需额外 sort。新增复合
// (canvas_id, created_at DESC) 覆盖"过滤 + 排序"。复合索引最左前缀已覆盖纯
// canvas_id 过滤，故单列 idx_jobs_canvas_id 冗余——一并删除（零兼容，减写放大）。

const String kSchemaV5 = r'''
CREATE INDEX idx_jobs_canvas_created ON jobs(canvas_id, created_at DESC);

DROP INDEX IF EXISTS idx_jobs_canvas_id;
''';
