# win-menubar · Windows 自绘菜单栏（文件 / 编辑 / 画布 / 节点 / 窗口 / 帮助真能点）
- 波次 W4 / lane D / 基底 origin/main〔W0–W3 已合入〕
- 依赖切片：app-action-table（W1）、menu-split（W0，InkMenuPanel）、help-actions（W3）、esc-ladder（W0，只读核对 Esc 顺序）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 顶栏六个标签（现在 shell_chrome.dart:103–140 `_MenuLabels` 只是文字）变成真菜单：点开下拉、子菜单、键盘 ←→ ↑↓ ↵ Esc。
- 菜单项全部来自 W1 的 AppAction 表（与 ⌘K 同源）：不可用的灰着、悬停写原因；「即将推出」的第二批动作一直灰着。
- 「窗口 › 任务」能从菜单打开状态栏的任务弹层。macOS 不画这一栏（mac-platform-menubar 接手）。

## 设计依据
- ShellExport.dc.html「顶部菜单栏」（生成脚本 b2_shell.js:24–160）：
  - 文件：新建项目… · 打开示例项目 | 导入项目包… · 导出项目包… · 导入媒体… Ctrl U（新，灰）| 导出视频… · 交付到剪辑软件… | 设置… · 回收站… | 退出 Alt F4。
  - 编辑：撤销 Ctrl Z · 重做 Ctrl Y（新）| 剪切 / 复制 / 粘贴（新，灰）| 复制一份 Ctrl D · 删除 Del | 全选 Ctrl A · 查找… Ctrl F（新，灰）· 命令面板… Ctrl K。
  - 画布：新建… Tab · 新建节点 › · 连线 L · 导入脚本… | 选择 V · 平移 H | 缩放 › · 适应全部 Shift 1 · 适应选中 Shift 2 | 收起左栏 Ctrl \。子菜单「新建节点 ›」= 图像配置 I · 视频配置 G · 文本 T · 镜头 · 便签 N（新，灰）| 泳道… F；「缩放 ›」= 放大 Ctrl + · 缩小 Ctrl − · 复位 100% Ctrl 0。
  - 节点：生成 Ctrl ↵ | 存为角色 · 加入泳道 › · 包成泳道 Ctrl G（新，灰）· 移出泳道 · 在序列中定位 | 删除 Del（danger）。
  - 窗口：工作室 · 画布 · 序列 · 画廊 · 导出（当前标签有标记）| 任务 · 通知 F6（新）。
  - 帮助：快捷键 | 新手引导 · 打开示例项目 | 版本说明 ↗ · 反馈问题 ↗ · 用户手册 ↗（灰，缺 URL）| 导出诊断包… · 打开日志目录 | 检查更新… · 关于 InkFrame。
  - 规则：共用一张动作表；灰着不藏、悬停说原因；点标签开，开着时划到相邻标签直接换开；Esc 先关菜单；标签移出 `DragToMoveArea`（双击判定让单击等 300ms）；重做只有一个主键（Windows 显示 Ctrl Y）；画布 / 节点两组只在画布标签可用；节点菜单对象 = 当前选中集、判据同节点右键菜单；帮助 = 左栏帮助弹层同一组动作 + 快捷键；macOS 不画。
- KeyMap.dc.html「弹层内部 · 菜单栏（Windows）」：←→ 切菜单 · ↑↓ · Enter · Esc 退出；「Esc 阶梯」：菜单是第 1 层。菜单栏下拉持焦，Esc 在面板里就被消费，不会漏到画布阶梯。
- 设计缺口：标签的悬停 / 打开态样式没画（按 KeyMap altBox：打开 / 悬停 = surface5 底 + fg1 字；键盘焦点 = InkActivatable 焦点环）；下拉离 chrome 下沿多远没画（按 0，贴下沿、左沿对齐标签）；行高 b2_shell 注释写 22、mi() 实画 21（按 22）；「窗口 › 任务」在没有 job（胶囊不画）时的状态没画（按灰 + 原因「还没有任务」）；「窗口」当前标签画的是前导圆点，InkMenuEntry 只有行尾打勾（按 checked 打勾）；设置浮层开着时菜单栏是否可用没画（按可用，各项判据照 AppAction 表，与 ⌘K overlay 分支同口径）。

## 允许改的文件
- lib/theme/components/ink_window_chrome.dart：加 `menus` 槽位，放在 DragToMoveArea 之外（见「具体改动 1」）；头注第 4–5 行补一句 menus 也在拖拽区外。
- lib/theme/components/ink_menu_bar.dart（新）：theme 层通用菜单栏组件，只收纯数据，不 import features/（no_reverse_layer_import_test 守着）。
- lib/theme/components/ink_menu_panel.dart（由 menu-split 新建；W4 无人占用，**只做纯追加的可选参数**，默认值保持现行为）：`InkMenuPanel.rowHeight`（默认 28）、`InkMenuPanel.onArrowOut`（见下）。置灰行悬停原因**不新加字段**：W3 help-actions 已给 `InkMenuEntry` 加了可选 `String? disabledReason`（置灰行外包 Tooltip 显示它），直接用它。见「风险」第 1 条。
- lib/features/shell/widgets/shell_chrome.dart：删 `_MenuLabels`（103–140），`center:` 改空、`menus:` 传 `ShellMenuBar()`（mac 传 null）；改头注 11–14 行（不再是纯文字）。
- lib/features/shell/widgets/shell_menu_bar.dart（新）：把菜单布局 + AppAction 表接成 `InkMenuBarMenu` 数据。
- lib/features/shell/util/shell_menu_layout.dart（新，表外新文件）：六个菜单的纯数据布局（mac 片复用）。
- lib/features/shell/util/shell_menu_actions.dart（新）：`kShellMenuActions`——W1 app-action-table 只**定了 id、没登记行**、明确留给本片的那几条（W1 表里标 ○）：file 组 `AppActionIds.exportProject` / `deliver` / `trash` / `quit`；window 组 `AppActionIds.showStudio` / `showCanvas` / `showSequence` / `showGallery` / `showExport` / `showTasks`。`addToLane`（○，带子菜单）不登记成 AppAction，由布局里的 `ShellMenuLaneSubmenu` 动态生成。`focusNotifications` 已是 W1 的 ★ 占位行、`helpShortcuts` 等 9 条已由 W3 help-actions 登记，本片都不再定义。
- lib/features/app_actions/app_action_catalog.dart（注册表，由 app-action-table 新建）：只追加一行 `...kShellMenuActions,`。
- lib/features/shell/providers/task_popover_open.dart（新）：任务弹层开关 provider。
- lib/features/shell/providers/app_quit.dart（新，表外新文件）：`AppQuitter` 接缝（退出项 + mac 片 ⌘Q 共用）。
- lib/features/shell/widgets/shell_task_capsule.dart：局部 `_portal` 开关（86、100–114 行）改由 provider 驱动。
- test/quality/no_dead_interactive_test.dart：正则名单加 `Selected`（菜单项 `onSelected: () {}` 也算死交互）。
- 测试文件见「测试」。

## 不许碰的文件
- W4 其他片：canvas_tool_actions.dart、widgets/stage/node_card_slot.dart、shot_config_inspector.dart、models/commands/create_nodes_command.dart、util/canvas_history_actions.dart（undo-node-create-move）；batch_results_*、batch_slot_*、batch_compare_overlay.dart、inspector_history_panel.dart、providers/current_take_controller.dart、models/commands/set_current_*_command.dart（tc-batch-slot-set-current）；canvas_view.dart、node_card.dart、widgets/stage/stage_lane_layer.dart、drop_placement.dart、canvas_drag_payload.dart、canvas_drop_hover.dart、widgets/stage_drop/*、theme/primitives/ink_dashed_outline.dart（stage-drop-target）；storage/schema、migrations、columns.dart、core/di/repositories.dart、test/_harness/shell_app.dart（export-records-table）。
- shell_task_popover.dart（W8 起归 job-timing 链）、ink_shell.dart、app.dart、main.dart（W7 mac 片）、create_node_menu.dart（只剩 barrel）、canvas_menu/*、node_menu_model.dart（只读调用）、shortcut_catalog.dart（只读调用 formatShortcutActivator）、command_actions.dart / palette_search.dart（W1 已接表，本片不动）。

## 具体改动
1. InkWindowChrome（现 45–63 行一个 DragToMoveArea 包 leading + center）改成：
```dart
const InkWindowChrome({super.key, this.leading, this.menus, this.center, this.trailing});
final Widget? menus; // 在 DragToMoveArea 之外；null = 不占位
// Row: [DragToMoveArea(Padding(left s12, Row[macInset?, leading]))]
//      [if menus != null: Flexible(loose, ClipRect(menus))]
//      [Expanded(DragToMoveArea(Align(centerLeft, center)))] [trailing] [窗口三键 / mac 让位]
```
2. ink_menu_bar.dart（theme，纯数据）：
```dart
@immutable class InkMenuBarMenu { const InkMenuBarMenu({required this.label, required this.groups, this.key});
  final String label; final List<List<InkMenuEntry<Object>>> groups; final Key? key; }
class InkMenuBarController extends ChangeNotifier { int? get openIndex; void open(int i); void close(); bool get isOpen; }
class InkMenuBar extends StatefulWidget {
  const InkMenuBar({super.key, required this.menus, required this.onSelected, this.controller});
  final List<InkMenuBarMenu> menus; final void Function(Object value) onSelected; final InkMenuBarController? controller;
  static const double dropdownWidth = 196; static const double rowHeight = 22;
  static Key labelKey(int i); static const Key dropdownKey;
}
```
   - 标签用 InkActivatable 的 onTap（走手势竞技场——这正是移出 DragToMoveArea 要验的点，不能改成 Listener.onPointerDown）。
   - 下拉：每个标签一个 CompositedTransformTarget；一个 OverlayPortal + CompositedTransformFollower（targetAnchor bottomLeft → followerAnchor topLeft），里面是 `InkMenuPanel(width: 196, rowHeight: 22, groups:…, onArrowOut:…)`。标签与下拉同一 TapRegion 组（含 InkMenuPanel.tapRegionGroup），点外面关。
   - 打开前记下 `FocusManager.instance.primaryFocus`，关时还回去（节点已 dispose 则不还）。
   - 窗口失焦（AppLifecycleListener，state != resumed，与 toast_layer.dart:80 同法）关。
3. InkMenuPanel 追加：`final void Function(TraversalDirection dir)? onArrowOut;`——现 create_node_menu.dart:1186–1194 的分支：子菜单没开且按 ←、或按 → 而高亮行不带子菜单时，若 onArrowOut 非 null 就调它并 handled；null 时行为不变（现在 ← 落到 skipRemainingHandlers）。
4. shell_menu_layout.dart（纯函数，可单测）：
```dart
sealed class ShellMenuItemSpec {}
final class ShellMenuAction extends ShellMenuItemSpec { const ShellMenuAction(this.id); final String id; } // AppActionIds 常量
final class ShellMenuSubmenu extends ShellMenuItemSpec { const ShellMenuSubmenu(this.titleKey, this.groups); ... }
final class ShellMenuLaneSubmenu extends ShellMenuItemSpec { const ShellMenuLaneSubmenu(); } // 节点 › 加入泳道 ›（动态）
enum ShellMenuTitle { file, edit, canvas, node, window, help }
List<({ShellMenuTitle title, List<List<ShellMenuItemSpec>> groups})> buildShellMenuLayout({required bool isMac});
```
   - 次序与分组逐项照「设计依据」；`isMac: true` 时去掉 文件›设置… / 文件›退出 / 帮助›关于（mac 片放进应用菜单），本片只用 isMac:false。
   - id 一律取 `app_action_ids.dart` 的常量（W1 已全部定义好 id）；要登记成 AppAction 的只有 W1 标 ○ 的十条（exportProject / deliver / trash / quit / showStudio / showCanvas / showSequence / showGallery / showExport / showTasks），在 shell_menu_actions.dart 定义，经 catalog 追加的一行进表，⌘K 也就能搜到（`inPalette` 按需给）。通知 F6 用 W1 已有的 ★ `focusNotifications` 行；帮助菜单整组直接取 W3 help-actions 的 `kHelpMenuGroups`（help_actions.dart，已含「快捷键」在首组），不在布局里另抄一份 id 列表。
   - 「导出项目包…」：执行体是 studio_home_screen.dart:639 的私有 `_exportProject`，本片不能改那个文件 → 登记为禁用、原因「即将推出」，留给后续片提公共函数。
   - 「通知 F6」：就是 W1 的 ★ 占位行 `comingSoon(AppActionIds.focusNotifications, …)`，本身已禁用「即将推出」，本片不碰（f6-notification-region W11 替换那一行）。
   - 窗口 › 五个标签：`goTab(t)`；当前标签 checked；交付进行中（deliveryBusyProvider）除序列外置灰，判据照 shell_tab_bar.dart:189 `lockedExcept`。
   - 回收站…：`showDialog(builder: (_) => const TrashDialog())`，参数照 library_sidebar.dart:70。
   - 退出：`ref.read(appQuitterProvider).quit()`；键位只显示 Alt F4（不注册 Flutter 快捷键，系统自己处理）。
5. shell_menu_bar.dart：
```dart
class ShellMenuBar extends ConsumerStatefulWidget { const ShellMenuBar({super.key}); static Key menuKey(ShellMenuTitle t); static Key itemKey(String actionId); }
```
   - build 里先 `final c = AppActionContext.read(context, ref);`，再把 layout 映射成 `InkMenuBarMenu`：每行 `final a = appActionById(id)!;` → 若 `!a.isAvailable(c)` 不画，否则 `InkMenuEntry(value: id, label: a.labelFor(c, l), keyHint: a.keyLabel(isMac: false), enabled: a.isEnabled(c), disabledReason: a.disabledReason(c, l), danger:…, checked:…)`（W1 `AppAction` 的实际成员：`labelFor` / `keyFor` / `keyLabel` / `isAvailable(c)` / `isEnabled(c)` / `disabledReason(c, l)` / `run(c)`；没有 `label(l)` / `primaryKey`）。为让置灰随状态刷新，build 里 watch `shellControllerProvider` 与当前画布的选中集，再按上面重算。
   - 动态「加入泳道 ›」：`laneMenuOptions(...)` / `canRemoveFromLane(...)`（node_menu_model.dart:113/127），对象 = `canvasSelectionControllerProvider(canvasId)`；选中时调 canvas_tool_actions 里现成的 moveNodesToLane（只调用，不改）。
   - onSelected：先关菜单、还焦点，再按 id 取 AppAction，用新的 `AppActionContext.read(context, ref)` **执行前重查 isEnabled**，false 就什么都不做；true 则 `action.run(c)`。
6. task_popover_open.dart：
```dart
final taskPopoverOpenProvider = NotifierProvider<TaskPopoverOpen, bool>(TaskPopoverOpen.new); // 非 autoDispose
class TaskPopoverOpen extends Notifier<bool> { void open(); void close(); void toggle(); }
```
   `open()` 在 jobsRegistry 为空时不置 true。胶囊：`_toggle` → `toggle()`；`ref.listen(taskPopoverOpenProvider, …)` 里 show + postFrame 要焦点 / hide；`_close`、Esc、onTapOutside → `close()`；摘要变成全 0 时 `close()`。
7. app_quit.dart：`abstract class AppQuitter { Future<void> quit(); }`；`final appQuitterProvider = Provider<AppQuitter>((ref) => const WindowManagerAppQuitter());` 实现只调 `windowManager.close()`（进 main.dart:304 的 `_TeardownWindowListener` 有序退出，与 ink_window_chrome.dart:99 关闭键同一条路）。

## 行为规则与边界情况
1. 点标签：下一帧（一次 pump）下拉就出来，不等 300ms（标签在 DragToMoveArea 外）。
2. 开着时再点同一标签 = 关；点外面 = 关；鼠标划到相邻标签 = 直接换开那一个（不用点）；没开时悬停只变底色、不开。
3. 下拉里 ↑↓ 跳过置灰行；↵ 执行；→ 开子菜单，行无子菜单时换到右边菜单（末尾回绕到第一个）；← 先收子菜单，没子菜单时换到左边（回绕）；换菜单后高亮落在新菜单第一项可用行。
4. Esc：先收子菜单，再关下拉并把焦点还给打开前的节点；Esc 不会漏到画布（画布选中不被清空）。
5. 菜单开着时按 I / Del 等画布单键不生效（面板 skipRemainingHandlers，menu-split 已有行为，不得破坏）。
6. 置灰行：点不动、悬停 Tooltip 显示原因；「即将推出」项原因文案一致。
7. 画布 / 节点两组：不在画布标签或没有 canvasId 时整组每项都灰（判据来自 AppAction.isEnabled，与 ⌘K 一致）；节点组对象 = 当前选中集，选中空时生成 / 删除等灰。
8. 执行前重查 isEnabled：菜单开着期间状态变了（如 job 跑完、选中被清），点下去不执行。
9. 动作执行在关菜单、还焦点之后；切标签类动作之后由 ShellContentStack 自己夺焦（shell_content_stack.dart:51–65，不加守卫）。
10. 「窗口 › 任务」：注册表空时灰（「还没有任务」）；有 job 时点 = 打开状态栏任务弹层并持焦，Esc / 点外面照旧关；胶囊上再点 = 关；注册表清空时 provider 自动回 false。
11. 退出：调 AppQuitter.quit 一次；不直接 exit / destroy。
12. 窗口失焦时下拉关。窄窗口：菜单标签从右侧裁掉不报溢出（保留现 _MenuLabels 的 ClipRect + OverflowBox 做法），shell_long_cjk_overflow_test 仍绿。
13. 全树仍只有一个 InkWindowChrome（shell_window_chrome_test V3a）。macOS（debugDefaultTargetPlatformOverride = macOS）：不画任何菜单标签。
14. 与撤销栈：菜单里的撤销 / 重做只是调同一 AppAction（W2 undo-shortcuts-ui 的 canvas_history_actions），不另走一条；文本框持焦时从菜单点「撤销」撤的是画布栈（菜单点击不是键盘事件）——按 AppAction 自己的判据。

## 新文案键
| key | en | zh |
|---|---|---|
| shellMenuNewNodeSubmenu | New node | 新建节点 |
| shellMenuZoomSubmenu | Zoom | 缩放 |
| shellMenuTasksEmpty | No tasks yet | 还没有任务 |
| shellMenuTrash | Trash… | 回收站… |
| shellMenuDeliver | Deliver to editor… | 交付到剪辑软件… |
| shellMenuExit | Exit | 退出 |
（「任务」复用现有 `taskPopoverTitle`（Tasks / 任务）；「通知 F6」用 W1 ★ 行自带的 `appActionFocusNotifications`；「打开示例项目」「关于」等帮助项用 W3 help-actions 的键；「即将推出」原因复用 W1 的 `appActionReasonComingSoon`。）

## 测试
- test/theme/components/ink_window_chrome_test.dart（加）：`menus 在拖拽区外`——menus 放一个 InkActivatable，tap 后只 `pump()` 一次 onTap 已触发；`menus 为 null 不占位`。
- test/theme/components/ink_menu_bar_test.dart（新，纯数据喂 InkMenuBar）：`点标签一帧内打开`；`开着时悬停相邻标签换开`；`再点同标签关`；`→ 在无子菜单行换到下一个菜单、末尾回绕`；`← 无子菜单时换到上一个`；`→ 在有子菜单行开子菜单而不换菜单`；`Esc 关并把焦点还给打开前的 FocusNode`；`置灰行悬停出 disabledReason Tooltip、点击不回调`；`点外面关`。
- test/features/shell/shell_menu_layout_test.dart（新）：`六个菜单次序与分组照稿`；`画布 › 新建节点子菜单含便签且排在泳道前`；`编辑里重做只出现一次`；`isMac 去掉设置 / 退出 / 关于`；`每个 ShellMenuAction 的 id 在 app_action_catalog 里都找得到`。
- test/features/shell/shell_menu_bar_test.dart（新，pumpInkShell + windows override）：`工作室标签：画布 / 节点组每项置灰`；`画布标签选中 1 个图像配置：节点 › 生成可用，点后 FakeNodesController / 生成入口被调一次`；`点击时 isEnabled 已变 false 不执行`；`窗口 › 画廊 → shell 状态 tab=gallery，当前标签行打勾`；`交付进行中：窗口里除序列外置灰`；`窗口 › 任务：注册表空时灰；有 job 时点开 → find.byType(ShellTaskPopover) 出现`；`退出调 FakeAppQuitter.quit 一次`；`Esc 关菜单后画布选中仍在`；`键位文本 = formatShortcutActivator(…, isMac:false)`（如复制一份显示 Ctrl+D）。
- test/features/shell/shell_task_capsule_test.dart（加）：`taskPopoverOpenProvider 置 true → 弹层出现；Esc 后 provider 回 false`；`注册表清空 → provider 回 false`。原有用例不改仍绿。
- test/features/shell/shell_window_chrome_test.dart（加）：`macOS 下不画菜单标签`；V3a 不改仍绿。
- test/quality/no_dead_interactive_test.dart：名单加 Selected 后仍绿。

## 变异点
1. ink_window_chrome.dart 把 menus 挪回 DragToMoveArea 里 → `menus 在拖拽区外`（一次 pump 未触发）变红。
2. ink_menu_bar.dart 去掉悬停换开（onEnter 不调 open）→ `开着时悬停相邻标签换开` 红。
3. InkMenuPanel 的 onArrowOut 分支删掉 → `→ 在无子菜单行换到下一个菜单` 红。
4. 关菜单不还焦点 → `Esc 关并把焦点还给…` 与 `Esc 关菜单后画布选中仍在` 红。
5. shell_menu_bar.dart onSelected 去掉执行前重查 → `点击时 isEnabled 已变 false 不执行` 红。
6. TaskPopoverOpen.open() 去掉注册表空判断 / 胶囊不 listen → `窗口 › 任务` 与胶囊 provider 用例红。
7. shell_chrome.dart 在 mac 也传 ShellMenuBar → `macOS 下不画菜单标签` 红。
8. layout 里重做多放一个 → `重做只出现一次` 红。

## 验收
- flutter analyze lib test；flutter test test/theme/components test/features/shell test/quality test/features/canvas/widgets（menu-split 的三份菜单测试不改仍绿）；逐条做上面变异。
- 截图（pumpInkShell + `debugDefaultTargetPlatformOverride = windows`，1536×984，深色）：① 工作室标签，打开「文件」；② 画布标签选中 1 个图像配置，打开「画布」并展开「新建节点 ›」；③ 打开「节点」悬停置灰的「包成泳道」出 Tooltip；④ 有 2 个运行中 job，点「窗口 › 任务」后任务弹层在状态栏上方打开。

## 风险与不确定
1. ink_menu_panel.dart 不在本波归属表里（W4 无人占用；W3 help-actions 已在里面加了 `disabledReason`），本片只追加 `rowHeight` 与 `onArrowOut` 两个可选参数；已在回报中告知主 Agent。若主 Agent 不同意，退路是 InkMenuBar 自己用 HardwareKeyboard 截 ←→（更脆，不推荐）。
2. （复核已定）W1 AppAction 成员按 app-action-table 派工单：`labelFor(c, l)` / `keyLabel(isMac:)` / `isAvailable(c)` / `isEnabled(c)` / `disabledReason(c, l)` / `run(c)`；W1 对窗口切标签、回收站、退出、交付、导出项目包、任务弹层只定了 id（○），所以 shell_menu_actions.dart 必建。
3. 「导出项目包…」执行体是私有函数，本片只能登记成禁用；建议后续片（Studio 相关）提成公共函数后改 isEnabled。
4. 退出项不显示 Alt F4 的可能：formatShortcutActivator 的 `_keyLabels` 若没有 F4，键位提示会是 null；本片不改 shortcut_catalog（W1 所有），先不显示键位，回报为缺口。
5. 菜单项 label 来自表，表里文案（如「打开示例项目」）改动会同时改 ⌘K，这是预期。
