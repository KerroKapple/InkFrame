# mac-platform-menubar · macOS 系统菜单栏 PlatformMenuBar（同一张动作表；⌘Q 走有序退出）
- 波次 W7 / lane E 第二片 / 基底：叠在 lone-alt-menubar 之后（origin/main〔W0–W6 已合入〕+ lone-alt-menubar）
- 依赖切片：app-action-table（W1）、help-actions（W3）、win-menubar（W4：shell_menu_layout.dart、shell_menu_actions.dart、app_quit.dart、task_popover_open.dart）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- macOS 顶部系统菜单栏出现「InkFrame · 文件 · 编辑 · 画布 · 节点 · 窗口 · 帮助」，内容与 Windows 自绘菜单栏是同一张动作表、同一份布局。
- 「InkFrame」应用菜单放 关于 InkFrame / 设置… ⌘, / 服务 · 隐藏 / 退出 InkFrame ⌘Q；键位显示 ⌘ ⌥ ⇧，重做只显示 ⇧⌘Z。
- ⌘Q 走 `windowManager.close()` → main.dart 的 `_TeardownWindowListener` → AppTeardown 有序退出（先冲挂起写入，再停 JobQueue、关连接池、停 PG）。

## 设计依据
- ShellExport.dc.html 菜单规则（b2_shell.js:141–157）：同一张动作表；macOS 用系统菜单栏 `PlatformMenuBar`，chrome 不画这六个标签；关于 / 设置 / 退出进「InkFrame」应用菜单，键位显示 ⌘ ⌥ ⇧；重做只有一个主键，macOS 显示 ⇧⌘Z。
- KeyMap.dc.html 组合键表（b2_keys.js:100–112）：Alt F4 ↔ ⌘Q「退出」；Ctrl Y ↔ ⇧⌘Z「重做」；「mac 不绑 ⌘H ⌘M ⌘Tab ⌃←→」——⌘H / ⌘M 留给系统（本片用 PlatformProvidedMenuItem 的 hide / minimizeWindow，正是系统行为）。
- targets 注：⌘Q 不能用默认的 NSApp terminate；PlatformMenuBar 是声明式的，可用状态要在 watch 时重建菜单。
- 设计缺口：mac 菜单项没有悬停 Tooltip，「灰着说原因」在系统菜单里做不到（按：只置灰，原因看 ⌘K / 快捷键页）；单键（V / H / I / G / T / F / L / Tab / Del / Shift 1 / Shift 2）在系统菜单里显示与否没画（按：**不登记**为菜单 shortcut，只有带 ⌘ 的才登记，见规则 6）；启动失败页时菜单是什么没画（按：只留应用菜单）；对话框盖着时没画（按：自定义项全部置灰）。

## 允许改的文件
- lib/features/shell/widgets/shell_platform_menu_bar.dart（新）：把 `buildShellMenuLayout(isMac: true)` + AppAction 表接成 PlatformMenu 树。
- lib/app.dart：`home:` 包一层 `ShellPlatformMenuBar`（仅 macOS），见具体改动 3。
- lib/main.dart：不改逻辑；只更新 223–226 行注释（⌘Q 现在走 windowManager.close()；Dock 退出 / 系统注销仍走 NSApp terminate → AppDelegate requestTerminate）与 302–303 行 `_TeardownWindowListener` 头注（⌘Q 也到这里）。
- lib/features/shell/util/shell_menu_layout.dart（由 win-menubar 新建；W7 只有本片碰）：若 isMac 分支需要微调（如窗口菜单末尾留给系统项）可改。
- lib/features/shell/util/shell_menu_actions.dart（由 W4 win-menubar 新建，必然存在；W7 lane E 串行，本片在 lone-alt 之后）：给 `AppActionIds.quit` 那条补 `macKey: SingleActivator(LogicalKeyboardKey.keyQ, meta: true)`。「设置…」是 W1 app-action-table 的 `AppActionIds.openSettings` 行（不在本文件、注册表只许追加不许改行），它的 ⌘, 只在本片 shell_platform_menu_bar.dart 里作为应用菜单项的本地 `shortcut` 常量给出，不改 W1 的行。
- test/features/shell/shell_platform_menu_bar_test.dart（新）。

## 不许碰的文件
- lib/features/shell/widgets/ink_shell.dart：原足迹列了它，核对后**不改**（理由：PlatformMenuBar 挂在 InkShell 里时，启动失败 `_StartupGate` 换成 StartupErrorView 会把它卸掉，Flutter 卸载时清空系统菜单 → 连 ⌘Q 都没了；挂在 app.dart 的 home 上则常驻）。
- 同波其他片的全部热点：node_card.dart、outline_panel.dart、outline_model.dart、node_card_slot.dart、node_drag_delta.dart、edge_painter.dart、stage_edge_layer.dart、stage_overlays.dart、canvas_nodes_controller.dart、canvas_menu/*、canvas_node_delete.dart、shortcuts/*、lane_title_bar.dart、stage_lane_layer.dart、lane_menu_model.dart。
- services/app_teardown.dart（顺序契约不动）、macos/Runner/AppDelegate.swift、MainMenu.xib（PlatformMenuBar 运行时整体替换主菜单，xib 不必改）、shell_menu_bar.dart / ink_menu_bar.dart（Windows 侧，不动）、shortcut_catalog.dart（只调用 formatShortcutActivator）。
- W7 其他 lane 的全部画布文件（`lib/features/canvas/**`，含 clipboard-paste 的 canvas_view.dart、cm-lane-menu 的 lane_collapse_controller.dart）。

## 具体改动
1. shell_platform_menu_bar.dart：
```dart
class ShellPlatformMenuBar extends ConsumerStatefulWidget {
  const ShellPlatformMenuBar({super.key, required this.child, this.minimal = false});
  final Widget child; final bool minimal; // minimal = 启动失败：只给应用菜单
}
/// 纯数据快照（值相等）：标题、每项 label / 是否可用 / checked / shortcut 的序列。只有它变了才重建 PlatformMenuBar。
@immutable class PlatformMenuSnapshot { ... operator == / hashCode }
PlatformMenuSnapshot buildPlatformMenuSnapshot(...); // 纯函数，便于单测
```
   - 应用菜单（标题 `appTitle`）：关于 InkFrame（W3 help-actions 登记的 `AppActionIds.helpAbout`，文案 `helpAbout`）| 设置… ⌘,（`openOverlay(ShellOverlay.settings)`，交付进行中置灰，同 shell_chrome.dart:46–55）| `PlatformProvidedMenuItem(type: servicesSubmenu)` | hide · hideOtherApplications · showAllApplications | 退出 InkFrame ⌘Q（`ref.read(appQuitterProvider).quit()`）。每个 provided 项先过 `PlatformProvidedMenuItem.hasMenu(type)`。
   - 其余六组照 `buildShellMenuLayout(isMac: true)`；窗口菜单末尾加 provided `minimizeWindow` · `zoomWindow`。动态「节点 › 加入泳道 ›」同 win-menubar 的做法（laneMenuOptions + moveNodesToLane）。
   - 每个 AppAction → `PlatformMenuItem(label:, shortcut: _menuShortcut(action), onSelected: enabled ? () => _run(id) : null)`。
   - `_menuShortcut`：取 `action.keyFor(isMac: true)`（W1 AppAction 的成员；没有 `primaryKey`），是 `SingleActivator` 且 `meta: true`；**只有带 meta 的 SingleActivator 才登记**，其余返回 null。重做只登记 ⇧⌘Z 一个。
   - `_run(id)`：重查 isEnabled 与 `ModalRoute.of(context)?.isCurrent`，任一为 false 不执行；否则 `action.run(AppActionContext.read(context, ref))`（W1 的 run 收 AppActionContext；isEnabled 同样用 `action.isEnabled(c)`）。
   - 可用状态的订阅：build 里对每个动作走 AppAction 的 isEnabled 判据（watch 语义）；生成 snapshot，与上次相同就复用上次的 `PlatformMenuBar` menus 列表（不让 PlatformMenuBar 重发 setMenus）。
2. 退出：动作执行体只调 `AppQuitter.quit()`（W4 app_quit.dart，实现是 `windowManager.close()`）。main.dart:242 `setPreventClose(true)` 已让 close 进 `_TeardownWindowListener.onWindowClose`（main.dart:312）→ `AppTeardown.run`（幂等，app_teardown.dart:34）→ `windowManager.destroy()`。不使用 `PlatformProvidedMenuItem(type: quit)`（那是 NSApp terminate:）。
3. app.dart：`home: const _StartupGate()`（93 行）改成 `home: defaultTargetPlatform == TargetPlatform.macOS ? const _MacMenuGate(child: _StartupGate()) : const _StartupGate()`；`_MacMenuGate` 是 ConsumerWidget，`minimal = ref.watch(pgMigratedPoolProvider) is AsyncError`，返回 `ShellPlatformMenuBar(minimal: minimal, child: child)`。头注加一条。

## 行为规则与边界情况
1. 顶层次序：InkFrame · 文件 · 编辑 · 画布 · 节点 · 窗口 · 帮助；文件里没有「设置…」「退出」，帮助里没有「关于」（都在应用菜单）。
2. ⌘Q / 应用菜单「退出 InkFrame」→ AppQuitter.quit 恰好一次；teardown 仍按 窗口状态 → 挂起写入 → JobQueue → Pool → PG 的顺序（AppTeardown 不改）。连按两次 ⌘Q 不重入（`_closing` 守卫 + AppTeardown 幂等）。
3. Dock「退出」/ 注销 仍走 NSApp terminate → AppDelegate.swift:17 → `requestTerminate` channel（main.dart:227），与 ⌘Q 共享同一个 AppTeardown 实例，回收至多一次。
4. 键位：显示用系统符号（⌘ ⌥ ⇧，由 macOS 渲染）；重做只有 ⇧⌘Z；撤销 ⌘Z；命令面板 ⌘K；复制一份 ⌘D；生成 ⌘↵；收起左栏 ⌘\；适应全部 / 适应选中（Shift 1 / 2，无 ⌘）不登记 shortcut。
5. 可用状态随上下文变：切到画布标签 → 画布 / 节点组变可用；选中变化 → 节点组跟着变；交付进行中 → 设置与切标签项置灰；变化后下一帧系统菜单已更新。
6. 带 ⌘ 的键：Flutter 框架先处理（画布 / ⌘K 的 Shortcuts、文本框的 ⌘Z / ⌘A / ⌘C），框架没处理才落到菜单的 onSelected——同一按键不会执行两次（需真机核对，见风险 1）。单键不登记，避免系统菜单在文本框里抢 V / Del。
7. 状态没变化的重建（如 job 进度跳动、画布平移）不向系统重发菜单。
8. 对话框（showDialog 路由）盖着时：所有自定义项置灰，只剩系统 provided 项与「退出」可用。
9. 启动失败（StartupErrorView）：只有应用菜单，「关于」「设置」置灰，「退出」可用。
10. 窗口 › 任务：同 win-menubar（注册表空时灰，点了 `taskPopoverOpenProvider.open()`）。
11. 非 macOS：不挂 PlatformMenuBar（Windows 用自绘菜单栏）。
12. 与撤销栈：菜单「撤销 / 重做」调同一 AppAction，无单独逻辑。

## 新文案键
| key | en | zh |
|---|---|---|
| shellMenuQuitApp | Quit InkFrame | 退出 InkFrame |
| shellMenuSettings | Settings… | 设置… |
（「关于 InkFrame」复用 W3 help-actions 的 `helpAbout`，不新加 shellMenuAboutApp；provided 项文案由系统给，不进 ARB。）

## 测试
- test/features/shell/shell_platform_menu_bar_test.dart（新；`debugDefaultTargetPlatformOverride = macOS`；`WidgetsBinding.instance.platformMenuDelegate = _RecordingMenuDelegate()` 记下每次 setMenus 的参数，tearDown 还原）：
  - `顶层七个菜单次序`：第一次 setMenus 的标题 = [InkFrame, 文件, 编辑, 画布, 节点, 窗口, 帮助]。
  - `设置 / 退出 / 关于只在应用菜单`：文件、帮助里找不到它们。
  - `退出的 shortcut = ⌘Q，onSelected 调 FakeAppQuitter.quit 一次`（override appQuitterProvider）。
  - `重做只有一项且 shortcut = SingleActivator(keyZ, meta, shift)`；`全树没有 control: true 的 shortcut`。
  - `单键动作（选择 V、删除 Del、适应全部 Shift 1）的 shortcut 为 null`。
  - `工作室标签：画布 / 节点项 onSelected == null`；`切到画布标签后再次 setMenus，且画布 › 新建… onSelected != null`。
  - `无关重建不重发`：改 jobsRegistry 里某 job 的进度 → setMenus 调用次数不变。
  - `对话框盖着时自定义项 onSelected 全为 null，退出仍可用`。
  - `minimal：只有应用菜单，退出可用`。
  - `执行前重查：拿到 onSelected 后把状态改成不可用再调，不执行`。
- test/features/shell/shell_platform_menu_bar_snapshot_test.dart（可并进上一个文件）：`buildPlatformMenuSnapshot 值相等 / 不等`。
- 已有：test/services/app_teardown 相关测试不改仍绿（顺序契约）。

## 变异点
1. 退出改成 `PlatformProvidedMenuItem(type: quit)` 或直接 `exit(0)` → `退出 … 调 FakeAppQuitter.quit 一次` 红。
2. 文件菜单把设置 / 退出留着（layout 不按 isMac 剥）→ `设置 / 退出 / 关于只在应用菜单` 红。
3. `_menuShortcut` 不过滤 meta、把单键也登记 → `单键动作 … shortcut 为 null` 红；把 control 变体也登记 → `全树没有 control: true` 红。
4. 去掉 snapshot 比较 → `无关重建不重发` 红。
5. `_run` / 置灰判据去掉 isCurrent → `对话框盖着时 …` 红。
6. `_run` 去掉执行前重查 → `执行前重查` 红。
7. app.dart 去掉 minimal 分支 → `minimal：只有应用菜单` 红。

## 验收
- flutter analyze lib test；flutter test test/features/shell；逐条变异。
- 无截图（系统菜单不在 Flutter 画面里）；改为在 PR 描述附 macOS 真机清单：⌘Q 后 `ps` 无残留 postmaster、上一笔防抖改动已落盘；文本框里 ⌘Z / ⌘A / ⌘C 仍归文本框；画布上 ⌘Z 只撤一步（不双发）；⌘H 隐藏、⌘M 最小化正常；Dock 退出仍走有序退出；启动失败页 ⌘Q 能退出。

## 风险与不确定
1. 「框架先处理、未处理才给菜单」是 Flutter macOS 嵌入层对 key equivalent 的行为，依引擎版本；若真机发现菜单先截（⌘Z 在文本框里失效或画布双发），退路是：带 ⌘ 的项也不登记 shortcut、只靠框架 Shortcuts，在 PR 里报给主 Agent。
2. PlatformMenuBar 在 Flutter 里同一时刻只能有一个；后续若别处也想挂会断言失败——本片之后应只经 ShellPlatformMenuBar 扩展。
3. ⌘Q 关窗后 `applicationShouldTerminateAfterLastWindowClosed` 会再走一次 terminate → `requestTerminate`，此时容器已 dispose；AppTeardown.run 返回已完成的同一 future，但 channel 回调若因引擎已停而不回，会落到 AppDelegate 的 15s 兜底。现在点窗口关闭键已经是这条路，本片不改变它；真机清单里看一眼退出耗时。
4. 原足迹列了 ink_shell.dart，本片改挂 app.dart 的 home，ink_shell.dart 不动（理由见「允许改的文件」）。
5. 「关于」动作来自 help-actions（W3）；若它打开的是设置浮层的关于页，在启动失败页上不可用，所以 minimal 下置灰。
