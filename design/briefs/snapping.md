# snapping · 拖动吸附（网格 24 + 对象参考线）+ Ctrl/⌘ 原样放下 + 两个开关
- 波次 W6 / lane A / 基底 origin/main〔W0–W5 已合入〕
- 依赖切片：group-drag（W5，拖动管线 `_filterDrag` / `_commitDrag`、`NodeDragDelta.ids`）、menu-split（W0，blank_menu_entries / menu_registry / InkMenuEntry.checked）、canvas-view-split（W0，node_card_slot / stage_overlays）、undo-node-create-move（W4）；并掉 ContextMenus 的 grid-snap 与 cm-blank-menu-additions 的「网格吸附」项
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
拖卡时，卡片左上角吸到 24 的世界网格；卡片的左 / 中 / 右缘或上 / 中 / 下缘离别的卡对应线 6 个屏幕像素以内时吸过去，并画一条琥珀参考线。拖动中按住 Ctrl（mac 为 ⌘）= 原样放下：不吸附（W7 起也不插进叙事线）。空白处右键菜单末尾多两项打勾开关「网格吸附」「对象吸附」，设置 › 节点布局里同样两个开关，记在 preferences.json。

## 设计依据
- Selection.dc.html ·「对齐 · 分布 · 排布 · 吸附」（b2_selection.js 177–214 行）：网格吸附 24（同网格底、复制偏移）；对象吸附 6 屏幕像素内出参考线；拖动中按住 Ctrl（⌘）= 原样放下：不吸、不插线（空格已是临时平移、Alt 已给切线）；吸附两个开关（空白处右键打勾 + 设置 › 节点布局），存 AppPreferences。示意图：实线参考线贴在两张卡共同的左缘，旁标「左缘」，底注「按住 Ctrl：不吸不插」。
- Selection ·「整组拖动」：Ctrl（⌘）= 原样放下：不吸附、不插进叙事线；Shift 只锁轴。
- ContextMenus.dc.html ·「空白处 · 补三项」（b2_wires.js 180–206 行）：菜单末尾分隔线后「网格吸附」打勾项；「网格吸附存 preferences.json…按住 Ctrl（⌘）拖 = 原样放下，不吸附」。
- KeyMap.dc.html · 指针表：「拖卡 + Ctrl / ⌘ = 原样放下」「拖到一半按修饰键即时生效」；mac 只认 ⌘（Ctrl 点在 mac 是右键）。
- ContextMenus 写「松手时取整」，Selection 画的是拖动中出参考线：本片按 Selection——拖动中就显示吸附后的位置，所见即所落。
- 设计缺口：网格底 `CanvasGridPainter` 是屏幕空间、不随平移缩放（canvas_grid_painter.dart:1，canvas_view.dart:710「屏幕空间，不随缩放」），而吸附只能吸世界坐标——「同网格底」在视觉上对不齐。本片只吸世界 24（= InkSpacing.lg = kDuplicateOffset，canvas_tool_actions.dart:432），不改网格底；是否让网格底改成世界空间，留给后续。
- 设计缺口：对象吸附与网格吸附同时满足时谁优先没写；本片：每个轴上对象吸附优先，没对象命中才用网格。
- 设计缺口：整组拖时按谁吸没写；本片按抓住的那张（与 Sel-Q2 B 同口径），组内相对位置不变。
- 设计缺口：示意图里还有一条半透明虚线参考线，含义未写；本片只画命中的实线。
- 设计缺口：打勾项点了之后菜单关不关没写；本片与其它项一致，点了就关。

## 允许改的文件
- 新 `lib/features/canvas/util/drag_snap.dart`：吸附纯函数 + 常量 + 原样放下的修饰键判据。
- 新 `lib/features/canvas/providers/canvas_snap_guides.dart`：拖动中的参考线状态。
- 新 `lib/core/di/canvas_snap.dart`：吸附开关控制器（照 core/di/canvas_style.dart 同模式；设置页要用，所以放 core/di 不放 features/canvas）。
- 新 `lib/features/canvas/widgets/snap_guides_layer.dart`：参考线绘制层（视口坐标）。
- `lib/features/canvas/widgets/stage/node_card_slot.dart`（由 canvas-view-split 新建，W5 group-drag 改过）：`_filterDrag` 管线加吸附 + 原样放下；`_commitDrag` 用同一结果；拖动结束清参考线。
- `lib/features/canvas/widgets/node_card.dart`：键盘处理器也对 Ctrl / Meta 变化重算（W5 只认 Shift 的话补上）；广播带 `precise`。
- `lib/features/canvas/providers/node_drag_delta.dart`：`NodeDragDelta` 加 `precise` 字段（上表 W6 未列此文件，但 W6 无人占用；已在回报中告知主 Agent）。
- `lib/features/canvas/widgets/stage/stage_overlays.dart`（由 canvas-view-split 新建）：挂 `SnapGuidesLayer`。
- 新 `lib/features/canvas/widgets/canvas_menu/snap_menu_items.dart`：`final List<CanvasMenuItemDef> snapBlankMenuItems`（两条：id `blank.snapToGrid` / `blank.snapToObjects`，scope blank，**group 70**——menu-split 在 menu_registry.dart 头注里约定的「空白处 70 吸附开关」，order 10 / 20；`build` 返回带 `checked:` 的 `InkMenuEntry`，`run(c)` 先 `c.dismiss?.call()` 再取反开关）。照 W2 undo-shortcuts-ui 的 `undo_menu_items.dart` 写法：条目自带 build / run，**不改 blank_menu_entries.dart、不加 BlankMenuAction 枚举值、不碰宿主**。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（由 menu-split 新建）：`kCanvasMenuItems` **追加一行** `...snapBlankMenuItems,`。
- `lib/core/models/app_preferences.dart`：`snapToGrid` / `snapToObjects`。
- `lib/services/file_preferences_service.dart`：只经 toMap / fromMap 落盘，预计不用改；如 InMemoryPreferencesService 有字段白名单再补。
- `lib/features/settings/widgets/canvas_appearance_section.dart`（「节点布局」页唯一的分节，settings_screen.dart:256）：两个 Switch 行 + 一行说明。
- 测试：见「测试」节；现有按精确坐标断言拖动结果的测试只加 override，不改断言。

## 不许碰的文件
- W6 其他切片：`canvas_view.dart` 骨架、`widgets/stage/stage_edge_layer.dart`、`canvas_menu/canvas_menu_host.dart`、`canvas_menu/canvas_menu_request.dart`、`canvas_menu/edge_menu_entries.dart`、`widgets/edge_toolbar.dart`、`util/edge_menu_model.dart`、`util/canvas_edge_actions.dart`、`providers/selected_edge_controller.dart`、`widgets/shortcuts/core_canvas_keys.dart`、`theme/components/ink_menu_panel.dart`、`models/commands/edge_menu_commands.dart`（cm-edge-menu）；`providers/canvas_nodes_controller.dart`、`util/canvas_node_delete.dart`、`util/delete_bridge_preview.dart`、`canvas_menu/node_menu_entries.dart`、`canvas_snackbars.dart`、`models/commands/delete_nodes_command.dart`（cm-delete-bridge）；`providers/canvas_lanes_controller.dart`、`widgets/stage/stage_lane_layer.dart`、`lane_title_bar.dart`、`lane_edit_dialog.dart`、`lane_toolbar.dart`、`canvas_tool_actions.dart`、`util/canvas_lane_actions.dart`、`models/commands/lane_edit_command.dart`（undo-lanes）；`export/*`、`shell/widgets/tabs/export_tab.dart`（export-records-recording）。
- `canvas_menu/blank_menu_entries.dart`（本片改用新文件 + 注册表一行，不碰它）。
- 也不碰：`canvas_grid_painter.dart`、`core/di/canvas_style.dart`、`theme/tokens.dart`（不新增令牌；24 用 InkSpacing.lg）、`edge_painter.dart`。
- W6 lane E 导出两片的文件：`lib/features/export/**`（含 open_export_dialog.dart、run_delivery.dart、widgets/export_video_dialog.dart、models/delivery_writer_registry.dart）、`lib/features/shell/widgets/tabs/export_tab.dart`。

## 具体改动
```dart
// drag_snap.dart
const double kSnapGridStep = InkSpacing.lg;      // 24：与 kDuplicateOffset、网格底步长同值
const double kObjectSnapScreenPx = 6;            // 屏幕像素；换世界单位 = 6 / scale
enum SnapLine { start, center, end }
@immutable
class SnapGuide {                                 // 舞台坐标；== / hashCode 按字段
  const SnapGuide({required this.vertical, required this.at, required this.from, required this.to, required this.line});
  final bool vertical; final double at; final double from; final double to; final SnapLine line;
}
typedef SnapResult = ({Offset delta, List<SnapGuide> guides});
SnapResult snapDragDelta({
  required Offset worldPosition,   // 抓住那张拖前的世界左上角
  required Rect stageRect,         // 抓住那张拖前的渲染矩形（displacedNodes 口径）
  required Offset delta,           // 锁轴之后的世界位移
  required List<Rect> others,      // 非组员、画得出来的卡的渲染矩形
  required double scale,
  required bool grid,
  required bool objects,
});
bool isPreciseDropPressed({required TargetPlatform platform, required bool control, required bool meta});
// macOS → meta；其余 → control。

// canvas_snap_guides.dart
final canvasSnapGuidesProvider = StateProvider.autoDispose.family<List<SnapGuide>, String>(…); // canvasId

// core/di/canvas_snap.dart
class CanvasSnapState { const CanvasSnapState({required this.grid, required this.objects}); final bool grid; final bool objects; }
class CanvasSnapController extends Notifier<CanvasSnapState> { void setGrid(bool v); void setObjects(bool v); }
final canvasSnapControllerProvider = NotifierProvider<CanvasSnapController, CanvasSnapState>(…);
// build 从 preferencesServiceProvider.current seed；setter 改内存态 + unawaited(update(copyWith))。

// node_drag_delta.dart
typedef NodeDragDelta = ({String nodeId, Set<String> ids, Offset delta, bool precise});

// app_preferences.dart
final bool snapToGrid;    // 默认 true；键 'canvas_snap_to_grid'
final bool snapToObjects; // 默认 true；键 'canvas_snap_to_objects'
```
- `snapDragDelta`：每个轴独立。对象：拿移动后矩形的 start / center / end 三条线和每个 other 的三条线两两比，取距离最小且 ≤ 6/scale 的那一对，delta 该轴补上差值，出一条 SnapGuide（跨两张卡的并集范围）。该轴没有对象命中且 `grid` → `round((worldPosition + delta)/24)*24 − worldPosition`。两开关都关 → 原样、guides 空。
- 插槽 `_filterDrag(raw)` 管线：`lockDragAxis`（W5）→ `precise = isPreciseDropPressed(defaultTargetPlatform, HardwareKeyboard.isControlPressed, isMetaPressed)`；`precise` 时直接返回锁轴结果并把参考线清空；否则 `snapDragDelta`，参考线**只在与上一帧不同（listEquals）时**写 provider。`others` 每帧从 nodes 控制器 + `displacedNodes`（lane_pin_geometry.dart:102）现算，去掉组员与折叠道里的卡。
- NodeCard 广播 `precise`：filter 外提供 `bool Function()? isPreciseDrop`（插槽给 `isPreciseDropPressed` 的读法），每次广播时取值。
- `_commitDrag`：位移就是 NodeCard 交上来的（已吸附 / 已原样），不再二次吸附；先清 `canvasSnapGuidesProvider`，再走 W5 的 resolveGroupDrop + moveNodes。pan cancel 也清。
- `SnapGuidesLayer(canvasId, transform)`：IgnorePointer + ValueListenableBuilder(transform) + CustomPaint，舞台坐标经 transform 换到视口，1px `colors.accent` 实线；guides 空时不画（返回 SizedBox.shrink）。挂在 stage_overlays 的浮层 Stack 最底层。
- 空白处菜单：`snap_menu_items.dart` 的两条 `CanvasMenuItemDef`（group 70，排在 50「选择 · 视图」组——即「适应视图」所在组——之后，`buildMenuGroups` 自动加分隔线），`checked:` 绑 `canvasSnapControllerProvider` 的值，`run` 里先 `c.dismiss?.call()`（关菜单 + 焦点还画布，与 selectAll 同一个 handoff）再取反。只在 menu_registry.dart 追加 `...snapBlankMenuItems,` 一行。
- 设置：canvas_appearance_section 在两组色板之后加 `Switch` 两行（照 startup_section.dart:43 的写法）+ 一行 fg5 说明 `settingsCanvasSnapHint`。
- AppPreferences：构造 / copyWith / toMap / fromMap（非 bool 或缺失 → true）/ == 都加；**hashCode 改用 `Object.hashAll([...])`**——现在 Object.hash 已 19 个参数（app_preferences.dart:232–254），加两个超过 20 的上限。

## 行为规则与边界情况
1. 默认两个开关都开（老 preferences.json 没这两个键 → 开）。
2. 网格只吸抓住那张的世界左上角到 24 的倍数；整组相对位置不变。
3. 对象吸附阈值是屏幕 6px：缩放 0.5 时世界 12 内也吸；缩放 2 时世界 3。
4. 同一轴对象命中优先于网格；两轴互不影响（x 吸对象、y 吸网格可以同时发生）。
5. 对象候选不含组员、不含折叠道里的卡；泳道里的卡按渲染位置比（含分道位移）。
6. 拖动中按下 Ctrl（mac ⌘）：不动鼠标也立即回到未吸附位置、参考线消失；松开立即恢复吸附。mac 上按 Ctrl 不算原样放下。
7. Shift + Ctrl 同时：先锁轴、不吸附。
8. 松手位置 = 松手前最后一帧显示的位置；参考线随松手 / 取消消失。
9. 参考线 provider 只在线集合变化时通知；拖动中线不变的帧不重建参考线层，也不碰任何卡片。
10. 打勾项切换立即生效于下一次拖动并落盘；设置页和菜单显示同一个状态。
11. 换道判定用吸附后的位移（吸附在 resolveCardDrop 之前）；吸附把卡吸回原带时就不换道。
12. 撤销：一次拖动仍是一步 MoveNodesCommand，吸附不额外进栈。
13. 落盘失败：内存态照用（与 CanvasStyleController 同口径），不提示。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasBlankMenuSnapToGrid | Snap to grid | 网格吸附 |
| canvasBlankMenuSnapToObjects | Snap to objects | 对象吸附 |
| settingsCanvasSnapToGrid | Snap cards to grid | 卡片吸附网格 |
| settingsCanvasSnapToObjects | Snap cards to other cards | 卡片吸附其他卡片 |
| settingsCanvasSnapHint | Hold Ctrl (⌘ on Mac) while dragging to drop exactly where you let go. | 拖动时按住 Ctrl（mac 为 ⌘）可原样放下、不吸附。 |

## 测试
- `test/features/canvas/util/drag_snap_test.dart`（新）：
  - `网格：世界 (10,10)+(30,5) → 落在 (48,24)`
  - `对象 scale 1：左缘差 5 → 吸齐，出一条 vertical guide；差 7 → 不吸`
  - `对象 scale 0.5：世界差 11 → 吸；差 13 → 不吸`
  - `中心对中心也吸`
  - `对象优先于网格（同一轴两者都满足时取对象）`
  - `两开关都关 → delta 原样、guides 空`
  - `isPreciseDropPressed：macOS 只认 meta；windows 只认 control`
- `test/core/models/app_preferences_test.dart`（追加）：`默认两开关 true`；`往返`；`缺失 / 非 bool → true`；`== 与 hashCode 区分 snapToGrid`。
- `test/services/file_preferences_service_test.dart`（追加）：`写 snapToGrid=false 后重新 load 仍为 false`。
- `test/features/canvas/widgets/canvas_snap_test.dart`（新；夹具照 canvas_lane_drag_test.dart，两张自由卡）：
  - `拖到左缘差 4px：拖动中出现参考线，松手 moveNodes 的位移让两张左缘相等；松手后参考线消失`
  - `按住 Ctrl 拖（windows）：落在原始位置、不出参考线、广播 precise=true`
  - `debugDefaultTargetPlatformOverride = macOS：按 ⌘ 原样；按 Ctrl 照常吸`
  - `拖动中按下 Ctrl 不动鼠标：卡片立即回到原始位置`
  - `空白处右键：两项打勾；点「Snap to grid」→ 控制器变 false、InMemoryPreferencesService 里 snapToGrid=false、再开菜单不打勾`
  - `两个开关都关 → 落在原始位置`
  - `参考线不变的 5 帧里 canvasSnapGuidesProvider 不通知`（container.listen 计数）
- `test/features/settings/canvas_appearance_section_test.dart`（追加）：`两个 Switch 反映控制器值；点击切换并落偏好`。
- 现有拖动断言精确坐标的测试（至少 canvas_lane_drag_test.dart、canvas_group_drag_test.dart、node_card_drag_test.dart 经插槽的用例；执行时 grep `moveNode` / `moveNodes` 断言）：在 ProviderScope 里 override `canvasSnapControllerProvider` 为两项都关，不改断言。

## 变异点
1. 对象阈值不除 scale → `对象 scale 0.5` 红。
2. 对象 / 网格优先级对调 → `对象优先于网格` 红。
3. isPreciseDropPressed 在 mac 用 control → `macOS 只认 meta` 与集成 mac 用例红。
4. fromMap 缺省退 false → `缺失 / 非 bool → true` 红。
5. hashCode 漏 snapToGrid → `== 与 hashCode` 红。
6. `_filterDrag` 去掉 precise 旁路 → `按住 Ctrl 拖` 红。
7. 松手不清参考线 → `松手后参考线消失` 红。
8. 参考线每帧无条件写 provider → `5 帧不通知` 红。
9. 打勾项 checked 写死 true → `再开菜单不打勾` 红。
10. NodeCard 键盘处理器只认 Shift → `拖动中按下 Ctrl 不动鼠标` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas test/core/models test/services test/features/settings`；逐条变异。
- 截图：CanvasView 两张自由卡，拖第二张到左缘差 4px（截参考线）；按住 Ctrl 同一位置（截无线）；空白处右键菜单（截两个打勾项）；设置 › 节点布局（截两个开关 + 说明）。

## 风险与不确定
- （复核已定）menu-split 的注册表条目自带 `build` / `run`，宿主只按 `menuItemForPick` 派发，本片用新文件 + 注册表一行即可，不碰 canvas_menu_host.dart（W6 归 cm-edge-menu）与 blank_menu_entries.dart。
- node_drag_delta.dart 不在约定表 W6 栏里（无人占用），加 `precise` 字段会改动 W5 的记录字面量；W7 cm-drag-insert 读这个字段。
- 默认开网格吸附会让现有所有按像素断言的拖动测试偏移，必须逐个加 override；漏一个就是 CI 红。
- （复核补充·同波测试文件）W6 cm-delete-bridge 也要改 `test/features/canvas/widgets/canvas_view_test.dart`、`canvas_node_menu_test.dart`、`canvas_create_menu_test.dart`、`test/_harness/fake_canvas.dart`（NodeDeletion 记录字面量），undo-lanes 改 `canvas_lane_integration_test.dart`。本片若 grep 出这些文件里也有按像素断言的拖动，只在它们的 ProviderScope overrides 里**追加一行** `canvasSnapControllerProvider` 关吸附的 override，不动别的行，并在回报里点名，由主 Agent rebase 时合并；`fake_canvas.dart` 本片不碰。
- 网格底屏幕空间与世界吸附对不齐（见设计缺口），用户会看到「吸了但没对上格子」。
