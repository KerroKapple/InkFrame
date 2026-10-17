# lone-alt-menubar · 单独按下再松开 Alt 聚焦菜单栏（Windows）
- 波次 W7 / lane E 第一片 / 基底 origin/main〔W0–W6 已合入，含 W4 win-menubar〕
- 依赖切片：win-menubar（W4：InkMenuBar / InkMenuBarController / ShellMenuBar）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- Windows 上单独按下再松开 Alt（期间没有别的键、指针按下或滚轮）→ 菜单栏「文件」获得键盘焦点（高亮描边），不展开。
- 聚焦后 ↓ / Enter 展开，←→ 换菜单，Esc 或再按一次 Alt 回到原来的焦点。
- Alt+字母（对齐，W8）、Alt+拖（切线，W17）、Alt F4 不受影响；单独按 Alt 不再触发 Windows 的系统菜单 / 提示音。

## 设计依据
- KeyMap.dc.html「单独按 Alt · Windows 菜单栏的唯一入口」（b2_keys.js:179–216）：Alt↓Alt↑ → 聚焦「文件」不展开；Alt↓A↓ → 左对齐、菜单栏不动；Alt↓ 指针拖空白 → 切线、菜单栏不动。规则：松开 Alt 时判，按下后没有别的键、指针按下或滚轮才聚焦；↓ / Enter 展开，←→ 换菜单，Esc 或再按 Alt 回原处；窗口失焦清标记（Alt Tab 回来不误触）；带 Ctrl 的 AltGr 不算；不做 Alt+字母助记键；mac 不画。
- KeyMap「文字让位」：「单独 Alt」属于「照常生效」——焦点在输入框里也聚焦菜单栏。
- KeyMap「Esc 阶梯」：菜单（含聚焦态的菜单栏）在最上层，Esc 先回这里。
- ShellExport.dc.html 菜单规则第 4 条（b2_shell.js:148）同上；critic.txt 第 21 条。
- 设计缺口：聚焦态标签的样式只在 KeyMap altBox 里画了一个（1px accent 描边 + surface5 底 + fg1 字），按它；聚焦态下鼠标点别处 / 点标签的行为没画（按：点别处 = 退出聚焦态，不还焦点；点标签 = 正常打开）；对话框盖着时单独 Alt 怎么办没画（按：不响应）。

## 允许改的文件
- lib/features/shell/util/lone_alt_detector.dart（新）：纯函数状态机 + 薄适配器。
- lib/features/shell/widgets/shell_menu_bar.dart（由 win-menubar 新建）：装 / 卸检测器，触发时调 InkMenuBarController。
- lib/theme/components/ink_menu_bar.dart（由 win-menubar 新建）：加「聚焦但不展开」态与它的键盘。
- windows/runner/flutter_window.cpp：MessageHandler 吞掉 SC_KEYMENU（见具体改动 4）。
- test/features/shell/util/lone_alt_detector_test.dart（新）、test/features/shell/shell_menu_bar_alt_test.dart（新）、test/theme/components/ink_menu_bar_test.dart（加用例）。

## 不许碰的文件
- W7 其他片：node_card.dart、outline_panel.dart、outline_model.dart（tc-stale-marks）；node_card_slot.dart、node_drag_delta.dart、edge_painter.dart、stage_edge_layer.dart、stage_overlays.dart（cm-drag-insert-narrative）；canvas_nodes_controller.dart、canvas_menu/blank_menu_entries.dart、node_menu_entries.dart、canvas_node_delete.dart、shortcuts/clipboard_keys.dart（clipboard）；lane_title_bar.dart、stage_lane_layer.dart、canvas_menu_host.dart（cm-lane-menu）。
- canvas_shortcuts.dart、canvas_shortcut_registry.dart（本片不加画布键）、ink_window_chrome.dart、shell_chrome.dart、ink_menu_panel.dart、ink_shell.dart / app.dart / main.dart（下一片 mac 用）。
- W7 clipboard-paste 的 `lib/features/canvas/widgets/canvas_view.dart`；以及 W7 其他 lane 的全部画布文件（`lib/features/canvas/**`）。

## 具体改动
1. lone_alt_detector.dart 纯函数：
```dart
sealed class LoneAltInput { const LoneAltInput(); }
final class AltDown extends LoneAltInput { const AltDown({required this.ctrlHeld}); final bool ctrlHeld; }
final class AltUp extends LoneAltInput { const AltUp(); }          // 适配器只在所有 Alt 键都松开时发
final class OtherKeyDown extends LoneAltInput { const OtherKeyDown(); }
final class PointerDown extends LoneAltInput { const PointerDown(); }
final class PointerScroll extends LoneAltInput { const PointerScroll(); } // 滚轮 / 触控板 panZoom 开始
final class WindowBlur extends LoneAltInput { const WindowBlur(); }
@immutable class LoneAltState { const LoneAltState({required this.armed}); final bool armed; static const idle = LoneAltState(armed: false); }
({LoneAltState next, bool fire}) reduceLoneAlt(LoneAltState s, LoneAltInput e);
```
   - AltDown(ctrlHeld:false) → armed；AltDown(ctrlHeld:true) → idle（AltGr 在 Windows 上是先 ControlLeft 再 AltRight）；已 armed 再来 AltDown（另一只 Alt）保持 armed。
   - OtherKeyDown / PointerDown / PointerScroll / WindowBlur → idle、不 fire。
   - AltUp：fire = s.armed；next = idle。
2. 适配器（同文件）：
```dart
class LoneAltDetector { LoneAltDetector({required VoidCallback onLoneAlt}); void attach(); void detach(); }
```
   - `HardwareKeyboard.instance.addHandler(_onKey)`：KeyDownEvent 的 logicalKey 属 altLeft / altRight / alt → AltDown(ctrlHeld: HardwareKeyboard.instance.isControlPressed)；KeyRepeatEvent 一律忽略；KeyUpEvent 是 Alt 且 `!HardwareKeyboard.instance.isAltPressed` → AltUp；其他 KeyDownEvent（含 Shift、Ctrl、altGraph、F4）→ OtherKeyDown；其他 KeyUp 忽略。**handler 永远返回 false**（不吞任何键，Alt 事件照常进焦点树）。
   - `GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer)`：PointerDownEvent → PointerDown；PointerScrollEvent / PointerPanZoomStartEvent → PointerScroll。
   - `AppLifecycleListener(onStateChange: s != resumed → WindowBlur)`（与 toast_layer.dart:80 同法）。
   - detach 卸掉三者（dispose 时必须调）。
3. ink_menu_bar.dart：InkMenuBarController 加
```dart
bool get isFocused;            // 聚焦但未展开
int? get focusedIndex;
void focusMenu(int index);     // 记下当前 primaryFocus 作为「原处」，标签 index 拿焦点
void exitToOrigin();           // 关下拉 / 退出聚焦态，焦点还原处（原处已 dispose 则不还）
```
   聚焦态键盘（挂在标签 Focus 上）：↓ / Enter / numpadEnter → open(focusedIndex)；← / → 换 focusedIndex（回绕）；Esc → exitToOrigin；其他键 → 忽略并放行（ignored）。从聚焦态展开后再 Esc → exitToOrigin（回原处，不回聚焦态，照稿「Esc 退出」）。聚焦态样式：1px accent 描边 + surface5 底 + fg1 字。焦点离开标签（点别处）→ 退出聚焦态，不抢回焦点。
4. flutter_window.cpp `FlutterWindow::MessageHandler`（现 50–71 行），在调用 `HandleTopLevelWindowProc` **之前**加：
```cpp
// 单独 Alt / Alt+字母：无原生菜单栏，DefWindowProc 进菜单模态会吃掉下一个键并响一声。Alt+Space（系统窗口菜单）放行。
if (message == WM_SYSCOMMAND && (wparam & 0xFFF0) == SC_KEYMENU && lparam != VK_SPACE /* ' ' */) { return 0; }
```
5. shell_menu_bar.dart：`initState` 里若 `defaultTargetPlatform != TargetPlatform.macOS`（与菜单栏是否画同一判据）建 `LoneAltDetector(onLoneAlt: _onLoneAlt)..attach()`，dispose 时 detach。
```dart
void _onLoneAlt(); // 路由不是 isCurrent（上面压着对话框）→ 什么都不做；
                   // controller.isOpen || controller.isFocused → exitToOrigin()；否则 focusMenu(0)（「文件」）
```

## 行为规则与边界情况
1. Alt↓ Alt↑（中间无任何事件）→ 「文件」聚焦、下拉不出现。
2. Alt↓ A↓ A↑ Alt↑ → 不聚焦；A 键事件照常到焦点树（画布的 Alt 字母快捷键不受影响）。
3. Alt↓ 鼠标按下 / 滚轮 / 触控板平移 → 不聚焦（Alt+拖切线不受影响）。
4. Alt↓ F4↓ → 不聚焦；Alt F4 照常由系统关窗走有序退出。
5. Ctrl 按住时按 Alt（AltGr、Ctrl+Alt+…）→ 不聚焦；Alt 按下后再按 Ctrl / Shift → 作废（Alt+Shift 是 Windows 切输入法）。
6. 按住 Alt 自动重复（KeyRepeatEvent）不算别的键，松开仍聚焦。
7. 左右两只 Alt 先后按下、全部松开才判一次。
8. Alt↓ 后窗口失焦（Alt Tab），回来时松开 Alt → 不聚焦。
9. 焦点在提示词条 / 检查器文本框里：单独 Alt 照样聚焦「文件」；Esc 回到该文本框（光标还在）。
10. 聚焦态：↓ / Enter 展开「文件」；←→ 换标签；Esc 回原处；再单独按 Alt 回原处；下拉开着时单独按 Alt 也关下拉回原处。
11. 上面压着对话框（showDialog 路由）时单独 Alt 不响应。设置浮层（不是路由）开着时照常聚焦。
12. 检测器不吞任何键：Alt 的 KeyDown / KeyUp 仍送达焦点树。
13. macOS：检测器不装（菜单在系统菜单栏）。
14. 与撤销栈无交互。
15. Windows 系统层（需真机，测试测不到）：单独按 Alt 不响提示音、不进系统菜单模态（下一个键不被吃）；Alt+A 不响提示音；Alt+Space 仍弹系统窗口菜单；Alt F4 仍关窗。

## 新文案键
无。

## 测试
- test/features/shell/util/lone_alt_detector_test.dart（纯函数，先写）：`AltDown→AltUp fire`；`AltDown→OtherKeyDown→AltUp 不 fire`；`AltDown→PointerDown→AltUp 不 fire`；`AltDown→PointerScroll→AltUp 不 fire`；`AltDown→WindowBlur→AltUp 不 fire`；`AltDown(ctrlHeld)→AltUp 不 fire`；`AltDown→AltDown→AltUp fire（另一只 Alt）`；`idle 下 AltUp 不 fire`；`fire 之后状态回 idle（再 AltUp 不 fire）`。
- 适配器（同文件测试或 shell_menu_bar_alt_test 里）：用 `tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft)` / `sendKeyUpEvent`；`KeyRepeatEvent 不作废`（sendKeyRepeatEvent）；`handler 返回 false：外层 Focus.onKeyEvent 收到了 Alt 的 KeyDown`。
- test/features/shell/shell_menu_bar_alt_test.dart（pumpInkShell + `debugDefaultTargetPlatformOverride = windows`）：`单独 Alt → 「文件」标签持焦、dropdownKey 不存在`；`Alt + A → 不持焦`；`Alt 期间 tester.tapAt 空白 → 不持焦`；`Alt 期间 sendEventToBinding(PointerScrollEvent) → 不持焦`；`聚焦后 ↓ → 下拉出现`；`聚焦后 → → 「编辑」持焦`；`聚焦后 Esc → 焦点回到原来的 TextField`；`聚焦后再单独 Alt → 焦点回原处`；`下拉开着时单独 Alt → 下拉关、焦点回原处`；`showDialog 盖着时单独 Alt → 不持焦`；`macOS override：单独 Alt 无反应（没有菜单栏）`。
- test/theme/components/ink_menu_bar_test.dart（加）：`focusMenu 后标签有 accent 描边`；`exitToOrigin 还给记下的 FocusNode`；`原处 FocusNode 已 dispose 时 exitToOrigin 不抛`。

## 变异点
1. reduceLoneAlt 里 OtherKeyDown 不作废 → `AltDown→OtherKeyDown→AltUp 不 fire` 与 `Alt + A → 不持焦` 红。
2. 去掉 pointerRouter 全局路由 → `Alt 期间 tester.tapAt 空白 → 不持焦` 红。
3. 去掉 PointerScroll 映射 → `PointerScrollEvent → 不持焦` 红。
4. AltDown 不看 ctrlHeld → `AltDown(ctrlHeld)→AltUp 不 fire` 红。
5. KeyRepeatEvent 当 OtherKeyDown → `KeyRepeatEvent 不作废` 红。
6. handler 改返回 true → `外层 Focus 收到 Alt 的 KeyDown` 红。
7. _onLoneAlt 去掉 isCurrent 判断 → `showDialog 盖着时 … 不持焦` 红。
8. focusMenu 不记原处 / exitToOrigin 不还焦点 → `聚焦后 Esc → 焦点回到原来的 TextField` 红。
9. 聚焦即展开（focusMenu 里调 open）→ `单独 Alt → … dropdownKey 不存在` 红。
- flutter_window.cpp 无自动测试，靠「验收」里的真机清单。

## 验收
- flutter analyze lib test；flutter test test/features/shell test/theme/components；逐条变异。
- 截图（pumpInkShell，windows override，画布标签，提示词条持焦）：① 单独 Alt 后「文件」聚焦描边、无下拉；② 再按 ↓ 展开「文件」。
- Windows 真机清单（主 Agent 或人工，写进 PR 描述）：单独 Alt 无提示音、随后按 A 没被系统吃掉；Alt+A 无提示音；Alt+Space 弹系统菜单；Alt F4 关窗且 PG 正常停；Alt Tab 回来松开 Alt 不聚焦。

## 风险与不确定
1. SC_KEYMENU 是否真的到达顶层 FlutterWindow（而不是 Flutter 子视图 HWND）要真机确认；若是子窗口先收到 WM_SYSCHAR / WM_SYSKEYUP 再转发，吞的位置可能要挪（仍只在 flutter_window.cpp 内）。window_manager 插件是否处理 WM_SYSCOMMAND 也要看：所以放在 HandleTopLevelWindowProc 之前。
2. 吞掉 Alt+字母 的 SC_KEYMENU 后，第三方 IME 的系统快捷键是否受影响需要实测（只吞 SC_KEYMENU，不吞 WM_SYSKEYDOWN，理论上不影响）。
3. Flutter 在 Windows 上对 AltGr 的合成序列（ControlLeft + AltRight）依版本略有差异；纯函数只认「AltDown 时 Ctrl 已按下」和「之后有别的键」两条，两种顺序都覆盖。
4. 测试环境的 AppLifecycleListener 状态切换要用 `tester.binding.handleAppLifecycleStateChanged`；只在纯函数层测 WindowBlur 也可接受。
