# import-media-command · Ctrl/⌘ U 与「导入媒体…」：多选文件，视口中心散布落点，一张通知带撤销并点名跳过的文件
- 波次 W3 / lane D / 基底 origin/main（届时已含 media-import-service、app-action-table、esc-ladder、menu-split、undo-stack、nodes-batch-ops、multi-select-core、undo-shortcuts-ui）；依赖切片：media-import-service（服务 / 控制器 / picker seam）、app-action-table（动作表与 importMedia 占位行）、esc-ladder（快捷键注册表）、menu-split（菜单注册表）、undo-stack（进栈）；阻塞决定：无。并掉 cm-blank-menu-additions 里「导入媒体…」一项（粘贴、网格吸附两项不归本片）。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/import-media-command`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
- 画布上按 Ctrl U（mac ⌘U）、空白处右键「导入媒体…」、工具条「更多 › 导入媒体…」、⌘K「导入媒体…」都打开系统文件选择框，可多选图片 / 视频。
- 选好后文件出现在视口中心（右键入口在右键点），排成一小片网格，每张先显示「复制中」再变成图；一张通知「已导入 2 个文件 · 跳过 1 个：notes.pdf 不是图片或视频 · [撤销]」。
- 撤销一次撤掉整批导入（卡上撤销 = 只撤这一步；之后 Ctrl Z 也能撤）。

## 设计依据
- ImportSearch.dc.html ›「导入媒体」：「Ctrl/⌘ U 或右键「导入媒体…」：可多选；图片 png / jpg / webp，视频 mp4 / mov / webm」；「落点：快捷键在视口中心散布……一次一张通知带撤销，不支持的点名跳过」；样稿卡「已导入 2 个文件 / 跳过 1 个：notes.pdf 不是图片或视频 / 撤销」。
- ImportSearch ›「工具锁 · 便签」：「新键 Ctrl U……都不撞现有键；单键只在画布持焦且不在文字里时生效」。KeyMap.dc.html 表：Ctrl U / ⌘U · 导入媒体 · 范围「画布」（画布持焦、不在文字里）。
- ContextMenus.dc.html ›「空白处 · 补三项」：顺序 新建… Tab | 粘贴 Ctrl V | **导入媒体… Ctrl U** | 导入剧本… | 全选 | 适应视图 | 网格吸附；「导入媒体 / 粘贴的图：复制进 canvases/<id>/imports/，建无来源的产物节点」。
- GapsCanvas.dc.html ›「「更多」下拉」：顺序 导入剧本… · 导入媒体… Ctrl U | …；「每项也进 ⌘K 动作表和菜单栏」。ShellExport ›「文件」菜单有「导入媒体… Ctrl U」（菜单栏归 win-menubar，本片只把动作登记成 file 组）。
- UndoClipboard.dc.html ›「什么进栈」：「粘贴 / 剪切 / 复制一份 / 导入剧本 / 导入媒体」各算一步；›「和撤销卡的关系」：卡是提醒、栈才是本体；需要你定按建议：UC-Q1 → A（卡上点哪步撤哪步，undoSpecific）。
- plan.md §3 W3：跳过的文件在卡片里点名。
- 设计缺口：①右键「导入媒体…」落在哪画板没写——本片定：落在右键按下点（与同菜单的「新建…」「粘贴」一致），其余三个入口落在视口中心 + 散布；②多文件「散布」的排法没画——本片定：按文件名排序后排成最多 4 列的网格，间距 InkSpacing.lg，整片以落点为中心，整片再加一次现有散布（防连按叠在一起）；③导入后选中谁没写——本片定：新节点成为选中，相机不动；④文件选择框打不开（权限）时的提示没画——见新文案键。

## 允许改的文件
- `lib/features/canvas/widgets/shortcuts/import_media_keys.dart`（新）：`ImportMediaIntent`、`List<CanvasKeyBinding> importMediaKeys`；activator 直接引用 app-action-table 新建的 `PlannedKeys` 里 importMedia 那一对（⌘U / Ctrl U，已带 includeRepeats: false），不另抄常量。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（由 esc-ladder 新建）：追加一行 `...importMediaKeys,`。
- `lib/features/canvas/util/canvas_import_actions.dart`（新）：入口函数、网格落点纯函数、跳过说明纯函数、重入守卫 provider。
- `lib/features/canvas/widgets/canvas_menu/import_media_menu_items.dart`（新）：`List<CanvasMenuItemDef> importMediaBlankMenuItems`。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（由 menu-split 新建）：追加一行 `...importMediaBlankMenuItems,`。
- `lib/features/app_actions/app_action_catalog.dart`（由 app-action-table 新建）：把 `comingSoon(AppActionIds.importMedia, ...)` 占位行换成真实一行。
- `lib/features/canvas/util/more_menu_model.dart`（由 app-action-table 新建）：`kMoreMenuActionIds` 追加 `AppActionIds.importMedia`（紧跟 importScript）。
- `lib/features/canvas/models/commands/import_media_command.dart`（新）：`ImportMediaCommand extends CanvasCommand`。
- 测试（新）：`test/features/canvas/util/canvas_import_actions_test.dart`、`test/features/canvas/widgets/canvas_import_media_test.dart`、`test/features/canvas/models/commands/import_media_command_test.dart`。

## 不许碰的文件
- undo-adopt-existing：`util/canvas_node_delete.dart`、`util/canvas_snackbars.dart`（只调用不改）、`stage/stage_edge_layer.dart`、`stage/node_card_slot.dart`、`node_inputs_section.dart`、它新建的 `models/commands/*`（本片命令文件名 `import_media_command.dart` 不与之重名）。
- marquee-select：`stage/stage_pointer_layer.dart`、`canvas_view.dart` 骨架、`marquee_layer.dart`、`providers/canvas_marquee.dart`、`providers/canvas_tool_mode.dart`。
- tc-set-current：`node_card.dart`、`inspector_history_panel.dart`、`image_result_inspector.dart`、`video_result_inspector.dart`、`result_inspector_parts.dart`、`job_notification_listener.dart`、`export_video_dialog.dart`、`providers/current_take_controller.dart`、`canvas_menu/set_current_menu_items.dart`。
- help-actions：`left_rail/canvas_left_rail.dart`、`left_rail/help_menu_popover.dart`、`app_actions/help_actions.dart`、`settings/widgets/diagnostics_section.dart`、`startup/widgets/startup_error_view.dart`、`services/github_update_check_service.dart`、`settings/providers/update_check_controller.dart`、`settings/providers/settings_page.dart`。
- 另外不碰：`canvas_tool_actions.dart`、`canvas_toolbar.dart`（「更多」只走 more_menu_model 一行）、`canvas_shortcuts.dart`、`shortcuts/core_canvas_keys.dart`、`settings/util/shortcut_catalog.dart`（从注册表自动收录）、`command_palette/command_actions.dart`（从动作表自动收录）、`media_import_controller.dart` / `core/di/media_import.dart`（只调用）。
- （主 Agent 自查补充）help-actions：`lib/core/constants/app_repo.dart`（新）、`lib/theme/components/ink_menu_panel.dart`（只加可选 `tooltip`）、`lib/theme/primitives/ink_activatable.dart`（只加可选 `focusNode`）、`lib/features/settings/widgets/diagnostics_section.dart`、`lib/features/startup/widgets/startup_error_view.dart`、`lib/services/github_update_check_service.dart`。

## 具体改动
```dart
// shortcuts/import_media_keys.dart
// activator 取 PlannedKeys.importMediaMac / PlannedKeys.importMediaOther（由 app-action-table 新建；实际字段名以合入版为准）
class ImportMediaIntent extends Intent { const ImportMediaIntent(); }
final List<CanvasKeyBinding> importMediaKeys = <CanvasKeyBinding>[
  CanvasKeyBinding(id: 'canvas.importMedia', activators: [PlannedKeys.importMediaMac, PlannedKeys.importMediaOther], intent: ImportMediaIntent(),
    gate: CanvasKeyGate.notEditingText, group: ShortcutGroup.edit, label: (l) => l.appActionImportMedia, onInvoke: (c, _) => importMediaViaPicker(c.context, c.ref, canvasId: c.canvasId)),
];

// util/canvas_import_actions.dart
Future<void> importMediaViaPicker(BuildContext context, WidgetRef ref, {required String canvasId, Offset? anchorViewport}); // null ⇒ 视口中心 + 散布
List<Offset> importGridOrigins({required Offset center, required List<Size> sizes, int maxColumns = 4, double gap = InkSpacing.lg}); // 纯：左上角世界坐标，整片以 center 为中心
List<String> sortForImport(List<String> paths);            // 按 basename 不分大小写排序（mac / Windows 结果一致）
String? mediaImportSkipBody(AppLocalizations l, List<MediaImportSkip> skipped); // 空 ⇒ null；按 unsupported / unreadable / copyFailed 分行，每行最多点 3 个名字，其余「等 N 个」
final importMediaPickerOpenProvider = StateProvider.autoDispose.family<bool, String>(...); // 重入守卫

// canvas_menu/import_media_menu_items.dart
final List<CanvasMenuItemDef> importMediaBlankMenuItems = <CanvasMenuItemDef>[
  CanvasMenuItemDef(id: 'blank.importMedia', scope: CanvasMenuScope.blank, group: 10, order: 15, // menu-split 表：blank.create g10/o10、blank.importScript g10/o20 ⇒ 插在两者之间
    build: (c) => InkMenuEntry(...label: l.appActionImportMedia, 键位提示取 PlannedKeys 按平台...), run: (c) => importMediaViaPicker(c.context, c.ref, canvasId: c.canvasId, anchorViewport: c.request 的锚点)),
];

// app_action_catalog.dart 替换占位行
AppAction(id: AppActionIds.importMedia, group: AppActionGroup.file, label: (l) => l.appActionImportMedia, icon: Icons.file_upload_outlined,
  macKey: PlannedKeys.importMediaMac, otherKey: PlannedKeys.importMediaOther,
  isAvailable: (_) => true, isEnabled: (c) => c.canvasId != null,   // AppActionContext.canvasId 已含「画布标签且无浮层」判据
  disabledReason: (c, l) => c.canvasId == null ? l.importMediaNeedsCanvas : null,
  inPalette: (_) => true,
  run: (c) => importMediaViaPicker(c.context, c.ref, canvasId: c.canvasId!));

// models/commands/import_media_command.dart
class ImportMediaCommand extends CanvasCommand {
  ImportMediaCommand({required this.nodeIds});
  final List<String> nodeIds;
  String label(AppLocalizations l) => l.canvasHistoryImportMedia(nodeIds.length);
  Set<String> get affectedNodeIds;
  Future<CanvasCommandOutcome> revert(CanvasCommandEnv env); // removeNodes(仍在画布上的 nodeIds) 记下 NodeDeletion；一个都不在 ⇒ gone
  Future<CanvasCommandOutcome> apply(CanvasCommandEnv env);  // restoreAll(记下的 deletions)；没有 ⇒ gone
}
```
- `importMediaViaPicker` 流程：守卫已开 ⇒ return；置守卫 → `ref.read(mediaFilesPickerProvider)()`（`PlatformException` ⇒ 错误卡 `mediaImportPickerFailed`）→ 关守卫 → 空列表 ⇒ return（无卡、无步）→ `sortForImport` → `mediaImportKindOf` 分出可导入的 → `importGridOrigins` → 每点过一遍相机得视口点 → `menuNodePlacement` 判泳道 → 弹进度卡 `toastService.show(l.mediaImportProgress(n), kind: progress)` → `mediaImportControllerProvider(canvasId).notifier.importFiles(projectId: ShellState.project.id, requests)`（不支持的也照传，由控制器统一记 skipped）→ 结果：有节点 ⇒ `canvasSelectionControllerProvider.replace(nodeIds)`、`stepId = history.record(ImportMediaCommand(nodeIds))`、`handle.complete(kind: undo, title: l.mediaImportDone(k), body: mediaImportSkipBody(...), primary: ToastAction(l.commonUndo, () => runCanvasUndoStep(ref.read, canvasId:, stepId:, l:, isMac:)))——`runCanvasUndoStep` 由 undo-shortcuts-ui 新建在 util/canvas_history_actions.dart，内部走 undoSpecific 并统一出胶囊 / 失败卡`、`history.bindCard(stepId, handle)`；一个节点都没有 ⇒ `handle.complete(kind: warning, title: l.mediaImportNothing, body: ...)`，不进栈。
- projectId 取 `shellControllerProvider` 的 `ShellState.project`；为 null（理论上画布标签不会）⇒ 不打开 picker。

## 行为规则与边界情况
1. Ctrl U 与 ⌘U 两个变体都注册（两个平台都认，与现有 Ctrl/⌘ 键同口径）；`includeRepeats: false`，按住只开一次。
2. 焦点在任何文本框（提示词条、检查器）里按 Ctrl U ⇒ 画布不接管、不开 picker。
3. 文件选择框打开期间再按 Ctrl U / 再点菜单 ⇒ 不开第二个（守卫）；关闭后守卫复位（含取消与异常）。
4. 取消选择框 ⇒ 什么都不发生：无卡、无节点、撤销栈不变。
5. 选择框打不开（PlatformException，如 macOS 沙箱缺权限）⇒ 错误卡「打不开文件选择框」，无步。
6. 选了 3 个：2 张图 + notes.pdf ⇒ 建 2 个节点；卡标题「已导入 2 个文件」、正文「notes.pdf 不是图片或视频」；撤销栈 +1 步「导入 2 个文件」。
7. 扩展名大小写：`A.JPG`、`b.MoV` 照常导入（mac / Windows 一致）；picker 过滤器只列媒体扩展名，但服务端仍按扩展名再判一次。
8. 落点：Ctrl U / 更多 / ⌘K 以视口中心为片中心（加一次散布）；右键入口以右键按下点为片中心；网格按文件名不分大小写排序、最多 4 列、间距 lg；每张按自己的落点判泳道（落在道里的写 laneId）。
9. 导入完成后新节点成为选中（替换原选中）；相机不动。
10. 全部被跳过 / 全部复制失败 ⇒ 卡改为 warning「没有导入任何文件」+ 点名，无撤销按钮、不进栈。
11. 部分失败：失败的点名「x.mov 没能复制」「y.png 读不出来」，成功的照常进栈。
12. 点名超过 3 个 ⇒ 「a.pdf、b.pdf、c.pdf 等 5 个 不是图片或视频」（分隔符走 ARB）。
13. 撤销：卡上「撤销」= `undoSpecific(stepId)`，只撤这一批（之后又做了别的也只撤这一步）；卡收起后 Ctrl Z 走栈顶照常可撤；重做恢复同一批节点（含导入后用户连上的边）；文件不删（回收器只读、软删节点仍引用）。
14. 撤销时这批节点已被用户全删 ⇒ outcome gone，由统一反馈显示「这一步已无法撤销」；部分已删 ⇒ 撤剩下的。
15. 复制进行中：卡是进度卡、没有撤销按钮，命令尚未进栈；此时 Ctrl Z 撤的是之前那一步。两批同时导入各自一张卡、各自一步。
16. 关画布：undo-stack 丢栈并 dismiss 绑定的卡；复制仍在后台完成（控制器非 autoDispose），但不再进栈、卡已收。
17. ⌘K：「导入媒体…」只在画布标签出现（app-action-table 的规则：⌘K 只列 isAvailable && isEnabled 的项）；其它标签不出现。菜单栏（W4 win-menubar）在没有画布时显示灰项并给原因「先打开一个画布」。「更多」里紧跟「导入剧本…」，带 Ctrl U / ⌘U 键位；设置页快捷键清单自动出现这一行（从注册表取）。
18. mac / Windows：键位提示 mac 显示 ⌘U、Windows 显示 Ctrl U（动作表 macKey / otherKey）；文件名排序不分大小写，保证两平台网格顺序一致；路径分隔符只影响 basename 取名，由 media-import-service 的 `importOriginalName` 处理。

## 新文案键
| key | en | zh |
|---|---|---|
| importMediaNeedsCanvas | Open a canvas first | 先打开一个画布 |
| mediaImportProgress | `{count, plural, =1{Importing 1 file…} other{Importing {count} files…}}` | `正在导入 {count} 个文件…` |
| mediaImportDone | `{count, plural, =1{Imported 1 file} other{Imported {count} files}}` | `已导入 {count} 个文件` |
| mediaImportNothing | Nothing was imported | 没有导入任何文件 |
| mediaImportSkippedHeader | `Skipped {count}:` | `跳过 {count} 个：` |
| mediaImportReasonUnsupported | `{names}: not an image or video` | `{names} 不是图片或视频` |
| mediaImportReasonUnreadable | `{names}: couldn't be read` | `{names} 读不出来` |
| mediaImportReasonCopyFailed | `{names}: couldn't be copied` | `{names} 没能复制` |
| mediaImportMoreNames | `{names} and {count} more` | `{names} 等 {count} 个` |
| mediaImportNameSeparator | `, ` | `、` |
| mediaImportPickerFailed | Couldn't open the file picker | 打不开文件选择框 |
| canvasHistoryImportMedia | `{count, plural, =1{Import 1 file} other{Import {count} files}}` | `导入 {count} 个文件` |

placeholders：count int、names String。动作名复用 app-action-table 已登记的 `appActionImportMedia`（Import media… / 导入媒体…），不新增。若 app-action-table 已有通用「需要先打开画布」原因键，主 Agent 合并时用那一个替掉 `importMediaNeedsCanvas`。

## 测试
- `test/features/canvas/util/canvas_import_actions_test.dart`（纯）
  - 「importGridOrigins：1 张以 center 为中心」；「5 张 ⇒ 4 + 1 两行、间距 lg、整片包围盒中心 == center」。
  - 「sortForImport：['b.png','A.jpg','a.mp4'] ⇒ A.jpg、a.mp4、b.png 的稳定顺序（不分大小写）」。
  - 「mediaImportSkipBody：空 ⇒ null；三类按固定顺序分行；5 个 pdf ⇒ 前 3 个 + 等 2 个」（en / zh 各一遍，`lookupAppLocalizations`）。
- `test/features/canvas/models/commands/import_media_command_test.dart`
  - 「revert 软删全部、apply 复原」；「节点已全删 ⇒ revert gone」；「label：Import 2 files」。
- `test/features/canvas/widgets/canvas_import_media_test.dart`（pumpInkShell 画布标签；override `mediaFilesPickerProvider`、`mediaImportServiceProvider`（假服务，立即成功 / 按名失败）、`toastServiceProvider`=RecordingToastService）
  1. 「Ctrl U ⇒ picker 调 1 次，2 张图建成节点并被选中」。
  2. 「⌘U 同样生效」。
  3. 「卡：进度 → Imported 2 files，正文 notes.pdf: not an image or video，主按钮 Undo」。
  4. 「撤销栈 +1，nextUndo.label == Import 2 files」。
  5. 「picker 返回空 ⇒ 无卡、无节点、栈不变」。
  6. 「焦点在提示词条 TextField ⇒ Ctrl U 不调 picker」。
  7. 「picker 未返回时再按 Ctrl U ⇒ picker 仍只调 1 次」。
  8. 「picker 抛 PlatformException ⇒ 错误卡 Couldn't open the file picker，守卫复位（再按能打开）」。
  9. 「全是 pdf ⇒ warning 卡 Nothing was imported，无 Undo，栈不变」。
  10. 「导入后再 record 一个假命令，点卡上 Undo ⇒ 导入的节点没了、假命令那步仍在栈里」（undoSpecific）。
  11. 「空白处右键菜单有『Import media…』，排在『Import script…』之前，带键位；点它 ⇒ 片中心 == 右键点」。
  12. 「更多菜单：Import script… 之后是 Import media…」。
  13. 「⌘K 搜 import media ⇒ 画布标签下出现并能运行；画廊标签下不出现」；「动作表：无画布时 isEnabled false、disabledReason == Open a canvas first」。
  14. 「设置页快捷键清单含 Import media…」。
  15. 「长按 U 不重复开（includeRepeats false）」。

## 变异点
1. `sortForImport` 去掉不分大小写 →「sortForImport」红。
2. `importGridOrigins` 不减半宽（片不居中）→「整片包围盒中心 == center」红；右键入口忽略锚点 → 用例 11 红。
3. `mediaImportSkipBody` 只写数量不写名字 → 纯函数用例与用例 3 红。
4. 绑定改用手写的 `SingleActivator(keyU, control: true)`（无 includeRepeats: false）→ 用例 15 与 esc-ladder 的注册表守卫测试红。
5. gate 改 `always` → 用例 6 红。
6. 去掉重入守卫 → 用例 7 红；异常时不复位守卫 → 用例 8「再按能打开」红。
7. picker 空列表仍弹卡 → 用例 5 红。
8. 不 `history.record` → 用例 4、10 红。
9. 卡上 Undo 调 `runCanvasUndo`（栈顶）而不是 `runCanvasUndoStep(stepId)` → 用例 10 红（撤掉的是假命令那步）。
10. 全部跳过仍进栈 / 仍给 Undo → 用例 9 红。
11. app_action_catalog 留着 comingSoon 占位 → 用例 13 红。
12. more_menu_model 不加这一行 → 用例 12 红。
13. 导入后不 `replace` 选中 → 用例 1 红。
14. `ImportMediaCommand.revert` 在节点已全删时返回 done → 命令测试「gone」红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas test/features/command_palette test/features/settings`；esc-ladder 的注册表守卫测试、menu-split 的菜单测试不改仍绿；逐条变异。
- 截图（en / zh 各一）：用 `CanvasScreen` + 假 picker（雾江.jpg、船桨.mp4、notes.pdf）+ 慢速假服务——①复制中（一张 48%）与进度卡；②完成后两张卡被选中、通知卡「已导入 2 个文件 · notes.pdf 不是图片或视频 · 撤销」；③空白处右键菜单含「导入媒体… Ctrl U」；④「更多」下拉两项顺序。

## 风险与不确定
- 偏离 contract：命令文件名用 `import_media_command.dart`（contract 未规定具体名）；键位常量用 app-action-table 的 `PlannedKeys`（不在 import_media_keys.dart 另抄）；`importMediaPickerOpenProvider` 放在 util 文件里（只本片用，不另建 providers 文件）。picker seam `mediaFilesPickerProvider` 由 media-import-service 放在 `core/di/media_import.dart`，本片只读。
- 依赖多个前序切片的落地签名：`CanvasMenuItemDef` 的 group / order 数值、`CanvasMenuContext.request` 的锚点字段、`AppActionContext.shell`、`runCanvasUndoStep` 的签名、nodes-batch-ops 的 `removeNodes` / `restoreAll`、multi-select-core 的 `replace`。若与本单不符按实际改，回报列出。
- `ImportMediaCommand` 需要在 revert / apply 之间记住 `NodeDeletion`，命令对象内部持有可变字段——与 contract「只持快照」的精神有出入，执行代理在文件头注释写明原因。
- 一次选上百个文件没有上限：网格会很大、卡片正文点名被截断；画板未定上限，先不加。
