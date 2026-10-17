# assets-hover-preview · 素材格悬停 400ms 出大预览，贴面板右沿外；视频静音循环播前 6 秒
- 波次：W14 / lane：C / 基底：origin/main（前序波已合入）
- 依赖切片：无硬依赖（duration-format W0 的统一时长格式只调用）
- 阻塞决定：无

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W13 已合入）起新分支 `feat/assets-hover-preview`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表每片只追加一行——本片不碰任何注册表。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法——本片不碰节点。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 视频只经 `VideoPlayerService`（`videoPlayerServiceProvider`）播放，测试覆写成假播放器；不在 widget 里直接 new media_kit `Player`。

## 目标
- 鼠标在左栏素材格上停 400ms，面板右沿外弹出一张大预览卡：图片画原图，视频静音自动播、只循环前 6 秒；卡下一行写标签与时间（视频再加片长）。
- 鼠标移开、面板滚动、按任意键、点格子，预览立即收起；正在预览的格子描 2px accent 边。

## 设计依据
`b2/project/GapsPanels.dc.html`（文本版 SCRATCH/boards/GapsPanels.txt）小节「素材：悬停预览 · 导入的怎么显示」：
- 「悬停 400ms 出大预览，贴面板右沿外；移开 / 滚动 / 按键即收；视频静音循环前 6 秒」。
- 稿面（b2_gaps_panels.js 约第 197–200 行）：卡 = surface4 底、1px overlayBorder、圆角 6、内边距 6、阴影 `0 24px 64px rgba(0,0,0,0.6)`（= `InkShadow.overlay`）；媒体 16:9、圆角 3、cover；下方 10 号 fg4 说明两行；被预览的格子「outline: 2px solid accent; outline-offset: 1px」。稿里的卡是缩小示意（160×90），并注「实际贴在面板右沿外」。
- 「导入」小标、来源 chip、`origin == import` 归 assets-gallery-import-origin（后序片），本片不做。
- 设计缺口：① 预览实际尺寸没定——本片定媒体宽 320（16:9 → 180 高），追加 token；② 尺寸行「1920×1080」——`GalleryItem` 没有宽高字段（只有 durationMs / thumbnailRelativePath），本片不画尺寸，只画「标签」+「时间 · 片长」；③ 预览卡底部放不下时的处理没画——纵向夹在 Overlay 可视区内；④ 文件丢失 / 视频打不开没画——退回缩略图或类型图标，不报错。

## 允许改的文件
- `lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`（新建）：悬停控制（计时、收起条件、OverlayPortal）+ 预览卡 + 视频小播放器。
- `lib/features/canvas/widgets/left_rail/assets_panel.dart`：`_AssetTile` 包进悬停控制；`ListView` 滚动时收起；被预览格子描 2px accent。
- `lib/theme/tokens.dart`：只追加 `class InkAssetPreviewSize { static const double mediaWidth = 320; }`。
- `lib/core/interfaces/video_player_service.dart`：`VideoPlayerHandle` 追加 `Future<void> setVolume(double volume)` 与 `Future<void> setLooping(bool looping)`（**偏离归属表**，见风险）。
- `lib/services/media_kit_video_player_service.dart`：实现上面两个方法（`_player.setVolume(volume * 100)`、`_player.setPlaylistMode(looping ? PlaylistMode.single : PlaylistMode.none)`）。
- `test/features/sequence/widgets/sequence_monitor_test.dart`：唯一的 `VideoPlayerHandle` fake（约第 24 行 `_FakeHandle`）补两个空实现。
- 测试：`test/features/canvas/widgets/left_rail/asset_hover_preview_test.dart`（新建）、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`（加用例）。

## 不许碰的文件
- W14 同波：note-variant 的 `node_card.dart`、`stage_edge_layer.dart`、`create_menu_*`、`canvas_toolbar.dart`、`text_node_inspector.dart`、`outline_model.dart`、`generation_controller.dart`；panel-resize 的 `left_rail/left_rail_panel.dart`、`panel_resize_handle.dart`、`panel_widths.dart`、`canvas_inspector_panel.dart`、`canvas_screen.dart`、`app_preferences.dart`、`file_preferences_service.dart`；character-kind 的 `character*`、`import_remapper.dart`、`columns.dart`、迁移；export-in-task-popover / delivery-clips-tab 的 `export/**`、`shell_task_*`。
- `left_rail/assets_model.dart`（不改纯函数）、`gallery/**`（只调用 `galleryResolveFile` / `galleryTimeAgo`）、`video_lightbox.dart`、`sequence_monitor.dart`、`create_node_menu.dart`、`models/canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W14）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- note-variant：`lib/features/app_actions/app_action_catalog.dart`（只换 newNote 占位行）、`lib/features/canvas/models/canvas_node_note.dart`、`lib/features/canvas/providers/link_action_controller.dart`、`lib/features/canvas/util/canvas_note_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/shortcuts/note_keys.dart`、`lib/features/canvas/widgets/stage/stage_edge_layer.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`lib/features/generation/generation_controller.dart`、`test/features/canvas/link_action_controller_test.dart`、`test/features/canvas/models/canvas_node_note_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/outline_model_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`test/features/canvas/widgets/note_node_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/features/generation/generation_controller_prompt_test.dart`
- panel-resize：`lib/core/models/app_preferences.dart`、`lib/features/canvas/providers/panel_widths.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/panel_resize_handle.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/providers/panel_widths_test.dart`、`test/features/canvas/widgets/canvas_inspector_tabs_test.dart`、`test/features/canvas/widgets/inspector_auto_save_row_test.dart`、`test/features/canvas/widgets/inspector_history_panel_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/panel_resize_test.dart`
- character-kind：`lib/core/db/columns.dart`、`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/mention_candidates.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`lib/features/canvas/widgets/mention_popover.dart`、`lib/services/import/import_remapper.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/schema/schema_v11.dart`、`test/core/db/columns_schema_test.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/mention_candidates_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`、`test/quality/import_schema_sync_test.dart`、`test/quality/migration_registry_test.dart`、`test/services/import/import_remapper_test.dart`、`test/storage/repositories/project_import_writer_integration_test.dart`、`test/storage/schema/populated_migration_test.dart`
- export-in-task-popover：`lib/features/export/providers/delivery_controller.dart`、`lib/features/export/providers/export_controller.dart`、`lib/features/export/providers/export_task_registry.dart`、`lib/features/shell/widgets/shell_task_capsule.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`test/features/export/providers/delivery_execute_test.dart`、`test/features/export/providers/export_controller_test.dart`、`test/features/export/providers/export_task_registry_test.dart`、`test/features/shell/shell_task_capsule_test.dart`、`test/features/shell/shell_task_popover_test.dart`
- delivery-clips-tab：`lib/features/export/util/delivery_clip_rows.dart`、`lib/features/export/widgets/delivery_clips_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/util/delivery_clip_rows_test.dart`、`test/features/export/widgets/delivery_clips_tab_test.dart`

## 具体改动
已有签名（核对过）：
```dart
// core/interfaces/video_player_service.dart 约第 8–28 行
abstract class VideoPlayerService { VideoPlayerHandle create(); }
abstract class VideoPlayerHandle { Future<void> open(String filePath); Future<void> play(); Future<void> pause(); Future<void> seek(Duration at);
  Stream<Duration> get positionStream; Stream<Duration?> get durationStream; Stream<bool> get playingStream; Future<void> dispose(); Object get rawPlayer; }
// core/di/video_player.dart 约第 8 行：videoPlayerServiceProvider
// services/media_kit_video_player_service.dart：open() = _player.open(Media(path), play: true)
// gallery/widgets/gallery_actions.dart 约第 26 行
File? galleryResolveFile(WidgetRef ref, {required String projectId, required String canvasId, required String relativePath});
// gallery/util/gallery_time.dart 约第 4 行：String galleryTimeAgo(AppLocalizations l, DateTime at, DateTime now);
// gallery/models/gallery_item.dart：GalleryItem{kind, relativePath, canvasId, canvasName, nodeId, createdAt, slotIndex, durationMs, thumbnailRelativePath}
// assets_panel.dart 约第 475 行 _AssetTile({projectId, item, caption, onTap})，约第 512 行 InkActivatable(builder: (ctx, hovered, focused) …)
```
新增（`asset_hover_preview.dart`）：
```dart
const Duration kAssetPreviewHoverDelay = Duration(milliseconds: 400);
const Duration kAssetPreviewLoopLength = Duration(seconds: 6);
/// 一个格子的悬停宿主：进 → 起 400ms 计时；到点 → 开 OverlayPortal；出 / 点 / 按键 / dismiss() → 收。
class AssetHoverPreviewTarget extends StatefulWidget {
  const AssetHoverPreviewTarget({super.key, required this.controller, required this.id, required this.anchorKey,
    required this.preview, required this.child});
  final AssetHoverPreviewController controller; // 面板级：同一时刻只有一张预览
  final String id;                              // galleryItemKey(item)
  final GlobalKey anchorKey;                    // AssetsPanel 根节点的 key：取面板右沿
  final WidgetBuilder preview;
  final Widget child;
}
class AssetHoverPreviewController extends ChangeNotifier { String? get showingId; void dismiss(); }
class AssetPreviewCard extends ConsumerWidget { /* projectId, item, caption */ }
class _LoopingMutedVideo extends ConsumerStatefulWidget { /* filePath, posterFile */ }
```
`assets_panel.dart`：`_AssetsPanelState` 持有一个 `AssetHoverPreviewController`（dispose 时释放）与面板根 `GlobalKey`；`ListView` 外包 `NotificationListener<ScrollNotification>`，任何滚动 → `controller.dismiss()`；`_AssetTile` 多一个 `previewing` 参数，为 true 时 foregroundDecoration 改 2px accent（outline 之外 1px 偏移，用 `InkRadius.s5` 外径）。

视频（`_LoopingMutedVideo`）：`create()` → `setVolume(0)` → `setLooping(true)` → `open(path)`；订阅 `positionStream`，位置 ≥ 6 秒 → `seek(Duration.zero)`；`open` 完成前画首帧缩略（`thumbnailRelativePath`），没有缩略画类型图标；dispose 时取消订阅并 `handle.dispose()`。`rawPlayer is Player` 时用 media_kit_video 的 `Video(controller: VideoController(raw), controls: …空)`，与 `video_lightbox.dart` 约第 52–56 行同一做法；假播放器（不是 Player）时只画缩略。

## 行为规则与边界情况
- R1 指针进入格子满 400ms 才出预览；不足 400ms 移出 ⇒ 永不出现（计时器取消）。
- R2 同一时刻至多一张预览：A 的预览开着时移到 B，A 立即收起，B 重新计 400ms。
- R3 收起条件（任一即收，且取消未到点的计时）：指针移出格子；面板内任何滚动；任意按键按下（`HardwareKeyboard` 监听，只看 KeyDownEvent）；点格子（点照常执行定位）；面板卸载 / 切页 / 左栏收起。
- R4 位置：卡左沿 = 面板根节点右沿 + `InkSpacing.sm`（面板宽怎么变都贴右沿，和 panel-resize 无耦合）；卡顶与格子顶对齐，纵向夹在 Overlay 可视区内（下面放不下往上推）。
- R5 预览卡不接指针（`IgnorePointer`）：不会因为卡挡住而触发移出 / 移入抖动。
- R6 图片：`Image.file` cover，解码宽 = `InkAssetPreviewSize.mediaWidth × dpr`；文件不存在 / 解码失败 ⇒ thumbFill 底 + 类型图标。
- R7 视频：静音（音量 0 在 `open` 之前设）；只播前 6 秒循环；短于 6 秒的整段循环（`setLooping(true)`）；`open` 失败（InkError 或 Future 报错由服务层抛出的具体类型）⇒ 停在首帧缩略，不弹卡、不打日志刷屏（只记一次 warn）。
- R8 收起即释放：预览卡卸载时 dispose 播放器 handle；快速掠过多格不得残留 handle（计时器到点前不创建播放器）。
- R9 说明行：第一行 = 格子同一个标签（「源配置名 · take N」/「成片」/「#n」）；第二行 = `galleryTimeAgo` + 视频时追加「 · 片长」（走 duration-format 的统一格式，未知片长不写）。
- R10 键盘焦点 / 读屏：预览只跟随指针悬停，键盘聚焦格子不出预览（避免与 Tab 遍历冲突）；预览卡对读屏 `excludeSemantics`。
- R11 动画：出现用 `InkMotion.fast` 淡入；`MediaQuery.disableAnimations` 时无动画。
- R12 平台：macOS 触控板两指滚动与 Windows 滚轮都产生 ScrollNotification，同一条收起路径；无其他平台差异。

## 新文案键
无（标签复用 `_captionOf` 的现有文案，时间复用 `galleryTimeAgo`，片长复用统一时长格式）。

## 测试
先写、先红。均用 `TestGesture(kind: PointerDeviceKind.mouse)` 悬停，`tester.pump(Duration)` 控时。
- `asset_hover_preview_test.dart`（覆写 `videoPlayerServiceProvider` 为记录调用的假服务，`fileResolverServiceProvider` 指向临时目录文件）：
  - `no preview before 400ms`（pump 399ms 找不到卡）/ `preview appears after 400ms`。
  - `moving out before delay cancels`。
  - `moving to another tile swaps preview`（始终只有一张卡）。
  - `scroll dismisses preview` / `key press dismisses preview` / `tap dismisses preview and still locates`。
  - `card is placed right of the panel edge`（卡 left ≥ 面板右沿 + 8）。
  - `video is muted before open and loops first 6 seconds`（调用序列 setVolume(0) → setLooping(true) → open；推送 position 6.1s ⇒ seek(0)）。
  - `player is disposed when preview hides`；`no player created when hover leaves before delay`。
  - `missing file falls back to placeholder`。
- `assets_panel_test.dart`：`previewing tile gets accent outline`。

## 变异点
- M1 把 `kAssetPreviewHoverDelay` 改成 0 / 去掉计时 → `no preview before 400ms` 红。
- M2 去掉滚动监听 → `scroll dismisses preview` 红。
- M3 去掉按键监听 → `key press dismisses preview` 红。
- M4 `setVolume(0)` 挪到 `open` 之后 → `video is muted before open and loops first 6 seconds` 红。
- M5 去掉 6 秒处 seek → `video is muted before open and loops first 6 seconds` 红（推送位置 6.1s 后没有 seek(0)）。
- M6 卸载时不 dispose handle → `player is disposed when preview hides` 红。
- M7 计时开始就 create 播放器 → `no player created when hover leaves before delay` 红。
- M8 控制器允许两张并存 → `moving to another tile swaps preview` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/widgets/left_rail test/features/sequence/widgets/sequence_monitor_test.dart`；M1–M8 逐条变异。
- 截图：`CanvasLeftRail` + `CanvasLeftRailPanel`（素材页），ProviderScope 覆写 `activeProjectProvider`、`galleryControllerProvider`（3 图 1 视频）、`galleryGraphProvider`、`videoPlayerServiceProvider`（假）；截 ① 悬停图片格 400ms 后（卡贴面板右沿外、格子 accent 边）② 悬停视频格（首帧缩略 + 说明行带片长）③ 移开后无卡。暗 / 亮各一张。

## 风险与不确定
- **偏离归属表**：`video_player_service.dart`、`media_kit_video_player_service.dart`、`sequence_monitor_test.dart` 不在 W14 归属里；同波没有别的片碰它们（delivery-clips-tab 只调 `sequence_playhead.selectShot`）。不加接口方法就只能在 widget 里把 `rawPlayer` 强转 media_kit `Player` 调音量，假播放器下测不到静音，故选择加接口；实现方共 2 个（lib 1 + test fake 1）。
- media_kit 音量单位是 0–100；接口按 0–1 定义，实现里换算，注释写明。
- `open()` 内部是 `play: true`；若 media_kit 在 open 前设音量不生效，改为 open 后立即 `setVolume(0)` 并在回报里说明（M4 的断言随之调整）。
- 设计缺口：预览尺寸、尺寸行、底部溢出、文件缺失四项按上文处理，需设计确认。
