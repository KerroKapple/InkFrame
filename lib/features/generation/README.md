# features/generation

把"画布 config 节点 → 生成 → 结果节点"串起来，并维护任务生命周期与 UI 状态。

> 相关 ADR：[0008 渲染队列 JobState/JobStatus](../../../docs/adr/0008-render-queue-jobstate-vs-jobstatus.md) · [0009 Provider 能力/接口隔离](../../../docs/adr/0009-provider-capability-and-interface-segregation.md) · [0004 同步 Provider 数据通道](../../../docs/adr/0004-sync-provider-data-channel.md) · [0005 DashScope 异步基类](../../../docs/adr/0005-dashscope-async-provider-base.md)

## 组成

```
generation_controller.dart   编排：config 节点 → GenerationTask → JobQueue → 追踪 → 结果
models/job_state.dart        UI 状态机 JobState（sealed，ADR-0008）
providers/jobs_registry.dart 内存镜像 JobsRegistry（keepAlive + 淘汰上限）
providers/batch_results_controller.dart 批量/变体结果读侧（按 nodeId 分族）
services/prompt_assembler    prompt 拼装：base 前缀 + 泳道风格 + 关联文本 + 用户 prompt + base 后缀
services/cost_estimator      成本估算
services/toast_service       轻提示
widgets/job_queue_panel      队列面板 UI
```

## 核心流程（`GenerationController.submitFromConfigNode`）
1. 读 config 节点 `type_config`（prompt/provider_id/resolution/aspect_ratio/seed/negative_prompt/batch_size/duration/camera…）
2. 取 API Key（缺失 → `MissingApiKeyError`）；校验 provider 已注册
3. 组装 `fullPrompt`（`prompt_assembler`）+ 解析 data 入连线的参考图/首尾帧
4. **单事务**预建 result 节点 + `jobs` 表行（batch_size>1 时同事务预建 `batch_results` slot 占位行；任一失败整体回滚）
5. 组 `GenerationTask` → `JobQueueService.submit` → 拿 `JobHandle`
6. **fire-and-forget**：立即返回 jobId；后台 `_track` 监听 `handle.status` 推进 `JobsRegistry`（queued→running→succeeded/failed/cancelled），失败时 `softDelete` 孤儿 result
7. **批量写侧闭环**（batch_size>1）：JobQueue 注入 `BatchResultRepository?`，逐 slot 落终态（success→`output_url` / error→`error_code`），首张成功图作结果节点主图 `image_url`；**取消/失败保留已 success 的 slot**（部分成功拍板：≥1 成即 job success，见 ADR-0008 修订记录 / ARCHITECTURE §5.1）

## 两个状态模型（务必分清，ADR-0008）
- `JobStatus`（`core/models/job_status.dart`）：Provider 单次 poll 的**瞬时**结果
- `JobState`（本模块）：UI 端**完整状态机**，带 `sourceNodeId`（供 inspector 按节点回读进度）与 `resultNodeId`（供批量网格终态定点刷新）

## 消费者
- `widgets/job_queue_panel` 与 canvas 的 `canvas_render_queue` 都读 `jobsRegistryProvider`
- canvas 的 `node_active_job` / `inspector_status_panel` 用 `JobsRegistry.activeForSourceNode` 显示节点级进度
- canvas 的 `canvas_job_listener` 监听终态、按 `resultNodeId` 定点 `invalidate(batchResultsControllerProvider(nodeId))` 刷新批量网格

## 约束
- 批量仅对 image 节点生效；video 强制单张（`generation_controller` 解析 batch_size 时收口）
- 不 catch 泛型异常，只处理 `InkError` 子类 + `GenerationError`；文案经 l10n（ADR-0010）
