# 画布生成集成 Design（让生成结果真正显示到画布）

> Status: 设计已与用户逐段确认（2026-06-02）。下一步：writing-plans 出可执行实现计划。
> 依赖：PR #104（fix/generation-loop-closure）的后端闭环——`jobQueueServiceProvider` 已 FutureProvider 化并注入 repo。本设计的实现分支 `feat/canvas-generation-integration` 基于该后端分支，待 #104 合并后 rebase 到 main。

## Goal

后端纵向链路（PR #104）已打实：生成任务能落库、产物能落盘、result 节点能写 `image_url`。但 UI 端还有三个断点，导致用户在画布里既进不去、也看不到任务在跑、看不到结果。本设计补齐这三处接线，兑现「发起生成 → 看到进度 → 结果显示在画布」的完整闭环。

## 范围（三个缺口，一份计划全包）

| # | 缺口 | 现状证据 | 用户后果 |
|---|---|---|---|
| **G1** | Studio 点项目打不开画布 | `studio_home_screen.dart:419` `onTap` 是空桩 `// Task 11/13 接 open canvas` | 点项目卡片无反应，进不去画布 |
| **G2** | JobsRegistry 没人喂 | `jobsRegistry.upsert()` 定义了但全仓零调用；`GenerationController` 只 `await handle.done`，从不订阅 `handle.status` 推进度 | `job_queue_panel` 永远空列表 |
| **G3** | CanvasRenderQueue 纯 mock | `canvas_render_queue.dart:49-62` 硬编码 3 行假进度 | 画布进度面板是假的 |

## 已确认的产品决策

- **G1 开画布行为**：打开 `canvases.first`（`listByProject` 契约为 `created_at ASC`，first = 最早建的画布，语义良好且顺序契约化）；项目 0 画布 → 先 `canvasRepository.create` 建空白画布再进。「打开最近编辑的画布」列为后续增强（需给 `CanvasRef` 加 `updatedAt` + 改查询，YAGNI，本期不做）。
- **G3 进度面板范围**：`CanvasRenderQueue` 只显示**当前画布**的任务（`JobState` 增加 `canvasId` 维度）。generation 的全局 `job_queue_panel` 维持全局不变。
- **生成交互模式**：fire-and-forget。inspector 点生成后立即返回（不再阻塞到终态），用户可继续操作画布；进度看面板，终态收尾由 controller 内部后台 future 负责。

## 架构（方案①：Controller 单点编排 + 注入 registry 实例）

```
inspector 点生成
   └─ controller.submitFromConfigNode(cfgId)   ← 立即返回 jobId（fire-and-forget）
        ├─ await nodes.create(result, 无 url) + await jobs.create
        ├─ handle = await queue.submit(task)
        ├─ registry.upsert(JobQueued)            ← 注入的 JobsRegistry 实例（非 ref.read）
        └─ unawaited _track(handle, canvasId, resultNodeId):   （后台 future）
             ├─ handle.status.listen → 映射 JobState.running(progress) → registry.upsert
             └─ await handle.done:
                  success   → registry.upsert(JobSucceeded)
                  failure   → nodes.softDelete(resultNode) + registry.upsert(JobFailed)
                  cancelled → nodes.softDelete(resultNode) + registry.upsert(JobCancelled)
             （整个 _track 包在 try/catch，任何异常转 JobFailed.upsert，绝不逃逸成未捕获 future error）

jobsRegistry 变化（keepAlive）
   └─ canvasJobsRefreshListener：当前画布的 job 进入/变更（queued/succeeded/failed/cancelled）
        └─ ref.invalidate(canvasNodesControllerProvider(canvasId))  → 画布重拉真实节点
```

### 模块边界（SOLID 自检）

- **`GenerationController`**：单一职责「跑一次生成的完整生命周期」——编排提交 + 后台收尾。依赖注入的 `JobsRegistry` 实例 + repo 接口，**不 import Riverpod / 不持有 ref**。
- **`JobsRegistry`**（`jobsRegistryProvider`）：UI 端 job 镜像，增加 `canvasId` 过滤维度。**keepAlive 单例，严禁加 autoDispose**（注释 + 设计约束）。
- **`CanvasRenderQueue`**：纯展示。`StatelessWidget` → `ConsumerWidget`，`watch(jobsRegistryProvider)` 后按 `canvasId == currentCanvasId && !isTerminal` 过滤。无业务逻辑。
- **canvas 刷新 listener**：独立 provider 或 `CanvasScreen` 内 `ref.listen`，单一职责「job 生命周期 → invalidate 当前画布节点控制器」。
- **G1 open 逻辑**：Studio 侧一个小函数（拿 `WidgetRef`），`StudioProjectCard` 保持 dumb（只收 `onTap`）。

## 关键不变量（#2 时序竞态——已用代码验证，非假设）

**写库严格早于信号**：`job_queue_service.dart:293-321` 成功路径串行执行——
`_persistInlineBytes`/`_persistRemoteUrls`（`patchTypeConfig(image_url/video_url)`）→ `_persistTransition(to:'success')` **全部 await 落库** → 然后才 `handle._emit(success)` → `handle._complete(success)`。

因为内嵌 PG 单连接、repo 读写同连接顺序执行，`onJobState(succeeded)`（由 status emit / done 驱动）**必晚于 url 落库**，后续 `invalidate → listByCanvas` 必然读到带 url 的节点行。**故 invalidate-on-succeeded 不存在「重拉出空占位」的窗口。**

同理提交侧：controller `await nodes.create`（`generation_controller.dart:190`）后才 `queue.submit`，节点行在 submit 前已提交；约束 **`registry.upsert(JobQueued)` 在 `nodes.create` 之后** emit，invalidate 必看得到占位节点。

这些顺序在实现中是**显式不变量**，由测试锁死（见下）。

## 数据流分时点（画布刷新）

| 时点 | 库状态 | 画布表现 |
|---|---|---|
| 提交后 | result 节点已建（无 url） | invalidate → 显示占位结果节点 |
| 成功 | url 已 patchTypeConfig 落库（早于信号） | invalidate → 占位节点变带图节点 |
| 失败/取消 | result 节点已 softDelete | invalidate → 占位节点消失 |

## 错误处理

- **提交阶段同步失败**（config 非法 / 缺 key / provider 未注册 / `nodes.create`/`jobs.create` 抛错）：仍同步抛 `GenerationError` 给 inspector，走现有 toast。fire-and-forget 只覆盖「已成功 submit 之后」的生命周期。
- **后台 `_track` 失败**：全程包 try/catch，任何异常 → `nodes.softDelete(resultNode)` + `registry.upsert(JobFailed)`，**绝不逃逸为未捕获 future error**（否则崩 UI，正是本设计要防的红线）。
- **failed vs cancelled 的 UX 分流**：
  - `failed` → error toast（`JobFailed.error.messageKey` 走 l10n）。
  - `cancelled`（用户主动）→ **静默，不弹任何 toast**（用户自己点的取消，结果节点消失即是反馈）。
  - 两者都 `softDelete` 孤儿 result 节点。
- **G1 0-画布 create 失败**：`canvasRepository.create` 抛错 → **不 set currentCanvasId**、留在 Studio、弹 error toast。绝不 set 一个不存在的 canvasId 把用户卡进空白 CanvasScreen。

## 终态显示规则（#3 已定死）

`CanvasRenderQueue` 纯 `!isTerminal` 过滤：终态条目即时从画布进度面板消失，**不做定时器、不做 recently-completed 列表**。理由：成功的视觉反馈由画布刷新出的结果节点给出，失败由节点消失给出，进度面板无需再兜一遍。registry 里的终态条目由现有 `clearTerminated()` / 用户在 `job_queue_panel` 手动 `remove` 管理；画布面板只过滤显示，不负责清理。

## 测试（TDD）

- **`jobs_registry_test`**：`upsert` 新增/更新；按 `canvasId` 过滤正确。
- **`generation_controller_test`**（fire-and-forget 重构核心）：
  - `submitFromConfigNode` 立即返回 jobId（不阻塞到终态）。
  - 注入的 registry 收到序列 `queued → running(progress) → succeeded`（fake queue/handle 喂 status 流）。
  - 失败时 `nodes.softDelete(resultNode)` 被调 + `upsert(JobFailed)`。
  - 取消时 softDelete + `upsert(JobCancelled)`。
  - 后台 future 抛异常时被捕获转 `JobFailed`，不逃逸。
- **#2 不变量锁死测试（升级版）**：fake 一个**慢写库**（`patchTypeConfig` 故意延迟/未完成），断言「url 未落库前，`emit(success)` 不发生 / `succeeded` 不进 registry」。**不是只断言 happy-path 顺序**——这样未来谁在 `job_queue_service` 引入并行/把 emit 提前，测试立刻红，不变量才真锁住。
- **`canvas_render_queue_test`**：override jobsRegistry，断言只显示当前画布的在跑任务、`running.progress` 正确、无 watch/harbor/nocturne 假数据。
- **`open_canvas_test`**：点项目 set `currentCanvasId = canvases.first.id`；0 画布项目先 `create` 再 set；create 失败时不 set + 留 Studio。
- **canvas 刷新 listener test**：当前画布 job succeeded → 对应 `canvasNodesControllerProvider(canvasId)` 被 invalidate（节点列表重拉）。

## 范围外（YAGNI）

- 不抽 `JobTracker` 独立层（方案②）——等出现第二个生成提交入口再升级。
- 不做画布进度面板的全局/切换 toggle（Q3 已选纯当前画布）。
- 不做「打开最近编辑画布」（需扩 `CanvasRef` 模型 + 查询，本期 created_at-first 已够）。
- 不做断点续跑 / 应用启动预热队列（已记 memory，属产品决策）。
- 不动 `JobQueueService` 服务层内部逻辑（只消费它现有的 `handle.status` / `handle.done` / `cancel`）。
