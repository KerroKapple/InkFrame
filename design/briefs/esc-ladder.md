# esc-ladder · Esc 阶梯 + 画布快捷键改注册表
- 波次 W0 / lane C / 基底 origin/main（f64f56e）；依赖：无；阻塞决定：无。后续同 lane 叠 zoom-reset-100，W1 的 app-action-table、canvas-capsule 都建在本片的注册表上。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main 起分支 `feat/esc-ladder`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表每片只追加一行（替换自己的占位行算一行）——本片是**建表**的那一片。
> - CanvasNode 新派生属性写成新文件 extension，不改 canvas_node.dart；不给 Node/Edge/StyleLaneRepository 加抽象方法。
> - 新画布动作写进新文件；本片不碰 canvas_tool_actions.dart（只调用）。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
1. 在提示词条 / 检查器 / 左栏筛选框里按 Esc：只让输入框失焦、焦点回到画布，选中不再被清空（现存 bug）。
2. Esc 按一张固定层序表一次剥一层；后续切片（@ 弹层、查找条、框选、工具锁）只往表里登记，不改判序代码。
3. 画布快捷键从一张 `Map` + 一串 `_xxx()` 改成注册表：一条 `CanvasKeyBinding` = 键位 + 门槛 + 回调 + 文案 + 分组；设置「快捷键」页从注册表取文案。用户可见行为除第 1 条外不变。

## 设计依据
- KeyMap.dc.html ›「Esc 阶梯」：1 菜单（子菜单先关）> 2 @ 补全弹层 > 3 查找条 > 4 文字输入框失焦、焦点回画布 > 5 进行中的手势（拖线 · 框选）> 6 工具回到选择（工具锁 · 平移 · 连线）> 7 清空选中（节点和连线）。「不在阶梯上：对话框 · ⌘K · 设置 · 任务弹层 · 铃铛盖着时，Esc 归它们」。「_escape 照这张表逐层判，现有拖线 / 菜单 / 平移 / 连线并进来」「第 4 层是改动：现在 CanvasEscapeIntent 不对文字让位」「框选中 Esc 恢复按下前的选中」。
- KeyMap ›「单键」规则：全走 _EditingAwareAction；Tab、空格只在画布本身持主焦点时接管；`includeRepeats: false`，按住不连发。
- KeyMap ›「文字让位」：判据只有一个 `isEditingText`；Esc「另有去处：先失焦」。
- critic.txt 第二节第 24 条（Esc 归属）→ 采用 contract 的十档细分（KeyMap 第 5、6 档拆开）：`menu > mentionPopup > findBar > textField > wireDrag > marquee > linkMode > toolLock > panTool > selection`。
- 设计缺口：KeyMap 第 6 档没排「工具锁 / 平移 / 连线」三者同时生效时的先后；本片定为 连线 > 工具锁 > 平移（与现状「平移先于连线」相反，两者同时生效的场景现有测试没覆盖）。

## 允许改的文件
- `lib/features/canvas/util/escape_ladder.dart`（新）：`EscapeRungId`、`EscapeRung`、`resolveEscape`，纯 Dart。
- `lib/features/canvas/providers/canvas_escape_ladder.dart`（新）：`CanvasEscapeLadder` + `canvasEscapeLadderProvider`。
- `lib/features/canvas/widgets/shortcuts/canvas_key_binding.dart`（新）：`CanvasKeyGate`、`ShortcutGroup`、`CanvasKeyContext`、`CanvasKeyBinding`、`buildCanvasActions`。
- `lib/features/canvas/widgets/shortcuts/canvas_intents.dart`（新）：现 canvas_shortcuts.dart 第 53–141 行的 15 个 Intent 原样搬来。
- `lib/features/canvas/widgets/shortcuts/canvas_tool_keys.dart`（新）：`CanvasToolKeys`（第 145–215 行）、`isEditingText()`（第 219–223 行）原样搬来。
- `lib/features/canvas/widgets/shortcuts/core_canvas_keys.dart`（新）：现有全部键 + 回调（第 272–341 行的表、第 578–730 行的 `_xxx()`）改写成 `coreCanvasKeys`；回调改成公开顶层函数。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（新）：`kCanvasKeyRegistry`。
- `lib/features/canvas/widgets/canvas_shortcuts.dart`：删掉搬走的部分；`export 'shortcuts/canvas_intents.dart'; export 'shortcuts/canvas_tool_keys.dart';`（所有现有 import 路径照常可用）；`kCanvasShortcuts` 改为由注册表派生；`build()` 的 Actions 改由 `buildCanvasActions` 生成；第 469 行的 `CallbackAction<CanvasEscapeIntent>` 删除（Esc 走注册表）；改头注第 23、31 行——第 31 行写成不绑具体行为的说法「⌘0 / Ctrl+0 = 缩放复位（行为见 shortcuts/core_canvas_keys.dart 的 resetCanvasZoom），不是适应」，搬到 canvas_intents.dart 的 `CanvasZoomResetIntent` 文档注释同样写「缩放复位（⌘0 / Ctrl+0），行为见 resetCanvasZoom」，这样同 lane 后续的 zoom-reset-100 不必再改这两个文件。
- `lib/features/settings/util/shortcut_catalog.dart`：删 `ShortcutAction` 枚举与 `shortcutActionOf`；`ShortcutRow` 改形；`buildShortcutRows` 从注册表取；加两个按 id 取键位的函数；`canvasShortcutLabel` 签名不变（create_node_menu.dart 第 564–673 行在用）。
- `lib/features/settings/widgets/shortcuts_section.dart`：删 `actionLabel` 的 switch，改用 `row.label(l)`。
- 测试：见「测试」；`test/features/settings/shortcut_catalog_test.dart` 只做机械替换（见下）。

## 不许碰的文件
- menu-split：`lib/features/canvas/widgets/create_node_menu.dart`、`lib/features/canvas/widgets/canvas_menu/**`、`lib/theme/components/ink_menu_panel.dart`。本片只 import `canvasMenuRequestProvider` / `canvasWireDragProvider`（从 create_node_menu.dart barrel 导入，路径不管它搬没搬）。
- canvas-view-split：`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/stage/**`。
- undo-stack：`lib/features/canvas/models/canvas_command.dart`、`edge_endpoints.dart`、`providers/canvas_history_controller.dart`。
- naming-shot-unify：`lib/features/storyboard/widgets/script_import_dialog.dart`。
- multi-select-core：`lib/features/canvas/providers/canvas_selection_controller.dart`、`util/selection_geometry.dart`。
- duration-format：`lib/l10n/duration_format.dart`。
- 另外：`canvas_tool_actions.dart`、`canvas_toolbar.dart`、`left_rail/canvas_left_rail.dart` 只读（它们 import 的 `CanvasToolKeys` / `isEditingText` 经 re-export 照常可用）。
- （主 Agent 自查补充）同 lane 串行例外：zoom-reset-100 从本片分支往后叠，会再改 `shortcuts/core_canvas_keys.dart` 的 `resetCanvasZoom`；本片照常新建该文件，不必为它预留什么。

## 具体改动
```dart
// util/escape_ladder.dart
enum EscapeRungId { menu, mentionPopup, findBar, textField, wireDrag, marquee, linkMode, toolLock, panTool, selection }
typedef EscapeRung = ({bool Function() isActive, void Function() dismiss});
EscapeRungId? resolveEscape(Map<EscapeRungId, EscapeRung> rungs); // 按 EscapeRungId.values 顺序取第一个 isActive 的
// providers/canvas_escape_ladder.dart
class CanvasEscapeLadder {
  void register(EscapeRungId id, EscapeRung rung);   // 同 id 重复登记 = 覆盖
  void unregister(EscapeRungId id);
  EscapeRungId? peek({Map<EscapeRungId, EscapeRung> local = const {}});
  bool handle({Map<EscapeRungId, EscapeRung> local = const {}}); // local 覆盖同 id；剥了一层返回 true
}
final canvasEscapeLadderProvider = Provider.autoDispose.family<CanvasEscapeLadder, String>(...);
// 构造时登记五档核心层：menu（canvasMenuRequestProvider != null → close）、wireDrag（canvasWireDragProvider != null → cancel）、
// linkMode（linkModeControllerProvider != null → cancel）、panTool（canvasToolModeProvider == pan → select()）、
// selection（选中非空或 selectedEdge != null → 两个都 clear）。textField 不在 provider 里：它要画布的 FocusNode，由 CanvasShortcuts 以 local 传入。
// mentionPopup / findBar / marquee / toolLock 是空位，由后续切片 register / unregister。

// widgets/shortcuts/canvas_key_binding.dart
enum CanvasKeyGate { always, notEditingText, canvasFocused }
enum ShortcutGroup { app, tools, edit, view, generate, panels }   // app = ⌘K / 浮层 Esc 这类非画布行（偏离：contract 无 app）
class CanvasKeyContext { final BuildContext context; final WidgetRef ref; final String canvasId; final FocusNode canvasFocus; }
class CanvasKeyBinding {   // 字段写全（后续切片按这里的名字构造，主 Agent 跨批核对补充）
  const CanvasKeyBinding({required this.id, required this.activators, required this.intent, required this.gate,
      required this.group, required this.label, required this.onInvoke, this.listed = true, this.enabledWhen});
  final String id;                                   // 全局唯一，lowerCamel、以 canvas 开头、不含 '.'（canvasDelete、canvasUndo、canvasImportMedia）
  final List<ShortcutActivator> activators;          // 第二批键位一律引用 app-action-table 的 PlannedKeys，不另抄常量
  final Intent intent;
  final CanvasKeyGate gate;
  final ShortcutGroup group;
  final String Function(AppLocalizations l) label;   // 快捷键页文案
  final void Function(CanvasKeyContext c, Intent intent) onInvoke;
  final bool listed;                                 // false = 不上快捷键页（如重复触发键）
  final bool Function(CanvasKeyContext c)? enabledWhen; // 偏离：追加可选字段，Esc 用
}
Map<Type, Action<Intent>> buildCanvasActions(List<CanvasKeyBinding> bindings, CanvasKeyContext? Function() context);
// 同一 Intent 类型的多条绑定（I / G / T 共用 CanvasAddNodeIntent）合成一个 Action，invoke 时把 intent 原样交给 onInvoke。
// 门槛：always = 只看 enabledWhen；notEditingText = 现 _EditingAwareAction 语义；canvasFocused = 现 _CanvasFocusedAction 语义。
// context() 返回 null（没打开画布）⇒ isEnabled / consumesKey 都 false。

// widgets/shortcuts/core_canvas_keys.dart
final List<CanvasKeyBinding> coreCanvasKeys; // id 用旧枚举名：canvasDelete, canvasEscape, canvasSelectAll, canvasDuplicate, canvasGenerate,
// canvasZoomIn, canvasZoomOut, canvasZoomReset, canvasFitAll, canvasFitSelection, canvasSelectTool, canvasPanTool, canvasAddImageNode,
// canvasAddVideoNode, canvasAddTextNode, canvasAddLane, canvasOpenCreateMenu, canvasToggleLink, canvasToggleLeftRail；列表顺序 = 旧枚举声明序。
// 每条 activators 与现 kCanvasShortcuts 同一组 const 表达式、同一顺序（Delete 在 Backspace 前，meta 在 control 前）。
void escapeCanvas(CanvasKeyContext c);  // = ladder.handle(local: {textField: ...})
void zoomCanvasBy(WidgetRef ref, {required String canvasId, required double factor});   // app-action-table、canvas-capsule 要调
void resetCanvasZoom(WidgetRef ref, {required String canvasId});                          // zoom-reset-100 改它
// widgets/shortcuts/canvas_shortcut_registry.dart
final List<CanvasKeyBinding> kCanvasKeyRegistry = <CanvasKeyBinding>[...coreCanvasKeys /* 后续每片追加一行 */];
// canvas_shortcuts.dart
final Map<ShortcutActivator, Intent> kCanvasShortcuts = { for (b in kCanvasKeyRegistry) for (a in b.activators) a: b.intent }; // 名字保留，现有测试直接读它
// settings/util/shortcut_catalog.dart
class ShortcutRow { final String id; final ShortcutGroup group; final String Function(AppLocalizations l) label; final List<String> keys; }
List<ShortcutRow> buildShortcutRows({required bool isMac, List<CanvasKeyBinding> registry = kCanvasKeyRegistry});
ShortcutActivator? canvasBindingActivator(String id, {required bool isMac}); // 该 id 第一个在本平台出得了字的激活器
String? canvasBindingLabel(String id, {required bool isMac});
```
- textField 层（CanvasShortcuts 以 local 传入）：`isActive = isEditingText()`；`dismiss = primaryFocus?.unfocus(); canvasFocus.requestFocus();`。
- Esc 绑定：`gate: always`，`enabledWhen: (c) => ladder.peek(local: …) != null`——无事可剥时不消费按键（现在是一律消费）。
- 清单行序：先 `commandPalette`、`overlayDismiss`（group app），再按注册表顺序逐 id 合并（listed == false 的跳过），`canvasHoldPan` 插在 `canvasPanTool` 行之后。

## 行为规则与边界情况
1. 焦点在 CanvasShortcuts 子树内任一 EditableText（提示词条、检查器、左栏筛选框）按 Esc：输入框失焦、画布持主焦点、选中与选中连线不变、按键被消费。
2. 输入框失焦后再按一次 Esc：按层序继续剥（例如清空选中）。
3. 菜单开着而焦点在画布：Esc 先关菜单；菜单自己持焦时由菜单处理（create_node_menu.dart 第 1204 行），本层收不到。
4. 拖线中按 Esc 取消拖线；连线模式 → 退出连线，不动选中；平移工具 → 回选择，不动选中；都没有 → 清空节点 + 边选中。
5. 什么都没得剥（无选中、无工具态、无菜单）：Esc 不被消费，冒泡给祖先。
6. 对话框、⌘K、设置浮层、任务弹层、铃铛开着时它们持焦，Esc 归它们；本层不改它们。
7. 后续层登记：`register` 后立刻参与判序；`unregister` 后不再参与；同 id 二次登记以后者为准。
8. 未打开画布（currentCanvasId == null）：所有画布绑定不启用、不消费。
9. macOS / Windows：⌘ 与 Ctrl 两个变体照旧同时注册；清单按平台各列一套（formatShortcutActivator 不变）。
10. 与撤销栈：Esc 不进撤销栈；输入框失焦不额外触发写入（失焦提交由各输入框自己负责，不改）。

## 新文案键
| key | en | zh |
|---|---|---|
| settingsShortcutCanvasEscape（改值） | Back out one step (menu · text field · tool · selection) | 逐层退出（菜单 · 输入框 · 工具 · 选中） |

## 测试
先写 1–3，确认在 origin/main 上红（1 现在会清空选中）。
- `test/features/canvas/widgets/canvas_shortcuts_escape_test.dart`（新，复用 canvas_shortcuts_test.dart 的 `_pump` 写法：CanvasShortcuts 包 Column[CanvasView, TextField]）：
  1. 「焦点在输入框里按 Esc：只失焦，选中还在」：select('a') + 选中边 e1 → tap TextField → Esc → 选中仍 {'a'}、边仍 e1、`isEditingText()` 为 false。
  2. 「失焦后焦点回到画布：紧接着按 H 生效」：同上 Esc 后按 H → `canvasToolModeProvider` == pan。
  3. 「无事可剥时 Esc 不被消费」：外层套 `CallbackShortcuts({Esc: counter++})`，无选中无工具态 → Esc → counter == 1；有选中时再 Esc → counter 不变、选中清空。
  4. 「登记的外部层优先于选中」：`ladder.register(EscapeRungId.findBar, …)` isActive=true → Esc → findBar 的 dismiss 被调、选中不变。
- `test/features/canvas/util/escape_ladder_test.dart`（新）：
  5. 「层序表」：`expect(EscapeRungId.values, <EscapeRungId>[menu, mentionPopup, findBar, textField, wireDrag, marquee, linkMode, toolLock, panTool, selection])`。
  6. 「两两同时生效取靠前的」：对每对 i<j，只开 i、j → `resolveEscape` == values[i]。
  7. 「登记顺序与优先级无关」：按倒序构造 Map 插入 → 结果同 6。
  8. 「全不生效 → null」。
- `test/features/canvas/providers/canvas_escape_ladder_test.dart`（新，ProviderContainer）：register / unregister / 覆盖 / `handle(local:)` 覆盖同 id；handle 返回值。
- `test/features/canvas/widgets/shortcuts/canvas_shortcut_registry_test.dart`（新）：
  9. 「id 唯一」。
  10. 「新键不吃自动重复」：除白名单 `{canvasDelete, canvasEscape, canvasSelectAll, canvasZoomIn, canvasZoomOut, canvasZoomReset}` 外，每条绑定的每个 `SingleActivator.includeRepeats` 为 false（白名单写死在测试里，后续切片加键不许改它）。
  11. 「同一 Intent 类型的绑定共用同一个 gate」。
  12. 「kCanvasShortcuts 与注册表一一对应」：条数相等、每个激活器映射到所属绑定的 intent。
- `test/features/settings/shortcut_catalog_test.dart`（机械替换，断言值不变）：`ShortcutAction.xxx` → 字符串 id `'xxx'`；`Map<ShortcutAction,…>` → `Map<String,…>`；第 19–27 行改为「每条 listed 绑定在两平台都出得了字」；第 174–179 行改为「行序 = app 两行 + 注册表顺序，holdPan 紧跟 panTool」（期望序列写死成旧枚举序）。新增 13.「listed: false 不上屏」：传入合成 registry（一条 listed:false）→ 行里没有它。
- 现有 `canvas_shortcuts_test.dart`、`canvas_node_shortcuts_test.dart`、`shortcuts_section_test.dart`、`canvas_create_menu_test.dart`、`canvas_node_menu_test.dart` 一行不改，必须全绿。

## 变异点
1. canvas_shortcuts.dart：把传给 `handle(local:)` 的 `EscapeRungId.textField` 那一项删掉 → 用例 1 红（选中被清空）。
2. textField 层 `dismiss` 里删掉 `canvasFocus.requestFocus()` → 用例 2 红。
3. escape_ladder.dart：`resolveEscape` 改成遍历 `rungs.keys` → 用例 7 红。
4. escape_ladder.dart：枚举里 `menu` 与 `wireDrag` 对调 → 用例 5、6 红。
5. core_canvas_keys.dart：L 键 `SingleActivator(CanvasToolKeys.link, includeRepeats: false)` 去掉 `includeRepeats: false` → 用例 10 红。
6. core_canvas_keys.dart：Esc 绑定的 `enabledWhen` 改成 `(_) => true` → 用例 3 红。
7. shortcut_catalog.dart：去掉 `listed` 过滤 → 用例 13 红。
8. canvas_escape_ladder.dart：selection 层的 dismiss 只清节点不清边 → canvas_shortcuts_test.dart「Esc 清空节点 + 边选择」红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas test/features/settings test/features/command_palette --exclude-tags golden`；逐条跑上面 8 个变异。
- 纯搬移部分用 `git diff -M --color-moved=zebra` 核对 Intent / CanvasToolKeys / 回调体是原样搬移。
- 手动 / 截图（test/_harness/screenshot.dart，CanvasScreen + fake_canvas 两节点）：① 选中节点 A 后点进提示词条输入，按 Esc → 截图：卡 A 仍有选中描边、输入框无光标；② 再按 Esc → 截图：选中消失。设置「快捷键」页截图与改前逐行一致（除 Esc 行文案）。

## 风险与不确定
- `kCanvasShortcuts` 的现有测试用 `const SingleActivator(...)` 当 Map 键查找，依赖 const 规范化成同一实例——core_canvas_keys.dart 必须写成完全相同的 const 表达式，否则这些查找取到 null。
- Intent / CanvasToolKeys 搬进 shortcuts/ 后由 canvas_shortcuts.dart re-export：避免 canvas_shortcuts ↔ core_canvas_keys 互相 import；若主 Agent 不要 re-export，就改为保留原位并接受循环 import。
- autoDispose 的 ladder provider 由 CanvasShortcuts 在 build 里 watch 保活（同第 457–458 行视口尺寸的写法）；后续切片在自己 widget 的 initState / dispose 里 register / unregister。
