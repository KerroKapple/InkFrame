# zoom-reset-100 · Ctrl 0 / ⌘0 = 缩放到 100%、保持视口中心
- 波次 W0 / lane C / 基底：叠在 esc-ladder 之后（从 `feat/esc-ladder` 起分支）；依赖：esc-ladder（`shortcuts/core_canvas_keys.dart` 与 `resetCanvasZoom` 由 esc-ladder 新建）；阻塞决定：KeyMap Q5 → 按建议 B。

> **执行代理约定**
> - 在自己的工作树里、从 `feat/esc-ladder` 起分支 `feat/zoom-reset-100`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表每片只追加一行；本片不追加（只改 core_canvas_keys.dart 里已有的 Ctrl 0 回调）。
> - CanvasNode 新派生属性写成新文件 extension；不给 Node/Edge/StyleLaneRepository 加抽象方法。
> - 本片不碰 canvas_tool_actions.dart。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
1. 画布上按 Ctrl 0（Windows）/ ⌘0（macOS）：缩放比例变成 100%，视口中心对着的那块内容不动；不再跳回初始相机（初始相机常落在空处）。
2. 设置「快捷键」页这一行写「复位 100%」；W4 的菜单栏「画布 › 缩放 › 复位 100%」读同一个 ARB 键。
3. 不新增 Shift 0。

## 设计依据
- KeyMap.dc.html ›「需要你定」Q5：A 保留复位 + 加 Shift 0；B Ctrl 0 改 100%、保持视口中心、不加 Shift 0；C 两键都 100%。**按建议：Q5 → B**（「复位到原点常落在空处，回内容有 Shift 1 和『回到内容』；一件事一个键」）。
- KeyMap ›「组合键」表：`Ctrl 0 / ⌘0 · 缩放复位（见 Q5）· 画布 · 已上线`。
- ShellExport.dc.html ›「画布 › 缩放 ›」：放大 Ctrl + · 缩小 Ctrl − · **复位 100%** Ctrl 0。
- critic.txt 第三节：「还没分配：… Shift 0（回 100%）」——按 Q5-B 不分配。
- 设计缺口：画板没说明「已经是 100%」时按 Ctrl 0 要不要有反馈；本片定为相机不动、无提示（缩放比例胶囊由 W1 canvas-capsule 统一加）。

## 允许改的文件
> 主 Agent 自查：`canvas_intents.dart` 与 `canvas_shortcuts.dart` 头注已由 esc-ladder 写成不绑具体行为的说法（「行为见 resetCanvasZoom」），本片不再改这两个文件。`core_canvas_keys.dart` 与 esc-ladder 共用，是 plan.md 第 2 节同 lane 串行（esc-ladder → zoom-reset-100）的例外：本片从 `feat/esc-ladder` 起分支，不与 esc-ladder 并行。
- `lib/features/canvas/util/canvas_zoom.dart`：新增 `actualSizeTransform`；改第 73–74 行 `resetTransform` 的注释（它仍是「回初始相机」，首帧 / 新画布 / 切画布在用，保留不删）。
- `lib/features/canvas/widgets/shortcuts/core_canvas_keys.dart`（由 esc-ladder 新建）：`resetCanvasZoom` 改调 `actualSizeTransform`。
- `test/features/canvas/util/canvas_zoom_test.dart`：加用例。
- `test/features/canvas/widgets/canvas_shortcuts_test.dart`：改第 241–249 行那条用例。
- `test/features/canvas/widgets/canvas_node_shortcuts_test.dart`：改第 330–338 行用例、第 346–347 行的前置步骤。

## 不许碰的文件
- menu-split：`create_node_menu.dart`、`canvas_menu/**`、`theme/components/ink_menu_panel.dart`。
- canvas-view-split：`canvas_view.dart`、`stage/**`（`InteractiveViewer` 的初始变换不动）。
- undo-stack：`models/canvas_command.dart`、`models/edge_endpoints.dart`、`providers/canvas_history_controller.dart`。
- naming-shot-unify：`storyboard/widgets/script_import_dialog.dart`。
- multi-select-core：`providers/canvas_selection_controller.dart`、`util/selection_geometry.dart`。
- duration-format：`lib/l10n/duration_format.dart`。
- 另外：`canvas_tool_actions.dart`（第 261 行 fitAll 空画布回初始相机，语义不变）、`canvas_transform_controller.dart`、`canvas_zoom_bar.dart`（W1 归 canvas-capsule）、`shortcut_catalog.dart`。
- （主 Agent 自查补充）esc-ladder 新建的 `shortcuts/canvas_intents.dart`、`shortcuts/canvas_tool_keys.dart`、`shortcuts/canvas_key_binding.dart`、`shortcuts/canvas_shortcut_registry.dart`、`canvas_shortcuts.dart`：本片不改；`core_canvas_keys.dart` 只改 `resetCanvasZoom` 一个函数（同 lane 串行例外）。

## 具体改动
```dart
// util/canvas_zoom.dart
/// 缩放到 100%：scale = 1，变换前落在视口中心的场景点，变换后仍落在视口中心。纯函数。
Matrix4 actualSizeTransform(Matrix4 current, Size viewport);
// 等价于 zoomedTransform(current: current, factor: 1 / scaleOf(current), viewportSize: viewport)，
// 但结果 scale 精确为 1.0（不经乘除误差，不经 clamp）——实现里直接用目标 1.0 算平移。

// shortcuts/core_canvas_keys.dart（esc-ladder 已建）
void resetCanvasZoom(WidgetRef ref, {required String canvasId});
// 读 canvasTransformControllerProvider(canvasId) 与 canvasViewportSizeProvider(canvasId)；
// transform.value = actualSizeTransform(transform.value, size)。
```
绑定本身（四个激活器 digit0 / numpad0 × meta / control、`CanvasZoomResetIntent`、`gate: notEditingText`、id `canvasZoomReset`）不动。

## 行为规则与边界情况
1. 当前 scale = s、视口中心对应场景点 P：按 Ctrl 0 后 scale == 1.0，P 仍映射到视口中心（误差 < 1e-6）。
2. 当前已是 100%：变换矩阵与按之前完全相等（不抖动、不重置平移）。
3. 视口尺寸还没上报（`Size.zero`，首帧前）：以 (0,0) 为锚点算（与 `zoomedTransform` 在 Size.zero 下的行为一致），不报错、不跳回初始相机。
4. 焦点在输入框里：Ctrl 0 照旧让位给文本编辑（gate 不变）。
5. 首帧、新建画布、切换画布时的相机仍是 `initialCanvasTransform()`；空画布上「适应全部」仍回初始相机（canvas_tool_actions.dart 第 261 行）。
6. macOS ⌘0、Windows Ctrl+0；小键盘 0 两个平台都有效；清单只列主键盘那个（`_duplicateTriggerIds` 不变）。
7. 不进撤销栈（相机操作）。

## 新文案键
| key | en | zh |
|---|---|---|
| settingsShortcutCanvasZoomReset（改值） | Reset to 100% | 复位 100% |

## 测试
先写 1–3，确认红（`actualSizeTransform` 还不存在 / Ctrl 0 仍回初始相机）。
- `test/features/canvas/util/canvas_zoom_test.dart`：
  1. 「100%：任意缩放、平移下，scale 变成 1，视口中心的场景点不动」：current = translate(120,-80)·scale(2.5)、viewport 800×600 → `scaleOf(result) == 1.0`；`transformPoint(result, P) ≈ (400,300)`（P = 变换前中心的场景点）。再测 scale 0.1、3.0 两个边界。
  2. 「已是 100%：原样返回」：current = translate(-37, 52)（scale 1）→ `result == current`。
  3. 「视口尺寸为零：以原点为锚、不抛错」：`Size.zero` → scale 1，(0,0) 处的场景点仍在 (0,0)。
  4. 原第 51–61 行「复位 → 初始相机」保留不改（resetTransform 仍在用）。
- `test/features/canvas/widgets/canvas_shortcuts_test.dart` 第 241 行用例改名「⌘0（Ctrl+0）缩放到 100%、保持视口中心」：先 Ctrl+= 两次 → 记下视口中心对应场景点 → Ctrl+0 → `scaleOf == 1.0`、该点仍在视口中心、且 `isNot(initialCanvasTransform())`（前置：先 Ctrl+= 再手动平移 transform 一段，保证与初始相机不同）。
- `test/features/canvas/widgets/canvas_node_shortcuts_test.dart`：
  5. 第 330 行改为「⌘0 / Ctrl+0 是 100% 不是适应：适应全部之后按它，scale 回到 1、中心不动」。
  6. 第 346–347 行的「前提：先复位」改为直接写 `container.read(canvasTransformControllerProvider('c1')).value = initialCanvasTransform()`，其后断言不变。
- `test/features/settings/shortcut_catalog_test.dart`、`shortcuts_section_test.dart` 不改（键位串不变）。

## 变异点
1. canvas_zoom.dart：`actualSizeTransform` 里目标 scale 写成 `scaleOf(current)`（不缩放）→ 用例 1 红。
2. canvas_zoom.dart：平移按 (0,0) 而非视口中心计算 → 用例 1 的「中心点不动」红。
3. core_canvas_keys.dart：`resetCanvasZoom` 改回 `resetTransform()` → canvas_shortcuts_test 第 241 行新用例与用例 5 红。
4. canvas_zoom.dart：视口尺寸为零时提前 `return initialCanvasTransform()`（「兜底回原点」）→ 用例 3 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas test/features/settings --exclude-tags golden`；逐条跑 4 个变异。
- 截图（test/_harness/screenshot.dart，CanvasScreen + fake_canvas 两节点，视口 1280×800）：① 放大到 240% 并平移使卡 A 位于视口中心 → 截图；② 按 Ctrl 0 → 截图：缩放条显示 100%，卡 A 仍在视口中心；③ 设置「快捷键」页：「复位 100%  Ctrl+0」（Windows）与「⌘0」（macOS，isMacOverride）各一张。

## 风险与不确定
- 改的是一个已上线键的语义：习惯用 Ctrl 0 回原点的用户会发现它不回了——画板 Q5-B 的取舍就是如此，回内容用 Shift 1。
- 本片与 esc-ladder 同 lane 串行：若 esc-ladder 最终没把回调改成公开函数 `resetCanvasZoom`，就改 core_canvas_keys.dart 里 Ctrl 0 绑定的 onInvoke，函数名以 esc-ladder 合入版为准。
- W1 canvas-capsule 会在同一函数里加「出比例胶囊」，本片合入后它 rebase 只有一行冲突。
