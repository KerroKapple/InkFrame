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
4. **单事务**预建 result 节点 + `jobs` 表行（任一失败整体回滚）
5. 组 `GenerationTask` → `JobQueueService.submit` → 拿 `JobHandle`
6. **fire-and-forget**：立即返回 jobId；后台 `_track` 监听 `handle.status` 推进 `JobsRegistry`（queued→running→succeeded/failed/cancelled），失败时 `softDelete` 孤儿 result

## 两个状态模型（务必分清，ADR-0008）
- `JobStatus`（`core/models/job_status.dart`）：Provider 单次 poll 的**瞬时**结果
- `JobState`（本模块）：UI 端**完整状态机**，带 `sourceNodeId`（供 inspector 按节点回读进度）

## 消费者
- `widgets/job_queue_panel` 与 canvas 的 `canvas_render_queue` 都读 `jobsRegistryProvider`
- canvas 的 `node_active_job` / `inspector_status_panel` 用 `JobsRegistry.activeForSourceNode` 显示节点级进度

## 约束
- 不 catch 泛型异常，只处理 `InkError` 子类 + `GenerationError`；文案经 l10n（ADR-0010）
