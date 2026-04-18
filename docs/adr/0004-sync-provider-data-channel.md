# ADR-0004: 同步 Provider 通过 Pollable + inline bytes 通道暴露结果

- **Status**: accepted
- **Date**: 2026-04-18
- **Deciders**: P9 (Tech Lead)
- **Related**: PROVIDER-API.md §9 / ARCHITECTURE §3 / GeminiImageProvider (`lib/providers/gemini_image_provider.dart`)

---

## Context

PRD §10 把 Provider 抽成 5 个 ISP 接口：`Submittable` / `Pollable` / `Cancellable` / `QuotaAware` / `KeyValidatable`。`Submittable.submit` 返回 `JobId`，异步 Provider 后续靠 `Pollable.poll(jobId)` 拿 `JobStatus`。

**Gemini Image 是同步 Provider**：API 调用一次即返回 inline base64 图片字节，不需要轮询。当前实现的漏洞：

- `submit` 把 base64 解码成 `Uint8List` 后**丢弃**（`gemini_image_provider.dart:234` 局部变量未被使用）
- 只 implements `Submittable + KeyValidatable`，没 `Pollable`
- 上层（未来 JobQueueService）拿到 jobId 后**没有标准通道**取到 inline bytes

如果不修这个漏洞，JobQueueService 会被迫为同步 Provider 走特例路径（按 providerId 硬编码 if-else 取 bytes），违反 SOLID O/D。

**约束：**
- 不能让 `Submittable.submit` 直接返回 `JobStatus` —— 破坏 Submittable / Pollable 接口分离
- 不能让 Provider 自己写盘 —— 违反 SRP（IO 是上层 FileResolverService 职责）
- 异步 Provider 路径不应被同步特性污染（inlineBytes 字段必须 nullable + 默认 null）

## Decision

**1. `JobStatus.success` 扩展可选 `inlineBytes` 字段：**

```dart
const factory JobStatus.success({
  required List<String> remoteUrls,
  DateTime? urlExpiresAt,
  List<Uint8List>? inlineBytes,  // 新增：同步 Provider 携带原始字节
}) = JobSuccess;
```

异步 Provider 不填该字段，行为不变。

**2. 同步 Provider 必须 implements Pollable：**

- `submit` 调 API → 解码 base64 → 把 bytes 缓存到 instance-scoped `Map<JobId, Uint8List>` → 返回 `local://...` 前缀的 jobId
- `poll(jobId)` 从 cache 取 bytes → 立即同步返回 `JobStatus.success(remoteUrls=[], inlineBytes=[bytes])` → **从 cache 删除**（一次性消费）
- 重复 poll 同一 jobId 抛 `ProviderError(providerServer, reason='cache_miss_or_consumed')`

**3. capabilities 标记：**

`supportsPolling: true` 同样适用于同步 Provider —— 调用方不需要区分，只是同步 Provider 的 poll 一调即结束。

**4. 上层契约（未来 JobQueueService 实现时遵守）：**

```
拿到 JobStatus.success 后：
  if (inlineBytes != null) {
    用 FileResolverService 写到 {canvasRoot}/images/...
  } else {
    走下载流程（remoteUrls → HTTP GET → 写盘）
  }
```

## Alternatives

| 方案 | 否定原因 |
|---|---|
| A. `Submittable.submit` 直接返回 `JobStatus` | 破坏 ISP（Submit 与 Poll 关注点融合） |
| B. 新建 `SyncSubmittable` 接口 | 接口爆炸；上层要按 capabilities 选接口 |
| C. submit 写临时文件返回 `file://` URL | Provider 越权做 IO；FileResolverService 失去唯一性 |
| D. 内存 stream/回调推 bytes | 接口复杂度 ↑↑；与 Future-based 风格不一致 |

## Consequences

**收益：**
- ✅ 同步 / 异步 Provider 上层调用代码无差别（统一 submit → poll → JobStatus 路径）
- ✅ inline 字段可选 + 默认 null，异步 Provider 路径完全不受影响（向后兼容现有测试）
- ✅ Provider 只做 API 调用 + 数据传递，不碰文件系统（SRP 守住）

**代价：**
- ⚠️ **内存压力**：base64 解码后字节驻留 Provider instance 的 cache，从 submit 到 poll 之间停留
- ⚠️ Cache 漏 cleanup 风险：如果 JobQueueService 异常路径未调 poll，bytes 永远留在内存
- ⚠️ Test surface ↑：Gemini test 需要补 poll 路径 + cache lifecycle 用例

**缓解：**
- JobQueueService 按 PRD §10.3 流程，submit 后**立即**进入 polling 状态，对同步 Provider 是同步立即调一次 poll，缓存停留 ≤ 一次方法调用栈
- Cache 用 instance-scoped Map（不是全局 static），Provider instance 被销毁时 GC 自动回收
- 单测覆盖：(a) submit→poll 一次成功 (b) 重复 poll 报错 (c) submit 异常时不留 cache

## 影响文件

- `lib/core/models/job_status.dart` + `job_status.freezed.dart`：`JobSuccess` 加 `inlineBytes` 字段
- `lib/providers/gemini_image_provider.dart`：`implements Pollable`，加 `_inlineCache: Map<JobId, Uint8List>`，capabilities 改 `supportsPolling: true`
- `test/providers/gemini_image_provider_test.dart`：补 3 case（poll 成功 / 重复 poll 报错 / submit 失败不污染 cache）
- `docs/PROVIDER-API.md` §9：补"同步 Provider 数据通道"小节
- `docs/adr/0000-index.md`：登记 ADR-0004
