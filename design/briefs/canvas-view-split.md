# canvas-view-split · 拆 canvas_view.dart：舞台各层搬进 widgets/stage/，骨架留在原文件
- 波次 W0 / lane B / 基底 origin/main（f64f56e，已含 #299 lane-drag）；**W0 最先合**
- 依赖切片：无；阻塞决定：无

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
用户看不到任何变化：画布的点选、拖卡换道、拖线、右键 / 双击开菜单、平移工具、泳道标题栏 / 分界线、错误横幅、计数 chip 全部原样。
`canvas_view.dart`（1875 行）只剩 CanvasView / _CanvasBody / _CanvasStage 骨架，舞台各层各占一个文件，后面 14 个切片（marquee、stage-drop、undo-adopt、group-drag、lane-ops…）各改各的文件，不再抢同一个大文件。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
无画板，纯重构。依据是 plan.md 第 2 节「热点文件逐波归谁」（stage_pointer_layer / node_card_slot / stage_edge_layer / stage_lane_layer 各自的后续链）与 contract.md 第 1 节 canvas-view-split 的文件名。
验收口径照 plan.md 第 3 节「纯搬移的 PR」：`git diff -M --color-moved=zebra` 核对，现有测试一行不改仍全绿，测试锚点 Key（`node-card-<id>`、`lane-group-<id>`）原名保留。

## 允许改的文件（逐个路径 + 每个文件改什么）
行号均指 origin/main f64f56e 的 `lib/features/canvas/widgets/canvas_view.dart`。
- `lib/features/canvas/widgets/canvas_view.dart`：只留骨架。保留第 78 行 `kCanvasBoundaryMargin`、第 80–118 行 `CanvasView`、第 290–436 行 `_CanvasBody`（含第 330–337 行点卡修饰键 = 切换，原样不动）、第 438–1014 行 `_CanvasStage.build`（去掉下面搬走的段落，改为引用新类）。重写第 1–16 行头注，说明各层去了哪个文件；import 删到只剩骨架用到的。
- `lib/features/canvas/widgets/stage/stage_pointer_layer.dart`（新）：
  - 第 1577–1593 行 `_PanGate` → `StagePanGate`
  - 第 1595–1631 行 `_StagePanCursor` + State → `StagePanCursor`
  - 第 1633–1642 行 `_StageSpace` / `_RenderStageSpace` → `StageSpace` / `RenderStageSpace`（node_card_slot 要 `findAncestorRenderObjectOfType<RenderStageSpace>()`）
  - 第 1644–1757 行 `_BlankPointerDetector` + State → `BlankPointerDetector`
  - 第 1759–1764 行 `_withinClickSlop` → 留私有 `_withinClickSlop`（只有本文件两个探测器用）
  - 第 1766–1826 行 `_SecondaryClickDetector` + State → `SecondaryClickDetector`（node_card_slot 也用）
- `lib/features/canvas/widgets/stage/node_card_slot.dart`（新）：第 1277–1481 行 `_NodeCardSlot` → `NodeCardSlot`（含 `_toStage`、`_laneName`、`_commitDrag`、`_portDrag`，私有方法保持私有）。
- `lib/features/canvas/widgets/stage/stage_lane_layer.dart`（新）：
  - 第 690–708 行闭包 `laneShifted` → `StageLaneShift` widget（参数：transform、direction、viewport、skinExtent、child；行为逐字照搬 ValueListenableBuilder + Positioned）
  - 第 648–668 行闭包 `dropTargetLaneOf` + 第 716–737 行泳道底色块 → `StageLaneBackgroundLayer`（内部仍是 `IgnorePointer(Consumer(LaneBackground…))`，`.select(dropTargetLaneOf)` 原样）
  - 第 978–1008 行标题栏 + 分界线 Stack、第 1016–1115 行 `_buildLaneTitleBars`、第 1117–1185 行 `_buildResizeDividers`、第 1187–1210 行 `_onEditLane`、第 1212–1249 行 `_onDeleteLane` → `StageLaneLayer`（build 出原来那个 `Stack(clipBehavior: Clip.none, children: [...标题栏, ...分界线])`；外面的 `StagePanGate` 与 `StageLaneShift` 留在骨架里包它）
- `lib/features/canvas/widgets/stage/stage_edge_layer.dart`（新）：
  - 第 772–823 行连线绘制 `RepaintBoundary(Consumer(… EdgePainter …))` → `StageEdgeLayer`（外面的 `BlankPointerDetector` + `GestureDetector(onTapDown)` 留在骨架里包它）
  - 第 918–956 行选中边删除钮 + 第 452–475 行 `_handleEdgeDelete` + 第 477–487 行 `_restoreEdge` → `StageEdgeDeleteOverlay`（`if (selectedGeometry != null)` 的判断留在骨架）
  - 第 169–191 行 `_EdgeDeleteButton` → 本文件私有，名字不变
  - 第 1251–1275 行 `_selectedEdgeGeometry` → 公开顶层函数 `selectedEdgeGeometry`
  - 第 1483–1546 行 `_EdgeLaneErrorSlot` + State → `EdgeLaneErrorSlot`
  - 第 1828–1875 行 `_PendingWireLayer` → `PendingWireLayer`
- `lib/features/canvas/widgets/stage/stage_overlays.dart`（新）：第 119–167 行 `_PendingFocusApplier` → `PendingFocusApplier`；第 193–224 行 `_SelectionCountChip` → `SelectionCountChip`；第 226–256 行 `_LinkHintBanner` → `LinkHintBanner`；第 258–288 行 `_LoadError` → `CanvasLoadError`；第 1548–1559 行 `_LinkHintSlot` → `LinkHintSlot`；第 1561–1575 行 `_SelectionCountSlot` → `SelectionCountSlot`。
- `test/features/canvas/widgets/stage/stage_lane_layer_test.dart`（新，见「测试」）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- menu-split：`create_node_menu.dart`、`widgets/canvas_menu/**`、`lib/theme/components/ink_menu_panel.dart`、`create_node_menu_test.dart`。骨架里 `import 'create_node_menu.dart'` 原样保留（它会变成 barrel，名字不变）。
- esc-ladder → zoom-reset-100：`canvas_shortcuts.dart`、`widgets/shortcuts/**`、`util/escape_ladder.dart`、`providers/canvas_escape_ladder.dart`、`settings/util/shortcut_catalog.dart`、`util/canvas_zoom.dart`。
- undo-stack → naming-shot-unify：`models/canvas_command.dart`、`models/edge_endpoints.dart`、`providers/canvas_history_controller.dart`、`storyboard/widgets/script_import_dialog.dart`。
- multi-select-core → duration-format：`providers/canvas_selection_controller.dart`、`util/selection_geometry.dart`、`lib/l10n/duration_format.dart`。
- 另外：`node_card.dart`、`lane_title_bar.dart`、`lane_background.dart`、`edge_painter.dart`、`canvas_tool_actions.dart`、所有现有测试文件一律不改。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// stage_pointer_layer.dart
class StagePanGate extends ConsumerWidget { const StagePanGate({super.key, required String canvasId, required Widget child}); }
class StagePanCursor extends ConsumerStatefulWidget { const StagePanCursor({super.key, required String canvasId, required Widget child}); }
class StageSpace extends SingleChildRenderObjectWidget { const StageSpace({super.key, required super.child}); }
class RenderStageSpace extends RenderProxyBox {}
class BlankPointerDetector extends StatefulWidget { const BlankPointerDetector({super.key, required ValueChanged<Offset> onDoubleDown, required ValueChanged<Offset> onSecondaryClick, required Widget child}); }
class SecondaryClickDetector extends StatefulWidget { const SecondaryClickDetector({super.key, required ValueChanged<PointerDownEvent> onSecondaryClick, required Widget child}); }
// node_card_slot.dart —— 构造参数与原 _NodeCardSlot 完全相同（node, lane, canvasId, lanes, laneSlices, direction, transform, hasInEdge, hasOutEdge, onTap, onSecondaryClick, onDelete, onWireDrop）
class NodeCardSlot extends ConsumerWidget {}
// stage_lane_layer.dart
class StageLaneShift extends StatelessWidget { const StageLaneShift({super.key, required TransformationController transform, required LaneDirection direction, required Size viewport, required double skinExtent, required Widget child}); }
class StageLaneBackgroundLayer extends StatelessWidget { const StageLaneBackgroundLayer({super.key, required List<StyleLane> lanes, required List<CanvasNode> nodes, required List<({String id, double size})> laneSlices, required LaneDirection direction, required Set<String> collapsedIds, required TransformationController transform, required Size viewport}); }
class StageLaneLayer extends ConsumerWidget { const StageLaneLayer({super.key, required String canvasId, required List<StyleLane> lanes, required List<({String id, double size})> laneSlices, required List<CanvasNode> nodes, required LaneDirection direction, required Set<String> collapsedIds, required Size viewport}); }
// stage_edge_layer.dart
class StageEdgeLayer extends StatelessWidget { /* canvasId, edges, lineage, visibleNodes, laneSlices, direction, transform, selectedEdgeId */ }
class StageEdgeDeleteOverlay extends ConsumerWidget { /* canvasId, geometry, laneSlices, direction, transform */ }
({CanvasEdge edge, CanvasNode source, CanvasNode target})? selectedEdgeGeometry({required String? selectedEdgeId, required List<CanvasEdge> edges, required List<CanvasNode> nodes});
class EdgeLaneErrorSlot extends ConsumerStatefulWidget { const EdgeLaneErrorSlot({super.key, required String canvasId}); }
class PendingWireLayer extends ConsumerWidget { /* 参数同原 _PendingWireLayer */ }
// stage_overlays.dart
class PendingFocusApplier extends ConsumerStatefulWidget {}   // canvasId, nodes, child
class SelectionCountChip extends StatelessWidget {}           // count
class SelectionCountSlot extends ConsumerWidget {}            // canvasId
class LinkHintBanner extends StatelessWidget {}
class LinkHintSlot extends ConsumerWidget {}                  // canvasId
class CanvasLoadError extends StatelessWidget {}              // message
```
没有新 provider、没有状态机变化。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 方法体逐字搬移：除了类名去下划线、`_RenderStageSpace` 引用改名、闭包变构造参数，不改任何表达式、注释、常量、手势顺序。
2. **watch 位置不许变**：原来在 `_CanvasStage.build` 里 watch 的（选中边、edges、lanes、方向、折叠、transform）仍在骨架里 watch，作为参数传给子层；原来在 `Consumer` / 插槽里 watch 的（nodeDragDeltaProvider、canvasStyleControllerProvider、选中集、linkMode、wireDrag）仍在子层里 watch。子层不得新增 watch——改选中只重建涉及的卡片，这一条不能因拆分退化。
3. Widget 树形状不变：`Positioned.fill` / `ValueListenableBuilder` / `RepaintBoundary` / `IgnorePointer` 的嵌套顺序与原来一致（`find.ancestor(of: InteractiveViewer, matching: MouseRegion).first` 仍落在 StagePanCursor 那层；泳道背景 / 标题栏仍在 InteractiveViewer 之外）。
4. Key 原名：`ValueKey('node-card-${node.id}')` 与 `ValueKey('lane-group-${lane.id}')` 留在骨架的 `Positioned` 上，不挪进 NodeCardSlot。
5. 删边失败提示、撤销失败提示、删道确认框、改道失败卡：文案键与 `showCanvasSnack` / `showCanvasUndoSnack` 调用原样（W3 undo-adopt-existing 会改 `StageEdgeDeleteOverlay` 与 `NodeCardSlot._commitDrag`，这里不预改）。
6. `_commitDrag` 在 await 前取齐 l10n / toasts / container 的写法原样保留（换道后插槽重挂、context 失效）。
7. stage/ 下文件只 import 各自用到的东西；stage/ 之间允许 node_card_slot → stage_pointer_layer（SecondaryClickDetector、RenderStageSpace），不允许反向 import canvas_view.dart。
8. mac / Windows 无差异（纯搬移）。

## 新文案键（key · en · zh 表；没有写无）
无。

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- 现有测试一行不改，全部要绿：`test/features/canvas/widgets/` 下 canvas_view_test、canvas_lane_drag_test、canvas_pan_tool_test、canvas_create_menu_test、canvas_node_menu_test、canvas_node_shortcuts_test、canvas_shortcuts_test、canvas_focus_request_test、lane_interactions_test、canvas_lane_integration_test、left_rail/*，以及 `test/features/shell/shell_canvas_fit_test.dart`、`shell_keepalive_test.dart`。
- 新增 `test/features/canvas/widgets/stage/stage_lane_layer_test.dart`（原来泳道删 / 改的接线没有任何测试覆盖，搬家时补上；harness 照抄 lane_interactions_test.dart 的 pump 写法，不改原文件）：
  - 「标题栏删除键 → 确认框；点删除 ⇒ deleteLane 收到这条道的 id」：tap `find.byTooltip('Delete lane')`，确认框标题 `Delete this lane?`，点确认后 fake lanes controller 的 deleteLane 调用列表 == [laneId]。
  - 「确认框点取消 ⇒ 不调 deleteLane」。
  - 「deleteLane 抛 InkError ⇒ 出 laneDeleteFailed 卡」：RecordingToastService 收到 `context.l10n.laneDeleteFailed` 的英文。
  - 「标题栏编辑键 → 编辑框；确认 ⇒ updateLane 收到 label / stylePrompt」。
  这几条在 origin/main 上同样应绿（它是补覆盖，不是红灯先行）；变异见下表第 10、11 条。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写，每条注明哪条测试抓住它）
1. `node_card_slot.dart` `_commitDrag` 里 `nodesCtrl.moveNode(nodeId, drop.delta, laneId: drop.laneId)` 改成 `laneId: fromLaneId` → canvas_lane_drag_test「真拖进 Dusk：途中 Dusk 高亮，松手换道并弹撤销卡…」红。
2. `stage_pointer_layer.dart` `SecondaryClickDetector._onPointerUp` 去掉 `_withinSlop(down, event.position)` 判断（直接回调）→ canvas_create_menu_test「空白处按住右键拖动：不开右键菜单（拖的是画布）」红。
3. `StagePanGate.build` 的 `ignoring:` 改成 `false` → canvas_pan_tool_test「平移工具：从卡片上起拖 → 拖的是画布、节点不动…」红。
4. `StagePanCursor.build` 的 cursor 恒为 `MouseCursor.defer` → canvas_pan_tool_test「光标：平移时舞台是手形（grab）…」红。
5. `BlankPointerDetector._onPointerDown` 去掉 `othersPressed ||` → canvas_create_menu_test「一根手指按着不放时，另一根手指在别处点两下：不算双击」红。
6. `stage_overlays.dart` `SelectionCountSlot` 的 `count < 2` 改成 `count < 3` → canvas_view_test「Shift 多选 → 两个节点都选中 + 计数 chip 显示」红。
7. `PendingFocusApplier._land` 去掉 `consume(request)` → canvas_focus_request_test「本画布的请求：帧后单选 + 移到视口中心，并消费掉」红。
8. `EdgeLaneErrorSlot` 关闭按钮的 `setState(() => _dismissed[source] = error)` 改成空 setState → canvas_view_test「边加载失败 → 非阻塞错误横幅，节点照常渲染；可关闭」红。
9. `StageEdgeDeleteOverlay` 删边成功后不调 `showCanvasUndoSnack` → canvas_view_test「删除连线 → Deleted · Undo；点 Undo → 调用 restore」红。
10. `StageLaneLayer._onDeleteLane` 去掉 `if (confirmed != true) return;` → stage_lane_layer_test「确认框点取消 ⇒ 不调 deleteLane」红。
11. `StageLaneLayer` 分界线 `onPanEnd: (_) => commit()` 改成空回调 → lane_interactions_test「拖拽泳道分界线 → 泳道宽度更新」红。
12. `StageLaneBackgroundLayer` 传给 LaneBackground 的 `dropTargetLaneId:` 改成 `null` → canvas_lane_drag_test「真拖进 Dusk：途中 Dusk 高亮…」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test` 零告警；`flutter test test/features/canvas test/features/shell test/quality --exclude-tags golden` 全绿；`git diff origin/main -M --color-moved=zebra --stat` 显示 canvas_view.dart 净减 ≥ 1300 行、新增五个 stage/ 文件，移动块着色为 moved。
- `git diff origin/main -- test/` 只有新增的 stage_lane_layer_test.dart。
- 不是 UI 片，不截图。

## 风险与不确定
- 骨架里 `_CanvasStage.build` 仍有约 450 行（InteractiveViewer + 卡片两组 Positioned）；卡片 Positioned 循环刻意留在骨架（Key 锚点在那里，W4 stage-drop / W5 group-drag 会改骨架），不再拆。
- 闭包变参数时容易把「每帧取 transform.value」写成「构造时取一次」：`StageLaneBackgroundLayer` 的 `dropTargetLaneOf` 必须在 select 回调里读 `transform.value`。
- `LaneToolbar` 在 `_CanvasBody` 的外层 Stack 里，不属于舞台层，留在骨架（偏离 contract「泳道工具条」的字面说法）。
