-- Schema v=4（文档镜像；真相源是 schema_v4.dart）
--
-- 崩溃-续轮决策 B：恢复语义确定为 cancel-on-restart（JobQueueService.init
-- 把 pending/submitted/polling 终结为 cancelled_on_exit），不做 remote_task_id
-- 续轮。续轮所需的 next_poll_at 列与 idx_jobs_next_poll 索引自落库起无写入方
-- （与 v3 删除的 retry 列同理），连同仓储侧 listDuePolling 一并移除。
--
-- 版本号由 MigrationRunner 在同一事务内 UPSERT 为 4，本文件不自写。

DROP INDEX IF EXISTS idx_jobs_next_poll;

ALTER TABLE jobs
  DROP COLUMN next_poll_at;
