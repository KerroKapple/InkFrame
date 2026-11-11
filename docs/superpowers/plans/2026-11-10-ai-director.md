# AI 导演模式：Claude 当导演、Grok 出图出片

> 状态：草案，待用户批准后执行。来源：《子美传》制作中跑通的流程（Claude 拆分镜/写提示词/审图 → Grok 出关键帧 → 人工定图 → Grok 出视频）。

## 目标

在 InkFrame 里复现这套流程：

```
剧本 ──Claude──▶ 分镜表（每镜：景别/首帧/运动/时长/角色）
     ──Claude──▶ 每镜出图提示词（带风格锚图、硬约束）
     ──Grok────▶ 关键帧
     ──Claude──▶ 审图（看图找问题 → 给修正提示词 → 一键重出）
     ──人工────▶ 按段落定图
     ──Grok────▶ 已定的镜出视频
```

## 关键决定

| 项 | 决定 | 理由 |
|---|---|---|
| Claude 接入面 | **Messages API**（工具调用 + 结构化输出 + 看图），用户在设置里填 API Key（plan 赠送的 API 额度，Key 存系统钥匙串） | 导演循环由 InkFrame 本地掌控，每步都要人工确认，不需要 Anthropic 托管沙箱；Managed Agents 用不上 |
| Claude 调用方式 | dio 直发 HTTP（Anthropic 无官方 Dart SDK） | — |
| 模型 | `claude-opus-5-5`，自适应思考（关不掉，省钱只能降 effort）；分镜/审图 effort 显式写 `medium`；开 server-side fallbacks：请求头 `anthropic-beta: server-side-fallback-2026-07-01` + body `fallbacks: "default"`；先判 `stop_reason == "refusal"`（读 `stop_details.category`）再读内容；记账单价 $4 / $20 每 MTok | 当前默认模型 |
| 结构化输出 | 分镜表、审图结论一律走 `output_config.format`（JSON Schema）；**不用**强制 `tool_choice`（`any`/`tool` 在 opus-5-5 上 400），也不做 assistant 预填（400） | 模型约束 |
| Grok 接入面 | **本机 grok CLI** 无头调用：`grok --prompt-file <task.md> --permission-mode acceptEdits --allow image_gen --allow image_edit --allow image_to_video --allow reference_to_video --allow 'run_terminal_command(cp:*)'`，走 `ProcessStarter` | 用用户 grok.com 订阅额度，不另付费；只在装了 grok 的机器可用，能力声明里标明；不 `--allow` 会被 grok 自身策略拒绝，不放 acceptEdits/cp 产物落不了盘 |
| 「零 LLM」原决定 D-M4-1 | 保留规则拆分为默认/兜底；AI 分镜是**可选增强**，没填 Claude Key 时入口置灰 | 不破坏无 Key 可用 |
| 水印 | Grok 水印原样保留，提示词与审图都不得要求去除 | xAI 使用条款 |

## 组件

1. **`GrokCliProvider`**（`lib/providers/grok_cli_provider.dart`）
   - 实现 `Submittable` + `Pollable` + `KeyValidatable`；JobId 用 `local://grok/<uuid>`。
   - `submit`：在任务目录写 `task.md`（提示词 + 参考图绝对路径 + 保存路径），`ProcessStarter.start('grok', [...])`；`poll` 看进程退出码与产物文件。
   - 能力：`textToImage`（从零出关键帧）、`imageToImage`、`imageToVideo`；视频 720p，时长 1–15 秒（reference_to_video）/ 6、10 秒（image_to_video）；参考图 ≤14。
   - `validateApiKey` 改为「环境检查」：找 grok 可执行文件 + `grok usage` 判断已登录。
   - 错误映射：ZDR 拒绝 → 专门的 `InkError` 子类，提示去 `/privacy` 选 Opt in；Grok 自身策略拒绝 → 提示需 `--allow`。
2. **`AnthropicClient`**（`lib/services/anthropic/`，接口在 `core/interfaces/`）
   - `messages(...)`（流式，取最终消息）；Key 校验用 `GET /v1/models`（不耗生成额度）。
   - 结构化输出走 `output_config.format`；看图走 base64 image block。
   - 统一处理 refusal（含 fallback 后仍拒）、429 / 5xx 退避（读 `retry-after`）、`usage` 记账（显示每次调用 token 与估算费用）。
3. **导演能力**（`lib/features/director/`）
   - **AI 分镜**：剧本 → 结构化输出分镜表 → 复用 SB-2 的建链控制器落到画布。
   - **提示词编写**（系统提示词按项目规则写成英文常量，放 `lib/features/director/director_prompts.dart`）：内置《子美传》踩过的硬规则——不画断肢（局部靠景别）、画面无文字印章、侧脸只一只眼、群像写完整人形、同场先出全景再锁光线、夜戏积墨等；风格锚图从画布上的参考节点取。
   - **AI 审图**：关键帧（base64）+ 该镜分镜 → 结构化结论 `{pass, issues[], fix_prompt}`；Inspector 显示问题，一键带 `fix_prompt` 重出。
   - **定图门**：镜头状态 草稿 → 待审 → 已定 → 视频中 → 完成；只有「已定」的镜能出视频；按段落批量「定图」「出视频」。
4. **设置页**：Claude API Key 输入 + 校验；Grok CLI 路径探测 + 登录/隐私状态提示。


## 分期（2026-11-11 改：先做 Claude 导演 agent，Grok 接入后置）

每期一个功能分支 + PR，过 `flutter analyze lib test` 与 `flutter test --exclude-tags golden`。

- **A1 Claude 客户端**（分支 `feat/anthropic-client`）：Key 存储 / 校验、Messages 调用、refusal / 重试 / 记账，单测用假 HTTP。不接 UI 功能入口。
- **A2 AI 分镜**：剧本导入对话框加「AI 拆分」开关，结构化输出分镜表 → 复用 SB-2 建链控制器落到画布。
- **A3 提示词编写**：按分镜 + 风格锚图给每镜写出图提示词（硬规则见「组件 3」），写进节点提示词。
- **A4 AI 审图 + 修正重出**：关键帧 + 分镜 → `{pass, issues[], fix_prompt}`，检查器显示，一键带修正提示词重出（走节点现有的出图 Provider）。
- **后置 G1 Grok CLI Provider**、**G2 定图门 + 按段落批量出视频**：A 系列跑顺后再定。在那之前出图出片照常用现有 Provider，或手动交给 Grok。

## 不做

- 不接 Managed Agents、不接 xAI 付费 API（以后要开源给别人用时再补 xAI API Provider）。
- 不做去水印。

## 已拍板（2026-11-11）

- 先做 Claude 导演 agent（A1–A4），Grok Provider 后置。
- 计划按 API 文档核对过一轮：补 fallback beta 头、结构化输出不用强制工具调用、不做 assistant 预填。

## A1 Claude 客户端实施细则

- `core/interfaces/anthropic_client.dart`（契约）+ `lib/services/anthropic/dio_anthropic_client.dart`（实现，app-scoped dio）。
  - `createMessage(request)`：流式 SSE 拼最终消息；固定带 `fallbacks: "default"` + beta 头 `server-side-fallback-2026-07-01`；`output_config.format` 结构化输出；image block base64。
  - 返回值先判 `stop_reason`：`refusal` → `ClaudeRefusalError(category)`；`max_tokens` → 截断错误；正常才给内容。
  - 429 / 529 / 5xx 读 `retry-after` 退避，最多 2 次；401 → `invalidKey`。
  - `usage` 记账：每次调用的 input / output / cache token 与按 $4 / $20 估算的费用，经 `ClaudeUsageLedger`（内存）给 UI 读。
  - `anthropic-version` 头按 claude-api skill 的 `shared/api-version-migration.md` 定当前版本（实施时先读该文件与 `curl/examples.md`，不凭记忆）。
- Key：`SecureStorageKeys.anthropicApiKey`；校验 `GET /v1/models`；设置页「API 密钥」加 Claude 一行（不进生成 Provider 注册表——它不是出图出片的 Provider）。
- 测试：假 HTTP 适配器覆盖 SSE 拼接、refusal、fallback 字段、重试、401、记账。

## 附：G1 Grok Provider 的已知缺口（后置时用）

1. 「能不能生成」只认 API Key（`inspectorHasApiKeyProvider`、生成闸、Studio 横幅、设置页 Key 表、引导第 2 步）→ 需要 `credential: apiKey | localCli` + 统一的就绪判据。
2. 产物落盘只有 PNG inline bytes 与远端 URL 下载 → 需要 `JobStatus.success(localFiles:)` + 本机文件拷进画布目录的分支。
3. `grok usage` 无头不可用 → 登录探测改用 `grok models` 输出。
4. 无头命令：`--prompt-file … --permission-mode acceptEdits --allow image_gen/image_edit/image_to_video/reference_to_video --allow 'run_terminal_command(cp:*)'`；另有 `grok agent` 子命令可评估。

## A2 导演 harness 骨架 + AI 分镜 实施细则（2026-11-11 重写，待批准）

设计参照 DeepSeek Harness（`dsh`，`docs/architecture.md`）：借它的「模型可见即入日志」「提示词分段拼装」「人工命令不占模型轮次」「在确认点分叉」四点，用 Dart 在 App 内实现精简版；不引入 dsh 本身（Node 运行时，嵌进 Flutter 桌面太重）。

### 1. 导演会话与事件日志（唯一事实源）

- **新表**（schema v9，按 ADR-0012 加一条前向迁移 `006_director_sessions.sql` + `schema_v9.dart`）：
  - `director_sessions`：`id`、`project_id`、`canvas_id`、`content_language`（BCP-47，如 `zh-CN`）、`setting`（JSONB：时代 / 地域 / 文化 / 美术风格，用内容语言写）、`created_at` / `updated_at`、软删列与其它表一致。
  - `director_events`：`id`、`session_id`、`seq`（会话内连续递增，唯一索引）、`kind`、`parent_seq`（分叉来源，可空）、`payload`（JSONB）、`created_at`。只追加，不改不删（会话软删时随之隐藏）。
- **事件种类**（`kind`，英文常量）：`script_submitted`、`model_request`（完整请求体，不含 Key）、`model_response`（最终消息 + usage + stop_reason）、`model_failed`（InkError code）、`storyboard_proposed`、`human_edited`、`human_confirmed`、`human_rejected`、`applied_to_canvas`（建出的节点 id）。
- **铁律**：发给模型的每一次请求都必须能只靠日志里的 `model_request` 原样重建；用量 / 费用由 `model_response.usage` 派生，`ClaudeUsageLedger` 改为从日志读，不再单独记。
- **项目包导出 / 导入**（LB-11 / LB-12）：两张新表纳入 `data.json`；导入重映射改写 `project_id` / `canvas_id` 与 `applied_to_canvas` 里的节点 id。
- 仓储：`core/interfaces/director_repository.dart` + `storage/repositories/postgres_director_repository.dart`；追加事件与更新会话的 `updated_at` 在同一事务。

### 2. 分段提示词拼装

- `features/director/prompt/`：`PromptSection`（`id`、`order`、`stability`：`stable` / `session` / `step`、`render(context) → String`）+ `PromptAssembler`（按 stability 再按 order 排序拼成 system，保证稳定段在前）。
- 段落（全部英文常量，放 `director_prompts.dart`）：
  1. `role`（stable）：导演助理的身份与总原则。
  2. `hard_rules`（stable）：《子美传》硬规则——保留原文人名 / 地名 / 器物名不翻译、不替换时代背景、不添加原文没有的元素；后续出图规则（不画断肢、画面无文字印章等）A3 再往这一段加。
  3. `setting`（session）：会话设定；第一次拆分时为空，拆完写回。
  4. `language`（session）：`Write every user-facing field in {content_language}.`——只把语言代码当参数注入，模板本身不随界面语言变化。
  5. `task`（step）：本步的任务说明与输出要求。
- 拼装结果原样写进 `model_request`，所以调提示词时历史可对比。

### 3. 步骤管线

- `DirectorStep` 抽象：`buildRequest(session, log) → ClaudeRequest`、`parse(ClaudeMessage) → StepProposal`、`apply(proposal, edits) → 画布写入`。每一步固定走：组请求 → 写 `model_request` → 调用 → 写 `model_response` / `model_failed` → 解析成提案 → **人工关口**（确认 / 改 / 驳回，全在本地，写 `human_*` 事件，不调模型）→ 确认后 apply、写 `applied_to_canvas`。
- 驳回或重来：从最近一个 `human_confirmed` 分叉（新事件 `parent_seq` 指过去），驳回意见作为一段 user 文本注入下一次请求；确认过的结果不受影响。
- `DirectorSessionController`（Riverpod，按会话 id）是唯一写入口；步骤实现不直接碰仓储。

### 4. 第一个步骤：拆分镜（`StoryboardStep`）

- 结构化输出 schema：
  - 顶层：`content_language`、`setting{era, region, culture, art_style}`、`shots[]`。
  - 每镜：`label`、`notes`（首帧画面 + 动作）、`shot_size`、`camera_angle`、`camera`、`duration_seconds`、`characters[]`；枚举直接写成 `ShotSize` / `CameraAngle` / `CameraMovement` 的 `.name`。
- 解析：未知枚举当 null、时长夹到 1–15 秒、空 label 取 notes 首行；`content_language` 与 `setting` 写回会话；出场角色名附在 notes 末尾一行（挂角色库留到 A3）。
- 落画布：`ShotDraft` 加可选的 `shotSize` / `cameraAngle` / `camera` / `durationMs`，`ScriptImportController.importDrafts` 有值才写进现有的 type_config 键——规则拆分与 AI 拆分共用这一条建链路径，不加节点新键。
- effort `medium`；一次导入只调一次，不做 caching / batches。

### 5. 剧本导入对话框

- 策略加第三段「AI 拆分」；没填 Claude Key 时置灰，悬停提示去设置页。
- AI 模式：「开始拆分」→ 进度（可取消，取消只是丢弃结果、照样记 `model_failed`）→ 预览顶部显示**识别出的语言与设定**（可直接改，改动记 `human_edited`），下面每镜「标题 · 景别 · 运镜 · 时长」，以及本次 token 和估算费用。
- 拆完又改了剧本：预览标「文字已修改，需重新拆分」，创建按钮置灰。
- 「创建镜头」= `human_confirmed` + apply。
- 文案全走 ARB（中英），`flutter gen-l10n`。

### 6. 测试

- 迁移：v8 → v9 前向迁移，旧数据原样保留；降级拒绝。
- 仓储：追加事件 seq 连续、并发追加不撞号、软删隐藏。
- 拼装器：排序稳定、语言参数注入、同一会话两次拼装的稳定前缀逐字节一致。
- 管线：用假 `AnthropicClient` 跑一遍确认 / 驳回再分叉 / 失败；断言日志里的 `model_request` 能原样重建实际发出的请求。
- 解析：正常、未知枚举、时长越界、空 label、拒答冒泡。
- 建链：带镜头语言 / 运镜 / 时长的草稿写对 type_config；规则草稿行为不变。
- 项目包：导出再导入后会话与事件完整、id 已改写。
- 对话框 widget：无 Key 置灰、拆分中 / 完成 / 失败、改字后标过期、改设定入日志、创建走同一控制器。

### 7. 文档

- `docs/MASTERPLAN.md` D-M4-1 补「AI 拆分作为可选增强接入（A2），规则拆分仍是默认」。
- 新 ADR：`docs/adr/00xx-director-event-log.md`，记录「模型可见即入日志」与 dsh 参照。
- `docs/CLAUDE.md` 目录快照加 `features/director/`、新仓储与 schema；README 目录概览同步。

### 不做（留给后续）

- 挂角色库、写出图提示词、按 Provider 选提示词语言（A3）；审图（A4）。
- 导演会话的独立界面 / 历史浏览（日志先只供重建与记账）。
