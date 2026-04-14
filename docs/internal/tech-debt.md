# Technical Debt Log

> 记录不在当前 scope 但已发现的技术债。格式：
> `TD-编号 | 描述 | 发现时 | 影响 | 建议修复窗口 | Owner`

---

## T2 (2026-04-15)

### TD-001 — jobs.result_node_id 缺 ON DELETE SET NULL

- **位置**：`lib/storage/schema/schema_v1.dart` `CREATE TABLE jobs` 段
- **现状**：按 PRD §21 字面量落 `NO ACTION`（无 `ON DELETE` 子句）
- **影响**：永久删除一个 result node 时，若仍有 jobs 行引用 `result_node_id`，外键会阻断删除。现阶段依赖 jobs retention（30 天 + 500 条）先清 jobs，再硬删 node。
- **证据**：`test/storage/schema/cascade_test.dart` "删 result node → batch_results CASCADE" 测试中必须先 `DELETE FROM jobs`，注释已标注 TD-001。
- **建议修复**：schema v=2 将 `result_node_id UUID REFERENCES nodes(id)` 改为 `ON DELETE SET NULL`。同时更新 PRD §21 的 DDL 文字。
- **修复窗口**：T3 JobQueueService 落地前或 M2 Sprint 1。
- **Owner**：T2 发现者（P7），修复由 T3 工程师承接。

