# InkFrame Provider API 契约 v0.1.0

> **受众**：T3 Provider 层实现者（人类 + AI agents）
> **权威性**：PRD §10 的工程化落地；与 `docs/ARCHITECTURE.md` §3 / §4 同级强约束
> **冲突仲裁**：PRD §10 字段定义 > 本文 > 实现代码。本文与 `ARCHITECTURE.md` 冲突时以本文为准（本文更具体到签名级）

---

## 目录

1. [范围与非目标](#1-范围与非目标)
2. [接口拓扑（ISP 五接口）](#2-接口拓扑isp-五接口)
3. [ProviderCapabilities 能力声明](#3-providercapabilities-能力声明)
4. [CostModel 计费口径](#4-costmodel-计费口径)
5. [生命周期契约（submit / poll / cancel）](#5-生命周期契约submit--poll--cancel)
6. [错误契约（InkError ↔ 14 错误码）](#6-错误契约inkerror--14-错误码)
7. [限流契约（Per-Provider Token Bucket）](#7-限流契约per-provider-token-bucket)
8. [产物下载契约](#8-产物下载契约)
9. [P0 Provider 差异矩阵](#9-p0-provider-差异矩阵)
10. [实现 checklist（新增 Provider 的 9 步）](#10-实现-checklist新增-provider-的-9-步)
11. [文件结构与命名约定](#11-文件结构与命名约定)
12. [测试契约（FakeProvider / fixture）](#12-测试契约fakeprovider--fixture)
13. [自定义 Provider 扩展点](#13-自定义-provider-扩展点)
14. [反模式清单](#14-反模式清单)

---

## 1. 范围与非目标

**本文锁定**：

- `lib/providers/` 下所有具体 Provider 实现必须遵守的接口契约、生命周期、错误、限流、测试规范
- P0 五家 Provider 的接入参数（真实模型 ID / Base URL / 鉴权 / 端点）——写死在各 provider 文件顶部 `const` 区
- Provider 层与 `JobQueueService`、`NodeGenerationService`、`FileResolverService` 的边界

**本文不讲**：

- JobQueueService 的调度算法细节（见 PRD §10.7）
- UI 内联面板如何根据 `ProviderCapabilities` 动态渲染（见 PRD §5 / §8）
- 密钥存储实现（见 `ARCHITECTURE.md` §9）

> **底层逻辑**：Provider 层是"把外部世界的不可靠性"封装到单一抽象之后的最后一道闸门。所有跨网络、跨模型、跨计费模式的差异都必须在这一层被吸收——向上只暴露统一的 `Submittable/Pollable/Cancellable`。

---

## 2. 接口拓扑（ISP 五接口）

定义位置：`lib/core/interfaces/generation_provider.dart`（纯 Dart，零 `dart:io` / 零 Flutter import）。

```dart
// 最小生成能力
abstract class Submittable {
  /// 提交生成任务。成功返回 Provider 侧 task_id；同步 Provider（如 Gemini）
  /// 允许在 submit 内完成生成，但仍需返回稳定 JobId。
  /// 抛出：[ProviderError]（永远是 InkError 子类，禁止裸 Exception）。
  Future<JobId> submit(GenerationTask task);
}

// 异步 Provider 必须实现；同步 Provider（Gemini）可跳过——由 JobQueueService 检测
abstract class Pollable {
  /// 单次轮询。实现方不要在内部 sleep/loop——退避由上层 JobQueueService 统一控制。
  /// 返回 JobStatus.inProgress / JobStatus.success / JobStatus.failure。
  Future<JobStatus> poll(JobId id);
}

// 仅当 ProviderCapabilities.supportsCancellation = true 时实现
abstract class Cancellable {
  /// 尽最大努力取消。返回 void——成功与否由下一次 poll 结果判定。
  /// 不可重试的错误（task_id 不存在、任务已完成）静默吞掉，不抛错。
  Future<void> cancel(JobId id);
}

// 可选：用于任务中心/设置页展示
abstract class QuotaAware {
  Future<ProviderQuota> getQuota();
}

// 必须实现——设置页 Key 验证依赖这个
abstract class KeyValidatable {
  /// 使用 Provider 最轻量的账户/配额查询接口，禁止消耗生成配额。
  /// 禁止调 submit 然后立即 cancel 作为"验证"。
  Future<KeyValidationResult> validateApiKey(String key);
}
```

**实现侧组合规则**：

| Provider | 必实现 | 选实现 |
|---|---|---|
| 异步 Provider（Kling / Jimeng / Hailuo） | `Submittable` + `Pollable` + `KeyValidatable` | `Cancellable` + `QuotaAware` |
| 同步 Provider（Gemini） | `Submittable` + `KeyValidatable` | — |

> **红线**：接口承诺但实现不了的方法，**必须拆接口，不准抛 `UnimplementedError`**（LSP）。

---

## 3. ProviderCapabilities 能力声明

**唯一事实源**：每个 Provider 实例必须暴露 `const ProviderCapabilities get capabilities`。UI 内联面板、`JobQueueService`、`estimateCost()` 都只通过这个字段决策。

```dart
@freezed
class ProviderCapabilities with _$ProviderCapabilities {
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
    required CostModel costModel,
    required int maxConcurrentJobs,        // per-provider 并发上限
    required int qps,                      // token bucket 补充速率
    required int burst,                    // token bucket 桶容量；默认 = qps
    Duration? pollInterval,                // null = 全局 3s
    Duration? pollTimeout,                 // null = 全局 30min
  }) = _ProviderCapabilities;
}
```

**硬约束**：

- `providerId` 全小写 kebab-case，与 PRD §10.2 表对齐（`kling-image` 不是 `KlingImage`）
- 枚举值只能用 `AspectRatio` / `Resolution` / `CameraMovement` / `GenerationMode`，禁止字符串
- `capabilities` 必须是 `const` 字段；禁止运行时构造、禁止从配置文件/网络下发

**UI fallback 规则**：`supportedRatios` 为空或不包含当前值 → 自动 fallback 到第一个支持值，**禁止抛错**。

---

## 4. CostModel 计费口径

```dart
@freezed
sealed class CostModel with _$CostModel {
  const factory CostModel.perCall({
    required double usdPerCall,
  }) = _PerCall;

  const factory CostModel.perSecondVideo({
    required double usdPerSecondAt1080p,
    required Map<Resolution, double> resolutionMultiplier, // 720p=0.6, 2K=2.0
  }) = _PerSecond;

  const factory CostModel.perCharInput({
    required double usdPerKChar,
    required double usdPerImageOutput,
  }) = _PerChar;
}

double estimateCost(GenerationTask task, ProviderCapabilities caps);
```

- 预估入口**只有** `estimateCost()` 一个——禁止在 UI 层散拼
- 展示精度：USD 保留 3 位小数，CNY 保留 2 位小数
- 中国区 Provider UI 显示 `≈¥X.XX`（汇率 7.2，可在设置覆盖）
- 预估不准确不影响业务流；UI 文案明示"以 Provider 官方账单为准"

---

## 5. 生命周期契约（submit / poll / cancel）

### 5.1 状态机（`jobs.status`）

```
pending ──► submitted ──► polling ──► success / error / timeout
   │                                         │
   └── cancelled_by_user                     │
                                             │
  任何阶段 ──► cancelled_on_exit  ◄──────────┘
```

| 阶段 | 定义 | 谁负责推进 |
|---|---|---|
| `pending` | 已创建 result 节点，未提交 Provider，等待槽位 | JobQueueService |
| `submitted` | 已调 `submit()` 拿到 task_id | Provider.submit |
| `polling` | 进入轮询循环；每次 `poll()` 返回 inProgress 不改状态 | JobQueueService 驱动 |
| `success` | `poll()` 返回 success **且** 产物下载成功 | 下载阶段闭环后才写 |
| `error` | 任意阶段抛 `InkError` 且重试耗尽 | JobQueueService |
| `cancelled_by_user` | 用户显式取消（队列中 or 进行中） | JobQueueService |
| `cancelled_on_exit` | app 退出时 graceful 取消 | 应用层 shutdown |

### 5.2 submit() 契约

- **幂等性**：Provider 层不保证幂等；幂等由 JobQueueService 的"同一 jobId 不二次入队"保证
- **同步 Provider**（Gemini）：`submit()` 内部完成 API 调用 + base64 解码 → 把 inline bytes 暂存进 instance-scoped cache → 返回 `local://` 前缀的合成 `JobId`。**仍必须 implements Pollable**（详见 §5.5 / ADR-0004）
- **返回前**：必须完成 token bucket `acquire()`；**不准**在 `acquire()` 前建立 HTTP 连接

### 5.3 poll() 契约

- **单次调用**：一次 HTTP 请求 → 一个 `JobStatus`；**禁止**在 `poll()` 内 loop
- **退避由上层**：`kPollInitialInterval = 3s`, `kPollBackoffMultiplier = 2.0`, `kPollMaxInterval = 30s`, `kPollJitter = ±20%`, `kPollTimeout = 30min`（见 `lib/core/constants/network.dart`）
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

## 6. 错误契约（InkError ↔ 14 错误码）

**唯一事实源**：`lib/core/errors/ink_error.dart` 的 `sealed class InkError`。所有 Provider 抛出的错误必须是 `InkError` 子类，不得裸 `Exception`。

### 6.1 14 错误码映射

| code | Dart 构造器 | 可重试 | 典型触发 |
|---|---|---|---|
| `invalid_key` | `ProviderError.invalidKey()` | ❌ | 401 / Key 撤销 |
| `insufficient_balance` | `ProviderError.insufficientBalance()` | ❌ | 402 |
| `content_policy` | `ProviderError.contentPolicy(detail)` | ❌ | 审核拒绝 |
| `invalid_parameter` | `ProviderError.invalidParameter(field)` | ❌ | 比例/分辨率/时长不合法 |
| `network_timeout` | `ProviderError.networkTimeout(jobId)` | ✅ | 连接/读写超时 |
| `network_offline` | `ProviderError.networkOffline()` | ✅ | 本机离线 |
| `provider_5xx` | `ProviderError.providerServer(status)` | ✅ | 5xx |
| `provider_busy` | `ProviderError.providerBusy(retryAfter)` | ✅ | 429 |
| `poll_timeout` | `ProviderError.pollTimeout(jobId)` | ❌ | 超 30min |
| `download_failed` | `ProviderError.downloadFailed(url)` | ✅ | 产物下载失败 |
| `local_io_error` | `StorageError.localIo(path)` | ❌ | 磁盘满/权限 |
| `cancelled_by_user` | `ProviderError.cancelledByUser()` | — | 用户取消 |
| `cancelled_on_exit` | `ProviderError.cancelledOnExit()` | — | app 退出 |
| `unknown` | `ProviderError.unknown(cause)` | ❌ | 未分类（必写日志） |

### 6.2 可重试白名单

```
network_timeout / network_offline / provider_5xx / provider_busy / download_failed
```

**其他一律不重试**。`kMaxRetries = 3`，指数退避 `3s / 9s / 27s`。

### 6.3 映射规则（HTTP → InkError）

Provider 实现**必须**在 HTTP 层之上一层做统一映射，禁止业务代码见到裸 `DioException`：

```dart
InkError _mapDioError(DioException e, {required String jobId}) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return ProviderError.networkTimeout(jobId: jobId);
    case DioExceptionType.connectionError:
      return ProviderError.networkOffline();
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode ?? 0;
      if (code == 401) return ProviderError.invalidKey();
      if (code == 402) return ProviderError.insufficientBalance();
      if (code == 429) return ProviderError.providerBusy(
        retryAfter: _parseRetryAfter(e.response),
      );
      if (code >= 500) return ProviderError.providerServer(status: code);
      return ProviderError.invalidParameter(field: _parseErrField(e.response));
    default:
      return ProviderError.unknown(cause: e);
  }
}
```

**异常：** Provider 自有错误码（如 Kling 的 `content_review_fail`）必须在映射前识别，优先于 HTTP status。

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

### 7.1 P0 默认值

| Provider | QPS | Burst |
|---|---|---|
| Gemini | 2 | 10 |
| Kling Image / Kling 3.0 | 2 | 5 |
| Hailuo 2.3 | 2 | 5 |
| Jimeng 4.5 | 1 | 3 |

### 7.2 实现规则

- 每个 `provider_id` 独立实例，由 Riverpod `keepAlive` provider 持有
- `acquire()` 撞限时**阻塞等待**，**不计入 `retry_count`**，**不抛错给用户**
- 日志 DEBUG 级记录等待时长：`{msg: "rate limit wait", provider: "kling-image", wait_ms: 420}`
- `submit()` 必须在真正发 HTTP 前 `await acquire()`
- `poll()` 和 `cancel()` **不过** token bucket——轮询不消耗生成配额

---

## 8. 产物下载契约

生成成功后的 CDN URL 处理与生成流程**解耦**，归属 `AssetDownloadService`，不在 Provider 层做。

```
polling ─success─► downloading ──► local_ready (node.status = success)
                      │
                      ├─ HTTP 失败 ─► retry (3s/9s/27s × 3)
                      │
                      └─ 重试耗尽 ─► node.status = error
                                     jobs.error_code = 'download_failed'
                                     jobs.parameters.remote_url 保留
                                     UI 提供"重新下载"按钮
```

**Provider 层**只需要：

1. `poll()` 返回 `JobStatus.success(remoteUrls: [...])` 带远端 URL
2. **禁止**在 `poll()` 内做下载——违反 SRP
3. 若 Provider 返回 URL 有效期，通过 `JobStatus.success(urlExpiresAt: ...)` 透传

---

## 9. P0 Provider 差异矩阵

### 9.1 接入参数（写死在各 provider 文件顶部 const 区）

| providerId | 真实模型 ID | Base URL | 鉴权 | 提交端点 | 轮询端点 | 阶段 |
|---|---|---|---|---|---|---|
| `gemini-image` | `gemini-2.5-flash-image-preview` | `https://generativelanguage.googleapis.com/v1beta` | `?key=` query | `POST /models/{model}:generateContent` | 同步，无轮询 | P0-Alpha |
| `jimeng-4.5` | `jimeng-4.5` | `https://visual.volcengineapi.com` | HMAC-SHA256 签名 | `POST /?Action=CVSync2AsyncSubmitTask` | `POST /?Action=CVSync2AsyncGetResult` | P0-Beta |
| `kling-image` | `kling-v1` | `https://api.klingai.com` | JWT Bearer | `POST /v1/images/generations` | `GET /v1/images/generations/{task_id}` | P0-Beta |
| `kling-3.0` | `kling-v1-6` | 同上 | 同上 | `POST /v1/videos/text2video` / `/v1/videos/image2video` | `GET /v1/videos/text2video/{task_id}` | P0-Beta |
| `hailuo-2.3` | `MiniMax-Hailuo-02` | `https://api.minimax.chat` | Bearer + GroupId | `POST /v1/video_generation` | `GET /v1/query/video_generation?task_id=` | P0-Beta |

### 9.2 能力差异速查

| 能力 | gemini-image | jimeng-4.5 | kling-image | kling-3.0 | hailuo-2.3 |
|---|:-:|:-:|:-:|:-:|:-:|
| 模式 | T2I | T2I | T2I / I2I | T2V / I2V | T2V / I2V |
| 分辨率 | 1080p | 1080p / 2K | 1080p | 1080p | 720p / 1080p |
| 视频时长 | — | — | — | 5s / 10s | 4s / 8s |
| 运镜 | — | — | — | ✅ | 有限 |
| 参考图 | 0 | 1 | 1 | — | — |
| 批量 | ❌ | ❌ | ❌ | ❌ | ❌ |
| 负向 prompt | ❌ | ✅ | ✅ | ✅ | ✅ |
| Seed | ✅ | ✅ | ✅ | ❌ | ❌ |
| 取消 | N/A（同步） | ❌ | ✅ | ✅ | ❌ |
| 轮询 | ❌（同步） | ✅ | ✅ | ✅ | ✅ |
| QPS / Burst | 2 / 10 | 1 / 3 | 2 / 5 | 2 / 5 | 2 / 5 |
| 并发 | 1 | 2 | 2 | 2 | 2 |

### 9.3 已知陷阱

- **Gemini**：同步返回，`polling` 状态直接跳过；但 `submitted → success` 必须经过一次状态写入（JobQueueService 兼容此路径）
- **Jimeng**：HMAC 签名需要 `Timestamp` + `Nonce`，签名错误会被当作 `invalid_key`——签名代码**禁止**散落在各 provider，统一放 `lib/providers/auth/volc_signer.dart`
- **Kling**：JWT Token 有效期 30 分钟；Provider 层自己续签，不暴露到上层
- **Hailuo**：`GroupId` 不是 Key 的一部分，单独在设置页存；验证 Key 时两个都要传

---

## 10. 实现 checklist（新增 Provider 的 9 步）

> **强制顺序**。跳步一律视为违反 DoD，CI 会在代码审查门禁阻断。

- [ ] **Step 1 · 能力声明先行**：在 `lib/providers/{id}_provider.dart` 顶部写 `const kCapabilities = ProviderCapabilities(...)`
- [ ] **Step 2 · 接入参数常量**：同文件顶部 `const kBaseUrl`, `const kSubmitPath`, `const kPollPath` 等，不准散落到别处
- [ ] **Step 3 · 选接口组合**：同步选 `Submittable + KeyValidatable`；异步选 `Submittable + Pollable + KeyValidatable`（+ 可选 `Cancellable` / `QuotaAware`）
- [ ] **Step 4 · 实现 `validateApiKey`**：用最轻量端点，禁止消耗生成配额
- [ ] **Step 5 · 实现 `submit`**：内置 `await rateLimiter.acquire()`，参数验证用 `capabilities` 字段
- [ ] **Step 6 · 实现 `poll`**：单次请求；退避参数不能覆盖全局默认（如需覆盖，改 `capabilities.pollInterval`）
- [ ] **Step 7 · 错误映射**：所有 `DioException` 经 `_mapDioError()`，所有业务错误码映射到 §6.1 14 码
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
│   │   └── generation_provider.dart       # 5 接口 + 枚举
│   ├── models/
│   │   ├── provider_capabilities.dart     # freezed
│   │   ├── cost_model.dart                # freezed sealed
│   │   ├── generation_task.dart           # freezed
│   │   ├── job_status.dart                # freezed sealed
│   │   └── key_validation_result.dart     # freezed sealed
│   └── errors/
│       └── ink_error.dart                 # sealed + 14 构造器
├── providers/
│   ├── provider_registry.dart             # id → factory
│   ├── rate_limiter.dart                  # Per-Provider Token Bucket
│   ├── auth/
│   │   ├── volc_signer.dart               # Jimeng HMAC
│   │   └── kling_jwt.dart                 # Kling JWT 续签
│   ├── gemini_image_provider.dart
│   ├── jimeng_image_provider.dart
│   ├── kling_image_provider.dart
│   ├── kling_video_provider.dart
│   └── hailuo_video_provider.dart
└── core/di/
    └── providers.dart                     # Riverpod 接线（keepAlive）
```

**命名**：

- 文件名 snake_case，`{provider}_{mode}_provider.dart`（`kling_video_provider.dart`）
- 类名 PascalCase，`KlingVideoProvider`
- `providerId` kebab-case，**与 PRD §10.2 表字面对齐**（`kling-3.0` 不是 `kling_3_0`）

---

## 12. 测试契约（FakeProvider / fixture）

### 12.1 三层测试

| 层 | 目标 | 工具 | 覆盖率门槛 |
|---|---|---|---|
| 单元测试 | 每个 provider 的错误映射、签名、状态转换 | `test` + Mocktail + in-memory | ≥ 85% |
| 契约测试 | 所有 Provider 对 `Submittable/Pollable/Cancellable` 契约合规 | 共享 `ProviderContractSuite` | 100% 必过 |
| 回放 E2E | 用固定 fixture 重放真实 API 响应 | `http_mock_adapter` + `test/fixtures/providers/{id}/` | 5 家 × 5 场景 |

### 12.2 FakeProvider 规范

```dart
// test/helpers/fake_provider.dart
class FakeProvider implements Submittable, Pollable, Cancellable, KeyValidatable {
  FakeProvider({
    this.submitDelay = Duration.zero,
    this.pollResponses = const [],           // 顺序返回
    this.submitError,
    this.pollErrorAtIndex,
  });

  final Duration submitDelay;
  final List<JobStatus> pollResponses;
  final InkError? submitError;
  final int? pollErrorAtIndex;
  // ...
}
```

**硬约束**：

- 禁止在生产代码 (`lib/`) 里 import `FakeProvider`——只能 `test/` 下
- `ProviderContractSuite` 对每个真实 Provider 跑一遍，验证：
  - `submit()` → `JobId` 非空
  - `poll()` 直到 `success` / `failure` / `timeout` 的状态序列合法
  - 错误码在 14 码白名单内
  - `validateApiKey()` 三种结果齐全

### 12.3 Fixture 目录

```
test/fixtures/providers/
├── gemini-image/
│   ├── submit_success.json
│   ├── submit_invalid_key.json
│   └── submit_content_policy.json
├── kling-image/
│   ├── submit_success.json
│   ├── poll_in_progress.json
│   ├── poll_success.json
│   ├── poll_429.json
│   └── cancel_success.json
└── ...
```

**采集方式**：真实 API 调用一次 → 脱敏（去 Key / jobId 替换为 `FIXTURE_JOB_ID`）→ 入库。禁止手写 fixture。

---

## 13. 自定义 Provider 扩展点

**P1 实现，P0 仅留扩展点**。

`ProviderRegistry` 启动时合并三个源：

1. 内置 Provider（`lib/providers/*.dart` 中的 `providerId`）
2. `~/InkFrame/config/custom_providers.json`（用户自定义）
3. 未来：插件包（不在 P0/P1 范围）

**自定义 Provider 协议白名单**（硬编码）：

| protocol | 说明 |
|---|---|
| `openai-image` | OpenAI Images API 兼容 |
| `openai-chat-image` | OpenAI Chat Completions + image 输出 |
| `gemini-compatible` | Google Generative Language API 兼容 |

**禁止**运行时下发协议（安全边界）。

---

## 14. 反模式清单

> 以下任意一条出现在 PR 中，直接 block 合流。

1. ❌ 在 Widget 里 `import 'package:inkframe/providers/kling_video_provider.dart'`
   → 应通过 `ref.watch(providerRegistryProvider).get('kling-3.0')` 拿接口

2. ❌ Provider 实现类里 `throw Exception('invalid key')`
   → 应 `throw ProviderError.invalidKey()`

3. ❌ `poll()` 内部循环直到 success
   → 一次调用一次请求，退避由 JobQueueService

4. ❌ 接入参数散落：`final baseUrl = context.read(...)`
   → 必须 `const kBaseUrl = 'https://...'` 在文件顶部

5. ❌ `validateApiKey` 内调 `submit()` 做"验证"
   → 消耗用户配额，用户会投诉

6. ❌ `capabilities` 从 `.env` 或数据库读
   → 必须 `const`

7. ❌ 在 `submit()` 里 `await Future.delayed(Duration(seconds: 3))` 模拟退避
   → 退避是 JobQueueService 的职责

8. ❌ 同 providerId 出现两个实现类
   → `ProviderRegistry` 启动期自检，发现冲突直接抛 `AssertionError`

9. ❌ Provider 返回 `Map<String, dynamic>` 代替 `JobStatus`
   → 强类型接口，所有边界都是 freezed

10. ❌ `cancel()` 抛错中断 UI
    → 必须 swallow + 写 WARN 日志

---

## 变更记录

| 日期 | 版本 | 内容 | 作者 |
|---|---|---|---|
| 2026-04-15 | v0.1.0 | 初版。对齐 PRD §10 + ARCHITECTURE §3 | P9 |
