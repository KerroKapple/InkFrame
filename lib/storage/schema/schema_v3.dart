// Schema v=3 — edges 部分唯一索引 + projects.cover_node_id FK + 死 retry 列删除。
//
// 真相源；`lib/storage/schema/003_edges_unique_cover_fk_retry_drop.sql` 是文档镜像。
// 生命周期：MigrationRunner 在 schema_version = 2 时于单事务内执行本 SQL，
// 并在同事务 UPSERT schema_version.version = 3。
//
// 修复内容：
//   HI-10  v1 的 UNIQUE (source_node_id, target_node_id, edge_type) 把软删行
//          也计入唯一槽位——删边后重连同一三元组必撞 23505。
//          重建为部分唯一索引 WHERE deleted_at IS NULL：仅活边互斥。
//   LO-14  projects.cover_node_id 无 FK，节点硬删后悬空。补 FK → nodes(id)
//          ON DELETE SET NULL；迁移前先清既有悬空引用（零兼容，直接置 NULL）。
//   死列   jobs.retry_count / max_retries 自落库起无任何读写方——
//          重试由 JobQueue 内存退避负责（FIX-003 ME-04），直接删除。

const String kSchemaV3 = r'''
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
''';
