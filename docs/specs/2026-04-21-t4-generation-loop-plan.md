# T4 Generation-Loop Sprint Plan

> 日期: 2026-04-21
> 起草: Tech Lead
> 状态: 草稿待审

---

## 1. 目标（用户价值一句话）

**用户在 Canvas 上创建一个 image config 节点 → 写 prompt → 选 Gemini → 点"生成" → 看到 result 节点渲染出图。**

达成后解锁：PRD §29.1 场景 A（首张图 E2E）可演示，剩下 6 款 Provider 仅需 UI 层 dropdown 注册即点亮。

---

## 2. 现状盘点（v0.1.0-alpha.2 HEAD）

### 已就绪积木
- **数据层** — 7 个 Repository + schema v=2 + FileResolver（`~/InkFrame/projects/{pid}/canvases/{cid}/images/`）
- **Provider 层** — Gemini 同步 + 6 款异步（Wanx/Kling），Registry + RateLimiter
- **JobQueueService** — B-b3 内存调度 + 持久化 + inlineBytes 落盘 + node.image_url 回写
- **SecureStorage** — Keychain/Credential Manager + 命名常量 `provider.{id}.api_key`
- **Canvas UI 骨架** — CanvasView + NodeCard + CanvasViewModel（视口/拖拽/增删）

### 不就绪（T4 要补）
1. **CanvasViewModel 纯本地 state**，注释写着"后续 T6 集成时由 Service 层从 Repository 的 Map 转换"——T4 把 T6 提前
2. **CanvasNode UI 模型缺 node_role**（config / result）
3. **NodeCard 无 config 面板、无生成按钮、无状态徽章**
4. **没有 ProviderRegistry 暴露给 UI 的 Riverpod provider**
5. **Settings 页面还未实现 API Key 管理 UI**（SecureStorage 只有 service 层）
6. **GenerationController 不存在**（读 config → SecureStorage → JobRepository.create → JobQueueService.submit → 结果回写的装配逻辑）

---

## 3. Scope 切片（按依赖顺序）

### S1 — Canvas ↔ DB 绑定 (原 T6 提前)

**动机**：UI 要跑生成就必须 persist；内存 state 这条路不通。

- `CanvasNode` 模型重构：加 `NodeRole {config, result}` enum + `projectId` / `canvasId` / `sourceNodeId`
- `CanvasScreenController`（新）接管 DB：
  - `.load(canvasId)` 从 NodeRepository + EdgeRepository 拉
  - `.addNode()` → Repository.insert（乐观更新 + 回滚）
  - `.moveNode()` → 去抖 200ms 后 Repository.updateLayout
  - `.removeNode()` → Repository.softDelete（deleted_at 非空）
- Widget test：overrides 打 mock NodeRepository
- Integration test：`TEST_PG_URL` 跑 load/add/remove 往返

**PR 数**：2（M1 拆分 model + model test；M2 controller + widget/integration test）
**PR 命名**：`feature/t4-s1a-node-role-model` / `feature/t4-s1b-canvas-db-binding`

### S2 — Config 节点编辑 UI

- `ConfigNodeInspector` 面板（右侧抽屉或节点下方 expandable）：
  - Prompt `TextArea`（多行，InkInput 组件）
  - Provider `Dropdown`（从新 `providerRegistryProvider` 拉 capabilities.providerId 列表）
  - Resolution `Dropdown`（读 ProviderCapabilities.resolutions）
  - **Generate** Button（disabled 当 prompt 为空 / 无 API key / Provider 不可用）
- Settings 页面新增 `ApiKeysSection`：每个 Provider 一行 input + 保存到 SecureStorage
- l10n：新增 11 个 key（en + zh 双语）

**PR 数**：2（M1 Inspector UI + Registry provider；M2 Settings API Key section）
**PR 命名**：`feature/t4-s2a-config-inspector` / `feature/t4-s2b-settings-api-keys`

### S3 — 生成动作串联

- `GenerationController`（`lib/features/generation/`）新文件：
  ```
  submit(configNodeId) →
    1. 从 NodeRepository 读 config 节点 parameters
    2. SecureStorage.retrieve(providerApiKey) → 缺失抛业务异常
    3. NodeRepository.insert({type: image, node_role: result, source_node_id: configId}) → resultNodeId
    4. JobRepository.insert({status: pending, ...}) → jobId
    5. Provider-specific GenerationTask 组装
    6. JobQueueService.submit(task)
    7. 订阅 JobHandle.status，异常态 toast + NodeRepository.update(deleted_at) 清掉空 result
  ```
- Canvas 上画生成按钮点击回调走 Controller
- NodeCard 读 `jobsByNodeIdProvider` 给 result 节点显示 progress bar / failure icon

**PR 数**：2（M1 Controller + unit test；M2 Canvas 连线 + status badge）
**PR 命名**：`feature/t4-s3a-generation-controller` / `feature/t4-s3b-node-status-badge`

### S4 — 结果渲染 + 错误收尾

- `NodeCard` result 节点：`FileResolverService.toAbsolute(image_url)` → `Image.file`
- 空态 / loading / error 三态占位
- Toast 组件分流：`JobError.AuthError` → 跳 Settings；`JobError.RateLimit` → 文案 + retry；`JobError.LocalIO` → 普通失败

**PR 数**：1-2（看 E2E 烟测情况）
**PR 命名**：`feature/t4-s4-result-render`

---

## 4. 总规模

- **PR 数**：7-9
- **预估工时**：5-8 个工作日（单人）
- **CI 跑数**：每 PR 独立 + 累计 retrograde 回归

---

## 5. Out of Scope（推后）

- 多帧 / 九宫格生成（PRD §4.6）
- 连线传递参考图（data edge，PRD §4.3）
- 基底风格 / 泳道注入（PRD §5）
- Wanx / Kling 在 UI 中暴露（先 Gemini 打通，再一锅注册）
- 视频节点（T7+）
- 批量并发 UI（JobQueue 内部支持，UI 层先单任务）

---

## 6. 风险 & 未决

### R1 — CanvasViewModel 重构反弹
纯 state 转 DB-backed 是 P2.3 的反向调整。旧测试会全挂，需要同步重写。
**缓解**：S1 直接替换而非兼容；CLAUDE.md §Zero Backward Compatibility 授权砸。

### R2 — Result 节点创建时机
S3 的设计是"提交前先建 result 节点"。但 Provider 失败时要清掉空节点，不够原子。
**备选**：等 Job.success 再创 result（简单），代价：中间态 Canvas 没占位，用户看不到"生成中"。
**决策待用户拍板**。

### R3 — provider 注册缺失
ProviderRegistry 当前只知道 Gemini？需要检查 #23 KlingV3 合流后是否全注册。
**动作**：S1 起手前跑 `grep ProviderRegistry.register` 清点。

### R4 — Schema v=2 生产库升级
alpha.2 内部测试用户可能已有 v=1 库；v=2 首次启动 MigrationRunner 自动升。已覆盖单测。
**动作**：S1 之前加手工 smoke：清 `~/InkFrame/pgdata` 冷启动 + 保留老库热升级两条都跑一次。

---

## 7. 决策请求（需用户/产品回复）

1. **接受这个 7-9 PR 规模**？还是要压缩（砍 S2 API Key UI，临时用 env var）？
2. **R2 result 节点创建时机**：提前创（占位好看）还是 success 后创（逻辑简单）？
3. **S2 Provider dropdown**：首版只放 Gemini 还是全 7 款？
4. **节奏**：7-9 PR 打包成 `v0.1.0-beta.1`，还是每切片一个 `alpha.X`？

审完标"同意 Plan, 按 S1 起手"或提修订意见，P9 再拆 P8/P7 Task Prompts。

---

## 变更记录

| 日期 | 修订 | 作者 |
|---|---|---|
| 2026-04-21 | 初版草稿 | Tech Lead |
