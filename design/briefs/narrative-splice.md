# narrative-splice · 叙事链拼接底座（插入一镜 / 删除接上 / 挪位 / 换连线类型 / 批量删线，纯函数 + 单事务操作）
- 波次 W1 / lane B / 基底 origin/main（W0 全部合入后，须含 undo-stack 的 `models/edge_endpoints.dart`）；依赖切片：undo-stack（只用 EdgeEndpoints 令牌形状）；阻塞决定：无。合并了 narrative-splice-core（ContextMenus）与 narrative-splice-ops（GapsPanels）。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/<切片id>`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
这一片**没有界面**。落一套「改叙事边」的纯函数和事务操作，后续 cm-edge-menu（改语义 / 插入节点…）、cm-drag-insert-narrative（拖到线上插一镜）、cm-delete-bridge（删中间一镜前后接上）、outline-drag-reorder（大纲拖动改序）、cm-knife-cut、rail-drag-assets（替换首帧）全部共用，不各写一套。
每个操作一个 UnitOfWork 事务、失败内存整批回滚，并给出按两端找边的撤销令牌。

## 设计依据
ContextMenus.dc.html：
- 「连线：右键 + 中点工具条」：改成首 / 尾帧时目标原有的同角色线同一事务降为参考（复用 `_conflictingFrameRoles`）；数据 ↔ 叙事 = 换 edge_type：一个事务软删旧边 + 建新边（→ `changeEdgeType`）；插入节点… 只对叙事线，A → 新 → B 一次接好（→ `insertPlan` + `applySplice`）。
- 「拖到叙事线上 = 插一镜」：文本、便签、产物不可插（→ `canInsertType`）；一个事务软删 A→B、建 A→新（沿用原 sortOrder）和 新→B；放不下时 B 及链上其后的节点整体后移一格（→ `makeRoomShifts`）；插入 + 让位 + 换道算一步撤销（位移由调用方交给 moveNodes）。
- 「删链中间的镜 → 前后接上」：恰一条叙事入边、一条叙事出边才接，新边沿用入边 sortOrder；多选按「连续被删的一段」算；有分叉 / 汇合不接（→ `bridgePlan`）。
- 「停用 · 切线」：划过的线松手全部断开、一张撤销卡（→ `removeEdges`）。
GapsPanels.dc.html「大纲」：落下改的是叙事边——摘出、前后接上、插进新位置，一个事务；只有同一分叉下兄弟换序才改 sortOrder（→ `movePlan` / `siblingReorderPlan`）。
UndoClipboard.dc.html：反向找边一律按两端，不按边 id（→ `SpliceUndoToken` 用 `EdgeEndpoints`，由 undo-stack 新建）。
- 按建议：ContextMenus W1 → A（删中间一镜默认接上，W6 cm-delete-bridge 落地）；W4 → B（只有未入链的能插，已在链上的挪位只走大纲 movePlan）。
- 设计缺口：「后移一格」多大、竖向泳道的主轴没画——本单定为一格 = 卡片主轴尺寸（kNodeCardSize）+ `kSpliceSlotGap`(64)，主轴随 LaneDirection（horizontal = x、vertical = y），无泳道按 horizontal。
- 设计缺口：多选删除时部分段接上、部分段因分叉不接，卡片怎么写没画——本片只返回 `skippedSegments` 计数，文案归 cm-delete-bridge。
- 设计缺口：大纲「兄弟换序」的落点语义（落在两兄弟之间 = 换序，而不是插进链）没画——本片拆成两个函数，由 outline-drag-reorder 判用哪个。

## 允许改的文件
- `lib/features/canvas/util/narrative_splice.dart`（新，纯 Dart，只 import models 与 `util/lane_geometry.dart`、`util/create_menu_model.dart` 的 `nextNarrativeSortOrder`（只读引用，不改该文件））。
- `lib/features/canvas/providers/canvas_edges_controller.dart`：加 `applySplice` / `changeEdgeType` / `removeEdges` / `addEdgesInTx` / `replaceRoleEdge`；已有方法不动，`_conflictingFrameRoles` 原样复用。
- `test/features/canvas/util/narrative_splice_test.dart`（新）。
- `test/features/canvas/canvas_edges_controller_splice_test.dart`（新，与现有 `test/features/canvas/canvas_edges_controller_test.dart` 同级；fake 仓储照该文件 `_FakeEdgeRepo` 抄一份，另加「同两端在世边再 create 抛 db_code 23505」的唯一索引模拟）。
- 核对结论：`lib/features/canvas/models/canvas_edge.dart` 不需要改（EdgeEndpoints 在 undo-stack 的新文件里）。

## 不许碰的文件
- nodes-batch-ops：`lib/features/canvas/providers/canvas_nodes_controller.dart`、`lib/features/canvas/util/canvas_node_delete.dart`、`test/_harness/fake_canvas.dart`。
- canvas-capsule：`util/canvas_tool_actions.dart`、`widgets/shortcuts/core_canvas_keys.dart`、`canvas_screen.dart`、`canvas_zoom_bar.dart`、capsule 新文件。
- current-take：`util/create_menu_model.dart`（只许 import）、`util/node_artifacts.dart`、`util/outline_model.dart`、`command_palette/palette_search.dart`、`features/export/**`、`gallery/util/gallery_meta.dart`、`features/sequence/**`。
- app-action-table：`lib/features/app_actions/**`、`command_actions.dart`、`shortcut_catalog.dart`、`canvas_toolbar.dart`、`more_menu_model.dart`。
- `lib/features/canvas/models/edge_endpoints.dart`（undo-stack 的，只 import）、`util/narrative_order.dart`（只读参考，不改）。
- （主 Agent 自查补充）current-take：`lib/features/canvas/widgets/left_rail/outline_panel.dart`、`lib/core/constants/take_keys.dart`（新）；canvas-capsule：`lib/theme/components/ink_canvas_capsule.dart`（新）。

## 具体改动
```dart
// util/narrative_splice.dart
const double kSpliceSlotGap = 64;
typedef SpliceEdgeSpec = ({String sourceNodeId, String targetNodeId, EdgeType edgeType, EdgeRole role, int sortOrder});
@immutable class SplicePlan {               // 手写值对象
  const SplicePlan({this.removeEdgeIds = const <String>{}, this.addEdges = const <SpliceEdgeSpec>[], this.sortOrders = const <String, int>{}});
  final Set<String> removeEdgeIds; final List<SpliceEdgeSpec> addEdges; final Map<String, int> sortOrders; // edgeId → 新 sortOrder
  bool get isEmpty;
}
typedef BridgePlan = ({SplicePlan plan, int skippedSegments});
bool canInsertType(CanvasNode node);
SplicePlan? insertPlan({required CanvasEdge edge, required String newNodeId, required List<CanvasEdge> edges});
BridgePlan bridgePlan({required Set<String> deletedIds, required List<CanvasEdge> edges});
Map<String, Offset> makeRoomShifts({required CanvasEdge edge, required List<CanvasNode> nodes, required List<CanvasEdge> edges, required LaneDirection direction});
SplicePlan? movePlan({required String nodeId, required String afterId, required List<CanvasEdge> edges});
SplicePlan siblingReorderPlan({required String parentId, required List<String> orderedChildIds, required List<CanvasEdge> edges});
bool wouldCreateNarrativeCycle({required String sourceNodeId, required String targetNodeId, required List<CanvasEdge> edges});
@immutable class SpliceUndoToken {
  final List<({EdgeEndpoints key, int sortOrder})> removed; final List<EdgeEndpoints> added; final Map<EdgeEndpoints, int> previousSortOrders;
}
SplicePlan? invertSplice(SpliceUndoToken token, List<CanvasEdge> current);   // null = 一样都对不上（调用方判 gone）

// canvas_edges_controller.dart
typedef SpliceApplied = ({List<CanvasEdge> removed, List<CanvasEdge> added, SpliceUndoToken token});
Future<SpliceApplied> applySplice(SplicePlan plan);
Future<({CanvasEdge removed, CanvasEdge created, Set<String> demotedIds})?> changeEdgeType(String edgeId, {required EdgeType to, EdgeRole role = EdgeRole.reference});
Future<List<CanvasEdge>> removeEdges(Set<String> ids);
Future<List<CanvasEdge>> addEdgesInTx(List<SpliceEdgeSpec> specs);
Future<({List<CanvasEdge> removed, CanvasEdge created})> replaceRoleEdge({required String targetNodeId, required EdgeRole role, required String newSourceNodeId});
```
- 五个控制器方法：入口解析 `unitOfWorkProvider.future`；整体进 `serialize`；op 内读 `previous` → 乐观写内存 → 一个 `uow.run` → `on InkError` 回滚到 `previous` 并 rethrow；`_alive` 守卫照现有。
- 事务内顺序固定：先软删（腾出 uq_edges_live 槽位）→ 再改 sortOrder（`update(id, {sort_order})`）→ 最后 create。

## 行为规则与边界情况
1. 「叙事边」只认 `EdgeType.narrative` 且两端都在给定边集里出现的；data / generationSource 不参与任何链判断。
2. `canInsertType`：`role == config` 且 `type ∈ {image, video, shot}`；text（含便签变体）、任何 result 都 false。
3. `insertPlan(A→B, X)`：边非叙事、X 已有任何叙事边、X 是 A 或 B ⇒ null；否则 删 A→B，加 A→X（sortOrder = A→B 原值）和 X→B（sortOrder 0）。
4. `bridgePlan`：对每个「连续被删的一段」（被删节点经叙事边相连的极大串）：段内每个节点叙事入度 = 1 且出度 = 1（计入全部叙事边，含连向被删节点的）⇒ 接段前一镜 P → 段后一镜 S，sortOrder = P→段首 那条的值。任一节点入度或出度 ≥ 2 ⇒ 整段不接，`skippedSegments + 1`。段首入度 0 或段尾出度 0（删的是链头 / 链尾）⇒ 无事可接、不计 skipped。P→S 已有在世叙事边 ⇒ 不重复建、不计 skipped。P == S ⇒ 不接。
5. 分叉 / 汇合时 bridgePlan「不接」= 返回的 plan 不含该段的边、`skippedSegments > 0`。
6. `makeRoomShifts(A→B)`：主轴上 A 卡尾到 B 卡头的空隙 < 卡片主轴尺寸 + 2·gap ⇒ B 以及 B 的全部叙事后继（DFS、去重、遇到 A 停）各后移一格；空隙够 ⇒ 空 map。返回 节点 id → 位移，调用方交给 nodes-batch-ops 的 `moveNodes`（同一步撤销）。
7. `movePlan(X, after: A)`：X 入度或出度 ≥ 2 ⇒ null（与 bridge 同口径）；X == A ⇒ null；X 已是 A 的直接后继 ⇒ 空 plan（摘出后 X 无任何叙事边，再接 A→X→B 不会成环，不另判）。否则：摘出 X（删 X 的入 / 出叙事边，P→S 接上，sortOrder 沿用 P→X）；A 有恰一条叙事出边 A→B ⇒ 删 A→B、加 A→X（沿用 A→B 的 sortOrder）、X→B；A 无出边 ⇒ 加 A→X（`nextNarrativeSortOrder`）；A 有分叉 ⇒ 加 A→X 排在已有分支之后（`nextNarrativeSortOrder`），不拆分叉。
8. `siblingReorderPlan(P, [c…])`：只改 P 的叙事出边 sortOrder 为 0..n-1（按给定顺序），不删不加；列表里不是 P 直接后继的 id 忽略；顺序不变的边不写进 sortOrders。
9. `wouldCreateNarrativeCycle(s, t)`：沿叙事边从 t 能走到 s ⇒ true；s == t ⇒ true。
10. 所有 plan 构造函数保证：加的边不与「删后仍在世」的边两端 + 类型重复（uq_edges_live），加的边之间也不重复。
11. `applySplice`：空 plan ⇒ 不碰库、返回空 removed / added。任一步失败 ⇒ 库回滚、内存整批回到调用前、InkError 上抛。成功 ⇒ 返回被删边快照、新边（含新 id）与令牌：`removed` 记 (EdgeEndpoints, 原 sortOrder)，`added` 记新边两端，`previousSortOrders` 记被改序边的两端 → 原值。
12. `invertSplice`：对 `added` 按两端找在世边 → 进 removeEdgeIds（找不到跳过）；对 `removed` 两端此刻没有在世边 → 重新 create（新 id、原 sortOrder / role）；对 `previousSortOrders` 找到边就改回原值。三样都空 ⇒ null（对象都已不在 → 调用方返回 CanvasCommandOutcome.gone）。**全程不用边 id 匹配**。
13. `changeEdgeType`：边不在内存、`to` 与原类型相同、任一侧是 generationSource ⇒ null 且不碰库。data → narrative：role 置 reference、sortOrder = `nextNarrativeSortOrder(anchor: source)`。narrative → data：role 按参数；首 / 尾帧时同目标同角色的 data 入边在同一事务降为参考（`_conflictingFrameRoles`），返回 `demotedIds`。旧边软删 + 新边 create + 降级，同一事务。合法性（成环、节点类型、模型支持）由调用方判，本方法不判。
14. `removeEdges`：一个事务软删全部；不在内存的 id 仍软删但不进返回值；空集合不碰库。
15. `addEdgesInTx`：一个事务按序 create；任一失败整批回滚（含 23505）。
16. `replaceRoleEdge`：role 只能是 firstFrame / lastFrame（reference 时 `ArgumentError` 断言）；同一事务：软删目标上该角色的其他 data 入边；newSource→target 已有在世 data 边 ⇒ 改它的 role，否则 create；返回被删的边与生效的那条。
17. 并发：全部进本 controller 的 `serialize`，与 addEdge / updateRole / restore 先来先写；plan 在调用方用读到的边集算，`applySplice` 在 op 内**不重算**——若期间边集已变导致 23505，整批回滚并上抛，调用方出失败卡。
18. 与撤销栈：本片不登记步；只产令牌。W5 undo-edges 的命令用 `invertSplice` 撤、用原 plan 重算重做。
19. 画布关闭（dispose）中途：await 后不写 state，不抛 StateError。mac / Windows 无差异。

## 新文案键
无。

## 测试
`test/features/canvas/util/narrative_splice_test.dart`（纯函数，节点 / 边用字面量构造）：
- `canInsertType：image / video / shot 配置可插，text 与 result 不可插`。
- `insertPlan：删 A→B、加 A→X（沿用 sortOrder 5）与 X→B`；`insertPlan：X 已在链上 / 边是 data ⇒ null`。
- `bridgePlan：A→X→B 删 X ⇒ 接 A→B，sortOrder 取入边`；`连续两张 A→X→Y→B ⇒ 一条 A→B`；`两段不相连 ⇒ 各接各的`。
- `bridgePlan：X 两条叙事出边（分叉）⇒ 不接，skippedSegments = 1`；`X 两条叙事入边（汇合）⇒ 不接`；`段中间那张分叉 ⇒ 整段不接`。
- `bridgePlan：删链头 / 链尾 ⇒ 空 plan、skipped 0`；`A→B 已存在 ⇒ 不重复建`；`data 边不参与`。
- `makeRoomShifts：空隙够 ⇒ 空`；`横向放不下 ⇒ B 与其后整条链 x + 一格`；`竖向泳道沿 y 后移`；`链上有环 ⇒ 每个节点只移一次`。
- `movePlan：摘出后前后接上并插到 A 后`；`A 无出边 ⇒ 接在末尾`；`X 有分叉 ⇒ null`；`已是 A 的后继 ⇒ 空 plan`。
- `siblingReorderPlan：只改 sortOrder，不删不加`。
- `wouldCreateNarrativeCycle`：直连回头 true、无路径 false。
- `invertSplice：按两端找边——新边被删后同两端重建（id 变了）仍能撤掉`；`全部对不上 ⇒ null`；`被删的边此刻已有同两端在世边 ⇒ 不重复 create`。
`test/features/canvas/canvas_edges_controller_splice_test.dart`（ProviderContainer + FakeUnitOfWork + 本文件 fake 仓储）：
- `applySplice 一个事务：先删后改序再建；内存同步，返回令牌`（fake 记调用顺序）。
- `applySplice 删 A→B 再建 A→B（同两端）不撞唯一索引`（fake 对在世同两端 create 抛 23505）。
- `applySplice 第 2 个 create 失败 ⇒ 内存整批回到调用前、抛 InkError`。
- `changeEdgeType narrative → data(首帧) ⇒ 同目标原首帧降为参考，同一事务`；`data → narrative ⇒ sortOrder 排在源已有分支之后`；`同类型 / 不在内存 ⇒ null、不碰库`。
- `removeEdges 一次删多条；失败整批回滚`。
- `addEdgesInTx 失败整批回滚`。
- `replaceRoleEdge 旧首帧软删、新首帧建立；新源已有 data 边 ⇒ 只改 role`。

## 变异点
- `bridgePlan` 的「入度 == 1 && 出度 == 1」改成 `>= 1` → 「X 两条叙事出边（分叉）⇒ 不接」与「汇合」红。
- `bridgePlan` 新边 sortOrder 取段尾出边 → 「sortOrder 取入边」红（夹具里入 / 出 sortOrder 不同）。
- `insertPlan` 的 A→X sortOrder 写死 0 → 「沿用 sortOrder 5」红。
- `canInsertType` 去掉 text 排除 → 「text 与 result 不可插」红。
- `makeRoomShifts` 只移 B 不走后继 → 「B 与其后整条链」红；主轴写死 x → 「竖向泳道沿 y」红。
- `invertSplice` 改成按边 id 找 → 「新边…id 变了仍能撤掉」红。
- `applySplice` 事务内改成先 create 后删 → 「同两端不撞唯一索引」红。
- 删 `applySplice` catch 里的回滚 → 「第 2 个 create 失败 ⇒ 内存整批回到调用前」红。
- `changeEdgeType` 不调 `_conflictingFrameRoles` → 「原首帧降为参考」红。
- `movePlan` 去掉分叉判断 → 「X 有分叉 ⇒ null」红。

## 验收
主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas/util/narrative_splice_test.dart test/features/canvas/canvas_edges_controller_splice_test.dart test/features/canvas/canvas_edges_controller_test.dart`（已有用例不改仍绿），逐条变异。无 UI、无截图。docs/CLAUDE.md 的 util 列表补 narrative_splice.dart 一行由主 Agent 加。

## 风险与不确定
- plan 在队列外算、在队列内执行，期间别处改边会 23505；当前只靠整批回滚 + 调用方失败卡。若 W6 / W7 发现频繁，再给 `applySplice` 加「op 内按两端校验」。
- `nextNarrativeSortOrder` 住在 current-take 本波占用的 create_menu_model.dart：只 import 不改；若 current-take 挪了它，rebase 时跟着改 import。
- 竖向泳道的卡片主轴尺寸取 kNodeCardSize.height（191），与画面实际卡高一致；若后续卡片变高需同步。
