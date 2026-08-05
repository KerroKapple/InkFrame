# InkFrame Provider API 契约 v0.2.1

> **受众**：T3 Provider 层实现者（人类 + AI agents）
> **权威性**：PRD §10 的工程化落地；与 `docs/ARCHITECTURE.md` §3 / §4 同级强约束
> **冲突仲裁**：PRD §10 字段定义 > 本文 > 实现代码。本文与 `ARCHITECTURE.md` 冲突时以本文为准（本文更具体到签名级）

---

## 目录

1. [范围与非目标](#1-范围与非目标)
2. [接口拓扑（ISP 四接口）](#2-接口拓扑isp-四接口)
3. [ProviderCapabilities 能力声明](#3-providercapabilities-能力声明)
4. [CostModel 计费口径](#4-costmodel-计费口径)
5. [生命周期契约（submit / poll / cancel）](#5-生命周期契约submit--poll--cancel)
6. [错误契约（InkError ↔ 15 错误码）](#6-错误契约inkerror--15-错误码)
7. [限流契约（Per-Provider Token Bucket）](#7-限流契约per-provider-token-bucket)
8. [产物下载契约](#8-产物下载契约)
9. [已实现 Provider 差异矩阵](#9-已实现-provider-差异矩阵)
10. [实现 checklist（新增 Provider 的 9 步）](#10-实现-checklist新增-provider-的-9-步)
11. [文件结构与命名约定](#11-文件结构与命名约定)
12. [测试契约（FakeProvider / fixture）](#12-测试契约fakeprovider--fixture)
13. [自定义 Provider 扩展点](#13-自定义-provider-扩展点)
14. [反模式清单](#14-反模式清单)

---

## 1. 范围与非目标

**本文锁定**：

- `lib/providers/` 下所有具体 Provider 实现必须遵守的接口契约、生命周期、错误、限流、测试规范
- 当前已实现 9 款 Provider 的接入参数（真实模型 ID / Base URL / 鉴权 / 端点）——写死在各 provider 文件顶部 `const` 区
- Provider 层与 `JobQueueService`、`NodeGenerationService`、`FileResolverService` 的边界

**本文不讲**：

- JobQueueService 的调度算法细节（见 PRD §10.7）
- UI 内联面板如何根据 `ProviderCapabilities` 动态渲染（见 PRD §5 / §8）
- 密钥存储实现（见 `ARCHITECTURE.md` §9）

> **底层逻辑**：Provider 层是"把外部世界的不可靠性"封装到单一抽象之后的最后一道闸门。所有跨网络、跨模型、跨计费模式的差异都必须在这一层被吸收——向上只暴露统一的 `Submittable/Pollable/Cancellable`。

---

## 2. 接口拓扑（ISP 四接口）

定义位置：`lib/core/interfaces/generation_provider.dart`（纯 Dart，零 `dart:io` / 零 Flutter import）。

```dart
/// Provider 侧任务 ID（透传自 API 响应）。同步 Provider 允许 `local://` 前缀。
typedef JobId = String;

// 所有 Provider 必须实现：基础生成能力 + 静态能力声明
abstract class Submittable {
  /// 静态能力声明——const 字段，编译期固定。
  ProviderCapabilities get capabilities;

  /// 提交生成任务。成功返回 Provider 侧 task_id；同步 Provider（如 Gemini）
  /// 允许在 submit 内完成生成，但仍需返回稳定 JobId。
  /// 抛出：InkError 子类（经 DioException 映射后），禁止裸 Exception。
  Future<JobId> submit(GenerationTask task);
}

// 单次轮询查询。同步 Provider 也实现（ADR-0004，详见 §5.5）
abstract class Pollable {
  /// 单次轮询。实现方不要在内部 sleep/loop——退避由上层 JobQueueService 统一控制。
  Future<JobStatus> poll(JobId id);
}

// 仅当 ProviderCapabilities.supportsCancellation = true 时实现
abstract class Cancellable {
  /// 尽最大努力取消。返回 void——成功与否由下一次 poll 结果判定。
  /// 不可重试的错误（task_id 不存在、任务已完成）静默吞掉，不抛错。
  Future<void> cancel(JobId id);
}

// 必须实现——设置页 Key 验证依赖这个
abstract class KeyValidatable {
  /// 使用 Provider 最轻量的账户/配额查询接口，禁止消耗生成配额。
  /// 禁止调 submit 然后立即 cancel 作为"验证"。
  Future<KeyValidationResult> validateApiKey(String key);
}
```

> **已删除**：早期版本曾有第 5 个接口 `QuotaAware`（`Future<ProviderQuota> getQuota()`），已在 cleanup 阶段删除。配额展示功能属 ROADMAP；`lib/core/models/provider_quota.dart` 模型保留备用。

**实现侧组合规则（当前真实阵容）**：

| Provider | 实现组合 |
|---|---|
| 同步图片（gemini-image / openai-image / stability-image-core） | `Submittable` + `Pollable` + `KeyValidatable`（poll 走 inlineBytes cache，见 §5.5） |
| DashScope 异步系（wanx-* / kling-v3 / kling-v3-omni，共享基类 `DashScopeAsyncProviderBase`） | `Submittable` + `Pollable` + `KeyValidatable` |
| 自定义 OpenAI 兼容（`custom:*`，`OpenAICompatibleImageProvider` extends `SyncProviderBase`，见 §13） | 同步图片同款（inlineBytes cache） |

当前没有任何 Provider 实现 `Cancellable`（所有 capabilities 的 `supportsCancellation` 均为 false）——接口保留作为扩展点。

> **红线**：接口承诺但实现不了的方法，**必须拆接口，不准抛 `UnimplementedError`**（LSP）。

---

## 3. ProviderCapabilities 能力声明

**唯一事实源**：每个 Provider 实例必须暴露 `const ProviderCapabilities get capabilities`（定义见 `lib/core/models/provider_capabilities.dart`）。UI 内联面板、`JobQueueService`、生成控制器（提交前首尾帧能力校验，不支持即抛 `InvalidGenerationConfigError`）、画布入边区 role 门控（`NodeInputsSection`）都只通过这个字段决策。

```dart
@freezed
abstract class ProviderCapabilities with _$ProviderCapabilities {
  const factory ProviderCapabilities({
    required String providerId,            // 唯一标识，kebab-case
    required ProviderRegion region,        // cn / global
    required List<GenerationMode> modes,   // textToImage / imageToImage / textToVideo / imageToVideo
    required List<AspectRatio> supportedRatios,
    required List<Resolution> supportedResolutions,
    required List<int> supportedDurations, // 视频秒数；图片 = []
    required List<CameraMovement> supportedCameras,
    required int maxBatchSize,             // 视频固定 1
    required int maxRefImages,             // 不含 first/last frame
    required bool refImagesIncludeKeyframes,
    required bool supportsFirstFrame,
    required bool supportsLastFrame,
    required bool supportsNegativePrompt,
    required bool supportsSeed,
    required bool supportsSound,
    required bool supportsBatch,
    required bool supportsCancellation,
    required bool supportsPolling,         // 同步 Provider 也为 true（ADR-0004）
    required CostModel costModel,
    required int maxConcurrentJobs,        // per-provider 并发上限
    required int qps,                      // token bucket 补充速率
    required int burst,                    // token bucket 桶容量；默认 = qps
    Duration? pollInterval,                // null = 全局 3s
    Duration? pollTimeout,                 // null = 全局 30min
    String? displayName,                   // UI 显示名覆盖；自定义 Provider（§13）派生时必填
  }) = _ProviderCapabilities;
}
```

**硬约束**：

- `providerId` 全小写 kebab-case，与 §9.1 表对齐（`wanx-image` 不是 `WanxImage`）；自定义 Provider 恒为 `custom:<id>`（§13）
- 枚举值只能用 `AspectRatio` / `Resolution` / `CameraMovement` / `GenerationMode`，禁止字符串
- 内置 Provider 的 `capabilities` 必须是 `const` 字段；自定义 Provider（§13）从代码内 const 协议模板经 `copyWith(providerId, displayName)` 派生、实例化后不可变——两种形态都禁止能力位来自 .env / DB / 网络 / 用户自由填写

**UI fallback 规则**：`supportedRatios` 为空或不包含当前值 → 自动 fallback 到第一个支持值，**禁止抛错**。

---

## 4. CostModel 计费口径

定义见 `lib/core/models/cost_model.dart`：

```dart
@freezed
sealed class CostModel with _$CostModel {
  const factory CostModel.perCall({
    required double usdPerCall,
  }) = PerCall;

  const factory CostModel.perSecondVideo({
    required double usdPerSecondAt1080p,
    required Map<Resolution, double> resolutionMultiplier, // 720p=0.6, 2K=2.0
  }) = PerSecondVideo;

  const factory CostModel.perCharInput({
    required double usdPerKChar,
    required double usdPerImageOutput,
  }) = PerCharInput;
}
```

> **Planned**：成本预估函数 `estimateCost(GenerationTask, ProviderCapabilities)` 与 UI 成本展示尚未实现（见 `ROADMAP.md`）。届时约束：预估入口只有一个，禁止在 UI 层散拼；展示精度 USD 3 位小数 / CNY 2 位小数；中国区显示 `≈¥X.XX`；UI 文案明示"以 Provider 官方账单为准"。

---

## 5. 生命周期契约（submit / poll / cancel）

### 5.1 状态机（`jobs.status`）

```
pending ──► submitted ──► polling ──► success / error / timeout
   │              │           │
   └──────────────┴───────────┴────► cancelled
```

`jobs.status` 的末态**只有一个 `cancelled`**（schema CHECK 共 7 值：pending / submitted /
polling / success / error / cancelled / timeout，见 `lib/storage/schema/001_init.sql`）；
取消**原因**不是独立状态，由 `jobs.error_code` 区分 `cancelled_by_user` / `cancelled_on_exit`
（对齐 ARCHITECTURE.md §5.1）。

| 阶段 | 定义 | 谁负责推进 |
|---|---|---|
| `pending` | 已创建 result 节点，未提交 Provider，等待槽位 | JobQueueService |
| `submitted` | 已调 `submit()` 拿到 task_id | Provider.submit |
| `polling` | 进入轮询循环；每次 `poll()` 返回 inProgress 不改状态 | JobQueueService 驱动 |
| `success` | `poll()` 返回 success **且** 产物下载成功 | 下载阶段闭环后才写 |
| `error` | 任意阶段抛 `InkError` 且重试耗尽 | JobQueueService |
| `timeout` | 轮询超过 pollTimeout | JobQueueService |
| `cancelled` | 任意非终态被取消；`error_code=cancelled_by_user`（用户显式取消）或 `cancelled_on_exit`（app 启动对上次未结束 job 扫尾） | JobQueueService |

### 5.2 submit() 契约

- **幂等性**：Provider 层不保证幂等；幂等由 JobQueueService 的"同一 jobId 不二次入队"保证
- **同步 Provider**（Gemini）：`submit()` 内部完成 API 调用 + base64 解码 → 把 inline bytes 暂存进 instance-scoped cache → 返回 `local://` 前缀的合成 `JobId`。**仍必须 implements Pollable**（详见 §5.5 / ADR-0004）
- **返回前**：必须完成 token bucket `acquire()`；**不准**在 `acquire()` 前建立 HTTP 连接

### 5.3 poll() 契约

- **单次调用**：一次 HTTP 请求 → 一个 `JobStatus`；**禁止**在 `poll()` 内 loop
- **退避由上层**：`pollInitialInterval = 3s`, `pollBackoffMultiplier = 2.0`, `pollMaxInterval = 30s`（含随机 jitter）, `pollTimeout = 30min`——均为 `InMemoryJobQueueService` 构造参数默认值（见 `lib/services/job_queue_service.dart`），Provider 可经 `capabilities.pollInterval` / `capabilities.pollTimeout` 覆盖
- **阶段性信号**：`JobStatus.inProgress(progress: 0.0-1.0)` 允许；Provider 不返回进度就填 0
- **HTTP 细节**：网络错误转 `network_timeout` / `network_offline`；5xx 转 `provider_5xx`；429 转 `provider_busy`

### 5.4 cancel() 契约

- 调用前 JobQueueService 已经把 `jobs.status` 置为 `cancelled_by_user`——`cancel()` 只负责通知 Provider
- 不保证远端真的停止扣费；UI 文案必须明示"可能已产生部分费用"
- `cancel()` 失败（网络超时、task 已结束）**不抛错**，写 WARN 日志

### 5.5 同步 Provider 数据通道（ADR-0004）

`JobStatus.success` 字段：

| 字段 | 异步 Provider | 同步 Provider |
|---|---|---|
| `remoteUrls` | CDN 临时 URL 列表 | `[]` 空列表 |
| `urlExpiresAt` | URL 过期时间 | `null` |
| `inlineBytes` | `null` | `Uint8List` 列表（base64 解码后的图片字节） |

**同步 Provider 实现规则：**

- `submit()` 完成 API 调用后，把 inline bytes 写入 instance-scoped `Map<JobId, Uint8List>` cache，**不写盘**
- `implements Pollable` + `capabilities.supportsPolling = true`
- `poll(jobId)` 从 cache 取出 → **立即从 cache 删除**（一次性消费）→ 返回 `JobStatus.success(remoteUrls: [], inlineBytes: [bytes])`
- 重复 poll 同一 jobId 抛 `ProviderError(providerServer, reason='cache_miss_or_consumed')`
- submit 失败路径**不准**写 cache（避免泄漏）

**JobQueueService 消费规则：**

```dart
final s = await provider.poll(jobId);
if (s case JobSuccess(:final inlineBytes, :final remoteUrls)) {
  if (inlineBytes != null) {
    // 同步 Provider：本地落盘走 FileResolverService
  } else {
    // 异步 Provider：HTTP GET remoteUrls
  }
}
```

---

## 6. 错误契约（InkError ↔ 15 错误码）

**唯一事实源**：`lib/core/errors/ink_error.dart` 的 `sealed class InkError`。所有 Provider 抛出的错误必须是 `InkError` 子类，不得裸 `Exception`。

### 6.1 15 错误码映射

错误按域拆为 6 个 sealed 子类，code 经构造参数传入（子类构造器内 assert 限定合法 code 集合），而非每个 code 一个命名构造器：

| code (`InkErrorCode.wire`) | 实际构造方式 | 可重试 | 典型触发 |
|---|---|---|---|
| `invalid_key` | `ProviderError(code: InkErrorCode.invalidKey)` | ❌ | 401 / 403 / Key 撤销 |
| `insufficient_balance` | `ProviderError(code: InkErrorCode.insufficientBalance)` | ❌ | 402 |
| `content_policy` | `ProviderError(code: InkErrorCode.contentPolicy)` | ❌ | 审核拒绝 |
| `invalid_parameter` | `ProviderError(code: InkErrorCode.invalidParameter)` | ❌ | 比例/分辨率/时长不合法 |
| `provider_invalid_response` | `ProviderError(code: InkErrorCode.providerInvalidResponse)` | ❌ | 2xx 但响应体缺关键字段/结构不符（HI-04） |
| `provider_5xx` | `ProviderError(code: InkErrorCode.providerServer)` | ✅ | 5xx |
| `provider_busy` | `ProviderError(code: InkErrorCode.providerBusy)` | ✅ | 429 |
| `poll_timeout` | `ProviderError(code: InkErrorCode.pollTimeout)` | ❌ | 超 30min |
| `network_timeout` | `NetworkError(code: InkErrorCode.networkTimeout)` | ✅ | 连接/读写超时 |
| `network_offline` | `NetworkError(code: InkErrorCode.networkOffline)` | ✅ | 本机离线 / TLS |
| `download_failed` | `DownloadError()` | ✅ | 产物下载失败 |
| `local_io_error` | `LocalIOError()` | ❌ | 磁盘满/权限 |
| `cancelled_by_user` | `CancelledError.byUser()` | — | 用户取消 |
| `cancelled_on_exit` | `CancelledError.onExit()` | — | app 退出 |
| `unknown` | `UnknownError(cause: e)` | ❌ | 未分类（cause 必填） |

上下文（jobId / providerId / HTTP status / 字段名等）统一塞 `extra: Map<String, Object?>`，**禁止**含 API Key 等敏感值。

### 6.2 可重试白名单

```
network_timeout / network_offline / provider_5xx / provider_busy / download_failed
```

**其他一律不重试**。白名单的唯一事实源是 `lib/core/errors/ink_error.dart` 顶层 `_retryable` 表，消费侧只读 `InkError.retryable`，禁止散落 switch。

> **Planned**：JobQueueService 侧的自动重试调度（次数上限 + 指数退避）尚未实现（`job_queue_service.dart` 顶注 b3.1 明确「重试 / 续传未实现」）；当前可重试错误直接进 `error` 终态，由 UI "重试"按钮人工触发。

### 6.3 映射规则（HTTP → InkError）

统一映射函数是 `lib/providers/dio_error_mapper.dart` 的顶层 `mapDioError`——所有 Provider 在 HTTP 层之上必须调用它，禁止业务代码见到裸 `DioException`：

```dart
// lib/providers/dio_error_mapper.dart（真实签名）
InkError mapDioError(DioException e, {required String providerId});
```

映射规则（与实现一一对应）：

| DioExceptionType / HTTP status | 映射结果 |
|---|---|
| `connectionTimeout` / `sendTimeout` / `receiveTimeout` | `NetworkError(networkTimeout)` |
| `connectionError` | `NetworkError(networkOffline)` |
| `badCertificate` | `NetworkError(networkOffline, extra.reason='bad_certificate')` |
| `cancel` | `CancelledError.byUser()` |
| `unknown` | `UnknownError(cause: e)` |
| `badResponse` 401 / 403 | `ProviderError(invalidKey)` |
| `badResponse` 402 | `ProviderError(insufficientBalance)` |
| `badResponse` 429 | `ProviderError(providerBusy)` |
| `badResponse` ≥500 | `ProviderError(providerServer)` |
| `badResponse` 其他 | `ProviderError(invalidParameter, extra.body=响应体)` |

**异常：** Provider 自有业务错误码（如 DashScope `task_status = FAILED` 里的审核拒绝）必须在调 `mapDioError` 之前识别，优先于 HTTP status。

---

## 7. 限流契约（Per-Provider Token Bucket）

```dart
// lib/providers/rate_limiter.dart
class ProviderRateLimiter {
  ProviderRateLimiter({required this.qps, required this.burst});
  final int qps;
  final int burst;
  Future<void> acquire();   // 阻塞直到拿到 token
}
```

### 7.1 当前默认值（来自各 provider `capabilities`，唯一事实源）

| providerId | QPS | Burst |
|---|---|---|
| `gemini-image` | 2 | 10 |
| `openai-image` | 2 | 5 |
| `stability-image-core` | 1 | 3 |
| `wanx-image` | 1 | 2 |
| `wanx-t2v` / `wanx-i2v` / `wanx-r2v` | 1 | 2 |
| `kling-v3` / `kling-v3-omni` | 1 | 2 |

### 7.2 实现规则

- 每个 `provider_id` 独享一个 `ProviderRateLimiter` 实例，在 `lib/core/di/providers.dart` 内预先创建并由 factory 闭包共享（factory 每次 `get()` 新建 Provider 实例，但限流器必须共享，否则 token bucket 形同虚设）
- `acquire()` 撞限时**阻塞等待**，**不计入 `retry_count`**，**不抛错给用户**
- 日志 DEBUG 级记录等待时长：`{msg: "rate limit wait", provider: "wanx-image", wait_ms: 420}`
- `submit()` 必须在真正发 HTTP 前 `await acquire()`
- `poll()` 和 `cancel()` **不过** token bucket——轮询不消耗生成配额

---

## 8. 产物下载契约

生成成功后的 CDN URL 处理与生成流程**解耦**，由 `JobQueueService` 编排：远端 URL 经 `VideoDownloadService`（`lib/core/interfaces/video_download_service.dart`，实现 `lib/services/dio_video_download_service.dart`）落盘，同步 inlineBytes 经 `FileResolverService` 落盘——都不在 Provider 层做。

```
polling ─success─► downloading ──► local_ready (node.status = success)
                      │
                      └─ HTTP 失败 ─► node.status = error
                                     jobs.error_code = 'download_failed'
                                     jobs.parameters.remote_url 保留
                                     UI 提供"重试"入口
```

> **Planned**：下载失败的自动重试 + 断点续传尚未实现（`job_queue_service.dart` 顶注 b3.1 明确「重试 / 续传未实现」）。

**Provider 层**只需要：

1. `poll()` 返回 `JobStatus.success(remoteUrls: [...])` 带远端 URL
2. **禁止**在 `poll()` 内做下载——违反 SRP
3. 若 Provider 返回 URL 有效期，通过 `JobStatus.success(urlExpiresAt: ...)` 透传

---

## 9. 已实现 Provider 差异矩阵

> 唯一事实源是各 provider 文件顶部的 `const k*Capabilities`；本节只是速查快照，改 capabilities 时同 commit 更新这里。注册清单见 `lib/core/di/providers.dart`。未接入的 Provider（Jimeng / Hailuo / Kling 官方 API / DALL-E 3 等）一律见 `ROADMAP.md`，不在本表。自定义 Provider（`custom:*`）能力由 §13.2 协议模板派生，也不在本表。

### 9.1 接入参数（写死在各 provider 文件顶部 const 区）

| providerId | 真实模型 ID | Base URL | 鉴权 | 提交端点 | 轮询端点 |
|---|---|---|---|---|---|
| `gemini-image` | `gemini-2.5-flash-image-preview` | `https://generativelanguage.googleapis.com/v1beta` | `?key=` query | `POST /models/{model}:generateContent` | 同步（poll 走 inlineBytes cache） |
| `openai-image` | `gpt-image-2` | `https://api.openai.com/v1` | Bearer | `POST /images/generations` | 同步（同上） |
| `stability-image-core` | `stable-image-core`（v2beta） | `https://api.stability.ai` | Bearer | `POST /v2beta/stable-image/generate/core`（multipart） | 同步（同上）；Key 验证走 `GET /v1/user/balance` |
| `wanx-image` | `wan2.7-image-pro` | `https://dashscope.aliyuncs.com/api/v1` | Bearer + `X-DashScope-Async: enable` | `POST /services/aigc/image-generation/generation` | `GET /tasks/{task_id}` |
| `wanx-t2v` | `wan2.7-t2v` | 同上 | 同上 | `POST /services/aigc/video-generation/video-synthesis` | 同上 |
| `wanx-i2v` | `wan2.7-i2v` | 同上 | 同上 | 同上 | 同上 |
| `wanx-r2v` | `wan2.7-r2v` | 同上 | 同上 | 同上 | 同上 |
| `kling-v3` | `kling/kling-v3-video-generation` | 同上（DashScope 渠道） | 同上 | 同上 | 同上 |
| `kling-v3-omni` | `kling/kling-v3-omni-video-generation` | 同上（DashScope 渠道） | 同上 | 同上 | 同上 |

### 9.2 能力差异速查

| 能力 | gemini-image | openai-image | stability-image-core | wanx-image | wanx-t2v | wanx-i2v | wanx-r2v | kling-v3 | kling-v3-omni |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 模式 | T2I | T2I | T2I | T2I / I2I | T2V | I2V | T2V（参考图） | T2V / I2V | T2V（参考图） |
| 分辨率 | 1080p | 1080p | 1080p | 1080p | 720p / 1080p | 720p / 1080p | 720p / 1080p | 720p / 1080p | 720p / 1080p |
| 视频时长 | — | — | — | — | 5s / 10s | 5s / 10s | 5s / 10s | 5s / 10s | 5s / 10s |
| 参考图 | 0 | 0 | 0 | 1 | 0 | 0（首末帧） | 3 | 0（首帧） | 4 |
| 首帧 / 末帧 | — | — | — | — | — | ✅ / ✅ | — | ✅ / ❌ | — |
| 批量 | ❌ | ❌ | ❌ | ✅（≤4） | ❌ | ❌ | ❌ | ❌ | ❌ |
| 负向 prompt | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Seed | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| 取消 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 轮询 | ✅（同步 cache） | ✅（同步 cache） | ✅（同步 cache） | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| QPS / Burst | 2 / 10 | 2 / 5 | 1 / 3 | 1 / 2 | 1 / 2 | 1 / 2 | 1 / 2 | 1 / 2 | 1 / 2 |
| 并发 | 1 | 1 | 1 | 2 | 1 | 1 | 1 | 1 | 1 |

### 9.3 已知陷阱

- **同步三家（gemini / openai / stability）**：`submit()` 内完成生成，inline bytes 暂存 instance cache；`poll()` 一次性消费，重复 poll 同一 jobId 抛 `ProviderError(providerServer, extra.reason='cache_miss_or_consumed')`（§5.5）
- **openai-image**：`gpt-image-2`（MOD-1 2026-08-05 升级;gpt-image-1 2026-10-23 弃用）支持任意 WIDTHxHEIGHT（16 整除、比 ≤3:1、总像素 655,360~8,294,400）——本档三比例走真尺寸,`r4x3` / `r3x4` / `r21x9` 暂不声明（能力位编译期固定,扩比例另卡）
- **stability-image-core**：提交是 multipart/form-data，不是 JSON；Key 验证用余额端点（最轻量、零配额消耗）
- **DashScope 系 6 款**：共享基类 `DashScopeAsyncProviderBase` + 同一把 sk-xxx Key（SecureStorage 按 `provider.dashscope.api_key` 折叠存储，见 ARCHITECTURE.md §9.2）；提交必须带 `X-DashScope-Async: enable` 头；`task_status` 字面量见基类 `DashScopeTaskStatus`
- **wanx-image / wanx-r2v / kling-v3-omni**：参考图超上限（1 / 3 / 4）客户端按 `capabilities.maxRefImages` 静默截断，最终裁决交给服务端；UI 侧输入区超限时显示「多余参考图将被忽略」警告
- **wanx-i2v（wan2.7 契约）**：首末帧经 `input.media` 数组传递（`{type: first_frame|last_frame, url}`）；旧版 `img_url` / `last_frame_url` 已被服务端拒绝（`Field required: input.media`）。缺首帧在 `buildRequestBody` 阶段抛 `ProviderError(invalidParameter, extra.reason='missing_first_frame')` fail-fast，不发注定失败的请求
- **首尾帧能力位的消费链**：`supportsFirstFrame/LastFrame` 由画布入边区 role 下拉门控（`NodeInputsSection`）+ 生成控制器建行事务前校验（不支持即抛 `InvalidGenerationConfigError('first/last_frame_unsupported')`）双层强制；provider 层不做静默降级翻译

---

## 10. 实现 checklist（新增 Provider 的 9 步）

> **强制顺序**。跳步一律视为违反 DoD，CI 会在代码审查门禁阻断。

- [ ] **Step 1 · 能力声明先行**：在 `lib/providers/{id}_provider.dart` 顶部写 `const kCapabilities = ProviderCapabilities(...)`
- [ ] **Step 2 · 接入参数常量**：同文件顶部 `const kBaseUrl`, `const kSubmitPath`, `const kPollPath` 等，不准散落到别处
- [ ] **Step 3 · 选接口组合**：一律 `Submittable + Pollable + KeyValidatable`（同步 Provider 的 poll 走 inlineBytes cache，见 §5.5；支持取消再加 `Cancellable`）；DashScope 系直接 `extends DashScopeAsyncProviderBase`
- [ ] **Step 4 · 实现 `validateApiKey`**：用最轻量端点，禁止消耗生成配额
- [ ] **Step 5 · 实现 `submit`**：内置 `await rateLimiter.acquire()`，参数验证用 `capabilities` 字段
- [ ] **Step 6 · 实现 `poll`**：单次请求；退避参数不能覆盖全局默认（如需覆盖，改 `capabilities.pollInterval`）
- [ ] **Step 7 · 错误映射**：所有 `DioException` 经 `mapDioError(e, providerId: ...)`（`lib/providers/dio_error_mapper.dart`），所有业务错误码映射到 §6.1 全码表（15 码）
- [ ] **Step 8 · 注册到 DI**：`lib/core/di/providers.dart` 加 `provider_id → factory` 映射，`ProviderRegistry` 扫描生效
- [ ] **Step 9 · 测试三件套**：FakeProvider 单测 + 错误矩阵测试 + fixture 回放 E2E（见 §12）

**PR 审查清单**：

- [ ] `rg 'Color\(|fontSize:|FontWeight\.' lib/providers/{id}*` = 0（Provider 层不写 UI）
- [ ] `rg 'flutter/material\|flutter/widgets' lib/providers/{id}*` = 0（Service 及以下不 import Flutter）
- [ ] `rg 'throw Exception\|throw .*Error[^(]' lib/providers/{id}*` = 0（所有错误是 `InkError` 子类）
- [ ] `capabilities` 所有字段均显式设置，无 null 兜底
- [ ] i18n：所有面向用户的 `messageKey` 在 `app_en.arb` + `app_zh.arb` 已定义

---

## 11. 文件结构与命名约定

```
lib/
├── core/
│   ├── interfaces/
│   │   ├── generation_provider.dart       # 4 接口 + JobId typedef
│   │   └── custom_provider_source.dart    # 自定义 Provider 配置源契约（同步只读）
│   ├── models/
│   │   ├── provider_capabilities.dart     # freezed + 枚举（Region/Mode/Ratio/Resolution/Camera）
│   │   ├── cost_model.dart                # freezed sealed
│   │   ├── generation_task.dart           # freezed
│   │   ├── job_status.dart                # freezed sealed
│   │   ├── key_validation_result.dart     # freezed sealed
│   │   ├── custom_provider_config.dart    # freezed + json（自定义 Provider 配置条目，§13）
│   │   ├── provider_protocol_template.dart # 协议模板白名单 const + 派生函数（§13.2）
│   │   └── provider_quota.dart            # freezed（配额展示模型，暂无消费方）
│   └── errors/
│       └── ink_error.dart                 # sealed hierarchy + InkErrorCode 15 码
├── services/
│   └── custom_providers_file_service.dart # custom_providers.json 读取/校验/兜底（§13.1）
├── providers/
│   ├── provider_registry.dart             # id → factory
│   ├── rate_limiter.dart                  # Per-Provider Token Bucket
│   ├── dio_error_mapper.dart              # mapDioError：DioException → InkError
│   ├── sync_provider_base.dart            # 同步图片 Provider 共享基类（inlineBytes 通道）
│   ├── dashscope_async_provider_base.dart # DashScope 系 6 款共享基类
│   ├── gemini_image_provider.dart
│   ├── openai_image_provider.dart
│   ├── openai_compatible_provider.dart    # 自定义 OpenAI 兼容适配器（§13.3）
│   ├── stability_image_core_provider.dart
│   ├── wanx_image_provider.dart
│   ├── wanx_t2v_provider.dart
│   ├── wanx_i2v_provider.dart
│   ├── wanx_r2v_provider.dart
│   ├── kling_v3_provider.dart
│   └── kling_v3_omni_provider.dart
└── core/di/
    ├── providers.dart                     # Riverpod 接线（registry + 共享 RateLimiter + 能力合并源）
    └── custom_providers.dart              # customProviderSourceProvider（默认空，main 覆盖）
```

**命名**：

- 文件名 snake_case，`{provider}_{mode}_provider.dart`（`wanx_image_provider.dart`）
- 类名 PascalCase，`WanxImageProvider`
- `providerId` kebab-case，**与 §9.1 表字面对齐**（`kling-v3` 不是 `kling_v3`）

---

## 12. 测试契约（FakeProvider / fixture）

### 12.1 三层测试

| 层 | 目标 | 工具 | 门槛 |
|---|---|---|---|
| 单元测试 | 每个 provider 的错误映射、请求体构造、状态转换 | `flutter_test` + `http_mock_adapter` | 见 ARCHITECTURE.md §12 覆盖率门禁 |
| 契约测试 | 每个 Provider 对 `Submittable/Pollable/KeyValidatable` 契约合规 | 各 provider 测试文件内的 `ProviderContractSuite: {id}` group（如 `test/providers/openai_image_provider_test.dart`） | 100% 必过 |
| 回放测试 | 用固定 fixture 重放真实 API 响应 | `http_mock_adapter` + `test/fixtures/providers/{id}/` | 每家覆盖 submit 成功 + 至少一个失败场景 |

### 12.2 Fake 双件规范

测试替身集中在 `test/_harness/fake_providers.dart`：`FakeSubmittable` / `FakePollable` / `FakeKeyValidatable` 按单接口拆分，`FakeProvider` 组合三接口（可配置 poll 响应序列 / 注入 InkError）。

**硬约束**：

- 禁止在生产代码 (`lib/`) 里 import 任何 Fake——只能 `test/` 下
- 契约用例对每个真实 Provider 验证：
  - `submit()` → `JobId` 非空
  - `poll()` 直到 `success` / `failure` 的状态序列合法
  - 错误码在 §6.1 的 15 码白名单内
  - `validateApiKey()` 三种结果（valid / invalid / networkError）齐全

### 12.3 Fixture 目录（实际布局）

```
test/fixtures/providers/
├── gemini-image/
│   ├── models_list_success.json
│   ├── submit_success.json
│   ├── submit_invalid_key.json
│   └── submit_content_policy.json
├── wanx-image/
│   ├── submit_success.json
│   ├── poll_success.json
│   └── poll_failed_content_policy.json
├── wanx-t2v/ · wanx-i2v/ · wanx-r2v/ · kling-v3/ · kling-v3-omni/
└── ...
```

**采集方式**：真实 API 调用一次 → 脱敏（去 Key / jobId 替换为 `FIXTURE_JOB_ID`）→ 入库。禁止手写 fixture。

---

## 13. 自定义 Provider（BYO-key，OpenAI 兼容）

> **已落地（首切片）**。2026-07-02 拍板的唯一方案：**配置文件 + 协议白名单模板派生**。
> 本节与实现一一对齐；运行时增删 / 更多协议模板 / 设置页编辑 UI 是后续切片（见 ROADMAP / BOARD）。

### 13.1 配置文件

- 位置：`<数据根>/config/custom_providers.json`（`AppPaths.config`，与 `preferences.json` 同目录；
  数据根=Win `%LOCALAPPDATA%\InkFrame`、macOS `~/Library/Application Support/InkFrame`，DIR-1）
- 可手编 / 可分享（**Key 永不入此文件**，见 §13.4）
- 顶层是 JSON 数组；每条 5 个字段，全部必填非空字符串：

```json
[
  {
    "id": "my-openrouter",
    "display_name": "OpenRouter FLUX",
    "template": "openai-image",
    "base_url": "https://openrouter.ai/api/v1",
    "model_id": "black-forest-labs/flux-1.1-pro"
  }
]
```

| 字段 | 约束 |
|---|---|
| `id` | `^[A-Za-z0-9][A-Za-z0-9_-]*$`，文件内唯一；providerId 恒为 `custom:<id>` |
| `display_name` | 非空；inspector 下拉显示名（设置页 API Keys 行当前显示原始 `custom:<id>`，接入 displayName 属下一切片设置页 UI） |
| `template` | §13.2 白名单之一 |
| `base_url` | 绝对 http(s) URL，**不得含 query/fragment/userinfo**（Dio baseUrl 为字符串拼接，带 query 必产坏请求）；尾部 `/` 解析时剔除 |
| `model_id` | 非空；透传为请求体 `model` 字段 |

**校验与损坏兜底**（`lib/services/custom_providers_file_service.dart`，模型 `lib/core/models/custom_provider_config.dart`）：

- 文件缺失 → 空列表（静默，不算错误）
- 文件不可读 / JSON 损坏 / 顶层不是数组 → 空列表 + WARN 日志（`module=custom_providers`），**不崩、不阻断启动**
- 单条非法（非对象、字段缺失或空、`id` 不合法/重复/与内置 providerId 冲突、未知 `template`、`base_url` 非法）→ 仅剔除该条 + WARN（含 index 与 reason），其余条目照常生效

### 13.2 协议模板白名单（代码内 const）

模板 = 一份 const `ProviderCapabilities` 能力基线，定义在 `lib/core/models/provider_protocol_template.dart` 的 `kProviderProtocolTemplates`。用户**只选模板 + 填实例化参数**（`base_url` / `model_id` / `display_name`），**不自由填能力位**。派生规则（`deriveCustomProviderCapabilities`）：

```
capabilities = 模板基线.copyWith(providerId: 'custom:<id>', displayName: display_name)
```

| template | 适配器 | 能力基线（保守） |
|---|---|---|
| `openai-image` | `OpenAICompatibleImageProvider`（`lib/providers/openai_compatible_provider.dart`，extends `SyncProviderBase`） | textToImage；比例 1:1 / 16:9 / 9:16；1080p；maxBatchSize 1；maxRefImages 0；无 seed / 负向 / 批量 / 取消；qps 1 / burst 2 / 并发 1；costModel `perCall(0)`（计费未知按零估） |

**禁止**运行时自由下发能力位（安全边界，§14-6）。加新模板 = 改代码 + 发版。候选模板（未实现，勿在配置中使用）：`openai-chat-image`、`gemini-compatible`。

### 13.3 协议接入点（`openai-image` 模板）

| 动作 | 请求 |
|---|---|
| 生成 | `POST {base_url}/images/generations`，JSON body `{model, prompt, n: 1, size, response_format: "b64_json"}`，`Authorization: Bearer <key>` |
| Key 验证 | `GET {base_url}/models`（零生成配额） |

- 结果走同步 inlineBytes 通道（§5.5 / ADR-0004）：解析 `data[0].b64_json`，poll 一次性消费；**基类禁止在 Provider 内下载远端 URL**，故请求体显式要求 `b64_json`
- `size` 由 AspectRatio 映射（gpt-image-2 真比例）：1:1→`1024x1024`，16:9→`1536x864`，9:16→`864x1536`
- 错误映射与内置同步 Provider 完全一致（`mapDioError` + §6.1 全码表）

### 13.4 Key 存储

复用 `SecureStorageKeys.providerApiKey('custom:<id>')` → `provider.custom:<id>.api_key`（`scopeOf` 对未登记家族回退 providerId 本身）。设置页 API Keys 分节按 capabilities 列表自动多出一行；生成链路 key 校验 / inspector 门控 / Studio banner **零改动生效**。

### 13.5 生效时机（本切片：启动期一次性注册）

- `main()` 在构建 ProviderContainer 前完成 `CustomProvidersFileService.load()`（对齐 `FilePreferencesService` 的 bootstrap 模式），经 `customProviderSourceProvider`（`lib/core/di/custom_providers.dart`，默认空实现）overrideWithValue 注入
- `providerRegistryProvider` 构建时把 custom factory 并入内置映射（每个 providerId 一个 `ProviderRateLimiter`，dispose 挂 container 生命周期，同内置样板）；`providerCapabilitiesListProvider` 同步合并（custom 为空时原样返回内置 const 列表）——保持**同步可读**（image inspector 在 initState 里 `ref.read`）
- **会话内不变**：改 json 须重启生效。`providerRegistryProvider` 禁止 invalidate（JobQueue 连锁重建会把运行中任务打成 cancelled）；运行时增删是下一切片（须走 registry 变异 + 旧实例驱逐，而非 invalidate）

---

## 14. 反模式清单

> 以下任意一条出现在 PR 中，直接 block 合流。

1. ❌ 在 Widget 里 `import 'package:inkframe/providers/kling_v3_provider.dart'`
   → 应通过 `ref.watch(providerRegistryProvider).get('kling-v3')` 拿接口

2. ❌ Provider 实现类里 `throw Exception('invalid key')`
   → 应 `throw ProviderError(code: InkErrorCode.invalidKey)`

3. ❌ `poll()` 内部循环直到 success
   → 一次调用一次请求，退避由 JobQueueService

4. ❌ 接入参数散落：`final baseUrl = context.read(...)`
   → 必须 `const kBaseUrl = 'https://...'` 在文件顶部

5. ❌ `validateApiKey` 内调 `submit()` 做"验证"
   → 消耗用户配额，用户会投诉

6. ❌ 能力位运行时自由下发（`.env` / DB / 网络 / 配置文件里直接写能力位）
   → 内置 Provider 的 `capabilities` 必须 `const`；自定义 Provider 只能从代码内 const 协议模板派生（§13.2），
     用户配置仅提供实例化参数（`base_url` / `model_id` / `display_name`），不含任何能力位

7. ❌ 在 `submit()` 里 `await Future.delayed(Duration(seconds: 3))` 模拟退避
   → 退避是 JobQueueService 的职责

8. ❌ 同 providerId 出现两个实现类
   → registry 映射在 `lib/core/di/providers.dart` 集中接线，map key 冲突在 review / 编译期暴露；新增 Provider 不准绕开这张表

9. ❌ Provider 返回 `Map<String, dynamic>` 代替 `JobStatus`
   → 强类型接口，所有边界都是 freezed

10. ❌ `cancel()` 抛错中断 UI
    → 必须 swallow + 写 WARN 日志

---

## 变更记录

| 日期 | 版本 | 内容 | 作者 |
|---|---|---|---|
| 2026-04-15 | v0.1.0 | 初版。对齐 PRD §10 + ARCHITECTURE §3 | P9 |
| 2026-06-12 | v0.1.1 | 对齐真实代码：QuotaAware 删除（四接口）；§6 错误契约改为真实 sealed 子类 + `mapDioError` 签名；§9 矩阵替换为已实现 9 款；estimateCost / 自定义 Provider 标 Planned；§11/§12 文件与测试布局对齐 repo | FIX-019 |
| 2026-07-03 | v0.2.0 | §13 重写为唯一已落地方案（custom_providers.json + 协议模板派生 + 启动期一次性注册）；§3 硬约束与 §14-6 反模式收敛为"能力位禁止运行时自由下发"（模板派生合法）；§2/§9/§11 补自定义 Provider 条目。对应 ADR-0009 2026-07-02 修订 | M3 首切片 |
| 2026-07-06 | v0.2.1 | §6 错误码 14→15（补 `provider_invalid_response`，HI-04）；§3 snippet 补 `displayName` + 消费方清单补生成控制器/入边区门控；§9.3 补 wanx-image 截断、wanx-i2v wan2.7 `input.media` 契约与缺首帧 fail-fast、首尾帧能力位双层强制（对应 PR #137/#138）；标题版本号对齐变更记录 | 文档清欠 |
