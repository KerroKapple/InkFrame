// Schema v=4 — 删除未接线的崩溃-续轮基础设施（死列 next_poll_at + 死索引）。
//
// 真相源；`lib/storage/schema/004_drop_next_poll.sql` 是文档镜像。
// 生命周期：MigrationRunner 在 schema_version = 3 时于单事务内执行本 SQL，
// 并在同事务 UPSERT schema_version.version = 4。
//
// 决策（崩溃-续轮选 B）：恢复语义确定为 cancel-on-restart——重启时把
// pending/submitted/polling 一律终结为 cancelled_on_exit（见 JobQueueService.init），
// 不做 remote_task_id 续轮。因此续轮所需的 jobs.next_poll_at 列与
// idx_jobs_next_poll 索引自落库起无任何写入方（与 v3 删除的 retry 列同理），
// 连同仓储侧 listDuePolling 一并移除，消除"看似支持恢复"的死代码。

const String kSchemaV4 = r'''
DROP INDEX IF EXISTS idx_jobs_next_poll;

ALTER TABLE jobs
  DROP COLUMN next_poll_at;
''';
