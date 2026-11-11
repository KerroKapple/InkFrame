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
