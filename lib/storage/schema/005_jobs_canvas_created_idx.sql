-- Schema v=5（文档镜像；真相源是 schema_v5.dart）
--
-- jobs(canvas_id, created_at DESC) 复合索引：JobRepository.listByCanvas 按 canvas_id
-- 过滤 + created_at DESC 排序，复合索引让"过滤+排序"走同一索引，消除额外 sort。
-- IF NOT EXISTS 幂等（重跑安全）。
--
-- 版本号由 MigrationRunner 在同一事务内 UPSERT 为 5，本文件不自写。

CREATE INDEX IF NOT EXISTS idx_jobs_canvas_created
  ON jobs(canvas_id, created_at DESC);
