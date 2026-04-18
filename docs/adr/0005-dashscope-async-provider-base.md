# ADR-0005: DashScope 异步 Provider 公共基类

- **Status**: accepted
- **Date**: 2026-04-18
- **Deciders**: P9 (Tech Lead)
- **Related**: PROVIDER-API.md §5 / ADR-0004 / PRD §10.2

---

## Context

阿里百炼 DashScope 平台同一 sk-xxx Key 可访问 6 个 Provider，全部走异步框架：

| Provider | 用途 | endpoint | model id |
|---|---|---|---|
| Wanx Image | 文生图 / 编辑 / 组图 | `/services/aigc/image-generation/generation` | `wan2.7-image-pro` `wan2.7-image` |
| Wanx T2V | 文生视频 | `/services/aigc/video-generation/video-synthesis` | `wan2.7-t2v` |
| Wanx I2V | 图生视频 | 同上 | `wan2.7-i2v` |
| Wanx R2V | 参考生视频 | 同上 | `wan2.7-r2v` |
| Kling v3 | 文生/图生/参考生视频 | 同上 | `kling/kling-v3-video-generation` |
| Kling v3 Omni | 多素材参考生视频 | 同上 | `kling/kling-v3-omni-video-generation` |

**所有 6 个共享：**
- Auth：`Authorization: Bearer sk-xxx` + `X-DashScope-Async: enable`
- 提交响应：`{output: {task_id, task_status: PENDING}}`
- 轮询接口：`GET /api/v1/tasks/{task_id}`
- 状态机：PENDING → RUNNING → SUCCEEDED / FAILED / CANCELED / UNKNOWN
- 错误码：InvalidApiKey / InvalidParameter / IPInfringementSuspect

**差异点：**
- POST endpoint path（image-generation vs video-generation）
- 请求 body 结构（`input.messages` vs `input.prompt`）
- 成功响应字段（`output.choices[].message.content[].image` vs `output.video_url`）

## Decision

抽出 `DashScopeAsyncProviderBase`：

```dart
abstract class DashScopeAsyncProviderBase implements Submittable, Pollable, KeyValidatable {
  // 子类提供
  String get submitEndpoint;          // POST 路径
  ProviderCapabilities get capabilities;
  Map<String, Object?> buildRequestBody(GenerationTask task);
  JobStatus parseSuccessOutput(Map<String, Object?> output);  // → success(remoteUrls=[...])

  // 基类负责（公共）
  Future<JobId> submit(GenerationTask task);   // POST + X-DashScope-Async + Bearer + 解析 task_id
  Future<JobStatus> poll(JobId taskId);        // GET /tasks/{id} + 状态机映射
  Future<KeyValidationResult> validateApiKey(String key);  // 通用：尝试 GET /tasks/<bogus>，401=invalid / 404=valid
}
```

**通用 poll 状态机映射**：
- PENDING / RUNNING → `JobStatus.inProgress(progress: 0)`
- SUCCEEDED → 调子类 `parseSuccessOutput()`
- FAILED → `JobStatus.failure(InkError)`，按 code 字段映射 InkErrorCode
- CANCELED → `JobStatus.failure(CancelledError.byUser)`
- UNKNOWN → `JobStatus.failure(ProviderError(providerServer))`（task_id 24h 过期）

## Alternatives

| 方案 | 否定原因 |
|---|---|
| A. 每个 Provider 独立写 submit+poll | 6 倍重复代码 + 状态机映射散落 6 处 |
| B. 用 DashScope 官方 Python SDK | Flutter/Dart 没官方 SDK |
| C. 把基类做成 mixin | mixin 不能持有 dio 字段，状态难管理 |

## Consequences

**收益：**
- 6 个 Provider 共享 ~150 行公共代码（auth / submit / poll / 状态机）
- 子类只需 ~80 行：endpoint + buildBody + parseOutput
- 用户 1 个 sk 解锁 6 个 Provider（设置页极简）
- DashScope 加新模型时：新 Provider = 子类继承 + 30 分钟接入

**代价：**
- ⚠️ 基类承担状态机翻译职责，将来 DashScope 改协议时 6 个 Provider 同时受影响
- ⚠️ Kling 模型 ID 含 `/`（`kling/kling-v3-...`）—— 注意 ProviderId 命名规范要兼容
- ⚠️ 缓解：基类内部逻辑保持极简，复杂参数解析下沉到子类的 buildRequestBody

## 影响文件

- `lib/providers/dashscope_async_provider_base.dart`（新基类）
- `lib/providers/wanx_image_provider.dart`（PR #2）
- `lib/providers/wanx_t2v_provider.dart`（PR #6）
- `lib/providers/wanx_i2v_provider.dart`（PR #7）
- `lib/providers/wanx_r2v_provider.dart`（PR #7）
- `lib/providers/kling_v3_provider.dart`（PR #8）
- `lib/providers/kling_v3_omni_provider.dart`（PR #8）
- `docs/PROVIDER-API.md` §10 加 DashScope 章节
- `docs/specs/2026-04-11-inkframe-v0.1.0-prd.md` §10.2 P0 列表更新为阿里全家桶
