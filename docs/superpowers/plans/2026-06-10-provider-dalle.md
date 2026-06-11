# DALL-E / GPT-Image Provider 实施计划 (`openai-image`)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> Flutter binary: **`/c/Users/Kerro/flutter/bin/flutter.bat`** — NOT on PATH. All flutter commands use this absolute path, run from repo root `E:\InkFrame`.

---

## Goal

Add `openai-image` as a first-class built-in provider: OpenAI `gpt-image-1` synchronous image generation via `POST /v1/images/generations`, wired into the existing `Submittable + Pollable + KeyValidatable` contract (ADR-0004 inline-bytes sync channel), registered in `ProviderRegistry`, and covered by the full §12 three-layer test suite.

**Non-goals:**
- Streaming / partial images (`partial_images`, `stream=true`)
- Image edit or variation endpoints (`/v1/images/edits`, `/v1/images/variations`)
- Image-to-image mode (OpenAI Images API does not support an explicit I2I endpoint at this time)
- `gpt-image-1-mini` / `gpt-image-1.5` / `gpt-image-2` variants (plan for future extension point)
- Batch `n > 1` (API supports it but InkFrame batch is not wired end-to-end)

---

## Architecture

### Why `openai-image`, not `dalle-3`

DALL-E 3 was **retired on 2026-03-04** and is no longer available. The current recommended model is `gpt-image-1` (launched April 2025). `providerId = "openai-image"` is the right kebab-case identifier because:
1. `PROVIDER-API.md §13` already lists `openai-image` as a whitelisted custom-provider protocol identifier — using the same string for the built-in implementation signals the canonical implementation of that protocol.
2. It avoids locking the name to a specific model generation (`dalle-3` is dead, `dalle-4` doesn't exist yet).

### Sync vs Async

The OpenAI Images API is **synchronous**: `POST /v1/images/generations` returns the image in the same HTTP response, with no polling endpoint. This mirrors the existing `GeminiImageProvider` pattern and uses the ADR-0004 inline-bytes data channel:

- `submit()` calls the API, base64-decodes the returned `b64_json`, writes bytes to `_inlineCache`, and returns a `local://openai-image/<jobId>-<rand>` synthetic `JobId`.
- `poll()` drains the cache entry and returns `JobStatus.success(remoteUrls: [], inlineBytes: [bytes])`.
- The provider `implements Submittable, Pollable, KeyValidatable` — same interface set as `GeminiImageProvider`.
- `capabilities.supportsPolling = true`, `supportsCancellation = false`.

### API Endpoint Details (authoritative as of 2026-06-10)

| Parameter | Value |
|---|---|
| Base URL | `https://api.openai.com/v1` |
| Submit endpoint | `POST /images/generations` |
| Auth | `Authorization: Bearer <key>` header |
| Model ID | `gpt-image-1` |
| Key validation endpoint | `GET /models` (zero quota consumed) |

**Request body fields used:**

| Field | Value sent |
|---|---|
| `model` | `"gpt-image-1"` |
| `prompt` | `task.prompt` |
| `n` | `1` (fixed — batch not wired) |
| `size` | Mapped from `task.aspectRatio` + `task.resolution` — see size mapping table below |
| `quality` | `"medium"` (fixed default; future: expose via `GenerationTask` extension) |
| `response_format` | `"b64_json"` (always — avoids CDN URL expiry complexity for a sync provider) |

**Size mapping** (`AspectRatio` → `size` string for `gpt-image-1`):

| `AspectRatio` | `size` |
|---|---|
| `r1x1` | `"1024x1024"` |
| `r16x9` | `"1536x1024"` |
| `r9x16` | `"1024x1536"` |
| `r4x3` | `"1536x1024"` (closest supported; no exact 4:3) |
| `r3x4` | `"1024x1536"` (closest supported; no exact 3:4) |
| `r21x9` | `"1536x1024"` (closest supported; note mismatch in capabilities) |

**Note on `r4x3` / `r3x4` / `r21x9`:** These ratios are not exactly representable in gpt-image-1's three supported sizes. The plan lists them as **not included in `supportedRatios`** — declare only `[r1x1, r16x9, r9x16]` to avoid misleading the UI. Users will see exactly what the model can produce.

**Response shape (success):**
```json
{
  "created": 1718000000,
  "data": [
    { "b64_json": "<base64-encoded PNG bytes>" }
  ]
}
```

**Error response shape:**
```json
{
  "error": {
    "message": "Incorrect API key provided: sk-...",
    "type": "invalid_request_error",
    "code": "invalid_api_key"
  }
}
```

**HTTP status → InkError mapping:**

| HTTP | OpenAI `error.code` | `InkError` |
|---|---|---|
| 401 | `invalid_api_key` / `invalid_authentication` | `ProviderError(invalidKey)` |
| 402 | `insufficient_quota` | `ProviderError(insufficientBalance)` |
| 429 | `rate_limit_exceeded` | `ProviderError(providerBusy, retryAfter)` |
| 400 | `content_policy_violation` | `ProviderError(contentPolicy)` |
| 400 | other | `ProviderError(invalidParameter)` |
| 5xx | `server_error` / `engine_overloaded` | `ProviderError(providerServer)` |
| connection / TLS | — | `NetworkError(networkTimeout)` / `NetworkError(networkOffline)` |

> **Content policy detection:** OpenAI 400 errors do NOT signal content policy by HTTP status alone. Before delegating to `mapDioError()`, inspect `error.code == "content_policy_violation"` in the response body. This is the same pre-check pattern as `GeminiImageProvider._isContentPolicy()`.

### Capabilities

```dart
const ProviderCapabilities kOpenAIImageCapabilities = ProviderCapabilities(
  providerId: 'openai-image',
  region: ProviderRegion.global,
  modes: [GenerationMode.textToImage],
  supportedRatios: [AspectRatio.r1x1, AspectRatio.r16x9, AspectRatio.r9x16],
  supportedResolutions: [Resolution.p1080],
  supportedDurations: [],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: 0,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: false,
  supportsSeed: false,          // gpt-image-1 has no seed parameter
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: false,
  supportsPolling: true,        // ADR-0004: sync provider still implements Pollable
  costModel: CostModel.perCall(usdPerCall: 0.042),  // medium quality 1024×1024
  maxConcurrentJobs: 1,
  qps: 2,
  burst: 5,
);
```

**Cost model note:** `gpt-image-1` uses token-based billing internally but OpenAI's published per-image estimates are ~$0.02 (low), ~$0.042 (medium), ~$0.167 (high) for 1024×1024. `CostModel.perCall` with the medium price is the most honest single-value approximation for the capabilities UI. The `CostModel` sealed union does not have a `perToken` variant; `perCall` is the contract-compliant choice. The UI already shows "as per provider billing" disclaimer.

### Rate Limiter

OpenAI Images API: no published fixed QPS, but practical "Tier 1" accounts receive 5 images/min and higher tiers get more. Using `qps: 2, burst: 5` as a conservative default consistent with `PROVIDER-API.md §7.1` comparables.

---

## Tech Stack

Flutter Desktop · Dart · Riverpod (`keepAlive`) · `dio` · `http_mock_adapter` (tests) · `freezed` (models, already generated, no new freezed types needed for this provider) · `flutter_secure_storage` (key access via `SecureStorageKeys`) · `dart:convert` (base64)

---

## Preconditions / Known Limitations

### CRITICAL: Fixture E2E layer (§12.3) requires a real OpenAI API key

`PROVIDER-API.md §12.3` states: fixtures must be captured from a real API call and desensitised — hand-written fixtures are **forbidden**. If no API key is available at plan execution time:

- **Task 1–5 proceed without a key** (unit tests + ProviderContractSuite use mocked Dio — zero real calls).
- **Task 6 (fixture-replay E2E) is BLOCKED** and must be marked `BLOCKED-pending-key` until a key is provided.
- The executor **must not fabricate fixture JSON**. Running `flutter test` with Task 6 skipped is a valid, shippable state for the non-E2E tasks.

To unblock Task 6:
1. Set env var `OPENAI_API_KEY=sk-...` in the shell.
2. Run the one-shot capture script described in Task 6.
3. Desensitise and commit the fixtures.
4. Run `flutter test test/providers/openai_image_provider_test.dart` — all groups should pass.

### Git staging hygiene — env churn files

**Never stage these files** — they are auto-generated by Flutter and contain machine-local state:
- `pubspec.lock`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugin_registrant.h`
- `windows/flutter/generated_plugins.cmake`

Use **file-specific `git add`** for every commit in this plan. Never `git add -A` or `git add .`.

### `ProviderCapabilities.supportsPolling` field

The PROVIDER-API.md §3 doc block does not list `supportsPolling` as a named field, but the actual freezed class in `lib/core/models/provider_capabilities.dart` **does** include `required bool supportsPolling`. The Gemini provider sets it to `true`. This plan follows the actual code, not the doc block (code wins per §1 conflict rule).

### `ProviderError` constructor form

The actual `ink_error.dart` defines `ProviderError` as a `final class` with `const ProviderError({required super.code, ...})` — there are no named factory constructors like `ProviderError.invalidKey()`. The PROVIDER-API.md §6.1 pseudocode uses shorthand names for readability. The correct call site is `ProviderError(code: InkErrorCode.invalidKey, ...)`.

---

## File Structure

| Action | Path | Responsibility |
|---|---|---|
| Create | `lib/providers/openai_image_provider.dart` | Provider implementation |
| Modify | `lib/core/di/providers.dart` | Register `openai-image` in ProviderRegistry |
| Modify | `lib/core/constants/secure_storage_keys.dart` | Add `'openai-image': 'OpenAI'` to `_familyDisplayNames` for a friendly Settings label (without it the UI shows the raw `openai-image` id). Provider names are NOT i18n — they resolve from this Dart map, not ARB. |
| Modify | `lib/l10n/app_en.arb` | No new keys needed — all user-visible error messageKeys already exist |
| Modify | `lib/l10n/app_zh.arb` | Same — no new keys |
| Create | `test/providers/openai_image_provider_test.dart` | Unit + contract tests (no real key) |
| Create | `test/fixtures/providers/openai-image/submit_success.json` | Real API fixture (Task 6, BLOCKED-pending-key) |
| Create | `test/fixtures/providers/openai-image/submit_invalid_key.json` | Real API fixture (Task 6, BLOCKED-pending-key) |
| Create | `test/fixtures/providers/openai-image/submit_content_policy.json` | Real API fixture (Task 6, BLOCKED-pending-key) |
| Create | `test/fixtures/providers/openai-image/submit_rate_limited.json` | Real API fixture (Task 6, BLOCKED-pending-key) |
| Create | `test/fixtures/providers/openai-image/models_list_success.json` | Real API fixture (Task 6, BLOCKED-pending-key) |
| Modify | `docs/PROVIDER-API.md` §9.1 差异矩阵 | Add `openai-image` row |
| Modify | `docs/CLAUDE.md` (Project Structure section) | Add `openai_image_provider.dart` to providers list |

---

## Task 1 — Provider skeleton + capabilities const (RED: compile-only guard)

**Files:**
- Create: `lib/providers/openai_image_provider.dart`

### Steps

- [ ] **1.1 RED — write failing test guard.** In `test/providers/openai_image_provider_test.dart`, add a single test that imports `openai_image_provider.dart` and asserts `kOpenAIImageCapabilities.providerId == 'openai-image'`. Run:
  ```
  /c/Users/Kerro/flutter/bin/flutter.bat test test/providers/openai_image_provider_test.dart --no-pub
  ```
  Expected: compile error (file does not exist).

- [ ] **1.2 GREEN — create the file.** Create `lib/providers/openai_image_provider.dart` with:
  - The `const` block: `kOpenAIBaseUrl`, `kOpenAIImagePath`, `kOpenAIValidatePath`, `kOpenAIModel`, `kOpenAILocalJobPrefix`.
  - `const kOpenAIImageCapabilities = ProviderCapabilities(...)` — all fields explicitly set per the Architecture section above.
  - Class skeleton `class OpenAIImageProvider implements Submittable, Pollable, KeyValidatable` with `get capabilities => kOpenAIImageCapabilities` and three unimplemented method stubs that `throw UnimplementedError()` temporarily (will be replaced in Tasks 2–4).
  - Constructor: `OpenAIImageProvider({required OpenAIKeySource keySource, required ProviderRateLimiter rateLimiter, Dio? dio})`.
  - `typedef OpenAIKeySource = Future<String> Function();`
  - Instance-scoped `final Map<JobId, Uint8List> _inlineCache = {};`

- [ ] **1.3 Verify.** Run the test from 1.1 again — it must pass. Run `flutter analyze` — zero errors.

---

## Task 2 — `validateApiKey` (RED → GREEN)

**Files:**
- Modify: `lib/providers/openai_image_provider.dart`
- Modify: `test/providers/openai_image_provider_test.dart`

### Steps

- [ ] **2.1 RED — write test group `'OpenAIImageProvider.validateApiKey'`.** Add these cases (all mock Dio, no real HTTP):
  - `200 from GET /v1/models → KeyValid`
  - `401 badResponse → KeyInvalid(invalidKey)`
  - `402 badResponse → KeyInvalid(insufficientBalance)`
  - `connectionTimeout → KeyInvalid(networkTimeout)`
  - `connectionError → KeyInvalid(networkOffline)`
  - `500 badResponse → KeyNetworkError(message contains '500')`

  Use `DioAdapter` from `http_mock_adapter` exactly as in `gemini_image_provider_test.dart`. Run tests — expect failures.

- [ ] **2.2 GREEN — implement `validateApiKey`.** Pattern mirrors `GeminiImageProvider.validateApiKey` exactly, substituting:
  - `GET kOpenAIValidatePath` (`/models`)
  - Auth via `Options(headers: {'Authorization': 'Bearer $key'})` instead of `?key=` query param.
  - 401 → `KeyInvalid(invalidKey)`, 402 → `KeyInvalid(insufficientBalance)`, 500 → `KeyNetworkError`.

- [ ] **2.3 Verify.** Run `validateApiKey` test group — all pass. `flutter analyze` — zero errors.

---

## Task 3 — `submit()` (RED → GREEN)

**Files:**
- Modify: `lib/providers/openai_image_provider.dart`
- Modify: `test/providers/openai_image_provider_test.dart`

### Steps

- [ ] **3.1 RED — write test group `'OpenAIImageProvider.submit'`.** Cases (all mock Dio):

  | Test name | Mock response | Expected outcome |
  |---|---|---|
  | 成功返回 `local://` JobId | 200 + inline fixture JSON with `data[0].b64_json` (minimal 1px PNG base64) | `jobId.startsWith(kOpenAILocalJobPrefix)` |
  | 401 → `ProviderError(invalidKey)` | 401 DioException | `ProviderError` with `code == InkErrorCode.invalidKey` |
  | 402 → `ProviderError(insufficientBalance)` | 402 DioException | `code == insufficientBalance` |
  | 429 → `ProviderError(providerBusy)` retryable | 429 DioException | `code == providerBusy`, `retryable == true` |
  | 400 content_policy_violation → `ProviderError(contentPolicy)` | 400 DioException with body `{"error":{"code":"content_policy_violation"}}` | `code == contentPolicy` |
  | 400 other → `ProviderError(invalidParameter)` | 400 DioException with generic body | `code == invalidParameter` |
  | 503 → `ProviderError(providerServer)` retryable | 503 DioException | `code == providerServer`, `retryable == true` |
  | 空 prompt 本地拒绝 | — (no HTTP mock needed) | `ProviderError(invalidParameter)` thrown before acquire() |
  | 非 textToImage 模式本地拒绝 | — | `ProviderError(invalidParameter)` |
  | `data` 数组空 → `ProviderError(providerServer)` | 200 + `{"data":[]}` | `code == providerServer` |
  | `b64_json` 字段缺失 → `ProviderError(providerServer)` | 200 + `{"data":[{"url":"http://..."}]}` (no b64_json) | `code == providerServer` |
  | submit 失败后 cache 为空 | 500 DioException | subsequent `poll(any-id)` throws `ProviderError(providerServer, reason: cache_miss_or_consumed)` |

  Run — expect failures.

- [ ] **3.2 GREEN — implement `submit()`.** Structure:
  1. Mode guard: if `task.mode != GenerationMode.textToImage` throw `ProviderError(invalidParameter)`.
  2. Prompt guard: if `task.prompt.trim().isEmpty` throw `ProviderError(invalidParameter)`.
  3. `await _rateLimiter.acquire()`.
  4. `final key = await _keySource()`.
  5. Build request body: `{'model': kOpenAIModel, 'prompt': task.prompt, 'n': 1, 'size': _sizeFor(task.aspectRatio), 'quality': 'medium', 'response_format': 'b64_json'}`.
  6. `POST kOpenAIImagePath` with `Authorization: Bearer $key` header.
  7. Parse response: navigate `data[0].b64_json`, base64-decode to `Uint8List`.
  8. On success: generate `jobId = '$kOpenAILocalJobPrefix${task.jobId}-${_rand()}'`, write to `_inlineCache[jobId]`, return `jobId`.
  9. On `DioException`: before delegating to `mapDioError()`, check `e.response?.statusCode == 400 && _isContentPolicyViolation(e.response?.data)` → throw `ProviderError(contentPolicy)`. Otherwise call `throw mapDioError(e, providerId: capabilities.providerId)`.
  10. Never write to `_inlineCache` if an exception is thrown (submit failure guard).

  Helper `_sizeFor(AspectRatio ratio) → String`:
  - `r1x1 → "1024x1024"`, `r16x9 → "1536x1024"`, `r9x16 → "1024x1536"`, others fallback to `"1024x1024"` (unreachable if capabilities.supportedRatios is honoured by UI).

  Helper `_isContentPolicyViolation(Object? body) → bool`:
  - Check `body is Map && body['error'] is Map && body['error']['code'] == 'content_policy_violation'`.

  Helper `_rand()` — identical to Gemini's: `Random.secure().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0')`.

- [ ] **3.3 Verify.** Run `submit` group — all pass. `flutter analyze` — zero errors.

---

## Task 4 — `poll()` sync channel (RED → GREEN)

**Files:**
- Modify: `lib/providers/openai_image_provider.dart`
- Modify: `test/providers/openai_image_provider_test.dart`

### Steps

- [ ] **4.1 RED — write test group `'OpenAIImageProvider.poll (sync provider channel)'`.** Cases:
  - `submit→poll 一次成功返回 inlineBytes 且 remoteUrls 为空` — mirror exact test from `gemini_image_provider_test.dart` (mock 200 submit, then `poll(jobId)`, assert `isA<JobSuccess>()`, `remoteUrls.isEmpty`, `inlineBytes.length == 1`, `inlineBytes.first.isNotEmpty`).
  - `重复 poll 同一 jobId → ProviderError(providerServer, reason: cache_miss_or_consumed)` — same pattern as Gemini test.
  - `submit 失败时不在 cache 留任何 jobId` — mock 500 submit, confirm poll throws `ProviderError` with `reason: cache_miss_or_consumed`.

  Run — expect failures (stubs throw `UnimplementedError`).

- [ ] **4.2 GREEN — implement `poll()`.** Exact mirror of `GeminiImageProvider.poll()`:
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

- [ ] **4.3 Verify.** Run `poll` group — all pass. Run full provider test file — all pass. `flutter analyze` — zero errors.

---

## Task 5 — DI wiring + ProviderContractSuite (RED → GREEN)

**Files:**
- Modify: `lib/core/di/providers.dart`
- Modify: `test/providers/openai_image_provider_test.dart`

### Steps

- [ ] **5.1 RED — write test group `'OpenAIImageProvider capabilities contract'`.** Cases:
  - `providerId == 'openai-image'`
  - `region == ProviderRegion.global`
  - `supportsPolling == true`
  - `supportsCancellation == false`
  - `supportsSeed == false`
  - `supportsNegativePrompt == false`
  - `modes == [GenerationMode.textToImage]`
  - `supportedRatios` contains `r1x1, r16x9, r9x16` and does NOT contain `r4x3, r3x4, r21x9`
  - `qps == 2`, `burst == 5`
  - `maxBatchSize == 1`
  - `costModel` is `PerCall` variant
  - `capabilities` field is accessible without instantiating the provider (via `kOpenAIImageCapabilities` const directly)

  Also write `'ProviderContractSuite: openai-image'` group that validates the interface contracts:
  - `OpenAIImageProvider implements Submittable` — static check (compile-time; just instantiate and assign to a `Submittable` variable)
  - `OpenAIImageProvider implements Pollable` — same
  - `OpenAIImageProvider implements KeyValidatable` — same
  - `OpenAIImageProvider does NOT implement Cancellable` — verified by absence of `cancel` method (dart:mirrors not needed; just document this as a comment in the test)

  Run — should pass (capabilities const already set in Task 1; this is mostly a regression guard).

- [ ] **5.2 GREEN — wire into DI.** In `lib/core/di/providers.dart`:
  1. Add import: `import '../../providers/openai_image_provider.dart';`
  2. Add `ProviderRateLimiter` instance:
     ```dart
     final openAIImageRl = ProviderRateLimiter(
       qps: kOpenAIImageCapabilities.qps,
       burst: kOpenAIImageCapabilities.burst,
     );
     ```
  3. Add entry to `ProviderRegistry`:
     ```dart
     kOpenAIImageCapabilities.providerId: () => OpenAIImageProvider(
       keySource: keyFor(kOpenAIImageCapabilities.providerId),
       rateLimiter: openAIImageRl,
     ),
     ```
  4. Update the comment block at the top of the file to list `openai-image`.
  5. In `lib/core/constants/secure_storage_keys.dart`, add `'openai-image': 'OpenAI'` to the `_familyDisplayNames` map so Settings renders "OpenAI" instead of the raw id. Add a test (in `test/core/constants/`, or extend the existing secure-storage-keys test) asserting `SecureStorageKeys.displayNameOf('openai-image') == 'OpenAI'` — RED before the map edit, GREEN after. No ARB key.

- [ ] **5.3 Verify.** Run:
  ```
  /c/Users/Kerro/flutter/bin/flutter.bat test --no-pub
  ```
  All existing tests pass. `flutter analyze` — zero errors.

  Confirm `openai-image` is visible:
  ```
  /c/Users/Kerro/flutter/bin/flutter.bat test test/core/di/ --no-pub
  ```

---

## Task 6 — Fixture-replay E2E (`BLOCKED-pending-key`)

> **STATUS: BLOCKED — requires a real OpenAI API key.**
> Do NOT fabricate fixture JSON. Do NOT skip and mark "done".
> This task is skippable for a shippable state (Tasks 1–5 cover all non-E2E contract requirements).
> Unblock by following the capture procedure below once a key is available.

**Files:**
- Create: `test/fixtures/providers/openai-image/submit_success.json`
- Create: `test/fixtures/providers/openai-image/submit_invalid_key.json`
- Create: `test/fixtures/providers/openai-image/submit_content_policy.json`
- Create: `test/fixtures/providers/openai-image/submit_rate_limited.json`
- Create: `test/fixtures/providers/openai-image/models_list_success.json`
- Modify: `test/providers/openai_image_provider_test.dart` (add fixture-replay group)

### Steps

- [ ] **6.1 RED — write fixture-replay test group.** Add group `'OpenAIImageProvider fixture-replay E2E'` to the test file. Each test loads a fixture via `loadProviderFixture('openai-image', '<name>')` (same helper as Gemini tests). Tests will fail with `fixture not found` until Step 6.3.

  Tests in this group:
  - `submit_success fixture → local:// JobId + inlineBytes round-trip` — identical pattern to Gemini submit_success test.
  - `submit_invalid_key fixture → ProviderError(invalidKey)` — DioException mock backed by real fixture.
  - `submit_content_policy fixture → ProviderError(contentPolicy)`.
  - `submit_rate_limited fixture → ProviderError(providerBusy)`.
  - `models_list_success fixture → validateApiKey returns KeyValid`.

- [ ] **6.2 Confirm key available.** Check `$env:OPENAI_API_KEY` is set to a live key with a non-zero image generation quota.

- [ ] **6.3 Capture real API responses.** Run a one-shot Dart capture script (create as `tool/capture_openai_fixtures.dart`, do NOT commit the script with the key embedded — use environment variable):
  - `GET /v1/models` → save as `models_list_success.json` (strip any sensitive field; `id`/`object`/`created` fields are fine).
  - `POST /v1/images/generations` with a benign prompt → save as `submit_success.json`. In the saved fixture, replace the `b64_json` value with the canonical 1×1 transparent PNG base64: `iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==` (this is the same desensitised bytes used by the Gemini fixture — it is a real decodable PNG, just not the generated image).
  - Trigger a real 401 by calling `/v1/images/generations` with `Authorization: Bearer invalid-key-fixture` → save error body as `submit_invalid_key.json`.
  - For `submit_content_policy.json` and `submit_rate_limited.json`: if live capture is not feasible, build the fixtures from the documented OpenAI error response structure (these are error-only responses with no image data, so constructing them from the spec is acceptable — only the _success image payload_ is forbidden to fabricate). Document this in the fixture file with a JSON comment-style field `"_fixture_note": "constructed from spec; no image payload"`.

- [ ] **6.4 Desensitise.** Verify no API key, real job ID, or real user data remains in any fixture. Replace any real job IDs with `"FIXTURE_JOB_ID"`.

- [ ] **6.5 GREEN — run fixture tests.** Run:
  ```
  /c/Users/Kerro/flutter/bin/flutter.bat test test/providers/openai_image_provider_test.dart --no-pub
  ```
  All groups pass, including `fixture-replay E2E`.

- [ ] **6.6 Stage fixtures specifically.** Use explicit `git add`:
  ```
  git add test/fixtures/providers/openai-image/submit_success.json \
          test/fixtures/providers/openai-image/submit_invalid_key.json \
          test/fixtures/providers/openai-image/submit_content_policy.json \
          test/fixtures/providers/openai-image/submit_rate_limited.json \
          test/fixtures/providers/openai-image/models_list_success.json
  ```

---

## Task 7 — Documentation updates

**Files:**
- Modify: `docs/PROVIDER-API.md`
- Modify: `docs/CLAUDE.md`

### Steps

- [ ] **7.1 Update `PROVIDER-API.md §9.1`** (P0 Provider 差异矩阵). Add row to the table:

  | `openai-image` | `gpt-image-1` | `https://api.openai.com/v1` | Bearer Token | `POST /images/generations` | 同步，无轮询 | P1-GA |

- [ ] **7.2 Update `PROVIDER-API.md §9.2`** (能力差异速查). Add column:

  | 能力 | openai-image |
  |---|:-:|
  | 模式 | T2I |
  | 分辨率 | 1080p |
  | 视频时长 | — |
  | 运镜 | — |
  | 参考图 | 0 |
  | 批量 | ❌ |
  | 负向 prompt | ❌ |
  | Seed | ❌ |
  | 取消 | N/A（同步） |
  | 轮询 | ❌（同步） |
  | QPS / Burst | 2 / 5 |
  | 并发 | 1 |

- [ ] **7.3 Update `docs/CLAUDE.md`** Project Structure section — add `openai_image_provider.dart` to the `lib/providers/` listing.

- [ ] **7.4 Verify compile + test.** Run full suite:
  ```
  /c/Users/Kerro/flutter/bin/flutter.bat test --no-pub
  ```
  All pass. `flutter analyze` — zero errors or warnings.

---

## Task 8 — Final gate: §10 nine-step checklist verification

- [ ] Step 1 ✅ Capabilities const in provider file top (`kOpenAIImageCapabilities`)
- [ ] Step 2 ✅ Access parameters as consts at file top (`kOpenAIBaseUrl`, `kOpenAIImagePath`, `kOpenAIValidatePath`, `kOpenAIModel`, `kOpenAILocalJobPrefix`)
- [ ] Step 3 ✅ Interface set: `Submittable + KeyValidatable + Pollable` (sync ADR-0004 path; no `Cancellable`)
- [ ] Step 4 ✅ `validateApiKey` uses `GET /v1/models` — zero generation quota consumed
- [ ] Step 5 ✅ `submit()` calls `await _rateLimiter.acquire()` before `_dio.post()`
- [ ] Step 6 ✅ `poll()` is single-call cache drain — no internal loop, no network
- [ ] Step 7 ✅ All `DioException`s pass through `mapDioError()`; content-policy pre-check before delegation
- [ ] Step 8 ✅ Registered in `lib/core/di/providers.dart` with shared `ProviderRateLimiter`
- [ ] Step 9 ✅ Three-layer tests: unit error-matrix (Tasks 2–4), ProviderContractSuite (Task 5), fixture-replay E2E (Task 6)

### PR review checklist

- [ ] `rg 'Color\(|fontSize:|FontWeight\.' lib/providers/openai_image_provider.dart` → 0 results
- [ ] `rg 'flutter/material|flutter/widgets' lib/providers/openai_image_provider.dart` → 0 results
- [ ] `rg 'throw Exception|throw .*Error[^(]' lib/providers/openai_image_provider.dart` → 0 results
- [ ] All `capabilities` fields explicitly set — no nulls
- [ ] i18n: no new ARB keys required (all error messageKeys already present in `app_en.arb` / `app_zh.arb`)
- [ ] `pubspec.lock`, `windows/flutter/generated_*`, `macos/Flutter/GeneratedPluginRegistrant.swift` NOT staged

---

## References

- OpenAI Images API guide: https://developers.openai.com/api/docs/guides/image-generation
- OpenAI Images `POST /v1/images/generations` reference: https://developers.openai.com/api/reference/resources/images/methods/generate
- OpenAI `gpt-image-1` model card: https://developers.openai.com/api/docs/models/gpt-image-1
- OpenAI error codes guide: https://developers.openai.com/api/docs/guides/error-codes
- OpenAI API pricing: https://developers.openai.com/api/docs/pricing
- InkFrame Provider API contract: `docs/PROVIDER-API.md`
- ADR-0004 (inline bytes sync channel): `docs/PROVIDER-API.md §5.5`
- Canonical sync provider reference implementation: `lib/providers/gemini_image_provider.dart`
