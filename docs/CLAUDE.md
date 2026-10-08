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

## Commands

Local verification — the same gate as `scripts/hooks/pre-push`:

```bash
flutter analyze lib test            # full static analysis (catches compile errors + stale generated files)
flutter test --exclude-tags golden  # full test suite, golden excluded locally
```

- **Golden tests run only in CI (ubuntu).** Baselines are rasterized on the CI ubuntu font stack; running golden tests on macOS/Windows always produces false failures. Never "fix" a golden locally — exclude with `--exclude-tags golden` and let CI be the gate (see `dart_test.yaml` tags.golden).
- **After changing any ARB file**: run `flutter gen-l10n` and commit the regenerated `lib/l10n/generated/` in the same commit. Stale generated files slip past `flutter test` (it only compiles what tests import) but are caught by `flutter analyze lib test`.

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

Follows the global no-backward-compatibility rule — no legacy code, no deprecated APIs kept around, no parallel old-format parsing paths; this includes downgrade: an older app opening a newer DB is rejected (`SchemaDowngradeError`), never silently reinterpreted.

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
5. **Key-set parity is enforced by `test/l10n/arb_hygiene_test.dart`** (runs with the full test suite in CI and pre-push): `app_en.arb` and `app_zh.arb` must have identical key sets. Adding more locales later only adds new ARB files; the parity rule generalizes to "all locales share identical key sets."

> Note: code comments follow the global rule (Chinese); the English-only requirement applies to ARB keys/default values, logs, error codes, prompts and other internal strings — not to comments.

### File Structure

```
l10n.yaml               # Flutter gen-l10n config (repo root)
lib/l10n/
├── app_en.arb          # English (source of truth)
├── app_zh.arb          # Chinese (must match all keys)
├── generated/          # gen-l10n output — checked in, regenerate + commit with every ARB change
└── l10n_x.dart         # context.l10n extension + InkError → localized string
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
├── l10n/                              # ARB files (app_en.arb, app_zh.arb) + generated/ + l10n_x.dart (context.l10n extension, InkError → localized string)
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
│   ├── licenses.dart                  # LicenseRegistry entries for bundled non-pub artifacts (libmpv+FFmpeg, PostgreSQL, OFL fonts)
│   ├── logging/                       # InkLogger interface
│   ├── media/                         # png_dimensions.dart (XM-2: PNG header → pixel size, pure; no image decoder dependency)
│   ├── models/                        # Domain models (freezed, immutable) + shot_language.dart (P3 hand-written: ShotSize / CameraAngle / focal table / ShotLanguage ↔ type_config)
│   ├── net/                           # proxy_env.dart (LB-24: HTTPS_PROXY/HTTP_PROXY/NO_PROXY 纯函数 + applyEnvProxy dio 接线)
│   └── paths/                         # app_paths.dart (well-known dirs, platform-conventional root) + legacy_root_migrator.dart (DIR-1 one-shot move)
├── features/                          # Feature modules (vertical slices)
│   ├── canvas/                        # Node canvas
│   │   ├── models/
│   │   ├── providers/                 # Riverpod ViewModels; P4 起还有 project_panel_tab.dart（左栏三页签选中态，非 autoDispose——「管理」链接要跨子树把左栏切到角色页）+ character_usage.dart（角色 id → 引用它的 config 节点，只数 config、跨全项目画布、按节点 id 去重；数据源复用 galleryGraphProvider，挂/摘角色后由 CharactersSection 定点 invalidate）
│   │   ├── util/                      # incl. narrative_order.dart (SB-5 chain ordering) + node_artifacts.dart (node → latest result) + camera_labels.dart (运镜 / 景别 / 机位角度 / 焦段 → ARB 文案 + parseCameraMovement + shotLanguageSummary) + batch_slot_view.dart (P4: slot 行 → 四种呈现态 promoted/success/error/generating 的唯一判据 + canPromote/aspectRatio)
│   │   └── widgets/                   # P4 批量：batch_results_grid.dart（检查器内联 2×N 网格，宿主 image_result_inspector.dart 只剩一层 s12 内边距——宽度跟面板走）/ batch_compare_overlay.dart（全屏并排对比；「叠加对比」是禁用标签，不做清单）/ batch_slot_parts.dart（BatchSlotImage + BatchTappable + runBatchSlotAction——slot 动作的统一执行口，只捕具体失败类型并落 toast）。P4 角色：character_library_panel.dart（左栏角色页，行 = 缩略图 + 名 + 「N 张参考图 · M 处引用」+ ⋯ 菜单）/ character_edit_dialog.dart（改名 + 描述 + 参考图增删拖排 + 「被引用」）
│   ├── command_palette/               # ⌘K/Ctrl+K command palette (PL-1; app-level, wraps InkShell). Screens 稿第 4 屏右：跨实体搜索，三组「镜头 · 当前画布 / 产物 / 动作」
│   │   ├── palette_entry.dart         # PaletteEntry / PaletteChoice（hand-written value objects; run = ↵ 打开, locate = ⌘↵ 在画布中定位）
│   │   ├── palette_search.dart        # buildPaletteEntries — 镜头组只搜当前画布已加载节点（不为搜索读库）、产物组复用 galleryController、动作组 = buildCommandActions
│   │   ├── command_actions.dart       # CommandAction + context-aware hardwired action list (≤6)
│   │   └── widgets/                   # palette dialog / top-chrome chip / app-level shortcuts wrapper
│   ├── export/                        # Video export UI (concat dialog; entries: export tab / sequence tab「导出 mp4」/ ⌘K, all via open_export_dialog.dart — projectId + gating from ShellState.project, BOARD 210)
│   │   ├── open_export_dialog.dart    # openExportVideoDialogForCanvas — the one path that orders by narrative chain and opens the dialog
│   │   ├── providers/                 # ExportController (canvas→project path conversion)
│   │   ├── util/                      # Output-name pre-validation + export_order.dart (EX-1′ narrative-chain default order)
│   │   └── widgets/
│   ├── gallery/                       # Project-wide generated-asset gallery (Screens 稿第 2 屏：筛选 220 | 网格 | 信息 320)
│   │   ├── models/                    # gallery_item (freezed) + gallery_graph / gallery_selection (hand-written)
│   │   ├── providers/                 # gallery_graph_provider (sole DB read) → gallery_controller (items) → gallery_view (meta / filtered / anchor); gallery_filter + gallery_selection are keepAlive per project
│   │   ├── util/                      # gallery_meta.dart (pure: meta / lineage / narrative-chain marks) + gallery_time.dart
│   │   └── widgets/                   # gallery_screen / gallery_filter_panel / gallery_grid + gallery_tile / gallery_info_panel / gallery_actions (save-as-character, locate-in-canvas)
│   ├── generation/                    # Generation flow UI + state (no widgets/ — panel retired in #164)
│   │   ├── generation_controller.dart # P3: 镜头语言英文前缀注入 fullPrompt；camera 参数只在 provider 声明 supportedCameras 时下发。P4: submitFromConfigNode 收 seedOverride（只对这一次生效、不写回节点）+ 挂载角色的 description 按 character_ids 顺序注入提示词（与参考图共用同一道能力位门）
│   │   ├── models/
│   │   ├── providers/                 # P4: batch_results_controller.dart（某 result 节点下的 slot 列表 + 转正/重跑/取消三个动作的唯一入口；转正在一个事务里改节点产物 + 清同节点旧 promoted + 标本行，然后定点重建画布节点集合）+ batch_job_progress.dart（jobId → 进度，family 化避免注册表任何一条 job 变动都重建整屏）
│   │   └── services/                  # prompt_assembler + shot_language_prompt.dart (P3: 镜头语言 → 英文提示词前缀，不 i18n) + cost_estimator
│   ├── settings/                      # Settings overlay dialog (Screens 稿第 3 屏: 1120×740 居中, 40 标题栏 | 左导航 200 + 页 | 44 底部条; 自持焦 + Esc 分层; 开关不写路由)
│   │   ├── settings_screen.dart       # SettingsScreen (dialog frame + nav + page bodies + footer 完成/导出诊断包); pages = 常规 / API 密钥 / 节点布局 / 存储 / 关于
│   │   ├── providers/
│   │   └── widgets/
│   ├── shell/                         # Persistent-tab app shell — the sole host after unlock; lib/app.dart's body is just InkShell (no routing predicates left there). See lib/features/shell/README.md for the invariants
│   │   ├── models/                    # shell_state.dart (ShellTab / ShellOverlay / ProjectRef / ShellState — hand-written value object, 7 named transitions, no copyWith)
│   │   ├── providers/                 # shell_controller.dart (ShellNavigator Notifier + shellControllerProvider — sole write entry point) + active_project.dart (activeProjectProvider — read-only projection of ShellState.project) + gallery_dirty.dart (galleryDirtyProvider — any job reaching JobSucceeded marks the gallery dirty; the gallery tab refreshes once on the invisible→visible edge, then clears. NOT live refresh: a gallery the user is already looking at stays put until they switch away and back)
│   │   ├── util/                      # tab_availability.dart (hasNarrativeEdges / canExportVideo — pure predicates moved verbatim out of the deleted canvas_top_chrome.dart)
│   │   └── widgets/                   # ink_shell.dart (sole root Scaffold + chrome + tab bar) / shell_content_stack.dart (outer Stack: tab host under an ExcludeFocus + overlay on top; inner five-slot IndexedStack; fallback focus) / shell_keep_alive_host.dart (five lazily-materialized, then permanent tab slots) / shell_chrome.dart (the tree's only InkWindowChrome) / shell_breadcrumb.dart / shell_empty_state.dart / shell_overlay_layer.dart (ModalBarrier scrim + settings / showcase overlays; NOT kept alive; the barrier is what stops click-through) / shell_tab_bar.dart (wires ShellState into the theme-layer InkShellTabBar — that component knows nothing about ShellTab, see test/quality/no_reverse_layer_import_test.dart) + tabs/ (studio / canvas / sequence / gallery / export bodies)
│   ├── showcase/                      # Bundled Codex image samples (local preview; no project records/API key)
│   │   └── widgets/
│   ├── startup/                       # Startup failure surface (DB-ready gate; LB-09)
│   │   └── widgets/                   # StartupErrorView (full-screen error + retry + open-log-dir)
│   ├── storyboard/                    # Script in, sequence out — paste a script into a shot chain (SB-1/SB-2), play the chain end to end (SB-6)
│   │   ├── models/                    # sequence_shot.dart (what each shot shows, and for how long)
│   │   ├── providers/                 # script_import_controller.dart (ShotDrafts → shot chain in ONE transaction; failure leaves no residue)
│   │   ├── util/                      # sequence_builder.dart (nodes+edges → playlist) + script_splitter.dart (SB-1 rule-based, no LLM); both pure
│   │   └── widgets/                   # script_import_dialog.dart (paste + strategy + live preview); the old sequence_preview_dialog moved into features/sequence (P2)
│   ├── sequence/                      # 序列视图（P2，Timeline 稿）：只读序列 lens 常驻在序列标签——叙事链 320 | 节目监视器 | 交付占位 320；序列区 300（时间尺 / 场次标记 / V1 只读轨 / 播放头）
│   │   ├── models/                    # sequence_lens.dart (buildSequenceLens: shots + startsMs + totalMs + 场次标记由链上 shot 节点推 + 未入链计数；locate / globalMs 纯函数)
│   │   ├── providers/                 # sequence_lens_provider (watch 节点 + 边控制器) / sequence_playhead (index + offsetMs + seekToken：监视器 report 不动 token，用户 seek 才自增；不落库) / sequence_zoom (px/s，Ctrl+滚轮，8..160)
│   │   ├── util/                      # timecode.dart (HH:MM:SS:FF / 短格式，24fps 常量——帧率无字段)
│   │   └── widgets/                   # sequence_screen.dart (三栏 + 序列区；点 / 拖轨道 = seekGlobal，只改 Player 位置) + sequence_monitor.dart (media_kit Player：不自动播放；paused = !isTabVisible ⇒ 立即 pause、回来不续播)
│   └── studio/                        # Project / workspace shell (Screens 稿第 1 屏：库 220 | 工具行 + 恢复条 + 4 列项目网格；first-run onboarding dialog; ON-1/ON-2)
│       ├── studio_home_screen.dart    # + showStudioNewProjectDialog / createStudioSampleProject（标签栏「新建项目」与网格虚线格共用）
│       ├── open_canvas.dart           # Open/create a canvas from Studio
│       ├── project_import_flow.dart   # runProjectImportFlow — LB-12 archive import, one path shared by shell tab-bar「导入项目包」/ zero-project empty state / ⌘K (audit 2026-08-31 P0-3)
│       ├── controllers/
│       ├── models/                    # project_with_canvases (createdAt + updatedAt; list sorted by updatedAt desc)
│       ├── providers/                 # workspace_projects_provider / restore_last_session (startup guard) / trashed_items_providers
│       ├── util/                      # last_session.dart — hasRestorableLastSession，启动守卫与首页恢复条共用的唯一判据 + onboarding_provider_choices.dart（向导第 2 步三行 Provider 的唯一判据：代表 providerId 按 SecureStorageKeys.scopeOf 的家族首个成员取、与设置页 Key 表同口径；scope 下无注册 Provider ⇒ 该行「待支持」禁用）
│       └── widgets/                   # library_sidebar / project_card / studio_provider_banner (无 Key 引导条) / onboarding_dialog（Screens 稿第 4 屏左：642×492，43 步骤条「可回退到已完成步」| 正文 | 55 底部条）+ onboarding_keys_step（第 2 步：Provider 单选 + Key 验证，存/校验复用 ApiKeyScopeController 不另造一套）+ onboarding_step_body（三步共用的正文壳）+ onboarding_anchors（两边都要用的测试锚点 Key——挂在任一侧都会把 import 绕成环，与 batch_slot_parts 同因；OnboardingDialog 上留同名转发常量） / trash_dialog
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
│   ├── database_bootstrap.dart        # One-shot DB bootstrap once pool is ready (pgcrypto + forward migrations; wraps ServerException as DatabaseBootstrapError; LB-08)
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
    ├── orphan_file_reaper.dart        # DiskOrphanFileReaper (disk orphan media GC; read-only scan — logs candidates, contains NO delete code at all; LB-13, audit 2026-08-31 P0-1)
    ├── database_backup_service.dart   # PgDumpBackupService (daily/manual/prerestore pg_dump -Fc, per-family retention 7/3/3, meta.json sidecar; LB-10/LB-22)
    ├── database_restore_service.dart  # PgSwapRestoreService (restore into scratch DB then rename-swap — failed restore leaves data untouched; LB-22)
    ├── diagnostics_bundle_service.dart # ZipDiagnosticsBundleService (support bundle: info+logs+crashes+config allowlist, never api keys; LB-18)
    ├── project_import_service.dart    # ZipProjectImportService (archive import: staging-first + rename + single-tx, zero-residue compensation; LB-12)
    ├── import/                        # LB-12 pure layers: archive_import_guard.dart (zip-slip/limits/manifest gates) + import_remapper.dart (UUID remap + FK/JSONB rewrite)
    ├── project_archive_service.dart   # ZipProjectArchiveService (whole-project zip export: manifest+data.json+files/, full-fidelity incl. soft-deleted rows; LB-11)
    ├── video_metadata_backfill_service.dart  # XM-1b startup housekeeping: probe legacy videos missing duration_ms, patch type_config (+thumbnail if absent)
    ├── app_teardown.dart              # Ordered shutdown (capture window state → JobQueue → Pool → PG)
    ├── window_state_service.dart      # DefaultWindowStateService + clampBoundsToVisible pure fn (window size/pos/maximized memory; multi-monitor clamp; PL-6)
    ├── window_manager_adapters.dart   # WindowManagerWindowController + ScreenRetrieverDisplayQuery (real plugin seams behind WindowController/DisplayQuery)
    ├── crash_reporter.dart            # FileCrashReporter (uncaught-error crash file + keep-3 rotation, no context/extra)
    ├── error_hooks.dart               # installErrorHooks + reportUncaught (FlutterError/PlatformDispatcher/zone → logger + CrashReporter)
    ├── lifecycle_timer.dart           # LifecycleTimer (startup stage timing → app.lifecycle {stage, ms}; see docs/perf-baseline.md)
    ├── image_cache_config.dart        # configureImageCache (LB-23: ImageCache 上限 256MB; main bootstrap 调用一次)
    ├── dio_video_download_service.dart
    ├── process_watchdog.dart          # runWithWatchdog (ProcessStarter 流式 + 定时 kill + 硬截止; pg_dump/pg_restore 超时)
    ├── system_process_runner.dart     # ProcessRunner/ProcessStarter impl (Process.run / Process.start+stdin close)
    ├── system_folder_opener.dart      # FolderOpener impl (explorer/open — reveal a dir in the OS file browser; LB-09 startup surface)
    ├── ffmpeg_locator.dart            # ffmpeg discovery (INKFRAME_FFMPEG env → PATH probe)
    ├── ffmpeg_video_export_service.dart  # VideoExportService impl (concat demuxer, stream copy)
    ├── media_kit_video_player_service.dart
    ├── media_kit_thumbnail_service.dart
    ├── github_update_check_service.dart   # UPD-1 in-app update check (releases list, SemVer max incl. prerelease)
    ├── process_url_opener_service.dart    # Open external URL via system command (open / rundll32; no url_launcher)
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

- `main` is protected (GitHub Flow) — all changes land via feature branch + PR, never commit/push directly
- Every commit must: compile clean, pass all tests, have full i18n coverage
- Commit messages: conventional commits (feat/fix/refactor/test/docs)
- No `--no-verify`, no skipping hooks

## Provider API Keys

- Stored in platform-secure storage (macOS Keychain / Windows Credential Manager)
- NEVER in code, config files, or database
- **Debug-only exception (macOS)**: unsigned Debug builds cannot reach Keychain (errSecMissingEntitlement, -34018), so `kDebugMode && Platform.isMacOS` routes to `FileSecureStorageService` — plaintext `config/secrets.dev.json`, local development only. Never distribute builds on this path.
- Access through `SecureStorageService` interface only
