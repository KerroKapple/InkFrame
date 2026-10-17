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
- **FFI**: ffi（Windows「系统提示音」直接调 winmm 的 PlaySoundW，见 services/notification_sound/system_alert_sound.dart）
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
├── duration_format.dart # formatDurationLabel / formatElapsed — duration & elapsed-time format (「N 秒」 and 「~」 come from ARB)
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
├── app.dart                           # MaterialApp, router, theme wiring; MaterialApp.builder = ToastLayer (toasts above every route)
├── l10n/                              # ARB files (app_en.arb, app_zh.arb) + generated/ + l10n_x.dart (context.l10n extension, InkError → localized string) + duration_format.dart（时长 / 耗时的统一写法，新代码都走这里〔画廊 / 产物检查器片长仍走 gallery_time.galleryFormatDuration，待迁〕：formatDurationLabel 片长与估时〔四舍五入，「~」前缀〕、formatElapsed 计时〔向下取整〕；<60 写「N 秒」、满分 m:ss、满时 h:mm:ss）
├── theme/                             # Design tokens, theme, components
│   ├── tokens.dart                    # Color / spacing / radius / shadow tokens
│   ├── typography.dart                # Text styles
│   ├── motion.dart                    # Animation timings / curves
│   ├── app_theme.dart                 # ThemeData builder from tokens
│   ├── primitives/                    # Low-level styled primitives
│   ├── icons/                         # 图标集 v1：ink_glyph.dart（45 个图标的 SVG 路径，与设计稿同源）+ svg_path_data.dart（d → Path，不引 SVG 依赖）；绘制入口是 components/ink_icon.dart
│   └── components/                    # Reusable Ink* components (incl. ink_menu_panel.dart — InkMenuPanel / InkMenuEntry, the searchable keyboard menu panel with disabled / danger / checked rows and submenus, knows nothing about the canvas; ink_icon.dart — the one painter for icon set v1 glyphs; ink_toast_card.dart — toast card + InkToastLeading, pure presentation with its own InkToastTone)
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
│   │   ├── models/                    # canvas_command.dart（撤销栈里一步的契约：名字 + 受影响节点 + revert / apply，只持快照；结果分 done / gone / failed；CanvasCommandEnv 给 canvasId 与 ref；每种命令一个文件）+ edge_endpoints.dart（按两端 + 类型认一条边，不看 id——撤销后重建的边 id 会变；findEdgeByEndpoints 在在世边里找）
│   │   ├── providers/                 # Riverpod ViewModels; canvas_prompt_bar_height.dart（底部提示词条此刻画出来的高度，条子自己量自己报上来，不显示为 0；适应视口据此让出它）; canvas_compact_cards.dart（缩放 < 0.6 时节点卡只画类型图标——只在跨阈值时通知，缩放时不逐帧重建卡片）；left_rail_state.dart（PR-4 画布左栏：停在哪一页〔大纲 / 素材 / 角色〕+ 面板展开 / 收起，非 autoDispose——「管理」链接与 Ctrl+\ / ⌘\ 都是跨子树来开合 / 切页；取代 P4 的 project_panel_tab.dart）+ character_usage.dart（角色 id → 引用它的 config 节点，只数 config、跨全项目画布、按节点 id 去重；数据源复用 galleryGraphProvider，挂/摘角色后由 CharactersSection 定点 invalidate）+ canvas_bootstrap_controller.dart（短剧示例：单事务建项目/画布/泳道/两镜 image config 节点 + 一条叙事边〔序列视图开箱就有两镜〕，泳道风格提示词是英文常量 kSampleLaneStylePrompt〔发给模型的只用英文〕，种子文案走 util/sample_seed.dart 的 sampleSeedOf〔引导与工作室示例共用〕；并把 assets/samples/ 的两张打包成片落盘 + 每镜种一张 result 节点；建完让工作区项目列表失效，左栏画布切换器立即看得到新画布——P7 把内置示例页并进来了；成片 best-effort，读不出来就少种两个节点）+ inspector_submit_controller.dart（提交四态 + type_config 单写入链 + 自动保存失败态；并实现 `PendingWriteFlushable`、在 build 里注册进 `pendingWriteRegistryProvider`；另实现编辑口 flushBeforeEdit——撤销前冲写，不置退出标志、不停自动重试——退出序列在关连接池之前冲一次挂起的防抖 patch 与 `_unsaved`，BOARD 第 201 行）+ canvas_tool_mode.dart（浮动工具条的工具态：选择 / 平移 + 按住空格临时平移，两个来源分开记、按画布 autoDispose；实际是否平移 = 二者取或，舞台指针闸 / 手形光标 / 工具条高亮共读 canvasPanActiveProvider）+ inspector_tab.dart（PR-6 检查器停在「属性」还是「历史」；autoDispose，换选中节点不重置）+ canvas_escape_ladder.dart（Esc 阶梯的运行时登记表：各层〔菜单 / 拖线 / 框选 / 工具锁…〕按 EscapeRungId 登记自己的「有没有东西可退、怎么退」，Esc 一次只剥最上面一层）+ canvas_menu_state.dart（画布菜单的请求与拖线状态：canvasMenuRequestProvider〔开着哪个菜单、锚点、源节点 / 右键的卡〕+ canvasWireDragProvider〔拖线实时状态〕；Esc 阶梯与快捷键从这里读，providers 层不反向依赖 widgets）+ canvas_history_controller.dart（每张画布一个撤销栈：keepAlive family、深度 100、纯内存不落库；record 只登记已做成的操作、清空重做栈；撤销 / 重做前先冲挂起写入〔走编辑口 flushBeforeEdit：失败照常退避重试，不是退出路径的 flushAll〕；一道 busy 闸不排队；revert 失败那步留在栈顶，对象已不在就丢掉这步；undoSpecific 给撤销卡「点哪步撤哪步」；外壳 canvasId 离开本画布即丢栈并收起绑定的撤销卡）
│   │   ├── util/                      # incl. narrative_order.dart (SB-5 chain ordering) + node_artifacts.dart (node → latest result) + camera_labels.dart (运镜 / 景别 / 机位角度 / 焦段 → ARB 文案 + parseCameraMovement + shotLanguageSummary) + batch_slot_view.dart (P4: slot 行 → 四种呈现态 promoted/success/error/generating 的唯一判据 + canPromote/aspectRatio) + ref_image_budget.dart (CH-2②: 参考图配额纯判据——边连 reference 入边 + 挂载角色图合计 vs maxRefImages，算出"谁被截掉几张"；检查器提交前点名、生成侧落 warn 用同一口径。首/尾帧不占配额) + edge_style.dart（连线外观的唯一判据：叙事 / 首帧 / 尾帧 / 参考 / 产出五种线型、颜色槽、标签，选中只换色）+ lineage_edges.dart（产出线由 source_node_id 推导、不入库不可点不可删；端口占用判据）+ result_placement.dart（成片落点：config 右侧一列、第 k 张往下错开；与 config 同道） + generate_gate.dart（「生成」能不能点的唯一判据：检查器生成按钮与提示词条生成按钮 / ⌘↵ 共用——先看提示词再看 Key，判 Key 的供应商按 节点已存 > 上次使用 > 候选第一个 同一条链取）+ prompt_bar_width.dart（提示词条宽 = 画布宽 × 0.6，夹在 480–880；窄于 512 贴边留 16）+ canvas_tool_actions.dart（浮动工具条与单键快捷键 V/I/G/T/F/L 共用的唯一实现：视口中心 + 散布建节点 / 建泳道 / 切连线 / 选择工具；建节点只有 addNodeFromMenu 一条路〔判泳道写 laneId、新节点只单选不挪相机；不带落点的入口——工具条、I / G / T、Tab 菜单里不带上下文的项、空画布 CTA、⌘K 新建节点——落在视口中心 + 散布，带落点的落在菜单锚点〕；PR-8a 起还有新建菜单的动作：在菜单锚点建节点并连好线〔先建节点再连线，边写失败回滚删节点 + 错误卡，成功挂定位请求单选〕、端口拖到卡上连线〔走 linkTo〕、全选；PR-8b 起还有节点右键菜单与 Ctrl+↵ / Ctrl+D / Shift+1 / Shift+2 的动作：生成〔InspectorSubmitController.submitWithPending：还没发射的防抖 patch 与写失败等重试的键并进终稿一并提交——提示词不从可能过期的内存节点里取，也不借退出路径的 flushPendingWrites〕、复制一份〔同类型 / typeConfig / 泳道，右下偏一个 lg，不复制边与产物〕、适应全部 / 适应选中〔底部让出缩放条那一截，提示词条显示时改让出条子〔canvasFitInsets：条高 + promptBarClearance，取大的〕；缩放条「适应」与空白处「适应视图」都是适应全部；⌘0 是缩放到 100%〔保持视口中心那一点不动，canvas_zoom.dart 的 actualSizeTransform〕〕、存为角色〔InkNameDialog + createFromImage，与角色库同一条路〕、加入 / 移出泳道〔moveNode 整批，位置一并挪进目标道的带里〕）+ viewport_fit.dart（PR-8b 适应视口纯函数：舞台矩形框进「视口扣掉留白」并居中，缩放夹在最小缩放与 min(1, 最大缩放) 之间——只缩小不放大；泳道里的卡片包围盒随缩放变，按缩放二分，卡片矩形走 nodeStageRect）+ node_menu_model.dart（PR-8b 节点右键菜单判据：目标集〔右键的卡在选中集里 = 整个选中集〕、生成 / 复制一份 / 存为角色的可用条件、泳道子菜单的打勾与「移出泳道」、加入泳道时的位置换算 laneMoveDelta）+ create_menu_model.dart（PR-8a 新建菜单项判据：带连线上下文时源带图像产物出首帧 / 尾帧 / 参考三项、配置节点〔shot / image / video〕出「下一镜」；不带上下文出图像配置 / 视频配置 / 文本 / 镜头 / 泳道；搜索过滤；nextNarrativeSortOrder：「下一镜」的叙事边排在锚点已有分叉之后〔最大 sortOrder + 1〕）+ drop_placement.dart（落点换算：拖卡片落点与新建菜单落点共用的泳道归属判定 resolveLaneDrop、视口点 → 世界坐标、舞台上一点落在哪张卡上；拖卡片换不换道走 resolveCardDrop——拖过 18 屏幕 px、卡心真的跨过道界、且进新道 12 px 以上才换道，否则只挪位置不改 laneId〔误拖几像素不再悄悄换风格继承〕；换道时目标道高亮〔cardDropTargetLane〕，落下后出带「撤销」的卡）+ outline_model.dart（PR-4 左栏大纲的分组纯函数：链上配置节点按泳道分组〔组序 = 泳道 sortOrder、组内 = 叙事链序〕→ 未分泳道 → 未入链〔按位置、不编号；列全部不在链上的配置节点，与序列状态栏「未入链 · N」只数有产物的口径不同〕，名称 / 提示词筛选；narrativeChainMembers 是「在链上」的唯一判据，narrativeSequenceIndex 只管组内行序；显示的镜号走 sequenceShotNumbers〔序列折叠后的镜序，节点归哪一镜用 sequence/util/shot_index.dart 的判据——与序列视图 / 画廊 / ⌘K 镜头组同一个号；组头「N 镜」= 组内不同镜号的个数〕）+ take_numbers.dart（take 号的唯一编号函数 takeNumbersOn：每个配置节点名下有产物的 result 节点按时间正序编号，名下只有一个不编号〔写「成片」〕，批量 slot 不参与；左栏素材页格子与检查器历史页共用）+ viewport_focus.dart（保持缩放、把节点渲染矩形〔世界 + 分道位移〕移到视口中心的纯函数）+ escape_ladder.dart（Esc 阶梯的层序表 EscapeRungId 与取最上层的纯函数；层序只在这里定，登记顺序不影响优先级）+ selection_geometry.dart（选区几何的唯一判据：框选命中〔闭区间相交，碰到就算；跳过折叠道里的卡〕、applyMarquee 三种模式〔替换 / Shift 加选 / Ctrl·⌘ 反选〕、选区包围盒；卡片矩形走 nodeStageRect）
│   │   └── widgets/                   # stage/（舞台按层一层一个文件，canvas_view.dart 只留 CanvasView / _CanvasBody / _CanvasStage 骨架：stage_pointer_layer〔平移闸 StagePanGate / 手形光标 / StageSpace / 空白处与右键的点击探测〕· node_card_slot〔单卡的选中 / 拖线态、拖动换道与撤销卡、端口拖线〕· stage_edge_layer〔连线绘制、选中边的删除钮、边泳道错误、拖线中的预览线〕· stage_lane_layer〔分道位移 StageLaneShift、泳道底色、标题栏与分界线〕· stage_overlays〔挂起定位、选中计数、连线提示、加载失败〕；后续切片各改各的层文件）+ canvas_screen.dart（左栏 | 舞台 + 浮层 | 检查器；PR-6 页签去重撤掉了舞台上方的画布头与底部的渲染队列——画布名在面包屑、缩放比例在缩放条、任务进状态栏胶囊，舞台上沿贴外壳标签栏、下沿贴状态栏）+ canvas_toolbar.dart（舞台顶部居中的浮动工具条：选择 · 平移 | 图像 · 视频 · 文本 · 镜头 · 泳道 · 连线 | 更多〔导入剧本〕；取代原左侧 37px 工具条与右下角加号）+ canvas_zoom_bar.dart（舞台左下的浮动缩放条；「适应」= 适应全部）+ canvas_inspector_panel.dart（右侧检查器，页签「属性 / 历史」，原「状态」页签已删）+ inspector_history_panel.dart（检查器「历史」页：选中节点的 take 列表——配置节点列名下全部产物、产物节点列同源兄弟并高亮自己；take 号走 util/take_numbers.dart〔与左栏素材页同一个号，名下只有一个写「成片」〕；有 data 出边的标「在用」；点行 = 单选 + 居中）+ shortcuts/（画布快捷键注册表：canvas_key_binding〔CanvasKeyBinding：id / 键位 / intent / 门槛 gate / 分组 / 文案 / onInvoke / listed / enabledWhen〕+ canvas_shortcut_registry〔kCanvasKeyRegistry，后续切片新建 shortcuts/<x>_keys.dart 再往这里追加一行〕+ core_canvas_keys〔现有键的绑定与回调〕+ canvas_intents + canvas_tool_keys；Esc 逐层退出：在输入框里只失焦、选中保留，没东西可退时不吞键）+ canvas_shortcuts.dart（读注册表装配 Shortcuts / Actions；删除 / Esc / 全选 / 缩放 + 工具单键 V/H/I/G/T/F/L，键位常量 CanvasToolKeys 与工具条 tooltip 同源；所在路由上面压着对话框时任何「要回焦点」的入口都不抢；按住空格临时平移走 Focus.onKeyEvent，只在画布本身持焦时接管；Ctrl+\ / ⌘\ 开合左栏；Tab = 新建…，同样只在画布本身持主焦点时接管、别处的 Tab 放行给焦点遍历；PR-8b 加了 Ctrl+↵ / ⌘↵ 生成选中、Ctrl+D / ⌘D 复制一份、Shift+1 适应全部、Shift+2 适应选中，四个都对文本编辑让位——提示词条里的 ⌘↵ 归提示词条自己）+ create_node_menu.dart（barrel，名字不变，实体在 canvas_menu/：canvas_menu_request〔请求与拖线 provider〕· canvas_menu_host〔舞台上的菜单宿主〕· canvas_menu_popover〔CanvasMenuPopover：给锚点就开、null 就收的通用弹出层，大纲 / 序列右键也能用〕· menu_registry〔空白处 / 节点菜单项的分组表 kCanvasMenuItems：节点 10 做 / 20 take / 30 归类·定位 / 80 停用 / 90 删除，空白处 0 撤销·重做 / 10 新建·导入 / 30 粘贴 / 50 选择·视图；后续切片加菜单项 = 新文件 + 往表里追加一行〕· create / blank / node_menu_entries〔各类菜单项〕。PR-8a 新建菜单：从出端口拖线到空白处 / 双击空白 / Tab / 空白处右键「新建…」开同一个带搜索的菜单；canvasMenuRequestProvider〔开着哪个菜单、锚点、源节点 / 右键的卡〕+ canvasWireDragProvider〔拖线实时状态，Esc 取消〕+ CanvasMenuHost〔OverlayPortal 浮层，点外面 / 失焦关〕+ 菜单面板 InkMenuPanel〔在 theme/components/ink_menu_panel.dart，项类型 InkMenuEntry；↑↓ / ↵ / Esc；项可置灰〔↑↓ 跳过〕/ 危险色 / 打勾 / 带子菜单——子菜单经第二个 OverlayPortal 贴在父行旁，与主菜单同一个点击区组〕；空白处右键菜单只有新建… / 导入剧本… / 全选 / 适应视图；PR-8b 节点右键菜单〔卡片上右键：没选中的先单选它，多选保持〕：生成 · 复制一份 | 存为角色 · 加入泳道 › · 在序列中定位 | 删除，不可用的置灰不隐藏；右键（空白处与卡片上）都在抬起时开、按下到抬起没挪出点击容差才开，锚点是按下的舞台点——按住右键拖动是拖画布；Tab 开的菜单里不带上下文的项与 I / G / T 同一条路〔viewportCentered〕；选了一项 / Esc 关菜单时焦点当场还给画布〔菜单卸载时不再把焦点还回画布、盖过随后推上来的对话框〕，点外面关走帧后补焦点）。PR-4 左栏 left_rail/：canvas_left_rail.dart（43px 图标导航条：大纲 / 素材 / 角色三页键 + 快捷键〔开设置的快捷键页〕+ 收起；剧本 / 帮助无后端不画）/ left_rail_panel.dart（241 面板宿主，收起时不占宽）/ outline_panel.dart（泳道分组的镜头行 + 产物子行 + 生成中子行，状态走 node_card 的 nodeStatusOf；点行 = 单选 + 移到视口中心）/ canvas_switcher.dart（大纲面板头的画布切换胶囊，接替旧画布树；同项目 openCanvas 不带 withProject）/ assets_panel.dart + assets_model.dart（本画布 / 项目全部 + 类型 chip + 两列网格，数据复用画廊 galleryGraphProvider / galleryController；每次挂载都让画廊图失效一次〔它可能被画廊标签 / 角色页保活而过期〕、开着时 job 成功再刷新；当前画布的格子按画布控制器的实时节点表过滤，删掉立即消失，点到已不存在的节点不选中；标签「源配置名 · take N / 成片」，批量 slot 写「#n」；点格子 = 当前画布定位或走画廊「在画布中定位」）/ left_panel_parts.dart（面板头 + 筛选框 + 说明行）/ left_rail_actions.dart（focusNodeOnCanvas：单选 + 居中）。P4 批量：batch_results_grid.dart（检查器内联 2×N 网格，宿主 image_result_inspector.dart 只剩一层 s12 内边距——宽度跟面板走）/ batch_compare_overlay.dart（全屏并排对比；「叠加对比」是禁用标签，不做清单）/ batch_slot_parts.dart（BatchSlotImage + BatchTappable + runBatchSlotAction——slot 动作的统一执行口，只捕具体失败类型并落 toast）。产物检查器：image_result_inspector.dart（有批量 slot 画网格，没有的单张产物画 16:9 预览）/ video_result_inspector.dart（首帧缩略 + 播放，走画布同一个 showVideoLightbox）共用 result_inspector_parts.dart（预览框、参数组、动作行：定位来源节点 / 在序列中定位 / 播放，不可用的置灰）；参数口径在 util/result_params.dart（与画廊同：provider / 分辨率 / 画幅 / 运镜 / 镜头语言 / 提示词取源配置节点，尺寸 / 种子取产物自身，时长先产物后配置）。text_node_inspector.dart：文本节点正文（type_config.text，生成侧并进提示词读的就是它），走 inspector_submit_controller 的防抖写链，失焦时立即落一笔并刷新画布节点。P4 角色：character_library_panel.dart（左栏角色页，PR-4 起顶上是面板头 + 「搜索角色…」筛选；行 = 缩略图 + 名 + 「N 张参考图 · M 处引用」+ ⋯ 菜单）/ character_edit_dialog.dart（改名 + 描述 + 参考图增删拖排 + 「被引用」）
│   ├── command_palette/               # ⌘K/Ctrl+K command palette (PL-1; app-level, wraps InkShell). Screens 稿第 4 屏右：跨实体搜索，三组「镜头 · 当前画布 / 产物 / 动作」
│   │   ├── palette_entry.dart         # PaletteEntry / PaletteChoice（hand-written value objects; run = ↵ 打开, locate = ⌘↵ 在画布中定位）
│   │   ├── palette_search.dart        # buildPaletteEntries — 镜头组只搜当前画布已加载节点（不为搜索读库）、产物组复用 galleryController、动作组 = buildCommandActions
│   │   ├── command_actions.dart       # CommandAction + context-aware hardwired action list (≤6)
│   │   └── widgets/                   # palette dialog / top-chrome chip / app-level shortcuts wrapper
│   ├── export/                        # Video export UI (concat dialog; entries: export tab / sequence tab「导出 mp4」/ ⌘K, all via open_export_dialog.dart — projectId + gating from ShellState.project, BOARD 210)
│   │   ├── open_export_dialog.dart    # openExportVideoDialogForCanvas — the one path that orders by narrative chain and opens the dialog
│   │   ├── providers/                 # ExportController (canvas→project path conversion)
│   │   ├── util/                      # Output-name pre-validation + export_order.dart (EX-1′ narrative-chain default order) + export_take_selection.dart (BOARD 194 默认勾选 = 每镜最新 take；候选集不收窄)
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
│   ├── notifications/                 # 右下角通知卡 + 铃铛历史 + 生成完成 / 失败通知（ToastService 的实现；卡片层挂在 MaterialApp.builder，画在所有路由之上）
│   │   ├── models/                    # toast_entry.dart（一张卡的不可变快照，也是历史里的一行）+ notification_prefs.dart（提示音 / 停留时长偏好字符串 → 枚举）
│   │   ├── providers/                 # toast_center.dart（ToastCenter：按类型计时、悬停 / 窗口失焦停表、dedupeKey 原地替换、最多 3 张在场其余折叠、本次会话历史 100 条 + 未读、chime 时按设置响一声）+ toast_service_provider.dart（以 core 契约类型暴露 ToastCenter）
│   │   └── widgets/                   # toast_layer.dart（builder 层：右下角卡片栈 + 进退场动画 +「还有 N 条」）/ job_notification_listener.dart（jobsRegistry 新终态 → 完成 / 失败卡；只有视频成片缺首帧缩略时才查一次库取 thumbnail_url；「查看」走挂起定位请求 canvasFocusRequestProvider）/ notification_bell.dart（外壳 chrome 的铃铛 + OverlayPortal 历史下拉；铃铛按自己所在路由是否在最上层上报 historyHostReady——上面压着对话框 / 没有铃铛时卡片栈的「还有 N 条」不可点）
│   ├── settings/                      # Settings overlay dialog (Screens 稿第 3 屏: 1120×740 居中, 40 标题栏 | 左导航 200 + 页 | 44 底部条; 自持焦 + Esc 分层; 开关不写路由)
│   │   ├── settings_screen.dart       # SettingsScreen (壳走 theme 层的 InkOverlayDialog + 左导航 + 各页正文 + 底部条 完成/导出诊断包); pages = 常规 / API 密钥 / 快捷键 / 性能 / 节点布局 / 网络 / 存储 / 关于（后三页里快捷键 / 性能 / 网络是 P7 补的只读页）
│   │   ├── providers/
│   │   ├── util/                      # shortcut_catalog.dart（快捷键页的清单：读画布快捷键注册表 kCanvasKeyRegistry〔只列 listed 的绑定〕+ kOverlayDismissActivator + 画布按住空格平移 CanvasToolKeys.holdToPan）+ proxy_status.dart（网络页：env 代理只读快照，凭据掩码，复用 core/net 的 proxyRuleFor）+ api_key_placeholder.dart（Key 输入框占位提示按 Provider 家族给：sk- / AIza / 通用；设置页 Key 表与引导第 2 步共用）+ settings_page_label.dart（页名，左导航与引导底部「打开设置 › 〈页名〉」共用）+ secure_store_name.dart（Key 存在哪的叫法：macOS 钥匙串 / Windows 凭据管理器）
│   │   └── widgets/
│   ├── shell/                         # Persistent-tab app shell — the sole host after unlock; lib/app.dart's body is just InkShell (no routing predicates left there). See lib/features/shell/README.md for the invariants
│   │   ├── models/                    # shell_state.dart (ShellTab / ShellOverlay / ProjectRef / ShellState — hand-written value object, 8 named transitions incl. closeCanvas / closeProject context-invalidation, no copyWith)
│   │   ├── providers/                 # shell_controller.dart (ShellNavigator Notifier + shellControllerProvider — sole write entry point) + active_project.dart (activeProjectProvider — read-only projection of ShellState.project) + gallery_dirty.dart (galleryDirtyProvider — any job reaching JobSucceeded marks *its own project's* gallery dirty, keyed by JobState.projectId; the gallery tab refreshes once on the invisible→visible edge **if the active project is dirty**, then clears that project's mark. State is a `Set<String?>` where `null` is the "project unknown" wildcard — unreachable in production, falls back to the old global semantics. NOT live refresh: a gallery the user is already looking at stays put until they switch away and back)
│   │   ├── util/                      # tab_availability.dart (hasNarrativeEdges / canExportVideo — pure predicates moved verbatim out of the deleted canvas_top_chrome.dart)
│   │   └── widgets/                   # ink_shell.dart (sole root Scaffold + chrome + tab bar; also hosts CanvasJobListener, so a job reaching a terminal state invalidates *its own canvas's* node controller even when no canvas page is mounted) / shell_content_stack.dart (outer Stack: tab host under an ExcludeFocus + overlay on top; inner five-slot IndexedStack; fallback focus) / shell_keep_alive_host.dart (five lazily-materialized, then permanent tab slots) / shell_chrome.dart (the tree's only InkWindowChrome; trailing = ⌘K chip + notification bell + ⚙) / shell_breadcrumb.dart / shell_empty_state.dart / shell_overlay_layer.dart (ModalBarrier scrim + the settings overlay — ShellOverlay 只剩 settings（P7 删掉内置示例页）; NOT kept alive; the barrier is what stops click-through) / shell_tab_bar.dart (wires ShellState into the theme-layer InkShellTabBar — that component knows nothing about ShellTab, see test/quality/no_reverse_layer_import_test.dart；画布标签右侧 = 「在序列中查看」〔切到序列标签 + 播放头跳到选中节点所在的镜，走 sequence_playhead 的 selectShot；本体 PR-8b 起在 sequence/util/view_in_sequence.dart，与节点右键菜单共用〕+「导出视频」，PR-6 撤掉了「导入脚本」) / shell_status_bar.dart (壳级状态栏：左侧随标签的计数 + 任务胶囊 + 右侧存储路径 / 版本) / shell_task_capsule.dart (PR-6 状态栏任务胶囊，取代画布底栏的渲染队列：全部 job、所有标签下都在；活动态「生成中 N · 排队 M」/ 终态「任务 N · 失败 K」/ 注册表空不画；点开任务弹层，再点或 Esc 关) / shell_task_popover.dart (任务弹层：数据与动作照搬原渲染队列——活动在前终态在后、源节点名回退 provider 名、取消 / 定位〔跨画布先 openCanvas 再单选 + 居中〕/ 清除已完成、「并发 N」) + tabs/ (studio / canvas / sequence / gallery / export bodies)
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
│   │   ├── util/                      # timecode.dart (HH:MM:SS:FF / 短格式，24fps 常量——帧率无字段) + view_in_sequence.dart (PR-8b 从 shell_tab_bar 原样搬出：viewInSequence 切到序列标签并把播放头跳到节点所在那一镜〔临时订阅撑过一帧〕；标签栏「在序列中查看」与节点右键菜单「在序列中定位」共用) + shot_index.dart (节点在序列哪一镜的唯一判据，纯函数：shotIndexForSelection〔跳哪一镜、「在序列中定位」可不可点〕+ shotIndexByNode〔每个节点所在那一镜；左栏大纲与 ⌘K 的「序列 NNN」经 outline_model.sequenceShotNumbers 用它〕)
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
    ├── app_teardown.dart              # Ordered shutdown (capture window state → flush pending writes → JobQueue → Pool → PG)
    ├── pending_write_registry.dart    # InMemoryPendingWriteRegistry（两个口：flushAll 退出前把「用户已改、还没落盘」的挂起写入冲掉；flushBeforeEdit 撤销 / 重做前冲写，失败照常退避重试、超时记 warn、日志 module pending_writes.flush；2s 总预算封顶，超时只记日志不阻断退出。feature 侧实现 core/interfaces/pending_write_flush.dart 的 PendingWriteFlushable 并自己注册——teardown 只认这一个抽象，不反向依赖 features；BOARD 第 201 行）
    ├── window_state_service.dart      # DefaultWindowStateService + clampBoundsToVisible pure fn (window size/pos/maximized memory; multi-monitor clamp; PL-6)
    ├── window_manager_adapters.dart   # WindowManagerWindowController + ScreenRetrieverDisplayQuery (real plugin seams behind WindowController/DisplayQuery)
    ├── crash_reporter.dart            # FileCrashReporter (uncaught-error crash file + keep-3 rotation, no context/extra)
    ├── notification_sound/            # 提示音出声：notification_sound_player.dart（NotificationSoundService 实现：InkFrame 默认 / 系统 / 自定义 / 关闭四档，1200ms 节流）+ audio_clip_player.dart（media_kit 播 asset 或自定义文件，最长 4 秒）+ system_alert_sound.dart（Windows PlaySoundW 别名 Notification.Default / macOS NSBeep）
    ├── file_notification_sound_store.dart  # 自定义提示音文件：config/sounds 下复制一份（扩展名白名单、≤2MB、先写 .partial 再改名），按文件名解析
    ├── silent_notification_sound_service.dart  # 默认的静音实现（main.dart 覆盖成真播放器；测试默认不出声）
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
