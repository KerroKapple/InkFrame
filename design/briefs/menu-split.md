# menu-split · 拆 create_node_menu.dart：菜单面板进 theme 层，宿主 / 请求 / 各类条目 / 菜单注册表分文件
- 波次 W0 / lane A / 基底 origin/main（f64f56e）；合入顺序在 canvas-view-split、esc-ladder 之后（plan.md 第 3 节「B 先合，C、A 其次」）
- 依赖切片：无（合并了 cm-menu-host-split、ink-menu-panel、canvas-menu-split）；阻塞决定：无

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/<切片id>`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标（用户看到什么变化，2–4 行）
用户看不到变化：新建菜单、空白处右键菜单、节点右键菜单（含「加入泳道 ›」子菜单）的项、顺序、置灰、键位提示、键盘与焦点行为全部原样。
内部：通用菜单面板 `InkMenuPanel` 进 theme 层（菜单栏下拉、「更多」、大纲 / 序列右键都能复用）；空白处 / 节点菜单项改由 `menu_registry.dart` 的一张表驱动，后续切片加菜单项 = 新文件 + 注册表一行；新增舞台外可用的 `CanvasMenuPopover`。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- ContextMenus.dc.html 顶部规则：「排序沿用节点菜单：动作 | 编排 | 删除。不可用的置灰不隐藏，键位都从快捷键表取」——注册表的 group / order 编号要能让后续连线 / 泳道 / 多选菜单按这个顺序插。
- GapsCanvas.dc.html「节点右键补项」：「分组：做 | take | 归类 | 定位 | 停用 · 删除」；「更多」下拉：「改用画布菜单组件 CanvasMenuPanel（键位、置灰说原因、↑↓ ↵ Esc，与右键同一套），不再用 Material showMenu」——舞台外要有按全局坐标开的弹层（本片的 `CanvasMenuPopover`）。
- ShellExport.dc.html「顶部菜单栏」：「←→ ↑↓ ↵ Esc」「置灰时上下键跳过、打勾、子菜单」——菜单栏下拉复用 `InkMenuPanel` 整套键盘行为，所以面板必须在 theme 层、不认识画布类型。
- 设计缺口：GapsCanvas 要求置灰项「悬停说原因」，现有面板没有这一状态（无 disabledReason 字段、无 tooltip）；本片纯搬移不加，留给第一个需要它的切片（more-dropdown-panel 或 cm-edge-menu）。
- 设计缺口：菜单栏下拉的宽度、相对标签的锚点没给尺寸；`CanvasMenuPopover` 先只支持「左上角对准一个全局点 + 放不下往回收」。

## 允许改的文件（逐个路径 + 每个文件改什么）
行号指 origin/main 的 `lib/features/canvas/widgets/create_node_menu.dart`（1561 行）。
- `lib/theme/components/ink_menu_panel.dart`（新）：搬第 863–1366 行（`CanvasMenuEntry`→`InkMenuEntry<T>`、`_CanvasMenuTapGroup`→`_InkMenuTapGroup`、`CanvasMenuPanel`→`InkMenuPanel<T>`、`_flattenMenu`、`_stepEnabled`、`_menuFrameHeight`、`_CanvasMenuPanelState`→`_InkMenuPanelState`）与第 1368–1561 行（`_MenuFrame`、`_MenuSearchField`、`_MenuRow`、`_MenuSeparator`、`_MenuEmptyRow`）。新增公开 `InkMenuPanelKeys { search, submenu }`，值沿用 `ValueKey<String>('canvasMenu.search')` / `('canvasMenu.submenu')`；面板内两处 `CanvasMenuKeys.*` 改引用它。只 import flutter 与 `lib/theme/**`。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`（新）：第 75–120 行（WireDrag / canvasWireDragProvider / WireDragController）、第 122–206 行（CanvasMenuKind / CanvasMenuRequest / canvasMenuRequestProvider / CanvasMenuController）、第 208–221 行 BlankMenuAction、第 223–240 行 CanvasMenuKeys（`search` / `submenu` 写成 `= InkMenuPanelKeys.search / .submenu`）。名字全不变。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`（新）：第 242–468 行 CanvasMenuHost + State、第 470–481 行 `_MenuFocusHandoff`、第 483–775 行 `_CanvasMenuLayer`（三个 `_xxxGroups` 方法移走，改调各 entries 文件 / 注册表）、第 780–800 行 `_MenuAnchorLayout` → 公开为 `CanvasMenuAnchorLayout`（popover 共用）。`_pickBlank` / `_pickNode` 改为按注册表派发；`_dismiss` 的「先交焦点再关」顺序与注释原样。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_popover.dart`（新）：`CanvasMenuPopover<T>`。
- `lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`（新）：第 802–861 行 `_createEntry` → `createMenuEntry`；第 516–540 行 `_createGroups` → `buildCreateMenuGroups`；第 321–352 行 `_pickCreate`（去掉开头的 `_dismiss`，由宿主先关）→ `runCreateMenuPick`。新建菜单仍由 `create_menu_model.dart` 的 `CreateMenuAction` 驱动，不进注册表。
- `lib/features/canvas/widgets/canvas_menu/blank_menu_entries.dart`（新）：`blankMenuItems`（由第 542–581 行 `_blankGroups` 与第 354–380 行 `_pickBlank` 改写成 4 条 `CanvasMenuItemDef`）。
- `lib/features/canvas/widgets/canvas_menu/node_menu_entries.dart`（新）：`nodeMenuItems`（由第 583–682 行 `_nodeGroups`、第 684–714 行 `_laneGroups`、第 382–423 行 `_pickNode`、第 425–437 行 `_saveAsCharacter`、第 777–778 行 `_isSubmitBusy` 改写）+ 舞台外入口 `buildNodeMenuGroups` / `runNodeMenuPick`。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（新）：`CanvasMenuScope`、`CanvasMenuContext`、`CanvasMenuItemDef`、`kCanvasMenuItems`、`buildMenuGroups`、`menuItemForPick`。
- `lib/features/canvas/widgets/create_node_menu.dart`：整文件替换为 barrel（见下）。
- `test/features/canvas/widgets/create_node_menu_test.dart`：**只做机械改名** `CanvasMenuEntry`→`InkMenuEntry`、`CanvasMenuPanel`→`InkMenuPanel`（含头注第 1 行的类名）；import 不动（barrel 会导出它们），断言一字不改。
- `test/features/canvas/widgets/canvas_menu/menu_registry_test.dart`（新）、`test/features/canvas/widgets/canvas_menu/canvas_menu_popover_test.dart`（新）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- canvas-view-split：`canvas_view.dart`、`widgets/stage/**`（它 `import 'create_node_menu.dart'` 用 CanvasMenuHost / WireDrag / canvasMenuRequestProvider，barrel 保证不用改）。
- esc-ladder → zoom-reset-100：`canvas_shortcuts.dart`（它也 import 本 barrel）、`widgets/shortcuts/**`、`util/escape_ladder.dart`、`providers/canvas_escape_ladder.dart`、`settings/util/shortcut_catalog.dart`、`util/canvas_zoom.dart`。
- undo-stack → naming-shot-unify：`models/canvas_command.dart`、`models/edge_endpoints.dart`、`providers/canvas_history_controller.dart`、`storyboard/widgets/script_import_dialog.dart`（导入脚本… 项照样调 `showScriptImportDialog`，签名不动）。
- multi-select-core → duration-format：`providers/canvas_selection_controller.dart`、`util/selection_geometry.dart`、`lib/l10n/duration_format.dart`。
- 另外：`util/create_menu_model.dart`、`util/node_menu_model.dart`（NodeMenuPick / NodeMenuAction 保留不删）、`canvas_tool_actions.dart`、`canvas_create_menu_test.dart`、`canvas_node_menu_test.dart`、`canvas_node_shortcuts_test.dart` 一律不改。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// lib/theme/components/ink_menu_panel.dart —— 字段 / 静态常量与原 CanvasMenuEntry / CanvasMenuPanel 逐个相同
@immutable class InkMenuEntry<T> { const InkMenuEntry({required T value, required String label, InkGlyph? glyph, Color? swatch, String? keyHint, bool enabled = true, bool danger = false, bool checked = false, List<List<InkMenuEntry<T>>>? submenu}); }
class InkMenuPanel<T> extends StatefulWidget {
  const InkMenuPanel({super.key, required double width, required List<List<InkMenuEntry<T>>> groups, required ValueChanged<T> onSelected, required VoidCallback onDismiss, required String emptyText, String? searchHint, ValueChanged<bool>? onFocusChange});
  static const double createWidth = 236, blankWidth = 196, rowHeight = 28, searchHeight = 30, swatchSize = 8;
  static const double separatorExtent = 1 + InkSpacing.xs * 2, frameInset = 1 + InkSpacing.xs;
  static const Object tapRegionGroup = _InkMenuTapGroup();
}
abstract final class InkMenuPanelKeys { static const Key search; static const Key submenu; }

// canvas_menu/menu_registry.dart
enum CanvasMenuScope { node, blank, create } // create 本片不用，留位
class CanvasMenuContext {
  const CanvasMenuContext({required this.context, required this.ref, required this.canvasId, required this.request, required this.targets, this.picked = '', this.dismiss});
  final BuildContext context; final WidgetRef ref; final String canvasId; final CanvasMenuRequest request; final Set<String> targets;
  final String picked;          // 偏离 contract：run 时 = 被选中那一行的 value（子菜单行带参数）；build 时为 ''
  final VoidCallback? dismiss;  // 偏离 contract：run 里先调它（关菜单 + 焦点还画布）；「新建…」不调、原地换菜单
}
class CanvasMenuItemDef { /* 与 contract 第 1 节相同：id, scope, group, order, build, run */ }
final List<CanvasMenuItemDef> kCanvasMenuItems = <CanvasMenuItemDef>[...blankMenuItems, ...nodeMenuItems];
List<List<InkMenuEntry<String>>> buildMenuGroups(CanvasMenuScope scope, CanvasMenuContext c, {List<CanvasMenuItemDef>? items}); // items 缺省 = kCanvasMenuItems（final 列表不能当默认值）
CanvasMenuItemDef? menuItemForPick(CanvasMenuScope scope, String picked, {List<CanvasMenuItemDef>? items}); // 取 picked 第一个 ':' 之前的部分比 id

// canvas_menu/node_menu_entries.dart
final List<CanvasMenuItemDef> nodeMenuItems;
List<List<InkMenuEntry<String>>> buildNodeMenuGroups(BuildContext context, WidgetRef ref, {required String canvasId, required String nodeId});
Future<void> runNodeMenuPick(BuildContext context, WidgetRef ref, {required String canvasId, required String nodeId, required String picked, VoidCallback? dismiss});
// canvas_menu/blank_menu_entries.dart
final List<CanvasMenuItemDef> blankMenuItems;
// canvas_menu/create_menu_entries.dart
InkMenuEntry<CreateMenuAction> createMenuEntry(AppLocalizations l, CreateMenuAction action);
List<List<InkMenuEntry<CreateMenuAction>>> buildCreateMenuGroups(WidgetRef ref, AppLocalizations l, {required String canvasId, required CanvasMenuRequest request});
void runCreateMenuPick(BuildContext context, WidgetRef ref, {required String canvasId, required CanvasMenuRequest request, required CreateMenuAction action});
// canvas_menu/canvas_menu_popover.dart —— 舞台外（大纲 / 工具条「更多」/ 序列 / 菜单栏）用
class CanvasMenuPopover<T> extends StatefulWidget {
  const CanvasMenuPopover({super.key, required Offset? anchor /* 全局坐标；null = 收起 */, required List<List<InkMenuEntry<T>>> groups, required ValueChanged<T> onSelected, required VoidCallback onDismiss, required String emptyText, double width = InkMenuPanel.blankWidth, Key? panelKey, required Widget child});
}
class CanvasMenuAnchorLayout extends SingleChildLayoutDelegate { CanvasMenuAnchorLayout(Offset anchor); }

// create_node_menu.dart（barrel，整文件）
export '../../../theme/components/ink_menu_panel.dart' show InkMenuEntry, InkMenuPanel, InkMenuPanelKeys;
export 'canvas_menu/canvas_menu_request.dart';
export 'canvas_menu/canvas_menu_host.dart' show CanvasMenuHost;
export 'canvas_menu/canvas_menu_popover.dart';
```
注册表初始内容（id 用现有枚举名拼，`'blank.${BlankMenuAction.x.name}'` / `'node.${NodeMenuAction.x.name}'`，让两个枚举继续有消费点）：

| id | scope | group | order | 说明 |
|---|---|---|---|---|
| blank.create | blank | 10 | 10 | run 不调 dismiss，直接 `openCreate(request.anchor)` |
| blank.importScript | blank | 10 | 20 | |
| blank.selectAll | blank | 50 | 10 | keyHint 仍走 `canvasShortcutLabel(... SelectAllNodesIntent ...)` |
| blank.fitView | blank | 50 | 20 | |
| node.generate | node | 10 | 10 | 「做」组 |
| node.duplicate | node | 10 | 20 | |
| node.saveAsCharacter | node | 30 | 10 | 「归类 / 定位」组（现状是一组，保持一条分隔线） |
| node.laneSubmenu | node | 30 | 20 | 子菜单行 value = `node.laneSubmenu:<laneId>`，「移出泳道」= `node.laneSubmenu:` |
| node.locateInSequence | node | 30 | 30 | |
| node.delete | node | 90 | 10 | danger |

group 编号约定写进 menu_registry.dart 头注：节点 10 做 / 20 take / 30 归类·定位 / 80 停用 / 90 删除；空白处 10 新建·导入 / 30 粘贴 / 50 选择·视图 / 70 吸附开关。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 三种菜单的项、文案、图标、键位提示、置灰判据、顺序、分隔线位置与 origin/main 完全一致（canvas_node_menu_test「…六项按稿的顺序都在」、canvas_create_menu_test「空白处右键 → …只有四项」守着）。
2. 右键的卡在菜单开着时被删 ⇒ 节点菜单一项都不出（`buildNodeMenuGroups` 先查节点，查不到返回空表，不进注册表）；新建菜单的源卡被删同理（原第 529–532 行逻辑原样）。
3. 派发：宿主收到 `String picked` → `menuItemForPick(scope, picked)` → `run(c)`；找不到定义 ⇒ 只关菜单什么都不做。生成 / 复制 / 存为角色 / 泳道 / 定位 / 删除各自先 `c.dismiss()` 再动作，顺序同原 `_pickNode`；`targets` 在 run 时用 `ref.read(selection)` 现算（与原来一致）。
4. `buildMenuGroups`：先按 group 升序、组内按 order 升序；`build` 返回 null 的项不出；组里一项都不剩就不出这一组（也不出多余分隔线）。
5. id 全局唯一且不含 `:`；子菜单参数只在 `:` 之后。
6. `_dismiss` 仍是「先 `CanvasShortcuts.reclaimFocus` 再 close」；点外面走 `toCanvasIfOrphaned`；焦点离开走 `keep`——三种交接原样（canvas_create_menu_test B1 组守着）。
7. `CanvasMenuPopover`：anchor 由 null 变非 null ⇒ 开（OverlayPortal.show）；全局点换成 Overlay 局部坐标后左上角对准它，右 / 下放不下往回收（`CanvasMenuAnchorLayout`）；点外面 / 面板失焦 / Esc ⇒ `onDismiss`；选一项 ⇒ `onSelected(value)`（由调用方决定关不关）；anchor 变回 null ⇒ 收起。与宿主共用 `InkMenuPanel.tapRegionGroup`，子菜单里点击不算点外面。本片没有生产调用方（大纲 / 「更多」/ 序列在后续切片接）。
8. theme 层零 features import；`InkMenuEntry` / `InkMenuPanel` / `InkMenuPanelKeys` 在 lib/ 下都有消费点（no_dead_theme_component_test 要求）。
9. 无持久化、不进撤销栈；mac / Windows 差异只在 keyHint（仍由 `canvasShortcutLabel(..., isMac:)` 给），不改。

## 新文案键（key · en · zh 表；没有写无）
无。

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- 不改断言即须全绿：`create_node_menu_test.dart`（仅改名）、`canvas_create_menu_test.dart`、`canvas_node_menu_test.dart`、`canvas_node_shortcuts_test.dart`、`test/quality/no_reverse_layer_import_test.dart`、`test/quality/no_dead_theme_component_test.dart`、`no_inline_styles_test.dart`、`no_magic_strings_test.dart`。
- 新 `test/features/canvas/widgets/canvas_menu/menu_registry_test.dart`（纯 Dart + 假 BuildContext 不需要：用自造的 `CanvasMenuItemDef` 列表传 `items:`）：
  - 「kCanvasMenuItems 的 id 全局唯一、不含冒号」。
  - 「buildMenuGroups 先按 group 再按 order 排」：给乱序的三项（g20/o10、g10/o20、g10/o10），断言输出 `[[g10o10, g10o20], [g20o10]]`。
  - 「build 返回 null 的项不出；整组都为 null 时这一组不出」。
  - 「menuItemForPick 认 `<id>:<参数>` 与裸 id；未知 id 返回 null；scope 不符返回 null」。
- 新 `test/features/canvas/widgets/canvas_menu/canvas_menu_popover_test.dart`（`test/_harness/test_app.dart` 包一层）：
  - 「anchor 为 null 时不出面板；给了全局点就开在那一点」：`tester.getTopLeft(find.byKey(panelKey))` == anchor（Overlay 原点为 0 时）。
  - 「右边 / 下边放不下：往回收进 Overlay」：anchor 贴右下角，面板右下沿 ≤ Overlay 尺寸。
  - 「点外面 ⇒ onDismiss 调一次」「Esc ⇒ onDismiss」「点一行 ⇒ onSelected 收到它的 value」。
  - 「子菜单里点击不算点外面」：带 submenu 的 groups，悬停开子菜单后点子菜单项，onDismiss 计数仍为 0。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写，每条注明哪条测试抓住它）
1. `ink_menu_panel.dart` `_stepEnabled` 里 `if (entries[i].enabled) return i;` 改成 `return i;` → create_node_menu_test「置灰的项：一打开高亮就跳过它，↵ 执行第一个能点的」红。
2. `canvas_menu_request.dart` `CanvasMenuKeys.search` 改成独立的 `ValueKey<String>('canvasMenu.search2')` → create_node_menu_test「打字过滤：不区分大小写的包含匹配…」红。
3. `menu_registry.dart` `buildMenuGroups` 去掉组内按 order 排序 → menu_registry_test「先按 group 再按 order 排」红，canvas_node_menu_test「右键一张没被选中的卡：…六项按稿的顺序都在」红。
4. `node_menu_entries.dart` node.generate 的 `enabled:` 去掉 `&& !busy` → canvas_node_menu_test「在忙（生成中）：生成置灰」红。
5. `blank_menu_entries.dart` blank.create 的 run 里先调 `c.dismiss?.call()` → canvas_create_menu_test「空白处右键 → 空白处右键菜单（只有四项）；点「新建…」→ 原地换成新建菜单」红。
6. `node_menu_entries.dart` node.laneSubmenu 的 run 把空后缀当成 `laneId: ''` 而不是 `null` → canvas_node_menu_test「移出泳道：laneId 为 null，屏幕上不挪」红。
7. `menu_registry.dart` `menuItemForPick` 不截 `:` 之前的部分（整串比 id）→ canvas_node_menu_test「子菜单列出本画布的泳道 + 移出泳道；…点另一条 ⇒ moveNode 带上目标…」红，menu_registry_test「menuItemForPick 认 `<id>:<参数>`」红。
8. `canvas_menu_host.dart` `_dismiss` 里先 close 再 reclaimFocus → canvas_create_menu_test「菜单选了一项、同一拍推上来一个不 autofocus 的框：焦点归框…」红。
9. `canvas_menu_popover.dart` TapRegion 的 `onTapOutside` 删掉 → canvas_menu_popover_test「点外面 ⇒ onDismiss 调一次」红。
10. 在 `ink_menu_panel.dart` 加一行 `import '../../features/canvas/widgets/canvas_shortcuts.dart';` → no_reverse_layer_import_test 红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test` 零告警；`flutter test test/features/canvas test/theme test/quality --exclude-tags golden` 全绿。
- `git diff origin/main -M --color-moved=zebra`：ink_menu_panel.dart 的主体应着色为 moved；`git diff origin/main -- test/` 只有 create_node_menu_test 的改名行 + 两个新测试文件。
- 不截图（行为不变）。

## 风险与不确定
- 注册表改写不是逐字搬移（枚举 switch → id 表），是本片唯一真改逻辑的地方；判据函数（node_menu_model / create_menu_model）一个不改，只换派发方式。
- esc-ladder 同波会动 `canvas_shortcuts.dart`；若它把 Intent 类或 `CanvasShortcuts.reclaimFocus` 挪走，本片的 import 由主 Agent rebase 时修（本片照 origin/main 写）。
- `ValueKey<T>(entry.value)` 的行 Key 从 NodeMenuPick / BlankMenuAction 值变成 String id；现有测试不按行 Key 找（已 grep 核对），但后续切片写测试请按文字或 id 找。
