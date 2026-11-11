# ADR-0015: 导演会话以只追加事件日志为唯一事实源（模型可见即入日志）

- **Status**: accepted
- **Date**: 2026-11-11
- **Deciders**: 仓库维护者（单人项目）；按 `docs/superpowers/plans/2026-11-10-ai-director.md` 的「A2 导演 harness 骨架」实施
- **Related**: MASTERPLAN D-M4-1（规则拆分仍是默认）· ADR-0012（前向迁移）· ADR-0007（type_config JSONB）· A1 Claude 客户端（`services/anthropic/`）· DeepSeek Harness `dsh` `docs/architecture.md`（只借思路）

---

## Context

A 系列把 Claude 接成「导演助理」：A2 拆分镜，A3 写出图提示词，A4 审图。每一步都是「模型提案 → 人工确认 / 改 / 驳回 → 落画布」，并且：

- 提示词会反复调——调完要能对比「那一次到底发了什么给模型」，否则行为漂移无从查起。
- 花的是用户自己的 API 额度——用量与费用要可追溯，取消 / 驳回的轮次也计费。
- 人工驳回后要重来，但已经确认过的结果不能被重来冲掉。
- A1 的 `ClaudeUsageLedger` 是内存记账：重启即丢，也和「哪一步、哪次请求」对不上。

参照 DeepSeek Harness（Node 运行时的本地 agent harness）的四条做法：模型可见即入日志、每次请求可从日志重建；system prompt 按 section 组装；人工命令不占模型轮次；在 turn 边界分叉。`dsh` 本身嵌进 Flutter 桌面太重，只借思路，用 Dart 在 App 内实现精简版。

## Decision

**决定：导演的一切状态都写成会话内只追加的事件日志（`director_events`），日志是唯一事实源；发给模型的每一次请求体原样入日志，用量 / 费用从日志派生。**

1. **两张表（schema v9，前向迁移）**：`director_sessions`（项目 / 画布 / 内容语言 BCP-47 / 设定 JSONB，软删）+ `director_events`（`seq` 会话内从 1 连续、`(session_id, seq)` 唯一索引；`kind`；`parent_seq`；`payload` JSONB；无 updated_at / deleted_at）。
2. **seq 的并发**：追加在单事务里先 `SELECT … FOR UPDATE` 锁会话行，再取 `MAX(seq)+1` 插入并 touch 会话 `updated_at`；同会话并发追加在行锁上排队，唯一索引兜底。会话字段（语言 / 设定）只随一件事件同事务写回——每次变化都有依据。
3. **事件种类**：`script_submitted` / `model_request`（完整请求体，不含 Key——Key 只在请求头）/ `model_response`（文本块 + usage + stop_reason，拒答、截断、流中途断开都记）/ `model_failed`（InkError code，含用户取消）/ `storyboard_proposed` / `human_edited` / `human_confirmed` / `human_rejected` / `applied_to_canvas`（建出的节点 id）。
4. **模型可见即入日志**：`AnthropicClient.createMessage` 收一个观察口，每次真正发出前（含重试）先 await `onRequest(原样请求体)`——写不进日志就不发；每次带用量的回应 await `onResponse`。日志里的 `model_request.body` 就是线上那份 JSON，可原样重发。
5. **分叉 = 树**：每件事件的 `parent_seq` 指向它接在哪件之后（null = 空根）。重拆从当前分支上最近一件 `human_confirmed` 分出新枝（没有就从空根），驳回意见放进新枝的 `script_submitted.feedback`，作为一段 user 文本进下一次请求；确认过的结果在所有后续分支的父链上，不受影响。取消的那一轮：当下记 `model_failed(cancelled_by_user)`，迟到的回应照样挂在它自己的 `model_request` 下入日志、不出提案。
6. **人工命令不占模型轮次**：确认 / 改 / 驳回只写 `human_*`，不调模型。
7. **system prompt 分段拼装**：`PromptSection`（stable / session / step）按 stability → order → id 排序，稳定段在前、逐字节不变；段落全是英文常量，内容语言只作参数注入。
8. **用量从日志派生**：`ClaudeUsageLedger.fromEvents` 数全部 `model_response`（跨分支）；删掉 A1 的内存记账与写接口。
9. **唯一写入口**：`DirectorSessionController`（按会话 id）；步骤（`DirectorStep`）只描述组请求 / 解析 / 落画布，不碰仓储。落画布走现有 `ScriptImportController.importDrafts`，规则拆分与 AI 拆分共用一条建链路径。
10. **项目包**：两表进 `data.json`；导入重映射 `project_id` / `canvas_id` / `session_id` 与 `applied_to_canvas.node_ids`；`seq` / `parent_seq` 是会话内序号，原样。

**理由：**

1. 提示词与模型行为只能靠「当时到底发了什么」来复盘；存派生物（拼好的提示词、摘要）会在代码改了之后与事实脱节，存原样请求体不会。
2. 计费、确认、驳回都是要追溯的事实；可变状态（「当前提案」）全部从日志派生，状态与历史就不会两张皮。
3. 树形分叉让「重来」不需要删任何东西，也就不需要在只追加的表上开例外。

## Consequences

**好的：**
- 任一次模型调用都能从 `model_request` 原样重建（真客户端 + 回放适配器的测试钉住：日志 body == 线上 body，含重试，且不含 Key）。
- 关掉对话框 / 重启后，会话状态能从日志重建（`DirectorSessionState.fromLog`）。
- A3 / A4 只需新增 `DirectorStep` 与事件种类，管线、日志、记账不动。

**坏的 / 欠的债：**
- **请求体整份入库**：A4 审图会带 base64 图片，日志会膨胀。届时再定是否把图片块换成内容寻址的文件引用（会改变「原样」的口径，需另立决定）。
- **JSONB 不保留键序**：「原样」指 JSON 值相等，不是字节相等；要逐字节重发时按 JSON 重新序列化。
- **落画布与 `applied_to_canvas` 不在同一事务**：`importDrafts` 自带事务，导演仓储追加事件也自带事务（要锁会话行，`RepositoryScope` 的 TxSession 开不了嵌套事务），两者先后提交。建链成功而追加失败时画布上有节点、日志缺这一件——`human_confirmed` 已在，可据此对账；真要原子化再把导演仓储纳入 `RepositoryScope` 并把 seq 分配改成不依赖嵌套事务。
- 会话目前只供重建与记账，没有独立的历史浏览界面。

## Alternatives Considered

### 方案 B：只存「当前提案」与累计用量（可变行）
- 优势：表小、读快。
- 否决理由：丢掉了请求原文与分支历史，提示词调整无法复盘；驳回 / 重来要么覆盖确认过的结果，要么另起一套版本字段。

### 方案 C：直接嵌入 DeepSeek Harness（dsh）
- 优势：现成的日志与分叉语义。
- 否决理由：Node 运行时嵌进 Flutter 桌面太重，进程间协议与打包都是新负担；我们只需要其中四条约定。

### 方案 D：记账继续放内存、日志只存提案
- 否决理由：两处记同一件事迟早对不上；取消 / 驳回轮次的费用会漏。

## Revisit Triggers

- A4 带图请求让日志体积成为问题时（见「坏的」第一条）。
- 需要导演会话的历史浏览 / 回放界面时。
- 落画布与日志的非原子窗口在真实使用中出现对账问题时。
