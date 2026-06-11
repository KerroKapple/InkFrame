# Plan: Stability AI Stable Image Core Provider

**Date**: 2026-06-10
**providerId**: `stability-image-core`
**Status**: Ready for execution (fixture-E2E task blocked pending real API key)

---

## Goal

Add `StabilityImageCoreProvider` — a **synchronous** text-to-image provider using the
Stability AI REST v2beta `POST /v2beta/stable-image/generate/core` endpoint.
Follows the ADR-0004 inlineBytes channel (same pattern as `GeminiImageProvider`).
Implements `Submittable + Pollable + KeyValidatable`.

---

## API Research (Stability AI REST v2beta)

### Sources

- [Stability AI Developer Platform — API Reference](https://platform.stability.ai/docs/api-reference)
- [Getting Started — Stable Image](https://platform.stability.ai/docs/getting-started/stable-image)
- [Medium: Building Your Own AI Image Generator — Utilizing Stability AI Endpoints](https://medium.com/@learningsomethingnew/building-your-own-ai-image-generator-utilizing-stability-ai-endpoints-e0b968feba1b)
- [DataCamp: How to Use the Stable Diffusion 3 API](https://www.datacamp.com/tutorial/how-to-use-stable-diffusion-3-api)
- [Stability AI Knowledge Base: Content Filtering](https://kb.stability.ai/knowledge-base/understanding-content-filtering-and-safeguards-at-stability-ai)
- [Stability AI Pricing](https://platform.stability.ai/pricing)

### Chosen Endpoint

| Field | Value |
|---|---|
| Base URL | `https://api.stability.ai` |
| Generate path | `POST /v2beta/stable-image/generate/core` |
| Auth | `Authorization: Bearer {API_KEY}` header |
| Request content-type | `multipart/form-data` (NOT JSON — see Preconditions) |
| Accept header | `image/*` → response body = raw PNG/JPEG bytes |
| Sync vs async | **Synchronous** — single call returns image bytes directly (HTTP 200 + body = image) |
| Key-validation endpoint | `GET /v1/user/balance` — returns `{"credits": <float>}`; no generation quota consumed |

### Request Parameters (multipart fields)

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `prompt` | string | yes | Max ~10,000 chars |
| `aspect_ratio` | string | no | `1:1` `16:9` `9:16` `4:3` `3:4` `21:9` `9:21`; default `1:1` |
| `negative_prompt` | string | no | Exclusions |
| `seed` | uint32 | no | 0 = random |
| `output_format` | string | no | `png` (default) `jpeg` `webp` |
| `style_preset` | string | no | e.g. `cinematic` `digital-art` `fantasy-art` etc. (Core only) |

### Response Shape

- **HTTP 200 + `Accept: image/*`**: body = raw image bytes; headers include `finish-reason` (`SUCCESS` or `CONTENT_FILTERED`) and `seed` (uint32 as string).
- **`finish-reason: CONTENT_FILTERED`** arrives as HTTP 200 with a blurred/blank image. Must be detected via the response header, not status code.
- **`Content-Type`**: `image/png` or `image/jpeg` depending on `output_format`.

### Status Codes

| Code | Meaning | InkError mapping |
|---|---|---|
| 200 | Success (check `finish-reason` header) | — |
| 400 | Bad request / missing param | `ProviderError(invalidParameter)` |
| 401 | Invalid or missing API key | `ProviderError(invalidKey)` |
| 402 | Insufficient credits | `ProviderError(insufficientBalance)` |
| 403 | Content moderation block | `ProviderError(contentPolicy)` |
| 422 | Invalid parameter value | `ProviderError(invalidParameter)` |
| 429 | Rate limited | `ProviderError(providerBusy)` |
| 500/5xx | Server error | `ProviderError(providerServer)` |

> **Note on `finish-reason: CONTENT_FILTERED`**: The API returns HTTP 200 with a body (blurred placeholder). The provider MUST inspect the `finish-reason` response header and throw `ProviderError(contentPolicy)` when the value is `CONTENT_FILTERED`. This is a Stability-specific deviation from the HTTP-status-only approach in `mapDioError`.

### Credit Cost

- Stable Image Core: **3 credits per successful image** = **USD $0.03** at $0.01/credit.
- Failed generations do **not** consume credits.

### Key Validation Endpoint

`GET https://api.stability.ai/v1/user/balance`
- Header: `Authorization: Bearer {key}`
- Response: `{"credits": 1234.56}` — read `credits` field; positive value = valid key.
- No generation credits consumed.
- 401 → `KeyInvalid(invalidKey)`, 403 → `KeyInvalid(invalidKey)`.

---

## Architecture

### Sync Provider Pattern (ADR-0004 — mirrors GeminiImageProvider)

```
submit(task)
  ├── validate mode + prompt (local, no HTTP)
  ├── await rateLimiter.acquire()
  ├── POST /v2beta/stable-image/generate/core  (multipart/form-data)
  │     Accept: image/*
  │     Authorization: Bearer {key}
  ├── check finish-reason header → throw contentPolicy if CONTENT_FILTERED
  ├── bytes = response body (Uint8List)
  ├── jobId = 'local://stability-image-core/{task.jobId}-{rand()}'
  ├── _inlineCache[jobId] = bytes
  └── return jobId

poll(jobId)
  ├── bytes = _inlineCache.remove(jobId)
  ├── if null → throw ProviderError(providerServer, reason: 'cache_miss_or_consumed')
  └── return JobStatus.success(remoteUrls: [], inlineBytes: [bytes])

validateApiKey(key)
  └── GET /v1/user/balance
        200 + credits > 0 → KeyValid(accountInfo: 'Credits: {n}')
        200 + credits == 0 → KeyValid  (zero balance ≠ invalid key; warn in UI)
        401/403 → KeyInvalid(invalidKey)
        402 → KeyInvalid(insufficientBalance)
        network errors → KeyNetworkError
```

### Key multipart deviation from JSON providers

Stability AI uses `multipart/form-data`, not `application/json`. In `submit()`,
build a `dio.FormData` object and append each field with `FormData.fromMap(...)`.
The response body must be consumed as **bytes** (`responseType: ResponseType.bytes`).
This is the only provider in the repo that uses `ResponseType.bytes`; all others
use `ResponseType.json`. Set this on the per-request `Options`, not on the shared
`BaseOptions`, so the shared Dio instance remains JSON-defaulted.

---

## Tech Stack

- Flutter Desktop (Dart), Riverpod, Dio
- `dio` `FormData` for multipart body
- `ResponseType.bytes` per-request for image response
- `http_mock_adapter` for tests
- `test` + `flutter_test`
- Flutter command: `/c/Users/Kerro/flutter/bin/flutter.bat`

---

## Preconditions / Known Limitations

1. **Multipart/form-data deviation**: All existing providers post `application/json`.
   Stability uses `multipart/form-data`. The implementation MUST use `FormData.fromMap({...})`
   and MUST NOT assume JSON body. This is called out in every task step that touches `submit()`.

2. **`finish-reason` header check**: The content-moderation signal arrives as an HTTP response
   header on a 200 response, not as a 4xx. `mapDioError` will not catch it; the provider
   must inspect `response.headers.value('finish-reason')` directly after a successful HTTP call.

3. **`ResponseType.bytes` required**: Image bytes are the raw response body.
   Without `responseType: ResponseType.bytes`, Dio will attempt JSON parsing and throw.
   Set this via per-request `Options` (not globally).

4. **Fixture-replay E2E (Task 9) requires a real API key**: The fixture for `submit_success`
   must be captured from a real Stability AI API call, then desensitized
   (replace real seed value with `99999`, strip any PII headers).
   Handwritten fixtures are FORBIDDEN per §12.3.
   Without a key, **Task 9 is BLOCKED** — mark it skipped in CI with `skip: 'BLOCKED-pending-stability-key'`.
   Tasks 1–8 (unit + contract tests) require no real key.

5. **Env churn files — never stage**: `pubspec.lock`,
   `macos/Flutter/GeneratedPluginRegistrant.swift`,
   `windows/flutter/generated_plugin_registrant.cc`,
   `windows/flutter/generated_plugin_registrant.h`,
   `windows/flutter/generated_plugins.cmake`.
   Use `git add lib/ test/ l10n/` targeted staging only.

6. **`style_preset` not in `GenerationTask`**: The `GenerationTask` model has no
   `stylePreset` field. This is a Stability-specific parameter. For the pilot,
   `style_preset` is omitted from the request (the API uses a sensible default).
   A follow-on task can add `stylePreset` to `GenerationTask` if needed; do NOT
   add it in this plan to avoid scope creep and model churn.

7. **`output_format` hardcoded to `png`**: `GenerationTask` has no output-format field.
   Hardcode `output_format = 'png'` at the const area; change is a single-line update later.

---

## ProviderCapabilities Design Decisions

| Field | Value | Rationale |
|---|---|---|
| `providerId` | `stability-image-core` | kebab-case, model-tier explicit |
| `region` | `ProviderRegion.global` | Stability AI is a global (US) service |
| `modes` | `[GenerationMode.textToImage]` | Core endpoint is T2I only |
| `supportedRatios` | `r1x1, r16x9, r9x16, r4x3, r3x4, r21x9` | Matches API's documented `aspect_ratio` values; `r21x9` maps to `21:9` |
| `supportedResolutions` | `[Resolution.p1080]` | Core outputs ~1MP images; no resolution toggle |
| `supportedDurations` | `[]` | Image provider |
| `supportedCameras` | `[]` | Image provider |
| `maxBatchSize` | `1` | API generates one image per call |
| `maxRefImages` | `0` | Core endpoint is text-only |
| `refImagesIncludeKeyframes` | `false` | |
| `supportsFirstFrame` | `false` | |
| `supportsLastFrame` | `false` | |
| `supportsNegativePrompt` | `true` | API supports `negative_prompt` |
| `supportsSeed` | `true` | API supports `seed` |
| `supportsSound` | `false` | |
| `supportsBatch` | `false` | |
| `supportsCancellation` | `false` | Sync provider, no async task to cancel |
| `supportsPolling` | `true` | Sync Provider still implements Pollable (ADR-0004) |
| `costModel` | `CostModel.perCall(usdPerCall: 0.03)` | 3 credits × $0.01 = $0.03 |
| `maxConcurrentJobs` | `1` | Conservative: single sync blocking call |
| `qps` | `1` | Stability Core rate limit is conservative; 1 QPS safe default |
| `burst` | `3` | Small burst allowance |
| `pollInterval` | `null` | Global default (3s); irrelevant for sync but field required |
| `pollTimeout` | `null` | Global default |

---

## File Structure

| File | Action | Notes |
|---|---|---|
| `lib/providers/stability_image_core_provider.dart` | **CREATE** | Provider implementation |
| `lib/core/di/providers.dart` | **EDIT** | Add `stability-image-core` registration |
| `lib/core/constants/secure_storage_keys.dart` | **EDIT** | Add `'stability-image-core': 'Stable Image Core'` to `_familyDisplayNames` so Settings shows a friendly label instead of the raw id |
| `test/providers/stability_image_core_provider_test.dart` | **CREATE** | Unit + contract tests |
| `test/fixtures/providers/stability-image-core/submit_success.json` | **CREATE** | Real API capture (Task 9 only) |
| `test/fixtures/providers/stability-image-core/submit_invalid_key.json` | **CREATE** | Real API capture (Task 9 only) |
| `test/fixtures/providers/stability-image-core/submit_content_policy.json` | **CREATE** | Real API capture (Task 9 only) |
| `test/fixtures/providers/stability-image-core/balance_success.json` | **CREATE** | Real API capture (Task 9 only) |

> Fixture files in Task 9 MUST NOT be handwritten. Mark Task 9 BLOCKED until a real key is available.

---

## Provider Display Name (NOT i18n)

**There are NO `providerXxxName` ARB keys in this repo.** The Settings "API Keys" section
resolves a provider's label via `SecureStorageKeys.displayNameOf(scope)`, which returns
`_familyDisplayNames[scope] ?? scope`. For a non-family provider, `scope == providerId`, so
without an entry the UI shows the raw `stability-image-core`.

To render a friendly label, add ONE entry to the `_familyDisplayNames` map in
`lib/core/constants/secure_storage_keys.dart`:

```dart
static const Map<String, String> _familyDisplayNames = <String, String>{
  'dashscope': 'DashScope',
  'stability-image-core': 'Stable Image Core',   // ← add this
};
```

> No ARB change. No `flutter gen-l10n`. Error messageKeys (`errorInvalidKey`, etc.) already exist.
> A provider name is internal config-surface text resolved from a Dart map, not localized UI copy.

---

## Numbered Tasks

Tasks are independent enough to be done sequentially in one session.
TDD order: write test first (RED) → implement (GREEN) → no separate refactor step unless noted.

---

### Task 1 — Write failing capability test (RED)

**Goal**: Establish the `ProviderCapabilities` const and verify its fields compile and match spec.

Steps:
- [ ] Create `test/providers/stability_image_core_provider_test.dart`
- [ ] Add group `'StabilityImageCoreProvider capabilities'`
- [ ] Write test: `providerId == 'stability-image-core'`
- [ ] Write test: `region == ProviderRegion.global`
- [ ] Write test: `modes == [GenerationMode.textToImage]`
- [ ] Write test: `supportsNegativePrompt == true`
- [ ] Write test: `supportsSeed == true`
- [ ] Write test: `supportsPolling == true` (ADR-0004 sync channel)
- [ ] Write test: `supportsCancellation == false`
- [ ] Write test: `costModel == CostModel.perCall(usdPerCall: 0.03)`
- [ ] Write test: `qps == 1`, `burst == 3`
- [ ] Run: `/c/Users/Kerro/flutter/bin/flutter.bat test test/providers/stability_image_core_provider_test.dart` from `E:\InkFrame` — expect compile error (file doesn't exist yet)

---

### Task 2 — Implement capabilities const (GREEN for Task 1)

**Goal**: Create the provider file with the `const kCapabilities` block and the class skeleton.

Steps (§10 Step 1 + Step 2 + Step 3):
- [ ] Create `lib/providers/stability_image_core_provider.dart`
- [ ] Add file-top const block:
  ```
  const String kStabilityBasePath = 'https://api.stability.ai';
  const String kStabilityCoreGeneratePath = '/v2beta/stable-image/generate/core';
  const String kStabilityBalancePath = '/v1/user/balance';
  const String kStabilityLocalJobPrefix = 'local://stability-image-core/';
  const String kStabilityOutputFormat = 'png';
  ```
- [ ] Declare `const ProviderCapabilities kStabilityImageCoreCapabilities = ProviderCapabilities(...)` with all fields from the design table above
- [ ] Declare class skeleton `class StabilityImageCoreProvider implements Submittable, Pollable, KeyValidatable`
- [ ] Add constructor: `StabilityImageCoreProvider({required keySource, required rateLimiter, Dio? dio})`
- [ ] Stub out `submit`, `poll`, `validateApiKey` to `throw UnimplementedError()`
- [ ] Run test: `/c/Users/Kerro/flutter/bin/flutter.bat test test/providers/stability_image_core_provider_test.dart` — capability tests PASS; other tests FAIL (unimplemented)

---

### Task 3 — Write failing `validateApiKey` tests (RED)

**Goal**: TDD-drive `validateApiKey` before implementing it.

Steps (§10 Step 4):
- [ ] Add group `'StabilityImageCoreProvider.validateApiKey'` to test file
- [ ] Write test: `GET /v1/user/balance` returns `{"credits": 10.5}` → `KeyValid`
- [ ] Write test: `GET /v1/user/balance` returns `{"credits": 0.0}` → `KeyValid` (zero balance is not invalid)
- [ ] Write test: 401 response → `KeyInvalid(reason: KeyInvalidReason.invalidKey)`
- [ ] Write test: 403 response → `KeyInvalid(reason: KeyInvalidReason.invalidKey)`
- [ ] Write test: 402 response → `KeyInvalid(reason: KeyInvalidReason.insufficientBalance)`
- [ ] Write test: connection timeout → `KeyNetworkError`
- [ ] Write test: `connectionError` (offline) → `KeyNetworkError`
- [ ] Run tests — all RED (UnimplementedError)

---

### Task 4 — Implement `validateApiKey` (GREEN for Task 3)

**Goal**: Hit `GET /v1/user/balance`, map responses to `KeyValidationResult`.

Steps:
- [ ] In `StabilityImageCoreProvider`, replace `validateApiKey` stub:
  - Build a separate `Dio` instance OR reuse `_dio` with `BaseOptions(baseUrl: kStabilityBasePath)`
  - `GET kStabilityBalancePath` with `Authorization: Bearer {key}` header
  - On 200: parse `{"credits": <double>}` → `KeyValidationResult.valid(accountInfo: 'Credits: ${credits.toStringAsFixed(2)}')`
  - On `DioExceptionType.badResponse`:
    - 401 / 403 → `KeyValidationResult.invalid(reason: KeyInvalidReason.invalidKey)`
    - 402 → `KeyValidationResult.invalid(reason: KeyInvalidReason.insufficientBalance)`
    - other → `KeyValidationResult.networkError(message: 'status $code')`
  - On timeout / connectionError → `KeyValidationResult.networkError(message: ...)`
  - No `mapDioError` call here — `validateApiKey` returns a result type, not throws
- [ ] Run: `/c/Users/Kerro/flutter/bin/flutter.bat test test/providers/stability_image_core_provider_test.dart` — Task 3 tests PASS

---

### Task 5 — Write failing `submit` tests (RED)

**Goal**: TDD-drive the multipart submit path before implementing it.

Steps (§10 Step 5):
- [ ] Add group `'StabilityImageCoreProvider.submit'` to test file
- [ ] Write test: success path — mock `POST /v2beta/stable-image/generate/core` returns 200 + PNG bytes + header `finish-reason: SUCCESS` → `submit()` returns `jobId` starting with `kStabilityLocalJobPrefix`
- [ ] Write test: `finish-reason: CONTENT_FILTERED` on 200 → throws `ProviderError(contentPolicy)`
- [ ] Write test: 401 → throws `ProviderError(invalidKey)`
- [ ] Write test: 402 → throws `ProviderError(insufficientBalance)`
- [ ] Write test: 403 → throws `ProviderError(contentPolicy)`
- [ ] Write test: 422 → throws `ProviderError(invalidParameter)`
- [ ] Write test: 429 → throws `ProviderError(providerBusy)` with `retryable == true`
- [ ] Write test: 500 → throws `ProviderError(providerServer)` with `retryable == true`
- [ ] Write test: empty prompt (local validation) → throws `ProviderError(invalidParameter)` without making HTTP call
- [ ] Write test: mode != `textToImage` → throws `ProviderError(invalidParameter)` without making HTTP call
- [ ] Write test: `submit` failure does NOT write to `_inlineCache` (poll after failed submit → `cache_miss_or_consumed`)
- [ ] Run — all RED

**Multipart mock note**: `http_mock_adapter` intercepts by URL; form fields are not matched. The mock simply returns the pre-configured response. No special form-data assertion needed in the mock — field correctness is asserted via a spy or trusted by implementation review.

---

### Task 6 — Implement `submit` (GREEN for Task 5)

**Goal**: POST multipart/form-data, read bytes, cache, return local JobId.

Steps:
- [ ] Replace `submit` stub in `StabilityImageCoreProvider`:
  1. Local validation: `mode != textToImage` → throw `ProviderError(invalidParameter, ...)`
  2. Local validation: `prompt.trim().isEmpty` → throw `ProviderError(invalidParameter, ...)`
  3. `await _rateLimiter.acquire()`
  4. `final key = await _keySource()`
  5. Build `FormData`:
     ```dart
     final form = FormData.fromMap({
       'prompt': task.prompt,
       if (task.negativePrompt != null) 'negative_prompt': task.negativePrompt,
       'aspect_ratio': _mapAspectRatio(task.aspectRatio),
       if (task.seed != null) 'seed': task.seed.toString(),
       'output_format': kStabilityOutputFormat,
     });
     ```
  6. POST with per-request options:
     ```dart
     Options(
       headers: {'Authorization': 'Bearer $key', 'Accept': 'image/*'},
       responseType: ResponseType.bytes,
       contentType: 'multipart/form-data',
     )
     ```
  7. Check `response.headers.value('finish-reason')`:
     - `'CONTENT_FILTERED'` → throw `ProviderError(contentPolicy, ...)`
  8. Extract bytes: `final bytes = Uint8List.fromList(response.data as List<int>)`
  9. Synthesize `jobId = '$kStabilityLocalJobPrefix${task.jobId}-${_rand()}'`
  10. `_inlineCache[jobId] = bytes` (only on success path)
  11. `return jobId`
  12. Wrap in `try/on DioException catch(e)` → `throw mapDioError(e, providerId: capabilities.providerId)`
     - **Before calling `mapDioError`**, check for 403 specifically:
       `if (status == 403) throw ProviderError(contentPolicy, ...)`
       (403 is content moderation at Stability, not `invalidKey`)

- [ ] Add private helper `String _mapAspectRatio(AspectRatio r)`:
  ```
  r1x1  → '1:1'
  r16x9 → '16:9'
  r9x16 → '9:16'
  r4x3  → '4:3'
  r3x4  → '3:4'
  r21x9 → '21:9'
  ```
  Any unmapped value (e.g. future enums) → fallback to `'1:1'` with a `debugPrint` warning.

- [ ] Add private `static String _rand()` (copy from `GeminiImageProvider._rand()`)
- [ ] Run: `/c/Users/Kerro/flutter/bin/flutter.bat test test/providers/stability_image_core_provider_test.dart` — Task 5 tests PASS

---

### Task 7 — Write failing `poll` tests (RED) + implement (GREEN)

**Goal**: TDD the ADR-0004 sync cache consume path.

Steps (§10 Step 6):
- [ ] Add group `'StabilityImageCoreProvider.poll (sync channel)'`
- [ ] Write test: `submit → poll` returns `JobStatus.success(remoteUrls: [], inlineBytes: [bytes])` where `bytes.isNotEmpty`
- [ ] Write test: second `poll` same jobId → throws `ProviderError(providerServer, reason: 'cache_miss_or_consumed')`
- [ ] Write test: `poll` on unknown jobId → throws `ProviderError(providerServer, reason: 'cache_miss_or_consumed')`
- [ ] Run — RED
- [ ] Implement `poll(JobId id)`:
  ```dart
  final bytes = _inlineCache.remove(id);
  if (bytes == null) {
    throw ProviderError(
      code: InkErrorCode.providerServer,
      extra: {'provider_id': capabilities.providerId, 'reason': 'cache_miss_or_consumed', 'job_id': id},
    );
  }
  return JobStatus.success(remoteUrls: const [], inlineBytes: [bytes]);
  ```
- [ ] Run: `/c/Users/Kerro/flutter/bin/flutter.bat test test/providers/stability_image_core_provider_test.dart` — all PASS

---

### Task 8 — Error mapping + DI wiring + i18n (§10 Step 7 + 8)

**Goal**: Wire into `ProviderRegistry`, register the friendly display name, run full test suite.

Steps:
- [ ] **Display name**: in `lib/core/constants/secure_storage_keys.dart`, add `'stability-image-core': 'Stable Image Core'` to the `_familyDisplayNames` map (see "Provider Display Name" section). No ARB change, no `gen-l10n`.
- [ ] **Display-name test**: in `test/core/constants/` (or extend the existing secure-storage-keys test if present), assert `SecureStorageKeys.displayNameOf('stability-image-core') == 'Stable Image Core'`. RED before the map edit, GREEN after.
- [ ] **DI wiring** in `lib/core/di/providers.dart`:
  - Import `stability_image_core_provider.dart`
  - Add rate limiter:
    ```dart
    final stabilityImageCoreRl = ProviderRateLimiter(
      qps: kStabilityImageCoreCapabilities.qps,
      burst: kStabilityImageCoreCapabilities.burst,
    );
    ```
  - Add registry entry:
    ```dart
    kStabilityImageCoreCapabilities.providerId: () => StabilityImageCoreProvider(
      keySource: keyFor(kStabilityImageCoreCapabilities.providerId),
      rateLimiter: stabilityImageCoreRl,
    ),
    ```
- [ ] Add a `provider_registry_registration_test.dart` assertion (or extend existing file):
  - `registry.contains('stability-image-core') == true`
- [ ] Run full suite: `/c/Users/Kerro/flutter/bin/flutter.bat test` from `E:\InkFrame`
- [ ] Fix any failures
- [ ] Run `flutter analyze`: `/c/Users/Kerro/flutter/bin/flutter.bat analyze` from `E:\InkFrame`
- [ ] Confirm zero issues

**CI checklist** (run manually before commit):
- `rg 'Color\(|fontSize:|FontWeight\.' lib/providers/stability_image_core_provider.dart` = 0
- `rg 'flutter/material|flutter/widgets' lib/providers/stability_image_core_provider.dart` = 0
- `rg 'throw Exception|throw .*Error[^(]' lib/providers/stability_image_core_provider.dart` = 0
- `SecureStorageKeys.displayNameOf('stability-image-core') == 'Stable Image Core'` (no ARB key added)

---

### Task 9 — Fixture-replay E2E tests (§12.3) — BLOCKED-pending-stability-key

**Status**: BLOCKED — requires a real Stability AI API key.

**Precondition**: Must have a valid `STABILITY_API_KEY` with credits.

Steps:
- [ ] Make ONE real call to `POST /v2beta/stable-image/generate/core` with a short test prompt
- [ ] Save raw response bytes. Because Stability returns **binary image bytes** (not JSON),
  the fixture for `submit_success` is stored differently from JSON providers.
  Store a minimal 1×1 PNG as base64 in a JSON wrapper:
  ```json
  { "_fixture_format": "base64_bytes", "data": "<base64>", "headers": { "finish-reason": "SUCCESS", "seed": "99999" } }
  ```
  The test must decode this wrapper to reconstruct the mock response.
- [ ] Make ONE real call with an invalid key → save `submit_invalid_key.json`
- [ ] Make ONE real call with a content-violating prompt (if possible) OR
  construct the 403 response shape manually from Stability docs — this is the ONE exception
  where the fixture may be manually constructed because content policy responses are
  structurally trivial (empty body + HTTP 403) and impossible to capture without violating ToS.
  Document this exception inline in the test file.
- [ ] Make ONE real call to `GET /v1/user/balance` → save `balance_success.json`
- [ ] Desensitize: replace real seed values with `99999`, strip any auth headers
- [ ] Write `'StabilityImageCoreProvider fixture E2E'` group in test file using
  `http_mock_adapter` replaying the above fixtures
- [ ] Run: `/c/Users/Kerro/flutter/bin/flutter.bat test test/providers/stability_image_core_provider_test.dart`

**Skip annotation until unblocked**:
```dart
group('StabilityImageCoreProvider fixture E2E', () {
  // BLOCKED-pending-stability-key: skip until real fixtures captured
}, skip: 'BLOCKED-pending-stability-key');
```

---

## Contract Ambiguities and Resolutions

| Ambiguity | Resolution |
|---|---|
| `finish-reason: CONTENT_FILTERED` arrives on HTTP 200, not 403 | Inspect header after successful HTTP call; throw `ProviderError(contentPolicy)`. The `mapDioError` path is not reached for this case. |
| `AspectRatio.r21x9` maps to Stability's `21:9` but not all providers support it | Map it; Stability Core docs list `21:9` explicitly. |
| No `AspectRatio` enum value for `9:21` (portrait ultra-wide) | Stability supports `9:21` but the repo's `AspectRatio` enum has no such value. Omit — do not add new enum values in this plan. |
| `style_preset` has no `GenerationTask` field | Omit from request for pilot. Document as follow-on extension. |
| `output_format` has no `GenerationTask` field | Hardcode `png` as const. |
| `CostModel` has no `perCall` variant that accounts for "zero credits on failure" | `CostModel.perCall(usdPerCall: 0.03)` is still correct — `estimateCost` is an estimate, not a billing guarantee. |
| `v1/user/balance` is v1 (legacy), not v2beta | Stability AI's v2beta does not include a balance/account endpoint as of 2026. The v1 balance endpoint remains active (not deprecated). Use it; document in code comments. |
| 403 on generate endpoint = content policy, but `mapDioError` maps 403 to `invalidKey` | Add a pre-check before calling `mapDioError`: `if (status == 403) throw ProviderError(contentPolicy, ...)`. This mirrors how `GeminiImageProvider` pre-checks for SAFETY before calling `mapDioError`. |

---

## Summary

| Item | Value |
|---|---|
| `providerId` | `stability-image-core` — model tier explicit, avoids future collision with `stability-image-ultra` |
| Sync vs async | **Synchronous** — single HTTP call returns PNG bytes directly |
| Endpoint | `POST https://api.stability.ai/v2beta/stable-image/generate/core` |
| Model tier | Core (cheapest at $0.03/image; no model selector needed) |
| Multipart note | Uses `dio.FormData` + `ResponseType.bytes`; only provider in repo not posting JSON |
| Key validation | `GET /v1/user/balance` (v1, not v2beta) — returns `{"credits": float}` |
| Notable capability fields | `supportsNegativePrompt: true`, `supportsSeed: true`, `supportsPolling: true` (ADR-0004), `supportsCancellation: false`, `costModel: perCall($0.03)` |
| Task count | 9 tasks (Tasks 1–8 executable without API key; Task 9 BLOCKED-pending-stability-key) |
| Fixture-E2E key dependency | Task 9 requires a live `STABILITY_API_KEY` with credits to capture binary response fixtures; skip annotation provided |
