# ADR-0008: 渲染队列分层——JobStatus(瞬时) 与 JobState(UI 状态机) 分离，内存镜像 + jobs 表双层

- **Status**: accepted
- **Date**: 2026-07-01
- **Revised**: 2026-07-07（批量部分成功语义 + JobState 携带 resultNodeId——见文末修订记录）
- **Deciders**: P9 (Tech Lead)
- **Related**: ADR-0001 (jobs 表持久化) / ADR-0002 (Riverpod keepAlive) / `lib/features/generation/models/job_state.dart` / `lib/core/models/job_status.dart` / `lib/features/generation/providers/jobs_registry.dart`

---

## Context

一次生成任务的状态要同时服务两个消费者：Provider 轮询逻辑（关心"这一次 poll 返回了什么"）和 UI（关心"任务从入队到终态的完整旅程"）。二者的形状并不相同。此外，状态既要**实时驱动 UI**，又要**跨重启持久**。

**约束：**

- Provider 侧的 `Pollable.poll()` 返回瞬时结果（进行中/成功/失败），不含"排队/提交中/已取消"这类队列语义
- UI（渲染队列面板 + inspector）要展示 queued → submitting → running(%) → succeeded / failed / cancelled 全程
- 持久真值必须落 `jobs` 表（进程重启后可恢复）；但 UI 每帧读 DB 不现实
- 提交生成不能阻塞 UI——inspector 点"生成"后要立刻可继续操作

**假设：**

- 单会话内活跃 job 数量有限，内存镜像成本可忽略
- "卡死的非终态 job"（进程被杀、_track 异常）是需要兜底的病态情形

---

## Decision

**决定：** 两个状态模型 + 两层存储 + fire-and-forget 提交。

1. **`JobStatus`（瞬时态，`lib/core/models/job_status.dart`）**：Provider 单次 poll 的结果，`inProgress(progress)` / `success` / `failure(error)`。
2. **`JobState`（UI 状态机，`lib/features/generation/models/job_state.dart`）**：sealed union `queued / submitting / running(progress) / succeeded(artifactPath) / failed(error) / cancelled`，配 `JobStateX` 派生 `isTerminal / isActive / isCancellable / isRetryable / progressValue`，并携带 `canvasId / jobId / providerId / sourceNodeId`。
3. **`JobsRegistry`（内存镜像，`lib/features/generation/providers/jobs_registry.dart`）**：`Notifier<List<JobState>>`，`keepAlive` 全程存活；`upsert` 按 `jobId` 去重更新；带**淘汰上限**（`kJobsRegistryMaxTerminal=50` / `kJobsRegistryMaxActive=200`）兜底无界增长；查询 `forCanvas` / `activeForSourceNode`。真值仍在 `jobs` 表。
4. **fire-and-forget**：`GenerationController.submitFromConfigNode` 落盘 + 提交后**立即返回 jobId**，后台 `_track` 监听 `JobHandle.status` 流推进 registry，终态时按需 `softDelete` 孤儿 result 节点。

**理由：** 关注点分离（poll 形状 ≠ UI 旅程）；UI 实时性靠内存镜像、可靠性靠 jobs 表；提交不阻塞。

---

## Consequences

**好的：**

- Provider 实现只管 poll 语义，不被 UI 队列态污染
- UI 读一个 `keepAlive` 的内存列表，零 DB 往返、跨屏共享（渲染队列面板 + inspector 都消费它）
- `sourceNodeId` 上到 `JobState` 后，inspector 能按节点回读真实进度（本迭代 ADR-0009 配套改动）
- 淘汰上限防长会话内存泄漏

**坏的 / 欠的债：**

- 内存镜像与 jobs 表是两处状态，需保证 `_track` 正确同步；`_track` 崩溃有兜底（置 failed）但仍是复杂度
- `JobStatus` 与 `JobState` 两套 sealed，映射代码需维护
- fire-and-forget 下 inspector 的提交态是瞬时的，真实进度改由 registry 回读（不是 inspector 自己算）

**中性的（需观察）：**

- 进程被杀导致"卡死非终态"条目，靠淘汰上限 + 下次启动对账（jobs 表）兜底
- progress 若 Provider 不提供则为 0/indeterminate，展示层需处理

---

## Alternatives Considered

### 方案 A: poll 与 UI 共用一个状态模型
- **优势**：模型更少
- **否决理由**：把瞬时 poll 形状和完整生命周期（含 queued/submitting/cancelled）硬塞一起，两边都别扭

### 方案 B: UI 状态也持久化，UI 直接从 DB 流式读
- **优势**：单一真值
- **否决理由**：写放大 + 读延迟；内存镜像 + jobs 表兜底更轻，UI 响应更快

### 方案 C: 提交阻塞直到完成（await submit）
- **优势**：调用点线性、简单
- **否决理由**：冻结 UI；inspector 生命周期被迫绑定 job 生命周期（关闭 inspector 就断了）

### 方案 D: 无上限内存列表
- **优势**：实现最简
- **否决理由**：长会话 + 卡死 job 会无界增长——故有 `kJobsRegistryMax*` 淘汰

---

## Revisit Triggers

- 活跃 job 规模显著增大（如批量/多画布并发）导致内存镜像不再"可忽略"
- 需要跨设备/多窗口同步 job 状态时（内存镜像不够）
- `_track` 同步 bug 反复出现，考虑用单一持久事件源 + 投影
- 至迟在引入"历史/重跑"模块前重审

---

## 修订记录

### 2026-07-07 — 批量部分成功/取消保留语义（拍板）+ JobState 携带字段补 resultNodeId

**触发**：M2「批量 / 变体」全链路落地（BOARD M2 表）——渲染队列之下新增 `batch_results` slot 子状态机，批量网格需要按结果节点定点刷新。

**变化**：

- **批量部分成功语义（拍板）**：一个 job 的 N 个 slot 独立收敛，**≥1 张成功即 job `success`**（首张成功图作结果节点主图 `image_url`）；cancel / error 时**已 success 的 slot 保留**，只翻仍在 `generating` 的 slot。收敛链绝不抛出，启动期 `finalizeAllPending` 兜底。语义正本见 ARCHITECTURE.md §5.1「批量 slot 收敛」，表侧注记见 DATABASE.md。
- **JobState 携带字段**：Decision 第 2 点的携带集（canvasId / jobId / providerId / sourceNodeId）补 **`resultNodeId`**——`canvas_job_listener` 终态时据它定点 `invalidate(batchResultsControllerProvider(nodeId))` 刷新批量网格。

**不变**：JobStatus/JobState 双模型分层、JobsRegistry 内存镜像 + jobs 表双层、fire-and-forget 提交。
