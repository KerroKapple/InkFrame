# InkFrame v2 — Architecture Reference

> Human-readable companion to CLAUDE.md.
> CLAUDE.md is the enforced ruleset. This document explains the *why* behind every constraint.

---

## Core Philosophy

**Every architectural decision answers one question: can I test this in isolation?**

If a widget, provider, or service cannot be tested without a real database, real network,
or real UI — the architecture is wrong. Fix the architecture, not the test.

---

## Layered Architecture

```
┌──────────────────────────────────────────┐
│              Widget Layer                │  Stateless/Stateful widgets
│   (renders state, emits user events)     │  ConsumerWidget reads providers
│                                          │  Never imports concrete services
├──────────────────────────────────────────┤
│            ViewModel Layer               │  Riverpod Notifier / AsyncNotifier
│   (orchestrates, no business logic)      │  autoDispose — screen-scoped
│                                          │  Calls service interfaces only
├──────────────────────────────────────────┤
│             Service Layer                │  Pure Dart — zero Flutter imports
│   (use cases, domain logic)              │  Implements abstract interfaces
│                                          │  Injected via Riverpod providers
├──────────────────────────────────────────┤
│           Repository Layer               │  Data access abstraction
│   (storage contracts)                    │  Abstract interface in core/
│                                          │  Concrete impl in storage/
├──────────────────────────────────────────┤
│          Infrastructure Layer            │  PostgreSQL, dio, ffmpeg, Keychain
│   (external systems)                     │  Never referenced above this layer
└──────────────────────────────────────────┘
```

**Rule: dependencies only flow downward.**
Widget → ViewModel → Service → Repository → Infrastructure.
No layer imports from a layer above it.

---

## Dependency Injection Pattern (Riverpod)

All dependencies are wired through Riverpod providers defined in `lib/core/di/`.
Widgets and ViewModels never import concrete implementations.

```
lib/core/interfaces/generation_provider.dart   ← abstract interface
lib/providers/kling_provider.dart              ← KlingProvider implements GenerationProvider
lib/core/di/generation.dart                    ← klingProviderProvider = Provider((ref) => KlingProvider(...))
lib/features/generation/providers/job.dart     ← ref.watch(generationProviderProvider)
```

### Lifecycle Rules

| Scope | Riverpod Modifier | Example |
|---|---|---|
| App singleton | `keepAlive` | Database, dio, repositories, **JobQueueService**, **FileResolverService**, **PerformanceDegradationController**, **SecureStorageService**, **LoggerService** |
| Per-provider | `keepAlive` family | **ProviderRateLimiter(providerId)** — token bucket state must survive screen switches |
| Screen/feature | `autoDispose` | ViewModels, controllers, form state, inline panel state |
| Job queue | `keepAlive` | JobQueueService — outlives screens |
| Transient | `autoDispose` | API call state, dialog state, IME composing guard |

```dart
// ✅ Correct — lifecycle declared explicitly
@riverpod
class JobViewModel extends _$JobViewModel {
  // autoDispose by default with code gen
}

@Riverpod(keepAlive: true)
DatabaseConnection database(DatabaseRef ref) {
  final db = DatabaseConnection();
  ref.onDispose(db.close);  // cleanup always registered
  return db;
}

// ❌ Wrong — no lifecycle, no cleanup
final db = DatabaseConnection(); // global mutable singleton
```

---

## SOLID in Practice

### S — Single Responsibility Examples

```
GenerationWidget       → renders job list, nothing else
JobSubmissionService   → submits jobs, no rendering
KlingProvider          → Kling API only, no storage
PostgresJobRepository  → SQL queries only, no business logic
```

### O — Open/Closed: Provider Strategy Pattern

```dart
// Adding a new provider = one new file, zero changes to existing code
abstract class GenerationProvider {
  Future<JobId> submit(GenerationTask task);
}

class KlingProvider    implements GenerationProvider { ... }
class SeedanceProvider implements GenerationProvider { ... }
class WanxProvider     implements GenerationProvider { ... }
// ← add BananaProvider here. Touch nothing else.
```

### I — Interface Segregation

```dart
// Not all providers support all capabilities — split the interfaces
abstract class Submittable { Future<JobId> submit(GenerationTask task); }
abstract class Pollable    { Future<JobStatus> poll(JobId id); }
abstract class Cancellable { Future<void> cancel(JobId id); }
abstract class QuotaAware  { Future<Quota> getQuota(); }

// KlingProvider supports all four
class KlingProvider implements Submittable, Pollable, Cancellable, QuotaAware {}

// A provider without cancellation support doesn't need to fake it
class SimpleProvider implements Submittable, Pollable {}
```

### D — Dependency Inversion

```dart
// ✅ Widget depends on abstract ViewModel interface
class GenerationPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobViewModelProvider); // abstract AsyncValue
    ...
  }
}

// ❌ Widget knows about concrete repository
class GenerationPanel extends StatelessWidget {
  final PostgresJobRepository repo; // violation — depends on concretion
}
```

---

## Design Token System

Tokens live in `lib/theme/tokens.dart` as static const values.
`lib/theme/app_theme.dart` builds `ThemeData` exclusively from tokens.
Widgets consume tokens or Ink components — never raw values.

```
Raw value  →  Token constant     →  ThemeData extension  →  Widget usage
#0F0F13    →  InkColors.surface1 →  context.inkColors     →  InkCard default bg
#1C1C24    →  InkColors.surface2 →  context.inkColors     →  InkCard elevated
12.0       →  InkRadius.lg       →  —                     →  InkCard border radius
16.0       →  InkSpacing.md      →  —                     →  InkCard padding
```

`lib/theme/components/` — the only place raw token values are used directly.
Feature code always uses Ink components (`InkCard`, `InkButton`, etc.).

`InkColors` exposes three factories — `dark()`, `light()`, `highContrast()` —
selected by `ThemeModeController` which observes:
1. Settings → General → Theme (`dark` / `light` / `system`)
2. `PlatformDispatcher.platformBrightnessChanged` (when `system`)
3. Settings → General → High Contrast (overrides 1 & 2)

`context.inkColors` returns the resolved set. Widgets never branch on theme —
they just read tokens, and the token set is swapped.

---

## i18n Architecture

```
Widget calls context.l10n.someKey
    → flutter_localizations resolves key
    → reads from active ARB file
    → app_en.arb  or  app_zh.arb
```

Keys are grouped by feature prefix: `canvas*`, `generation*`, `settings*`, `common*`.

CI enforces: `app_en.arb` and `app_zh.arb` must have **identical key sets**.
A missing translation is a build failure, not a runtime warning.

System prompts (Gemini, provider hints) also go through ARB —
they are user-facing in the sense that they affect output quality
and must be translatable for future locale expansion.

---

## Error Handling Flow

```
KlingProvider throws ProviderException(code: 429, message: "rate limited")
    → JobSubmissionService catches ProviderException, wraps in ServiceError
    → JobViewModel catches ServiceError, calls state = AsyncError(...)
    → Widget reads AsyncValue, renders InkErrorBanner
    → InkErrorBanner displays context.l10n.errorProviderRateLimit
```

Rules:
- NO bare `catch (e)` — always catch specific exception types
- NO `print()` / `debugPrint()` as error handling — errors must surface to UI or be explicitly swallowed with a comment
- Every `AsyncNotifier` exposes errors via `AsyncValue` — widgets use `.when()` to handle all states

---

## Error Taxonomy

All errors implement `InkError` with a discriminated `code` from PRD §10.6.

```dart
sealed class InkError implements Exception {
  String get code;               // 'invalid_key' | 'network_timeout' | ...
  String get messageKey;         // i18n ARB key, e.g. 'errorInvalidKey'
  bool   get retryable;          // drives retry policy in JobQueueService
  Map<String, Object?> get extra;
}

final class ProviderError  extends InkError {}   // auth / quota / request validation
final class NetworkError   extends InkError {}   // timeout / offline / 5xx / busy
final class DownloadError  extends InkError {}   // download_failed
final class LocalIOError   extends InkError {}   // disk full / permission denied
final class CancelledError extends InkError {}   // by_user / on_exit
```

**Rule:** No layer above Infrastructure may construct raw `Exception`.
Services translate infrastructure exceptions to `InkError` at the boundary.
ViewModels propagate via `AsyncError(InkError)`.
Widgets render via `InkErrorBanner` which reads `messageKey` for i18n.

---

## Concurrency & Rate Limiting

Two-tier throttling, both owned at app scope, both observable via Riverpod:

```
┌─ JobQueueService (global) ──────────────────────────────┐
│  maxConcurrent = PerformanceTier.maxConcurrentJobs      │
│  FIFO across all canvases                               │
│  pending → submitted → polling → terminal               │
└────────────────────┬────────────────────────────────────┘
                     │ acquire global slot
                     ▼
┌─ ProviderRateLimiter(providerId) (per-provider) ────────┐
│  Token bucket: qps + burst                              │
│  Blocks before each HTTP call, not counted as retry     │
└─────────────────────────────────────────────────────────┘
```

Both are `Provider.family` / `keepAlive`. Neither is a static singleton.
Unit tests override both via `ProviderContainer` with fake clocks.

---

## File Path Resolution

Database stores only canvas-relative paths (`images/{uuid}.png`).
No layer holds absolute paths except `FileResolverService`:

```dart
abstract class FileResolverService {
  /// nodes.type_config.image_url → absolute file path
  File resolve(String canvasId, String relativePath);

  /// reverse: dropped file path → canvas-relative path
  String toRelative(String canvasId, File source);
}
```

**Rule:** Widgets and ViewModels MUST go through `FileResolverService`.
Direct `File(nodeState.imageUrl)` is a violation — it breaks data-dir
migration (PRD §12.6) and makes integration tests depend on host filesystem
layout.

---

## freezed Model Pattern

```dart
// Every domain model follows this pattern exactly
@freezed
class GenerationTask with _$GenerationTask {
  const factory GenerationTask({
    required String id,
    required String prompt,
    required TaskStatus status,
    required DateTime createdAt,
    String? referenceImagePath,
  }) = _GenerationTask;

  factory GenerationTask.fromJson(Map<String, dynamic> json)
      => _$GenerationTaskFromJson(json);
}

// ✅ Mutation via copyWith — original is immutable
final updated = task.copyWith(status: TaskStatus.running);

// ❌ Never
task.status = TaskStatus.running;
```

---

## Accessibility

A11y is a layered responsibility, not a one-off review. Rules:

1. **Every Ink component** declares `Semantics(label:)` — widgets receive labels
   via `context.l10n`, never hardcoded strings.
2. **State changes** (job success/error, toast) call `SemanticsService.announce()`.
3. **Focus management** — `FocusNode` trees are owned at ViewModel layer, not
   scattered across widgets.
4. **`MediaQuery.disableAnimations`** is honored globally via a `reduceMotion`
   token; widgets reading animation duration get `Duration.zero` when active.
5. **Keyboard equivalents** — every pointer action has a keyboard counterpart
   registered in `KeybindingRegistry`. CI verifies coverage ≥ 95%.

Scope: PRD §20.1 baseline for v0.1.0. WCAG 2.1 AA certification is out of scope.

---

## Testing Strategy

| Layer | Tool | Pattern |
|---|---|---|
| Models / utils | `flutter_test` | Pure unit, no mocks needed |
| Services | `flutter_test` + `mockito` | Mock repositories via interface |
| Repositories | `flutter_test` + in-memory DB | Real SQL, test schema |
| Providers (Riverpod) | `riverpod_test` | `ProviderContainer` overrides |
| Widgets | `flutter_test` + `ProviderScope` | Override providers with mocks |

**Never test implementation details. Test behavior.**

```dart
// ✅ Tests behavior
test('submitting a job transitions status to running', () async { ... });

// ❌ Tests implementation
test('submit() calls _client.post() once', () async { ... });
```

---

## Security: API Keys

```
User enters API key in Settings UI
    → SecureStorageService.store(provider: 'kling', key: value)
    → macOS: flutter_secure_storage → Keychain
    → Windows: flutter_secure_storage → Credential Manager
    → NEVER written to PostgreSQL, NEVER in dart files, NEVER logged
```

Retrieval at runtime:
```dart
// ✅ Only valid access path
final key = await ref.read(secureStorageProvider).retrieve('kling');

// ❌ All of these are violations
const klingKey = 'sk-...';                     // hardcoded
final key = prefs.getString('kling_api_key');  // insecure storage
final key = db.query('SELECT key FROM ...');   // database — wrong
```

---

## Runtime Performance Degradation

`PerformanceDegradationController` (app-scoped, `keepAlive`) samples:
- Process RSS via `dart:io` / platform channel
- Frame time via `SchedulerBinding.addTimingsCallback`
- Disk free space via `path_provider` + stat

On threshold breach (PRD §3.9.2), it mutates `effectivePerformanceTier` — a
derived provider that token caches, animation durations, and connection renderers
read. Hysteresis (60s cooldown, 30s sustain) prevents flapping.

Degradation is **observable**: widgets never read raw signals, only the derived
tier. The controller is overridable in tests with deterministic signal streams.
