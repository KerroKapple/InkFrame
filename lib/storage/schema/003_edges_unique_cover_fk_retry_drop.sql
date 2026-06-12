-- Schema v=3（文档镜像；真相源是 schema_v3.dart）
--
-- HI-10：edges 唯一约束改部分唯一索引——软删行不再占唯一槽位，
--        删边后重连同一 (source, target, edge_type) 不再撞 23505。
-- LO-14：projects.cover_node_id 补 FK → nodes(id) ON DELETE SET NULL；
--        迁移前清既有悬空引用。
-- 死列：jobs.retry_count / max_retries 无任何读写方（重试由 JobQueue
--       内存退避负责，FIX-003 ME-04），直接删除。
--
-- 版本号由 MigrationRunner 在同一事务内 UPSERT 为 3，本文件不自写。

ALTER TABLE edges
  DROP CONSTRAINT edges_source_node_id_target_node_id_edge_type_key;

CREATE UNIQUE INDEX uq_edges_live
  ON edges(source_node_id, target_node_id, edge_type)
  WHERE deleted_at IS NULL;

UPDATE projects p SET cover_node_id = NULL
  WHERE cover_node_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM nodes n WHERE n.id = p.cover_node_id);

ALTER TABLE projects
  ADD CONSTRAINT projects_cover_node_id_fkey
  FOREIGN KEY (cover_node_id) REFERENCES nodes(id) ON DELETE SET NULL;

ALTER TABLE jobs
  DROP COLUMN retry_count,
  DROP COLUMN max_retries;
