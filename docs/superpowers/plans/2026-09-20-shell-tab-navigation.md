# 持久工作区标签外壳 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `_UnlockedShell` 的三级 if 链换成持久工作区标签外壳——五个标签切换不销毁彼此状态，设置降为外壳内一层，全树只剩一个窗口 chrome。

**Architecture:** 新增 `ShellState` 手写值对象（无 copyWith，只有 7 个具名迁移）作唯一真相源，`ShellNavigator extends Notifier<ShellState>` 作唯一写入口；`currentCanvasIdProvider` 降级为它的派生只读投影，`AppScreen` / `currentScreenProvider` / `currentGalleryProjectProvider` 三者整体退役。外壳是两级 `IndexedStack`（外层选 标签宿主/浮层槽，内层选五个标签），标签体懒物化、物化后常驻；`CanvasShortcuts` 按 `isTabVisible(canvas)` 让渡焦点。

**Tech Stack:** Flutter Desktop、Riverpod 2.6.1（手写 provider，**不新增 freezed**——build_runner 工具链受阻，见 `docs/BOARD.md`）、flutter_test + `test/_harness`、flutter gen-l10n。

**Spec:** `docs/superpowers/specs/2026-09-20-shell-tab-navigation-design.md`

## Global Constraints

- **门禁**（每个任务结束前两条都必须全绿）：
  ```bash
  NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
  NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
  ```
  Windows 上 flutter 不在 PATH，必须用绝对路径 `flutter.bat`；`NO_PROXY` 前缀必须有（本机 `HTTP_PROXY=http://127.0.0.1:7890`，缺了它整个 suite 会以 "Connection closed before test suite loaded" 全灭）。全量约 2 分钟，~66 skip 是本机正常基线。
- **golden 只在 CI ubuntu 铸线**，本地一律 `--exclude-tags golden`。绝不在本机"修" golden。
- **零硬编码文案**：新增用户可见文案必须同时进 `lib/l10n/app_en.arb` 与 `lib/l10n/app_zh.arb`，改完跑 `flutter gen-l10n` 并把 `lib/l10n/generated/` 一起提交（generated 陈旧 `flutter test` 抓不到，只有 `flutter analyze lib test` 会红）。
- **ARB key 禁止 `workspace` 前缀**（`test/l10n/arb_hygiene_test.dart:32-39` 硬禁 `startsWith('workspace')`，无白名单）。本 PR 一律 `shell*` / `shellTab*`。
- **零硬编码样式**：颜色/间距/圆角只用 `context.inkColors` / `InkSpacing` / `InkRadius`。`test/quality/no_inline_styles_test.dart:27-30` 只对 `lib/theme/primitives/` 与 `lib/theme/components/` 豁免 hex / `Colors.*` / `BoxShadow`；裸 `fontSize` / `EdgeInsets` 数字 / `BorderRadius` 数字**全仓适用含 theme 目录**。固定高度用具名 `static const double`（`SizedBox.height` 不在规则覆盖面内）。
- **注释中文**；ARB key、日志 module、错误码、provider `name:` 英文。
- **不新增 freezed 类**；值对象手写 `==` / `hashCode`。
- **零向后兼容**：退役的 provider / ARB key 不留别名、不留转发。
- **提交走 conventional commits**；`main` 受保护，全部提交在 `feat/shell-tab-navigation` 分支上，**不 push**（push 由用户处理）。
- **新增目录必须同一 commit 更新 `docs/CLAUDE.md` 的 Project Structure 段。**
- **TDD**：每个任务先写必红的测试、跑一次确认它红、再写实现、再跑绿。

---

## File Structure

### 新建（lib）

| 路径 | 职责 |
|---|---|
| `lib/features/shell/models/shell_state.dart` | `ShellTab` / `ShellOverlay` / `ProjectRef` / `ShellState`（纯 Dart，零 widget 依赖） |
| `lib/features/shell/providers/shell_controller.dart` | `ShellNavigator extends Notifier<ShellState>` + `shellControllerProvider` |
| `lib/features/shell/providers/active_project.dart` | `activeProjectProvider`（`ShellState.project` 的只读投影） |
| `lib/features/shell/providers/gallery_dirty.dart` | `galleryDirtyProvider`（粗粒度脏标记） |
| `lib/features/shell/widgets/ink_shell.dart` | 外壳根：唯一 Scaffold + chrome + 标签条 + 内容区 |
| `lib/features/shell/widgets/shell_content_stack.dart` | 两级 IndexedStack + `_shellFocus` 兜底焦点 |
| `lib/features/shell/widgets/shell_keep_alive_host.dart` | 懒物化 + 物化后常驻的五槽宿主 |
| `lib/features/shell/widgets/shell_chrome.dart` | 全树唯一 `InkWindowChrome` 的宿主 |
| `lib/features/shell/widgets/shell_breadcrumb.dart` | `project › canvas`（条件 watch，纯数据） |
| `lib/features/shell/widgets/shell_empty_state.dart` | 四处复用的空态（图标 + 标题 + 副标题 + 可选 CTA） |
| `lib/features/shell/widgets/shell_overlay_layer.dart` | 浮层槽分发（settings / showcase） |
| `lib/features/shell/widgets/tabs/studio_tab.dart` | Studio 标签体 |
| `lib/features/shell/widgets/tabs/canvas_tab.dart` | 画布标签体（含 canvasId==null 空态） |
| `lib/features/shell/widgets/tabs/gallery_tab.dart` | 画廊标签体（含未选项目空态 + 脏刷新） |
| `lib/features/shell/widgets/tabs/sequence_tab.dart` | 序列标签体（空态 + 拉起现有对话框） |
| `lib/features/shell/widgets/tabs/export_tab.dart` | 导出标签体（空态 + 拉起现有对话框） |
| `lib/features/shell/README.md` | 外壳不变量与副作用清单 |
| `lib/theme/components/ink_shell_tab_bar.dart` | 标签条组件（`height = 44`） |
| `lib/theme/components/ink_tool_bar.dart` | surface 级工具条（`height = 44`） |

### 修改（lib）

| 路径 | 改动 |
|---|---|
| `lib/app.dart` | `_UnlockedShell.build` → `const InkShell()` |
| `lib/theme/tokens.dart` | 28 槽 → 30（`surface5` / `borderStrong`），三工厂各补两行 |
| `lib/features/canvas/providers/current_canvas_id.dart` | `StateProvider<String?>` → 派生只读 `Provider<String?>` |
| `lib/features/canvas/providers/canvas_selection_controller.dart` | 改 family(canvasId) |
| `lib/features/canvas/providers/selected_edge_controller.dart` | 改 family(canvasId) |
| `lib/features/canvas/providers/link_mode_controller.dart` | 改 family(canvasId) |
| `lib/features/canvas/providers/canvas_transform_controller.dart` | `canvasViewportSizeProvider` 改 family(canvasId) |
| `lib/features/canvas/widgets/canvas_shortcuts.dart` | `+required bool isActive`；四处 family 实参 |
| `lib/features/canvas/widgets/canvas_screen.dart` | `+required bool isVisible`；透传给 `CanvasShortcuts` |
| `lib/features/canvas/widgets/canvas_view.dart` | family 实参（`:284/:315/:504/:1028/:1164/:1180`） |
| `lib/features/canvas/widgets/canvas_empty_state.dart` | family 实参（`:42/:79`） |
| `lib/features/canvas/widgets/canvas_add_node_fab.dart` | family 实参（`:36`） |
| `lib/features/canvas/util/canvas_node_delete.dart` | family 实参（`:23/:61`） |
| `lib/features/canvas/providers/canvas_bootstrap_controller.dart` | `:52` 改走 navigator（**极易漏**） |
| `lib/features/command_palette/command_actions.dart` | 三个导航动作改走 navigator；上下文判据读 `ShellState` |
| `lib/features/gallery/providers/gallery_filter.dart` | 改 family(projectId) |
| `lib/features/gallery/widgets/gallery_screen.dart` | 剥 chrome、补 `isActive` watch、搜索框播种 |
| `lib/features/settings/settings_screen.dart` | `AppBar` → `InkToolBar`；返回键 → `closeOverlay()` |
| `lib/features/settings/widgets/backup_section.dart` | 三 notifier → 一个 nav；`canPop()` 守卫 |
| `lib/features/settings/widgets/startup_section.dart` | `shellKeepLastCanvas` 开关 |
| `lib/features/showcase/widgets/built_in_showcase_screen.dart` | 剥 chrome；返回键 → `closeOverlay()` |
| `lib/features/studio/studio_home_screen.dart` | 去掉 `StudioTopChrome`；三处写点走 navigator |
| `lib/features/studio/open_canvas.dart` | `:24` 走 `nav.openCanvas(..., withProject:)` |
| `lib/features/studio/providers/restore_last_session.dart` | 守卫改 `isPristine` + 先判开关 |
| `lib/features/studio/widgets/library_sidebar.dart` | `:267` 走 navigator |
| `lib/features/studio/widgets/studio_provider_banner.dart` | `:55` 走 navigator |
| `lib/core/models/app_preferences.dart` | `+bool shellKeepLastCanvas`（六处） |
| `lib/l10n/app_en.arb` / `app_zh.arb` / `generated/` | +24 / −7 |

### 删除（lib）

| 路径 | 理由 |
|---|---|
| `lib/core/di/current_screen.dart` | `AppScreen` + `currentScreenProvider` 退役 |
| `lib/features/gallery/providers/current_gallery_project.dart` | 升格为 `activeProjectProvider` |
| `lib/features/canvas/widgets/canvas_top_chrome.dart` | chrome 收敛；导航由标签条承担 |
| `lib/features/studio/widgets/studio_top_chrome.dart` | 同上 |

### 新建（test）

`test/_harness/shell_app.dart`（`pumpInkShell`）、`test/_harness/shell_expect.dart`（`expectShellSurface`）、`test/features/shell/shell_state_test.dart`、`shell_navigator_test.dart`、`shell_tab_order_test.dart`、`shell_keepalive_test.dart`、`shell_focus_test.dart`、`shell_window_chrome_test.dart`、`shell_tabs_empty_state_test.dart`、`test/features/canvas/canvas_scope_isolation_test.dart`、`test/features/gallery/gallery_filter_scope_test.dart`、`test/quality/shell_projection_override_test.dart`。

---

## 依赖图

```
T1 焦点安全 ────┐
T2 画布态分族 ──┤
T3 两个 token ──┼──→ T5 ShellState ──→ T6 三 provider 退役 ──→ T7 外壳骨架 ──┬──→ T8  V1+V2 端到端
T4a 画廊 bug3 ──┤                                                           ├──→ T9  画廊标签真身
T4b 分键+播种 ──┘                                                           ├──→ T10 序列/导出标签
                                                                            └──→ T11 恢复+开关 → T12 收口 → T13 文档+golden
```

T1–T4b 五路并行。T4a 独立可先行合入。T6 是唯一不可再分的原子 commit。

---

### Task 1: `CanvasShortcuts` 按可见性让渡焦点（安全问题，最高优先级）

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_shortcuts.dart:135-194`
- Modify: `lib/features/canvas/widgets/canvas_screen.dart:21-60`
- Modify: `lib/app.dart:159`（临时传 `isVisible: true`，T7 换成真值）
- Test: `test/features/canvas/widgets/canvas_shortcuts_test.dart`

**Interfaces:**
- Produces: `CanvasShortcuts({Key? key, required bool isActive, required Widget child})`
- Produces: `CanvasScreen({Key? key, required bool isVisible})`

**背景**：`canvas_shortcuts.dart:150-152` 在 `initState` 的 post-frame 里 `requestFocus()` 恰好一次、此后永不释放（刻意压过 `CommandPaletteShortcuts` 的 `autofocus`）。画布保活后，不可见的画布会继续吞 Delete 并软删节点。

- [ ] **Step 1: 给 `CanvasShortcuts` 加形参但不接线（制造编译红 → 断言红）**

`lib/features/canvas/widgets/canvas_shortcuts.dart`，替换 `:135-142`：

```dart
class CanvasShortcuts extends ConsumerStatefulWidget {
  const CanvasShortcuts({
    super.key,
    required this.isActive,
    required this.child,
  });

  /// 画布页当前是否是外壳里被激活（可见）的那一层。
  /// false 时本层交出焦点并拒绝再被聚焦——不可见的画布绝不吞
  /// Delete / Backspace / Esc / ⌘A / ⌘0。
  final bool isActive;
  final Widget child;

  @override
  ConsumerState<CanvasShortcuts> createState() => _CanvasShortcutsState();
}
```

`canvas_screen.dart`：`:21-22` 改 `const CanvasScreen({super.key, required this.isVisible}); final bool isVisible;`，`:45` 改 `CanvasShortcuts(isActive: isVisible, child: ...)`（注意：原 `:44` 的 `const Expanded` 要去掉 `const`）。`app.dart:159` 改 `const CanvasScreen(isVisible: true)`。现有三处测试构造补 `isActive: true`。

- [ ] **Step 2: 写必红的测试**

`test/features/canvas/widgets/canvas_shortcuts_test.dart` 末尾追加。`_pump` / `_sendKey` / `twoNodes` 沿用本文件已有的 helper（见文件内既有用例）。

```dart
  // ===== 保活安全：不可见的画布不得吞 Delete（V2 前半）=====
  testWidgets('isActive:false → Delete 不删节点，且 ⌘K 仍能开命令面板', (tester) async {
    final container = await _pump(tester, nodes: twoNodes, isActive: false);
    container.read(canvasSelectionControllerProvider.notifier).select('a');
    await tester.pumpAndSettle();

    await _sendKey(tester, LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.byType(NodeCard), findsNWidgets(2), reason: '不可见画布不得响应 Delete');

    // 同一帧里 ⌘K 必须仍然可用——证明我们让出的是画布焦点，不是把键盘整个掐死。
    await _sendMeta(tester, LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteDialog), findsOneWidget);
  });

  // ===== 保活安全：重新可见时必须自己拿回焦点（V2 后半）=====
  testWidgets('isActive false→true → 不点任何东西，Delete 直接恢复生效', (tester) async {
    final container = await _pumpToggleable(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider.notifier).select('a');
    await tester.pumpAndSettle();

    await _setActive(tester, true);          // 由 StatefulBuilder 翻转
    await tester.pumpAndSettle();            // 等 post-frame 复焦跑完

    await _sendKey(tester, LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.byType(NodeCard), findsNWidgets(1),
        reason: 'ExcludeFocus 文档明说重新可见不会自动复焦，必须由 didUpdateWidget 的 post-frame 补上');
  });
```

配套 helper（同文件，放在既有 `_pump` 旁）：

```dart
/// 由 _pumpToggleable 装填：在测试里翻转 isActive。
late void Function(bool) _setActiveFn;

Future<void> _setActive(WidgetTester tester, bool v) async {
  _setActiveFn(v);
  await tester.pump();
}

/// 与 _pump 同构，唯一区别：CanvasShortcuts 包进 StatefulBuilder，isActive 可翻转。
/// 初始 false。
Future<ProviderContainer> _pumpToggleable(
  WidgetTester tester, {
  required List<CanvasNode> nodes,
}) async {
  final container = ProviderContainer(overrides: _canvasOverrides(nodes));
  addTearDown(container.dispose);
  bool active = false;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1.0),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CommandPaletteShortcuts(
            child: StatefulBuilder(
              builder: (BuildContext ctx, StateSetter setState) {
                _setActiveFn = (bool v) => setState(() => active = v);
                return CanvasShortcuts(
                  isActive: active,
                  child: const CanvasView(),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
```

> **实现顺序**：先把本文件现有 `_pump` 里那一长串 `overrides: <Override>[...]` 抽成一个共享的
> `List<Override> _canvasOverrides(List<CanvasNode> nodes)` 函数（`_pump` 与 `_pumpToggleable` 共用，
> 避免两份 override 清单漂移），再写 `_pumpToggleable`。
> `_pump` 的签名同时加 `bool isActive = true` 并透传给 `CanvasShortcuts`。
>
> 这里用 `UncontrolledProviderScope` 而非 `pumpInkApp`，是因为需要把 `container` 返回给测试去
> 直接驱动 provider——本文件既有的 `_pump` 已经是这个写法，照它来即可。

- [ ] **Step 3: 跑测试确认它红**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/features/canvas/widgets/canvas_shortcuts_test.dart --exclude-tags golden
```
预期：第一个用例 FAIL（`findsNWidgets(2)` 实际拿到 1——节点被删了），第二个用例视焦点情况可能 PASS。**第一个必须红**，红色输出贴进 commit body。

- [ ] **Step 4: 实现——`Focus` 接上 `isActive` + post-frame 复焦**

`canvas_shortcuts.dart`，`_CanvasShortcutsState` 里：

```dart
  @override
  void initState() {
    super.initState();
    if (widget.isActive) _claimFocus();
  }

  @override
  void didUpdateWidget(CanvasShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // 必须 post-frame：隐藏期间 canRequestFocus 被祖先拉成 false
      // （focus_manager.dart:536），同帧 requestFocus() 是彻底的 no-op 且不排队；
      // 要等这一帧的 Focus.didUpdateWidget 把开关拨回来。
      // ExcludeFocus 文档（focus_scope.dart:924-926）明说重新可见不会自动复焦。
      _claimFocus();
    }
    // 变 false 不必手动 unfocus：focus_manager.dart:583-594 在
    // descendantsAreFocusable 置 false 时自己会 unfocus(previouslyFocusedChild)。
  }

  void _claimFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) _focusNode.requestFocus();
    });
  }
```

`build` 里的 `Focus`（原 `:187-191`）改成：

```dart
        child: Focus(
          focusNode: _focusNode,
          skipTraversal: true,
          canRequestFocus: widget.isActive,
          descendantsAreFocusable: widget.isActive, // 连 Inspector 的 TextField 一起排除
          child: widget.child,
        ),
```

> **不要**顺手把 `CanvasEscapeIntent`（`:173-175` 的裸 `CallbackAction`）统一成 `_EditingAwareAction`——会改变 Esc 在输入框里的既有语义。

- [ ] **Step 5: 跑测试确认全绿**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/features/canvas/widgets/canvas_shortcuts_test.dart --exclude-tags golden
```
预期：PASS，且本文件既有的 D1 / D3 用例不得回归。

- [ ] **Step 6: 变异验证**

把 `canRequestFocus: widget.isActive` 临时改回 `canRequestFocus: true`，重跑——第一个用例**必须红**。确认后改回。

- [ ] **Step 7: 全量门禁 + 提交**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
git add lib/features/canvas/widgets/canvas_shortcuts.dart lib/features/canvas/widgets/canvas_screen.dart lib/app.dart test/features/canvas/widgets/canvas_shortcuts_test.dart
git commit -m "fix(canvas): 快捷键层按可见性让渡焦点——保活后不可见画布不得吞 Delete"
```

---

### Task 2: 四个全局画布 provider 按 canvasId 分族（V1 的硬前提）

**Files:**
- Modify: `lib/features/canvas/providers/canvas_selection_controller.dart:9-15`
- Modify: `lib/features/canvas/providers/selected_edge_controller.dart`
- Modify: `lib/features/canvas/providers/link_mode_controller.dart`
- Modify: `lib/features/canvas/providers/canvas_transform_controller.dart:27-46`
- Modify: `canvas_shortcuts.dart:199/211/220/228`、`canvas_view.dart:284/315/504/1028/1164/1180`、`canvas_empty_state.dart:42/79`、`canvas_add_node_fab.dart:36`、`canvas_node_delete.dart:23/61`、`command_actions.dart:121`、`link_action_controller.dart`
- Test: `test/features/canvas/canvas_scope_isolation_test.dart`（新建）

**Interfaces:**
- Produces: `canvasSelectionControllerProvider(String canvasId)`、`selectedEdgeControllerProvider(String canvasId)`、`linkModeControllerProvider(String canvasId)`、`canvasViewportSizeProvider(String canvasId)`

**背景**：今天「跨画布选中不串味」是**偶然**的——靠切 canvasId 时 `nodesAsync` 回 loading、`_CanvasBody` 卸载、唯一 watcher 消失。`canvas_shortcuts_test.dart:285-293` 的注释自己承认这点。保活会掀掉这个盖子。**不先做这一步，V1 的选中集断言是在为串味 bug 背书。**

- [ ] **Step 1: 写必红的测试**

`test/features/canvas/canvas_scope_isolation_test.dart`：

```dart
// 画布态按 canvasId 隔离（V1 的硬前提）：c1 的选中/选中边/连线态/视口尺寸
// 一律不得被 c2 读到。今天这四个 provider 是全局单例，本文件在改 family 前编译不过。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('选中集按 canvasId 隔离', () {
    container.read(canvasSelectionControllerProvider('c1').notifier).select('n1');
    expect(container.read(canvasSelectionControllerProvider('c1')), <String>{'n1'});
    expect(container.read(canvasSelectionControllerProvider('c2')), isEmpty,
        reason: 'c1 的 nodeId 串进 c2 会让 deleteNodesWithUndo 误删');
  });

  test('选中边按 canvasId 隔离', () {
    container.read(selectedEdgeControllerProvider('c1').notifier).select('e1');
    expect(container.read(selectedEdgeControllerProvider('c1')), 'e1');
    expect(container.read(selectedEdgeControllerProvider('c2')), isNull);
  });

  test('连线态按 canvasId 隔离', () {
    container.read(linkModeControllerProvider('c1').notifier).start('n1');
    expect(container.read(linkModeControllerProvider('c1')), isNotNull);
    expect(container.read(linkModeControllerProvider('c2')), isNull,
        reason: '残留 sourceNodeId 会让新画布首次点击就连出跨画布的边');
  });

  test('视口尺寸按 canvasId 隔离', () {
    container.read(canvasViewportSizeProvider('c1').notifier).setSize(const Size(800, 600));
    expect(container.read(canvasViewportSizeProvider('c1')), const Size(800, 600));
    expect(container.read(canvasViewportSizeProvider('c2')), Size.zero);
  });
}
```

> `selectedEdgeControllerProvider` / `linkModeControllerProvider` 的方法名以各自文件实际为准（`select` / `start` 可能叫别的），实现前先 `cat` 一眼再落笔。

- [ ] **Step 2: 跑测试确认它编译红**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/features/canvas/canvas_scope_isolation_test.dart
```
预期：编译失败（`canvasSelectionControllerProvider` 不是函数，不能用 `('c1')` 调用）。**编译红而非断言红，正是我们要的**——说明今天根本表达不了这个隔离。

- [ ] **Step 3: 四个 provider 改 family**

`canvas_selection_controller.dart:9-17`：

```dart
final canvasSelectionControllerProvider =
    AutoDisposeNotifierProviderFamily<CanvasSelectionController, Set<String>, String>(
      CanvasSelectionController.new,
      name: 'canvasSelectionControllerProvider',
    );

class CanvasSelectionController
    extends AutoDisposeFamilyNotifier<Set<String>, String> {
  @override
  Set<String> build(String canvasId) => const <String>{};
  // 其余方法体一字不动
}
```

`canvas_transform_controller.dart:27-46`：

```dart
/// 画布视口尺寸（由舞台层 LayoutBuilder 上报），按 canvasId 分族——与
/// canvasTransformControllerProvider 对称，避免第二个被布局的画布状表面覆盖它。
final canvasViewportSizeProvider =
    AutoDisposeNotifierProviderFamily<CanvasViewportSize, Size, String>(
      CanvasViewportSize.new,
      name: 'canvasViewportSizeProvider',
    );

class CanvasViewportSize extends AutoDisposeFamilyNotifier<Size, String> {
  @override
  Size build(String canvasId) {
    // 无人 watch（仅缩放处 read），不 keepAlive 会在 setSize 后随即自毁并复位
    // Size.zero，令快捷键缩放读到 0×0 → 围绕 (0,0) 而非视口中心（D2）。
    //
    // 债：family 上的 keepAlive 意味着每个开过的 canvasId 都永久留一个 entry
    // ——"与 transform 对称"这句话在 dispose 语义上并不成立。后续让缩放路径
    // 改 watch 后去掉 keepAlive。见 docs/BOARD.md。
    ref.keepAlive();
    return Size.zero;
  }

  void setSize(Size size) {
    if (size == state) return;
    state = size;
  }
}
```

`selected_edge_controller.dart` / `link_mode_controller.dart` 同法改 family，方法体不动。

- [ ] **Step 4: 用 analyze 当完备 checklist 修所有调用点**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
```
无参 provider 改 family 后所有调用点编译红 = 完备清单。逐个补 `canvasId` 实参。`canvas_node_delete.dart:23/61` 的函数签名里**已经有** `canvasId` 形参，直接用。

> **评审必须盯的静默错**：有人图省事写成 `canvasViewportSizeProvider('')`。改完手工跑：
> ```bash
> grep -n "canvasViewportSizeProvider" lib/ -r
> ```
> 六处必须全部带真实 canvasId 实参，零处传空串。

- [ ] **Step 5: 跑测试确认全绿**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
```
预期：新文件 4 个用例 PASS；`canvas_shortcuts_test.dart` 的 D3 用例**必须仍然 PASS**（它只碰早已 family 化的 transform + currentCanvasId）。

- [ ] **Step 6: 记债 + 提交**

`docs/BOARD.md` 债表追加一行：`canvasViewportSizeProvider family + keepAlive → 每个开过的 canvasId 永久留一个 entry；后续让缩放路径改 watch 后去掉 keepAlive`。

```bash
git add -A
git commit -m "refactor(canvas): 选中/选中边/连线态/视口尺寸按 canvasId 分族——保活前先堵跨画布串味"
```

---

### Task 3: `surface5` + `borderStrong` 两个 token（孤立，5 分钟）

**Files:**
- Modify: `lib/theme/tokens.dart`
- Test: `test/theme/tokens_test.dart`

**Interfaces:**
- Produces: `InkColors.surface5`、`InkColors.borderStrong`

- [ ] **Step 1: 写必红的测试**

`test/theme/tokens_test.dart` 追加：

```dart
  test('dark 的两个新槽位取值精确', () {
    final c = InkColors.dark();
    expect(c.surface5, const Color(0xFF36302A));
    expect(c.borderStrong, const Color(0xFF0D0A08));
  });

  test('light 的 surface5 取值精确', () {
    expect(InkColors.light().surface5, const Color(0xFFD9CDB6));
  });

  // 方向性：现有测试只断"槽位存在"，写反了照样绿。
  test('surface5 的 ramp 方向不许写反：暗色/HC 更亮，浅色更暗', () {
    for (final c in <InkColors>[InkColors.dark(), InkColors.highContrast()]) {
      expect(c.surface5.computeLuminance(),
          greaterThan(c.surface4.computeLuminance()));
    }
    expect(InkColors.light().surface5.computeLuminance(),
        lessThan(InkColors.light().surface4.computeLuminance()));
  });

  // 防复制：有人图省事把 surface5 复制成 surface4，激活标签与非激活标签
  // 视觉上不可区分，而所有功能测试照绿。
  test('surface5 不得等于 surface4', () {
    for (final c in <InkColors>[
      InkColors.dark(), InkColors.light(), InkColors.highContrast(),
    ]) {
      expect(c.surface5, isNot(c.surface4));
    }
  });

  // 激活标签的 label 直接画在 surface5 上，是新增的彩底前景组合。
  test('选中标签文字在 surface5 上满足 WCAG AA', () {
    for (final c in <InkColors>[InkColors.dark(), InkColors.light()]) {
      expect(wcagContrast(c.surface5, c.fg1), greaterThanOrEqualTo(4.5));
    }
    final hc = InkColors.highContrast();
    expect(wcagContrast(hc.surface5, hc.fg1), greaterThanOrEqualTo(7.0));
  });
```

同时把 `:29-46` 的"每个变体暴露 N 个槽位"循环补上两条 `expect(c.surface5, isA<Color>())` / `expect(c.borderStrong, isA<Color>())`，`:105-127` 的全槽位清单同改，并把测试名里的数字改对（否则名实不符）。

- [ ] **Step 2: 跑测试确认它编译红**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/theme/tokens_test.dart
```
预期：编译失败（`InkColors` 无 `surface5` / `borderStrong` 成员）。

- [ ] **Step 3: 实现**

`lib/theme/tokens.dart` 字段声明区按现有风格追加：

```dart
  /// 最高抬升面：激活标签 chip 底 / 列表选中行底。
  /// 只用于"激活 / 选中"的底，不做卡片底（那是 surface2/surface3）。
  final Color surface5;

  /// 结构性强分隔线：chrome ↔ 标签条 ↔ 内容 三段之间的硬边界。
  /// 只用于外壳级分区；组件内部细线继续用 borderSubtle。
  final Color borderStrong;
```

私有构造 `InkColors._` 的具名参数表加 `required this.surface5, required this.borderStrong`（28 槽 → 30）。三个工厂各补两行：

```dart
// dark()：ramp 0B0908 → 100C0A → 15110E → 1C1814 → 2A2520，surface5 延续暖褐爬升。
surface5: const Color(0xFF36302A),
borderStrong: const Color(0xFF0D0A08),

// light()：这条 ramp 本身不单调（越活跃越压暗），surface5 是 E5DBC4 再压一档。
// borderStrong 刻意不取 8A7E70——那是 fg3 的值，会被误读为文字。
surface5: const Color(0xFFD9CDB6),
borderStrong: const Color(0xFF9A8B70),

// highContrast()：border 本来就是纯白，"强"分隔线不可能比纯白更强，
// 故 borderStrong 与 border 同值——这是刻意的，不是遗漏。
surface5: const Color(0xFF2B241C),
borderStrong: const Color(0xFFFFFFFF),
```

- [ ] **Step 4: 跑测试确认全绿**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/theme/
```

- [ ] **Step 5: 提交**

```bash
git add lib/theme/tokens.dart test/theme/tokens_test.dart
git commit -m "feat(theme): 补 surface5 与 borderStrong 两个槽位（暖色 ramp，三变体）"
```

零 widget 影响、零 golden 影响（尚无人消费）。

---

### Task 4a: 画廊筛选器在 loading/error/空态被回收（今天就存在的 bug，可先行合入）

**Files:**
- Modify: `lib/features/gallery/widgets/gallery_screen.dart:41-52`
- Test: `test/features/gallery/gallery_filter_scope_test.dart`（新建）

**背景**：`galleryFilterProvider` 是全局 `StateProvider.autoDispose`，其唯一 watcher `_GalleryContent` 只出现在 `data` 且 `items.isNotEmpty` 这一个分支（已核实 `gallery_screen.dart:42-51`）。loading / error / `items.isEmpty` 三条路径下它不在树里 → 筛选器失去 watcher → autoDispose 复位。表现为"偶发丢筛选"，最难查。

> **若这条红测试在今天的代码上无法复现**，说明前提判断有误 —— **不得**把测试改成绿的，应先重新核实 `gallery_screen.dart:41-52` 的分支结构再决定本任务是否成立。

- [ ] **Step 1: 写必红的测试**

`test/features/gallery/gallery_filter_scope_test.dart`：

```dart
// 画廊筛选器的存活性（T4a）：筛选态不得因为列表进入 loading/error/空态而被回收。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_filter.dart';

void main() {
  test('筛选态在唯一 watcher 消失后被 autoDispose 回收——这正是要修的 bug', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 模拟 _GalleryContent 挂载：建立唯一的 watcher。
    final sub = container.listen(galleryFilterProvider, (_, _) {}, fireImmediately: true);
    container.read(galleryFilterProvider.notifier).state =
        const GalleryFilter(kind: GalleryItemKind.video);
    expect(container.read(galleryFilterProvider).kind, GalleryItemKind.video);

    // 模拟列表转入 error / 空态：_GalleryContent 卸载，watcher 消失。
    sub.close();

    // autoDispose 是调度式的，跑一次微任务队列让 dispose 落地。
    // 修复后 GalleryScreen 层自己持有一条 watch，这里应仍是 video。
    expect(container.read(galleryFilterProvider).kind, GalleryItemKind.video,
        reason: 'error 重试或 data→空 的抖动不得静默复位用户的筛选');
  });
}
```

> 若纯 `ProviderContainer` 层面复现不稳，改用 widget 层：`pumpInkApp` 一个 `GalleryScreen`，先让仓储返回非空 items（设筛选），再让它返回空 list（`ref.invalidate` + fake 切换），断言筛选控件仍显示原值。以能稳定复现的那个为准。

- [ ] **Step 2: 跑测试确认它红**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/features/gallery/gallery_filter_scope_test.dart
```
预期：FAIL（筛选被复位成默认值）。红色输出贴进 commit body。

- [ ] **Step 3: 实现——`GalleryScreen` 层补一条 watch**

`gallery_screen.dart` 的 `build` 里，在 `itemsAsync` 之后加：

```dart
    // 筛选器是 autoDispose，而它唯一的 watcher _GalleryContent 只存在于
    // data 且非空这一个分支（见下方 when）。loading / error / 空态三条路径下
    // 筛选态会被静默回收 → 用户的筛选在一次重试后凭空消失。
    // 这条 watch 把筛选器的存活性锚在 GalleryScreen 自身的生命周期上，
    // 顺带驱动工具条的"筛选生效中"指示。
    final filtersActive = ref.watch(
      galleryFilterProvider.select((GalleryFilter f) => f.isActive),
    );
```

并把 `filtersActive` 消费掉——工具条上渲染一个"筛选生效中 / 清除"的 chip（T9 会把它挪进 `InkToolBar`，本任务先就地放在 `_GalleryTopChrome` 里）。**必须真消费**，否则 `analyze` 报 unused 且 watch 会被后人当死代码删掉。

> 这同时把今天的死代码 `GalleryFilter.isActive`（`gallery_filter.dart:21-22`，lib 里零使用）用起来了。

- [ ] **Step 4: 跑测试确认全绿**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/features/gallery/ --exclude-tags golden
```

- [ ] **Step 5: 全量门禁 + 提交**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
git add lib/features/gallery/widgets/gallery_screen.dart test/features/gallery/gallery_filter_scope_test.dart lib/l10n/
git commit -m "fix(gallery): 筛选态不再因列表进入 loading/error/空态被静默回收"
```

> 若 chip 引入了新文案，本任务同样要加 ARB 两条 + `flutter gen-l10n` + 提交 `lib/l10n/generated/`。

---

### Task 4b: 画廊筛选按 projectId 分键 + 搜索框播种

**Files:**
- Modify: `lib/features/gallery/providers/gallery_filter.dart:61-64`
- Modify: `lib/features/gallery/widgets/gallery_screen.dart`（`_GalleryContentState` 的 `_searchCtrl`、`:157-159` 的失配回落、Step 3 的 watch 加实参）
- Test: `test/features/gallery/gallery_filter_scope_test.dart`（扩充）

**Interfaces:**
- Produces: `galleryFilterProvider(String projectId)`

**背景**：今天不可复现（退出画廊即卸载复位），保活恰好掀开盖子：项目 A 选画布筛选 → 切 Studio 开项目 B → 回画廊标签 → `filterGalleryItems` 拿 A 的 canvasId 比 B 的项，零命中 → 空结果；而三个筛选控件因为 `:157-159` 的失配回落**都显示"未筛选"**，界面在撒谎。

- [ ] **Step 1: 扩测试**

追加到 `gallery_filter_scope_test.dart`：

```dart
  test('筛选按 projectId 分键：A 的画布筛选不得清空 B 的网格', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subA = container.listen(galleryFilterProvider('pA'), (_, _) {}, fireImmediately: true);
    final subB = container.listen(galleryFilterProvider('pB'), (_, _) {}, fireImmediately: true);
    addTearDown(subA.close);
    addTearDown(subB.close);

    container.read(galleryFilterProvider('pA').notifier).state =
        const GalleryFilter(canvasId: 'canvas-in-A');

    expect(container.read(galleryFilterProvider('pA')).canvasId, 'canvas-in-A');
    expect(container.read(galleryFilterProvider('pB')).canvasId, isNull,
        reason: 'A 的 canvasId 比 B 的项必然零命中，而筛选控件会回落显示"未筛选"——界面撒谎');
  });
```

- [ ] **Step 2: 跑测试确认它编译红**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/features/gallery/gallery_filter_scope_test.dart
```
预期：编译失败（`galleryFilterProvider` 不可调用）。

- [ ] **Step 3: 改 family**

`gallery_filter.dart:61-64`：

```dart
/// 画廊筛选状态，按 projectId 分族——跨项目不共享，避免 A 的 canvasId 筛选
/// 静默清空 B 的网格（而三个筛选控件因失配回落全都显示"未筛选"）。
final galleryFilterProvider =
    StateProvider.autoDispose.family<GalleryFilter, String>(
      (ref, projectId) => const GalleryFilter(),
      name: 'galleryFilterProvider',
    );
```

`gallery_screen.dart` 里全部调用点补 `projectId` 实参（`analyze` 会给出完备清单），含 T4a 加的那条 watch。

- [ ] **Step 4: 搜索框从筛选态播种**

`_GalleryContentState.initState`：

```dart
  @override
  void initState() {
    super.initState();
    // _searchCtrl 是 onChanged 的唯一输入源，从不从 filter.query 读回；
    // 切项目 / error 重试 / data→空 三条路径都会重建 State 但不重建 filter，
    // 于是输入框显示空、筛选却仍然生效——界面与真相脱同步。
    final seeded = ref.read(galleryFilterProvider(widget.projectId)).query;
    _searchCtrl = TextEditingController(text: seeded)
      ..selection = TextSelection.collapsed(offset: seeded.length);
  }
```

并给 `_GalleryContent` 的构造加 `key: ValueKey(projectId)` 作保险（切项目时强制重建 State，避免播种只跑一次）。

- [ ] **Step 5: 跑测试确认全绿**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/features/gallery/ --exclude-tags golden
```
预期：`gallery_screen_test.dart` 的 6 个 pump 点**一行不改**仍然全绿（`GalleryScreen` 的两个必填构造参保留不动）。

- [ ] **Step 6: 全量门禁 + 提交**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
git add -A
git commit -m "fix(gallery): 筛选按 projectId 分键 + 搜索框从筛选态播种"
```

---

### Task 5: `ShellState` + `ShellNavigator`（纯新增，lib 里零引用）

**Files:**
- Create: `lib/features/shell/models/shell_state.dart`
- Create: `lib/features/shell/providers/shell_controller.dart`
- Test: `test/features/shell/shell_state_test.dart`、`shell_navigator_test.dart`、`shell_tab_order_test.dart`（均新建）

**Interfaces:**
- Produces: `enum ShellTab { studio, canvas, sequence, gallery, export }`
- Produces: `enum ShellOverlay { settings, showcase }`
- Produces: `class ProjectRef { const ProjectRef({required String id, required String name}); }`
- Produces: `class ShellState { const ShellState({ShellTab tab = ShellTab.studio, ShellOverlay? overlay, String? canvasId, ProjectRef? project}); bool isTabVisible(ShellTab t); bool get isPristine; }` + 7 个迁移
- Produces: `class ShellNavigator extends Notifier<ShellState> { ShellNavigator({ShellState initial = const ShellState()}); }`
- Produces: `final shellControllerProvider = NotifierProvider<ShellNavigator, ShellState>(...)`

**为什么单独一任务**：这是整个 PR 的类型地基，它的测试必须在任何 UI 接线之前就绿——否则后面每个 UI bug 都会被怀疑是状态机的锅。

- [ ] **Step 1: 写必红的测试（三个文件）**

`test/features/shell/shell_state_test.dart`：

```dart
// ShellState 的 7 个具名迁移 + 字段级相等性 + isPristine 真值表。
// 手写值对象、无 freezed：== / hashCode 漏一个字段的症状是静默丢导航，
// 没有任何现有测试会红，所以这里表驱动逐字段钉死。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';

void main() {
  const p1 = ProjectRef(id: 'p1', name: 'Alpha');
  const p2 = ProjectRef(id: 'p2', name: 'Beta');

  group('迁移语义', () {
    test('goTab 切标签即关浮层，保留 canvasId 与 project', () {
      const s = ShellState(
        tab: ShellTab.canvas, overlay: ShellOverlay.settings,
        canvasId: 'c1', project: p1);
      final n = s.goTab(ShellTab.gallery);
      expect(n.tab, ShellTab.gallery);
      expect(n.overlay, isNull);
      expect(n.canvasId, 'c1', reason: '切标签绝不可清 canvasId——那会当场毁掉画布保活');
      expect(n.project, p1);
    });

    test('openCanvas 落在 canvas 标签、写 canvasId、关浮层', () {
      const s = ShellState(tab: ShellTab.studio, overlay: ShellOverlay.settings, project: p1);
      final n = s.openCanvas('c9');
      expect(n.tab, ShellTab.canvas);
      expect(n.canvasId, 'c9');
      expect(n.overlay, isNull);
      expect(n.project, p1, reason: '不传 withProject 时保留原项目上下文');
    });

    test('openCanvas 带 withProject 时换项目上下文', () {
      const s = ShellState(project: p1);
      expect(s.openCanvas('c9', withProject: p2).project, p2);
    });

    test('openGallery 落在 gallery 标签、写 project、保留 canvasId', () {
      const s = ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: p1);
      final n = s.openGallery(p2);
      expect(n.tab, ShellTab.gallery);
      expect(n.project, p2);
      expect(n.canvasId, 'c1');
      expect(n.overlay, isNull);
    });

    test('setProject 只换上下文，不动标签与浮层', () {
      const s = ShellState(
        tab: ShellTab.canvas, overlay: ShellOverlay.showcase, canvasId: 'c1', project: p1);
      final n = s.setProject(p2);
      expect(n.tab, ShellTab.canvas);
      expect(n.overlay, ShellOverlay.showcase);
      expect(n.canvasId, 'c1');
      expect(n.project, p2);
    });

    test('openOverlay 只加浮层，其余全保留', () {
      const s = ShellState(tab: ShellTab.gallery, canvasId: 'c1', project: p1);
      final n = s.openOverlay(ShellOverlay.settings);
      expect(n.overlay, ShellOverlay.settings);
      expect(n.tab, ShellTab.gallery);
      expect(n.canvasId, 'c1');
      expect(n.project, p1);
    });

    test('closeOverlay 只清浮层，回到原标签', () {
      const s = ShellState(
        tab: ShellTab.gallery, overlay: ShellOverlay.settings, canvasId: 'c1', project: p1);
      final n = s.closeOverlay();
      expect(n.overlay, isNull);
      expect(n.tab, ShellTab.gallery);
      expect(n.canvasId, 'c1');
      expect(n.project, p1);
    });

    test('resetSession 四项归零（还原备份后：库换了）', () {
      const s = ShellState(
        tab: ShellTab.gallery, overlay: ShellOverlay.settings, canvasId: 'c1', project: p1);
      expect(s.resetSession(), const ShellState());
    });
  });

  group('派生判据', () {
    test('isTabVisible：浮层盖住时一律不可见', () {
      const s = ShellState(tab: ShellTab.canvas);
      expect(s.isTabVisible(ShellTab.canvas), isTrue);
      expect(s.isTabVisible(ShellTab.gallery), isFalse);
      expect(s.openOverlay(ShellOverlay.settings).isTabVisible(ShellTab.canvas), isFalse,
          reason: '一个谓词同时覆盖"切走标签"与"开浮层遮挡"两种不可见');
    });

    test('isPristine 真值表', () {
      expect(const ShellState().isPristine, isTrue);
      expect(const ShellState(canvasId: 'c1').isPristine, isFalse);
      expect(const ShellState(overlay: ShellOverlay.settings).isPristine, isFalse);
      expect(const ShellState(tab: ShellTab.gallery).isPristine, isFalse);
      // project 不参与：Studio 里选了项目但没导航，仍应恢复上次画布。
      expect(const ShellState(project: p1).isPristine, isTrue);
    });
  });

  group('字段级相等性（漏一个字段 = 静默丢导航）', () {
    const base = ShellState(
      tab: ShellTab.canvas, overlay: ShellOverlay.settings, canvasId: 'c1', project: p1);
    final variants = <String, ShellState>{
      'tab': ShellState(
        tab: ShellTab.gallery, overlay: base.overlay, canvasId: base.canvasId, project: base.project),
      'overlay': ShellState(
        tab: base.tab, overlay: ShellOverlay.showcase, canvasId: base.canvasId, project: base.project),
      'canvasId': ShellState(
        tab: base.tab, overlay: base.overlay, canvasId: 'c2', project: base.project),
      'project': ShellState(
        tab: base.tab, overlay: base.overlay, canvasId: base.canvasId, project: p2),
    };
    variants.forEach((field, other) {
      test('只差 $field 即不相等', () {
        expect(other, isNot(base));
        expect(other.hashCode, isNot(base.hashCode));
      });
    });
    test('全同即相等', () {
      expect(
        const ShellState(
          tab: ShellTab.canvas, overlay: ShellOverlay.settings, canvasId: 'c1', project: p1),
        base,
      );
    });
    test('ProjectRef 逐字段相等', () {
      expect(const ProjectRef(id: 'p1', name: 'Alpha'), p1);
      expect(const ProjectRef(id: 'p1', name: 'Other'), isNot(p1));
    });
  });
}
```

`test/features/shell/shell_navigator_test.dart`：

```dart
// ShellNavigator：地基合同 + 通知语义。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

void main() {
  const p1 = ProjectRef(id: 'p1', name: 'Alpha');

  ProviderContainer makeContainer([ShellState initial = const ShellState()]) {
    final c = ProviderContainer(overrides: <Override>[
      shellControllerProvider.overrideWith(() => ShellNavigator(initial: initial)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  // 这是整个 PR 的地基合同：写在第一条，任何违反它的改动都当场红。
  test('地基合同：切标签绝不改 canvasId', () {
    final c = makeContainer(const ShellState(tab: ShellTab.canvas, canvasId: 'c1'));
    c.read(shellControllerProvider.notifier).goTab(ShellTab.gallery);
    expect(c.read(shellControllerProvider).canvasId, 'c1');
  });

  test('幂等：连续两次同迁移只通知一次', () {
    final c = makeContainer();
    var notifications = 0;
    final sub = c.listen(shellControllerProvider, (_, _) => notifications++);
    addTearDown(sub.close);

    c.read(shellControllerProvider.notifier).goTab(ShellTab.gallery);
    c.read(shellControllerProvider.notifier).goTab(ShellTab.gallery);

    expect(notifications, 1, reason: '_set 的 if (next == state) return 与 updateShouldNotify 双保险');
  });

  test('updateShouldNotify 用值相等而非 identical', () {
    // riverpod-2.6.1/lib/src/notifier.dart:113-115 默认是 !identical(previous, next)，
    // 而外壳每次导航都构造新实例——不覆写就会在每次切标签时唤醒全体订阅者。
    final nav = ShellNavigator();
    const a = ShellState(tab: ShellTab.gallery);
    const b = ShellState(tab: ShellTab.gallery);
    expect(identical(a, b), isFalse);
    expect(nav.updateShouldNotify(a, b), isFalse);
    expect(nav.updateShouldNotify(a, const ShellState(tab: ShellTab.canvas)), isTrue);
  });

  test('select(canvasId) 在切标签时不通知', () {
    final c = makeContainer(const ShellState(tab: ShellTab.canvas, canvasId: 'c1'));
    var hits = 0;
    final sub = c.listen(
      shellControllerProvider.select((ShellState s) => s.canvasId), (_, _) => hits++);
    addTearDown(sub.close);

    c.read(shellControllerProvider.notifier).goTab(ShellTab.gallery);
    expect(hits, 0, reason: '画布子树不该因为用户瞥了一眼画廊就整棵重建');
  });

  test('openGallery / openOverlay / closeOverlay 委托语义与 ShellState 一致', () {
    final c = makeContainer(const ShellState(tab: ShellTab.canvas, canvasId: 'c1'));
    final nav = c.read(shellControllerProvider.notifier);
    nav.openGallery(p1);
    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
    expect(c.read(shellControllerProvider).canvasId, 'c1');
    nav.openOverlay(ShellOverlay.settings);
    expect(c.read(shellControllerProvider).overlay, ShellOverlay.settings);
    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
    nav.closeOverlay();
    expect(c.read(shellControllerProvider).overlay, isNull);
    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
  });
}
```

`test/features/shell/shell_tab_order_test.dart`：

```dart
// ShellTab 的声明序 == 标签条序 == IndexedStack children 序。
// index 与 children 顺序错位是最难查的一类 bug：界面显示 A 的内容、选中态标在 B 上。
// 任何人插入新标签，必须显式改这条断言。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';

void main() {
  test('ShellTab 顺序被钉死', () {
    expect(
      ShellTab.values.map((t) => t.name).toList(),
      <String>['studio', 'canvas', 'sequence', 'gallery', 'export'],
    );
  });
}
```

- [ ] **Step 2: 跑测试确认全编译红**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/features/shell/
```
预期：三个文件全部编译失败（目标文件不存在）。

- [ ] **Step 3: 实现 `shell_state.dart`**

```dart
// 外壳状态：唯一真相源。
//
// 手写不可变值对象（仓库禁新增 freezed，build_runner 工具链受阻，见 docs/BOARD.md），
// == / hashCode 手写，由 shell_state_test.dart 表驱动逐字段钉死。
//
// 【禁止补 copyWith】——补了就等于把 tab × overlay × canvasId × project 的
// 合法性还给人工纪律。本文件的全部意义在于：每个合法迁移都有名字，
// 于是 "tab: settings + canvasId: 'x'" 这类自相矛盾的态在类型层面无法构造。
//
// 【没有 closeCanvas()】——本 PR 不提供任何能清 canvasId 的公共动词
// （resetSession 除外）。老代码里那些"清 canvasId"写点的真实意图都是"回 Studio"，
// 正确替代是 goTab(studio)。这让"某处顺手清 canvasId 毁掉画布保活"
// 在类型层面不可达。真需要"关闭画布"菜单时，另加具名迁移 + 一条
// "调用后保活被销毁"的显式断言。
import 'package:flutter/foundation.dart';

/// 声明序 == 标签条渲染序 == 保活宿主 children 序。三者由
/// shell_tab_order_test.dart 钉死。
enum ShellTab { studio, canvas, sequence, gallery, export }

/// 浮层不是标签：它盖在标签宿主之上，关掉后回到原标签。
enum ShellOverlay { settings, showcase }

/// 项目引用。刻意用具名类而非记录 ({String id, String name})：
/// 记录是结构化类型，任何 (id, name) 对（画布引用、角色引用、备份条目）
/// 都能被静默传进项目上下文——正是本 PR 要消灭的那类隐式状态。
@immutable
class ProjectRef {
  const ProjectRef({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectRef && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'ProjectRef($id, $name)';
}

@immutable
class ShellState {
  const ShellState({
    this.tab = ShellTab.studio,
    this.overlay,
    this.canvasId,
    this.project,
  });

  /// 永不为 null；默认 studio（启动恢复守卫 isPristine 依赖这个默认值）。
  final ShellTab tab;

  /// null = 无浮层。
  final ShellOverlay? overlay;

  /// null 是合法态 = 画布标签显示"尚未打开画布"空态。
  final String? canvasId;

  /// 画廊 / 序列 / 导出共享的项目上下文。
  final ProjectRef? project;

  /// 某标签此刻是否可见。浮层盖住时一律不可见 ⇒ 画布让出焦点。
  /// V2 的两条用例（切走标签 / 开浮层遮挡）走同一条代码路径。
  bool isTabVisible(ShellTab t) => overlay == null && tab == t;

  bool get hasOverlay => overlay != null;

  /// 启动恢复守卫：用户尚未发生任何导航。
  /// tab 默认 studio，所以用户在 PG 启动窗口期内切到任何标签，本判据自然为假
  /// ——不需要额外的布尔闩。
  bool get isPristine =>
      canvasId == null && overlay == null && tab == ShellTab.studio;

  // ===== 7 个具名迁移：全量构造，不存在"忘了清某个字段" =====

  ShellState goTab(ShellTab next) =>
      ShellState(tab: next, canvasId: canvasId, project: project);

  ShellState openCanvas(String id, {ProjectRef? withProject}) => ShellState(
        tab: ShellTab.canvas,
        canvasId: id,
        project: withProject ?? project,
      );

  ShellState openGallery(ProjectRef p) =>
      ShellState(tab: ShellTab.gallery, canvasId: canvasId, project: p);

  ShellState setProject(ProjectRef p) => ShellState(
        tab: tab, overlay: overlay, canvasId: canvasId, project: p);

  ShellState openOverlay(ShellOverlay o) => ShellState(
        tab: tab, overlay: o, canvasId: canvasId, project: project);

  ShellState closeOverlay() =>
      ShellState(tab: tab, canvasId: canvasId, project: project);

  /// 还原备份后：库换了，全清。
  ShellState resetSession() => const ShellState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShellState &&
          other.tab == tab &&
          other.overlay == overlay &&
          other.canvasId == canvasId &&
          other.project == project;

  @override
  int get hashCode => Object.hash(tab, overlay, canvasId, project);

  @override
  String toString() =>
      'ShellState(tab: $tab, overlay: $overlay, canvasId: $canvasId, project: $project)';
}
```

- [ ] **Step 4: 实现 `shell_controller.dart`**

```dart
// ShellNavigator：外壳状态的唯一写入口。
//
// 【抽象接口的豁免】docs/CLAUDE.md 的 "Every injectable must have an abstract
// interface" 针对的是注入的【服务】（lib/core/interfaces/ 下 38 个文件）。
// ShellNavigator 是 Notifier<ShellState>——状态而非服务，仓库既有先例是
// CanvasSelectionController / CanvasViewportSize，均无接口。给 Notifier 套接口
// 还会让 overrideWith(() => ShellNavigator(initial: ...)) 这条最有用的测试
// 播种通道失效。此处显式记录豁免理由，不沉默跳过。
//
// 写权限天然被收口：ShellState 字段全 final，迁移全在本类内，外部只有
// read(shellControllerProvider.notifier).<七个方法之一>。因此不需要任何
// 正则质量测试来"禁止绕过"。
//
// 导航器不做 IO：偏好落盘（lastCanvasId / lastProjectId）留在 open_canvas.dart
// 原处（SRP：导航器只管内存态，可纯单测、零 mock）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gallery/providers/gallery_controller.dart';
import '../models/shell_state.dart';

class ShellNavigator extends Notifier<ShellState> {
  ShellNavigator({ShellState initial = const ShellState()}) : _initial = initial;

  final ShellState _initial;

  @override
  ShellState build() => _initial;

  /// riverpod-2.6.1/lib/src/notifier.dart:113-115 的默认实现是
  /// `!identical(previous, next)`。外壳每次导航都构造新 ShellState，
  /// 不覆写就会在每次切标签时唤醒全体订阅者。
  @override
  bool updateShouldNotify(ShellState previous, ShellState next) =>
      previous != next;

  /// 第二道腰带：值相等直接短路，连 state setter 都不进。
  void _set(ShellState next) {
    if (next == state) return;
    state = next;
  }

  void goTab(ShellTab t) => _set(state.goTab(t));
  void openCanvas(String id, {ProjectRef? withProject}) =>
      _set(state.openCanvas(id, withProject: withProject));
  void openGallery(ProjectRef p) => _set(state.openGallery(p));
  void setProject(ProjectRef p) => _set(state.setProject(p));
  void openOverlay(ShellOverlay o) => _set(state.openOverlay(o));
  void closeOverlay() => _set(state.closeOverlay());

  /// 还原备份后：四项归零，并让画廊整族失效——保活后画廊标签会捧着
  /// 还原前那个库的产物继续显示，且 project.id 可能在新库里已不存在。
  void resetSession() {
    _set(state.resetSession());
    ref.invalidate(galleryControllerProvider);
  }
}

final shellControllerProvider =
    NotifierProvider<ShellNavigator, ShellState>(
      ShellNavigator.new,
      name: 'shellControllerProvider',
    );
```

> `galleryControllerProvider` 是 family，传本体即整族失效。若它的真实路径与上面的 import 不符，以 `grep -rn "galleryControllerProvider" lib/` 为准。

- [ ] **Step 5: 跑测试确认全绿**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test test/features/shell/
```

- [ ] **Step 6: 门禁 + 提交**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
git add lib/features/shell/ test/features/shell/
git commit -m "feat(shell): ShellState 值对象 + ShellNavigator 唯一写入口（纯新增，未接线）"
```

---

### Task 6: 三个路由 provider 退役（唯一不可再分的原子 commit）

**Files:**
- Delete: `lib/core/di/current_screen.dart`、`lib/features/gallery/providers/current_gallery_project.dart`
- Create: `lib/features/shell/providers/active_project.dart`
- Modify: `lib/features/canvas/providers/current_canvas_id.dart`、`lib/app.dart:155-170`，以及 §File Structure 里列出的全部导航写点
- Modify: `lib/features/settings/widgets/backup_section.dart:199-204,264-279`
- Delete: `test/core/di/current_screen_test.dart`
- Create: `test/quality/shell_projection_override_test.dart`
- Modify: `test/app/app_routing_test.dart`（**只换 override 写法，5 条断言一字不改**）+ 10 处 `.notifier).state =` 的测试写点

**Interfaces:**
- Consumes: T5 的 `shellControllerProvider` / `ShellState` / `ShellNavigator` / `ProjectRef`
- Produces: `currentCanvasIdProvider`（`Provider<String?>`，路径与名字不变）、`activeProjectProvider`（`Provider<ProjectRef?>`）

**自证闸门**：这一步 `app.dart` 仍然只 build 一个 body，且**判序必须保持 canvasId-first**，渲染逐帧等价。`app_routing_test` 那 5 条**断言**一字不改——只换 override 写法。**若这一步需要改断言，说明改多了，回退。** V4 刻意留到 T7。

- [ ] **Step 1: 降级两个投影**

`lib/features/canvas/providers/current_canvas_id.dart` 整文件替换：

```dart
// 当前画布 id——ShellState.canvasId 的【派生只读投影】。
//
// 降级自 StateProvider：Provider 上不存在 .notifier.state，"谁都能偷改路由"
// 在类型层面消失。写入一律走 shellControllerProvider.notifier。
//
// 【外壳级测试禁止 override 本 provider】——override 投影会把它与真相源脱钩：
// widget 读投影看到 'c1'，任何读 shellControllerProvider 的代码看到 null。
// 外壳级测试一律用：
//   shellControllerProvider.overrideWith(() => ShellNavigator(initial: ShellState(...)))
// 纯画布组件测试不受此限（那正是保留本 provider 名字与路径的价值）。
// 由 test/quality/shell_projection_override_test.dart 强制。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';

final currentCanvasIdProvider = Provider<String?>(
  (ref) => ref.watch(shellControllerProvider.select((ShellState s) => s.canvasId)),
  name: 'currentCanvasIdProvider',
);
```

`lib/features/shell/providers/active_project.dart`（新建，头注同样写明禁止 override）：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shell_state.dart';
import 'shell_controller.dart';

final activeProjectProvider = Provider<ProjectRef?>(
  (ref) => ref.watch(shellControllerProvider.select((ShellState s) => s.project)),
  name: 'activeProjectProvider',
);
```

- [ ] **Step 2: 删两个文件，用 analyze 拿完备清单**

```bash
rm lib/core/di/current_screen.dart lib/features/gallery/providers/current_gallery_project.dart
rm test/core/di/current_screen_test.dart
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
```
所有引用点编译红 = 完备 checklist。

- [ ] **Step 3: 逐点替换 lib 侧写点**

| 位置 | 替换为 |
|---|---|
| `open_canvas.dart:24` | `nav.openCanvas(canvasId, withProject: ProjectRef(id: p.id, name: p.name))`（prefs 写入 `:27-29` **不动**） |
| `canvas_bootstrap_controller.dart:52` | `nav.openCanvas(newCanvasId, withProject: ProjectRef(...))` ——**极易漏**：该文件被 `canvas_view.dart:188` / `studio_home_screen.dart:271` / `onboarding_dialog.dart:54` 三处调用，漏了它 ON-2 首启建示例会"写了 canvasId 但标签停在 studio" |
| `canvas_top_chrome.dart:37-45` | 暂不动（T7 整文件删） |
| `command_actions.dart:154-162` `_backToStudio` | `nav.goTab(ShellTab.studio)`，**不清 canvasId**，删 `clearLastCanvas` 直写 |
| `command_actions.dart:171` `_openShowcase` | `nav.openOverlay(ShellOverlay.showcase)` |
| `command_actions.dart:180-182` `_openSettings` | `nav.openOverlay(ShellOverlay.settings)`（**三行清场就此消失**） |
| `command_actions.dart:52/92/95-100` | 上下文判据读 `ShellState`（exhaustive switch on `tab` + `overlay`） |
| `gallery_screen.dart:74` 返回键 | 删除（标签模型下"返回"不存在） |
| `built_in_showcase_screen.dart:35` | `nav.closeOverlay()` |
| `settings_screen.dart:83` | `nav.closeOverlay()` |
| `studio_home_screen.dart:57-59` | 暂留（T7 删 `StudioTopChrome`），`onOpenSettings` 先改 `nav.openOverlay(ShellOverlay.settings)` |
| `studio_home_screen.dart:126` / `:655` | `nav.openOverlay(ShellOverlay.showcase)` |
| `studio_home_screen.dart:651-653` 项目卡 Gallery | `nav.openGallery(ProjectRef(id: ..., name: ...))` |
| `library_sidebar.dart:267` / `studio_provider_banner.dart:55` | `nav.openOverlay(ShellOverlay.settings)` |
| `restore_last_session.dart:42-46` | 暂时改成 `if (!ref.read(shellControllerProvider).isPristine) return;` + `nav.openCanvas(canvasId, withProject: ProjectRef(id: projectId, name: projectRow['name'] as String))`（开关判据在 T11 加） |

- [ ] **Step 4: `backup_section.dart` 三处**

`:199-204`（第一个 await 前）：三个 notifier 预捕获 → 一个
```dart
final nav = ref.read(shellControllerProvider.notifier);
```
`:277-279` 三行清场 → `nav.resetSession();`

`:264-274` 的兜底 pop 加守卫：
```dart
    } else if (navigator.canPop()) {
      navigator.pop();
    }
```
> 走 else 分支恰恰是 barrier **没进栈**的情况，此时 root 栈里只有 `MaterialApp` 的 home 路由，裸 `pop()` 会去弹它。

- [ ] **Step 5: `app.dart` 改读 `ShellState`，但仍只 build 一个 body**

`_UnlockedShellState.build` 替换 `:155-171`：

```dart
  @override
  Widget build(BuildContext context) {
    // T6 过渡态：状态层已换成 ShellState，但渲染仍是单 body 的 if 链，
    // 且【判序保持 canvasId-first】——与今天逐帧等价，
    // 于是 app_routing_test 的 5 条断言一字不改即可通过。
    // 外壳骨架（两级 IndexedStack + 标签条）在 T7 接上。
    final s = ref.watch(shellControllerProvider);
    final Widget body;
    if (s.canvasId != null) {
      body = const CanvasScreen(isVisible: true);
    } else if (s.tab == ShellTab.gallery && s.project != null) {
      body = Scaffold(
        body: GalleryScreen(projectId: s.project!.id, projectName: s.project!.name),
      );
    } else if (s.overlay == ShellOverlay.settings) {
      body = const SettingsScreen();
    } else if (s.overlay == ShellOverlay.showcase) {
      body = const Scaffold(body: BuiltInShowcaseScreen());
    } else {
      body = const Scaffold(body: StudioHomeScreen());
    }
    return CommandPaletteShortcuts(child: body);
  }
```

> **不要**改成 overlay-first 的 exhaustive switch：那会反转今天的 canvasId 优先级，`app_routing_test` 第 5 例（`canvasId='cv-1'` + showcase 断 `findsNothing`）必红，把自证闸门变成噪声。

- [ ] **Step 6: 改测试的 override 写法（断言不动）**

`app_routing_test.dart` 五例，把三个旧 provider 的 override 换成一条：

```dart
// 第 1 例（studio）
shellControllerProvider.overrideWith(() => ShellNavigator(initial: const ShellState())),

// 第 2 例（settings）
shellControllerProvider.overrideWith(
  () => ShellNavigator(initial: const ShellState(overlay: ShellOverlay.settings))),

// 第 3 例（gallery）
shellControllerProvider.overrideWith(() => ShellNavigator(
  initial: const ShellState(
    tab: ShellTab.gallery, project: ProjectRef(id: 'p1', name: 'Alpha')))),

// 第 4 例（showcase）
shellControllerProvider.overrideWith(
  () => ShellNavigator(initial: const ShellState(overlay: ShellOverlay.showcase))),

// 第 5 例（canvasId 优先级）
shellControllerProvider.overrideWith(() => ShellNavigator(
  initial: const ShellState(overlay: ShellOverlay.showcase, canvasId: 'cv-1'))),
```

删掉 `currentScreenProvider` / `currentCanvasIdProvider` / `currentGalleryProjectProvider` 三条 override 与对应 import。**`expect` 行一个字都不改。**

其余 10 处 `.notifier).state =` 的测试写点同法改为 `shellControllerProvider.overrideWith(...)` 或 `read(shellControllerProvider.notifier).<迁移>`：`current_canvas_name_test.dart:17`、`canvas_shortcuts_test.dart:299`、`canvas_top_chrome_test.dart:54`、`command_palette_test.dart:149/166/179/198/217`、`backup_section_test.dart:232`、`restore_last_session_test.dart:125`。

`command_palette_test.dart:212-226` 改断"`tab == ShellTab.studio` 且 **canvasId 保持不变**"；`backup_section_test.dart:227-249` 改断 `resetSession` 四项归零。

- [ ] **Step 7: 新增质量测试**

`test/quality/shell_projection_override_test.dart`：

```dart
// 外壳级测试禁止 override 只读投影——override 投影会把它与真相源脱钩：
// widget 读投影看到 'c1'，任何读 shellControllerProvider 的代码看到 null。
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const _banned = <String>[
  'currentCanvasIdProvider.overrideWith',
  'activeProjectProvider.overrideWith',
];

void main() {
  test('外壳级测试不得 override ShellState 的只读投影', () {
    final files = <File>[
      ...Directory('test/features/shell')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
      File('test/app/app_routing_test.dart'),
    ];
    final offenders = <String>[];
    for (final f in files) {
      if (!f.existsSync()) continue;
      final src = f.readAsStringSync();
      for (final b in _banned) {
        if (src.contains(b)) offenders.add('${f.path}: $b');
      }
    }
    expect(offenders, isEmpty,
        reason: '请改用 shellControllerProvider.overrideWith(() => '
            'ShellNavigator(initial: ShellState(...))) 播种。\n违规：$offenders');
  });
}
```

- [ ] **Step 8: 跑门禁 + 收口判据**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
git grep -n "AppScreen\|currentScreenProvider\|currentGalleryProjectProvider"
```
最后一条**必须零命中**。约 11 个只写 `overrideWith((_) => 'c1')` 的画布测试文件应当**一行未改**——若你改了它们，说明走偏了。

- [ ] **Step 9: 提交**

```bash
git add -A
git commit -m "refactor(shell): 三个路由 provider 退役，全部导航收口到 ShellNavigator

app.dart 仍是单 body 的 if 链且保持 canvasId-first 判序，渲染逐帧等价——
app_routing_test 的 5 条断言一字未改，只换 override 写法。外壳骨架在下一步。"
```

---

### Task 7: 外壳骨架（V3/V4 主战场，最大的一步）

**Files:**
- Create: `lib/features/shell/widgets/` 下 9 个文件 + `tabs/` 下 5 个
- Create: `lib/theme/components/ink_shell_tab_bar.dart`、`ink_tool_bar.dart`
- Modify: `lib/app.dart`（body → `const InkShell()`）
- Delete: `lib/features/canvas/widgets/canvas_top_chrome.dart`、`lib/features/studio/widgets/studio_top_chrome.dart`
- Modify: `gallery_screen.dart:60-84`（删 `_GalleryTopChrome`）、`built_in_showcase_screen.dart:31`、`settings_screen.dart`（AppBar → InkToolBar）、`studio_home_screen.dart:53-59`
- Create: `test/_harness/shell_app.dart`、`test/_harness/shell_expect.dart`
- Modify: `test/app/app_routing_test.dart`（**这一步才动断言**）
- Create: `test/features/shell/shell_window_chrome_test.dart`
- Delete: `test/features/studio/widgets/studio_top_chrome_test.dart`、`test/features/canvas/widgets/canvas_top_chrome_test.dart`
- Modify: `test/features/studio/studio_home_test.dart`、`canvas_top_chrome_base_style_test.dart`
- Move: `canvas_top_chrome_export_test.dart` / `_sequence_test.dart` 的用例 → `test/features/shell/shell_tabs_empty_state_test.dart`

**Interfaces:**
- Consumes: T5 的 `ShellState` / `shellControllerProvider`；T3 的 `surface5` / `borderStrong`；T1 的 `CanvasScreen({required bool isVisible})`
- Produces: `InkShell()`、`ShellKeepAliveHost({required ShellTab activeTab, required Widget Function(BuildContext, ShellTab) buildTab})`、`InkShellTabBar.height = 44`、`InkToolBar.height = 44`、`pumpInkShell(...)`、`expectShellSurface(...)`

- [ ] **Step 1: 先建靶——写 harness**

`test/_harness/shell_app.dart`：

```dart
// 外壳级 widget test 启动器。
//
// 两条硬纪律：
// 1. orphanReapStartupProvider 必须与 pgMigratedPoolProvider【分开单独 override】
//    ——前者直接 await nodeRepositoryProvider，不吃 pool 封印
//    （app_routing_test.dart:155-157 的注释已经踩过这个坑）。
// 2. 全外壳测试【禁止 pumpAndSettle】，只固定次数 pump()
//    ——StoragePathSection 留 pending frame（app_routing_test.dart:136-137 是现成先例）。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
// … 其余 import 照 app_routing_test.dart 现有清单搬

/// 封住一切会去起真内嵌 PostgreSQL 的链路。任何新增的 eager 仓储读都要加进来，
/// 否则测试会挂到 isolate 超时、覆盖率收集永挂。
List<Override> sealedShellOverrides({required AppPaths paths}) => <Override>[
      appPathsProvider.overrideWithValue(paths),
      preferencesServiceProvider.overrideWithValue(
        InMemoryPreferencesService(const AppPreferences(onboardingCompleted: true))),
      anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
      orphanReapStartupProvider.overrideWith((_) async {}),
      pgMigratedPoolProvider.overrideWith((ref) => Completer<Pool<void>>().future),
      workspaceProjectsProvider.overrideWith((_) async => const <ProjectWithCanvases>[]),
      canvasRepositoryProvider.overrideWith((_) async => InMemoryCanvasRepository()),
      nodeRepositoryProvider.overrideWith((_) async => InMemoryNodeRepository()),
      batchResultRepositoryProvider.overrideWith((_) async => FakeBatchResultRepo()),
      ffmpegLocatorProvider.overrideWithValue(FakeFfmpegLocator()),
      customProviderStoreProvider.overrideWithValue(const EmptyCustomProviderStore()),
    ];

/// 用 ShellState 播种整个外壳。**不要** override currentCanvasIdProvider /
/// activeProjectProvider（见 test/quality/shell_projection_override_test.dart）。
Future<void> pumpInkShell(
  WidgetTester tester, {
  ShellState initial = const ShellState(),
  required AppPaths paths,
  List<Override> extraOverrides = const <Override>[],
  Size surfaceSize = const Size(1440, 900),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...sealedShellOverrides(paths: paths),
        shellControllerProvider.overrideWith(() => ShellNavigator(initial: initial)),
        ...extraOverrides,
      ],
      child: const InkFrameApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// 点某个标签。标签条在 DragToMoveArea 之外，所以【不需要】400ms 的
/// kDoubleTapTimeout workaround——一帧落地。
/// 若你发现这里必须加 pump(400ms) 才稳，说明标签条被挪进 chrome 了，回退。
Future<void> tapShellTab(WidgetTester tester, ShellTab tab) async {
  await tester.tap(find.byKey(ValueKey<String>('shellTab-${tab.name}')));
  await tester.pump();
  await tester.pump();
}

/// 临时 AppPaths（每个用例独立目录，自动清理）。
/// 照搬 app_routing_test.dart:43-49 的 _setupPaths，提到 harness 供外壳测试共用。
Future<AppPaths> setupTempPaths(WidgetTester tester, String prefix) async {
  final Directory tmp = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() => tmp.deleteSync(recursive: true));
  final AppPaths paths = DefaultAppPaths.forRoot(tmp);
  await tester.runAsync(() => paths.ensureInitialized());
  return paths;
}

/// 拿到外壳所在的 ProviderContainer，用来在测试里直接驱动 / 读回 provider。
ProviderContainer readShellContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(InkShell)));
```

`test/_harness/shell_expect.dart`：

```dart
// V4 的断言工具：三条【正交】通道，任何一条单独用都会假绿。
//
// 通道 1（在树里吗）：find.byType(T, skipOffstage: false) —— 保活的证据
// 通道 2（在台上吗）：find.byType(T)（默认 skipOffstage: true）—— 激活的证据
// 通道 3（可命中吗）：find.byType(T).hitTestable() —— 没被浮层盖住的证据
import 'package:flutter_test/flutter_test.dart';

/// 断言某个 surface 的三通道状态。
///
/// 刻意【接受类型参数而非 Finder】：三条通道各自需要一个不同参数的
/// find.byType，在内部构造才能保证 skipOffstage 两种取值都真实用上。
/// 传一个 Finder 进来再 .first / .hitTestable() 是做不到的——Finder 的
/// skipOffstage 在构造时就固定了。
///
/// - [mounted]: 是否在 widget 树里（保活 / 懒物化的证据）
/// - [onstage]: 是否在台上（当前激活标签的证据）
/// - [hittable]: 是否可命中（没被浮层盖住的证据）
void expectShellSurface<T extends Widget>({
  required bool mounted,
  required bool onstage,
  required bool hittable,
  String? reason,
}) {
  final String tag = reason == null ? '$T' : '$T · $reason';

  // 通道 1：在树里吗。V4 的核心——必须显式 skipOffstage: false，
  // 否则保活会让 findsNothing 恒真、断言永远绿着却什么都不测。
  expect(
    find.byType(T, skipOffstage: false),
    mounted ? findsOneWidget : findsNothing,
    reason: '$tag [在树通道 · skipOffstage:false]',
  );

  // 通道 2：在台上吗。默认 skipOffstage: true，跳过 Offstage 子树。
  expect(
    find.byType(T),
    onstage ? findsOneWidget : findsNothing,
    reason: '$tag [在台通道 · 默认 skipOffstage:true]',
  );

  // 通道 3：可命中吗。浮层盖住时 RenderIndexedStack.hitTestChildren
  // （rendering/stack.dart:846-861）只命中 index 子，底下的标签体必然落空。
  expect(
    find.byType(T, skipOffstage: false).hitTestable(),
    hittable ? findsOneWidget : findsNothing,
    reason: '$tag [可命中通道]',
  );
}
```

用法：

```dart
expectShellSurface<StudioHomeScreen>(
  mounted: true, onstage: false, hittable: false,
  reason: '切去画廊后 Studio 必须保活但离台');
expectShellSurface<SettingsScreen>(
  mounted: false, onstage: false, hittable: false,
  reason: '从未打开过设置，浮层槽应是 SizedBox.shrink');
```

- [ ] **Step 2: 用 `expectShellSurface` 重写 `app_routing_test.dart` 五例（此时全红）**

五例映射：

| 旧断言 | 新断言 |
|---|---|
| studio 例：`StudioHomeScreen` 有 / `SettingsScreen` 无 | Studio 体：mounted/onstage/hittable 全 true；`SettingsScreen`：三者全 false（**从未打开过设置，浮层槽是 SizedBox.shrink**） |
| settings 例 | `SettingsScreen`：全 true；Studio 体：mounted **true**（已物化）、onstage **false**、hittable **false** |
| gallery 例 | `GalleryScreen`：全 true；Studio 体：mounted true / onstage false / hittable false |
| showcase 例 | `BuiltInShowcaseScreen`：全 true；Studio 体：mounted true / onstage false |
| 第 5 例（canvasId + showcase） | `BuiltInShowcaseScreen`：全 true；`CanvasScreen`：mounted **true**（保活）、onstage **false**、hittable **false** |

> 第 5 例的语义在标签模型下变了：不再是"画布赢"，而是"浮层永远在上、画布保活在下"。这是**正确的变更**，此处才允许改断言（T6 不允许）。

新增 `shell_window_chrome_test.dart`：

```dart
  testWidgets('V3a：全树恰好一个 InkWindowChrome', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_chrome_');
    await pumpInkShell(tester, paths: paths,
        initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1'));
    await tapShellTab(tester, ShellTab.studio);   // 让 Studio 也物化
    expect(find.byType(InkWindowChrome, skipOffstage: false), findsOneWidget,
        reason: '两个标签都物化后仍只能有一个窗口 chrome——否则重复的最小化/关闭按钮');
  });

  testWidgets('V3b：两个标签都物化时，一条 toast 只渲染一份', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_toast_');
    await pumpInkShell(tester, paths: paths,
        initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1'));
    await tapShellTab(tester, ShellTab.studio);   // Studio 与 Canvas 同时在树里

    ToastService.show(/* 按 toast_service.dart 的实际签名 */);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SnackBar, skipOffstage: false), findsOneWidget,
        reason: 'ScaffoldMessenger 对每个 root Scaffold 都推一份；'
            '外壳根 Scaffold 让画布/Studio 自带的 Scaffold 变 nested 而被排除');
  });
```

跑一次，确认**全红**（`InkShell` 不存在）。

- [ ] **Step 3: 实现保活宿主**

`lib/features/shell/widgets/shell_keep_alive_host.dart`：

```dart
// 保活宿主：五个标签槽，懒物化、物化后常驻。
//
// 两条不变量，缺一 V4 就塌：
// 1. Key 落在【槽位】上——五个 shellTabBody-* 恒在树里，无论是否物化。
//    保活断言因此锚在稳定 Key 上，不会因"画廊未选项目所以 GalleryScreen 不 mount"而假红。
//    守护它的是 test/features/shell/shell_keepalive_test.dart。
// 2. 内容懒物化、物化后【永不换回占位】——于是
//    find.byType(GalleryScreen, skipOffstage: false) 在从未访问过画廊的用例里
//    真的 findsNothing。这是 V4 成立的唯一物理前提。
//    守护它的是 test/app/app_routing_test.dart。
import 'package:flutter/material.dart';

import '../models/shell_state.dart';

class ShellKeepAliveHost extends StatefulWidget {
  const ShellKeepAliveHost({
    super.key,
    required this.activeTab,
    required this.buildTab,
  });

  final ShellTab activeTab;

  /// 惰性构造器，每帧重新调用（不缓存 Widget 实例）——isActive / isVisible
  /// 靠这条路径逐帧下传。
  ///
  /// 用函数 + exhaustive switch，不用 Map<ShellTab, WidgetBuilder>：
  /// 加第六个标签时编译器在 switch 上报错，Map 版本是 builders[t]! 的运行时崩溃。
  final Widget Function(BuildContext, ShellTab) buildTab;

  @override
  State<ShellKeepAliveHost> createState() => _ShellKeepAliveHostState();
}

class _ShellKeepAliveHostState extends State<ShellKeepAliveHost> {
  final Set<ShellTab> _materialized = <ShellTab>{};

  @override
  void initState() {
    super.initState();
    _materialized.add(widget.activeTab);
  }

  @override
  void didUpdateWidget(ShellKeepAliveHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _materialized.add(widget.activeTab);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: ShellTab.values.indexOf(widget.activeTab),
      // 必需：默认 StackFit.loose 会让画布/画廊 shrink-wrap，Column+Expanded 直接错位。
      sizing: StackFit.expand,
      children: <Widget>[
        for (final ShellTab t in ShellTab.values)
          KeyedSubtree(
            key: ValueKey<String>('shellTabBody-${t.name}'),
            child: _materialized.contains(t)
                ? widget.buildTab(context, t)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: 实现 `ShellContentStack`（两级 IndexedStack + 兜底焦点）**

```dart
class _ShellContentStackState extends State<ShellContentStack> {
  final FocusNode _shellFocus = FocusNode(debugLabel: 'ShellContentStack');

  @override
  void dispose() {
    _shellFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ShellContentStack old) {
    super.didUpdateWidget(old);
    if (widget.tab == old.tab && widget.overlay == old.overlay) return;
    // 【无条件】—— 千万别加 if (!_shellFocus.hasFocus) 守卫：
    // 切换那一帧画布的 FocusNode 还没被 unfocus，hasFocus 仍为 true → 守卫跳过请求
    // → 随后焦点掉到 ModalScope 的 FocusScope（它在 CommandPaletteShortcuts 之【上】）
    // → 全 app 的 ⌘K 直接失效。
    //
    // 顺序安全性来自【注册时机】：本回调在祖先重建时先注册（早），
    // CanvasShortcuts 的 _claimFocus 在后代 build 期间注册（晚），
    // post-frame 队列 FIFO ⇒ 晚的赢 ⇒ 切回画布页时画布稳拿焦点。
    // 这条是 load-bearing，改动前先读 shell_focus_test.dart。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shellFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _shellFocus,
      skipTraversal: true,
      child: IndexedStack(
        index: widget.overlay == null ? 0 : 1,
        sizing: StackFit.expand,
        children: <Widget>[
          ShellKeepAliveHost(activeTab: widget.tab, buildTab: _buildTab),
          // 浮层不保活：关掉即销毁，于是
          // find.byKey('shellOverlay-settings', skipOffstage: false) → findsNothing
          // 是真断言，StoragePathSection 的 pending frame 不会在后台常驻。
          widget.overlay == null
              ? const SizedBox.shrink()
              : ShellOverlayLayer(
                  key: ValueKey<String>('shellOverlay-${widget.overlay!.name}'),
                  overlay: widget.overlay!,
                ),
        ],
      ),
    );
  }

  /// 与 ShellState.isTabVisible 同义，只是这里手上只有 tab + overlay 两个字段。
  /// 【必须包含 overlay == null 这一项】——一个谓词同时覆盖"切走标签"与
  /// "开浮层遮挡"两种不可见，V2 的两条用例才会走同一条代码路径而非两套特判。
  bool _isVisible(ShellTab t) => widget.overlay == null && widget.tab == t;

  Widget _buildTab(BuildContext context, ShellTab tab) => switch (tab) {
        ShellTab.studio => const StudioTab(),
        ShellTab.canvas => CanvasTab(isVisible: _isVisible(ShellTab.canvas)),
        ShellTab.sequence => const SequenceTab(),
        ShellTab.gallery => GalleryTab(isVisible: _isVisible(ShellTab.gallery)),
        ShellTab.export => const ExportTab(),
      };
}
```

> `ShellContentStack` 的构造是 `const ShellContentStack({super.key, required this.tab, required this.overlay});`
> ——刻意只收这两个字段而不是整个 `ShellState`：`canvasId` / `project` 的变化不该
> 触发 `didUpdateWidget` 里的焦点重夺（换画布时焦点本就在画布上，重夺是多余的抖动）。

- [ ] **Step 5: 实现 `InkShell`（唯一根 Scaffold + 唯一 chrome + 标签条）**

```dart
class InkShell extends ConsumerWidget {
  const InkShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShellState s = ref.watch(shellControllerProvider);
    return Scaffold(
      // 外壳唯一的【根】Scaffold。画布与设置自带的 Scaffold 保留不动——
      // 它们因为有了 Scaffold 祖先而变成 nested，_isRoot（material/scaffold.dart:240-245）
      // 返回 false，被自动排除出 SnackBar 广播。
      // 不加这一层的后果：两个已物化标签各自是 root Scaffold → 一条 toast 渲染两份；
      // 而序列/导出标签（无 Scaffold）激活时 toast 全画在离台子树里，用户看不见。
      backgroundColor: context.inkColors.surfaceCanvas,
      body: Column(
        children: <Widget>[
          const ShellChrome(),        // 56：全树唯一 InkWindowChrome
          const InkShellTabBar(),     // 44：在 DragToMoveArea 之外
          Expanded(
            child: ShellContentStack(tab: s.tab, overlay: s.overlay),
          ),
        ],
      ),
    );
  }
}
```

`app.dart` 的 `_UnlockedShellState.build` 塌成：

```dart
  @override
  Widget build(BuildContext context) =>
      const CommandPaletteShortcuts(child: InkShell());
```

- [ ] **Step 6: 实现 `InkShellTabBar`（落 `lib/theme/components/`）**

要点（详细样式见 spec §7.2）：
- `static const double height = 44;`，chip 高 32 垂直居中
- 选中：`colors.fg1` + `FontWeight.w500` + 2px `colors.accent` 下边框 + `colors.surface5` 底
- 未选中：`colors.fg3`，hover `colors.surface4`
- 每个 chip `key: ValueKey<String>('shellTab-${tab.name}')`
- `for (final t in ShellTab.values)` 遍历，顺序由 `shell_tab_order_test.dart` 钉死
- 下沿 1px `colors.borderStrong`
- 窄屏退化：用 `LayoutBuilder` 的**实际约束**（非 `MediaQuery.size`，这样 textScale 放大也会先触发）。**阈值按五组标签在 en / zh 下实测渲染宽度定，不要照抄任何数字**：先用一个临时大阈值跑 `tester.takeException()` 与溢出检查，量出五个 chip 的自然宽度之和，取"和 + 左右 gutter"为阈值。退化时 chip 收成纯图标 + `Tooltip`，**选中项必须同时给 `surface5` 底**——纯图标条上只靠琥珀下边框太弱。
- 必测：`setSurfaceSize(Size(960, 600))` + `textScale: 1.3` 下 `tester.takeException()` 为 null

- [ ] **Step 7: 剥四处 chrome + 设置换工具条**

```bash
git rm lib/features/canvas/widgets/canvas_top_chrome.dart
git rm lib/features/studio/widgets/studio_top_chrome.dart
git rm test/features/studio/widgets/studio_top_chrome_test.dart
git rm test/features/canvas/widgets/canvas_top_chrome_test.dart
```
- `studio_home_screen.dart:53-59`：删掉 `Column` 的第一件 `StudioTopChrome`
- `gallery_screen.dart:60-84`：删 `_GalleryTopChrome`，换 `InkToolBar`
- `built_in_showcase_screen.dart:31`：删 chrome
- `settings_screen.dart`：`AppBar`(56) → `InkToolBar`(44)；`SettingsBackButton` **保留 widget 名与 key**（`settings_screen_test.dart:14-29` 靠它），只把行为改成 `nav.closeOverlay()`
- `CanvasShortcuts.isActive` 从 T1 的常量 `true` 换成 `state.isTabVisible(ShellTab.canvas)`（**必须同 commit 接上，否则分支上活着一个吞键漏洞**）
- `studio_home_test.dart` / `canvas_top_chrome_base_style_test.dart` 改指
- `canvas_top_chrome_export_test.dart` / `_sequence_test.dart` 的用例**先搬**进 `shell_tabs_empty_state_test.dart` 跑绿再删原文件（T10 补齐真身）

gallery/sequence/export 三个标签体本步先放最小占位壳（槽位 Key + 空态），真身在 T9/T10。

**画布空态本步就要做实**（spec §8.1 / D12）：`canvasId == null` 时 `CanvasTab` 渲染
`ShellEmptyState(title: shellCanvasEmptyTitle, body: shellCanvasEmptyBody, cta: shellGoToStudio → nav.goTab(ShellTab.studio))`。
文案是**可行动的引导**而非错误态——本 PR 不提供"关闭当前画布"，用户不能觉得卡死。
注意这个空态在今天的生产代码里**根本不可达**（`app.dart` 从不以 null canvasId 构建
`CanvasScreen`），本步让它第一次真正可达，所以要亲自跑一次看它长什么样。

**`app_toast_messenger_test.dart:69` 是哨兵，不许放宽**：它用
`tester.widget<MaterialApp>(find.byType(MaterialApp))`（隐含 findsOneWidget）
假定全树唯一 MaterialApp。本设计不新增任何 MaterialApp（浮层是 widget 层不是路由），
它应当继续绿。**若它红了，说明有人把设置做成了嵌套 MaterialApp 或 root 路由——
去修实现，不要动这个测试。**

- [ ] **Step 8: ARB +10 / −5**

新增：`shellTabStudio` / `shellTabCanvas` / `shellTabSequence` / `shellTabGallery` / `shellTabExport` / `shellBreadcrumbNoProject` / `shellCloseOverlay` / `shellGoToStudio` / `shellCanvasEmptyTitle` / `shellCanvasEmptyBody`（en/zh 取值见 spec §11）。
退役：`studioBreadcrumbAll` / `canvasBreadcrumbProject` / `canvasBreadcrumbCanvas` / `canvasBackToStudio`(+@) / `showcaseBackTooltip`。

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat gen-l10n
```
把 `lib/l10n/generated/` 一起提交。`docs/CLAUDE.md` 的 Project Structure 加 `features/shell/`。

- [ ] **Step 9: 跑测试确认全绿**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
```

- [ ] **Step 10: 变异验证（逐条跑红再改回）**

| 变异 | 必红的断言 |
|---|---|
| 宿主 eager 建五子（`_materialized` 初始装 `ShellTab.values`） | V4：从未访问过的标签体应 `findsNothing` |
| 内层 `IndexedStack` 换 `Stack` | V4 / 点穿 |
| `ShellTab.values` 顺序调乱 | `shell_tab_order_test.dart` |
| 切标签时把非活动槽换回 `SizedBox.shrink()` | V1 |
| 把 `InkWindowChrome` 加回画布子树 | **V3a** |
| 去掉 `InkShell` 的根 `Scaffold` | **V3b** |
| `_shellFocus` 加 `hasFocus` 守卫 | V2 的 ⌘K 一例 |

**外加一条反向变异**：把 V4 的"在树通道"断言改回默认 `skipOffstage`（即 true），**确认它不红**——以此证明 `skipOffstage: false` 是 load-bearing 的。只做正向变异回答不了"这个断言是否真的在测东西"。

- [ ] **Step 11: 提交**

```bash
git add -A
git commit -m "feat(shell): 持久标签外壳骨架——两级 IndexedStack 保活 + 唯一 chrome + 设置降为浮层"
```

---

### Task 8: V1 + V2 端到端（测试为主）

**Files:**
- Create: `test/features/shell/shell_keepalive_test.dart`、`shell_focus_test.dart`

**Interfaces:**
- Consumes: T7 的 `pumpInkShell` / `tapShellTab` / `expectShellSurface`

- [ ] **Step 1: 写 V1 测试**

```dart
  testWidgets('V1：画布切到画廊再切回，视口变换矩阵逐元素不变', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_keepalive_');
    await pumpInkShell(tester, paths: paths,
        initial: const ShellState(
          tab: ShellTab.canvas, canvasId: 'c1',
          project: ProjectRef(id: 'p1', name: 'Alpha')));

    // 缩放画布，制造一个不等于初始相机的变换。
    await sendCtrl(tester, LogicalKeyboardKey.equal);
    final Matrix4 before = ivTransform(tester);
    expect(before, isNot(initialCanvasTransform()));

    await tapShellTab(tester, ShellTab.gallery);
    await tapShellTab(tester, ShellTab.canvas);

    final Matrix4 after = ivTransform(tester);
    for (int i = 0; i < 16; i++) {
      expect(after.storage[i], closeTo(before.storage[i], 1e-9),
          reason: '矩阵第 $i 位变了——保活没生效，或有人在切标签时卸载了画布子树');
    }
  });

  testWidgets('V1：选中集跨标签保留', (tester) async {
    // 前提：这条断言只有在 T2 的 family 化落地后才有意义——否则它是在为
    // 跨画布串味背书（见 spec §6.2）。
    final paths = await setupTempPaths(tester, 'ink_shell_sel_');
    await pumpInkShell(tester, paths: paths,
        initial: const ShellState(
          tab: ShellTab.canvas, canvasId: 'c1',
          project: ProjectRef(id: 'p1', name: 'Alpha')),
        extraOverrides: <Override>[
          canvasNodesControllerProvider('c1')
              .overrideWith(() => FakeNodesController(twoNodes)),
        ]);

    final ProviderContainer c = readShellContainer(tester);
    c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>{'a', 'b'});
    await tester.pump();

    await tapShellTab(tester, ShellTab.gallery);
    await tapShellTab(tester, ShellTab.canvas);

    expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'a', 'b'},
        reason: '切走再切回不得丢选中集——保活的元素没离开树，family entry 就不该被回收');
  });

  testWidgets('V1：画廊筛选与搜索框跨标签保留', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_gfilter_');
    await pumpInkShell(tester, paths: paths,
        initial: const ShellState(
          tab: ShellTab.gallery, project: ProjectRef(id: 'p1', name: 'Alpha')));

    final ProviderContainer c = readShellContainer(tester);
    c.read(galleryFilterProvider('p1').notifier).state =
        const GalleryFilter(kind: GalleryItemKind.video, query: 'moon');
    await tester.pump();

    await tapShellTab(tester, ShellTab.studio);
    await tapShellTab(tester, ShellTab.gallery);

    expect(c.read(galleryFilterProvider('p1')).kind, GalleryItemKind.video);
    expect(c.read(galleryFilterProvider('p1')).query, 'moon');
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'moon',
      reason: '搜索框必须从筛选态播种，否则显示空、筛选却仍生效——界面撒谎',
    );
  });
```

> `readShellContainer(tester)` 是 harness 里的小工具：
> `ProviderScope.containerOf(tester.element(find.byType(InkShell)))`。
> `FakeNodesController` / `twoNodes` 从 `canvas_shortcuts_test.dart` 里提到
> `test/_harness/` 复用（本任务顺带做这次提取）。

- [ ] **Step 2: 写 V2 测试**

```dart
  testWidgets('V2：画布保活但不可见时，Delete 不删节点', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_focus_a_');
    await pumpInkShell(tester, paths: paths,
        initial: const ShellState(
          tab: ShellTab.canvas, canvasId: 'c1',
          project: ProjectRef(id: 'p1', name: 'Alpha')),
        extraOverrides: <Override>[
          canvasNodesControllerProvider('c1')
              .overrideWith(() => FakeNodesController(twoNodes)),
        ]);
    final ProviderContainer c = readShellContainer(tester);
    c.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    await tapShellTab(tester, ShellTab.studio);          // 画布保活但离台
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await tester.pump();

    expect(find.byType(NodeCard, skipOffstage: false), findsNWidgets(2),
        reason: '离台画布吞 Delete 会在用户看不见的界面上软删节点——这是安全问题');
  });

  testWidgets('V2：浮层打开时画布不可见，Delete 不删节点且 ⌘K 仍可用', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_focus_b_');
    await pumpInkShell(tester, paths: paths,
        initial: const ShellState(
          tab: ShellTab.canvas, canvasId: 'c1',
          project: ProjectRef(id: 'p1', name: 'Alpha')),
        extraOverrides: <Override>[
          canvasNodesControllerProvider('c1')
              .overrideWith(() => FakeNodesController(twoNodes)),
        ]);
    final ProviderContainer c = readShellContainer(tester);
    c.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    c.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.settings);
    await tester.pump();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(find.byType(NodeCard, skipOffstage: false), findsNWidgets(2));

    // 让出的必须是画布焦点，不是把键盘整个掐死。
    await sendMeta(tester, LogicalKeyboardKey.keyK);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CommandPaletteDialog), findsOneWidget,
        reason: '若 _shellFocus 被加了 hasFocus 守卫，焦点会掉到 ModalScope 的 '
            'FocusScope（在 CommandPaletteShortcuts 之上），全 app 的 ⌘K 失效');
  });

  testWidgets('V2 正向对照：切回画布标签后不点任何东西，Delete 直接生效', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_focus_c_');
    await pumpInkShell(tester, paths: paths,
        initial: const ShellState(
          tab: ShellTab.canvas, canvasId: 'c1',
          project: ProjectRef(id: 'p1', name: 'Alpha')),
        extraOverrides: <Override>[
          canvasNodesControllerProvider('c1')
              .overrideWith(() => FakeNodesController(twoNodes)),
        ]);
    final ProviderContainer c = readShellContainer(tester);
    c.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    await tapShellTab(tester, ShellTab.studio);
    await tapShellTab(tester, ShellTab.canvas);
    await tester.pump();                                  // 等 post-frame 复焦

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await tester.pump();

    expect(find.byType(NodeCard, skipOffstage: false), findsNWidgets(1),
        reason: 'ExcludeFocus 文档明说重新可见不会自动复焦——没有这条正向对照，'
            '"永远不给焦点"也能让上面两条通过');
  });
```

- [ ] **Step 3: 跑测试，修出来的问题**

预期会红在三处：`sizing: StackFit.expand` 遗漏、`buildTab` 缓存了 Widget 实例导致 `isActive` 不下传、focus 回调顺序。

> 若 V2 的 ⌘K 一例红，**先查 `_shellFocus` 是不是被加了 `hasFocus` 守卫**。

- [ ] **Step 4: 门禁 + 提交**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
git add test/features/shell/
git commit -m "test(shell): V1 状态保留 + V2 焦点归属的端到端断言"
```

---

### Task 9: 画廊标签真身

**Files:**
- Create: `lib/features/shell/widgets/tabs/gallery_tab.dart`、`lib/features/shell/providers/gallery_dirty.dart`
- Modify: `lib/features/gallery/widgets/gallery_screen.dart`（`InkToolBar`）
- Modify: `test/features/gallery/widgets/gallery_screen_test.dart:157-181`（删返回键用例）

**Interfaces:**
- Consumes: T4b 的 `galleryFilterProvider(projectId)`；T5 的 `activeProjectProvider`
- Produces: `GalleryTab({required bool isVisible})`、`galleryDirtyProvider`

- [ ] **Step 1: `GalleryTab` 薄壳 + 未选项目空态**

读 `activeProjectProvider`；为 null 时渲染 `ShellEmptyState(title: shellGalleryNoProjectTitle, body: shellGalleryNoProjectBody, cta: shellGoToStudio → nav.goTab(ShellTab.studio))`；非 null 时透传两个必填参给 `GalleryScreen`。**`GalleryScreen` 的构造签名不动**（6 个 pump 点 + 1 个 golden 用例靠它）。

- [ ] **Step 2: 粗粒度脏标记**

`galleryDirtyProvider`：`jobsRegistryProvider` 里任一 job 转 `JobSucceeded` → 置脏。`GalleryTab` 在「不可见→可见」且脏时 `ref.invalidate(galleryControllerProvider(pid))`，然后清脏。

- [ ] **Step 3: 钉死 `skipLoadingOnRefresh`**

```dart
  testWidgets('invalidate 后 GridView 的 ScrollPosition.pixels 不变', (tester) async {
    // riverpod 2.6.1：ref.invalidate 走 refresh 而非 reload（common.dart:585-586），
    // when 默认 skipLoadingOnRefresh: true（common.dart:673-674, 728-729）
    // ⇒ 不走 loading 分支 ⇒ _GalleryContent 不卸载 ⇒ 滚动/搜索框/筛选全保。
  });
```

并在 `gallery_screen.dart` 的 `when` 旁加注释：任何人给它加 `skipLoadingOnRefresh: false`，V1 的滚动/搜索框/筛选三条会同时静默失效且没有测试会红。

- [ ] **Step 4: `InkToolBar` 取代 chrome**

`InkToolBar(title: 项目名 + 产物计数, actions: [「筛选生效中」chip（消费 T4a 的 `filtersActive`）, 「更换项目」ghost → `nav.goTab(ShellTab.studio)`])`。

- [ ] **Step 5: ARB +5 / −2**

新增 `shellGalleryNoProjectTitle` / `shellGalleryNoProjectBody` / `shellGalleryChangeProject` / `shellGalleryFiltersActive` / `shellGalleryItemCount`（后者需 `@` metadata 声明 `{count}` 占位符，**两个 ARB 都要写**）；退役 `galleryBreadcrumb`(+@) / `galleryBackTooltip`。跑 `gen-l10n`，提交 generated。

- [ ] **Step 6: 门禁 + 提交**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
git add -A && git commit -m "feat(shell): 画廊标签真身——工具条取代 chrome + 激活时脏刷新"
```

---

### Task 10: 序列 / 导出标签

**Files:**
- Create: `lib/features/shell/widgets/tabs/sequence_tab.dart`、`export_tab.dart`
- Test: `test/features/shell/shell_tabs_empty_state_test.dart`（T7 已搬入的用例 + 补齐）

**对话框一个字符都不改**：`showSequencePreviewDialog` / `showExportVideoDialog` 保持私有、`barrierDismissible: false` 不变（理由见 spec §8.2）。

- [ ] **Step 1: 三态空态**

① `canvasId == null` → 按钮禁用 + `shellNeedsCanvas`；② 有画布但不满足可用性 → 禁用 + 复用既有的 `sequencePreviewDisabledTooltip` / `exportVideoDisabledTooltip`；③ 满足 → 可点 → 弹既有对话框。

可用性判据从已删的 `canvas_top_chrome.dart` 的 `_hasNarrative` / `_canExport` **原样搬**（T7 删文件前先把这两个纯函数复制出来），不重写。

- [ ] **Step 2: 硬约束测试——空态分支不得碰仓储**

```dart
/// 一碰就炸的仓储：用来证明某条渲染路径确实没读它。
class _ExplodingNodeRepository implements NodeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      '空态分支不得触碰 NodeRepository：碰了它就会去起真内嵌 PostgreSQL，'
      '覆盖率收集会永挂（见 app_routing_test.dart:38-40, :96）。'
      '被碰的方法：${invocation.memberName}');
}

  testWidgets('canvasId 为 null 时，序列/导出标签不触碰任何仓储', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_no_repo_');
    await pumpInkShell(tester, paths: paths,
        // canvasId 为 null：两个标签都应停在"请先打开一个画布"空态。
        initial: const ShellState(
          tab: ShellTab.sequence, project: ProjectRef(id: 'p1', name: 'Alpha')),
        extraOverrides: <Override>[
          nodeRepositoryProvider.overrideWith((_) async => _ExplodingNodeRepository()),
        ]);

    expect(find.text('Open a canvas first.'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: '空态分支碰了仓储——懒物化只挡住"没点过的标签"，'
            '点开后的空态分支必须自证不读仓储');

    await tapShellTab(tester, ShellTab.export);
    expect(find.text('Open a canvas first.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
```

> `NodeRepository` 用 `noSuchMethod` 兜底需要在类上加 `@GenerateNiceMocks` 之外的
> 写法——本仓库不用 mockito，所以这里直接 `implements` + `noSuchMethod`，
> 并在文件顶部加 `// ignore: avoid_implementing_value_types` 之类的 lint 豁免（若 analyze 报）。
> 若 `NodeRepository` 的抽象方法太多导致 `noSuchMethod` 不被接受，
> 改成显式实现每个方法并全部 `throw StateError(...)`。

- [ ] **Step 3: 手工确认**

序列对话框关闭后，`SequencePreviewContent` 不在树里（media_kit `Player` 已 dispose，不会后台播）。

- [ ] **Step 4: ARB +7**

`shellSequenceEmptyTitle` / `shellSequenceEmptyBody` / `shellSequencePlay` / `shellExportEmptyTitle` / `shellExportEmptyBody` / `shellExportOpen` / `shellNeedsCanvas`。跑 `gen-l10n`。

- [ ] **Step 5: 门禁 + 提交**

PR 描述里点名：`canvas_top_chrome_export_test.dart` / `_sequence_test.dart` 的测试数量搬运前后一致。

```bash
git add -A && git commit -m "feat(shell): 序列/导出标签过渡态——空态 + 拉起现有对话框"
```

---

### Task 11: 会话恢复 + `shellKeepLastCanvas`

**Files:**
- Modify: `lib/core/models/app_preferences.dart`（六处）、`lib/features/settings/widgets/startup_section.dart`、`lib/features/studio/providers/restore_last_session.dart:36-47`
- Test: `test/features/studio/providers/restore_last_session_test.dart:125-160`、`test/core/models/app_preferences_test.dart`

- [ ] **Step 1: 写必红的测试**

```dart
  test('空 map 解析出 shellKeepLastCanvas == true', () {
    // fromMap 缺省【必须】退 true，与 app_preferences.dart:158 现成的
    // `updateCheckEnabled: uce is bool ? uce : true` 对齐。
    // 写反的后果：所有老用户（preferences.json 无此键）升级后会话恢复静默失效，
    // 且没有任何现有测试会红。
    expect(AppPreferences.fromMap(const <String, Object?>{}).shellKeepLastCanvas, isTrue);
  });

  test('开关 false 时不恢复，且不清记录', () async {
    // 关掉开关不等于放弃记录——用户可能只是这次不想回去。
  });
```

`restore_last_session_test.dart:125-160` 的三例守卫测试**必须重写**（不是微调）：它们的前提是"seed `currentScreen=settings` 或 gallery 目标 = 用户已导航"，那两个 provider 已不存在。新前提是 `ShellState.isPristine`。

- [ ] **Step 2: `AppPreferences` 六处**

字段声明、构造具名参数、`copyWith`、`toMap`、`fromMap`（**缺省退 `true`**）、`==`/`hashCode`。

- [ ] **Step 3: 守卫改判**

`restore_last_session.dart:36-47`：

```dart
  if (!prefs.current.shellKeepLastCanvas) return;

  // 债145：守卫判据 = 用户尚未发生任何导航。
  // tab 默认 studio，所以用户在 PG 就绪窗口内切到任何标签，isPristine 自然为假
  // ——不需要额外的布尔闩。
  final nav = ref.read(shellControllerProvider.notifier);
  if (!ref.read(shellControllerProvider).isPristine) return;
  nav.openCanvas(
    canvasId,
    withProject: ProjectRef(id: projectId, name: projectRow['name'] as String),
  );
```

> 注意 `if (!valid)` 分支里的 `clearLastCanvas` **保留**——那是记录本身失效（画布被软删），与开关无关。

- [ ] **Step 4: 设置页开关 + ARB +2**

`startup_section.dart` 加 `shellKeepLastCanvasTitle` / `shellKeepLastCanvasSubtitle` 的开关。跑 `gen-l10n`。

- [ ] **Step 5: 确认两处直写已无残留**

```bash
git grep -n "clearLastCanvas"
```
只应剩 `restore_last_session.dart` 里"记录失效"那一处与 `app_preferences.dart` 的定义。

- [ ] **Step 6: 门禁 + 提交**

```bash
git add -A && git commit -m "feat(shell): 启动恢复改判 isPristine + shellKeepLastCanvas 开关（默认开）"
```

---

### Task 12: 剩余接线收口

**Files:** `test/features/studio/open_canvas_test.dart`、`project_card_gallery_entry_test.dart`、`built_in_showcase_screen_test.dart`、`command_palette_test.dart`

- [ ] **Step 1: 补 tab 断言**——`openCanvas` 后 `tab == ShellTab.canvas`；项目卡 Gallery 后 `tab == ShellTab.gallery` 且 `project` 正确
- [ ] **Step 2: `command_palette_test.dart` 全文走 navigator**，含 `:212-226` 的"Back to Studio 不清 canvasId"
- [ ] **Step 3: 收口判据**

```bash
grep -rn "AppScreen\|currentScreenProvider\|currentGalleryProjectProvider" lib test
grep -rn "galleryBackTooltip\|galleryBreadcrumb\|showcaseBackTooltip\|studioBreadcrumbAll\|canvasBreadcrumbProject\|canvasBreadcrumbCanvas\|canvasBackToStudio" lib test
```
两条都必须零命中。

- [ ] **Step 4: 门禁 + 提交**

---

### Task 13: 文档 + golden 收口

**Files:** `docs/BOARD.md`、`docs/CLAUDE.md`、`lib/features/shell/README.md`、三个 feature README

- [ ] **Step 1: `lib/features/shell/README.md`** —— 写清两条不变量、"同一时刻只保活一个 canvasId"、隐藏标签的副作用清单（`CanvasJobListener` 在任何标签下都会弹失败 toast，这是**改善**不是回归）
- [ ] **Step 2: `docs/BOARD.md`** —— 登记外壳卡；三条债：`canvasViewportSizeProvider` 的 family+keepAlive entry 永不释放、**浮层 Esc 不可用是刻意的（写明原因：与 `_EditorDialog` 的 `DismissIntent` 竞争；下一个人当 bug 顺手"修"掉之后，在设置里按 Esc 会连编辑框带浮层一起关）**、「关闭当前画布」待补卡
- [ ] **Step 3: `docs/CLAUDE.md`** Project Structure 补 `features/shell/`
- [ ] **Step 4: golden 重铸 4 张** —— `studio_empty` / `studio_error` / `gallery_empty` / `settings_screen`，经 CI ubuntu 的 `update-goldens` workflow 铸线后回填。

  **`canvas_empty.png` 不在清单内**：`empty_states_golden_test.dart:120-134` pump 的是裸 `const CanvasView()`，整棵子树无 chrome，像素不变；重铸它会把"它为什么变了"的信号永久抹掉。

  **不要**给画廊 golden 用例加 `activeProjectProvider` override：该用例（`:136-154`）走 `GalleryScreen` 的两个必填构造参，根本不读任何项目上下文 provider。

- [ ] **Step 5: 最终门禁**

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden --coverage
```
看 `lib/features/shell/` 的行覆盖（`lib/app.dart` 在 CI 70% 底线内，`.github/workflows/ci.yml:84,94`）。

- [ ] **Step 6: 提交**

```bash
git add -A && git commit -m "docs(shell): 外壳 README + BOARD 债登记 + golden 重铸回填"
```
