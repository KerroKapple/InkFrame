# canvas-capsule · 画布轻提示胶囊（InkCanvasCapsule + CanvasCapsuleHost + canvasCapsuleProvider），接上键盘缩放和「适应」的比例提示
- 波次 W1 / lane C / 基底 origin/main（届时已含 W0 全部；本片改 esc-ladder 新建的 `shortcuts/core_canvas_keys.dart`，以及 zoom-reset-100 改过的 Ctrl 0 那一项，所以必须在 esc-ladder + zoom-reset-100 合入之后起分支）；依赖切片：esc-ladder、zoom-reset-100；阻塞决定：无。并掉 canvas-hint-capsule（UndoClipboard）。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/canvas-capsule`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
- 画布舞台底部居中出现一枚「我刚做了什么」的小胶囊：本画布专用、一次一条、自己消失，不进铃铛。
- 本片先接一种内容：键盘缩放（Ctrl/⌘ + / − / 0）和「适应全部 / 适应选中」（Shift 1 / Shift 2、缩放条「适应」、空白处「适应视图」）后显示「缩放 80%」；滚轮 / 捏合不显示。
- 后续切片（撤销反馈、已新开分叉、已接到第 N 镜之后、按剧本拆镜…）只需 `show(CanvasCapsuleMessage(...))`。

## 设计依据
- GapsCanvas.dc.html ›「画布轻提示胶囊」（「我刚做了什么」，只在本画布，不进铃铛）：
  - 组件：theme 层 InkCanvasCapsule（纯展示）+ CanvasCapsuleHost + canvasCapsuleProvider(canvasId)；**高 28、全圆角、s4 底（surface4）、overlayBorder 描边**。
  - 位置：舞台水平居中；提示词条显示时在条子上方 8（canvasPromptBarHeight），收起时离舞台底 16；**两侧让出缩放条 + 16**，超出省略号；查找条在顶部，互不避让。
  - 最多 1 条：新的立刻顶掉旧的（交叉淡入 120ms）；同 dedupeKey（如缩放）原地改字、重新计时。
  - 停留：纯文字 2 秒、带动作 4 秒、缩放 1.2 秒（最后一次变化后）；悬停停表；不跟通知的停留设置。
  - 缩放比例只在键盘缩放和「适应」时出，滚轮捏合不出（缩放条一直在显示）。
  - 不用于错误（通知卡）和删除撤销（8 秒撤销卡）；不出声，读屏 polite 播一次；换标签、关画布即收；不进 Esc 链和 Tab 序。
  - 样稿四种：「已撤销 · 移动 3 个节点 [重做 Ctrl Y]」「缩放 80%」「已新开分叉 · 在 02 之后」「已接到第 7 镜之后」。
- UndoClipboard.dc.html ›「撤销 / 重做」：「反馈只走画布底部胶囊」；动作按钮旁带键位提示（重做 Ctrl Y）。
- plan.md §3 W1：一次只有一条；位置贴在提示词条上方 8；滚轮缩放不出提示。
- 设计缺口：画板没画「舞台太窄、两侧让位后放不下」的样子 → 本片定：可用宽 < `InkCanvasCapsuleSize.minWidth`（96）时不画（计时照走）。画板也没写动作按钮能否键盘触达 → 按「不进 Tab 序」只给鼠标，键盘用户走该动作的快捷键（胶囊上写出键位）。

## 允许改的文件
- `lib/theme/components/ink_canvas_capsule.dart`（新）：`InkCanvasCapsule` 纯展示，不 import features。
- `lib/theme/tokens.dart`：只追加常量——`InkToolbarSize.zoomBarWidth = 143`、`InkToolbarSize.zoomBarPercentCell = 46`；新类 `InkCanvasCapsuleSize { height = 28; stageBottom = 16; promptBarClearance = 24 /* 条子 bottom 16 + 间隙 8 */; sideReserve = 171 /* 缩放条 left 12 + 宽 143 + 16 */; minWidth = 96; }`（注释写清每个数怎么来的，禁止 widget 里对 token 加减）。
- `lib/features/canvas/providers/canvas_capsule.dart`（新）：provider + 控制器 + 消息类型 + `showZoomCapsule`。
- `lib/features/canvas/widgets/canvas_capsule_host.dart`（新）：定位、悬停、可见性、交叉淡入。
- `lib/features/canvas/widgets/canvas_screen.dart`：舞台 Stack 里在 `CanvasPromptBar` 之后、`CanvasToolbar` 之前挂 `CanvasCapsuleHost(canvasId:, visible: isVisible)`。
- `lib/features/canvas/widgets/canvas_zoom_bar.dart`：百分比格改成固定宽 `InkToolbarSize.zoomBarPercentCell`（居中），整条外包 `SizedBox(width: kCanvasZoomBarWidth)`；导出 `const double kCanvasZoomBarWidth = InkToolbarSize.zoomBarWidth;`。缩放条自己的 +/− 不出胶囊（条上已显示比例）；「适应」格走 fitAllNodes，自然出胶囊。
- `lib/features/canvas/widgets/shortcuts/core_canvas_keys.dart`（由 esc-ladder 新建）：在 esc-ladder 公开的 `zoomCanvasBy(ref, canvasId:, factor:)` 与 `resetCanvasZoom(ref, canvasId:)`（zoom-reset-100 改成 actualSizeTransform）末尾调 `showZoomCapsule(ref, canvasId: canvasId)`——键盘缩放与 ⌘K 的缩放动作（app-action-table 也调这两个函数）都出比例；缩放条的 +/− 保持自己的本地 `zoom()`，**不得**改调 `zoomCanvasBy`。
- `lib/features/canvas/util/canvas_tool_actions.dart`：只在 `_fitNodes` 里两处写 `transform.value = ...` 之后调 `showZoomCapsule(ref, canvasId: canvasId)`（适应全部 / 适应选中共用）；不改其它函数。
- 测试（新）：`test/theme/components/ink_canvas_capsule_test.dart`、`test/features/canvas/providers/canvas_capsule_test.dart`、`test/features/canvas/widgets/canvas_capsule_host_test.dart`、`test/features/canvas/widgets/canvas_capsule_zoom_test.dart`；改：`test/features/canvas/widgets/canvas_zoom_bar_test.dart`（固定宽）、`test/features/canvas/widgets/canvas_screen_layout_test.dart`（加一条位置用例）。

## 不许碰的文件
- nodes-batch-ops：`providers/canvas_nodes_controller.dart`、`util/canvas_node_delete.dart`。
- narrative-splice：`providers/canvas_edges_controller.dart`、`util/narrative_splice.dart`。
- current-take：`util/node_artifacts.dart`、`command_palette/palette_search.dart`、`util/create_menu_model.dart`、`util/outline_model.dart`、`features/export/**`、`models/canvas_node_take.dart`。
- app-action-table：`lib/features/app_actions/**`、`command_palette/command_actions.dart`、`settings/util/shortcut_catalog.dart`、`widgets/canvas_toolbar.dart`、`util/more_menu_model.dart`。
- 也不碰 `canvas_view.dart` / `stage/*`（滚轮缩放在 InteractiveViewer 里，本片**不**接它）、`canvas_shortcut_registry.dart`（本片不加新键）、`notifications/**`（胶囊不走 ToastService）。
- （主 Agent 自查补充）current-take：`lib/features/canvas/widgets/left_rail/outline_panel.dart`、`lib/core/constants/take_keys.dart`（新）。
- （主 Agent 跨批核对补充）current-take 另改：`lib/features/storyboard/util/sequence_builder.dart`、`lib/features/storyboard/models/sequence_shot.dart`、`lib/features/sequence/models/sequence_lens.dart`、`lib/features/gallery/util/gallery_meta.dart`、`lib/features/export/open_export_dialog.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/command_palette/palette_search.dart`。

## 具体改动
```dart
// lib/theme/components/ink_canvas_capsule.dart
class InkCanvasCapsule extends StatelessWidget {
  const InkCanvasCapsule({super.key, required this.text, this.actionLabel, this.actionHint, this.onAction});
  final String text; final String? actionLabel; final String? actionHint; final VoidCallback? onAction;
} // 高 28、InkRadius.pill、surface4 底、overlayBorder 1px；文字 meta fg2 单行省略；动作 = accent 文字（+ fg5 键位），包 ExcludeFocus；Semantics(liveRegion: true, container: true)

// lib/features/canvas/providers/canvas_capsule.dart
enum CanvasCapsuleKind { text, action, zoom }          // 停留 2s / 4s / 1.2s
const Duration kCanvasCapsuleTextDwell, kCanvasCapsuleActionDwell, kCanvasCapsuleZoomDwell;
const String kCanvasCapsuleZoomKey = 'zoom';
class CanvasCapsuleMessage {
  const CanvasCapsuleMessage({required this.text, this.kind = CanvasCapsuleKind.text, this.dedupeKey, this.actionLabel, this.actionHint, this.onAction});
  const CanvasCapsuleMessage.zoom(int percent);       // text '', kind zoom, dedupeKey kCanvasCapsuleZoomKey, zoomPercent = percent
  final String text; final CanvasCapsuleKind kind; final String? dedupeKey;
  final String? actionLabel; final String? actionHint; final VoidCallback? onAction;
  final int? zoomPercent;                             // 非空时宿主用 l.canvasCapsuleZoom(zoomPercent) 渲染，忽略 text
}
final canvasCapsuleProvider = AutoDisposeNotifierProviderFamily<CanvasCapsuleController, CanvasCapsuleMessage?, String>(CanvasCapsuleController.new, name: 'canvasCapsuleProvider');
class CanvasCapsuleController extends AutoDisposeFamilyNotifier<CanvasCapsuleMessage?, String> {
  void show(CanvasCapsuleMessage m);   // 顶掉旧的；同 dedupeKey ⇒ 原地换字 + 重新计时
  void showZoom(double scale);         // show(CanvasCapsuleMessage.zoom((scale * 100).round()))
  void dismiss();
  void setHovered(bool hovered);       // true 停表（记剩余），false 按剩余续跑
}
void showZoomCapsule(WidgetRef ref, {required String canvasId}); // 读 canvasTransformControllerProvider 的 scaleOf → showZoom

// lib/features/canvas/widgets/canvas_capsule_host.dart
class CanvasCapsuleHost extends ConsumerWidget/StatefulWidget {
  const CanvasCapsuleHost({super.key, required this.canvasId, this.visible = true});
}
```
- 控制器计时：一个 `Timer`（ref.onDispose 取消）；停留由 kind 决定（带 actionLabel 的 text 也按 action 4s：kind 以调用方传为准，`actionLabel != null` 时 debug assert kind == action）。
- 宿主：`Positioned(left: InkCanvasCapsuleSize.sideReserve, right: 同, bottom: h > 0 ? h + InkCanvasCapsuleSize.promptBarClearance : InkCanvasCapsuleSize.stageBottom)`，h = `ref.watch(canvasPromptBarHeightProvider(canvasId))`；内部 `Align(bottomCenter)` + `LayoutBuilder` 判 minWidth；`AnimatedSwitcher(duration: InkMotion.fast)`，child key = `dedupeKey ?? ObjectKey(message)`（同 key 不重放淡入）；`MouseRegion(onEnter/onExit → setHovered)`；`visible == false` 时 `dismiss()` 并画空。

## 行为规则与边界情况
1. 同一画布任一时刻最多一枚；新消息（不同 dedupeKey 或无 key）立即替换，120ms 交叉淡入。
2. 同 dedupeKey 的新消息：不换卡、不重放淡入，只改字，计时从头算（连按 Ctrl + 三次 ⇒ 最后一次之后 1.2s 才收）。
3. 停留：text 2s、action 4s、zoom 1.2s；到点 state 回 null。
4. 悬停停表：鼠标在胶囊上不收；移出后按剩余时间续跑（不是从头算）。
5. 位置：提示词条不显示（高度 0）⇒ 底边离舞台底 16；显示且量得高 h ⇒ 底边离舞台底 h + 24（即条子上方 8）；h 变化时胶囊跟着移动。
6. 左右：胶囊左沿 ≥ 舞台左沿 + 171、右沿 ≤ 舞台右沿 − 171；文字超长省略号；可用宽 < 96 不画。
7. 键盘缩放（Ctrl/⌘ = + 小键盘+ / − 小键盘− / 0、小键盘 0）与 ⌘K 的放大 / 缩小 / 实际大小每次都出「缩放 N%」，N = 变换后的比例取整；按住重复也只是原地改字。
8. 适应全部 / 适应选中（Shift 1 / Shift 2、缩放条「适应」、空白处右键「适应视图」）真的改了相机就出比例；空画布适应全部（回初始相机）也出；适应选中但没选中 / 节点未载入 / 视口未量出 ⇒ 不动相机、不出胶囊。
9. 滚轮 / 触控板捏合 / 缩放条 +、− 按钮：不出胶囊。
10. 不进铃铛：显示胶囊时 ToastService 没有任何调用；不出声。
11. 不进 Esc 链：胶囊显示时按 Esc，画布照原 Esc 阶梯处理（清选中），胶囊不受影响、不消失。
12. 不进 Tab 序：胶囊带动作时，从画布按 Tab 焦点不会落到胶囊动作上；鼠标点动作 ⇒ 调 onAction 并 dismiss。
13. 读屏：胶囊 Semantics liveRegion；同 dedupeKey 原地改字不新增节点（只播当前文字）。
14. 换标签（CanvasScreen.isVisible 变 false）⇒ 立即收掉；回来不重放。关画布 / 换画布 ⇒ 旧 canvasId 的 provider autoDispose，计时器被取消，不在新画布上出现。
15. 两个画布互不串：A 画布的消息不出现在 B 画布（family by canvasId）。
16. mac / Windows：mac 键位提示写 ⌘、Windows 写 Ctrl——由调用方传 actionHint（本片缩放无动作，不涉及）；字体无差异。与撤销栈无交互（胶囊只展示，后续 undo-shortcuts-ui 调它）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasCapsuleZoom | `Zoom {percent}%`（placeholders: percent int；description: "Canvas hint capsule after keyboard zoom or Fit: current zoom percentage"） | `缩放 {percent}%` |

## 测试
- `test/theme/components/ink_canvas_capsule_test.dart`
  - 「高 28、全圆角、surface4 底、overlayBorder 描边」：取 DecoratedBox 断言 color / border / radius == InkRadius.pill，getSize().height == 28。
  - 「带动作：文字 + 动作 + 键位；点动作回调一次」。
  - 「动作不进焦点遍历」：Tab 两次后 `primaryFocus` 不在胶囊子树（ExcludeFocus）。
  - 「liveRegion」：`tester.getSemantics` 有 `isLiveRegion` 标志。
  - 「超长文字省略」：给 maxWidth 120，Text overflow == ellipsis、无溢出异常。
- `test/features/canvas/providers/canvas_capsule_test.dart`（ProviderContainer + fakeAsync）
  - 「text 2s 后收；action 4s 后收；zoom 1.2s 后收」（各差 1ms 未收、到点收）。
  - 「新消息顶掉旧消息」：state == 新的。
  - 「同 dedupeKey 原地改字并重新计时」：zoom 80 → 0.8s 后 zoom 96 → 再过 1.0s 仍在、再过 0.2s 收。
  - 「悬停停表、移出续剩余」：show text → 1.5s → setHovered(true) → 10s 仍在 → setHovered(false) → 0.4s 仍在、0.5s 收。
  - 「dispose 时取消计时器」：container.dispose() 后 fakeAsync 推进不抛。
  - 「两个 canvasId 互不影响」。
- `test/features/canvas/widgets/canvas_capsule_host_test.dart`
  - 「无提示词条：底边离舞台底 16」；「条高 60：底边离舞台底 84」（`canvasPromptBarHeightProvider(cv).notifier.report(60)`）。
  - 「左右各让出 171」：长文案时 rect.left ≥ stage.left + 171、rect.right ≤ stage.right − 171。
  - 「舞台宽 300：不画」。
  - 「同 dedupeKey 不重放淡入」：show 两次 zoom，第二次后 `find.byType(InkCanvasCapsule)` 仍 1 个且同一 Element（AnimatedSwitcher 无第二个 child）。
  - 「visible 变 false 立即收」。
  - 「显示胶囊不调 ToastService」：RecordingToastService.shown 为空。
  - 「Esc 不收胶囊」：CanvasShortcuts 包裹下按 Esc，胶囊仍在、选中被清。
- `test/features/canvas/widgets/canvas_capsule_zoom_test.dart`（pumpInkShell 画布标签，参照 canvas_node_shortcuts_test 的装置）
  - 「Ctrl = 出『Zoom 120%』」；「⌘− 出『Zoom 83%』」；「Ctrl 0 出『Zoom 100%』」。
  - 「Shift 1 适应全部出比例」；「缩放条『Fit』出比例」；「Shift 2 无选中：不出」。
  - 「滚轮缩放不出」：`tester.sendEventToBinding(PointerScrollEvent(...))` 改了相机（scale 变了）但 `find.byType(InkCanvasCapsule)` 为空。
  - 「缩放条 +/− 不出」。
- `canvas_zoom_bar_test.dart` 加「缩放条固定宽 kCanvasZoomBarWidth（10% 与 300% 时同宽）」。
- `canvas_screen_layout_test.dart` 加「胶囊左右让位线在缩放条右沿 + 16 之外」：`zoom.right + 16 <= stage.left + InkCanvasCapsuleSize.sideReserve`。

## 变异点
1. 控制器 show 里去掉 dedupeKey 相同时的原地分支（总是新建）→「同 dedupeKey 原地改字并重新计时」不红但「同 dedupeKey 不重放淡入」（host）红。
2. 同 dedupeKey 分支不重启计时 →「同 dedupeKey 原地改字并重新计时」红。
3. `kCanvasCapsuleZoomDwell` 改成 2s →「zoom 1.2s 后收」红。
4. setHovered(true) 不停表 →「悬停停表」红；移出改为从头计时 → 同一用例「0.5s 收」那步红。
5. 宿主 bottom 用 `h + InkCanvasCapsuleSize.stageBottom`（漏了 8）→「条高 60：底边 84」红。
6. 宿主 left/right 用 0 →「左右各让出 171」红。
7. `zoomCanvasBy` 去掉 `showZoomCapsule` →「Ctrl = 出 Zoom 120%」红。
8. `_fitNodes` 去掉 `showZoomCapsule` →「Shift 1 适应全部出比例」「缩放条 Fit 出比例」红。
9. 在 canvasTransformController 上加 listener 统一出胶囊（偷懒做法）→「滚轮缩放不出」「缩放条 +/− 不出」红。
10. InkCanvasCapsule 去掉 ExcludeFocus →「动作不进焦点遍历」红。
11. 宿主 visible=false 不 dismiss →「visible 变 false 立即收」红。
12. 把缩放条百分比格改回按文字宽 →「缩放条固定宽」红。

## 验收
- `flutter analyze lib test`；`flutter test test/theme/components test/features/canvas`；`no_reverse_layer_import_test`（theme 不 import features）绿；逐条跑变异。
- 截图：用 `CanvasScreen`（pumpInkShell，画布 cv-1，两张节点卡）截四张——①无提示词条、Ctrl = 后「缩放 120%」；②选中一张图像配置（提示词条出现）后 Shift 2，胶囊贴在条子上方 8；③控制器直接 show 带动作样例「已撤销 · 移动 3 个节点 [重做 Ctrl Y]」；④窗口拉窄到舞台 600，长文案省略号、两侧让位线不越过。

## 风险与不确定
- 偏离 contract（只做加法）：`CanvasCapsuleMessage` 多了 `actionHint`（画板样例带键位）与 `zoomPercent` + `.zoom()` 命名构造（`fitAllNodes` 只有 ref 没有 l10n，比例文案只能在宿主渲染）；控制器多 `showZoom` / `setHovered`；宿主多可选参数 `visible`。contract 列出的公开名字全部保留。
- 若 esc-ladder 合入后的函数名不是 `zoomCanvasBy` / `resetCanvasZoom`（见 esc-ladder 派工单第 82–83 行），按实际改，并回报。
- tokens 里 `sideReserve = 171` 与缩放条宽度手工同步，由 canvas_screen_layout_test 新用例守着；改缩放条要一起改。
