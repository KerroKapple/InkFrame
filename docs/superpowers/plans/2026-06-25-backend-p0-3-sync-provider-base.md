# Backend P0#3 — SyncProviderBase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** Kill the ~40% copy-paste across the three synchronous image providers (gemini / openai / stability) by extracting a `SyncProviderBase`, mirroring the existing `DashScopeAsyncProviderBase` (ADR-0005). Each provider drops from ~300 lines to ~80, keeping byte-identical behavior (existing per-provider test suites are the regression gate).

**Architecture:** `SyncProviderBase implements Submittable, Pollable, KeyValidatable`. Base owns: constructor (keySource/rateLimiter/baseUrl/dio) + default-dio builder, the `_inlineCache` + local-jobId synthesis, `_rand()`, `poll()` (consume cache → `JobStatus.success(inlineBytes)`), `submit()` skeleton (textToImage+prompt guard → `rateLimiter.acquire` → key → `performGeneration` → cache → DioException mapping with content-policy hook), and `validateApiKey()` skeleton (provider GET → shared DioException→KeyValidationResult switch). Subclasses supply: `capabilities`, `localJobPrefix`, `performGeneration(task,key)→Uint8List`, `performKeyValidation(key)`, and (optional) `contentPolicyFromDioError(e)`.

**Tech Stack:** Dart, dio, flutter_test, http_mock_adapter. No codegen.

## Global Constraints

- Behavior must be byte-identical: tests assert exact `InkErrorCode` / `KeyInvalidReason` / `extra['reason']` / jobId prefixes / request bodies+headers. Keep all public consts (`kGeminiBaseUrl`, `kGeminiSubmitPath`, `kGeminiLocalJobPrefix`, `kGeminiImageCapabilities`, and the openai/stability equivalents) and the public constructor signature `({required keySource, required rateLimiter, Dio? dio})` unchanged — DI (`lib/core/di/providers.dart`) and tests construct these directly.
- Errors are `InkError` subtypes only. Network protocol literals / model ids stay English consts.
- Comments Chinese, minimal. DI via Riverpod. Flutter not on PATH: `C:\Users\Kerro\flutter\bin\flutter.bat`.
- Every commit: `flutter analyze` 0 issues + `flutter test --exclude-tags pg` green.
- The networkError *message text* may be unified (no test asserts it); error codes/reasons must not change.

---

### Task 1: `SyncProviderBase`

**Files:** Create `lib/providers/sync_provider_base.dart`; Test `test/providers/sync_provider_base_test.dart`.

**Produces:**
- `typedef SyncProviderKeySource = Future<String> Function();`
- `abstract class SyncProviderBase implements Submittable, Pollable, KeyValidatable` with:
  - ctor `({required SyncProviderKeySource keySource, required ProviderRateLimiter rateLimiter, Dio? dio})`
  - `ProviderRateLimiter get rateLimiterForTesting`
  - `Dio get dio`
  - abstract `String get baseUrl` / abstract `String get localJobPrefix`
  - abstract `Future<Uint8List> performGeneration(GenerationTask task, String apiKey)`
  - abstract `Future<void> performKeyValidation(String apiKey)`
  - `InkError? contentPolicyFromDioError(DioException e) => null;`
  - concrete `submit` / `poll` / `validateApiKey`

> **As-built deviations from the draft below:** `baseUrl` is an **abstract getter** (not a ctor param) and the default Dio is built lazily (`late final _dio = _injectedDio ?? _buildDefaultDio(baseUrl)`) — an instance getter can't be read from a ctor initializer list, and the getter form lets subclasses use `super` parameters. `@protected` + the `meta` import were dropped to match `DashScopeAsyncProviderBase`'s convention (no annotation) and avoid a `depend_on_referenced_packages` lint. Behavior is unchanged.

- [ ] **Step 1: write base** (`lib/providers/sync_provider_base.dart`):

```dart
// 同步图片 Provider 公共基类（对照 DashScopeAsyncProviderBase / ADR-0004 / ADR-0005）。
//
// gemini / openai / stability 共享：rate-limit + key 读取 + 本地 JobId 合成 + inlineBytes
// 暂存 + poll 消费 + DioException→KeyValidationResult 开关。各 Provider 仅实现
// performGeneration（HTTP+解码出 bytes）/ performKeyValidation（最轻量鉴权 GET）/
// contentPolicyFromDioError（可选：把内容审核类 DioException 翻成 contentPolicy）。
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../core/errors/ink_error.dart';
import '../core/interfaces/generation_provider.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/key_validation_result.dart';
import '../core/models/provider_capabilities.dart';
import 'dio_error_mapper.dart';
import 'rate_limiter.dart';

/// Key getter 协议——延迟读取，避免 Provider 持久化 Key。
typedef SyncProviderKeySource = Future<String> Function();

abstract class SyncProviderBase
    implements Submittable, Pollable, KeyValidatable {
  SyncProviderBase({
    required SyncProviderKeySource keySource,
    required ProviderRateLimiter rateLimiter,
    required String baseUrl,
    Dio? dio,
  })  : _keySource = keySource,
        _rateLimiter = rateLimiter,
        _dio = dio ?? _buildDefaultDio(baseUrl);

  final SyncProviderKeySource _keySource;
  final ProviderRateLimiter _rateLimiter;
  final Dio _dio;

  /// 同步 Provider 的 inline bytes 暂存（ADR-0004）：submit 塞入、poll 一次性消费。
  final Map<JobId, Uint8List> _inlineCache = {};

  /// 仅供 DI 单测验证「共享 limiter」不变量。生产代码不要读这个。
  ProviderRateLimiter get rateLimiterForTesting => _rateLimiter;

  /// 子类在 performGeneration / performKeyValidation 里用它发请求。
  @protected
  Dio get dio => _dio;

  // ---- 子类必须提供 ------------------------------------------------------

  /// 本地合成 JobId 前缀，如 `local://gemini-image/`。
  String get localJobPrefix;

  /// 执行同步生成请求并返回原始图片字节。
  /// HTTP/解析失败抛 [ProviderError]；成功响应里的内容审核（如 Stability 的
  /// finish-reason 头）也在此直接抛 [ProviderError(contentPolicy)]。
  /// DioException 原样抛出，由基类统一映射。
  @protected
  Future<Uint8List> performGeneration(GenerationTask task, String apiKey);

  /// 执行最轻量鉴权 GET（零生成配额）。成功即返回；失败抛 DioException。
  @protected
  Future<void> performKeyValidation(String apiKey);

  /// 把内容审核类 DioException 翻成 [ProviderError(contentPolicy)]；否则返回 null。
  @protected
  InkError? contentPolicyFromDioError(DioException e) => null;

  // ---- Submittable -------------------------------------------------------

  @override
  Future<JobId> submit(GenerationTask task) async {
    if (task.mode != GenerationMode.textToImage) {
      throw ProviderError(
        code: InkErrorCode.invalidParameter,
        extra: {'provider_id': capabilities.providerId, 'reason': 'mode'},
      );
    }
    if (task.prompt.trim().isEmpty) {
      throw ProviderError(
        code: InkErrorCode.invalidParameter,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'empty_prompt',
        },
      );
    }

    await _rateLimiter.acquire();
    final key = await _keySource();
    try {
      final bytes = await performGeneration(task, key);
      final jobId = '$localJobPrefix${task.jobId}-${_rand()}';
      _inlineCache[jobId] = bytes;
      return jobId;
    } on DioException catch (e) {
      final policy = contentPolicyFromDioError(e);
      if (policy != null) throw policy;
      throw mapDioError(e, providerId: capabilities.providerId);
    }
  }

  // ---- Pollable ----------------------------------------------------------

  @override
  Future<JobStatus> poll(JobId id) async {
    final bytes = _inlineCache.remove(id);
    if (bytes == null) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'cache_miss_or_consumed',
          'job_id': id,
        },
      );
    }
    return JobStatus.success(remoteUrls: const [], inlineBytes: [bytes]);
  }

  // ---- KeyValidatable ----------------------------------------------------

  @override
  Future<KeyValidationResult> validateApiKey(String key) async {
    try {
      await performKeyValidation(key);
      return const KeyValidationResult.valid();
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const KeyValidationResult.networkError(
            message: 'validation timeout',
          );
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          return const KeyValidationResult.networkError(message: 'no network');
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode ?? 0;
          if (status == 401 || status == 403) {
            return const KeyValidationResult.invalid(
              reason: KeyInvalidReason.invalidKey,
            );
          }
          if (status == 402) {
            return const KeyValidationResult.invalid(
              reason: KeyInvalidReason.insufficientBalance,
            );
          }
          return KeyValidationResult.networkError(
            message: 'unexpected status $status',
          );
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          return KeyValidationResult.networkError(
            message: e.message ?? 'unknown',
          );
      }
    }
  }

  // ---- 内部 --------------------------------------------------------------

  static String _rand() =>
      Random.secure().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');

  static Dio _buildDefaultDio(String baseUrl) => Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          responseType: ResponseType.json,
        ),
      );
}
```

- [ ] **Step 2: focused base test** (`test/providers/sync_provider_base_test.dart`) — a tiny in-test subclass exercising poll cache-miss, jobId synthesis, validate switch, and the content-policy hook. (Per-provider suites cover the rest.)

- [ ] **Step 3:** `flutter.bat analyze lib/providers/sync_provider_base.dart test/providers/sync_provider_base_test.dart` → 0 issues; run the base test → green.

- [ ] **Step 4: commit** `feat(providers): SyncProviderBase — shared sync image-provider scaffolding`.

---

### Task 2: GeminiImageProvider on the base

**Files:** Modify `lib/providers/gemini_image_provider.dart`. Regression: `test/providers/gemini_image_provider_test.dart` (unchanged, must stay green).

- [ ] Rewrite class to `extends SyncProviderBase`. Keep all consts + `kGeminiImageCapabilities`. Constructor forwards to `super(keySource: keySource, rateLimiter: rateLimiter, baseUrl: kGeminiBaseUrl, dio: dio)`. Implement:
  - `capabilities => kGeminiImageCapabilities`
  - `localJobPrefix => kGeminiLocalJobPrefix`
  - `performGeneration(task,key)`: build the JSON body (contents/generationConfig/imageConfig.aspectRatio/responseModalities), `dio.post(kGeminiSubmitPath, headers:{kGeminiApiKeyHeader:key})`, then the existing `_handleSubmitResponse` parse → return the decoded `Uint8List` (move the base64-decode out of cache-insertion into the return).
  - `performKeyValidation(key)`: `dio.get(kGeminiValidatePath, queryParameters:{'pageSize':1}, headers:{kGeminiApiKeyHeader:key})`.
  - `contentPolicyFromDioError(e)`: if `statusCode==400 && _isContentPolicy(body)` → `ProviderError(contentPolicy, extra:{provider_id}, cause:e)` else null.
  - Keep `_aspectRatioFor`, `_isContentPolicy`. Delete `_buildDefaultDio`, `_rand`, `_inlineCache`, `poll`, `submit` skeleton, `validateApiKey` skeleton, the duplicated fields/getter (now in base). `_handleSubmitResponse` returns `Uint8List` instead of caching+jobId.
- [ ] Run `flutter.bat test test/providers/gemini_image_provider_test.dart` → green. analyze → 0.
- [ ] commit `refactor(providers): GeminiImageProvider on SyncProviderBase`.

---

### Task 3: OpenAIImageProvider on the base

**Files:** Modify `lib/providers/openai_image_provider.dart`. Regression: its test.

- [ ] Same transform. `performGeneration`: JSON body (model/prompt/n/size/quality), `dio.post(kOpenAIImagePath, headers:{'Authorization':'Bearer $key'})`, `_handleSubmitResponse` parse (`data[0].b64_json`) → `Uint8List`. `performKeyValidation`: `dio.get(kOpenAIValidatePath, headers:{'Authorization':'Bearer $key'})`. `contentPolicyFromDioError`: `statusCode==400 && _isContentPolicyViolation(body)`. Keep `_sizeFor`, `_isContentPolicyViolation`.
- [ ] Run its test → green. analyze → 0. commit `refactor(providers): OpenAIImageProvider on SyncProviderBase`.

---

### Task 4: StabilityImageCoreProvider on the base

**Files:** Modify `lib/providers/stability_image_core_provider.dart`. Regression: its test.

- [ ] Same transform. `performGeneration`: multipart `FormData` body, `dio.post<List<int>>(kStabilityCoreGeneratePath, headers:{Authorization, Accept:'image/*'}, responseType: bytes, contentType: multipart)`, check `finish-reason` header (CONTENT_FILTERED → throw `ProviderError(contentPolicy, reason:'content_filtered')`), empty body → `ProviderError(providerServer, reason:'empty_body')`, else `Uint8List.fromList(raw)`. `performKeyValidation`: `dio.get(kStabilityBalancePath, headers:{Authorization})`. `contentPolicyFromDioError`: `statusCode==403` → `ProviderError(contentPolicy, extra:{provider_id, status:403}, cause:e)`. Keep `_mapAspectRatio`.
- [ ] Run its test → green. analyze → 0. commit `refactor(providers): StabilityImageCoreProvider on SyncProviderBase`.

---

### Task 5: Full verification + branch finish

- [ ] `flutter.bat gen-l10n` (no diff) · `flutter.bat analyze` (0) · `flutter.bat test --exclude-tags "pg || golden"` (all green).
- [ ] Confirm line counts dropped (~300→~90 each).
- [ ] superpowers:requesting-code-review → finishing-a-development-branch → push + PR.

## Self-Review

- **Coverage:** base owns every duplicated member (ctor/dio/cache/_rand/poll/submit-skeleton/validate-switch); the 3 providers keep only their genuinely-unique HTTP+parse+policy. Mirrors `DashScopeAsyncProviderBase`. ✅
- **Behavior preservation:** submit order (mode→prompt→acquire→key→generate→cache), error codes/reasons/extra, jobId prefix+format, poll cache-miss, validate 401/403→invalidKey + 402→insufficientBalance, stability submit-403→contentPolicy + 200 finish-reason→contentPolicy — all preserved. Regression = existing 3 suites. ✅
- **Type consistency:** `performGeneration→Future<Uint8List>`, `contentPolicyFromDioError→InkError?`, `SyncProviderKeySource` (function-type compatible with the old per-provider typedefs, so DI lambdas still bind). ✅
- **Out of scope:** async (DashScope) providers untouched; provider *response* parse hardening = P1-4.
