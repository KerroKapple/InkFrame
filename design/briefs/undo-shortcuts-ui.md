# undo-shortcuts-ui · 撤销 / 重做入口：Ctrl Z · Ctrl Y / ⌘Z · ⇧⌘Z、空白处右键两项、⌘K 同名动作、胶囊反馈
- 波次 W2 / lane A / 基底：叠在 undo-stack、canvas-capsule、esc-ladder、app-action-table、menu-split 之后（即 W1 全部合入后的 origin/main）；依赖切片：undo-stack（CanvasHistoryController）、canvas-capsule（canvasCapsuleProvider）、esc-ladder（CanvasKeyBinding 注册表）、app-action-table（AppAction / 占位行）、menu-split（CanvasMenuItemDef 注册表）、multi-select-core（选中 `replace` / `removeAll`）；阻塞决定：无。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/<切片id>`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
画布上按 Ctrl Z / ⌘Z 撤销、Ctrl Y（Windows）/ ⇧⌘Z（macOS）重做；空白处右键菜单顶上多出「撤销 删除 3 个节点」「重做 …」两行（栈空置灰）；⌘K 动作组里有「撤销」「重做」；设置 › 快捷键页自动列出这两行。
撤销 / 重做后选中受影响的节点，不在视口里就平移过去（缩放不变），画布底部胶囊写「已撤销 · 删除 3 个节点」并带「重做 Ctrl+Y」按钮。
这一片之后栈里**还没有任何命令**（W3 才接删节点 / 删线 / 换道），所以手测时两项都是灰的；靠测试里的脚本命令验。

## 设计依据
UndoClipboard.dc.html「撤销 / 重做」：
- 头注：Windows Ctrl Z · Ctrl Y；macOS ⌘Z · ⇧⌘Z。空白处右键「撤销 移动 3 个节点 Ctrl Z」「重做 新建 图像配置 Ctrl Y」；栈空时「撤销」「重做」置灰不隐藏；⌘K 动作组同名。胶囊样稿「已撤销 · 移动 3 个节点 | 重做 Ctrl Y」。
- 规则：名字 =「撤销 / 重做」+ 这一步；重做主键 Windows Ctrl Y、macOS ⇧⌘Z，右键菜单、菜单栏「编辑」、⌘K、快捷键页都只显示这一个；文本框有焦点时 Ctrl Z 归文本框；撤销后选中受影响的节点，不在视口里就平移过去，缩放不变；反馈只走画布底部胶囊。
KeyMap.dc.html：重做每平台只注册一个（菜单、⌘K、右键、快捷键页同一串）；「文字让位」表里 Ctrl Z/Y 交给框，判据只有 isEditingText。
ShellExport.dc.html「编辑」菜单：撤销 Ctrl Z、重做 Ctrl Y，用镜像撤销图标；规则「重做：动作表只有一个主键」。critic.txt 第二节第 12 条：动作表主键 Windows Ctrl Y、mac ⇧⌘Z。
- 设计缺口：栈空时按 Ctrl Z、撤销进行中再按，反馈没画——本单定为都静默。
- 设计缺口：撤销**失败**的反馈没画——本单沿用现状的错误卡 `undoFailed`（失败卡不自动消失，胶囊 2s 会被错过）；「这一步已无法撤销」走胶囊。
- 设计缺口：⌘K 的动作名要带步名，但 `AppAction.label` 只收 `AppLocalizations`、拿不到栈——本片 ⌘K 只显示「撤销 / 重做」，禁用时原因「没有可撤销的操作」。
- 设计缺口：重做的「镜像撤销」图标 icon set v1 里没有（只有 `InkGlyph.undo`）——重做行 glyph 留空（空位对齐），不在本片加图标。
- 设计缺口：KeyMap 说「每平台只注册一个」，而现有画布键一律 ⌘ / Ctrl 双注册（esc-ladder 照旧）——本单注册 ⇧⌘Z 与 Ctrl+Y 两个变体、**不**注册 Ctrl+Shift+Z / ⌘Y；显示按平台各取一个。macOS 上 Ctrl+Y 也会重做（不展示），列入风险。

## 允许改的文件
- `lib/features/canvas/widgets/shortcuts/undo_keys.dart`（新）：两个 Intent、`UndoKeys` 激活器常量、`undoKeys` 绑定列表。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（由 esc-ladder 新建）：追加一行 `...undoKeys,`。
- `lib/features/canvas/widgets/canvas_menu/undo_menu_items.dart`（新）：`undoBlankMenuItems`。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（由 menu-split 新建）：追加一行 `...undoBlankMenuItems,`。
- `lib/features/canvas/util/canvas_history_actions.dart`（新）：撤销 / 重做 / 按步撤销的执行口 + 后效（选中、平移、胶囊、失败卡）+ 纯函数 `revealAffectedTransform` + `canvasHistoryAppActions`（两条 AppAction）。
- `lib/features/app_actions/app_action_catalog.dart`（由 app-action-table 新建）：把 `AppActionIds.undo` / `AppActionIds.redo` 两条占位行换成一行 `...canvasHistoryAppActions,`。
- `lib/features/settings/util/shortcut_catalog.dart`（偏离约定，见风险）：`_keyLabels` 补 `keyZ: 'Z'`、`keyY: 'Y'`；`formatShortcutActivator` 在 mac 上按 Apple 顺序写修饰键（⌃⌥⇧⌘），即 ⇧ 写在 ⌘ 前；Windows 顺序不变。
- 测试：`test/features/canvas/widgets/canvas_undo_shortcuts_test.dart`（新）、`test/features/canvas/widgets/canvas_undo_menu_test.dart`（新）、`test/features/canvas/util/canvas_history_actions_test.dart`（新）、`test/features/app_actions/canvas_history_app_actions_test.dart`（新）、`test/features/settings/shortcut_catalog_test.dart`（追加用例；并把第 203 行现有断言 `'⌘⇧A'` 改成 `'⇧⌘A'`——这是本片有意改的 mac 修饰键顺序，主 Agent 自查补充）。

## 不许碰的文件
- node-cost：`generation/services/node_cost.dart`、`cost_estimator.dart`、`image_config_inspector.dart`、`video_config_inspector.dart`、`canvas_prompt_bar.dart`、`canvas/widgets/cost_breakdown_tooltip.dart`。
- gen-inputs-snapshot：`generation/services/gen_inputs_snapshot.dart`、`generation_controller.dart`、`services/import/import_remapper.dart`、`services/project_archive_service.dart`。
- lane-ops-core：`canvas_lanes_controller.dart`、`util/lane_dissolve.dart`、`widgets/stage/stage_lane_layer.dart`、`lane_toolbar.dart`、`lane_title_bar.dart`。
- media-import-service：`core/interfaces/media_import_service.dart`、`services/file_media_import_service.dart`、`core/di/media_import.dart`、`services/orphan_file_reaper.dart`、`canvas/models/canvas_node_import.dart`、`canvas_nodes_controller.dart`、`providers/media_import_controller.dart`、`postgres_node_repository.dart`、`node_card.dart`。
- 另外不碰：`canvas_shortcuts.dart`、`shortcuts/core_canvas_keys.dart`、`canvas_menu/blank_menu_entries.dart`、`canvas_history_controller.dart`（undo-stack 的，只调用）、`providers/canvas_capsule.dart`（canvas-capsule 的，只调用）、`command_palette/command_actions.dart`（它从 kAppActions 自动取）。

## 具体改动
```dart
// shortcuts/undo_keys.dart
class CanvasUndoIntent extends Intent { const CanvasUndoIntent(); }
class CanvasRedoIntent extends Intent { const CanvasRedoIntent(); }
abstract final class UndoKeys {
  static const SingleActivator undoMeta    = SingleActivator(LogicalKeyboardKey.keyZ, meta: true, includeRepeats: false);
  static const SingleActivator undoControl = SingleActivator(LogicalKeyboardKey.keyZ, control: true, includeRepeats: false);
  static const SingleActivator redoMeta    = SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true, includeRepeats: false); // mac 主键
  static const SingleActivator redoControl = SingleActivator(LogicalKeyboardKey.keyY, control: true, includeRepeats: false);           // Windows 主键
  static SingleActivator undoFor({required bool isMac});
  static SingleActivator redoFor({required bool isMac});   // ShellExport 菜单栏（W4 win-menubar）也引这组常量
}
final List<CanvasKeyBinding> undoKeys; // id 'canvasUndo' / 'canvasRedo'；gate: CanvasKeyGate.notEditingText；group: ShortcutGroup.edit；
                                       // label: l.settingsShortcutCanvasUndo / Redo；onInvoke → runCanvasUndo / runCanvasRedo(c.ref.read, …)

// canvas_menu/undo_menu_items.dart
final List<CanvasMenuItemDef> undoBlankMenuItems; // id 'blank.undo' / 'blank.redo'，scope blank，group 小于 blankMenuItems 的最小 group（排在最上），order 0 / 1

// util/canvas_history_actions.dart
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);   // WidgetRef.read 与 ProviderContainer.read 都能传
Future<CanvasUndoResult> runCanvasUndo(ProviderReader read, {required String canvasId, required AppLocalizations l, required bool isMac});
Future<CanvasUndoResult> runCanvasRedo(ProviderReader read, {required String canvasId, required AppLocalizations l, required bool isMac});
Future<CanvasUndoResult> runCanvasUndoStep(ProviderReader read, {required String canvasId, required String stepId, required AppLocalizations l, required bool isMac}); // W3 卡片用
String canvasUndoMenuLabel(AppLocalizations l, CanvasHistoryStep? step);  // 「撤销」/「撤销 X」
String canvasRedoMenuLabel(AppLocalizations l, CanvasHistoryStep? step);
Matrix4? revealAffectedTransform({required Matrix4 current, required Size viewportSize, required Rect stageBounds}); // null = 已在视口，不动
final List<AppAction> canvasHistoryAppActions;   // AppActionIds.undo / redo，group edit
```
- 后效只在结果为 done 时做：选中 → 平移 → 胶囊；gone 只出胶囊；failed 出错误卡；empty / busy 什么都不做。
- 平移：受影响节点里此刻还在的，逐个 `nodeStageRect`（泳道切片 / 方向的取法照 `left_rail_actions.dart` 的 focusNodeOnCanvas）求并集 → `revealAffectedTransform` → 非 null 才写回 `canvasTransformControllerProvider(canvasId).value`。

## 行为规则与边界情况
1. Windows：Ctrl+Z 撤销、Ctrl+Y 重做；Ctrl+Shift+Z 不做任何事。macOS：⌘Z 撤销、⇧⌘Z 重做；⌘Y 不做任何事。（双注册下 mac 上 Ctrl+Z / Ctrl+Y 也生效，不展示。）
2. 主焦点在任何 EditableText 里（检查器文本框、提示词条、改名框）⇒ 两键都不被画布消费，交给框自己的撤销；画布栈不动。
3. 按住不放不连发（`includeRepeats: false`）；撤销在途再按 ⇒ 控制器返回 busy，静默。
4. 栈空按键 ⇒ 静默，不出胶囊、不出卡。
5. 撤销 done ⇒ 选中 = 受影响节点里此刻还在的（`replace`）；一个都不在 ⇒ 只把它们从选中里移除（`removeAll`），其余选中不动。
6. 受影响节点并集与视口有任何相交 ⇒ 不平移；完全在视口外 ⇒ 平移到并集中心落在视口中心，缩放不变；视口还没上报尺寸 ⇒ 不平移。
7. done 胶囊：`canvasHistoryUndone(<步名>)`，kind action（4s），按钮 `canvasHistoryRedoWithKey(<本平台重做键>)` → 重做；重做 done 胶囊：`canvasHistoryRedone(<步名>)`，按钮 `canvasHistoryUndoWithKey(<本平台撤销键>)`。同一 dedupeKey `'canvas-history'`，连按只留最新一条。
8. gone ⇒ 胶囊 `canvasUndoStepGone`（kind text），栈已丢掉那一步；不自动再撤下一步。
9. failed ⇒ 错误卡 `undoFailed`（toastServiceProvider，ToastKind.error），那一步仍在栈顶，可再按重试。
10. 右键菜单：两行永远出现；`nextUndo == null || busy` ⇒ 撤销行置灰（不隐藏），重做同理；行名带步名（菜单打开那一刻的栈顶）；行尾键位 = `canvasBindingLabel('canvasUndo' / 'canvasRedo', isMac)`，与快捷键页同源。
11. 选了菜单项 ⇒ 菜单先关、焦点回画布，再执行 `runCanvasUndo`；后效同 5–9。
12. ⌘K：两条动作 `isAvailable` = 外壳当前标签是画布且 `canvasId != null`；`isEnabled` = 有栈顶且不 busy；禁用原因 `canvasHistoryNothingToUndo` / `…Redo`；macKey / otherKey 取 `UndoKeys`（不另抄）。
13. 快捷键页：两行出现在「编辑」组；Windows 显示 `Ctrl+Z` / `Ctrl+Y`，macOS 显示 `⌘Z` / `⇧⌘Z`；不出现 Ctrl+Shift+Z。
14. 关画布：栈由 undo-stack 丢掉；残留胶囊随画布页卸载消失（canvasCapsuleProvider 是 autoDispose）。
15. 跨画布：键与菜单只作用于当前 `canvasId` 的栈。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasHistoryUndo | Undo | 撤销 |
| canvasHistoryRedo | Redo | 重做 |
| canvasHistoryUndoStep | Undo {step} | 撤销 {step} |
| canvasHistoryRedoStep | Redo {step} | 重做 {step} |
| canvasHistoryUndone | Undone · {step} | 已撤销 · {step} |
| canvasHistoryRedone | Redone · {step} | 已重做 · {step} |
| canvasHistoryUndoWithKey | Undo {key} | 撤销 {key} |
| canvasHistoryRedoWithKey | Redo {key} | 重做 {key} |
| canvasUndoStepGone | This step can no longer be undone | 这一步已无法撤销 |
| canvasHistoryNothingToUndo | Nothing to undo | 没有可撤销的操作 |
| canvasHistoryNothingToRedo | Nothing to redo | 没有可重做的操作 |
| settingsShortcutCanvasUndo | Undo | 撤销 |
| settingsShortcutCanvasRedo | Redo | 重做 |
（`{step}` / `{key}` 为 String 占位；复用 `undoFailed`。若 app-action-table 的占位行已有 undo / redo 文案键，⌘K 复用它们、不再用 canvasHistoryUndo / Redo，在回报里写明。）

## 测试
`test/features/canvas/widgets/canvas_undo_shortcuts_test.dart`（`_pump` 照 canvas_shortcuts_test.dart 抄；预先 `record` 两个 `ScriptedCanvasCommand`（由 undo-stack 新建的 test/_harness/fake_canvas_command.dart）；`debugDefaultTargetPlatformOverride` 切平台，tearDown 复位）：
- `Windows：Ctrl+Z 撤销栈顶一步`（脚本日志 `revert:B`）；`Windows：Ctrl+Y 重做`；`Windows：Ctrl+Shift+Z 不重做`。
- `macOS：⌘Z 撤销、⇧⌘Z 重做`；`macOS：⌘Y 不重做`。
- `文本框有焦点时 Ctrl+Z 归文本框：画布栈不动`（照 440 行那条把 TextField 放进子树，tap 后打字再按）。
- `撤销后选中受影响节点、出「Undone · <步名>」胶囊`（读 `canvasCapsuleProvider('c1')`）。
- `revert 返回 failed ⇒ 出 Couldn't undo 错误卡，栈顶不变`；`gone ⇒ 胶囊 This step can no longer be undone`。
`test/features/canvas/widgets/canvas_undo_menu_test.dart`（空白处右键开菜单，照 canvas_create_menu_test 的开法）：
- `栈空：撤销 / 重做两行都在且置灰`；`有一步：撤销行写「Undo <步名>」、行尾 Ctrl+Z，可点`；`点撤销行 ⇒ 菜单关、revert 调一次`。
`test/features/canvas/util/canvas_history_actions_test.dart`：
- `revealAffectedTransform：与视口相交 ⇒ null`；`完全在视口外 ⇒ 中心对齐、缩放不变`；`视口尺寸为空 ⇒ null`。
- `受影响节点有一个已不在 ⇒ 只选还在的`；`都不在 ⇒ 从原选中里移除、其余不动`。
- `连按两次 ⇒ 胶囊只留最新一条（同 dedupeKey）`。
`test/features/app_actions/canvas_history_app_actions_test.dart`：
- `栈空 ⇒ isEnabled false、disabledReason = Nothing to undo`；`非画布标签 ⇒ isAvailable false`；`macKey / otherKey 与 UndoKeys 是同一对象`。
`test/features/settings/shortcut_catalog_test.dart` 追加：
- `撤销 / 重做在编辑组：Windows 列 Ctrl+Z / Ctrl+Y`；`macOS 列 ⌘Z / ⇧⌘Z`；`不列 Ctrl+Shift+Z`。

## 变异点
- 把 undo_keys.dart 两条绑定的 `gate` 改成 `CanvasKeyGate.always` → 「文本框有焦点时 Ctrl+Z 归文本框」红。
- 把 `UndoKeys.redoControl` 改成 `SingleActivator(keyZ, control: true, shift: true)` → 「Windows：Ctrl+Y 重做」与「Ctrl+Shift+Z 不重做」红。
- 把 undo_menu_items.dart 的 `enabled` 改成恒 true → 「栈空：…置灰」红。
- 把菜单行文案改成恒 `canvasHistoryUndo` → 「撤销行写 Undo <步名>」红。
- 把 `revealAffectedTransform` 的相交判断删掉（恒平移）→ 「与视口相交 ⇒ null」红。
- 把后效里的 `replace(still)` 改成 `replace(affected)` → 「受影响节点有一个已不在 ⇒ 只选还在的」红。
- 删掉 done 分支的胶囊调用 → 「出 Undone · <步名> 胶囊」红。
- failed 分支改成出胶囊 → 「出 Couldn't undo 错误卡」红。
- 把 `formatShortcutActivator` 的 mac 修饰键顺序改回先 ⌘ 后 ⇧ → 「macOS 列 ⌘Z / ⇧⌘Z」红。
- 把 AppAction 的 `isEnabled` 改成恒 true → 「栈空 ⇒ isEnabled false」红。

## 验收
主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas test/features/settings test/features/app_actions test/features/command_palette`、逐条变异。
截图场景（`CanvasView` + 两节点 fake + 预先 record 一步「Delete 3 nodes」脚本命令，en / zh 各一）：① 空白处右键菜单（撤销行可点、重做行灰）；② 栈空时同一菜单（两行皆灰）；③ 按 Ctrl+Z 后底部胶囊「已撤销 · 删除 3 个节点 | 重做 Ctrl+Y」；④ 设置 › 快捷键「编辑」组（macOS 覆盖平台时显示 ⇧⌘Z）。

## 风险与不确定
- 偏离约定：contract 说「新键不再改 shortcut_catalog.dart」，但现有 `_keyLabels` 是白名单、没有 Z / Y，不补就出不了字；mac 修饰键顺序现写成 ⌘⇧，与设计 ⇧⌘Z 不符。W2 无其他切片占用该文件。
- 双注册使 mac 上 Ctrl+Y 也能重做，与 KeyMap「每平台只注册一个」字面不符；若要严格，需 esc-ladder 的 CanvasKeyBinding 支持按平台的激活器，留给 shortcuts-page-v2。
- 胶囊在画布页上：从卡片（W3）触发撤销时若用户在别的标签，胶囊看不到；失败仍有错误卡兜底。
- 栈里暂无真实命令，手测只能看到灰项；W3 合入后再做一次端到端截图。
