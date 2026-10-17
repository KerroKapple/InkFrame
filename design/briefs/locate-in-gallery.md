# locate-in-gallery · 节点右键「在画廊中定位」
- 波次：W12 / lane：E / 基底：origin/main（W0–W11 已合入）
- 依赖切片：menu-split（W0：`InkMenuEntry<String>`、`menu_registry.dart` 的 `CanvasMenuItemDef(id, scope, group, order, build, run)` / `CanvasMenuContext.targets`；节点菜单分组号 30 = 归类·定位，现有 `node.locateInSequence` 是 g30/o30）、help-actions（W3：`InkMenuEntry` 加了可选 `disabledReason`，置灰行悬停原因走它）、current-take（W1：`currentResultFor({required String sourceNodeId, required List<CanvasNode> nodes, bool Function(CanvasNode)? accept, String? pinnedResultId})`，`util/node_artifacts.dart`）
- 阻塞决定：无

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W11 已合入）起新分支 `feat/locate-in-gallery`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行。本片只在 `menu_registry.dart` 追加一行。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法。本片不写库。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. **不碰 `lib/features/canvas/util/node_menu_model.dart`**（W12 归 cm-multi-select-menu）。菜单项的可用判据写进本片新文件，不进 NodeMenuAction 枚举。

## 目标
画布节点右键菜单「定位」组里多一项「在画廊中定位」：点了切到画廊标签，单选对应那一格并把它滚进视口；
那一格被当前筛选挡住时先清掉筛选，筛选栏顶上出一行「已清除筛选」。节点没有产物时这一项置灰，悬停说「还没有产物」。

## 设计依据
- `b2/project/GapsCanvas.dc.html` ›「节点右键补项」（抽文：SCRATCH/boards/GapsCanvas.txt 第 103–139 行）：
  - 菜单项序列里「在序列中定位」下一行就是「在画廊中定位」（标「新」）；
  - 「分组：做 | take | 归类 | 定位 | 停用 · 删除；不可用的置灰不隐藏，悬停说原因」；
  - 「在画廊中定位：产物 = 它自己，配置节点 = 当前 take（currentResultFor）；没产物置灰」；
  - 「切到画廊标签，单选那一格并滚到它；被筛选挡住就清掉筛选，筛选条上说『已清除筛选』」。
- 设计缺口：「已清除筛选」提示的位置 / 何时消失没画。本片定为：筛选栏（GalleryFilterPanel）顶部一行 meta 字号 fg5，
  用户下一次改任何筛选即消失；清筛选是一次性整体清空（四轴全空），不只清挡住它的那一轴。
- 设计缺口：滚动用跳转还是动画没画。本片定为 `jumpTo`（目标行已完整可见则不滚）。
- 设计缺口：多选菜单下这一项的行为没画。本片只认「目标恰好一张」，多张置灰（原因同「还没有产物」之外另给一句，见新文案键）。

## 允许改的文件
- `lib/features/gallery/util/locate_in_gallery.dart`（新建）：纯判据 + `locateInGallery` 动作（见下）。
- `lib/features/gallery/providers/gallery_selection.dart`：追加挂起请求 `galleryLocateRequestProvider`（非 autoDispose、不分项目）。
- `lib/features/gallery/providers/gallery_filter.dart`：追加 `galleryFilterClearedNoticeProvider`（`StateProvider.family<bool, String>`，按 projectId）。
- `lib/features/gallery/widgets/gallery_grid.dart`：加 `ScrollController`；消费挂起请求（清筛选 / 单选 / 滚动 / 要焦点）。
- `lib/features/gallery/widgets/gallery_filter_panel.dart`：顶部「已清除筛选」一行；筛选一旦变为 active 就把提示置 false。
- `lib/features/canvas/widgets/canvas_menu/node_locate_gallery_entry.dart`（新建）：菜单项构建 + 执行。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（menu-split 新建）：`kCanvasMenuItems` 追加一行 `...nodeLocateGalleryItems`（`CanvasMenuItemDef(id: 'node.locateInGallery', scope: CanvasMenuScope.node, group: 30, order: 40, …)`，紧跟「在序列中定位」）。
- 测试：`test/features/gallery/util/locate_in_gallery_test.dart`（新建）、`test/features/gallery/widgets/gallery_locate_test.dart`（新建）、
  `test/features/canvas/widgets/canvas_menu/node_locate_gallery_entry_test.dart`（新建）。

## 不许碰的文件
- `lib/features/canvas/util/node_menu_model.dart`、`canvas_menu/multi_menu_entries.dart`、`canvas_menu/canvas_menu_host.dart`（W12 cm-multi-select-menu）。
- `canvas_menu/node_menu_entries.dart`（若 menu_registry 的「一行」够用就不碰；不够用停下回报）。
- toast-category-mute 的全部文件（`core/interfaces/toast_service.dart`、`notifications/**`、`export/widgets/export_video_dialog.dart`、`canvas/util/canvas_snackbars.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart` 等）。
- rail-script-panel / prompt-bar-mention-ui 的文件（`left_rail_state.dart`、`canvas_left_rail.dart`、`left_rail_panel.dart`、`shot_config_inspector.dart`、`canvas_prompt_bar.dart`、`inspector_submit_controller.dart`、`characters_section.dart`、`character_library_panel.dart`、`mention_*.dart`）。
- `lib/features/gallery/widgets/gallery_screen.dart`、`lib/features/shell/**`（只调用 `shellControllerProvider` / `activeProjectProvider`，不改）。
- `create_node_menu.dart`（barrel）、`canvas_node.dart`、`node_artifacts.dart`（只调用 `currentResultFor`）、ARB / generated / docs/CLAUDE.md。

**同波（W12）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- cm-multi-select-menu：`lib/features/canvas/util/node_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`、`lib/features/canvas/widgets/canvas_menu/multi_menu_entries.dart`、`lib/features/canvas/widgets/canvas_menu/node_menu_entries.dart`、`test/features/canvas/util/node_menu_model_test.dart`、`test/features/canvas/widgets/canvas_multi_menu_test.dart`
- toast-category-mute：`lib/core/interfaces/toast_service.dart`、`lib/core/models/app_preferences.dart`、`lib/features/canvas/util/canvas_snackbars.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/notifications/models/toast_entry.dart`、`lib/features/notifications/providers/toast_center.dart`、`lib/features/notifications/widgets/job_notification_listener.dart`、`lib/features/notifications/widgets/notification_bell.dart`、`lib/features/settings/providers/notification_prefs_controller.dart`、`lib/features/settings/widgets/notifications_section.dart`、`lib/services/file_preferences_service.dart`、`test/_harness/fake_toast_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/canvas_snackbars_test.dart`、`test/features/notifications/providers/toast_center_test.dart`、`test/features/notifications/widgets/job_notification_listener_test.dart`、`test/features/settings/notification_prefs_controller_test.dart`、`test/features/settings/notifications_section_test.dart`
- rail-script-panel：`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/providers/script_document_provider.dart`、`lib/features/canvas/util/canvas_shot_notes_actions.dart`、`lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/left_rail/script_model.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/canvas/widgets/shot_config_inspector.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/left_rail/script_model_test.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`
- prompt-bar-mention-ui：`lib/features/canvas/providers/inspector_submit_controller.dart`、`lib/features/canvas/util/mention_candidates.dart`、`lib/features/canvas/widgets/canvas_prompt_bar.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`lib/features/canvas/widgets/characters_section.dart`、`lib/features/canvas/widgets/mention_popover.dart`、`lib/features/canvas/widgets/mention_text_controller.dart`、`test/features/canvas/providers/inspector_submit_mention_test.dart`、`test/features/canvas/util/mention_candidates_test.dart`、`test/features/canvas/widgets/characters_section_mounted_guard_test.dart`、`test/features/canvas/widgets/mention_text_controller_test.dart`、`test/features/canvas/widgets/prompt_bar_mention_test.dart`

## 具体改动
现有 API（已核对）：
- `galleryItemKey(GalleryItem item) => '${item.canvasId}|${item.relativePath}|${item.slotIndex}'`（gallery_meta.dart 约第 18 行）。
- `galleryFilterMatches(GalleryFilter filter, GalleryItem item, GalleryItemMeta meta)`（gallery_filter.dart 约第 50 行）；`GalleryFilter.isActive`。
- `gallerySelectionProvider = StateProvider.family<GallerySelection, String>`；`GallerySelection.select(key)`。
- `galleryControllerProvider(projectId)`（AsyncValue<List<GalleryItem>>，同一 result 节点：主产物 slotIndex == null，批量 slot 带 slotIndex）。
- `galleryMetaProvider(projectId)`、`galleryGraphProvider(projectId)`（刷新走 invalidate，`skipLoadingOnRefresh` 网格不卸载，gallery_screen.dart 约第 48 行注释）。
- `ShellNavigator.openGallery(ProjectRef p)`（shell_controller.dart 约第 57 行）；`activeProjectProvider`（ProjectRef?）。
- `currentResultFor(sourceNodeId: config.id, nodes: nodes)`（W1 current-take；配置节点在 `nodes` 里时不用显式传 `pinnedResultId`）。W1 合入后 `latestResultFor` 若已无调用方会按 Zero-BC 删掉，本片不得回退到它。

新增签名：
```dart
// gallery/util/locate_in_gallery.dart
/// 画廊里该定位的 result 节点：产物节点（role == result 且 imageUrl / videoUrl 非空）= 自己；
/// image / video 配置节点 = currentResultFor；其余（文本、镜头、无产物）⇒ null。
CanvasNode? galleryLocateTarget(CanvasNode node, List<CanvasNode> nodes);

/// 在 [items] 里找 (canvasId, nodeId) 的格子：主产物（slotIndex == null）优先，否则 slotIndex 最小的 slot；没有 ⇒ null。
GalleryItem? galleryItemForNode(List<GalleryItem> items, {required String canvasId, required String nodeId});

/// 定位结果：要选中的 key + 是否需要先清筛选（目标不满足当前筛选）。找不到 ⇒ null。
typedef GalleryLocatePlan = ({String key, bool clearFilter});
GalleryLocatePlan? planGalleryLocate({
  required List<GalleryItem> items,
  required GalleryFilter filter,
  required GalleryItemMeta Function(GalleryItem) metaOf,
  required String canvasId,
  required String nodeId,
});

/// 网格滚动偏移：第 [index] 格所在行的顶边（含 padding）。纯函数。
double galleryRowOffset({required int index, required int columns, required double rowExtent, required double padding, required double gap});

/// 动作：invalidate galleryGraphProvider(project.id)（保证新 take 在列）→ 挂起请求 → openGallery(project)。
void locateInGallery(WidgetRef ref, {required ProjectRef project, required String canvasId, required String nodeId});

// gallery/providers/gallery_selection.dart（追加）
@immutable class GalleryLocateRequest { projectId, canvasId, nodeId; ==/hashCode }
final galleryLocateRequestProvider = NotifierProvider<GalleryLocateRequestController, GalleryLocateRequest?>(...);
// request(...) 新的覆盖旧的；consume(request) 只清它自己（同 canvas_focus_request.dart 的 consume 口径）。

// gallery/providers/gallery_filter.dart（追加）
final galleryFilterClearedNoticeProvider = StateProvider.family<bool, String>((ref, projectId) => false, name: ...);

// canvas_menu/node_locate_gallery_entry.dart
/// 节点菜单「在画廊中定位」一项；targets 恰好一张且 galleryLocateTarget != null 且有项目才可点；置灰时 `disabledReason:` 写原因。
InkMenuEntry<String> buildLocateInGalleryEntry(WidgetRef ref, AppLocalizations l, List<CanvasNode> targets, List<CanvasNode> nodes);
void runLocateInGallery(WidgetRef ref, {required String canvasId, required List<CanvasNode> targets, required List<CanvasNode> nodes});
final List<CanvasMenuItemDef> nodeLocateGalleryItems; // 一行：build = (c) => buildLocateInGalleryEntry(…c.targets…)，run = (c) => runLocateInGallery(…)
```
（行形状按 menu-split 派工单的 `CanvasMenuItemDef`；`InkMenuEntry.disabledReason` 由 W3 help-actions 加。）

gallery_grid 消费流程：`_GalleryGridState` 持 `ScrollController`（与现有 `PageStorageKey` 并存，`GridView.builder(controller: ...)`）；
build 里 watch `galleryLocateRequestProvider` 与 `galleryControllerProvider(projectId)`：请求的 projectId 等于本格 且 AsyncValue 有值且 `!isLoading`
⇒ 帧后执行一次：`planGalleryLocate` → 需要清筛选则 `filter = const GalleryFilter()` + notice = true → `selection = select(key)` →
在**清筛后的**列表里求 index，按 LayoutBuilder 记下的 `cols / rowExtent(h + s12)` 算 `galleryRowOffset`，不在视口内则 `jumpTo(clamp 0..maxScrollExtent)` → `_focus.requestFocus()` → consume。
找不到目标 ⇒ consume，不改选中、不改筛选，网格不滚。

## 行为规则与边界情况
- R1 产物节点（有 image/video url）右键：可点，定位到它自己的主产物格。
- R2 配置节点：定位到 `currentResultFor` 给出的 take；钉过的 take 优先于更新的那张（current-take 语义）。
- R3 配置节点没有任何产物 / 文本节点 / 镜头节点 / 生成中占位产物（url 空）：置灰，悬停原因 `canvasNodeMenuLocateInGalleryNoResult`。
- R4 目标 ≥2 张：置灰，原因 `canvasNodeMenuLocateInGallerySingleOnly`。外壳没有项目（activeProjectProvider == null）：置灰，复用 `exportVideoNoProjectTooltip`。
- R5 目标格满足当前筛选：不动筛选、不出提示；只单选 + 滚动。
- R6 目标格被筛选挡住（任一轴不命中）：四轴整体清空，notice = true，筛选栏顶出「已清除筛选」；用户再改任何筛选（isActive 变 true）即消失。
- R7 只有批量 slot、主产物路径与某 slot 重复被去重：取主产物；没有主产物取 slotIndex 最小那格。
- R8 画廊数据被 invalidate 后刷新中（isLoading）不消费；数据到了才落地。画廊标签首次露面（保活槽懒加载）请求同样在挂上后落地。
- R9 刷新后仍找不到（产物刚被删）：请求被消费掉，选中 / 筛选 / 滚动都不变；不弹提示（设计未画，见风险）。
- R10 连点两次不同节点：以后一次为准（request 覆盖），consume 只清自己。
- R11 目标行已完整在视口内：不滚动；在视口外：jumpTo 使该行顶边对齐视口顶边（夹到 maxScrollExtent）。
- R12 不进撤销栈：画布无任何写入，画廊筛选 / 选中是 UI 态。
- R13 无平台差异：纯 Flutter 布局与 provider 状态，没有平台通道或键位。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasNodeMenuLocateInGallery | Locate in gallery | 在画廊中定位 |
| canvasNodeMenuLocateInGalleryNoResult | No result yet | 还没有产物 |
| canvasNodeMenuLocateInGallerySingleOnly | Select a single node | 只能对一个节点定位 |
| galleryFilterClearedNotice | Filters cleared | 已清除筛选 |

## 测试
`test/features/gallery/util/locate_in_gallery_test.dart`
- `'result node targets itself'`：产物节点 → 返回自身。
- `'config node targets current take, pinned beats newest'`：两张 take，配置节点 typeConfig 写 `TakeKeys.pinnedResultId` = 旧的 → 返回旧的。
- `'config without results, text and shot nodes have no target'`：三者都返回 null；url 为空的占位产物也 null。
- `'primary item preferred over batch slots'`：同 nodeId 主产物 + slot → 主产物；无主产物 → slotIndex 最小。
- `'plan clears filter only when target is hidden'`：filter.kind = video、目标是 image → clearFilter true；filter 命中 → false。
- `'plan returns null when item missing'`。
- `'row offset uses row index and gap'`：index 7、5 列 → 第 1 行顶 = padding + rowExtent + gap。
`test/features/gallery/widgets/gallery_locate_test.dart`（ProviderScope 覆写 galleryGraphProvider 为 30 张图的固定图）
- `'pending request selects and scrolls to the tile'`：请求第 28 张 → selection.anchor == 其 key，ScrollController.offset > 0，该 tile 可见。
- `'hidden by filter clears filter and shows notice'`：预设 filter.kind = video → 落地后 filter == GalleryFilter()，找得到文案「已清除筛选」。
- `'notice disappears on next filter change'`：点任一筛选行 → 提示消失。
- `'request waits while refreshing'`：AsyncValue 处于 refresh 时不消费，数据到达后才选中。
- `'visible target does not scroll'`：目标在首行 → offset 仍为 0。
`test/features/canvas/widgets/canvas_menu/node_locate_gallery_entry_test.dart`
- `'entry disabled without result and shows reason'`、`'entry disabled for multiple targets'`、
- `'run switches to gallery tab and posts request'`：shell.tab == ShellTab.gallery，请求 == (projectId, canvasId, resultNodeId)。

## 变异点
- M1 把 `galleryLocateTarget` 里配置节点分支改成返回 null → `'config node targets current take, pinned beats newest'` 红。
- M2 把 `currentResultFor` 换成 `resultsFor(...).first`（不看固定）→ `'config node targets current take, pinned beats newest'` 红（钉旧的那张被换成最新）。
- M3 `galleryItemForNode` 去掉 `slotIndex == null` 优先 → `'primary item preferred over batch slots'` 红。
- M4 `planGalleryLocate` 恒返回 clearFilter: false → `'plan clears filter only when target is hidden'` 与 `'hidden by filter clears filter and shows notice'` 红。
- M5 gallery_grid 消费时去掉 `!isLoading` 判据 → `'request waits while refreshing'` 红。
- M6 删掉 jumpTo 调用 → `'pending request selects and scrolls to the tile'` 红。
- M7 filter_panel 去掉「isActive 时 notice = false」→ `'notice disappears on next filter change'` 红。
- M8 菜单项 enabled 判据去掉 `targets.length == 1` → `'entry disabled for multiple targets'` 红。

## 验收
- `flutter analyze lib test`；`flutter test --exclude-tags golden test/features/gallery test/features/canvas/widgets/canvas_menu`；变异 M1–M8 逐条红。
- 截图场景：`GalleryScreen(projectId: 'p1', projectName: 'Demo')`，ProviderScope 覆写 `galleryGraphProvider('p1')` 为 30 张图 / 视频混合；
  ① 未筛选，请求第 28 张 → 选中并滚到；② 预设 filter.kind = video、请求一张图 → 筛选栏「已清除筛选」+ 选中。
  画布侧：节点右键菜单打开态，配置节点有产物（可点）/ 无产物（置灰 + 悬停原因）两张。

## 风险与不确定
- 置灰原因字段已统一为 `InkMenuEntry.disabledReason`（W3 help-actions 加（主 Agent 跨批核对补充））。合入后若没有这个字段，停下回报，不要改 ink_menu_panel.dart / node_menu_entries.dart。
- 多选（≥2）时 W12 cm-multi-select-menu 的多选菜单取代节点菜单，本行实际只在单选节点菜单里出现；R4 的「多张置灰」保留作防御。
- slices.json 原足迹写了 `node_menu_model.dart` 与 `node_context_menu.dart`，已按归属表改为新文件 + registry 一行。
- R9 找不到时不提示：toast_service 在 W12 被 toast-category-mute 改接口，本片不引入 toast 调用；如主 Agent 要提示，W13 以后补。
- 每次定位都 invalidate 一次画廊图（一次读库），换来新 take 一定在列；画廊大项目上的耗时未测。
