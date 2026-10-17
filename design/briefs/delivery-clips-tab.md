# delivery-clips-tab · 交付面板「片段」页签：只读镜头表，点一行播放头跳到那一镜
- 波次：W14 / lane：E / 基底：叠在 export-in-task-popover 之后（从 `feat/export-in-task-popover` 起分支）
- 依赖切片：export-in-task-popover（同 lane 前序，只为串行 rebase，不用它的 API）；duration-format（W0，本片不用，时长列是时间码不是「时长文案」）
- 阻塞决定：无

## 执行约定
1. 在你自己的工作树里，从 `feat/export-in-task-popover`（若已合入则 origin/main）起新分支 `feat/delivery-clips-tab`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行——本片一行都不加。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法——本片不涉及节点写入。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 本片补充：**同 lane 前序 export-in-task-popover 正在改 export_controller / delivery_controller / shell_task_popover / shell_task_capsule，一行都不要碰**；`sequence_playhead.dart` 的 `selectShot` 已存在，只调用不改（slices.json 把它列进 files 是多余的）。

## 目标
序列标签右侧交付面板的页签条现在只有「交付」能看，「片段」「历史」是死标签。做完后点「片段」切到一张只读镜头表：序号 · 缩略 · 镜头名 / 导出文件名 · 时长，和主按钮「交付」将要产出的镜头一一对应；没有视频产物的镜画虚线框并写「无视频产物 → 空隙 + 标记」；画幅不一致的镜点名。点一行，监视器与播放头跳到那一镜。「历史」仍是不可点的标签（下一片接）。

## 设计依据
- 画板 `b2/project/ShellExport.dc.html` 「导出第二批」小节右下的交付面板（320 宽，页签 交付 / 片段 / 历史，「片段」选中）。
- 规则原文：「片段 = deliveryPlanProvider 的镜头表，与主按钮同源、只读；占位 / 尺寸不一致取自交付前检查」「点一行 = 播放头跳到那一镜」。
- 行几何（画板 html）：行高 30 + 1px 下沿（`#1F1F1F` ≈ surface1）；左右 padding 10；gap 8；序号 mono 10px fg 灰、宽 22（`001`）；缩略 36×20、圆角 2；名称 11px 浅色 + 下一行文件名 mono 9px 暗灰（`001_镜头01.mp4`）；右侧时长 mono 10px（`00:05:00`）。占位行：缩略换成 34×18 虚线框（琥珀暗色），第二行写「无产物 → 空隙 + 标记」琥珀色。
- 设计缺口：①画板没画「尺寸不一致」的行长什么样——按本单 R5 处理（第二行追加琥珀色「画幅 9:16 不一致」）；②没画空态（链上 0 镜）；③没画当前播放镜的高亮——沿用序列左栏链表行的选中底色 surface5；④没画「片段」页时底部摘要（输出 / 包含）在不在——画板片段卡只有页签 + 行，本片只在「交付」页显示底部摘要与滚动设置区，结果条（上一次交付回执）三页都显示。

## 允许改的文件
- `lib/features/export/widgets/delivery_panel.dart`：`DeliveryPanel` 改成 `ConsumerStatefulWidget`，持有当前页签；`_Tabs` 接 `selected` / `onSelect` / 可点判据；`_PanelFrame` 下的 child 按页签切换（交付 = 现有滚动区 + `_Footer`；片段 = `DeliveryClipsTab`）。改文件头注释里「后两个只画标签不挂内容」这句。
- `lib/features/export/widgets/delivery_clips_tab.dart`（新建）：`DeliveryClipsTab` 与行组件。
- `lib/features/export/util/delivery_clip_rows.dart`（新建，归属表外的新文件，无冲突）：纯函数，plan + preflight → 行视图。
- `lib/theme/tokens.dart`：只追加 `InkDeliveryListSize`（rowHeight 30、indexWidth 22、thumbWidth 36、thumbHeight 20、placeholderWidth 34、placeholderHeight 18）。
- `test/features/export/util/delivery_clip_rows_test.dart`（新建）
- `test/features/export/widgets/delivery_clips_tab_test.dart`（新建）

## 不许碰的文件
- 同 lane 前序：`export/providers/export_task_registry.dart`、`export_controller.dart`、`delivery_controller.dart`、`shell/widgets/shell_task_popover.dart`、`shell_task_capsule.dart`。
- 同 lane 后序（W15）：`export/widgets/delivery_history_tab.dart`（不要预建）、`export/providers/export_history_provider.dart`。
- W14 其他 lane：`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`、`widgets/node_card.dart`、`widgets/stage_edge_layer.dart`、`widgets/canvas_toolbar.dart`、`widgets/text_node_inspector.dart`、`util/outline_model.dart`、`generation/generation_controller.dart`、`left_rail/left_rail_panel.dart`、`widgets/canvas_inspector_panel.dart`、`widgets/canvas_screen.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`、`left_rail/assets_panel.dart`、character-kind 那组文件。
- `lib/features/sequence/providers/sequence_playhead.dart`、`sequence/widgets/sequence_screen.dart`（W13 已改完；它的 `_thumbFile` / `_Thumb` 是私有的，不要去公开它们，本片自己解析缩略）。
- `export/models/delivery_plan.dart`、`export/util/delivery_preflight.dart`、`export/widgets/delivery_panel_rows.dart`、`export/delivery_keys.dart`。
- `create_node_menu.dart`、`canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W14）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- note-variant：`lib/features/canvas/models/canvas_node_note.dart`、`lib/features/canvas/providers/link_action_controller.dart`、`lib/features/canvas/util/canvas_note_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/shortcuts/note_keys.dart`、`lib/features/canvas/widgets/stage_edge_layer.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`lib/features/generation/generation_controller.dart`、`test/features/canvas/link_action_controller_test.dart`、`test/features/canvas/models/canvas_node_note_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/outline_model_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`test/features/canvas/widgets/note_node_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/features/generation/generation_controller_prompt_test.dart`
- panel-resize：`lib/core/models/app_preferences.dart`、`lib/features/canvas/providers/panel_widths.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/panel_resize_handle.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/providers/panel_widths_test.dart`、`test/features/canvas/widgets/canvas_inspector_tabs_test.dart`、`test/features/canvas/widgets/inspector_auto_save_row_test.dart`、`test/features/canvas/widgets/inspector_history_panel_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/panel_resize_test.dart`
- assets-hover-preview：`lib/core/interfaces/video_player_service.dart`、`lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`、`lib/features/canvas/widgets/left_rail/assets_panel.dart`、`lib/services/media_kit_video_player_service.dart`、`test/features/canvas/widgets/left_rail/asset_hover_preview_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/sequence/widgets/sequence_monitor_test.dart`
- character-kind：`lib/core/db/columns.dart`、`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/mention_candidates.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`lib/features/canvas/widgets/mention_popover.dart`、`lib/services/import/import_remapper.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/schema/schema_v11.dart`、`test/core/db/columns_schema_test.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/mention_candidates_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`、`test/quality/import_schema_sync_test.dart`、`test/quality/migration_registry_test.dart`、`test/services/import/import_remapper_test.dart`、`test/storage/repositories/project_import_writer_integration_test.dart`、`test/storage/schema/populated_migration_test.dart`
- export-in-task-popover：`lib/features/export/providers/delivery_controller.dart`、`lib/features/export/providers/export_controller.dart`、`lib/features/export/providers/export_task_registry.dart`、`lib/features/shell/widgets/shell_task_capsule.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`test/features/export/providers/delivery_execute_test.dart`、`test/features/export/providers/export_controller_test.dart`、`test/features/export/providers/export_task_registry_test.dart`、`test/features/shell/shell_task_capsule_test.dart`、`test/features/shell/shell_task_popover_test.dart`

## 具体改动
已有 API（照抄，均已核对）：
- `final deliveryPlanProvider = Provider.autoDispose.family<DeliveryPlan, String>(...)`（`delivery_plan_provider.dart` 约第 27 行），按 canvasId。
- `final deliveryPreflightProvider = Provider.autoDispose.family<DeliveryPreflight, String>(...)`（约第 80 行）。
- `DeliveryShotPlan { int index /* 1 起 */; String nodeId; String name; int durationMs; bool isPlaceholder; String? fileName; int? width; int? height; ... }`（`delivery_plan.dart` 约第 42 行）；`buildDeliveryPlan` 按 `lens.shots` 逐个出一镜、`index: i + 1`（约第 249 行）⇒ **plan.shots[k] 与 lens.shots[k] 一一对应**。
- `DeliveryCheck { id; level; List<String> aspectLabels; ... }`、`DeliveryCheckId.frameSize`、`DeliveryCheckLevel.warn`、`String? aspectRatioLabel(int? width, int? height)`（`delivery_preflight.dart`）。
- `void selectShot(int index)`（`sequence_playhead.dart` 第 51 行，**0 起**的 lens 下标）；`sequencePlayheadProvider(canvasId)`。
- `final sequenceLensProvider = Provider.autoDispose.family<SequenceLens, String>`；`SequenceShot.thumbnailRelativePath` / `canvasId`（`storyboard/models/sequence_shot.dart` 约第 59、63 行）。
- `File resolve({required String projectId, required String canvasId, required String relativePath})`，非法抛 `PathSecurityError`（`core/interfaces/file_resolver_service.dart`）。
- `String formatTimecodeShort(int ms)`（`sequence/util/timecode.dart` 第 19 行；5000ms → `05:00`，≥1 分钟带分位）。
- `InkDashedSlot({required child, onPressed /* null = 不可点 */, ...})`（`theme/primitives/ink_dashed_slot.dart`）。
- 常量 `kDvTabsHeight = 29`、`kDvTabWidth = 48`（`delivery_panel_rows.dart`）。

新增：
```dart
// delivery_panel.dart
enum DeliveryPanelTab { delivery, clips, history }
// DeliveryPanel 上的静态测试锚点（不进 delivery_keys.dart）
static Key tabKey(DeliveryPanelTab t); // ValueKey('delivery.tab.${t.name}')
// 本片可点集合：{delivery, clips}；history 仍只画标签（下一片放开）

// util/delivery_clip_rows.dart
@immutable class DeliveryClipRow {
  final int lensIndex;          // 0 起，传给 selectShot
  final int number;             // 1 起，显示为 3 位
  final String name;
  final String? fileName;       // 占位为 null
  final int durationMs;
  final bool isPlaceholder;
  final String? mismatchedRatio; // 画幅与链上首个比值不同才非 null
}
List<DeliveryClipRow> deliveryClipRows(DeliveryPlan plan, DeliveryPreflight preflight);

// widgets/delivery_clips_tab.dart
class DeliveryClipsTab extends ConsumerWidget {
  const DeliveryClipsTab({super.key, required this.canvasId, required this.projectId});
  static Key rowKey(int lensIndex); // ValueKey('delivery.clips.row.$lensIndex')
  static const Key emptyState;      // Key('delivery.clips.empty')
}
```
缩略图：watch `sequenceLensProvider(canvasId)`，取 `lens.shots[row.lensIndex]` 的 `thumbnailRelativePath` + `canvasId` 经 `fileResolverServiceProvider` 解析；`PathSecurityError` / 缺字段 / lens 长度对不上 → 画 surface 底色空框（不崩）。`Image.file` 带 `errorBuilder`。

## 行为规则与边界情况
- R1 默认页签是「交付」；点「片段」切过去，点「交付」切回；「历史」点了不切（本片）。当前页顶部 1px accent 线、底色 surface3 的现有画法随 `selected` 走。
- R2 片段行数 = `deliveryPlanProvider(canvasId).shots.length`，顺序同 plan；序号显示 `row.number` 补零 3 位；时长列 `formatTimecodeShort(durationMs)`。
- R3 非占位行：第一行镜头名（单行省略），第二行 `fileName`（mono，单行省略）。
- R4 占位行（`isPlaceholder`，含只有图片产物的镜）：缩略处画 `InkDashedSlot`（onPressed: null），第二行 `deliveryClipsPlaceholder`，accent 色。
- R5 `preflight` 的 frameSize 检查为 `warn` 时，非占位且 `aspectRatioLabel(w,h)` 不为 null 且 ≠ `aspectLabels.first` 的行，`mismatchedRatio` 为它的比值；行第二行在文件名后追加 ` · ` + `deliveryClipsAspectMismatch(ratio)`（accent）。宽高未知（null）的行**不算**不一致（与 preflight 头注同口径）。frameSize 为 ok 时一律 null。
- R6 点一行 = `ref.read(sequencePlayheadProvider(canvasId).notifier).selectShot(row.lensIndex)`；占位行也能点（监视器自己处理空隙镜）。不写库。
- R7 当前播放镜（`sequencePlayheadProvider(canvasId).select((p) => p.index)` == lensIndex）行底色 surface5；用 select 订阅，播放进度 report 不重建整表。
- R8 链上 0 镜（plan.isEmpty）：显示 `deliveryClipsEmpty` 居中说明（Key `DeliveryClipsTab.emptyState`），不报错。
- R9 无项目（`activeProjectProvider == null`）：保持现状——只剩「请先打开一个项目」，页签条照画但**全部不可点**（不碰仓储的门控不变）。
- R10 结果条（DeliverySucceeded / DeliveryFailed）在三页都显示在页签条下；底部摘要 `_Footer` 与设置滚动区只在「交付」页。
- R11 交付执行中切页签不影响交付（controller 在面板外）；切回「交付」页时设置区状态照旧（数据都在 provider 里）。
- R12 只读：行上没有右键菜单、没有拖动、没有编辑。
- R13 无平台差异：纯 Flutter 绘制 + 已有 provider，不碰文件对话框 / 进程。

## 新文案键
| key | en | zh |
|---|---|---|
| deliveryClipsPlaceholder | No video → gap + marker | 无视频产物 → 空隙 + 标记 |
| deliveryClipsAspectMismatch | Frame {ratio} differs | 画幅 {ratio} 不一致 |
| deliveryClipsEmpty | No shots on the narrative chain yet. Link config nodes with narrative edges to build the sequence. | 叙事链上还没有镜头。用叙事边把配置节点连起来，序列就有了。 |

`deliveryClipsAspectMismatch` 占位符 `ratio`（String）。

## 测试
先写、先红。
`test/features/export/util/delivery_clip_rows_test.dart`
- `rows follow plan order with 0-based lensIndex and 1-based number`：3 镜 plan → lensIndex 0,1,2；number 1,2,3。
- `placeholder rows carry no file name`：isPlaceholder 行 fileName == null。
- `mismatch marks only shots whose ratio differs from the first seen`：16:9、9:16、16:9 + warn → 只有第 2 行 mismatchedRatio == '9:16'。
- `unknown size is never a mismatch`：width null 的行在 warn 下仍为 null。
- `ok frame-size check marks nothing`：preflight ok → 全 null。

`test/features/export/widgets/delivery_clips_tab_test.dart`（项目上下文用 `shellControllerProvider.overrideWith(() => ShellNavigator(initial: ShellState(...)))` 播种——与 delivery_panel_test 约第 161 行同款，**不要 override activeProjectProvider**（只读投影）；ProviderScope 覆写 `deliveryPlanProvider(canvasId)`、`deliveryPreflightProvider(canvasId)`、`sequenceLensProvider(canvasId)`；用 `pumpInkApp` 或 delivery_panel_test 同款装配）
- `clips tab switches body and back`：点 `DeliveryPanel.tabKey(clips)` 后 `rowKey(0)` 出现、`DeliveryKeys.footerOutput` 消失；点 delivery 回来反之。
- `history tab is still inert`：点 history，body 不变（仍见 footer）。
- `tapping a row selects that shot on the playhead`：点 `rowKey(2)` → `container.read(sequencePlayheadProvider(c)).index == 2` 且 seekToken 自增。
- `placeholder row shows gap hint`：占位行见 `deliveryClipsPlaceholder` 文案。
- `mismatched row names the ratio`：见 `Frame 9:16 differs`。
- `empty chain shows empty state`：plan.empty → `DeliveryClipsTab.emptyState`。
- `no project keeps tabs inert`：project null → 点 clips 不出现 rowKey。
- `result bar stays visible on clips tab`：覆写 deliveryControllerProvider 为 DeliverySucceeded → 切 clips 后 `DeliveryKeys.resultBar` 仍在。

## 变异点
- M1 把 `delivery_clip_rows.dart` 里 `lensIndex: k` 改成 `lensIndex: shot.index`（1 起）→ `tapping a row selects that shot on the playhead` 与 `rows follow plan order…` 变红。
- M2 去掉 R5 里「宽高为 null 跳过」的判据 → `unknown size is never a mismatch` 变红。
- M3 把 mismatch 判据改成「frameSize level 不看、只比比值」→ `ok frame-size check marks nothing` 变红。
- M4 `_Tabs` 的可点集合加上 history → `history tab is still inert` 变红。
- M5 把结果条从 `_PanelFrame.extra` 挪进「交付」页 body → `result bar stays visible on clips tab` 变红。
- M6 删掉无项目分支里的「页签不可点」→ `no project keeps tabs inert` 变红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/export test/features/sequence test/quality`（排除 golden）。
- 逐条做上面 M1–M6 变异。
- 截图（`test/_harness/screenshot.dart` 的 `pumpScreenshotScene`）：`DeliveryPanel(canvasId: 'c1')`，shellController 播种项目 Alpha、plan 3 镜（第 3 镜占位、第 2 镜 9:16）、preflight frameSize warn、lens 带缩略；截①「片段」页（playhead 在第 1 镜）②「片段」页空态 ③「交付」页（确认原样）。

## 风险与不确定
- export-in-task-popover 若改了 `delivery_panel.dart` 的结果条（例如把「取消」挪进面板），rebase 时以它为准，本片只改页签与 body 切换。
- plan 与 lens 的下标对齐依赖 `buildDeliveryPlan` 逐 lens.shots 一镜的实现（已核对）；若将来 plan 跳镜，lensIndex 要改用 nodeId 反查——测试 M1 会兜住当前约定。
- 设计缺口见「设计依据」四条；尺寸不一致的标法是本单自定，画板定稿后可能要改文案。
