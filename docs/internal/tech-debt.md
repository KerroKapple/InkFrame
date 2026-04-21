# Technical Debt Log

> 记录不在当前 scope 但已发现的技术债。格式：
> `TD-编号 | 描述 | 发现时 | 影响 | 建议修复窗口 | Owner`

---

## T2 (2026-04-15)

### TD-001 — jobs.result_node_id 缺 ON DELETE SET NULL ✅ 已修复（schema v=2, 2026-04-21）

- **位置**：原 v=1 `lib/storage/schema/schema_v1.dart` `CREATE TABLE jobs` 段
- **修复**：schema v=2 `lib/storage/schema/schema_v2.dart` DROP + ADD CONSTRAINT，`jobs_result_node_id_fkey` 重建为 `ON DELETE SET NULL`
- **测试**：`test/storage/schema/cascade_test.dart` "删 result node → batch_results CASCADE" 已改为直接删 result，断言 batch_results CASCADE 清空 + jobs.result_node_id 置 NULL
- **v=1 历史**：保留字面量 NO ACTION，不回溯字面追改——升级路径走 MigrationRunner

