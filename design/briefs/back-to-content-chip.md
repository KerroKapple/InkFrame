# back-to-content-chip · 「回到内容」胶囊
- 波次：W18；lane：C；基底：origin/main（W17 全部合入之后的 main）
- 依赖切片：没有功能上的硬依赖。文件上要叠在 canvas_screen 链的前一环 W17 canvas-minimap 之后（它在缩放条那段 Stack 里挂了小地图）；读 canvas-find-bar（W9）新建的 `canvasFindControllerProvider` 判断查找条是否开着。以上在执行本片时都已合入 main。
- 阻塞决定：无

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
把画布拖到一片空地、视口里一张卡都看不见时，停手 300ms 后工具条正下方浮出一颗胶囊「⤢ 回到内容  Shift 1」。点它 = 适应全部（与 Shift 1、缩放条「适应」同一个动作），所有卡回到眼前，胶囊消失。空画布不出现；查找条开着时让位。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
画板 `ImportSearch.dc.html`（文本版 boards/ImportSearch.txt 第 125–141 行；生成器 b2_import.js 第 171–199 行）小节「小地图 · 回到内容 —— 都在画布角落，不占工具条」。规则原文：
- 回到内容：有节点但视口里一个都看不到、平移停下 300ms 后出现；点 = 适应全部（同 Shift 1）
- 空画布不出（那里是空画布引导）；查找条开着时让位
样稿（mockE）：舞台顶部水平居中、top 10；高 28、左右内边距 12、圆角 14（全圆）；底 s4、1px overlayBorder 边、浮层阴影；内容 = fit 图标 14 + 「回到内容」11px fg2 + 键帽「Shift 1」，间距 6；角注「视口里一个节点都没有」。KeyMap 板 Q5 说明「Shift 1 和『回到内容』已能把内容带回来」，所以 Ctrl 0 不必承担这件事。
设计缺口：
- 样稿 top 10 与真实浮动工具条（top 12、高 42）重叠；查找条「浮在工具条下方居中」，两者同一个位置，所以胶囊放在工具条下方 `InkToolbarSize.stageTopInset`（64），与查找条互斥（查找条开着就不出）。
- 胶囊出现 / 消失的动效没画：本片用 `InkMotion.fast` 淡入淡出（尊重 disableAnimations）。
- 连线模式提示条也在 stageTopInset 这一行（全宽）：本片在连线模式下不出胶囊。
- 节点全在折叠泳道里时算不算「有节点」没写：本片按「看得见的节点」算，全折叠 = 没内容可回，不出（与 fitAllNodes 只框可见卡同口径）。

## 允许改的文件（逐个路径 + 每个文件改什么；新建的标「新建」；前序切片新建的标「由 <id> 新建」）
- `lib/features/canvas/util/viewport_fit.dart`：新增纯函数 `anyNodeVisible`（节点渲染矩形与视口求交）。
- `lib/features/canvas/widgets/back_to_content_chip.dart`（新建）：胶囊 widget + 300ms 停手计时 + 显示判据接线。
- `lib/features/canvas/widgets/canvas_screen.dart`（canvas_screen 链 W18 环归本片）：在 Stack 里、`CanvasToolbar` 那个 Positioned 之前挂 `BackToContentChip`。
- 测试：`test/features/canvas/util/viewport_fit_test.dart`、`test/features/canvas/widgets/back_to_content_chip_test.dart`（新建）。

## 不许碰的文件
- 同波 more-dropdown-panel：`canvas_toolbar.dart`、`canvas_more_menu.dart`、`more_menu_model.dart`（只许别的片追加一行，本片不加）。`command_palette/command_actions.dart` 本波无人占用，本片也不碰。
- 同波 create-menu-notes-characters：`create_menu_model.dart`、`create_menu_entries.dart`、`characters_controller.dart`、`character.dart`、`ink_menu_panel.dart`。`canvas_tool_actions.dart` 本波无人占用，本片只调用 `fitAllNodes`、不改。
- 同波 node-library-section / node-library-drag-recents：`left_rail/*`、`node_library_model.dart`、`job_repository.dart`、`postgres_job_repository.dart`、`recent_generation_params.dart`、`canvas_drag_payload.dart`、`image_config_inspector.dart`、`prompt_presets_controller.dart`。
- 同波 storyboard-pdf-export：`pubspec.*`、`assets/fonts/*`、`core/licenses.dart`、`export/*`、`core/di/video_export.dart`。
- 其余：`canvas_view.dart`、`stage_overlays.dart`、`canvas_shortcuts.dart`、`canvas_zoom_bar.dart`、`canvas_minimap.dart`、`viewport_focus.dart`、`theme/tokens.dart`。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W18 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - node-library-drag-recents（另加）：`lib/features/canvas/widgets/canvas_view.dart`（舞台拖放派发的三个分支）
  - more-dropdown-panel：`lib/features/canvas/widgets/canvas_more_menu.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`test/features/canvas/widgets/canvas_more_menu_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`
  - create-menu-notes-characters：`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/canvas_character_create_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/theme/components/ink_menu_panel_test.dart`
  - node-library-section：`lib/features/canvas/util/canvas_library_actions.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`test/features/canvas/util/node_library_model_test.dart`、`test/features/canvas/widgets/left_rail/node_library_section_test.dart`
  - node-library-drag-recents：`lib/features/canvas/models/canvas_drag_payload.dart`、`lib/features/canvas/util/canvas_library_actions.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/features/canvas/util/prompt_preset_apply.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`test/features/canvas/util/node_library_model_test.dart`、`test/features/canvas/util/prompt_preset_apply_test.dart`、`test/features/canvas/widgets/left_rail/node_library_drag_test.dart`
  - storyboard-pdf-export：`assets/fonts/`、`assets/fonts/NotoSansSC-Regular.ttf`、`assets/fonts/OFL-NotoSansSC.txt`、`lib/core/di/storyboard_pdf.dart`、`lib/core/interfaces/storyboard_pdf_service.dart`、`lib/core/licenses.dart`、`lib/features/export/providers/storyboard_pdf_controller.dart`、`lib/features/export/util/storyboard_pages.dart`、`lib/features/export/widgets/export_history_row.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/storyboard_pdf_dialog.dart`、`lib/services/pdf_storyboard_service.dart`、`lib/services/ui_storyboard_thumbnail_loader.dart`、`pubspec.yaml`、`test/core/licenses_test.dart`、`test/features/export/providers/storyboard_pdf_controller_test.dart`、`test/features/export/util/storyboard_pages_test.dart`、`test/features/export/widgets/storyboard_pdf_dialog_test.dart`、`test/services/pdf_storyboard_service_test.dart`

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// viewport_fit.dart（追加，不动已有函数）
/// [nodes] 里（调用方已剔掉折叠泳道里的）任一张卡的渲染矩形与视口有交集 ⇒ true。视口没量出来 ⇒ true（不出胶囊）。
bool anyNodeVisible({
  required List<CanvasNode> nodes,
  required List<({String id, double size})> lanes,   // 有效厚度切片（collapseLaneSlices）
  required LaneDirection direction,
  required Matrix4 transform,
  required Size viewportSize,
});

// back_to_content_chip.dart
const Duration kBackToContentSettle = Duration(milliseconds: 300);
class BackToContentChip extends ConsumerStatefulWidget {
  const BackToContentChip({super.key, required this.canvasId});
  static const Key chipKey = ValueKey<String>('backToContentChip');
}
```
- 矩形口径：每张卡 `nodeStageRect(node:, lanes:, direction:, transform:)`（viewport_focus.dart 第 21 行），再 `MatrixUtils.transformRect(transform, r)` 换到视口，与 `Offset.zero & viewportSize` 求 `overlaps`。与 `_fitNodes`（canvas_tool_actions.dart 第 247 行）同一套取值：泳道切片按 `collapseLaneSlices`，没有泳道就不读泳道方向。
- 计时状态机（State 内）：`hidden` →（相机变化 / 节点集变化 / 视口尺寸变化）重置 300ms 计时并保持 hidden →（计时到点，判据成立）`shown` →（任何相机变化）立即 hidden 并重新计时。判据 = 画布有可见节点 && `!anyNodeVisible(...)` && 查找条没开 && 不在连线模式。
- 监听：`addListener` 到 `canvasTransformControllerProvider(canvasId)`（TransformationController）；`ref.listen` `canvasNodesControllerProvider(canvasId)`、`canvasViewportSizeProvider(canvasId)`、`laneCollapseProvider(canvasId)`；`ref.watch` `canvasFindControllerProvider(canvasId)`（由 canvas-find-bar 新建，W9；「开着」的判据以 main 上该 controller 的状态为准）和 `linkModeControllerProvider(canvasId)`。dispose 时取消计时器、移除监听。
- 点击：`fitAllNodes(ref, canvasId: canvasId)`（canvas_tool_actions.dart 第 219 行），然后 `CanvasShortcuts.reclaimFocus(context)` 把焦点还给画布。
- 外观：`InkActivatable`（Tab 可达、Enter / Space 激活、焦点环），高 28、`EdgeInsets.symmetric(horizontal: InkSpacing.s12)`、`BorderRadius.circular(InkRadius.pill)`、底 `c.surface4`、边 `c.overlayBorder`、阴影 `InkShadow.elevated`；内容 Row：`InkIcon(InkGlyph.fit, size: InkIconSize.sm, color: c.fg2)`、`Text(l.canvasBackToContent, style: t.meta.copyWith(color: c.fg2))`、键位文字 `formatShortcutActivator(CanvasToolKeys.fitAll, isMac: …)`（shortcut_catalog.dart 第 143 行，isMac 取法同 canvas_left_rail.dart 第 61 行），`t.mono` + `c.fg4`；间距 `InkSpacing.s6`。tooltip / semanticLabel = 「回到内容  Shift 1」。
- 挂载：`Positioned(top: InkToolbarSize.stageTopInset, left: 0, right: 0, child: Center(child: BackToContentChip(canvasId: canvasId)))`，放在 `if (canvasId != null)` 块里、工具条之前（工具条最后画）。隐藏时返回 `SizedBox.shrink()`，不占命中区。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 画布节点列表为空（空画布引导在场）：永不出现。
2. 有节点但视口里至少能看见一张卡（哪怕只露一角）：不出现。
3. 视口里一张都看不见：相机最后一次变化之后 300ms 才出现；300ms 内又动了就重新计时。
4. 出现后用户再平移 / 缩放（任何相机变化）：立刻消失，停手 300ms 后按规则 2 / 3 重新判。
5. 点击（或 Tab 聚焦后 Enter / Space）：执行适应全部；相机变化后胶囊消失，内容回到视口里所以不再出现。焦点回画布。
6. 节点集变化也重新判：删掉视口里最后一张看得见的卡 → 300ms 后出现；在空地新建了一张卡（落在视口里）→ 不出现 / 立即消失。
7. 视口尺寸变化（拖窗口、开合左栏或检查器）也触发重判（300ms）。
8. 节点全在折叠泳道里：视为没有可回的内容，不出现。
9. 查找条开着：不出现（同一个位置让给查找条）；关掉查找条后按规则 2 / 3 重判。
10. 连线模式中：不出现（连线提示条占着这一行）；退出连线模式后重判。
11. 视口还没量出来（Size.zero，首帧前）：不出现。
12. 不进撤销栈（视口与缩放不进栈，UndoClipboard 板）；不进 Esc 阶梯；不进铃铛历史。
13. 切到别的标签（画布页保活但不可见）：计时照跑但不影响别处；回到画布时状态与相机一致即可，不要求重新计时。
14. 动效：淡入淡出 `InkMotion.fast`；`MediaQuery.disableAnimations` 时直接出现 / 消失。
15. mac 显示「⇧1」，Windows 显示「Shift+1」（formatShortcutActivator 的平台写法，以它为准）。

## 新文案键（key · en · zh 表；没有写「无」）
| key | en | zh |
|---|---|---|
| canvasBackToContent | Back to content | 回到内容 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/viewport_fit_test.dart`（追加 group「anyNodeVisible」）
  - 「卡在视口内 → true」。
  - 「卡只露一角 → true」：卡右下角 10px 落进视口。
  - 「卡全在视口外 → false」：相机平移 5000px。
  - 「泳道里的卡按分道位移算」：横向泳道、scale 0.5，卡的世界坐标在视口外但渲染位置在视口内 → true（与 nodeStageRect 同源）。
  - 「视口未量出 → true」。
- `test/features/canvas/widgets/back_to_content_chip_test.dart`（pumpInkApp + `CanvasScreen(isVisible: true)` 或一个只装 BackToContentChip 的 Stack；fake_canvas 的 twoNodes；相机直接写 `canvasTransformControllerProvider('c1')`）
  - 「看得见卡时不出现」。
  - 「平移到空地，299ms 不出现、300ms 出现」：`tester.pump(Duration(milliseconds: 299))` 断言 findsNothing，再 pump 1ms findsOneWidget。
  - 「出现后再动一下立刻消失」。
  - 「点击 = 适应全部」：点后相机矩阵等于直接调 `fitAllNodes` 得到的矩阵；胶囊消失。
  - 「空画布不出现」：节点控制器返回空列表、相机移到远处，pump 1s 仍 findsNothing。
  - 「查找条开着不出现」：覆写 canvasFindControllerProvider 为开着的状态。
  - 「连线模式不出现」。
  - 「删掉最后一张可见卡后出现」：fake 节点控制器发新列表，pump 300ms。
  - 「Enter 激活」：Tab 聚焦胶囊后按 Enter，相机变成 fit 结果。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写，并写「由测试 <用例名> 抓住」）
1. `anyNodeVisible` 用 `contains(rect.center)` 代替 `overlaps` → 由「卡只露一角 → true」抓住。
2. `anyNodeVisible` 不走 nodeStageRect、直接用 `node.position` → 由「泳道里的卡按分道位移算」抓住。
3. `kBackToContentSettle` 改成 0 / 计时器去掉 → 由「平移到空地，299ms 不出现、300ms 出现」抓住。
4. 相机变化时不立即隐藏 → 由「出现后再动一下立刻消失」抓住。
5. 判据去掉「有节点」→ 由「空画布不出现」抓住。
6. 判据去掉查找条条件 → 由「查找条开着不出现」抓住。
7. 点击改调 `fitSelectedNodes` → 由「点击 = 适应全部」抓住。
8. 不监听节点集变化 → 由「删掉最后一张可见卡后出现」抓住。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑 `flutter analyze lib test`、`flutter test test/features/canvas --exclude-tags golden`，逐条变异。
- 截图（test/_harness/screenshot.dart，中文界面）：`CanvasScreen(isVisible: true)`，数据 = 一条横向泳道 + 4 个节点。截三张：① 正常视图（无胶囊）；② 相机平移到空地并 pump 300ms，胶囊在工具条正下方居中、键位「Shift+1」；③ 点胶囊之后，4 张卡都在视口里、胶囊消失。另截一张查找条开着 + 空地的状态，确认胶囊不出现。

## 风险与不确定
- `canvasFindControllerProvider` 的名字和「开着」的判据由 canvas-find-bar（W9）定，执行代理先看 main；若查找条的开合态在别的 provider 里，改读那个。
- 胶囊与查找条、连线提示条、多选计数 chip 都在 stageTopInset 这一行：多选计数在右侧（right md），胶囊居中，宽度够时不相撞；窗口极窄（舞台 < 400px）时可能压住，画板没画，本片不处理。
- 画板写 top 10，本片放到工具条下方 64，属于对样稿的位置校正，主 Agent 若不同意需回画板确认。
