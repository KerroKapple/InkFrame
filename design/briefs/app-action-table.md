# app-action-table · 共用动作表（id · 文案 · 键位 · 可用判据 · 执行）
- 波次 W1 / lane E / 基底：叠在 esc-ladder 之后（W0 全部合入后的 origin/main；若届时 esc-ladder 未合，从 `feat/zoom-reset-100` 起）；依赖：esc-ladder（注册表、`canvasBindingActivator`、`zoomCanvasBy` / `resetCanvasZoom`）、menu-split（`canvasMenuRequestProvider` 新路径）；阻塞决定：无。

> **执行代理约定**
> - 在自己的工作树里、从基底起分支 `feat/app-action-table`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表每片只追加一行（替换自己的占位行算一行）——本片**新建** app_action_catalog.dart 与 more_menu_model.dart 两张表。
> - CanvasNode 新派生属性写成新文件 extension；不给 Node/Edge/StyleLaneRepository 加抽象方法。
> - 新画布动作写进新文件；canvas_tool_actions.dart 在 W1 归 canvas-capsule，本片只调用其中现有函数，不改。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
1. 新建一张应用级动作表：每个动作 = id + ARB 文案 + 每平台一个主键（从快捷键注册表 / `CanvasToolKeys` / `kCommandPaletteActivators` 取，不另抄）+ 可用 / 启用判据 + 禁用原因 + 执行。
2. ⌘K 的「动作」组全部改从这张表按上下文过滤；用户在 ⌘K 里看到的动作集合与顺序与现在**完全一致**（本片是重构，不加 ⌘K 项）。
3. 工具条「更多」从 `kMoreMenuActionIds` + 动作表取项；第二批还没落地的动作（撤销、复制粘贴、查找、导入媒体、便签、包成泳道、F6 等）登记成禁用行，原因「即将推出」，供 W4 菜单栏灰着显示。

## 设计依据
- ShellExport.dc.html ›「顶部菜单栏」六个菜单（文件 / 编辑 / 画布 / 节点 / 窗口 / 帮助）的项与键位；规则：「菜单 / 右键菜单 / Ctrl K / 快捷键页共用一张动作表（id · 文案 · 键位 · 可用判据），改一处处处变」「不可用的灰着不藏，悬停说原因；『新』= 第二批的动作，接上之前一直灰着」「画布 / 节点两组只在画布标签可用；节点菜单的对象 = 当前选中集，与节点右键菜单同一判据」。
- ShellExport + critic.txt 第二节第 12 条：**重做主键 Windows Ctrl Y、macOS ⇧⌘Z**，动作表只有一个主键，菜单、快捷键页、撤销卡显示同一串。KeyMap ›「组合键」：「重做每平台只注册一个」。
- KeyMap ›「组合键」表给出第二批键位：Ctrl Z / ⌘Z、Ctrl C/X/V、Ctrl U / ⌘U、Ctrl F / ⌘F、Ctrl G / ⌘G、N、F6。
- 设计缺口：① ⌘K 里禁用项画不画——画板只说菜单「灰着不藏」，没画 ⌘K 的禁用行；本片定为 ⌘K 只列可用且启用的（`PaletteEntry` 没有禁用态，palette_search.dart 在 W1 归 current-take 不能改）。② 「更多」下拉的完整项表散在四张板上（critic 第一节「工具条 · 部分」），本片只放「导入脚本…」，其余由各自切片追加。③ mac 显示 `⇧⌘Z` 而现有 `formatShortcutActivator` 输出 `⌘⇧Z`（shortcut_catalog_test 第 203 行钉了这个顺序），本片不改格式器，记为缺口交 undo-shortcuts-ui 定。

## 允许改的文件
- `lib/features/app_actions/app_action.dart`（新）：`AppActionGroup`、`AppActionContext`、`AppAction`。
- `lib/features/app_actions/app_action_ids.dart`（新）：`AppActionIds`。
- `lib/features/app_actions/planned_keys.dart`（新）：`PlannedKeys`——第二批键位常量的唯一出处；后续切片注册绑定时引用它，不再手写第二份。
- `lib/features/app_actions/app_action_catalog.dart`（新）：`kAppActions`、`appActionById`、`comingSoon`。
- `lib/features/canvas/util/more_menu_model.dart`（新）：`kMoreMenuActionIds`。
- `lib/features/command_palette/command_actions.dart`：`buildCommandActions` 改为从 `kAppActions` 过滤；签名与 `CommandAction` 类不变；删掉私有的 `_addNode` / `_openExport` / `_backToStudio` 等（逻辑原样搬进 catalog 的 run；`_openExport` 例外，改调 `openExportVideoDialogForCanvas`，见下）。
- `lib/features/canvas/widgets/canvas_toolbar.dart`：删 `_MoreAction` 枚举（第 34 行）；`_showMoreMenu`（第 184–224 行）的 items 改为遍历 `kMoreMenuActionIds`。
- 测试：`test/features/app_actions/app_action_catalog_test.dart`（新）、`test/features/command_palette/command_actions_test.dart`（新）、`test/features/canvas/widgets/canvas_toolbar_test.dart`（追加用例）。

## 不许碰的文件
- nodes-batch-ops：`providers/canvas_nodes_controller.dart`、`util/canvas_node_delete.dart`（只调用 `deleteNodesWithUndo`）。
- narrative-splice：`providers/canvas_edges_controller.dart`、`util/narrative_splice.dart`。
- canvas-capsule：`widgets/shortcuts/core_canvas_keys.dart`、`util/canvas_tool_actions.dart`、`widgets/canvas_screen.dart`、`widgets/canvas_zoom_bar.dart`、`providers/canvas_capsule.dart`、`theme/components/ink_canvas_capsule.dart`。
- current-take：`util/node_artifacts.dart`、`command_palette/palette_search.dart`、`util/create_menu_model.dart`、`util/outline_model.dart`、`features/export/**`（含 open_export_dialog.dart、export_order.dart——只调用）、`gallery/util/gallery_meta.dart`、`features/sequence/**`（只调用 `viewInSequence`、`shotIndexForSelection`）。
- `util/node_menu_model.dart`：不许改，只调用 `generationTarget` / `duplicateSources` / `characterSource` / `canRemoveFromLane`。
- `settings/util/shortcut_catalog.dart`：只调用 esc-ladder 加的 `canvasBindingActivator` 与现有 `formatShortcutActivator`。
- （主 Agent 自查补充）narrative-splice：`lib/features/canvas/models/canvas_edge.dart`；current-take：`lib/features/canvas/models/canvas_node_take.dart`（新）、`left_rail/outline_panel.dart`、`lib/features/storyboard/models/sequence_shot.dart`、`lib/features/sequence/models/sequence_lens.dart`、`lib/core/constants/take_keys.dart`（新）、`lib/features/storyboard/util/sequence_builder.dart`；canvas-capsule：`lib/features/canvas/widgets/canvas_capsule_host.dart`（新）（主 Agent 跨批核对补充）。

## 具体改动
```dart
enum AppActionGroup { file, edit, canvas, node, window, help } // 与 shell_chrome.dart 第 112–117 行六个菜单一一对应（偏离：contract 写的是 file/edit/view/canvas/generate/window/help）
class AppActionContext {
  final BuildContext context; final WidgetRef ref; final ShellState shell;
  String? get canvasId; // shell.overlay == null && shell.tab == ShellTab.canvas ? shell.canvasId : null（与 command_actions 第 54–63 行同判据）
  factory AppActionContext.read(BuildContext context, WidgetRef ref);
}
class AppAction {
  const AppAction({required this.id, required this.group, required this.label, this.macKey, this.otherKey, this.icon,
    required this.isAvailable, required this.isEnabled, required this.disabledReason, required this.run,
    this.contextualLabel, this.inPalette});
  // contract 原字段，签名写全（主 Agent 跨批核对补充：W2 undo-shortcuts-ui、W3 import-media-command / help-actions、W4 win-menubar 都按这些名字用）：
  final String id; final AppActionGroup group;
  final String Function(AppLocalizations l) label;               // 静态文案；要上下文的走 contextualLabel，调用方一律用 labelFor
  final ShortcutActivator? macKey; final ShortcutActivator? otherKey; // 每平台一个主键；取用一律走 keyFor / keyLabel（没有 primaryKey 字段）
  final bool Function(AppActionContext c) isAvailable;
  final bool Function(AppActionContext c) isEnabled;
  final String? Function(AppActionContext c, AppLocalizations l) disabledReason; // isEnabled 为真时返回 null
  final FutureOr<void> Function(AppActionContext c) run;          // 调用方：a.run(AppActionContext.read(context, ref))
  // 三个可选字段（偏离，全是追加）：
  final IconData? icon;                                                    // ⌘K 行首图标，沿用 command_actions 现有 Icons.*
  final String Function(AppActionContext c, AppLocalizations l)? contextualLabel; // help-actions 的「有新版本 x.y.z · 下载」要用
  final bool Function(AppActionContext c)? inPalette;                      // null = 不进 ⌘K；进 ⌘K 还要 isAvailable && isEnabled
  String labelFor(AppActionContext c, AppLocalizations l);
  ShortcutActivator? keyFor({required bool isMac});      // isMac ? macKey : otherKey
  String? keyLabel({required bool isMac});               // formatShortcutActivator(keyFor(..), isMac: ..)
}
abstract final class AppActionIds { static const String undo = 'undo'; /* … 见下表 */ }
abstract final class PlannedKeys { // 全部 includeRepeats: false；字段名写死（主 Agent 跨批核对补充），后续切片注册绑定 / 菜单栏一律引用，不另抄
  static const SingleActivator undoMac, undoOther, redoMac /* ⇧⌘Z */, redoOther /* Ctrl Y */,
      cutMac, cutOther, copyMac, copyOther, pasteMac, pasteOther, findMac, findOther,
      importMediaMac, importMediaOther /* U */, wrapInLaneMac, wrapInLaneOther /* G */,
      newNote /* N，两平台同一个 */, focusNotifications /* F6，两平台同一个 */;
}
AppAction comingSoon(String id, AppActionGroup group, String Function(AppLocalizations l) label, {ShortcutActivator? macKey, ShortcutActivator? otherKey});
final List<AppAction> kAppActions;           // 顺序 = ⌘K 里的顺序；菜单栏排列由菜单栏切片自己的 id 表决定
AppAction? appActionById(String id);
final List<String> kMoreMenuActionIds = <String>[AppActionIds.importScript /* 后续每片追加一行 */];
```
**AppActionIds 与本片登记的行**（★ = `comingSoon` 占位行，每个一行，后续切片替换自己那一行；○ = 只定 id 不登记，由 W3 help-actions / W4 win-menubar 追加）：
- file：`newProject`（showStudioNewProjectDialog）· `openSampleProject`（createStudioSampleProject；帮助菜单复用同一个 id）· `importProject`（runProjectImportFlow）· `exportVideo`（不再原样搬 `_openExport`：改调 `features/export/open_export_dialog.dart` 的 `openExportVideoDialogForCanvas`——与导出标签、序列标签同一条路，按叙事链排序并拿到 current-take 的固定信息；主 Agent 自查补充，配合 current-take）· `openSettings` · ○`exportProject` · ○`deliver` · ○`trash` · ○`quit`
- edit：★`undo`（label `commonUndo`）· ★`redo` · ★`cut` · ★`copy` · ★`paste` · `duplicate` · `delete`（deleteNodesWithUndo）· `selectAll` · ★`find` · `commandPalette`（showCommandPalette）
- canvas：`openCreateMenu` · `addImageNode` · `addVideoNode` · `addTextNode` · `addShotNode` · ★`newNote` · `addLane` · `toggleLink` · `importScript` · ★`importMedia` · `selectTool` · `panTool` · `zoomIn` · `zoomOut` · `zoomReset` · `fitAll` · `fitSelection` · `toggleLeftRail`
- node：`generate` · `saveAsCharacter` · ★`wrapInLane` · `removeFromLane` · `locateInSequence` · ○`addToLane`（带子菜单，归菜单栏切片）
- window：`backToStudio` · ★`focusNotifications` · ○`showStudio` / `showCanvas` / `showSequence` / `showGallery` / `showExport` / `showTasks`
- help（全部 ○，W3 help-actions 登记）：`helpShortcuts` · `helpOnboarding` · `helpReleaseNotes` · `helpFeedback` · `helpManual` · `helpExportDiagnostics` · `helpOpenLogDir` · `helpCheckUpdate` · `helpAbout`
- 键位来源：画布动作 `macKey = canvasBindingActivator('<旧绑定 id>', isMac: true)`、`otherKey = …(isMac: false)`（如 selectAll ← `canvasSelectAll`、zoomReset ← `canvasZoomReset`）；`commandPalette` ← `kCommandPaletteActivators[0]/[1]`；★ 行 ← `PlannedKeys`；没键的（exportVideo、importScript、saveAsCharacter…）为 null。
- 执行体只调用现有函数：addNodeAtViewportCenter、addLaneViaDialog、toggleLinkMode、activateSelectTool、`canvasToolModeProvider.togglePan()`、selectAllNodes、fitAllNodes、fitSelectedNodes、generationTarget + generateNode、duplicateNodes、deleteNodesWithUndo、saveNodeAsCharacter（projectId = shell.project!.id）、moveNodesToLane(laneId: null)、viewInSequence、`leftRailProvider.toggle()`、`canvasMenuRequestProvider.openCreate(viewport.center, viewportCentered: true)`、zoomCanvasBy / resetCanvasZoom、showScriptImportDialog(origin: viewportCenteredNodeOrigin(type: shot))（toolbar 第 213–223 行原样）。
- `buildCommandActions`：`kAppActions.where((a) => a.inPalette?.call(c) == true && a.isAvailable(c) && a.isEnabled(c))` → `CommandAction(id: a.id, icon: a.icon ?? Icons.bolt_outlined, label: a.labelFor(c, l), run: (ctx, r) => a.run(AppActionContext.read(ctx, r)))`。
- 现有 ⌘K 上下文规则原样编码进各行的 `inPalette`：设置浮层开着 → 只 backToStudio；画布标签 → addImageNode、addVideoNode、addShotNode、exportVideo（`canExport` 不满足时 isEnabled=false，⌘K 不列、菜单灰）、backToStudio、openSettings；画廊标签且有项目 → backToStudio、openSettings；其余 → importProject、openSampleProject（⌘K 文案仍是 `studioCreateSampleProject`）、openSettings。
- 「更多」：每个 id 经 `appActionById` 取行，`isAvailable` 为假不画，`isEnabled` 为假画 `PopupMenuItem(enabled: false)` 并包 `Tooltip(message: disabledReason)`；选中后 `run(AppActionContext.read(anchor, ref))`。

## 行为规则与边界情况
1. 不在画布标签（或设置浮层开着）：canvas / node 组 `isAvailable` 为真、`isEnabled` 为假，原因「先打开一个画布」——菜单栏灰着不藏。
2. node 组判据 = 当前选中集，与节点右键菜单同一函数：generate 需 `generationTarget != null`；duplicate 需 `duplicateSources` 非空；delete 需选中非空；saveAsCharacter 需 `characterSource != null` 且外壳有项目；removeFromLane 需 `canRemoveFromLane`；locateInSequence 需 `shotIndexForSelection >= 0`。各自有原因文案（见下表）。
3. 每个 `isEnabled == false` 的情形 `disabledReason` 非 null；`isEnabled == true` 时返回 null。
4. ★ 行：isEnabled 恒假、原因「即将推出」、`run` 为空操作、`inPalette` 为 null。
5. ⌘K 的集合与顺序与改前一致（见「测试」2）；搜索、↓↵、⌘↵ 行为不变（palette_search.dart 不动）。
6. run 里跨 await 先查 `context.mounted`（沿用 command_actions 头注第 5 行的约定）；面板关闭到执行之间节点变了（如 exportVideo 链序首个为空）静默不弹，同现状。
7. mac / Windows：同一动作 `keyLabel(isMac: true)` 出 ⌘ 串、`false` 出 Ctrl 串；redo 例外地两平台不同键（⇧⌘Z / Ctrl+Y）。Windows 上没有 ⌘ 变体、mac 上没有 Ctrl 变体上屏。
8. 本片不改任何右键菜单的界面与判据；不进撤销栈。

## 新文案键
| key | en | zh |
|---|---|---|
| appActionRedo | Redo | 重做 |
| appActionCut | Cut | 剪切 |
| appActionCopy | Copy | 复制 |
| appActionPaste | Paste | 粘贴 |
| appActionFind | Find… | 查找… |
| appActionImportMedia | Import media… | 导入媒体… |
| appActionNewNote | Note | 便签 |
| appActionWrapInLane | Wrap in lane | 包成泳道 |
| appActionFocusNotifications | Notifications | 通知 |
| appActionCommandPalette | Command palette… | 命令面板… |
| appActionReasonComingSoon | Coming soon | 即将推出 |
| appActionReasonOpenCanvas | Open a canvas first | 先打开一个画布 |
| appActionReasonSelectNodes | Select nodes first | 先选中节点 |
| appActionReasonSelectOneConfig | Select one config node to generate | 选中一个配置节点才能生成 |
| appActionReasonSelectOneImage | Select one image result | 选中一张图像产物 |
| appActionReasonNotInLane | The selection isn't in a lane | 选中的节点不在泳道里 |
| appActionReasonNotInSequence | The selection isn't in the sequence | 选中的节点不在序列里 |
| appActionReasonNoVideo | No video to export yet | 还没有可导出的视频 |
| appActionReasonNoProject | Open a project first | 先打开一个项目 |
其余文案复用现有键：commonUndo、canvasAddImageNode / VideoNode / ShotNode、canvasToolTextNode、canvasBlankMenuNew、settingsShortcutCanvasAddLane、canvasToolLink、canvasAddImportScript、canvasToolSelect、canvasToolPan、settingsShortcutCanvasZoomIn / ZoomOut / ZoomReset / FitAll / FitSelection / ToggleLeftRail、canvasNodeMenuGenerate / Duplicate / SaveAsCharacter / RemoveFromLane / LocateInSequence / Delete、canvasBlankMenuSelectAll、studioNewProject、studioCreateSampleProject、studioImportProject、exportVideoLabel、studioOpenSettings、commandBackToStudio。

## 测试
先写 2、3（command_actions_test 引用 `kAppActions` 会编译失败 = 红）。
- `test/features/app_actions/app_action_catalog_test.dart`（新）：
  1. 「id 唯一，且每个 ★ id 都有一行」：`kAppActions.map(id)` 无重复；`{undo, redo, cut, copy, paste, find, importMedia, newNote, wrapInLane, focusNotifications}` 全在表里。
  2. 「禁用必有原因」（testWidgets，Consumer 取 context/ref；四个上下文：Studio、画布无选中、画布选中一张 image 配置、设置浮层）：对每行 `isAvailable` 为真者，`isEnabled == false ⇔ disabledReason != null`。
  3. 「★ 行灰着、原因即将推出、不进 ⌘K」：`isEnabled` 假、原因 == `l.appActionReasonComingSoon`、`inPalette == null`。
  4. 「键位取自注册表，不另抄」：selectAll / duplicate / generate / fitAll / zoomReset / toggleLeftRail 的 `macKey`、`otherKey` 分别 `identical` 于 `canvasBindingActivator('<id>', isMac: true/false)`；commandPalette 的键 `identical` 于 `kCommandPaletteActivators`。
  5. 「重做：Windows Ctrl+Y，macOS ⇧⌘Z」：`redo.keyLabel(isMac: false) == 'Ctrl+Y'`；`redo.macKey` 为 meta+shift+Z。
  6. 「node 组跟选中走」：画布选中一张 image 配置 → generate 启用、saveAsCharacter 禁用且原因 == SelectOneImage；清空选中 → generate 原因 == SelectOneConfig。
- `test/features/command_palette/command_actions_test.dart`（新，testWidgets + Consumer）：
  7. 「⌘K 动作全部来自表」：各上下文 `buildCommandActions` 的每个 id 都 `appActionById != null`。
  8. 「集合与顺序与改前一致」：Studio → `[importProject, openSampleProject, openSettings]`；画布无可导出视频 → `[addImageNode, addVideoNode, addShotNode, backToStudio, openSettings]`；画布有视频 + 有项目 → 在 addShotNode 后多 `exportVideo`；画廊有项目 → `[backToStudio, openSettings]`；**画布标签上**开设置浮层（canvasId 保留）→ `[backToStudio]`。断言写法：先把结果按测试里写死的 `kLegacyPaletteIds`（改前 ⌘K 全部 id）过滤，再与上面的序列比——这样 W2 undo-shortcuts-ui、W3 import-media-command / help-actions 往 ⌘K 加行时不必改本测试（否则 W3 两片会同改这个文件）；另加一条「结果里没有任何 comingSoon 占位行的 id」。（主 Agent 跨批核对补充）
- `test/features/canvas/widgets/canvas_toolbar_test.dart` 追加 9.「更多 = kMoreMenuActionIds 逐项」：打开更多 → PopupMenuItem 个数 == `kMoreMenuActionIds.length`，文字依次为对应 `label`。现有第 311–315 行「Import script…」用例不改。
- 现有 `command_palette_test.dart`、`command_palette_focus_test.dart` 一行不改、全绿（特别是「键盘 ↓ + Enter 执行第二项」与「搜索 image」）。

## 变异点
1. app_action_catalog.dart：exportVideo 的 `isEnabled` 改成恒真 → 用例 8「画布无可导出视频」红（多出 exportVideo）。
2. command_actions.dart：在过滤结果后追加一个写死的 `CommandAction(id: 'x', …)` → 用例 7 红。
3. app_action_catalog.dart：selectAll 的 `macKey` 改取 `canvasBindingActivator('canvasDuplicate', …)` → 用例 4 红。
4. planned_keys.dart：`redoOther` 改成 Ctrl+Shift+Z → 用例 5 红。
5. app_action_catalog.dart：`comingSoon` 的 `disabledReason` 返回 null → 用例 2、3 红。
6. app_action_catalog.dart：generate 的判据改成「选中非空」→ 用例 6 红。
7. more_menu_model.dart：把 `AppActionIds.importScript` 换成 `AppActionIds.undo` → canvas_toolbar_test 第 311 行「Import script…」用例红。
8. app_action.dart：`canvasId` getter 去掉 `overlay == null` 条件 → 用例 8「设置浮层」红。

## 验收
- （主 Agent 自查补充）exportVideo 的 run 只调 `openExportVideoDialogForCanvas(context, ref, canvasId)`：`grep -rn "_openExport\|showExportVideoDialog" lib/features/app_actions lib/features/command_palette` 应无结果。现在 `_openExport` 与它行为相同（都按链序），所以没有单测能区分；区别在 current-take 合入后——固定的 take 只经 openExportVideoDialogForCanvas 传入，W1 两片都合入后由主 Agent 补一条集成用例「⌘K 导出默认勾固定的 take」。
- `flutter analyze lib test`；`flutter test test/features/app_actions test/features/command_palette test/features/canvas/widgets/canvas_toolbar_test.dart --exclude-tags golden`；逐条跑 8 个变异。
- 截图（test/_harness/screenshot.dart）：① CanvasScreen 打开工具条「更多」：一项「导入脚本…」；② 同一屏临时把 `kMoreMenuActionIds` 加上 `importMedia`（只为截图，不提交）→ 第二项灰着、悬停出「即将推出」；③ ⌘K 在画布标签与 Studio 标签各一张，与改前截图逐行一致。

## 风险与不确定
- 本片落地时 canvas-capsule 正在改 core_canvas_keys.dart 与 canvas_tool_actions.dart：只按函数名调用，不 import 它们的私有部分；rebase 冲突应为零。
- ⌘K 的禁用项不显示（设计缺口 ①）：若主 Agent 要「灰着带原因」也进 ⌘K，需等 W2 以后有切片能改 palette_search.dart / PaletteEntry。
- `command_palette_dialog.dart` → palette_search → command_actions → catalog → `showCommandPalette` 会形成 import 环（Dart 允许）；若 analyze 有规则拦，就把 commandPalette 行的 run 改成发 `ActivateIntent` 给 CommandPaletteShortcuts，回报里说明。
- `deleteNodesWithUndo` 在 W1 被 nodes-batch-ops 改成批量路径，签名不变；本片只调用。
