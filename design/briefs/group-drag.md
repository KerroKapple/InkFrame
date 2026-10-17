# group-drag · 整组拖动（按抓住的那张判换道）+ Shift 锁轴
- 波次 W5 / lane A / 基底 origin/main〔W0–W4 已合入〕
- 依赖切片：multi-select-core（W0）、canvas-view-split（W0）、undo-stack（W0）、nodes-batch-ops（W1）、undo-adopt-existing（W3）、marquee-select（W3）、undo-node-create-move（W4）、stage-drop-target（W4，同改 node_card.dart，已先合）
- 阻塞决定：无（Sel-Q2 已定 B）

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
选中多张卡后拖其中任一张，整组一起跟手移动，连线跟着走；拖一张没选中的卡 = 先把它单选再拖。是否换道只看抓住的那张（沿用 resolveCardDrop 的三道闸），全组进同一条道，途中目标道高亮、卡上方挂「移入「X」· N 张改继承风格」。松手整组一个事务、撤销栈一步。拖动中按住 Shift 只沿一个轴走，拖到一半按下或松开都即时生效。

## 设计依据
- Selection.dc.html ·「整组拖动 · PL-5 · 换道沿用 resolveCardDrop」（b2_selection.js 72–93 行）：
  - 拖选中的任一张 = 整组走；拖没选中的卡 = 先单选再拖（同右键）。
  - 换道：屏幕拖动 > 18px、中心跨过带边界、进新带 ≥ 12px，三条都满足才换（现有 kLaneChangeMinDrag / kLaneChangeMargin）。
  - 整组只看抓住的那张判（Q2 已定 B），全组进同一条道；途中高亮目标道（cardDropTargetLane，与松手同一判定），卡组上方挂提示「移入「水墨风格」· 2 张改继承风格」。
  - 起拖阈值只分「点」和「拖」，不参与判泳道。
  - 换了道弹撤销卡「已移入泳道「X」」，撤销 = 整组回原位、原道。
  - Shift = 只锁轴；Ctrl（⌘）= 原样放下（归 snapping，本片不做）。
  - moveNodes 整组一个事务，失败整组回滚 + 错误卡。
- KeyMap.dc.html · 指针表（b2_keys.js 140、148 行）：「拖卡 + Shift = 锁轴」「拖到一半按修饰键即时生效」。
- 设计缺口：提示挂在「卡组上方」，画板里画在舞台右上角，没定锚点——本片挂在抓住的那张卡上方（随卡走）。
- 设计缺口：整组换出所有道（目标 = 无道）时的提示文案画板没画；本片用「移出泳道 · N 张不再继承风格」。
- 设计缺口：锁轴按哪个轴没写；本片按累计位移的主分量（|dx| ≥ |dy| 锁横向），每帧重判。
- 设计缺口：选中集里有折叠泳道中的卡（看不见）时是否跟着走没写；本片不带它们（只动画得出来的卡）。

## 允许改的文件
- `lib/features/canvas/providers/node_drag_delta.dart`：`NodeDragDelta` 记录加 `ids` 字段（整组 id，含抓住的那张）；`nodeId` 字段**保留原名**，语义改为「抓住的那张」——这样 stage_lane_layer 里的 dropTargetLaneOf（main 上 canvas_view.dart:652，由 canvas-view-split 搬走）不用改：它本来就按 `drag.nodeId` 判，正是 Q2-B 的口径。
- `lib/features/canvas/widgets/node_card.dart`：起拖回调取组、广播带 ids；累计原始位移与显示位移分开，显示位移过 `filterDragOffset`；拖动期间挂 HardwareKeyboard 处理器，修饰键变化即时重算。
- `lib/features/canvas/widgets/node_card_slot.dart`（由 canvas-view-split 新建，含原 `_NodeCardSlot` / `_commitDrag`，main 上 canvas_view.dart:1283–1486）：起拖时定组（未选中先单选）、给 NodeCard 传锁轴 filter、非抓住的组员跟手位移（`GroupDragFollower`）、`_commitDrag` 改整组。
- 新 `lib/features/canvas/widgets/group_drag_hint.dart`：抓住那张卡上方的换道提示 chip。
- 新 `lib/features/canvas/util/drag_axis_lock.dart`：锁轴纯函数。
- `lib/features/canvas/util/drop_placement.dart`：新增 `resolveGroupDrop`（resolveCardDrop / cardDropTargetLane 不改）。
- `lib/features/canvas/widgets/edge_painter.dart`：`dragNodeId` 换成 `dragNodeIds`。
- `lib/features/canvas/widgets/stage_edge_layer.dart`（由 canvas-view-split 新建；main 上 canvas_view.dart:775–817）：给 EdgePainter 传 `drag?.ids`。
- 测试：见「测试」节列出的文件。

## 不许碰的文件
- W5 其他切片：`providers/canvas_edges_controller.dart`、`providers/link_action_controller.dart`、`util/canvas_tool_actions.dart`、`widgets/node_inputs_section.dart`（undo-edges）；`providers/inspector_submit_controller.dart`、`characters_section.dart`、`image_config_inspector.dart`、`video_config_inspector.dart`、`shot_config_inspector.dart`、`text_node_inspector.dart`（undo-params）；`left_rail/assets_panel.dart`、`left_rail/assets_model.dart`、`util/asset_drop_model.dart`、`util/canvas_asset_drop_actions.dart`、`canvas_menu/canvas_menu_host.dart`、`canvas_menu/asset_drop_menu_entries.dart`（rail-drag-assets）；`util/current_take_edges.dart`、`providers/current_take_controller.dart`、`generation/generation_controller.dart`、`widgets/canvas_job_listener.dart`（tc-take-edge-follow）。
- 热点、本片不需要：`canvas_view.dart` 骨架、`stage_pointer_layer.dart`、`stage_lane_layer.dart`、`stage_overlays.dart`、`canvas_nodes_controller.dart`（只调用 moveNodes）、`canvas_command.dart`（复用 MoveNodesCommand，不加 label）、`test/_harness/*`（录调用的 fake 写在新测试文件里）。

## 具体改动
```dart
// node_drag_delta.dart
typedef NodeDragDelta = ({String nodeId, Set<String> ids, Offset delta});
// nodeId = 抓住的那张；ids 在起拖时建一次，整趟拖动复用同一个 Set 实例（EdgePainter.shouldRepaint 靠 != 比较）。

// drag_axis_lock.dart
Offset lockDragAxis(Offset raw, {required bool shift});
// shift=false 原样；true：|raw.dx| >= |raw.dy| → Offset(raw.dx, 0)，否则 Offset(0, raw.dy)。

// node_card.dart（NodeCard 新增可选参数，旧调用方不传 = 现行为）
typedef DragGroupResolver = Set<String> Function();
typedef DragOffsetFilter = Offset Function(Offset raw);
final DragGroupResolver? onDragStartGroup; // 起拖时调一次；null = {node.id}
final DragOffsetFilter? filterDragOffset;   // 每次 pan update / 修饰键变化时对累计原始位移求显示位移；null = 原样
// _NodeCardState：新增 Offset _rawOffset；_dragOffset = filter(_rawOffset)；onDragEnd 交 _dragOffset。
// 起拖：HardwareKeyboard.instance.addHandler(_onKey)；_onKey 只在修饰键变化时 setState 重算 + 重新广播，返回 false（不吞键）。
// _endDrag / dispose：removeHandler。

// drop_placement.dart
typedef GroupMove = ({Offset delta, String? laneId});
typedef GroupDrop = ({Map<String, GroupMove> moves, String? laneId, bool changed, int restyled});
GroupDrop resolveGroupDrop({
  required CanvasNode grabbed,
  required List<CanvasNode> members, // 含 grabbed
  required Offset dragDelta,
  required List<({String id, double size})> laneSlices,
  required LaneDirection direction,
  required double scale,
});

// node_card_slot.dart
class GroupDragFollower extends ConsumerWidget { // 公开，测试按 nodeId 计数
  const GroupDragFollower({required this.nodeId, required this.child});
  // watch nodeDragDeltaProvider.select((d) => d != null && d.nodeId != nodeId && d.ids.contains(nodeId) ? d.delta : Offset.zero)
  // 只返回 Transform.translate(offset, child: child)——child（NodeCard）不重建。
}

// group_drag_hint.dart
class GroupDragHint extends ConsumerWidget { // 挂在抓住那张卡的插槽里，Stack(clipBehavior: Clip.none) + IgnorePointer
  const GroupDragHint({required this.canvasId, required this.nodeId, required this.lanes, required this.laneSlices, required this.direction, required this.transform});
}
```
- `resolveGroupDrop` 规则：`drop = resolveCardDrop(node: grabbed, …)`；`!drop.changed` → 每个成员 `(delta: dragDelta, laneId: 成员原 laneId)`；`changed` → 每个成员 laneId = drop.laneId，横截分量逐个换算：`startCross_i = 成员横截 + 半卡`，`endCross_i = startCross_i + dragDelta 横截`，按成员**自己原道**的 `laneStartOf` 走 `crossToScreen`，再按目标道走 `crossToWorld`，横截 delta = 结果 − startCross_i（换道前后每张卡屏幕位置不动）；主轴分量 = dragDelta 主轴。`restyled` = 原 laneId ≠ drop.laneId 的成员数。抓住那张的 move 必须等于 `drop.delta`。
- 插槽起拖（`onDragStartGroup`）：本卡未选中 → `canvasSelectionControllerProvider(canvasId).notifier.replace({node.id})`（multi-select-core 的 API）并返回 `{node.id}`；已选中 → 返回 选中集 ∩ 本画布当前画得出来的节点（canvasNodesControllerProvider 的值去掉 `laneCollapseProvider(canvasId)` 里折叠道的卡）。
- 插槽 `filterDragOffset` = `(raw) => lockDragAxis(raw, shift: HardwareKeyboard.instance.isShiftPressed)`（W6 snapping 在这条管线后面接吸附，保留成一个私有方法 `_filterDrag` 便于它扩展）。
- 插槽 build：`NodeCard` 外包 `GroupDragFollower(nodeId: node.id, child: …)`；抓住的那张自己的位移仍由 NodeCard 内部 Transform.translate 画（follower 对它返回 zero）。RepaintBoundary 保留在 follower 里面。
- `_commitDrag(totalDelta)`：取组成员（从 nodes 控制器按广播起拖时的 ids 取；拖动中被删的成员跳过），`resolveGroupDrop` → 一次 `CanvasNodesController.moveNodes(moves)`（nodes-batch-ops）→ 推**一条** `MoveNodesCommand`（W3/W4 已定义，带全部成员的旧位置 / 旧道）。换了道 → `showCanvasUndoSnack` 一张卡，文案沿用 `canvasNodeJoinedLane(目标道名)` / `canvasNodeLeftLane(抓住那张原道名)`，「撤销」= 该栈步 `undoSpecific`。失败 → 内存已由 moveNodes 回滚，`nodeMoveFailed` 错误卡，不推命令。把 W4 版本里单节点的 moveNode / 单节点命令改掉（文件内搜 `moveNode(` 与 `MoveNodesCommand(`）。
- `EdgePainter`：`final Set<String> dragNodeIds;`（默认 const {}），`_paintEdge` 里 `if (dragNodeIds.contains(src.id)) p1 += dragDelta;` 同理 p2；shouldRepaint 比 `dragNodeIds != old.dragNodeIds`。stage_edge_layer 传 `dragNodeIds: drag?.ids ?? const {}`。
- `GroupDragHint`：watch `nodeDragDeltaProvider.select((d) => d?.nodeId == nodeId ? d : null)`（只有抓住那张的插槽每帧重建这一个小部件），本地算 `resolveGroupDrop`；`changed` 时在卡片上方（top = −(chip 高 + InkSpacing.sm)，跟随 delta）画 chip：泳道图标 + 文案，样式用 wash / washBorder / accent 令牌（与泳道高亮同色系），无交互。

## 行为规则与边界情况
1. 选中 3 张，拖其中任一张：3 张同位移跟手；未选中的卡不动。
2. 拖未选中的卡（无论之前选了什么、是否按着修饰键）：起拖那一刻选中集变成只有它，只它走。
3. 点击（未过平移阈值）不触发 onDragStartGroup，不改选中（现有 onTap 逻辑不变）。
4. 换道只看抓住那张：别的组员跨了道界、抓住那张没满足三道闸 → 全组不换道，各自留在原道。
5. 抓住那张满足换道 → 全组 laneId = 目标道（含原本就在目标道里的），每张屏幕位置松手前后不动。
6. 途中目标道高亮与提示的出现 / 消失与松手结果一致（同一个 resolveCardDrop）。
7. 提示里 N = 换道后风格继承会变的张数（原 laneId ≠ 目标）。
8. 松手：moveNodes 恰好一次，撤销栈恰好一步；Ctrl Z 后整组回原位、原道。换了道才弹卡。
9. moveNodes 失败：整组回到拖前位置，错误卡一张，栈无新步。
10. 拖动中组员被删（Delete 键）：松手跳过它，其余照常；抓住那张被删：现有 dispose 兜底清广播（判据改成 `broadcast.state?.nodeId == nodeId`，不变）。
11. Shift 锁轴：拖动中任意时刻按下 / 松开 Shift，不动鼠标卡片也立刻按新规则重画（键盘处理器触发），连线、跟随组员、提示同步；松手位移按锁轴后的值落。
12. 锁轴后再判换道（锁轴在 resolveCardDrop 之前）：锁到主轴时横截位移为 0，不会换道。
13. 性能（HI-13 / HI-15）：拖动帧里非组员卡的 NodeCard 不重建、widget 实例不变；跟随组员只重建 GroupDragFollower，NodeCard 实例不变；连线层每帧只重绘 EdgePainter。
14. 平移生效（_PanGate）时卡片收不到指针，本片不改。
15. mac / Windows：Shift 在两端相同；HardwareKeyboard 处理器返回 false，不影响快捷键。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasGroupDragHintJoin（placeholders: lane String, count int） | Move into “{lane}” · {count} will inherit its style | 移入「{lane}」· {count} 张改继承风格 |
| canvasGroupDragHintLeave（placeholders: count int） | Move out of lanes · {count} will stop inheriting style | 移出泳道 · {count} 张不再继承风格 |

## 测试
- `test/features/canvas/util/drag_axis_lock_test.dart`（新）：`shift=false 原样`；`|dx|>|dy| 锁横向`；`|dy|>|dx| 锁纵向`；`相等锁横向`；`负值保留符号`。
- `test/features/canvas/util/drop_placement_test.dart`（追加 group `resolveGroupDrop`）：
  - `抓住的不换道 → 每张保留原 laneId，delta 原样`
  - `抓住的进 Dusk → 全组 laneId=Dusk；来自 Rain 的组员屏幕横截位置不变`（用 crossToScreen 前后对比，scale 0.5）
  - `抓住那张的 move == resolveCardDrop(...).delta`
  - `组员跨界、抓住那张没跨 → changed=false`
  - `restyled 只数原 laneId ≠ 目标的`
- `test/features/canvas/widgets/canvas_group_drag_test.dart`（新；夹具照 canvas_lane_drag_test.dart：Rain / Dusk 两道 + RecordingNodesController 的本地子类记录 moveNodes 调用）：
  - `选中 A B C 拖 A：三张跟手同位移，D 不动；松手 moveNodes 只调一次、map 含 3 项`
  - `拖未选中的 D：选中变 {D}，只 D 走`
  - `整组拖进 Dusk：途中 Dusk 高亮 + 提示 “Move into “Dusk” · 2 will inherit its style”；松手全组 laneId=Dusk；一张撤销卡；点 Undo 全组回原位原道`
  - `20 张卡选 3 张拖 10 帧：非组员与跟随组员的 NodeCard widget 实例 identical 不变；debugOnRebuildDirtyWidget 对非抓住卡的 NodeCard 计数 0；GroupDragFollower 只在组员上重建`（在第一帧 moveBy 之后开始取样，结束前停）
  - `连线跟随：组员之间和组员到外部的边，EdgePainter.dragNodeIds 含 3 个 id`
  - `拖到 (60,20) 后按下 Shift 不动鼠标：卡片纵向位移立即归 0；松开 Shift 恢复`
  - `moveNodes 抛 InkError：全组回原位，错误卡 Failed to move node，栈深度不变`
- `test/features/canvas/widgets/node_card_drag_test.dart`（追加）：`广播带 ids（不传 onDragStartGroup = {自己}）`；`onDragStartGroup 起拖时调一次、点击不调`；`filterDragOffset 的返回值就是 onDragEnd 收到的位移`。
- `test/features/canvas/widgets/edge_painter_test.dart`（追加）：`dragNodeIds 两端都在组里 → 整条线平移 delta`；`只一端在组里 → 只那一端移`。

## 变异点
1. resolveGroupDrop 改成每个成员各自调 resolveCardDrop → `组员跨界、抓住那张没跨` 红。
2. 换道时组员横截 delta 直接用抓住那张的 drop.delta → `来自 Rain 的组员屏幕横截位置不变` 红。
3. 插槽改为 watch 整个 nodeDragDeltaProvider（或 follower 把 NodeCard 放进 builder 里新建）→ 重建计数用例红。
4. 起拖时未选中卡不先 replace 选中 → `拖未选中的 D` 红。
5. 去掉 NodeCard 的 HardwareKeyboard 处理器 → `按下 Shift 不动鼠标` 红。
6. EdgePainter 只认 nodeId → edge_painter `整条线平移` 与集成用例的连线断言红。
7. _commitDrag 每张调一次 moveNode / 推多条命令 → `moveNodes 只调一次` 与 Undo 用例红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas`；逐条跑上面的变异。
- 截图：CanvasView，两条横向泳道 Rain / Dusk，Rain 里 2 张视频配置 + 1 张自由卡全选；截 (1) 拖动途中跨进 Dusk：Dusk 高亮 + 提示 chip，(2) 松手后撤销卡，(3) Shift 锁轴拖动中。

## 风险与不确定
- MoveNodesCommand 的形状以 W3/W4 落地为准；若它只收单节点，需要扩成 Map（它定义在 models/commands/ 下，W5 本片未被分配该文件——若必须改，回报主 Agent）。
- moveNodes 对缺失 id 的口径以 nodes-batch-ops 为准（跳过 / 抛错），规则 10 依赖跳过。
- W6 snapping 和 W7 cm-drag-insert 会在 `_filterDrag` 与 `_commitDrag` 上继续改，本片把两者写成独立私有方法，别内联。
- 跟随组员在不同泳道组里各自 Transform.translate 世界位移，缩放下屏幕位移一致（泳道组只平移）；如果拆分后泳道组改成带缩放的变换，这一条要重核。
