# InkFrame v2 — Project Rules

## Tech Stack

- **Framework**: Flutter Desktop (Dart)
- **State**: Riverpod (manual providers; codegen pending — build_runner toolchain blocked, see `docs/BOARD.md`)
- **Models**: freezed (immutable + copyWith + JSON; generated files checked in)
- **Storage**: Embedded PostgreSQL
- **Network**: dio
- **App metadata**: package_info_plus (version info, About section)
- **i18n**: flutter_localizations + ARB files
- **Video playback / thumbnail**: media_kit (+ media_kit_video, media_kit_libs_video)
- **Video export**: external ffmpeg binary (runtime probe via `FfmpegLocator`; not bundled)
- **Window chrome**: window_manager (frameless shell); screen_retriever (multi-monitor enumeration for window-state restore clamp)
- **File import**: file_selector
- **Secure storage**: flutter_secure_storage (macOS Keychain / Windows Credential Manager); Debug+macOS falls back to a plaintext dev file (see Provider API Keys)
- **Platforms**: macOS + Windows

> Modules not yet implemented (e.g. script parsing / sequence preview) are tracked in `docs/BOARD.md` (status) and the repo-root `ROADMAP.md` (community roadmap). This file only documents what currently exists in the repo — when you add a module, update this file in the same commit.

## Architecture Principles

### SOLID — No Exceptions

- **S**: Every class/widget has ONE responsibility. A widget that fetches data AND renders UI = violation.
- **O**: Open for extension, closed for modification. Use abstract classes/interfaces, not if-else chains.
- **L**: Subtypes must be substitutable. Every Provider implementation must honor the base contract.
- **I**: No fat interfaces. Split `GenerationProvider` into `Submittable`, `Pollable`, `Cancellable` if a provider doesn't support all.
- **D**: Depend on abstractions. Widgets never import concrete providers/repositories directly — always through DI.

### Dependency Injection (Riverpod)

- ALL services injected via Riverpod providers
- NO static singletons, NO global mutable state, NO `ServiceLocator` pattern
- Lifecycle managed by Riverpod: `autoDispose` for transient, `keepAlive` for singletons
- Every injectable must have an abstract interface (for testing)

```dart
// ✅ Correct
abstract class ProjectRepository {
  Future<Project> load(String id);
  Future<void> save(Project project);
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return PostgresProjectRepository(ref.watch(databaseProvider));
});

// ❌ Wrong — concrete dependency, no interface
final projectProvider = Provider((ref) {
  return PostgresProjectRepository(PostgresDatabase());
});
```

### IoC & Lifecycle

- Database connections: app-scoped (created once, disposed on exit)
- HTTP clients: app-scoped (shared dio instance)
- Repositories: app-scoped
- ViewModels/Controllers: screen-scoped (autoDispose)
- Generation jobs: managed by JobQueue, outlive screens

### Zero Backward Compatibility

- NO legacy support code
- NO deprecated APIs kept "just in case"
- NO parallel old-data-format parsing paths
- NO downgrade — an older app opening a newer DB is rejected (`SchemaDowngradeError`), never silently reinterpreted

**Carve-out — user data durability (ADR-0012):** the user's persisted PostgreSQL workspace is the one exception. A schema change MUST NOT wipe or reset the user's data; the database is advanced through the single forward-migration chain (`lib/storage/migrations/`, `schema_version` table). Every schema change ADDS one contiguously-numbered forward migration; shipped migrations are immutable (never edit a released migration — add `v_next`). Single-line forward migration is the *only* supported upgrade path. See `docs/adr/0012-forward-migration-as-sole-data-upgrade-path.md`.

## i18n — Zero Hardcoded Strings

### Rules

1. **i18n covers end-user UI text only.** Strings the user reads on screen go through ARB.
2. **Internal strings stay English-only constants.** This includes:
   - LLM/system prompts sent to providers (a localized prompt = silent A/B on model behavior)
   - Log messages and `module` names
   - Error code identifiers (`InkErrorCode.invalidKey` etc.)
   - SQL, JSON keys, network protocol literals
3. **Development language is English** — all ARB keys and default values in English
4. **Every commit** must have 100% zh-CN and en-US coverage of the keys that DO exist in ARB
5. **CI check**: `app_en.arb` and `app_zh.arb` must have identical key sets (build fails otherwise). Adding more locales later only adds new ARB files; the parity rule generalizes to "all locales share identical key sets."

### File Structure

```
l10n.yaml               # Flutter gen-l10n config (repo root)
lib/l10n/
├── app_en.arb          # English (source of truth)
└── app_zh.arb          # Chinese (must match all keys)
```

### Usage

```dart
// ✅ Correct
Text(context.l10n.canvasNewNodeImage)
Text(context.l10n.generateButtonLabel)
ToastService.show(context.l10n.jobSubmitted(providerName))

// ❌ Wrong — hardcoded string
Text("New Image Node")
Text("生成")
ToastService.show("已提交到 $providerName")
```

### LLM / System Prompts — DO NOT i18n

Prompts sent to AI providers are part of the model contract, not user-facing copy. Keep them as English string constants in `lib/providers/<provider>_prompts.dart` (or inline near the call site for short ones). Translating a system prompt creates a per-locale model behavior fork that is impossible to A/B reason about.

```dart
// ✅ Correct — English-only constant
const _kGeminiImageSystemPrompt = '''
You are an image-generation assistant...
''';

// ❌ Wrong — i18n'd prompt drifts across locales
final hint = context.l10n.geminiSystemPrompt;
```

If you ever need to inject locale-aware text **into** a prompt (e.g. "respond in the user's UI language"), pass the user-facing locale code as a parameter; the prompt template itself stays English.

### Adding a New String

1. Add key + English value to `app_en.arb`
2. Add key + Chinese value to `app_zh.arb`
3. Run `flutter gen-l10n`
4. Use `context.l10n.yourNewKey` in code
5. Both files must be updated in the same commit

## Zero Hardcoded Styles — Design Token System

### Rules

1. **Every color, font size, spacing, radius, shadow** comes from the theme/token system
2. **No inline `Color(0xFF...)` or `fontSize: 14`** in widget code
3. **All visual properties** defined in `lib/theme/` as tokens

### Token Structure

```
lib/theme/
├── tokens.dart         # Color, spacing, radius, shadow tokens
├── app_theme.dart      # ThemeData builder from tokens
├── typography.dart     # Text styles
└── components/         # Reusable styled components
    ├── ink_button.dart
    ├── ink_card.dart
    ├── ink_input.dart
    └── ...
```

### Usage

```dart
// ✅ Correct
Container(
  padding: EdgeInsets.all(InkSpacing.md),
  decoration: BoxDecoration(
    color: context.inkColors.surface2,
    borderRadius: BorderRadius.circular(InkRadius.lg),
    boxShadow: [InkShadow.card],
  ),
)

// ❌ Wrong — hardcoded values
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Color(0xFF2A2A3E),
    borderRadius: BorderRadius.circular(12),
  ),
)
```

### Components Over Primitives

```dart
// ✅ Correct — use design system component
InkCard(
  child: Text(context.l10n.nodeTitle),
)

// ❌ Wrong — raw Container with inline styles
Container(
  decoration: BoxDecoration(...),
  child: Text("Node Title"),
)
```

## Project Structure

> **Snapshot, not blueprint.** Mirrors the current `lib/` tree. Planned-but-unimplemented modules belong in `docs/BOARD.md` (status) and the repo-root `ROADMAP.md` (community roadmap), not here. Keep this in sync — if your PR adds/removes a directory, update this section in the same commit.

```
lib/
├── main.dart                          # Entry point, ProviderScope
├── app.dart                           # MaterialApp, router, theme wiring
├── l10n/                              # ARB files (app_en.arb, app_zh.arb) + gen
├── theme/                             # Design tokens, theme, components
│   ├── tokens.dart                    # Color / spacing / radius / shadow tokens
│   ├── typography.dart                # Text styles
│   ├── motion.dart                    # Animation timings / curves
│   ├── app_theme.dart                 # ThemeData builder from tokens
│   ├── primitives/                    # Low-level styled primitives
│   └── components/                    # Reusable Ink* components
├── core/                              # Shared abstractions (no Flutter imports below interfaces)
│   ├── constants/                     # Enums, numeric constants (no side effects)
│   ├── db/                            # DbRow typing + column-name constants (columns.dart, row_reader.dart)
│   ├── di/                            # Riverpod provider definitions (the only wiring folder)
│   ├── errors/                        # InkError sealed hierarchy + InkErrorCode
│   ├── interfaces/                    # Abstract service / repository contracts
│   ├── logging/                       # InkLogger interface
│   ├── models/                        # Domain models (freezed, immutable)
│   └── paths/                         # app_paths.dart — well-known app directories
├── features/                          # Feature modules (vertical slices)
│   ├── canvas/                        # Node canvas
│   │   ├── models/
│   │   ├── providers/                 # Riverpod ViewModels
│   │   ├── util/
│   │   └── widgets/
│   ├── command_palette/               # ⌘K/Ctrl+K command palette (PL-1; app-level, wraps _UnlockedShell)
│   │   ├── command_actions.dart       # CommandAction + context-aware hardwired action list (≤6)
│   │   └── widgets/                   # palette dialog / top-chrome chip / app-level shortcuts wrapper
│   ├── export/                        # Video export UI (concat dialog; entry in canvas top chrome)
│   │   ├── providers/                 # ExportController (canvas→project path conversion)
│   │   ├── util/                      # Output-name pre-validation
│   │   └── widgets/
│   ├── gallery/                       # Project-wide generated-asset gallery (read-only)
│   │   ├── models/
│   │   ├── providers/
│   │   └── widgets/
│   ├── generation/                    # Generation flow UI + state
│   │   ├── generation_controller.dart
│   │   ├── models/
│   │   ├── providers/
│   │   ├── services/
│   │   └── widgets/
│   ├── settings/                      # Settings surfaces
│   │   ├── settings_screen.dart
│   │   ├── providers/
│   │   └── widgets/
│   ├── startup/                       # Startup failure surface (DB-ready gate; LB-09)
│   │   └── widgets/                   # StartupErrorView (full-screen error + retry + open-log-dir)
│   └── studio/                        # Project / workspace shell (home + open-canvas)
│       ├── studio_home_screen.dart
│       ├── open_canvas.dart           # Open/create a canvas from Studio
│       ├── controllers/
│       ├── models/
│       ├── providers/
│       └── widgets/
├── providers/                         # AI provider adapters (see docs/PROVIDER-API.md)
│   ├── provider_registry.dart         # providerId → factory mapping
│   ├── rate_limiter.dart              # Per-provider token bucket
│   ├── dio_error_mapper.dart          # DioException → InkError mapping
│   ├── sync_provider_base.dart        # Shared base for sync image providers (inlineBytes)
│   ├── dashscope_async_provider_base.dart  # Shared base for DashScope async tasks
│   ├── gemini_image_provider.dart
│   ├── openai_image_provider.dart
│   ├── openai_compatible_provider.dart # Custom OpenAI-compatible endpoint (PROVIDER-API §13)
│   ├── stability_image_core_provider.dart
│   ├── kling_v3_provider.dart
│   ├── kling_v3_omni_provider.dart
│   ├── wanx_image_provider.dart
│   ├── wanx_i2v_provider.dart
│   ├── wanx_r2v_provider.dart
│   └── wanx_t2v_provider.dart
├── storage/                           # Embedded PostgreSQL layer
│   ├── pg_controller.dart             # Embedded PG lifecycle
│   ├── pg_binary_locator.dart         # PG binary discovery
│   ├── base_repository.dart           # Shared SQL helpers
│   ├── postgres_unit_of_work.dart     # Multi-step write transactions (UnitOfWork)
│   ├── migrations/                    # Migration runner
│   ├── repositories/                  # Concrete postgres_*_repository.dart
│   └── schema/                        # DDL (.sql) + schema version (.dart)
└── services/                          # App-level services
    ├── job_queue_service.dart         # InMemoryJobQueueService orchestrator (<500 lines): scheduling + state machine + cancel-race arbitration
    ├── job_queue/                      # JobQueue collaborators (LB-03 split)
    │   ├── job_media_persister.dart    # JobMediaPersisterImpl + NullJobMediaPersister (inlineBytes/remoteUrls 落盘 + slot 收敛)
    │   ├── job_state_persister.dart    # JobStatePersister (jobs 表写库 + 启动孤儿回收 init)
    │   ├── job_handle_impl.dart        # JobHandleImpl (last-value replay + done completer)
    │   └── job_queue_util.dart         # RunningJob + lostToCancel/truncate + log module 常量
    ├── file_resolver_service.dart     # Relative ↔ absolute path resolution
    ├── file_preferences_service.dart  # config/preferences.json load/save
    ├── custom_providers_file_service.dart  # config/custom_providers.json parse + fallback
    ├── character_asset_service.dart
    ├── orphan_file_reaper.dart        # DiskOrphanFileReaper (disk orphan media GC; DRY-RUN v1 — logs only, never deletes; LB-13)
    ├── app_teardown.dart              # Ordered shutdown (capture window state → JobQueue → Pool → PG)
    ├── window_state_service.dart      # DefaultWindowStateService + clampBoundsToVisible pure fn (window size/pos/maximized memory; multi-monitor clamp; PL-6)
    ├── window_manager_adapters.dart   # WindowManagerWindowController + ScreenRetrieverDisplayQuery (real plugin seams behind WindowController/DisplayQuery)
    ├── crash_reporter.dart            # FileCrashReporter (uncaught-error crash file + keep-3 rotation, no context/extra)
    ├── error_hooks.dart               # installErrorHooks + reportUncaught (FlutterError/PlatformDispatcher/zone → logger + CrashReporter)
    ├── lifecycle_timer.dart           # LifecycleTimer (startup stage timing → app.lifecycle {stage, ms}; see docs/perf-baseline.md)
    ├── dio_video_download_service.dart
    ├── system_process_runner.dart     # ProcessRunner impl (Process.run)
    ├── system_folder_opener.dart      # FolderOpener impl (explorer/open — reveal a dir in the OS file browser; LB-09 startup surface)
    ├── ffmpeg_locator.dart            # ffmpeg discovery (INKFRAME_FFMPEG env → PATH probe)
    ├── ffmpeg_video_export_service.dart  # VideoExportService impl (concat demuxer, stream copy)
    ├── media_kit_video_player_service.dart
    ├── media_kit_thumbnail_service.dart
    ├── platform_secure_storage_service.dart
    └── file_secure_storage_service.dart   # Debug+macOS plaintext dev key store (see Provider API Keys)
```

## Code Rules

### Models

- ALL models use `freezed` for immutability + copyWith + JSON serialization
- NO mutable model classes
- NO `Map<String, dynamic>` as model substitute

### Error Handling

- Custom `InkError` sealed subclasses per domain (`ProviderError` / `NetworkError` / `DownloadError` / `LocalIOError` / `CancelledError` / `UnknownError`) — see `lib/core/errors/ink_error.dart` and ARCHITECTURE.md §4.1
- NO catching `Exception` or `dynamic` — always specific `InkError` subtypes
- Errors bubble up to UI via Riverpod AsyncValue; widgets render `messageKey` through `context.l10n`

### Testing

- TDD: write test first, watch it fail, implement, watch it pass
- Every public method has a test
- Repositories tested with mock DB
- Providers tested with mock repositories
- Widgets tested with ProviderScope overrides

### Git

- Every commit must: compile clean, pass all tests, have full i18n coverage
- Commit messages: conventional commits (feat/fix/refactor/test/docs)
- No `--no-verify`, no skipping hooks

## Provider API Keys

- Stored in platform-secure storage (macOS Keychain / Windows Credential Manager)
- NEVER in code, config files, or database
- **Debug-only exception (macOS)**: unsigned Debug builds cannot reach Keychain (errSecMissingEntitlement, -34018), so `kDebugMode && Platform.isMacOS` routes to `FileSecureStorageService` — plaintext `config/secrets.dev.json`, local development only. Never distribute builds on this path.
- Access through `SecureStorageService` interface only
