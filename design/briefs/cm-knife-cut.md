# cm-knife-cut · Alt + 拖空白切线
- 波次：W17；lane：D；基底：origin/main（W16 全部合入之后的 main）
- 依赖切片：硬依赖 narrative-splice（W1，`Future<List<CanvasEdge>> removeEdges(Set<String> ids)`：一个事务软删、返回被删边快照）、esc-ladder（W0，`util/escape_ladder.dart` 的 `EscapeRungId` + `providers/canvas_escape_ladder.dart` 的 `canvasEscapeLadderProvider(canvasId).register / unregister`）、marquee-select（W3，`stage_pointer_layer` 里左键拖空白起框、4px 点击判定、`StagePanGate` 放行规则）、canvas-view-split（W0，`stage_pointer_layer.dart` 已拆出）、undo-stack（W0，`CanvasCommand` 非 sealed、`canvasHistoryControllerProvider(canvasId).notifier.record(cmd)` 返回步 id、`undoSpecific(stepId)`；`EdgeEndpoints` / `findEdgeByEndpoints`）、undo-adopt-existing（W3，`showCanvasUndoSnack(context, {message, canvasId, stepId})`——按步 id 出卡，卡上「撤销」= 撤这一步；`DeleteEdgeCommand` 只管单条边）与 undo-edges（W5）。软依赖 lone-alt-menubar（W7，单独按 Alt 才聚焦菜单栏，指针动作作废标记）。以上在执行本片时都已合入 main。
- 阻塞决定：无。ContextMenus「需要你定」W3（切线用什么手势）未列为阻塞，按建议 A：Alt + 左键拖空白，并列进快捷键页。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
按住 Alt（mac ⌥）在画布空白处用左键拖，拖出一条红色虚线；划过的叙事线和数据线当场变红。松手，变红的线一次全部断开，右下角出一张「已切断 N 条连线 · 撤销」卡，Ctrl Z 也能撤回。拖到一半按 Esc 取消，什么都不删。产出线划不断；平移工具下不生效。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
画板 `ContextMenus.dc.html`（文本版 boards/ContextMenus.txt 第 158–196 行）小节「停用 · 切线 · P2」，卡角标「Alt + 拖」。规则原文：
- Alt + 左键在空白处拖出红色虚线，划过的叙事 / 数据线变红；松手全部断开、一张撤销卡
- Esc 取消切线，与「框选进行中」同一级（菜单 > @ 弹层 > 查找条 > 框选 / 切线进行中 > 工具锁 > 清空选中）
- Alt 期间有指针动作就不聚焦菜单栏——只认单独按下再松开的 Alt；不做 Alt+字母助记键
- 右键拖已是平移，所以不用 Blender 的 Ctrl + 右键；产出线划不断；平移工具下不生效
KeyMap 板：指针表「Alt 拖空白 / ⌥ 拖空白 · 切线 · 画布 · 第二批」；「原样放下 = 不吸附、不插进叙事线；Alt(⌥) 只给切线」；Esc 阶梯第 5 层「进行中的手势（拖线 · 框选）」；刻意不绑「K 剪线（W3 选 A）」；「窗口失焦清标记；带 Ctrl 的 AltGr 不算」。UndoClipboard 板：「连线 / 删线 / 改语义」进栈；卡片是提醒、栈才是本体，卡停 8 秒，卡上「撤销」撤卡上这一步；反向找边按两端、不按边 id。GapsCanvas 板「更多」下拉：「切线（Alt 拖）」从菜单进是一次性模式（W18 more-dropdown-panel 落地，本片提供 `arm()` 入口）。
设计缺口：
- 红线的线宽、虚线节奏、变红线的线宽没写：本片取虚线 4 / 3（同 `kPendingWireDash`）、线宽 1.5，变红的连线按原线宽重描一遍 danger 色。
- 只按了 Alt 没拖（Alt + 单击空白）是什么：本片按普通单击空白处理（清空选中）。
- 一次性模式（菜单进入）时的光标：没有系统剪刀光标，本片用 `SystemMouseCursors.precise`。

## 允许改的文件（逐个路径 + 每个文件改什么；新建的标「新建」；前序切片新建的标「由 <id> 新建」）
- `lib/features/canvas/widgets/stage/stage_pointer_layer.dart`（由 canvas-view-split 新建，W0；stage_pointer_layer 链 W17 环归本片）：原 `BlankPointerDetector` 起框分支前加「Alt / 已武装 → 起切线」分支；挂切线浮层画笔；一次性模式下换光标。
- `lib/features/canvas/providers/edge_cut_controller.dart`（新建）：切线状态（武装 / 笔画 / 已命中边）+ 提交 / 取消。
- `lib/features/canvas/util/edge_cut_hit.dart`（新建）：纯函数，折线段与连线路径相交。
- `lib/features/canvas/widgets/edge_cut_painter.dart`（新建）：红色虚线 + 被划中的连线重描红色。
- `lib/features/canvas/util/canvas_cut_actions.dart`（新建）：`commitEdgeCut`——删边、清选中边、进栈、出卡。
- `lib/features/canvas/models/commands/cut_edges_command.dart`（新建）：`CutEdgesCommand extends CanvasCommand`（持被删边快照 + 各自 `EdgeEndpoints`；revert = 一个事务按两端恢复、已有在世同端点边的跳过、任一端节点已不在 ⇒ gone；apply = 按两端找边再 `removeEdges`；`label(l) => l.canvasCommandCutEdges(n)`）。不改 `canvas_command.dart`（undo-stack 的约定是一条命令一个文件）；W3 的 `DeleteEdgeCommand` 是单条边，不复用。
- `lib/features/canvas/util/escape_ladder.dart`（由 esc-ladder 新建，W0）：`EscapeRungId` 在 `marquee` 之后追加一个值 `edgeCut`（只改这一处）。esc-ladder 的层是 `{menu, mentionPopup, findBar, textField, wireDrag, marquee, linkMode, toolLock, panTool, selection}`，「进行中的手势」= wireDrag / marquee 两档，`marquee` 已被 marquee-select 登记，同 id 再登记会覆盖它，所以切线要自己的档。
- 测试：`test/features/canvas/util/edge_cut_hit_test.dart`（新建）、`test/features/canvas/providers/edge_cut_controller_test.dart`（新建）、`test/features/canvas/widgets/canvas_knife_cut_test.dart`（新建）、`test/features/canvas/models/commands/cut_edges_command_test.dart`（新建，写法照 W3 的 `delete_edge_command_test.dart`）。

## 不许碰的文件
- 同波 canvas-minimap：`canvas_screen.dart`、`canvas_zoom_bar.dart`、`app_preferences.dart`、`file_preferences_service.dart`、`minimap_*`、`shortcuts/minimap_keys.dart`。
- 同波 shortcuts-page-v2：`shortcut_catalog.dart`、`pointer_gesture_catalog.dart`、`shortcuts_section.dart`、`create_node_menu.dart`、`command_palette_dialog.dart`、`batch_compare_overlay.dart`、`gallery_grid.dart`。
- 同波 rail-templates-page：`canvas_toolbar.dart`、`create_menu_model.dart`、`left_rail/*`、`left_rail_state.dart`；同波 script-reimport-diff：`storyboard/*`。
- 热点链本波不归本片的：`stage_edge_layer.dart`、`edge_painter.dart`（不改，红色走独立浮层画笔）、`canvas_edges_controller.dart`（只调用 removeEdges / restore，不改）、`canvas_tool_actions.dart`、`canvas_view.dart` 骨架、`node_card_slot.dart`。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W17 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - rail-templates-page：`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/left_rail/template_card.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`lib/features/templates/util/template_ui_actions.dart`、`lib/features/templates/widgets/template_thumbnail_painter.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/left_rail/templates_panel_test.dart`、`test/features/templates/widgets/template_thumbnail_painter_test.dart`
  - script-reimport-diff：`lib/features/canvas/providers/script_document_provider.dart`、`lib/features/canvas/widgets/left_rail/script_model.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/providers/script_reimport_controller.dart`、`lib/features/storyboard/util/script_diff.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`、`lib/features/storyboard/widgets/script_reimport_preview.dart`、`test/features/canvas/widgets/left_rail/script_model_test.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/providers/script_reimport_controller_test.dart`、`test/features/storyboard/util/script_diff_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`
  - canvas-minimap：`lib/core/models/app_preferences.dart`、`lib/features/canvas/providers/minimap_visible.dart`、`lib/features/canvas/util/minimap_geometry.dart`、`lib/features/canvas/widgets/canvas_capsule_host.dart`、`lib/features/canvas/widgets/canvas_minimap.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/canvas_zoom_bar.dart`、`lib/features/canvas/widgets/shortcuts/minimap_keys.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/providers/minimap_visible_test.dart`、`test/features/canvas/util/minimap_geometry_test.dart`、`test/features/canvas/widgets/canvas_minimap_test.dart`、`test/features/canvas/widgets/canvas_screen_layout_test.dart`、`test/features/canvas/widgets/canvas_zoom_bar_test.dart`、`test/services/file_preferences_service_test.dart`
  - shortcuts-page-v2：`lib/features/settings/util/overlay_key_catalog.dart`、`lib/features/settings/util/pointer_gesture_catalog.dart`、`lib/features/settings/util/shortcut_catalog.dart`、`lib/features/settings/widgets/shortcuts_section.dart`、`test/features/settings/overlay_key_catalog_test.dart`、`test/features/settings/pointer_gesture_catalog_test.dart`、`test/features/settings/shortcut_catalog_test.dart`、`test/features/settings/shortcuts_section_test.dart`

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// edge_cut_hit.dart
const double kEdgeCutSampleStep = 8;                     // 连线路径采样步长（舞台 px），同 distanceToEdgePath
bool segmentsIntersect(Offset a0, Offset a1, Offset b0, Offset b1);
Set<String> edgesCrossedBySegment({required Offset from, required Offset to, required List<CanvasEdge> edges,
    required List<CanvasNode> drawnNodes, required LaneDirection direction});   // drawnNodes = displacedNodes(可见节点)
bool isCuttable(CanvasEdge e);                           // edgeType ∈ {data, narrative}；generationSource 与派生产出线不算

// edge_cut_controller.dart
@immutable class EdgeCutState { final bool armed; final List<Offset> stroke; final Set<String> hits; bool get cutting; }
final edgeCutControllerProvider = AutoDisposeNotifierProviderFamily<EdgeCutController, EdgeCutState, String>(…);
class EdgeCutController extends AutoDisposeFamilyNotifier<EdgeCutState, String> {
  void arm();                     // 一次性模式（W18「更多 › 切线」调）；已在切就不动
  void disarm();
  void begin(Offset stagePoint);
  void extend(Offset stagePoint, Set<String> newHits);   // hits 只增不减
  Set<String> finish();          // 返回命中集并复位（含解除武装）
  void cancel();                 // Esc / 指针取消：复位，不删
}

// canvas_cut_actions.dart
Future<void> commitEdgeCut(BuildContext context, WidgetRef ref, {required String canvasId, required Set<String> edgeIds});
```
- 起手判定（stage_pointer_layer，原 `BlankPointerDetector` 位置）：主键按下在空白处、`HardwareKeyboard.instance.isAltPressed && !isControlPressed && !isMetaPressed`（AltGr 带 Ctrl，不算），或 `edgeCutController.armed` → 走切线，不起框、不计双击第一下。平移生效时 `StagePanGate` 不放指针进来，自然不切；连线模式（`linkModeControllerProvider` 非 null）不起切线（同框选）。
- 判定「拖」与「点」：沿用 marquee 的 4px 阈值；没挪出 4px 就松手 = 普通单击空白（清空选中），不调 removeEdges。挪出 4px 后才 `begin`（起点 = 按下点）。
- 每次 move：取上一个笔画点到当前点的线段，调 `edgesCrossedBySegment`（命中用 `displacedNodes(可见节点…)`，与 canvas_view 里 `edgeAt` 同源；折叠泳道里的端点不画也不算）→ `extend`。命中集只增：笔画越长越多。
- 浮层：`CustomPaint(foregroundPainter: EdgeCutPainter(…))` 包在连线层外（舞台坐标），只 watch edgeCutControllerProvider；红色 = `context.inkColors.danger`。
- 松手：`finish()` 拿命中集；空集什么都不做；非空调 `commitEdgeCut`：先清 `selectedEdgeControllerProvider`（若选中边在集里）→ `removeEdges(ids)`（一个 UnitOfWork 事务）→ 进撤销栈一步（标签「切断 N 条连线」）→ `stepId = record(CutEdgesCommand(removed))` → `showCanvasUndoSnack(context, message: l.canvasEdgesCut(n), canvasId: canvasId, stepId: stepId)`（undo-adopt-existing 改过的签名；卡上「撤销」就是 `undoSpecific(stepId)`）。失败（InkError）→ `showCanvasSnack(context, l.canvasEdgesCutFailed)`，边由 removeEdges 回滚，不进栈。
- Esc：`ref.read(canvasEscapeLadderProvider(canvasId)).register(EscapeRungId.edgeCut, (isActive: () => state.cutting || state.armed, dismiss: cancel))`（在 EdgeCutController.build 里登记，`ref.onDispose` 里 unregister）。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 只有「Alt + 主键在空白处按下」或「已武装 + 主键在空白处按下」才起切线；在卡片上按下照旧是拖卡；右键 / 中键拖照旧是平移。
2. 按下后挪不到 4px 就松手 = 普通单击空白（清空节点与连线选中），不删任何边。
3. 拖动中划过的 data / narrative 边立刻变红；generationSource 边和派生的产出线永不命中、不变红。
4. 命中集只增不减：笔画回头不会让已变红的线恢复。
5. 松手且命中集非空：所有命中边在一个事务里软删；任何一条失败整批回滚，弹「切线失败」，画布上的边一条不少，不进撤销栈。
6. 成功后：一步进栈（Ctrl Z 一次复原全部被切的边，Ctrl Y / ⇧⌘Z 重做再切掉）；弹一张撤销卡，点「撤销」只撤这一步（UndoClipboard Q1-A）；被切掉的边若正被选中，选中清空。
7. 被切的叙事边断开后序列 / 大纲随边控制器自动刷新（不另写刷新）。
8. Esc（拖动中）：取消，命中集清空、红线消失、不删边；Esc 只剥这一层，选中不受影响。
9. 拖动中松开 Alt：照常继续切（起手时已经定了是切线）。
10. 指针取消（PointerCancel）或画布卸载：等同 Esc，不删边。
11. 平移工具（H 或按住空格）开着：Alt + 拖不起切线（指针被 `StagePanGate` 挡掉，拖的是画布）。连线模式下同样不起切线。
12. 一次性模式（`arm()` 之后）：不按 Alt 的主键拖空白也起切线，光标 precise；切完（不论命中与否）或 Esc 后自动解除；武装着的时候 Esc 先解除武装。
13. Windows：Alt 期间有指针按下，lone-alt 检测作废标记，松开 Alt 不聚焦菜单栏（lone_alt_detector 已实现，本片不改，只在验收里手测）。AltGr（Ctrl+Alt）按下拖动不起切线，走框选。
14. mac：⌥ 即 `isAltPressed`，行为同 Windows；mac 无菜单栏聚焦问题。
15. 大画布：每次 move 只测新的一段线段，对每条边先做包围盒预筛（复用 `edgeBoundsMayHit`，edge_geometry.dart 第 90 行），再采样相交。

## 新文案键（key · en · zh 表；没有写「无」）
| key | en | zh |
|---|---|---|
| canvasEdgesCut | {count, plural, one{{count} link cut} other{{count} links cut}} | 已切断 {count} 条连线 |
| canvasEdgesCutFailed | Couldn't cut links | 切线失败 |
| canvasCommandCutEdges | {count, plural, one{Cut {count} link} other{Cut {count} links}} | 切断 {count} 条连线 |
（`canvasCommandCutEdges` 是 `CutEdgesCommand.label` 用的；三个 count 都是 int 占位符。）

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/edge_cut_hit_test.dart`
  - 「线段相交基本情形」：十字相交 true、平行 false、端点相接 true、共线不重叠 false。
  - 「横向贝塞尔被竖直划过」：两节点间一条 narrative 边，竖线从上到下穿过中点 → 命中该边 id。
  - 「没碰到不命中」：竖线停在曲线上方 20px → 空集。
  - 「产出 / generationSource 不命中」：同一位置放一条 generationSource 边 → 不在结果里。
  - 「竖向泳道方向」：direction vertical 时横线穿过竖直连线 → 命中。
  - 「包围盒预筛跳过远处边」：远处 200 条边不影响结果（只断言结果正确）。
- `test/features/canvas/providers/edge_cut_controller_test.dart`
  - 「begin / extend / finish 返回累计命中并复位」；「命中只增不减」；「cancel 清空且不返回」；「arm 后 finish 自动解除」；「已在切时 arm 不改状态」。
- `test/features/canvas/widgets/canvas_knife_cut_test.dart`（夹具照 canvas_pan_tool_test：pumpInkApp + CanvasShortcuts + CanvasView + fake_canvas；边控制器用一个记录 removeEdges 调用的 fake）
  - 「Alt + 拖穿过一条边 → 松手 removeEdges 收到它，出撤销卡」：`tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft)` 后拖动；断言记录的 id 集合与 RecordingToastService 的 undo 卡。
  - 「不按 Alt 拖空白 = 框选，不删边」。
  - 「Alt + 挪不到 4px 松手 = 清空选中，不删边」。
  - 「拖动中 Esc 取消 → 不删边，红线消失」：Esc 后 edgeCutControllerProvider 状态为空。
  - 「平移工具下 Alt + 拖不删边」：先按 H。
  - 「removeEdges 抛 InkError → 出失败卡、不进栈」：历史控制器 canUndo 为 false。
  - 「成功后 Ctrl Z 复原」：撤销后边控制器里边又在（按两端找回）。
  - 「Ctrl+Alt 拖（AltGr）不起切线」。
  - 「arm 后不按 Alt 拖也能切，切完自动解除」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写，并写「由测试 <用例名> 抓住」）
1. `isCuttable` 放行 generationSource → 由「产出 / generationSource 不命中」抓住。
2. `segmentsIntersect` 里把严格判定改成只比包围盒 → 由「没碰到不命中」与「线段相交基本情形」抓住。
3. 起手判定去掉 `isAltPressed` 条件（任何拖空白都切）→ 由「不按 Alt 拖空白 = 框选，不删边」抓住。
4. 去掉 4px 门槛 → 由「Alt + 挪不到 4px 松手 = 清空选中，不删边」抓住。
5. Esc 层的 dismiss 改成空函数 → 由「拖动中 Esc 取消」抓住。
6. commitEdgeCut 去掉进栈 → 由「成功后 Ctrl Z 复原」抓住。
7. commitEdgeCut 失败分支也进栈 → 由「removeEdges 抛 InkError → 出失败卡、不进栈」抓住。
8. 起手判定去掉 `!isControlPressed` → 由「Ctrl+Alt 拖（AltGr）不起切线」抓住。
9. `extend` 用新命中集覆盖旧集 → 由「命中只增不减」抓住。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑 `flutter analyze lib test`、`flutter test test/features/canvas --exclude-tags golden`，逐条变异。
- 截图（test/_harness/screenshot.dart）：`CanvasView` 包在 `CanvasShortcuts` 里，数据 = 镜头 01 → 02 → 03 两条叙事边 + 一条 02 → 视频配置的首帧 data 边 + 一条产出线。截三张：① 按住 Alt 拖到一半，红虚线穿过两条线、它们变红、产出线不变；② 松手后两条线消失、右下撤销卡；③ 点撤销后两条线回来。
- 手测（Windows）：Alt + 拖完松开 Alt，菜单栏「文件」不获得焦点。

## 风险与不确定
- `removeEdges` 按 narrative-splice 派工单返回被删边快照列表（`Future<List<CanvasEdge>>`），所以复原走现有 `CanvasEdgesController.restore(CanvasEdge)`（canvas_edges_controller.dart 第 120 行）逐条恢复，但要放在一个事务里，否则撤销会半成功——这一点执行代理要先看 main 再定。
- 撤销命令：已核对前序派工单——undo-adopt-existing 只有单条的 `DeleteEdgeCommand`，undo-edges / cm-edge-menu 没有「删一组边」，所以新建 `CutEdgesCommand`（新 ARB 键 `canvasCommandCutEdges`）。
- 快捷键页的「Alt 拖空白 / ⌥ 拖空白 = 切线」一行：主 Agent 交叉核对后改由同波 shortcuts-page-v2 直接写进 `kPointerGestureRows`（ARB 键 `settingsPointerActionCutEdges` 由它列出），本片不碰 `pointer_gesture_catalog.dart`。如果本片最终不合入，主 Agent 要把那一行连同用例一起撤掉。
- 一次性模式（`arm()`）是为 W18 more-dropdown-panel 预留的；那一片的 slices.json 依赖名写作 `edge-cut-gesture`，指的就是本片。
- `stage_pointer_layer.dart` 拆分后的内部结构（`BlankPointerDetector` 是否还叫这个名、marquee 的 4px 判定放在哪）以 main 为准；本片的分支一定要插在框选起手之前，否则 Alt + 拖会先被框选吃掉。
