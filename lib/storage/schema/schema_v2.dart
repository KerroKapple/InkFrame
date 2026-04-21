// Schema v=2 — jobs.result_node_id 改为 ON DELETE SET NULL（TD-001 修复）
//
// 真相源；`lib/storage/schema/002_jobs_result_node_id_set_null.sql` 是文档镜像。
// 生命周期：MigrationRunner 在 schema_version = 1 时执行本 SQL，
// 完成后 UPSERT schema_version.version = 2（由 runner 统一处理，本 SQL 不自己写）。
//
// 修复内容：
//   v=1 里 jobs.result_node_id 按 PRD §21 字面量落 NO ACTION（无 ON DELETE 子句），
//   删 result 节点时 FK 阻断。v=2 重建 FK 为 ON DELETE SET NULL，
//   保留 job 审计行，同时允许 result 节点被硬删。

const String kSchemaV2 = r'''
ALTER TABLE jobs
  DROP CONSTRAINT jobs_result_node_id_fkey;

ALTER TABLE jobs
  ADD CONSTRAINT jobs_result_node_id_fkey
  FOREIGN KEY (result_node_id) REFERENCES nodes(id) ON DELETE SET NULL;
''';
