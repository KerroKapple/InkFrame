-- Schema v=5 文档镜像（不参与运行时加载，真相源为 schema_v5.dart）。
-- 深评 P1-5c：jobs 按 canvas 过滤 + created_at 排序的热路径加复合索引。
-- purgePerCanvasCap 的 PARTITION BY canvas_id ORDER BY created_at DESC、
-- 以及按画布列举 job 历史都吃这个索引。
-- 同时删除 v1 的单列 idx_jobs_canvas_id：复合索引 (canvas_id, created_at) 的
-- 最左前缀已覆盖纯 canvas_id 过滤，单列索引冗余（零兼容，直接删，减写放大）。

CREATE INDEX idx_jobs_canvas_created ON jobs(canvas_id, created_at DESC);

DROP INDEX IF EXISTS idx_jobs_canvas_id;
