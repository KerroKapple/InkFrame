-- Schema v=2 — jobs.result_node_id 改为 ON DELETE SET NULL
--
-- 本文件为 lib/storage/schema/schema_v2.dart (kSchemaV2) 的文档镜像，
-- 不参与运行时加载。真相源是 schema_v2.dart。
--
-- 背景（TD-001 修复）：
--   v=1 按 PRD §21 字面量落 NO ACTION（无 ON DELETE 子句）。
--   删一个 result 节点时，若仍有 jobs 行引用 result_node_id，FK 会阻断删除，
--   只能靠 JobRepository retention（30 天 + 500 条）先清 jobs，才能硬删 node。
--
-- 修复策略：
--   DROP 掉隐式 FK（jobs_result_node_id_fkey）重建为 ON DELETE SET NULL。
--   语义：删 result node 后，历史 jobs 保留，result_node_id 置 NULL
--   （job 完成但结果被用户丢弃，审计记录保持完整）。
--
-- 回滚：PRD "Zero Backward Compatibility"，不提供降级路径。

ALTER TABLE jobs
  DROP CONSTRAINT jobs_result_node_id_fkey;

ALTER TABLE jobs
  ADD CONSTRAINT jobs_result_node_id_fkey
  FOREIGN KEY (result_node_id) REFERENCES nodes(id) ON DELETE SET NULL;
