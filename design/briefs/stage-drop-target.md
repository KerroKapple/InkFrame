# stage-drop-target · 舞台应用内拖放底座：sealed 拖放载荷 + 舞台 DragTarget + 悬停卡琥珀虚线高亮 + 按载荷分派表
- 波次 W4 / lane C / 基底 origin/main〔W0–W3 已合入〕；依赖切片：canvas-view-split（W0）；阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 从左栏（以及之后的节点库）拖东西进画布时，舞台能接住：指针压在「这个载荷能落」的卡上，那张卡的图区描边变成 1.5px 琥珀虚线；压在空白处、而落点在某条泳道里时，那条泳道像拖卡片换道一样高亮。
- 松手后按载荷类型交给对应的处理器（本片只搭底座、不接任何具体载荷；W5 rail-drag-assets、W9 rail-drag-characters、W18 node-library-drag-recents 各往分派表里追加一行）。
- 本片合入后用户侧看不到新功能（没有注册处理器 = 舞台不接任何载荷），行为零变化。

## 设计依据
- ImportSearch.dc.html ·「从左栏拖进画布」（colB）：mock 里目标卡 `镜头 02` 的图区 `outline: 1.5px dashed accent`；拖动中的缩略跟着指针（60×34、accent 1px 描边、阴影）；规则「左栏包 Draggable、舞台加 DragTarget，不用新依赖」。
- 同板 colB 规则：「素材拖到空白处：建导入式产物节点」「拖到配置节点：松手弹菜单」「视频素材没有合法项，按落空白处理」——对底座的要求：①命中卡片要问处理器「这张卡算不算目标」，不算就当空白；②空白落点要带泳道归属（复用 resolveLaneDrop / createNodePlacement）。
- 泳道高亮沿用现有拖卡片换道的视觉（LaneBackground.dropTargetLaneId，canvas_view.dart:719–733）。
- 设计缺口：板上没画「拖到空白处」时舞台是否有整体提示（OS 拖入那种整块虚线框是 W9 的），本片空白处只做泳道高亮；没画拖动中按 Esc 取消（Flutter Draggable 不认 Esc），本片不做，记进风险。

## 允许改的文件
- `lib/features/canvas/models/canvas_drag_payload.dart`（新）：sealed `CanvasDragPayload` + 本片就定义的两个子类 `AssetDragPayload`、`CharacterDragPayload`（字段见下）；其余载荷（nodeLibraryItem / recentParams / promptPreset）由各自切片「追加一行 `part 'drag_payloads/<x>_payload.dart';` + 新 part 文件」。
- `lib/features/canvas/providers/canvas_drop_hover.dart`（新）：`canvasDropHoverProvider`。
- `lib/features/canvas/widgets/stage_drop/stage_drop_target.dart`（新）：`StageDropTarget` 组件、`StageDropHandler` 抽象、`CanvasPayloadDraggable` 包装件。
- `lib/features/canvas/widgets/stage_drop/stage_drop_registry.dart`（新，**注册表：之后每片只追加一行**）：`kStageDropHandlers` 常量表 + `stageDropHandlersProvider`。本片表为空。
- `lib/features/canvas/util/drop_placement.dart`：追加纯函数 `stagePaintOrder`、`resolveStageDrop`（见下），不改已有函数。
- `lib/features/canvas/widgets/canvas_view.dart`（骨架，canvas-view-split 后的版本）：① `_CanvasBody.build` 里把 `canvasArea`（现 main 第 381–394 行，空画布 `CanvasEmptyState` 与 `_CanvasStage` 两支都要）包进 `StageDropTarget(canvasId:, child: canvasArea)`——包在 `Positioned.fill(child: …)` 里面、`CanvasMenuHost` 之内，坐标系 = 舞台视口（与菜单锚点同一个）；② `_CanvasStage` 里 `paintOrder` 的现算（main 第 609–615 行，canvas-view-split 后仍在骨架）改调 `stagePaintOrder`；③ 骨架构造 `StageLaneBackgroundLayer(...)` 时多传一个 `canvasId:`。
- `lib/features/canvas/widgets/stage/stage_lane_layer.dart`（canvas-view-split 把 main 第 648–668 行 `dropTargetLaneOf` 与第 716–737 行泳道底色块搬进了这里的 `StageLaneBackgroundLayer`；W4 无他片占用，链上前一片是 W2 lane-ops-core、后一片 W6 undo-lanes）：只动 `StageLaneBackgroundLayer`——构造加 `required String canvasId`；内部 `Consumer` 里 LaneBackground 的 `dropTargetLaneId` 改成「拖卡片的目标道 ?? 载荷悬停的泳道」：`ref.watch(nodeDragDeltaProvider.select(dropTargetLaneOf)) ?? ref.watch(canvasDropHoverProvider(canvasId).select((h) => h?.cardId == null ? h?.laneId : null))`。`StageLaneLayer` / `StageLaneShift` 不动。
- `lib/features/canvas/widgets/node_card.dart`：图区外圈描边（main 第 354–368 行那个 `Positioned(left:-1…)`）在「本卡是载荷悬停目标」时换成虚线；新增测试锚点 `NodeCard.dropOutlineKey`。
- `lib/theme/primitives/ink_dashed_outline.dart`（新）：`InkDashedOutline`（只画虚线 RRect 外框的 CustomPaint，参数 color / radius / strokeWidth / dash / gap）。InkDashedSlot 的 painter 是私有的、边色写死 outline，不改它。
- 测试：`test/features/canvas/util/drop_placement_test.dart`（追加组）、`test/features/canvas/widgets/canvas_stage_drop_target_test.dart`（新）、`test/features/canvas/widgets/node_card_drop_outline_test.dart`（新）、`test/theme/primitives/ink_dashed_outline_test.dart`（新，可选）。

## 不许碰的文件
- `lib/features/canvas/widgets/stage/node_card_slot.dart`、`canvas_tool_actions.dart`、`shot_config_inspector.dart`、`models/commands/create_nodes_command.dart`、`util/canvas_history_actions.dart`（W4 undo-node-create-move）。
- `generation/providers/batch_results_controller.dart`、`batch_results_grid.dart`、`batch_compare_overlay.dart`、`batch_slot_parts.dart`、`util/batch_slot_view.dart`、`inspector_history_panel.dart`、`providers/current_take_controller.dart`、`models/commands/set_current_take_command.dart`、`models/commands/set_current_slot_command.dart`（W4 tc-batch-slot-set-current）。
- `theme/components/ink_window_chrome.dart`、`ink_menu_bar.dart`、`ink_menu_panel.dart`、`features/shell/**`（W4 win-menubar）；`storage/schema/*`、`storage/migrations/*`、`core/db/columns.dart`、`core/di/repositories.dart`（W4 export-records-table）。
- `left_rail/*`、`character_library_panel.dart`、`canvas_menu/*`（本片不接任何载荷源，也不开菜单）。

## 具体改动
```dart
// models/canvas_drag_payload.dart
sealed class CanvasDragPayload { const CanvasDragPayload(); }
// 左栏素材格：GalleryItem 的落盘信息 + 所在项目。
final class AssetDragPayload extends CanvasDragPayload {
  const AssetDragPayload({required this.projectId, required this.canvasId, required this.nodeId,
    required this.kind /* GalleryItemKind */, required this.relativePath, this.slotIndex,
    this.thumbnailRelativePath, this.durationMs});
  factory AssetDragPayload.fromGalleryItem(GalleryItem item, {required String projectId});
}
// 左栏角色行（W9 用）。
final class CharacterDragPayload extends CanvasDragPayload {
  const CharacterDragPayload({required this.projectId, required this.characterId, required this.name});
}
// 预留：后续片在这里追加 part 行（每片一行）

// providers/canvas_drop_hover.dart
typedef StageDropHover = ({String? cardId, String? laneId});
final canvasDropHoverProvider = AutoDisposeNotifierProviderFamily<CanvasDropHoverController, StageDropHover?, String>(...);
class CanvasDropHoverController extends AutoDisposeFamilyNotifier<StageDropHover?, String> {
  void set(StageDropHover? next); // 与 state 记录相等就不写（不触发重建）
  void clear();
}

// util/drop_placement.dart（追加）
/// 卡片的绘制顺序：无道（或道已不存在）的先画，再按泳道顺序画道内的；折叠道里的不画（不参与命中）。
List<CanvasNode> stagePaintOrder({required List<CanvasNode> nodes, required List<StyleLane> lanes, required Set<String> collapsedIds});
/// 视口点 → 一次拖放的落点：指针压着的最上面那张卡（舞台坐标 + 分道位移命中，同 topmostNodeAt）+ 空白落点（createNodePlacement）。
typedef StageDrop = ({Offset viewportPoint, NodePlacement placement, String? cardId});
StageDrop resolveStageDrop({required Offset viewportPoint, required Matrix4 transform,
  required List<CanvasNode> paintOrder, required List<({String id, double size})> laneSlices,
  required LaneDirection direction});

// widgets/stage_drop/stage_drop_target.dart
typedef StageDropContext = ({BuildContext context, WidgetRef ref, String canvasId});
abstract class StageDropHandler<P extends CanvasDragPayload> {
  const StageDropHandler();
  bool handles(CanvasDragPayload payload) => payload is P;
  /// 这张卡算不算 [payload] 的目标卡：算 → 悬停高亮、松手 cardId 带过去；不算 → 当空白。
  bool acceptsCard(P payload, CanvasNode card);
  /// 空白处能不能落；false → 空白处不高亮泳道、松手什么都不做。
  bool acceptsBlank(P payload) => true;
  /// 松手。[card] = 命中且 acceptsCard 的那张卡，否则 null（= 落空白）。
  Future<void> onDrop(StageDropContext ctx, P payload, {required StageDrop drop, CanvasNode? card});
}
class StageDropTarget extends ConsumerWidget { const StageDropTarget({required this.canvasId, required this.child}); }
/// 载荷源统一用它：dragAnchorStrategy 固定 pointerDragAnchorStrategy（DragTargetDetails.offset 才是指针位置）。
class CanvasPayloadDraggable extends StatelessWidget {
  const CanvasPayloadDraggable({required this.payload, required this.feedback, required this.child, this.onDragStarted});
}

// widgets/stage_drop/stage_drop_registry.dart
/// 舞台拖放分派表：按顺序找第一个 handles(payload) 的处理器。新载荷 = 在这里追加一行，别处不改。
const List<StageDropHandler<CanvasDragPayload>> kStageDropHandlers = <StageDropHandler<CanvasDragPayload>>[
  // W5 rail-drag-assets: AssetStageDropHandler(),
  // W9 rail-drag-characters: CharacterStageDropHandler(),
];
final stageDropHandlersProvider = Provider<List<StageDropHandler<CanvasDragPayload>>>((ref) => kStageDropHandlers);
```
`StageDropTarget` 状态机：`DragTarget<CanvasDragPayload>`——
- `onWillAcceptWithDetails`：表里有 `handles` 的处理器 → true；否则 false（不悬停、不高亮）。
- `onMove`：`details.offset`（全局）→ `(context.findRenderObject() as RenderBox).globalToLocal` 得视口点 → 用此刻的 nodes（canvasNodesControllerProvider valueOrNull）、lanes、collapse、direction、transform 算 `resolveStageDrop` → 命中卡且 `acceptsCard` → `set((cardId: id, laneId: null))`；否则 `acceptsBlank` → `set((cardId: null, laneId: placement.laneId))`，不接受空白 → `set(null)`。相机与泳道读法照 `menuNodePlacement`（canvas_tool_actions.dart:311）的口径（无泳道不读方向）。
- `onLeave`：`clear()`。`onAcceptWithDetails`：先 `clear()`，再按同一套算出 drop，调处理器 `onDrop`（`unawaited`，处理器自己报错）。
- 只 `ref.read`，不 watch 节点表（拖放不该让包装层随节点变化重建）。

`NodeCard`：`final bool dropHover = canvasId.isNotEmpty && ref.watch(canvasDropHoverProvider(canvasId).select((h) => h?.cardId == node.id));`（canvasId 取 `node.canvasId ?? ''`，同 `_ConfigBody` 第 626 行做法，不新加构造参数、不碰 node_card_slot）。dropHover 时外圈换成 `InkDashedOutline(key: NodeCard.dropOutlineKey, color: colors.accent, strokeWidth: 1.5, radius: InkRadius.s5, dash: 4, gap: 3)`，其余时候原样实线。

## 行为规则与边界情况
1. 分派表为空（本片合入时）：任何载荷拖到舞台上都不被接受，`canvasDropHoverProvider` 始终为 null，画面无变化。
2. 指针压着卡、处理器 `acceptsCard` 为 true：只有那一张卡出虚线；移到另一张可接受的卡，前一张立刻恢复实线（同一时刻至多一张）。
3. 压着卡但 `acceptsCard` 为 false：按空白算——那张卡不出虚线；若落点在泳道里，那条泳道高亮。
4. 两张卡叠放：命中最上面那张（与 `onWireDrop` 同一绘制顺序，`stagePaintOrder` 倒着找）。
5. 折叠泳道里的卡不参与命中（不画就不命中）。
6. 泳道里的卡按渲染位置（含分道位移）命中，缩放 ≠ 1 时也对。
7. 拖出舞台（回到左栏 / 移出窗口）：高亮全部消失（onLeave）。
8. 松手：先清高亮再分派；处理器拿到的 `drop.placement` 与新建菜单在同一点开出来的落点完全一致（同一个 createNodePlacement）。
9. 空画布（`CanvasEmptyState` 那一支）也能接：没有卡可命中，只有空白落点。
10. 拖卡片换道的泳道高亮（nodeDragDeltaProvider）优先于载荷悬停；两者不会同时发生，但合并写法不能让任何一路丢失。
11. 平移工具开着时照样接拖放（DragTarget 不经 `StagePanGate`）；拖放不进撤销栈（底座本身不写库）。
12. mac / Windows 无差异（应用内拖放，不涉及系统拖放）。

## 新文案键
无

## 测试
- `test/features/canvas/util/drop_placement_test.dart`（追加 group `resolveStageDrop`）：
  - `命中最上面那张`：两卡叠放，返回后画的那张 id。
  - `泳道里的卡按分道位移命中`：缩放 0.5、卡在第二条道，视口点落在渲染位置上 → 命中；落在世界坐标原位上 → 不命中。
  - `空白落点与 createNodePlacement 一致`：cardId 为 null，placement 等于同参的 createNodePlacement。
  - `stagePaintOrder 跳过折叠道`：折叠道里的节点不在结果里，顺序 = 无道 → 各道按 lanes 顺序。
- `test/features/canvas/widgets/canvas_stage_drop_target_test.dart`（新；装配照 canvas_lane_drag_test.dart：FakeNodes / FakeEdgesController / StubFileResolver + `stageDropHandlersProvider` override 成一个记录型假处理器 `_RecordingAssetHandler`，`acceptsCard` 只认 `type == video`）：
  - `没有处理器时不接受`：override 成空表，拖一个 `CanvasPayloadDraggable(AssetDragPayload)` 到卡上 → hover 一直 null、无 `NodeCard.dropOutlineKey`。
  - `悬停可接受的卡出虚线`：拖到视频卡上 → `find.byKey(NodeCard.dropOutlineKey)` 只有 1 个，在该卡子树里。
  - `不接受的卡当空白`：拖到图像卡上 → 无虚线，hover.cardId == null。
  - `空白处在泳道里高亮泳道`：两条横向泳道，拖到第二条道的空白 → `LaneBackground.dropTargetLaneId == 'lane-2'`。
  - `拖出舞台清高亮`：先压在卡上再移到舞台外（测试里放一个舞台外的区域）→ 无虚线、hover null。
  - `松手分派`：在视频卡上松手 → 处理器收到 1 次 onDrop，card.id 正确；在空白松手 → card null、placement.world 等于 createNodePlacement。
  - `空画布也能接`：节点表为空 → 松手 onDrop 被调、card null。
- `test/features/canvas/widgets/node_card_drop_outline_test.dart`（新）：直接改 `canvasDropHoverProvider('c1')` 状态 → 目标卡出虚线、别的卡没有；清空后消失；`node.canvasId == null` 时不读 provider、不崩。

## 变异点
1. `StageDropTarget.onLeave` 去掉 `clear()` → `拖出舞台清高亮` 红。
2. `onMove` 里不问 `acceptsCard`、命中即当目标 → `不接受的卡当空白` 红。
3. `resolveStageDrop` 改成正着找第一张（`for i in 0..`）→ `命中最上面那张` 红。
4. `resolveStageDrop` 用 `nodes` 原坐标、不过 `displacedNodes` → `泳道里的卡按分道位移命中` 红。
5. `onWillAcceptWithDetails` 恒返回 true → `没有处理器时不接受` 红（hover 被写）。
6. NodeCard 的 select 判据改成 `h != null` → `node_card_drop_outline_test` 的「别的卡没有」红。
7. stage_lane_layer 里 StageLaneBackgroundLayer 的 dropTargetLaneId 合并去掉 `?? 载荷悬停泳道` → `空白处在泳道里高亮泳道` 红。
8. `stagePaintOrder` 不跳折叠道 → `stagePaintOrder 跳过折叠道` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/util/drop_placement_test.dart test/features/canvas/widgets/canvas_stage_drop_target_test.dart test/features/canvas/widgets/node_card_drop_outline_test.dart test/features/canvas/widgets/canvas_lane_drag_test.dart test/features/canvas/widgets/canvas_view_test.dart`（后两个不改、仍绿：拖卡片换道高亮没坏）。
- 变异 1–8 逐条。
- 截图（widget：`CanvasView`，两条横向泳道 + 道外一张视频配置卡 + 道内一张图像卡，假处理器只认视频卡）：①拖动中压在视频卡上（虚线 + 跟手缩略）；②压在第二条道空白（泳道高亮、卡全实线）；③压在图像卡上（无虚线）。

## 风险与不确定
- 主 Agent 交代「在 canvas_view 骨架里留分派表」。我把分派点放在 canvas_view（挂一次 `StageDropTarget`），把**表本体**放进独立的 `stage_drop/stage_drop_registry.dart`：canvas_view 骨架在 W6（cm-edge-menu）/ W9（os-drop）/ W13 都有人占，表放在骨架里会让 W5 / W9 / W18 的「追加一行」与这些片抢同一个热点文件。后续片只改注册表文件，不碰 canvas_view。
- sealed 子类必须同库：后续载荷用 `part` 文件，`canvas_drag_payload.dart` 按注册表对待（每片一行 part）。分派表是运行时按 `handles` 找的，不是穷举 switch，新增载荷不会让别处编译失败——但也意味着漏注册处理器时编译器不提醒（由各片的 widget 测试兜）。
- Flutter `Draggable` 没有 Esc 取消；拖动中按 Esc 只会走 Esc 阶梯的其它层。设计缺口，先不做。
- `DragTargetDetails.offset` 是 feedback 左上角：所有载荷源必须用 `CanvasPayloadDraggable`（锁定 pointerDragAnchorStrategy），否则落点偏一个缩略图尺寸。
- （复核已定）canvas-view-split 把 LaneBackground 的 `dropTargetLaneOf` 接线搬进了 `stage/stage_lane_layer.dart` 的 `StageLaneBackgroundLayer`，`paintOrder` 仍在骨架：本片因此改 stage_lane_layer.dart（只动 StageLaneBackgroundLayer，已列入允许清单），骨架只多传 canvasId。`StageDrop.placement` 用 drop_placement.dart 里原有的 `NodePlacement = ({Offset world, String? laneId})`（W3 的 MoveNodesCommand 也复用它，全仓只有这一个）。
