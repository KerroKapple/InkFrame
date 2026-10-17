# lane-ops-core · 泳道操作底座：解散（节点留下）与删除泳道和内容；修删道后 lane_id 悬空
- 波次 W2 / lane D / 基底 origin/main（届时已含 W0–W1；本片改的 `stage/stage_lane_layer.dart` 由 canvas-view-split 新建）；依赖切片：canvas-view-split（文件）、undo-stack（只读，确认本片**不**登记进栈）；阻塞决定：无。
- 「新道插在最后一条目标道之后」（ContextMenus 包成泳道）不归本片，引用 Selection Q5，归 wrap-in-lane。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/lane-ops-core`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
- 泳道标题栏的删除键改成「解散泳道（节点留下）」：不再弹确认框，道没了、道里的卡片**原地不动**并变成道外节点，右下角出一张 8 秒撤销卡。
- 修掉现有 bug：今天删道后节点的 `lane_id` 还指着已删的道（卡片跳位、之后生成的产物继承悬空 lane_id）。
- 新增「删除泳道和内容」底座：道 + 道内全部节点 + 这些节点的入 / 出边一个事务软删，带撤销卡；道内有生成中任务时先确认（会取消任务）。本片只提供动作函数，菜单入口归 W7 cm-lane-menu。

## 设计依据
- ContextMenus.dc.html ›「泳道 · 标题栏右键」：
  - 「解散（节点留下）= 现有「删除泳道」，补清节点 lane_id、屏幕位置不动——现在软删后节点还指着已删的道」。
  - 「删除泳道和内容：一个事务软删道 + 道内节点及其边」。
  - 「两项分开进撤销栈、分开命名：「解散泳道」「删除泳道和内容」，各算一步、互不合并」。
  - 「都不弹确认，走撤销卡；唯一例外：道内有生成中的任务——取消任务撤不回来，先确认」。
- UndoClipboard.dc.html ›「和撤销卡的关系」：「解散（节点留下）不确认：清掉道内节点的 lane_id、位置不动，直接解散 + 卡」；「删除泳道和内容：一个事务软删道和道内节点；道内有生成中任务先确认，否则直接删 + 卡。和解散是两个动作、两步」。进栈名「解散泳道「水墨」」「删除泳道「水墨」和 4 个节点」。
- critic.txt 第二节第 14 条：区分两件事、分别命名。
- plan.md §3 W2：解散后屏幕位置不变、lane_id 清空；删除时道、节点、边在一个事务里。
- 进栈归 W6 undo-lanes：本片返回撤销令牌、只接撤销卡，**不调** `canvasHistoryControllerProvider.record`。现状没有删道撤销卡（只有确认框），所以没有「保持旧卡行为」的负担。
- 设计缺口：①解散折叠中的道时屏幕位置以什么为准（道折叠时卡片不画）——本片定：按**展开厚度**换算（等于先展开再解散）；②解散后后面的道会整体前移（道栈收拢），那些道里的卡跟着道走，画板没画——本片照此；③「生成中」确认框的文案与按钮画板没画——见新文案键。

## 允许改的文件
- `lib/features/canvas/util/lane_dissolve.dart`（新，纯 Dart）：撤销令牌类型、解散后位置换算、道内活动任务判据。
- `lib/features/canvas/providers/canvas_lanes_controller.dart`：删掉 `deleteLane`（唯一调用点改走解散，零兼容），新增四个方法（见具体改动）；一律 `serialize` + UnitOfWork。
- `lib/features/canvas/util/canvas_lane_actions.dart`（新，偏离 contract 的加法，见风险）：带 BuildContext 的两个动作（撤销卡、确认框、取消任务、清选中）。
- `lib/features/canvas/widgets/stage/stage_lane_layer.dart`（由 canvas-view-split 新建）：原 `_onDeleteLane`（canvas_view.dart 第 1212–1248 行搬来的那段）整段删掉，标题栏 `onDelete` 改为 `dissolveLaneWithUndo(...)`。
- `lib/features/canvas/widgets/lane_title_bar.dart`：删除键 tooltip 由 `l10n.laneDelete` 改为 `l10n.laneDissolve`；参数名 `onDelete` 改 `onDissolve`（只有 stage_lane_layer 一个调用方）。图标不变。
- `test/features/canvas/widgets/stage/stage_lane_layer_test.dart`（由 canvas-view-split 新建）：「删除键 → 确认框 → deleteLane」「确认框点取消」「deleteLane 抛错出 laneDeleteFailed」三条改写为解散语义（无确认框、调 dissolveLane、失败出 laneDissolveFailed），编辑键那条不动。
- 测试：`test/features/canvas/util/lane_dissolve_test.dart`（新）、`test/features/canvas/util/canvas_lane_actions_test.dart`（新）、`test/features/canvas/canvas_lanes_controller_test.dart`（改）、`test/features/canvas/widgets/lane_interactions_test.dart`（加用例）、`test/features/canvas/widgets/lane_title_bar_test.dart`（改 tooltip / 参数名）。

## 不许碰的文件
- media-import-service（同波 lane E）：`providers/canvas_nodes_controller.dart`、`providers/media_import_controller.dart`、`widgets/node_card.dart`、`services/orphan_file_reaper.dart`、`storage/repositories/postgres_node_repository.dart`、`core/di/media_import.dart`、`models/canvas_node_import.dart`。本片**不给 CanvasNodesController 加方法**，节点改动在泳道控制器的事务里直写仓储，提交后让节点 / 边控制器失效重载。
- undo-shortcuts-ui：`shortcuts/undo_keys.dart`、`canvas_menu/undo_menu_items.dart`、`util/canvas_history_actions.dart`、`settings/util/shortcut_catalog.dart`（它在 W2 改修饰键顺序与键名白名单）。
- node-cost：`canvas_prompt_bar.dart`、`generation/services/cost_estimator.dart`、`node_cost.dart`、`image_config_inspector.dart`、`video_config_inspector.dart`、`inspector_status_panel.dart`、`cost_breakdown_tooltip.dart`。
- gen-inputs-snapshot：`generation/generation_controller.dart`、`services/import/import_remapper.dart`、`gen_inputs_snapshot.dart`、`lib/core/models/gen_inputs.dart`（新）、项目包导出侧。
- 也不碰：`canvas_view.dart` 骨架、`stage/node_card_slot.dart`、`stage/stage_edge_layer.dart`、`canvas_snackbars.dart`（只调用）、`node_menu_model.dart`（只调用 `laneMoveDelta`）、`lane_collapse_controller.dart`（只调用 `toggle`）、四张注册表。
- （主 Agent 自查补充）media-import-service：`lib/core/interfaces/media_import_service.dart`（新）、`lib/services/file_media_import_service.dart`（新）。
- （主 Agent 跨批核对补充）撤销卡调用写法：本片两处 `showCanvasUndoSnack(context, message: …, onUndo: …)` 用 main 上现有的回调形；W3 undo-adopt-existing 把它改成「按步 id 登记」时保留可选 `onUndo` 回调形（专给本片这两处用，不进栈），W6 undo-lanes 把这两处改成进栈，W6 合完后由主 Agent 删掉回调形。本片照现有签名写即可。

## 具体改动
```dart
// lib/features/canvas/util/lane_dissolve.dart
typedef LaneNodeSnapshot = ({String nodeId, Offset position});
class LaneDissolution { const LaneDissolution({required this.lane, required this.nodes}); final StyleLane lane; final List<LaneNodeSnapshot> nodes; } // nodes = 解散前的世界坐标
class LaneContentsDeletion { const LaneContentsDeletion({required this.lane, required this.nodeIds, required this.edgeIds}); final StyleLane lane; final List<String> nodeIds; final List<String> edgeIds; }
/// 解散后每张卡的新世界坐标：屏幕上不动。被解散的道按展开厚度算（折叠也一样），其余道按 collapseLaneSlices 的有效厚度；
/// 逐张调 node_menu_model.laneMoveDelta(toLaneId: null)。
Map<String, Offset> dissolvedPositions({required List<CanvasNode> laneNodes, required String laneId, required List<StyleLane> lanes, required Set<String> collapsed, required LaneDirection direction, required double scale});
/// 道内非终态 job（sourceNodeId 或 resultNodeId 落在 laneNodeIds，且 canvasId 相同）。
List<JobState> activeJobsInLane({required String canvasId, required Set<String> laneNodeIds, required List<JobState> jobs});

// canvas_lanes_controller.dart（CanvasLanesController 新增；deleteLane 删除）
Future<LaneDissolution?> dissolveLane(String laneId, {required Map<String, Offset> positions});
Future<void> restoreDissolved(LaneDissolution token);
Future<LaneContentsDeletion?> deleteLaneWithContents(String laneId);
Future<void> restoreLaneContents(LaneContentsDeletion token);

// lib/features/canvas/util/canvas_lane_actions.dart
Future<void> dissolveLaneWithUndo(BuildContext context, WidgetRef ref, {required String canvasId, required StyleLane lane});
Future<void> deleteLaneWithContentsWithUndo(BuildContext context, WidgetRef ref, {required String canvasId, required StyleLane lane});
```
- `dissolveLane` 事务内：`scope.nodes.listByCanvas(canvasId)` 取 **库里** `lane_id == laneId` 的行（不只信内存）→ 逐行 `scope.nodes.update(id, {position_x, position_y（positions 里有才写）, lane_id: null})` → `scope.styleLanes.softDelete(laneId)`。提交后 `ref.invalidate(canvasNodesControllerProvider(canvasId))`、`await ref.read(canvasNodesControllerProvider(canvasId).future)`，**之后**才把本道从泳道 state 里拿掉（避免道先消失、卡片按旧 lane_id 闪一帧）。令牌里的快照取事务里读到的旧坐标。
- `deleteLaneWithContents` 事务内：道内节点 → 每个节点 `listOutgoing` + `listIncoming` 的边 id 去重 → 软删边 → 软删节点 → 软删道；提交后失效节点与边控制器、等节点重载、再改泳道 state。
- 两个 restore：一个事务里 `styleLanes.restore` + 节点（解散：`update` 回旧坐标与 lane_id；删除：`nodes.restore` + `edges.restore`）；恢复后若与现存道 sort_order 撞号，在同一事务里按「复原的道回到旧下标」重排编号。方法入口先查 `_alive`（画布已关 ⇒ 空操作，同 CanvasNodesController.restore）。
- 动作层：解散 = 读 lanes / collapse / 方向 / scale → `dissolvedPositions` → `dissolveLane` → 若该道在 `laneCollapseProvider` 里则 `toggle` 去掉 → `showCanvasUndoSnack(message: l.laneDissolved(name), onUndo: restoreDissolved)`。删除和内容 = `activeJobsInLane` 非空 ⇒ AlertDialog 确认（取消 ⇒ 什么都不做）；确认 ⇒ 逐个 `jobQueueService.cancel(jobId)`（InkError 记日志后继续）→ `deleteLaneWithContents` → 选中集里去掉被删节点（`canvasSelectionControllerProvider.removed`）、被删的边若是选中边则清 → 撤销卡 `l.laneDeletedWithContents(count, name)`。失败 ⇒ `showCanvasSnack(laneDissolveFailed / laneDeleteFailed)`；撤销失败 ⇒ `undoFailed`。

## 行为规则与边界情况
1. 点标题栏解散键：不弹任何对话框；道从画布消失；原道内每张卡的屏幕矩形与解散前相同（±0.5px）；这些节点 `lane_id == null`（内存与库都是）。
2. 解散不动节点以外的东西：边、产物、其它道的节点 lane_id 不变；后面的道整体前移，它们的卡随道走。
3. 解散的是折叠中的道：按展开厚度换算位置，解散后从折叠集合里移除该 id；不报错。
4. 竖向泳道、缩放 0.5 / 2.0 时同样屏幕不动（主轴不变，只换算横截轴）。
5. 内存里没载到、但库里 lane_id 指向该道的节点也被清掉（事务里按库查）。
6. 解散后撤销卡 8 秒：点「撤销」⇒ 道回来（同名同风格、原下标），节点回到旧世界坐标和旧 lane_id，屏幕上回到原道里。撤销时某节点已被删 ⇒ 跳过它，其余照复原。
7. 删除泳道和内容：道、`lane_id == 该道` 的全部节点（含产物节点）、这些节点的全部入边与出边，在**一次** `uow.run` 里软删；道外节点之间的边不动。
8. 道内没有非终态任务 ⇒ 直接删 + 撤销卡「已删除泳道「水墨」和 4 个节点」；空道 ⇒「已删除泳道「水墨」」。
9. 道内有非终态任务（queued / submitting / running，按 sourceNodeId 或 resultNodeId 命中，且 canvasId 相同）⇒ 先弹确认框，写出任务数；点取消 ⇒ 道、节点、任务都不动；点确认 ⇒ 先取消这些任务、再删。终态任务、别的画布的任务不触发确认。
10. 删除后撤销 ⇒ 道、节点、边全部复原；被取消的任务不复原（确认框已写明）。
11. 失败：事务抛 InkError ⇒ 泳道 state 回到原样、节点 / 边不失效重载、出失败卡「解散泳道失败」/「删除泳道失败」；库里无半截（全在一个事务里）。
12. 并发：泳道控制器的写全部串行（SerialMutationQueue）；解散与同道的「改名 / 改风格」交错时按入队顺序执行，后到的改名落在已软删的道上返回 0 行、不抛。
13. 关画布后点撤销卡 ⇒ 控制器已 dispose，空操作、不抛（入口 `_alive` 守卫）。
14. 撤销栈：两项都**不**进 `canvasHistoryControllerProvider`（undo / redo 列表长度不变）；Ctrl Z 不会撤解散。之前栈里引用该道的步（如「移入泳道」）在撤销时由 undo-stack 判 gone，不在本片处理。本条只管本片：W6 undo-lanes 起解散 / 删除泳道进栈（主 Agent 跨批核对补充）。
15. 生成侧：解散后这些节点再生成，产物不再带悬空 lane_id（产物沿用 config 的 lane_id = null）。
16. mac / Windows 无差异；确认框按钮顺序沿用 AlertDialog 现有写法（取消在左、危险动作在右）。

## 新文案键
| key | en | zh |
|---|---|---|
| laneDissolve | Dissolve lane (keep nodes) | 解散泳道（节点留下） |
| laneDissolved | Lane “{name}” dissolved | 已解散泳道「{name}」 |
| laneDissolveFailed | Couldn't dissolve the lane | 解散泳道失败 |
| laneDeletedWithContents | `{count, plural, =0{Lane “{name}” deleted} =1{Lane “{name}” and 1 node deleted} other{Lane “{name}” and {count} nodes deleted}}` | `{count, plural, =0{已删除泳道「{name}」} other{已删除泳道「{name}」和 {count} 个节点}}` |
| laneDeleteRunningTitle | Delete lane “{name}” and its nodes? | 删除泳道「{name}」和其中的节点？ |
| laneDeleteRunningBody | `{count, plural, =1{1 job in this lane is still generating. Deleting cancels it, and a cancelled job can't be undone.} other{{count} jobs in this lane are still generating. Deleting cancels them, and cancelled jobs can't be undone.}}` | `{count} 个任务正在生成，删除会一并取消，取消的任务撤销不回来。` |
| laneDeleteRunningConfirm | Delete and cancel jobs | 删除并取消任务 |

placeholders：name String、count int。复用：`laneDeleteFailed`、`laneDialogCancel`、`undoFailed`、`commonUndo`、`laneUntitled`（道名为空时）。变成无引用、建议主 Agent 删除：`laneDelete`、`laneDeleteConfirmTitle`、`laneDeleteConfirmBody`。

## 测试
- `test/features/canvas/util/lane_dissolve_test.dart`（纯函数，先写）
  - 「横向两道 [a 400, b 300]、scale 1：b 里的卡解散后 crossToScreen 前后相等」。
  - 「scale 0.5 / 2.0 同样屏幕不动」；「竖向泳道只改 x」。
  - 「被解散的道折叠中：按展开厚度换算（结果 == 未折叠时的结果）」；「别的道折叠：用折叠厚度」。
  - 「activeJobsInLane：running / queued 命中；succeeded 不算；别的 canvasId 不算；resultNodeId 命中也算」。
- `test/features/canvas/canvas_lanes_controller_test.dart`（FakeUnitOfWork + InMemory 仓储；把 `deleteLane removes from state` 改写）
  - 「dissolveLane：道软删、道内节点 lane_id 清空并写入新坐标，道外节点不动」。
  - 「dissolveLane：库里有、内存没有的道内节点也被清 lane_id」。
  - 「dissolveLane：所有写在一次 uow.run 里」（计数 UoW：run 调用 1 次；顶层仓储 fake 无写入）。
  - 「dissolveLane 事务抛错：泳道 state 原样、节点控制器未失效」。
  - 「restoreDissolved：道回来、节点回旧坐标与旧 lane_id」；「已删节点被跳过」；「sort_order 撞号时复原的道回到旧下标」。
  - 「deleteLaneWithContents：道 + 道内节点 + 入 / 出边软删，边去重；道外两节点之间的边不动」；「一次 uow.run」。
  - 「restoreLaneContents：全部复原」；「未知 laneId ⇒ null、无写入」。
- `test/features/canvas/util/canvas_lane_actions_test.dart`（ProviderScope + 假 JobQueueService + RecordingToastService）
  - 「解散：无对话框，出撤销卡『Lane “Ink” dissolved』，历史栈 undo 为空」。
  - 「点卡上撤销 ⇒ restoreDissolved 被调、道回来」。
  - 「删除和内容、无活动任务：不弹框，直接删 + 卡『… and 2 nodes deleted』」。
  - 「有 running 任务：弹框；点取消 ⇒ 无写入、无 cancel」；「点确认 ⇒ cancel 被调用 N 次、然后删」。
  - 「删除后选中集去掉被删节点」。
- `test/features/canvas/widgets/lane_interactions_test.dart` 新用例「点标题栏解散键：无确认框，卡片 getRect 前后相等，repo 里 lane_id 为 null，tooltip 为 Dissolve lane (keep nodes)」。
- `test/features/canvas/widgets/lane_title_bar_test.dart`：tooltip / 参数名同步。

## 变异点
1. `dissolveLane` 不写 `lane_id: null` → 控制器「道内节点 lane_id 清空」、交互「repo 里 lane_id 为 null」红。
2. `dissolvedPositions` 返回原坐标（不调 laneMoveDelta）→ 纯函数「crossToScreen 前后相等」、交互「getRect 前后相等」红。
3. 被解散的道仍用折叠厚度 →「被解散的道折叠中」红。
4. 只按内存列表找道内节点 →「库里有、内存没有」红。
5. `deleteLaneWithContents` 只删出边 →「入 / 出边软删」红。
6. 把删边和删节点拆到两次 `uow.run` →「一次 uow.run」红。
7. `activeJobsInLane` 不排除终态 → 纯函数「succeeded 不算」红、动作「无活动任务不弹框」红。
8. 动作层总是弹确认 →「无活动任务：不弹框」红；从不弹 →「有 running 任务：弹框」红。
9. 解散时调了 `history.record` →「历史栈 undo 为空」红。
10. `restoreDissolved` 只恢复道不恢复节点 →「节点回旧坐标与旧 lane_id」红。
11. stage_lane_layer 仍走旧确认框 → 交互「无确认框」、stage_lane_layer_test「点解散键不弹框」红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas`；`transaction_integration_test` 不改也须绿；逐条变异。
- 截图：`CanvasView`（pumpInkShell，横向两道「水墨」「赛博」，水墨里 3 张卡，其中一张缩放 0.8）——①解散前；②点解散后（卡片原地、道消失、右下撤销卡）；③点撤销后；④对含 running 任务的道调用删除和内容时的确认框。

## 风险与不确定
- 偏离 contract：新增 `util/canvas_lane_actions.dart`（项目规则「新画布动作写进新文件」，同波无人占用）；`deleteLane` 被删除（零兼容，唯一调用点已改）；`LaneTitleBar.onDelete` 改名 `onDissolve`。
- 本片不碰 CanvasNodesController，靠「提交后失效 + 等重载」同步内存；若节点控制器此刻有在途的 moveNode 正把某卡写进这条道，可能在解散后又写回悬空 lane_id——概率很低，记入 W6 undo-lanes 复查（届时可改走 nodes-batch-ops 的 moveNodes 同事务）。
- 历史上已经悬空的 lane_id 行不做数据修复（无迁移）：显示上已等同道外节点，下次拖动会写成 null。
