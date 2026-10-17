# clipboard-paste · Ctrl C / X / V 复制·剪切·粘贴节点（同画布 / 同项目别的画布 / 别的项目）+ 右键「粘贴」「剪切」「复制」，粘贴一步撤销
- 波次 W7 / lane C 第二片 / 基底：叠在 canvas-clipboard-core 之后（origin/main〔W0–W6 已合入〕+ canvas-clipboard-core）；依赖切片：canvas-clipboard-core、nodes-batch-ops（W1）、undo-stack（W0）、undo-shortcuts-ui（W2）、undo-adopt-existing（W3）、canvas-capsule（W1）、media-import-service（W2）、multi-select-core（W0）、esc-ladder（W0，快捷键注册表）、menu-split（W0）；阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 选中节点按 Ctrl C（mac ⌘C）复制、Ctrl X 剪切，在同一画布、同项目别的画布、别的项目的画布里按 Ctrl V 粘贴；节点连同彼此之间的线一起出来，粘出的节点成为选中。
- 空白处右键多一项「粘贴 Ctrl V」（剪贴板空时置灰）；节点右键多「剪切 Ctrl X」「复制 Ctrl C」。
- 粘贴算一步撤销；剪切 = 复制 + 删除，删除那一步照现有删除卡可撤。跨画布 / 跨项目的图和视频先复制进目标画布 `imports/`，失败零残留。

## 设计依据
- UndoClipboard.dc.html ·「复制 / 粘贴节点」：Ctrl C · Ctrl X · Ctrl V；Ctrl X = 复制 + 删除；粘贴出的节点成为选中；两者各算一步。
- 同板「粘贴到哪 · 带什么」：落点四种（已在 canvas-clipboard-core 的 layoutPaste）；媒体 同画布引用同一个文件、别的画布 / 别的项目复制一份；「先复制文件再写库，失败删掉复制件、零残留」；角色 别的项目「挂载和 @ 记号都去掉，胶囊提示」。
- 同板「撤销 / 重做」进栈清单：「粘贴 / 剪切 / 复制一份 / 导入剧本 / 导入媒体 → 粘贴 4 个节点」；「和撤销卡的关系」：剪切进栈之外再弹卡，卡上「撤销」撤卡上这一步。
- 同板「系统剪贴板」：复制节点时往系统剪贴板写一份纯文字（标签 + 提示词）；Ctrl D 不变（只复制配置节点、不碰剪贴板）。从别的软件贴文字 / 图片不归本片（W8 clipboard-text-paste、W9 os-drop-paste-image）。
- GapsCanvas 画布轻提示胶囊 mock：「已复制 2 个节点」。
- ContextMenus.dc.html · 空白处补项：「新建… Tab」下面是「粘贴 Ctrl V」；「节点菜单同批补剪切 / 复制」。
- 设计缺口：①节点菜单里剪切 / 复制放哪一组——板没画，本片放在「复制一份」所在组、排在它前面（剪切 · 复制 · 复制一份）；②粘贴成功要不要胶囊——板没写，本片只在跨项目去掉了角色时出胶囊，平时不出（粘出的节点已选中）；③剪切的删除卡文案——本片写「已剪切 N 个节点」；④粘贴时源文件已从磁盘消失（源画布被彻底清掉）——本片按复制失败处理。

## 允许改的文件
- `lib/features/canvas/widgets/shortcuts/clipboard_keys.dart`（新）：三个 Intent + `clipboardKeys` 三条 `CanvasKeyBinding`（激活器引用 W1 `PlannedKeys.cut/copy/paste` 的 Mac / Other，不另抄；对文本编辑让位走 `CanvasKeyGate.notEditingText`）（主 Agent 跨批核对补充）。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（由 esc-ladder 新建）：**追加一行**登记 clipboard_keys（快捷键页从注册表取文案，不改 shortcut_catalog.dart）。
- 新 `lib/features/canvas/widgets/canvas_menu/clipboard_menu_items.dart`：`final List<CanvasMenuItemDef> clipboardMenuItems`（照 W2 undo-shortcuts-ui 的 `undo_menu_items.dart` 写法，条目自带 build / run，宿主不用加 case）：
  - `blank.paste`：scope blank，**group 30**（menu-split 在 menu_registry.dart 头注约定「空白处 30 粘贴」，紧跟 10「新建 · 导入」组），order 10；剪贴板空时 `enabled: false`；keyHint 取本平台的 `canvasBindingLabel('canvasPaste', isMac:)`。
  - `node.cut` / `node.copy`：scope node，**group 10**（「做」组），order 14 / 16（排在 `node.generate` 10 之后、`node.duplicate` 20 之前 ⇒「剪切 · 复制 · 复制一份」）；作用于 `c.targets`（整个选中集）。
  - 不改 blank_menu_entries.dart / node_menu_entries.dart，不加 BlankMenuAction / NodeMenuAction 枚举值。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`：**追加一行** `...clipboardMenuItems,`。
- `lib/features/app_actions/app_action_catalog.dart`（注册表）：把 W1 的三条 ★ 占位行 `comingSoon(AppActionIds.cut / copy / paste, …)` 换成一行 `...clipboardAppActions,`（定义在 `canvas_paste_actions.dart`，group edit，`macKey` / `otherKey` 取 `PlannedKeys.cutMac` / `cutOther` 等，`isEnabled` = 画布标签且有选中 / 剪贴板非空；替换自己的占位行算一行）。这样 W4 菜单栏「编辑」与 ⌘K 里的剪切 / 复制 / 粘贴随之可用。
- `lib/features/canvas/util/canvas_paste_actions.dart`（新）：`copySelection` / `cutSelection` / `pasteClipboard`。
- `lib/features/canvas/providers/canvas_nodes_controller.dart`：新增 `pasteSnapshot`。
- `lib/features/canvas/util/canvas_node_delete.dart`：`deleteNodesWithUndo` 加可选参数 `String Function(AppLocalizations l, int count)? message`（剪切传「已剪切 N 个节点」），默认行为不变。
- `lib/features/canvas/providers/canvas_pointer.dart`（新）：`canvasPointerProvider`（family(canvasId) autoDispose，持一个可变的 `CanvasPointerTracker { Offset? viewportPoint; }`，写入不通知，只在按键时 read）。
- `lib/features/canvas/widgets/canvas_view.dart`：只加一处——`_CanvasBody` 的 `leftArea`（main 第 401 行起的 Stack）外包 `MouseRegion(opaque: false, onHover: 记点, onExit: 清空)`，坐标系 = 舞台视口（与菜单锚点同一个）。（主 Agent 自查确认：W7 没有别的切片改 canvas_view.dart，本波归本片，只许这一处。）
- `lib/features/canvas/models/commands/paste_nodes_command.dart`（新，独立文件，不是 part；不改 canvas_command.dart）。
- 测试：`test/features/canvas/util/canvas_paste_actions_test.dart`（新）、`test/features/canvas/canvas_nodes_controller_test.dart`（追加 group）、`test/storage/transaction_integration_test.dart`（追加一条）、`test/features/canvas/widgets/canvas_clipboard_shortcuts_test.dart`（新）。

## 不许碰的文件
- `node_card.dart`、`util/take_staleness.dart`、`providers/stale_takes_provider.dart`、`widgets/stale_reason_popover.dart`、`outline_panel.dart`、`outline_model.dart`（W7 tc-stale-marks）。
- `widgets/stage/node_card_slot.dart`、`node_drag_delta.dart`、`edge_painter.dart`、`widgets/stage/stage_edge_layer.dart`、`widgets/stage/stage_overlays.dart`、`util/narrative_drop_insert.dart`、`util/canvas_narrative_drop_actions.dart`、`models/commands/narrative_drop_insert_command.dart`（W7 cm-drag-insert-narrative）。
- `lane_title_bar.dart`、`widgets/stage/stage_lane_layer.dart`、`canvas_menu/canvas_menu_host.dart`、`canvas_menu/canvas_menu_request.dart`、`lane_menu_entries.dart`、`util/lane_menu_model.dart`、`providers/lane_rename_controller.dart`、`lane_collapse_controller.dart`、`util/canvas_lane_actions.dart`（W7 cm-lane-menu）。
- `canvas_menu/blank_menu_entries.dart`、`canvas_menu/node_menu_entries.dart`（菜单项走新文件 + 注册表一行）。
- `shell/*`、`theme/components/ink_menu_bar.dart`、`app.dart`、`main.dart`（W7 菜单栏 lane）。
- `canvas_shortcuts.dart`（核心键文件，不在本片）、`shortcut_catalog.dart`、`canvas_tool_actions.dart`（Ctrl D 不变）、`core/di/services.dart`（不存在，也不新建 copier：媒体复制只用 media-import-service）。
- W7 lane E 的 shell 菜单栏文件：`lib/features/shell/**`（含 ink_shell.dart、shell_menu_bar.dart）、`lib/theme/components/ink_menu_bar.dart`、`lib/app.dart`、`lib/main.dart`、`windows/runner/flutter_window.cpp`。

## 具体改动
```dart
// shortcuts/clipboard_keys.dart
class CanvasCopyIntent extends Intent { const CanvasCopyIntent(); }
class CanvasCutIntent extends Intent { const CanvasCutIntent(); }
class CanvasPasteIntent extends Intent { const CanvasPasteIntent(); }
// 激活器**不另抄**：W1 app-action-table 的 `PlannedKeys`（lib/features/app_actions/planned_keys.dart）是第二批键位常量的唯一出处，
// 已有 cutMac / cutOther / copyMac / copyOther / pasteMac / pasteOther（全部 includeRepeats: false）；W3 import-media-command 同做法。
final List<CanvasKeyBinding> clipboardKeys; // 三条：id 'canvasCopy' / 'canvasCut' / 'canvasPaste'，activators [PlannedKeys.xxxMac, PlannedKeys.xxxOther]，
                                            // gate: CanvasKeyGate.notEditingText，group: ShortcutGroup.edit，label: l.settingsShortcutCanvasCopy / Cut / Paste

// providers/canvas_nodes_controller.dart
/// 粘贴：一个 UoW 内按草稿顺序建节点（sourceNodeId 用已建的新 id）→ 对需要的节点 patchTypeConfig（`secondPassPatch(d, idMap, scope: draft.scope)`——canvas-clipboard-core 让 PasteDraft 带上 scope，pasteSnapshot 签名不变）→ 建边。
/// 成功后一次性把新节点并进 state，并让 canvasEdgesControllerProvider(canvasId) 失效；任一步失败整体回滚、state 不动、rethrow。
Future<List<String>> pasteSnapshot(PasteDraft draft, Map<String, NodePlacement> placements); // NodePlacement = drop_placement.dart 的 ({Offset world, String? laneId})

// util/canvas_paste_actions.dart
Future<void> copySelection(BuildContext context, WidgetRef ref, {required String canvasId, Set<String>? nodeIds});
Future<void> cutSelection(BuildContext context, WidgetRef ref, {required String canvasId, Set<String>? nodeIds});
Future<void> pasteClipboard(BuildContext context, WidgetRef ref, {required String canvasId, required PasteAnchor anchor});
/// 键盘路径的锚点：canvasPointerProvider 有点 → PointerPasteAnchor，否则 NoPointerPasteAnchor。
PasteAnchor keyboardPasteAnchor(WidgetRef ref, {required String canvasId});

// models/commands/paste_nodes_command.dart（独立文件）
/// 撤销 = removeNodes(新 id 集)（nodes-batch-ops，一个事务，级联软删边；W6 起有 bridge 参数，这里用默认 false），记下 NodeDeletion；
/// 一个都不在 ⇒ CanvasCommandOutcome.gone。重做 = restoreAll(那批 NodeDeletion)，返回 0 ⇒ gone。
class PasteNodesCommand extends CanvasCommand {
  PasteNodesCommand(this.nodeIds);
  final Set<String> nodeIds; List<NodeDeletion>? _deleted;
  @override String label(AppLocalizations l); // l.canvasCommandPasteNodes(nodeIds.length)
}
```
- `copySelection`：nodeIds 缺省 = 当前选中集；读本画布节点 / 边表、项目角色（`charactersControllerProvider(projectId).valueOrNull`，取 id → 名字）→ `buildClipboardSnapshot`（由 canvas-clipboard-core 新建）→ null 就什么都不做 → `canvasClipboardProvider.put` → `Clipboard.setData(ClipboardData(text: clipboardPlainText(...)))`（`displayName` 用 node_card 的 `nodeDisplayName`）→ 胶囊「已复制 N 个节点」（canvasCapsuleProvider，dedupeKey 'clipboard'）。不进撤销栈。
- `cutSelection` = `copySelection` 成功后 `deleteNodesWithUndo(..., message: 已剪切 N 个节点)`（nodes-batch-ops 之后它是一个事务、一张卡；undo-adopt 之后卡与栈步已绑定）。
- `pasteClipboard`：
  1. state 为 null → 返回。scope = `pasteScopeOf`。
  2. scope ≠ sameCanvas：对快照里每个**不同的**媒体相对路径，用 `fileResolverServiceProvider.resolve(projectId: sourceProjectId, canvasId: sourceCanvasId, relativePath: rel)` 取源文件绝对路径，经 W2 的 `ref.read(mediaImportServiceProvider).copyIntoCanvas(projectId:, canvasId: 目标画布, sourcePath: 绝对路径)` → `ImportedMedia.relativePath`（`imports/<uuid>.<ext>`，失败抛 `LocalIOError` 且不留 .partial）复制进目标画布，得 mediaPathMap；任一失败 → 对已复制的逐个 `discard(projectId:, canvasId:, relativePath:)`、错误卡「粘贴失败：有文件复制不了」、返回。
  3. `draftPaste` → `layoutPaste`（返回 drop_placement.dart 的 `NodePlacement = ({Offset world, String? laneId})`）（transform / 视口尺寸 `canvasViewportSizeProvider` / 泳道切片读法同 `menuNodePlacement`；`repeat` = 同画布且 NoPointer 时 `takeRepeat(canvasId)`，否则 0）。
  4. `pasteSnapshot` 失败 → 删掉复制件 + 错误卡「粘贴失败」。
  5. 成功：`canvasSelectionControllerProvider(canvasId).replace(新 id)`（multi-select-core）；`ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(PasteNodesCommand(新 id 集))`；`droppedCharacterRefs > 0` → 胶囊「已去掉 N 处角色引用（角色不在这个项目）」。不挪相机。
- 菜单：`clipboard_menu_items.dart` 的 run 里先 `c.dismiss?.call()`：空白处「粘贴」= `pasteClipboard(anchor: MenuPasteAnchor(c.request.anchor))`；节点菜单「复制」/「剪切」= 对 `c.targets` 调 copy / cut。menu-split 的条目自带 build / run，宿主按 `menuItemForPick` 派发，不用改宿主。

## 行为规则与边界情况
1. 焦点在任何文本框里：Ctrl C / X / V 归文本框（复制文字 / 粘贴文字），画布什么都不做（Action isEnabled / consumesKey 为 false）。
2. 选中集为空按 Ctrl C / X：什么都不做，不写系统剪贴板、不出胶囊。选中的全是没产物的空壳 result：同上。
3. Ctrl C：应用剪贴板换成新快照，系统剪贴板写纯文字，胶囊「已复制 N 个节点」（N = 快照里的节点数）；不进撤销栈，画布不变。
4. Ctrl X：先复制，再删除（一个事务、一张「已剪切 N 个节点」撤销卡，栈里一步「删除」）。撤销后节点回来，剪贴板内容不变。
5. Ctrl V 剪贴板为空：什么都不做；空白处菜单里「粘贴」置灰。
6. 同画布粘贴：不复制文件，新产物节点指向同一个相对路径。
7. 同项目别的画布 / 别的项目：每个不同的媒体文件只复制一次（同一张图被两个节点引用也只复制一份），复制件在目标画布 `imports/` 下。
8. 复制途中失败：已复制的全部删掉、库里不写任何行、错误卡；写库失败：同样删掉复制件，节点 / 边整体回滚（一个事务）。
9. 粘出的节点（且只有它们）成为选中；相机不动。
10. 粘贴一步撤销：Ctrl Z 一次让全部粘出的节点与它们之间的线消失；Ctrl Y / ⇧⌘Z 一次全部回来（restore，不换 id）。复制件撤销后不删（被软删节点引用，回收器只读）。
11. 落点按 layoutPaste：指针在舞台上 → 包围盒中心对指针；右键「粘贴」→ 锚点；指针不在舞台（如鼠标停在检查器上按 Ctrl V）同画布 → 原位右下偏 lg、连按递增；别的画布 → 视口中心。指针离开舞台（MouseRegion onExit）即清掉记的点。
12. 跨项目：粘出的配置不带 character_ids，提示词里的角色记号降成「@名字」或删掉；有改动时出胶囊。同项目不动角色。
13. 跨画布：粘出的节点不带原泳道，按落点重判；产物源配置不在选区里 → 断开溯源（独立的未入链图）。
14. Ctrl D 行为不变；按住 Ctrl V 不连粘（includeRepeats: false），一次次按才递增偏移。
15. mac 用 ⌘C / ⌘X / ⌘V，Windows 用 Ctrl；两组在两个平台都注册（与现有 ⌘D / Ctrl D 一致）。右键菜单里的快捷键提示按平台显示一个（取法同 undo-shortcuts-ui）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasClipboardCopied | Copied {count, plural, =1{1 node} other{{count} nodes}} | 已复制 {count} 个节点 |
| canvasClipboardCut | Cut {count, plural, =1{1 node} other{{count} nodes}} | 已剪切 {count} 个节点 |
| canvasClipboardCharactersDropped | Removed {count} character references (not in this project) | 已去掉 {count} 处角色引用（角色不在这个项目） |
| canvasPasteFailed | Couldn't paste | 粘贴失败 |
| canvasPasteCopyFailed | Couldn't paste: some files couldn't be copied | 粘贴失败：有文件复制不了 |
| canvasCommandPasteNodes | Paste {count} nodes | 粘贴 {count} 个节点 |
| settingsShortcutCanvasCopy / settingsShortcutCanvasCut / settingsShortcutCanvasPaste | Copy nodes / Cut nodes / Paste nodes | 复制节点 / 剪切节点 / 粘贴节点 |
（菜单行「粘贴 / 剪切 / 复制」与 AppAction 标签复用 W1 app-action-table 已加的 `appActionPaste` / `appActionCut` / `appActionCopy`，不新加 canvasBlankMenuPaste / canvasNodeMenuCut / canvasNodeMenuCopy。快捷键页键名照 W2 undo-shortcuts-ui 的 `settingsShortcutCanvasUndo` 前缀。）

## 测试
- `test/features/canvas/util/canvas_paste_actions_test.dart`（ProviderContainer + RecordingNodesController 改造的假控制器（记录 pasteSnapshot 入参）+ 记录型 MediaImportService fake + FakeToastService + 真 CanvasHistoryController；`TestDefaultBinaryMessengerBinding` 拦 `SystemChannels.platform` 的 `Clipboard.setData`）：
  - `复制写应用剪贴板与系统纯文字`；`空选区不复制`。
  - `同画布粘贴不复制文件`：copy 调用 0，草稿里路径原样。
  - `跨画布每个文件只复制一次`：两节点共用一张图 → copy 1 次，两个节点都指向复制件。
  - `复制失败零残留`：第二个文件复制抛错 → 第一个复制件被删、pasteSnapshot 0 次、错误卡 1 张。
  - `写库失败删复制件`：pasteSnapshot 抛 InkError → 删除调用覆盖全部复制件。
  - `粘出的节点成为选中`：选中集 == 返回的新 id。
  - `粘贴一步撤销`：undo 一次 → removeNodes 收到全部新 id；redo → restoreAll。
  - `剪切 = 复制 + 一个删除步`：剪切后剪贴板有快照、栈顶是删除步、卡文案为「已剪切 2 个节点」。
  - `跨项目去角色出胶囊`：droppedCharacterRefs > 0 → 胶囊文案；同项目无胶囊。
  - `指针不在画布同画布连粘递增`：两次粘贴的原点差一个 kDuplicateOffset。
- `test/features/canvas/canvas_nodes_controller_test.dart`（追加 group `pasteSnapshot`，用 fake_repositories + FakeUnitOfWork）：`按草稿顺序建、sourceNodeId 用新 id`；`第二遍补 pinned_result_id`；`边两端换成新 id`；`中途失败 state 不变并 rethrow`；`成功后边控制器失效`。
- `test/storage/transaction_integration_test.dart`（追加，真 PG）：`pasteSnapshot 第 3 个节点写失败整批回滚`——nodes / edges 行数不变。
- `test/features/canvas/widgets/canvas_clipboard_shortcuts_test.dart`（CanvasView + 快捷键层，装配照 canvas_node_shortcuts_test.dart）：
  - `Ctrl C 再 Ctrl V 在指针处粘出`（先 hover 到舞台某点）；`⌘C / ⌘V 同样生效`。
  - `文本框里 Ctrl V 不粘节点`（焦点在 TextField，pasteSnapshot 0 次）。
  - `空白处菜单粘贴：空时置灰、复制后可点、点了落在锚点`。
  - `节点菜单有剪切与复制，作用于整个选中集`。
  - `按住 Ctrl V 只粘一次`（repeat 事件不触发）。

## 变异点
1. clipboard_keys 的绑定 gate 改成 CanvasKeyGate.always（去掉文本让位） → `文本框里 Ctrl V 不粘节点` 红。
2. 跨画布不去重、每个引用复制一次 → `跨画布每个文件只复制一次` 红。
3. 复制失败时不删已复制件 → `复制失败零残留` 红。
4. pasteSnapshot 失败分支不删复制件 → `写库失败删复制件` 红。
5. 粘贴后不 replace 选中 → `粘出的节点成为选中` 红。
6. PasteNodesCommand.revert 只删第一个 id → `粘贴一步撤销` 红。
7. cutSelection 不传剪切文案 → `剪切 = 复制 + 一个删除步` 红。
8. pasteSnapshot 建产物时用旧 sourceNodeId → `按草稿顺序建、sourceNodeId 用新 id` 红。
9. pasteSnapshot 节点逐个各开事务 → `pasteSnapshot 第 3 个节点写失败整批回滚` 红。
10. activator 去掉 `includeRepeats: false` → `按住 Ctrl V 只粘一次` 红（esc-ladder 的守卫测试也红）。
11. MouseRegion 的 onExit 不清点 → `指针不在画布同画布连粘递增` 中「指针离开后按原位偏移」的断言红（该用例先 hover 再 exit）。
12. 空白处「粘贴」不判剪贴板空 → `空白处菜单粘贴：空时置灰` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/ test/storage/transaction_integration_test.dart`（后者 CI 有 PG 时跑）。
- 变异 1–12 逐条。
- 截图（widget：CanvasScreen，画布 A：镜头 01 图像配置 + 它的成片 + 选区外一张参考图，三者有参考边与产出线；画布 B 空）：①A 里选中配置 + 成片按 Ctrl C 后的胶囊；②A 里指针在空白处 Ctrl V 后（新的一对选中、内部产出线在、选区外的参考线没跟来）；③空白处右键菜单（粘贴可点）与剪贴板为空时（粘贴置灰）；④节点右键菜单（剪切 · 复制 · 复制一份）；⑤切到画布 B 粘贴后（落在视口中心）。

## 风险与不确定
- **canvas_view.dart 不在 W7 约定表里**：键盘粘贴要知道「指针此刻在不在舞台、在哪」，现有代码没有任何地方记录悬停位置（grep 无 PointerHoverEvent / onHover），只能在舞台视口外包一层 MouseRegion。W7 里没有别的片占用 canvas_view.dart（cm-drag-insert-narrative 用 stage_overlays、cm-lane-menu 用 stage_lane_layer），所以列成本片的一处一行改动；若主 Agent 不同意，退路是挂在 stage-drop-target 建的 `StageDropTarget`（同一坐标系，W7 也无人占用），或者暂时只做 NoPointer / Menu 两种落点、把「对指针」留到后续波。
- （复核已定）menu-split 的条目自带 build / run（undo_menu_items.dart 就是这么写的），本片用新文件 + 注册表一行，不碰 canvas_menu_host.dart（W7 归 cm-lane-menu）。
- （复核已定）W2 的 `MediaImportService.copyIntoCanvas(sourcePath: 绝对路径)` 与 `discard` 正好就是「已有文件 → 目标画布 imports/」与「删复制件」两个能力，不需要补接口（W5 rail-drag-assets 同用法）。
- 改动量大（计划估约 1400 行）；放不下时按计划拆：本片只做同画布 + 同项目（不跨项目，不碰角色降级），跨项目与 droppedCharacterRefs 胶囊拆成第二个 PR。
- （复核已定）步名由 `PasteNodesCommand.label(l)` 返回 `l.canvasCommandPasteNodes(n)`；胶囊走 W1 canvas-capsule 的 `canvasCapsuleProvider(canvasId).notifier.show(CanvasCapsuleMessage(text: …, dedupeKey: 'clipboard'))`。
