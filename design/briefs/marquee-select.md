# marquee-select · 左键拖空白 = 框选（Shift 加选、Ctrl/⌘ 反选），Esc 取消并恢复；中键拖平移
- 波次 W3 / lane B / 基底：叠在 canvas-view-split、multi-select-core、esc-ladder 之后（从合入了这三片的 origin/main 起）
- 依赖切片：canvas-view-split（stage/ 文件）、multi-select-core（selection_geometry + 选中控制器批量方法）、esc-ladder（EscapeRungId.marquee 空位 + canvasEscapeLadderProvider）；合并了 canvas-pointer-pan-axis 的「中键拖平移」（锁轴不在本片，归 group-drag）
- 阻塞决定：无（Selection Q1、Q7 未拍板，按建议走）

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
选择工具下用鼠标左键在画布空白处（含泳道底色）拖动，拉出一个金色细框，碰到的卡实时被选中，框右下角挂「已选 N」；Shift 拖 = 加选，Ctrl 拖（mac 用 ⌘）= 反选。拖动中按 Esc 收起框并恢复按下前的选中。
**有意的行为变化**：鼠标左键拖空白不再平移画布；平移改走 H / 按住空格 / 右键拖 / 中键拖 / 触控板双指。拖不到 4px 松手仍算点空白（清空选中 / 点中连线）。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- Selection.dc.html「框选与加减选 · 选择工具下在空白处拖」：左键拖空白 = 框选；拖框不按键替换、Shift 加选、Ctrl（mac ⌘）反选；点卡 Shift / Ctrl / ⌘ 都是切换（canvas_view 现状）；碰到框就算；折叠泳道里的卡不参与；便签、文本照常可选；移动不到 4px 算点空白 = 清空；贴边自动平移；Esc 取消框选并恢复原选中；泳道底色算空白，标题栏起拖仍是拖泳道；连线模式不起框。样稿：框 = 1px accent 边 + accent 8% 底、圆角 1；「已选 3」芯片 = 高 18、左右内边距 7、胶囊、surface4 底 + overlayBorder 边、fg2 等宽 10 号，压在框右下角。
- KeyMap.dc.html「指针」表：左键拖空白 = 框选；Shift 拖框 加选；Ctrl / ⌘ 拖框 反选；右键拖 = 平移（已上线）；中键拖 = 平移（第二批）；右键点 = 松开时开右键菜单（已上线）；「4px 内松开算点」；「拖到一半按修饰键即时生效」。「Esc 阶梯」第 5 档：进行中的手势（拖线 · 框选），「框选中 Esc 恢复按下前的选中」。
- critic.txt 第二节第 2 条：点卡修饰键现状是切换（`_CanvasBody._handleNodeTap`）→ 按建议：Selection Q7 → A（保持切换，本片不改点卡逻辑）；mac 上框选反选用 ⌘（Ctrl+点在 mac 是右键）。
- 按建议：Selection Q1 → A（碰到即算；判据在 multi-select-core 的 `marqueeHits`）。
- 设计缺口：触摸屏 / 触控笔单指拖空白是框选还是平移——没画；本片只对 `PointerDeviceKind.mouse` 起框，其余设备保持现状（平移）。
- 设计缺口：Shift 与 Ctrl/⌘ 同时按住的模式没写；本片定为反选优先。
- 设计缺口：起框时已选中的连线怎么办没写；本片定为起框即清掉选中连线（与点空白一致），Esc 不恢复连线选中。
- 设计缺口：贴边自动平移的触发区宽度、速度没写；本片定为距视口边 24 内触发，每帧最多 12 屏幕 px，越靠边越快。
- 设计缺口：右键 / 中键拖平移时的光标（grab / grabbing）没画；本片不改光标。
- 设计缺口：Esc 取消后指针仍按着继续拖——没写；本片定为不重新起框，松手也不算点。

## 允许改的文件（逐个路径 + 每个文件改什么）
- `lib/features/canvas/widgets/stage/stage_pointer_layer.dart`（由 canvas-view-split 新建）：新增 `MarqueeGestureRecognizer` 与 `StageMarqueeDetector`（包在 `BlankPointerDetector` 里面、连线层 GestureDetector 外面）；不改 `BlankPointerDetector` / `SecondaryClickDetector` / `StagePanGate` / `StagePanCursor` 的现有逻辑。
- `lib/features/canvas/widgets/canvas_view.dart`（骨架）：在 `_CanvasStage` 里把连线层包进 `StageMarqueeDetector`（回调：起框 / 更新 / 结束 / 点），点的回调复用现有 `onEdgeLayerTap` 的判据（压着连线 = 选连线，否则 `onEmptyTap`）；在 LayoutBuilder 的 Stack 末尾加 `Positioned.fill(IgnorePointer(MarqueeLayer(...)))`；`_CanvasStage` 本身不 watch `canvasMarqueeProvider`。不改 `_CanvasBody._handleNodeTap`。
- `lib/features/canvas/widgets/marquee_layer.dart`（新）：画框与「已选 N」芯片；持有贴边自动平移的 Ticker；登记 / 注销 Esc 阶梯的 marquee 档；修饰键实时监听。
- `lib/features/canvas/providers/canvas_marquee.dart`（新）：`canvasMarqueeProvider` + `CanvasMarqueeController` + `MarqueeState`。
- `lib/features/canvas/providers/canvas_tool_mode.dart`：**默认不改**。只有当「中键拖平移」用例在不加代码时为红、且自实现需要一个临时平移来源时才追加（不改现有三个 provider 的语义）。
- `lib/theme/tokens.dart`：只追加常量类 `InkMarquee`（见下）。
- 测试：`test/features/canvas/widgets/canvas_marquee_test.dart`（新）、`test/features/canvas/providers/canvas_marquee_test.dart`（新）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- undo-adopt-existing：`stage/stage_edge_layer.dart`、`stage/node_card_slot.dart`、`util/canvas_node_delete.dart`、`util/canvas_snackbars.dart`、`node_inputs_section.dart`、`models/commands/*`、`canvas_lane_drag_test.dart`。
- tc-set-current：`providers/current_take_controller.dart`、`inspector_history_panel.dart`、`image_result_inspector.dart`、`video_result_inspector.dart`、`result_inspector_parts.dart`、`node_card.dart`、`canvas_menu/set_current_menu_items.dart`、`job_notification_listener.dart`、`export_video_dialog.dart`、`canvas_node_menu_test.dart`。
- import-media-command：`shortcuts/import_media_keys.dart`、`util/canvas_import_actions.dart`、`canvas_menu/import_media_menu_items.dart`。
- help-actions：`app_actions/help_actions.dart`、`left_rail/help_menu_popover.dart`、`left_rail/canvas_left_rail.dart`、`settings/**`、`startup/**`。
- 另外：`canvas_shortcuts.dart`、`shortcuts/**`、`providers/canvas_escape_ladder.dart`、`util/escape_ladder.dart`（只调 register / unregister，不改）、`util/selection_geometry.dart`、`canvas_selection_controller.dart`（只调用）、`shortcut_catalog.dart`、`stage/stage_lane_layer.dart`、`stage/stage_overlays.dart`。
- （主 Agent 自查补充）help-actions：`lib/core/constants/app_repo.dart`（新）、`lib/theme/components/ink_menu_panel.dart`（只加可选 `tooltip`）、`lib/theme/primitives/ink_activatable.dart`（只加可选 `focusNode`）、`lib/features/settings/widgets/diagnostics_section.dart`、`lib/features/startup/widgets/startup_error_view.dart`、`lib/services/github_update_check_service.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// providers/canvas_marquee.dart
const double kMarqueeClickSlop = 4; // 屏幕逻辑 px：按下到松手没超过它 = 点
@immutable class MarqueeState {
  const MarqueeState({required this.startStage, required this.currentStage, required this.before, required this.mode, required this.selectedCount});
  final Offset startStage; final Offset currentStage; final Set<String> before; final MarqueeMode mode; final int selectedCount;
  Rect get stageRect => Rect.fromPoints(startStage, currentStage);
}
final canvasMarqueeProvider = AutoDisposeNotifierProviderFamily<CanvasMarqueeController, MarqueeState?, String>(...);
class CanvasMarqueeController extends AutoDisposeFamilyNotifier<MarqueeState?, String> {
  void begin(Offset startStage);                                        // 快照 before = 当前选中；清选中连线
  void update(Offset currentStage, {required MarqueeMode mode, required Set<String> hits}); // selection.replace(applyMarquee(before, hits, mode))
  void commit();                                                        // state = null，选中保持
  bool cancel();                                                        // selection.replace(before ∩ 现存节点 id)；state = null；原来不在框选中返回 false
}
MarqueeMode marqueeModeFor({required bool shift, required bool control, required bool meta, required TargetPlatform platform}); // mac: meta→invert；其余: control→invert；再 shift→add；否则 replace

// widgets/stage/stage_pointer_layer.dart（追加）
class MarqueeGestureRecognizer extends OneSequenceGestureRecognizer {
  MarqueeGestureRecognizer({required bool Function(PointerDownEvent) shouldClaim}); // 只收 kind == mouse && buttons == kPrimaryButton；shouldClaim 为真即 resolve(accepted)
  GestureDragStartCallback? onStart; GestureDragUpdateCallback? onUpdate; VoidCallback? onEnd; ValueChanged<Offset>? onClick; VoidCallback? onCancel;
}
class StageMarqueeDetector extends StatefulWidget {
  const StageMarqueeDetector({super.key, required bool Function() enabled, required ValueChanged<Offset> onStart, required void Function(Offset stagePoint, Offset globalPoint) onUpdate, required VoidCallback onEnd, required ValueChanged<Offset> onClick, required Widget child});
} // 回调坐标 = 本层局部坐标 = 舞台坐标；enabled 读 linkMode == null（W17 cm-knife-cut 会在这里加 Alt 旁路）

// widgets/marquee_layer.dart
class MarqueeLayer extends ConsumerStatefulWidget {
  const MarqueeLayer({super.key, required String canvasId, required TransformationController transform, required Size viewport});
}

// theme/tokens.dart（追加）
abstract final class InkMarquee {
  static const double borderWidth = 1, radius = 1, fillAlpha = 0.08;
  static const double chipHeight = 18, chipPaddingH = 7, chipOverlap = 6; // 芯片下沿比框下沿低 6
  static const double autoPanZone = 24, autoPanMaxStep = 12;
}
```
状态机（每根鼠标左键指针）：`idle` →（按下在空白、选择工具、非连线模式、非平移）`pressed`（识别器当场胜出，InteractiveViewer 与连线层单击都让位）→ 移动距按下点 ≥ 4 ⇒ `marquee`（begin + 首次 update）；松手且始终 < 4 ⇒ 回调 `onClick(按下点)` → `idle`。`marquee` 中：指针移动 / 修饰键变化 / 自动平移每帧 ⇒ update；松手 ⇒ commit → `idle`；Esc ⇒ cancel → `cancelled`（后续移动忽略，松手不算点）→ `idle`。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 只在：选择工具、未在平移（H / 空格时舞台整层在 `StagePanGate` 下不收指针，自然不起框）、不在连线模式、鼠标左键、按在舞台空白（连线层 = 卡片没盖住的地方）时接管；泳道底色在 InteractiveViewer 之外且不收指针，按在底色上就是按在舞台空白。
2. 泳道标题栏 / 分界线在单独一层，按在上面仍是拖泳道 / 调道宽；卡片上按下仍是拖卡（卡盖住的地方到不了空白层）。
3. 起框阈值 4 屏幕 px（`kMarqueeClickSlop`，与 KeyMap「4px 内松开算点」一致）：没过阈值松手 = 点空白——压着连线就选中连线，否则清空选中 / 选中连线、退出连线模式（现有 `onEmptyTap`）。
4. 框是舞台坐标：起点钉在世界里，缩放 / 平移 / 自动平移时框跟着内容走；命中每次按当前 transform 用 `marqueeHits(…, collapsedLaneIds: 折叠集)` 重算。
5. 模式按修饰键实时算（拖到一半按 / 松 Shift、Ctrl、⌘ 立即重算，不等指针再动）：replace = hits；add = before ∪ hits；invert = before △ hits。mac：⌘ = 反选，Ctrl 不参与；Windows：Ctrl = 反选。两者都按 → 反选优先。
6. 选中在拖动中实时写回选中控制器（`replace`），「已选 N」= 写回后的选中数（add / invert 时含 before）；顶部右侧原有的计数 chip 照常随选中变化。
7. 起框时清掉选中连线；Esc 恢复的只有节点选中（before 里已被删掉的节点 id 先滤掉）。
8. Esc：marquee 档在 `EscapeRungId.marquee`（菜单 / @ / 查找 / 输入框 / 拖线之后，连线模式 / 工具锁 / 平移工具 / 清空选中之前）；一次 Esc 只收框并恢复，不再往下清空选中；再按一次 Esc 才清空。
9. 贴边自动平移：框选中且指针距视口任一边 < 24 时，每帧按 `autoPanMaxStep × (1 − 距离 / 24)`（至少 1）把相机往那一侧挪，框的当前点按指针全局坐标重新换算成舞台坐标并重算命中；指针离开触发区、松手、Esc 即停（Ticker 停）。
10. 右键：不受影响——识别器不收次键；右键单击仍在抬起时开菜单（`SecondaryClickDetector`），右键拖仍是平移。
11. 中键拖空白 / 卡上：平移相机，不改选中、不开菜单。先写用例；若 InteractiveViewer 现有识别器已接中键（用例不加代码就绿），不加任何代码并在回报里写明；否则在 `StageMarqueeDetector` 旁加原始指针监听按位移平移 `transform`。
12. 触控板双指平移 / 捏合、滚轮缩放、触摸单指拖：保持现状（识别器只收鼠标）。
13. 双击空白开新建菜单（`BlankPointerDetector` 用原始指针事件，不进竞技场）照常；第二下按下开菜单后、松手时的「点」照常清空选中，菜单不关。
14. 点卡修饰键（Shift / Ctrl / ⌘ = 切换）不改（Q7-A）。
15. 框选进行中节点集变化（别处删了节点 / job 完成刷新）：下一次 update 用新节点集重算，被删的 id 不会留在选中里。
16. `_CanvasStage` / 卡片插槽不 watch `canvasMarqueeProvider`：拖框只重建 `MarqueeLayer` 与选中翻转的那几张卡。
17. 框选不进撤销栈（选中是 UI 态）；画布切换 / 卸载时 `MarqueeLayer.dispose` 注销 Esc 档并停 Ticker，autoDispose 回收状态。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| canvasMarqueeCount | {count} selected | 已选 {count} |

（`@canvasMarqueeCount` 的 placeholders 照 `canvasSelectionCount` 写：`count` 为 int。）

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
`test/features/canvas/widgets/canvas_marquee_test.dart`（新；harness 照 canvas_pan_tool_test 的 `_pump`：三张卡 a (0,0)、b (300,0)、c (0,400) 无道，再加一条横向泳道 L1 折叠时装着 d；所有拖动用 `kind: PointerDeviceKind.mouse`）：
- 「左键拖空白框住 a、b：两张被选中，相机不动」：从 a 左上外 20px 拖到 b 右下内侧；选中 == {a,b}；`_ivTransform` 前后相等。
- 「拖动中出框与『已选 2』；松手框消失、选中保留」：拖到一半 pump，`find.text('2 selected')` 在 MarqueeLayer 里一个；up 后 `find.byType(MarqueeLayer)` 内无框。
- 「只碰到一角也选中（Q1-A）」。
- 「Shift 拖框 = 加选」：先选 c，按住 Shift 框 a → {a,c}。
- 「Windows：Ctrl 拖框 = 反选」：`debugDefaultTargetPlatformOverride = windows`，先选 {a,b}，Ctrl 框 b、c → {a,c}。
- 「mac：⌘ 拖框 = 反选；Ctrl 不算反选」：platform = macOS，Meta 同上 → {a,c}；换成 Ctrl → 结果 = replace。
- 「拖到一半按下 Shift：不动指针也立即变加选」。
- 「Esc：框收起，选中恢复成按下前；再按 Esc 才清空」：先选 c，拖框盖 a（选中变 {a}），Esc → {c}、框消失；继续移动 / 松手选中仍 {c}；再 Esc → {}。
- 「移动 3px 松手 = 点空白：清空选中」：先选 a，按下移 3px 松手 → {}，相机不动。
- 「移动 5px 就起框」：同上移 5px → MarqueeLayer 出框。
- 「点在连线上（< 4px）：选中这条连线」：两卡间一条 data 边，点其中点 → selectedEdgeControllerProvider == 边 id。
- 「连线模式下拖空白：不起框」：linkModeController.start('a') 后拖 → 无框，选中不变。
- 「折叠道里的卡框不中」：框盖住 L1 折叠轨 → d 不在选中里。
- 「泳道底色上起拖也是框选；标题栏上起拖仍是拖泳道」：底色上起拖出框；标题栏上起拖 → 泳道 reorder / 无框。
- 「平移工具 / 按住空格时左键拖空白：仍是平移」：相机变、无框。
- 「右键拖空白：平移，不开菜单；右键单击：抬起开空白处菜单」：`CanvasMenuKeys.blankMenu` 断言同 canvas_create_menu_test 口径。
- 「中键拖空白：相机平移、选中不变、不开菜单」（`buttons: kMiddleMouseButton`）。
- 「触摸单指拖空白：仍平移（不起框）」（默认 kind = touch）。
- 「贴边自动平移：指针停在视口右缘内 4px，pump 10 帧，相机往左移、视口外的卡 e 被框进来」。
- 「双击空白仍开新建菜单」（鼠标两下原地点）。
`test/features/canvas/providers/canvas_marquee_test.dart`（新，ProviderContainer）：
- 「begin 快照 before、清选中连线」；「update 按模式写回选中，selectedCount 正确」；「cancel 恢复 before 并滤掉已删节点，返回 true；未在框选时返回 false」；「commit 后 state 为 null、选中保留」；「marqueeModeFor 四个平台 × 修饰键组合」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写，每条注明哪条测试抓住它）
1. `stage_pointer_layer.dart` `MarqueeGestureRecognizer` 的阈值 `kMarqueeClickSlop` 改成 0 → 「移动 3px 松手 = 点空白：清空选中」红。
2. 识别器不在按下时 `resolve(accepted)`（改成过阈值才接）→「左键拖空白框住 a、b：…相机不动」红（InteractiveViewer 先抢走平移）。
3. 识别器的设备过滤去掉 `kind == mouse` →「触摸单指拖空白：仍平移（不起框）」红。
4. 识别器去掉 `buttons == kPrimaryButton` 过滤 →「右键拖空白：平移，不开菜单；右键单击：抬起开空白处菜单」红。
5. `StageMarqueeDetector.enabled` 恒 true（不看连线模式）→「连线模式下拖空白：不起框」红。
6. 骨架里点的回调直接调 `onEmptyTap`（不先 hitTest 连线）→「点在连线上（< 4px）：选中这条连线」红。
7. `marqueeModeFor` 在 mac 上把 control 也当反选 →「mac：⌘ 拖框 = 反选；Ctrl 不算反选」红；把 mac 的 meta 判断删掉 → 同一条红。
8. `MarqueeLayer` 不监听键盘、只在指针移动时重算模式 →「拖到一半按下 Shift：不动指针也立即变加选」红。
9. `CanvasMarqueeController.cancel` 不恢复 before（只清 state）→「Esc：框收起，选中恢复成按下前…」红、providers 测试「cancel 恢复 before…」红。
10. Esc 档登记成 `EscapeRungId.selection`（或不登记）→「Esc：…再按 Esc 才清空」红。
11. cancel 之后不进 `cancelled` 态（继续移动又起框）→「Esc：…继续移动 / 松手选中仍 {c}」红。
12. `marqueeHits` 调用不传 collapsedLaneIds →「折叠道里的卡框不中」红。
13. 自动平移 Ticker 不启动 →「贴边自动平移…」红。
14. `cancel` 不滤已删节点 → providers 测试「cancel 恢复 before 并滤掉已删节点」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test` 零告警；`flutter test test/features/canvas test/features/shell test/quality --exclude-tags golden` 全绿（canvas_create_menu_test、canvas_pan_tool_test、lane_interactions_test 的触摸拖动用例不得回归）。
- 截图（`test/_harness/screenshot.dart` 的 `pumpScreenshotScene` + `captureToPng`，中文界面）：widget = `CanvasView`（canvasId c1，1280×800 视口）；数据 = 示例两镜（「镜头 01」图像配置 + 成片、「镜头 02」视频配置）+ 「远山参考」图像，另一条折叠泳道。截四个状态：① 拖框进行中、碰到三张卡，芯片「已选 3」；② Shift 加选中途（before 1 张 + 框 2 张）；③ Esc 之后（框消失、恢复原选中）；④ 框贴视口右缘、自动平移中。

## 风险与不确定
- 关键假设：InteractiveViewer 的缩放识别器与本片识别器同在竞技场时，本片在按下时宣布胜出即可压住左键平移，而触控板 PointerPanZoom 事件不经过它（双指平移不受影响）。用例「左键拖空白…相机不动」「触摸单指拖空白：仍平移」守着；若实测双指平移受影响，回报里写明，不要改成 `panEnabled: false`（那会关掉触控板平移）。
- 中键是否已由 InteractiveViewer 接管未实测（canvas_create_menu_test 证明它接次键）；按规则 11 先写用例再决定。
- 鼠标左键点空白的「点」从按下时（原连线层 onTapDown）挪到了松手时；双击、右键菜单、点外面关菜单的现有用例要全绿才算过。
- W17 cm-knife-cut 要在 `StageMarqueeDetector.enabled` / `shouldClaim` 上加 Alt 旁路；W19 tool-lock 也改本文件——接口留成谓词就是为它们。
