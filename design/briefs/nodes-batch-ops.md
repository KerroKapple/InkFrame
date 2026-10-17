# nodes-batch-ops · 节点批量写：moveNodes / removeNodes / restoreAll / patchTypeConfigMany / replaceTypeConfig，各一个事务
- 波次 W1 / lane A / 基底 origin/main（W0 五条 lane 全部合入后的 main）；依赖切片：无（不依赖 undo-stack 的代码）；阻塞决定：无。

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
多选删除不再「逐个删、中途失败删一半」：选 N 张按 Delete / 右键「删除」，要么一起删掉、出**一张**「已删除 N 个节点 · 撤销」卡，要么一张都不删、出「删除节点失败」。点卡上「撤销」一次事务把 N 张连同它们的线一起放回。
其余四个批量写（移动、补丁、整列替换）这一片只落控制器 API，没有新入口；后续 group-drag、align、undo-* 用。

## 设计依据
Selection.dc.html：
- 「整组拖动」需：moveNodes 整组一个事务，失败整组回滚 + 错误卡。
- 「多选检查器」需：typeConfig 批量 patch 一个事务（→ patchTypeConfigMany）。
- 「对齐 · 分布」：一次操作 = 一次 moveNodes。
UndoClipboard.dc.html「要补的底座」：多选删除并成一个 removeNodes 事务；改参数旧值不存在要能删键 → 板上写的 `removeTypeConfigKeys` 改为 `replaceTypeConfig`（整列覆盖，用现有 `NodeRepository.update`，不加抽象方法）。
- 设计缺口：整批删除失败时卡片文案没画——沿用 `nodeDeleteFailed`（单张失败同一句）。
- 设计缺口：删除失败后被取消的选中要不要恢复没画——维持现状（删前已从选中移除，失败不恢复）。

## 允许改的文件
- `lib/features/canvas/providers/canvas_nodes_controller.dart`：加 `NodeMove` typedef 与五个方法（签名见下）；`removeNode` / `restore` / `moveNode` 原样保留（单选路径与现有 26 处测试在用）。
- `lib/features/canvas/util/canvas_node_delete.dart`：`deleteNodesWithUndo` 多选分支改为一次 `removeNodes` + 一张卡；`_restore` 改为一次 `restoreAll`；单选 `deleteNodeWithUndo` 不动。
- `test/features/canvas/canvas_nodes_controller_test.dart`：新 group「批量写」；本文件里的 `_FakeNodeRepository` 加「第 n 次 softDelete / update / patchTypeConfig 抛错」开关、`restoreAffected`（restore 返回的行数，默认 1）与 `patchCalls` 记录。
- `test/storage/transaction_integration_test.dart`：加两条真 PG 用例（见测试）。
- `test/_harness/fake_canvas.dart`：`FakeNodesController` 补 `removeNodes` / `restoreAll` / `moveNodes` 覆盖（内存就地增删，与现有 removeNode / restore 同法）；`RecordingNodesController` 补 `moveNodes` 记录。
- `test/features/canvas/widgets/canvas_node_menu_test.dart`：只改本文件的 `_Nodes` fake（补 `removeNodes` 覆盖，记 `batchRemoved` 调用；补 `restoreAll` 覆盖，记调用次数——W3 undo-adopt-existing 不再碰这个文件，W3 只有 tc-set-current 改它）与「多选：整批删除」用例的断言。
- 核对结论：`test/_harness/fake_repositories.dart` 不需要改（控制器测试用本文件内的 fake；`FakeUnitOfWork` 不模拟回滚，DB 回滚由 PG 集成测覆盖）。

## 不许碰的文件
- `lib/features/canvas/util/canvas_tool_actions.dart`（W1 归 canvas-capsule；moveNodesToLane 改走 moveNodes 推到 W4 undo-node-create-move）。
- narrative-splice：`lib/features/canvas/providers/canvas_edges_controller.dart`、`lib/features/canvas/util/narrative_splice.dart`。
- canvas-capsule：`lib/features/canvas/widgets/shortcuts/core_canvas_keys.dart`、`canvas_screen.dart`、`canvas_zoom_bar.dart`、`lib/theme/components/ink_canvas_capsule.dart`、`providers/canvas_capsule.dart`、`widgets/canvas_capsule_host.dart`。
- current-take：`util/node_artifacts.dart`、`command_palette/palette_search.dart`、`util/create_menu_model.dart`、`util/outline_model.dart`、`features/export/**`、`gallery/util/gallery_meta.dart`、`features/sequence/**`、`models/canvas_node_take.dart`。
- app-action-table：`lib/features/app_actions/**`、`command_palette/command_actions.dart`、`settings/util/shortcut_catalog.dart`、`canvas_toolbar.dart`、`util/more_menu_model.dart`。
- `canvas_node.dart`（freezed，不改）；`canvas_snackbars.dart`（W3 归 undo-adopt-existing）。
- （主 Agent 自查补充）current-take：`lib/features/canvas/widgets/left_rail/outline_panel.dart`、`lib/core/constants/take_keys.dart`（新）。
- （主 Agent 跨批核对补充）current-take 另改：`lib/features/storyboard/util/sequence_builder.dart`、`lib/features/storyboard/models/sequence_shot.dart`、`lib/features/sequence/models/sequence_lens.dart`、`lib/features/gallery/util/gallery_meta.dart`、`lib/features/export/open_export_dialog.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/command_palette/palette_search.dart`。

## 具体改动
```dart
// canvas_nodes_controller.dart
typedef NodeMove = ({Offset delta, String? laneId});            // 与 moveNode(id, delta, laneId:) 同语义
Future<void> moveNodes(Map<String, NodeMove> moves);
Future<List<NodeDeletion>> removeNodes(Set<String> ids);
Future<int> restoreAll(List<NodeDeletion> deletions);           // 返回真正复原的节点行数（见规则 7）
Future<void> patchTypeConfigMany(Map<String, Map<String, Object?>> patches);
Future<void> replaceTypeConfig(String id, Map<String, Object?> full);
```
- 五个方法都：入口一次性解析 `unitOfWorkProvider.future` / 仓储（不在串行 op 里触 ref，ME-27）；整体包进一个 `serialize`；op 内读 `previous` 快照 → 乐观写内存 → 一个 `uow.run` 写库 → `on InkError` 回滚到 `previous` 并 rethrow；`_alive` 守卫照现有写法。
- `restoreAll` 照 `restore` 加方法入口守卫：`!_alive` ⇒ 直接返回 0。
- `removeNodes` / `restoreAll` 成功后 `ref.invalidate(canvasEdgesControllerProvider(canvasId))`（与 removeNode 同）。
- `replaceTypeConfig` 走 `update(id, {NodeCol.typeConfig: full})`（postgres 仓储已把 type_config 编成 `::jsonb` 整列覆盖），单语句不需要 UoW，但仍进 `serialize`。
- canvas_node_delete.dart 多选：`selectionCtrl.removed(id)` 逐个 → `await nodesCtrl.removeNodes(nodeIds)` → 成功且令牌非空 ⇒ `showCanvasUndoSnack(message: l.nodesDeleted(deletions.length), onUndo: () => _restoreAll(...))`；`InkError` ⇒ `showCanvasSnack(l.nodeDeleteFailed)`，不出撤销卡。

## 行为规则与边界情况
1. `moveNodes`：只处理此刻在内存里的 id，不在的跳过；新位置 = 当前位置 + delta，夹在 ±kWorldReach；laneId 为 null 即移出泳道（`clearLaneId`）。一个事务里逐个 `update(position_x, position_y, lane_id)`。空 map 或一个都不在 ⇒ 不碰库、直接返回。
2. `moveNodes` 任一行写失败 ⇒ 内存整批回到调用前，InkError 上抛。
3. `removeNodes`：一个事务里对每个 id 列出入 / 出边、软删边、软删节点；**同一条边只软删一次、只记进第一个碰到它的节点的令牌**（两张互连的卡）。返回顺序按 `ids` 的迭代顺序；不在内存里的 id 照现有 removeNode 口径仍软删、但不产令牌。空集合 ⇒ 返回空列表、不碰库。
4. `removeNodes` 第 k 步失败 ⇒ 库里整批回滚（真事务），内存整批放回，InkError 上抛；不出撤销卡，只出 `nodeDeleteFailed`。
5. 多选删除只调一次 `removeNodes`、只出一张卡；单选仍走 `removeNode` + 「Node deleted」卡（PL-4a 不回归）。
6. `restoreAll`：一个事务里复原全部节点 + 全部令牌里的边（边 id 去重）；内存里**已经在的节点不重复插入**。失败 ⇒ 内存回到调用前、上抛，卡片路径出 `undoFailed`。
7. `restoreAll` 返回 Σ `scope.nodes.restore` 的受影响行数；全部为 0（行已硬删）⇒ 调用方可判「对象已不在」（W3 的 DeleteNodesCommand 用它返回 gone）。
8. `patchTypeConfigMany`：内存按 `{...旧, ...patch}` 合并（值为 null 即写 JSON null，不删键——与 jsonb `||` 一致）；一个事务里逐个 `patchTypeConfig`；不在内存的 id 跳过；失败整批回滚。
9. `replaceTypeConfig`：整列覆盖，用于撤销时删掉原来没有的键；节点不在内存 ⇒ 什么也不做。失败回滚该节点的 typeConfig。
10. 并发：五个方法与已有的 add / remove / move 同一条 `serialize` 队列，先来先写；快照在 op 内读，不丢更新。
11. 画布关闭（provider dispose）中途：await 之后不写 state（`_alive`），不抛 StateError。
12. 与撤销栈：本片不登记任何步（undo-stack 的命令在 W3 才接）；只保证令牌（`List<NodeDeletion>`）足够一次复原。
13. mac / Windows：无差异。

## 新文案键
无（复用 `nodesDeleted`、`nodeDeleteFailed`、`undoFailed`、`commonUndo`）。

## 测试
`test/features/canvas/canvas_nodes_controller_test.dart`，group「批量写」（先写这些，跑红再实现）：
- `moveNodes 一个事务写全部位置 + lane_id，内存同步`：两张，各自 delta / laneId；`updateCalls` 两条，state 新位置。
- `moveNodes 越界落点 clamp 到 ±kWorldReach`。
- `moveNodes 第 2 行 update 失败 ⇒ 内存两张都回原位、抛 LocalIOError`。
- `moveNodes 不在内存的 id 跳过、空 map 不碰库`。
- `removeNodes 一次删三张 + 级联边，返回三个令牌`：顺序 = 入参顺序，edgeIds 各自正确。
- `removeNodes 两张互连：共享边只软删一次、只记进一个令牌`：`edgeRepo.softDeleted` 无重复。
- `removeNodes 第 3 张 softDelete 失败 ⇒ 内存三张都回来、抛 InkError`。
- `restoreAll 一次复原全部节点和边，state 里每张只出现一次`（先放一张已在内存的令牌）。
- `restoreAll 失败 ⇒ 内存回到调用前`；`restoreAll 在 dispose 后返回 0、不抛`。
- `restoreAll 返回受影响行数：行都没删过 ⇒ 0`（`restoreAffected = 0`）。
- `patchTypeConfigMany 合并进内存 + 逐个 patchTypeConfig；失败整批回滚`。
- `replaceTypeConfig 整列覆盖：update 收到的 type_config 不含被删的键`。
`test/storage/transaction_integration_test.dart`（`@Tags(['pg'])`，无 TEST_PG_URL 跳过）：
- `节点批量删除：第 3 张 softDelete 失败 ⇒ 三张节点与相连边一行没删`：建 project / canvas / 三节点 / 两条边；`PostgresUnitOfWork(h.conn, (s) => _FailNthNodeSoftDelete(postgresRepositoryScope(s), 3))`（测试内装饰器，nodes 第 3 次 softDelete 抛 `LocalIOError`，其余委托）；在 ProviderContainer 里用这些覆盖跑 `removeNodes`，`expectLater(throwsA(isA<LocalIOError>()))`；裸 SQL 查 `deleted_at IS NULL` 的节点仍是 3、边仍是 2。
- `节点批量删除：全部成功 ⇒ 三张节点与相连边 deleted_at 都有值`。
`test/features/canvas/widgets/canvas_node_menu_test.dart`：
- 改「多选：整批删除，一张批量撤销卡」：断言 `batchRemoved` 恰一次且 = {'img','vid'}，`removed`（单删记录）为空，卡标题 `2 nodes deleted`。
- 新增 `多选删除失败 ⇒ 一张不删、只出 Failed to delete node、没有撤销卡`（fake 的 removeNodes 抛 LocalIOError）。
- 新增 `多选删除后点撤销 ⇒ restoreAll 恰一次、两张都回来`。

## 变异点
- 把 `removeNodes` 的单个 `uow.run` 改成循环里每张各开一个 `uow.run` → PG 用例「第 3 张 softDelete 失败 ⇒ … 一行没删」红（前两张已提交）。
- 删掉 `removeNodes` catch 里的 `state = AsyncData(previous)` → 「removeNodes 第 3 张 softDelete 失败 ⇒ 内存三张都回来」红。
- 去掉 `removeNodes` 的边去重集合 → 「共享边只软删一次」红。
- 把 canvas_node_delete.dart 多选分支改回逐个 `removeNode` → canvas_node_menu_test「多选：整批删除」红（batchRemoved 为空）。
- 删掉 `restoreAll` 里「已在内存不重复插入」的判断 → 「restoreAll …每张只出现一次」红。
- 把 `restoreAll` 返回值改成 `deletions.length` → 「restoreAll 返回受影响行数」红。
- 把 `moveNodes` 的 clamp 删掉 → 「越界落点 clamp」红。
- 把 `patchTypeConfigMany` catch 里的回滚删掉 → 「…失败整批回滚」红。
- 把 `replaceTypeConfig` 改成调 `patchTypeConfig` → 「replaceTypeConfig 整列覆盖」红（update 未被调）。

## 验收
主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas test/storage/transaction_integration_test.dart`（有 TEST_PG_URL 时 PG 用例真跑），逐条变异。UI 只多了「一张卡」：不截图，靠 canvas_node_menu_test 断言卡数与标题。docs/CLAUDE.md 的 canvas_nodes_controller 说明行补「批量写各一个事务」由主 Agent 加。

## 风险与不确定
- `restoreAll` 复原的边若在删后被同两端重连过一条新的，`uq_edges_live` 会让整个复原事务 23505 失败 → 卡片出 `undoFailed`（现状 restore 同样如此）；W3 的命令再按 EdgeEndpoints 预检，本片不处理。
- 同波 canvas-capsule 也可能改 canvas_node_menu_test（适应视图相关用例）：本片只动 `_Nodes` fake 与删除 group，冲突由主 Agent 合并。
- W2 media-import-service 会接着改 canvas_nodes_controller.dart（放宽断言）：本片新方法放在文件末尾、不重排已有方法，减少 rebase 冲突。
