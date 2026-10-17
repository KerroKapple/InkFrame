# undo-node-create-move · 新建 / 复制一份 / 移动 / 加入·移出泳道进栈（含新建菜单里建好并连线算一步）
- 波次 W4 / lane A / 基底 origin/main〔W0–W3 已合入〕
- 依赖切片：undo-stack（W0）、undo-shortcuts-ui（W2）、canvas-capsule（W1）、nodes-batch-ops（W1）、undo-adopt-existing（W3）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 画布上新建一个节点（工具条 / I G T / Tab / 双击 / 右键「新建…」/ 拖线松手建好并连线 / ⌘K / 空画布 CTA / 镜头检查器「生成图像 / 生成视频」）之后，Ctrl Z 能把它撤掉，Ctrl Y 再原样回来（同一个 id）。
- 「复制一份」（Ctrl D / 右键）一次复制出的 N 张算一步。
- 拖动卡片松手（不论换没换道）、右键「加入泳道 › / 移出泳道」都进栈，撤销回到原位置、原泳道。
- 撤销「新建」时这个节点正在生成：照删，任务不取消，胶囊补一句「任务仍在运行」。

## 设计依据
- 画板 UndoClipboard.dc.html（生成脚本 /home/user/plan/design/b2_history.js）
  - 「什么进栈 · 一次用户编辑 = 一步；系统和任务做的不算」表：
    - 新建节点（含新建菜单里建好并连线）→ 菜单名「新建 视频配置并连线」
    - 拖动松手，多选一起算一步 →「移动 3 个节点」
    - 加入 / 移出泳道 →「移入泳道「水墨」」
    - 粘贴 / 剪切 / 复制一份 …→（复制一份属本片，粘贴 / 剪切属 clipboard-paste）
  - 不进栈：选中、视口与缩放、任务建的产物节点（job 落成的 result 节点不进栈）。
  - 规则：撤销失败整步回滚、留在栈顶；要撤的对象已不在就丢掉这一步，提示「这一步已无法撤销」（undo-stack 已实现，本片只给对象已消失的信号）。
  - 「撤销后选中受影响的节点，不在视口里就平移过去」由 undo-shortcuts-ui 的 canvas_history_actions 做，本片只填好 affectedNodeIds。
- 按 UndoClipboard-Q2 建议 A：撤销「新建」时节点在生成 → 照删，任务跑完产物落成未入链结果；胶囊补一句「任务仍在运行」。花钱的任务不被 Ctrl Z 默默取消。
- slices.json notes：撤销新建 = 软删，重做 = restore，不用硬删也不用换 id。
- 设计缺口：画板没画「撤销新建 · 任务仍在运行」胶囊的确切文案排布；按「已撤销 · 新建 视频配置 · 任务仍在运行」写（胶囊原有「已撤销 · <步名>」格式后接一段）。

## 允许改的文件
- lib/features/canvas/models/commands/create_nodes_command.dart（新建，独立文件，不是 part）：CreateNodesCommand。MoveNodesCommand **不新建**：直接用 W3 undo-adopt-existing 已建的 `models/commands/move_nodes_command.dart`（`MoveNodesCommand({required Map<String, NodePlacement> before, required Map<String, NodePlacement> after, required MoveNodesLabel label})`，已支持多张卡，`MoveNodesLabelKind { move, intoLane, outOfLane }`），本片不改该文件。
- （不改 canvas_command.dart：undo-stack 的契约里命令各自成文件，没有 part / label 枚举。）
- lib/features/canvas/util/canvas_tool_actions.dart：
  - addNodeFromMenu（main 第 343–422 行）：节点 + 线都成功后 record 一条 CreateNodesCommand；回滚路径（第 397–407 行 removeNode）不 record。
  - duplicateNodes（第 440–496 行）：created 非空就 record 一条（部分失败也只记成功复制出来的那几张）。
  - moveNodesToLane（第 554–603 行）：**W1 nodes-batch-ops 没碰这个函数**（它的不许碰清单里写明「moveNodesToLane 改走 moveNodes 推到 W4」），本片先把逐张 moveNode 改成一次 `CanvasNodesController.moveNodes(Map<String, NodeMove>)`（`NodeMove = ({Offset delta, String? laneId})`），成功后 record `MoveNodesCommand(before:, after:, label: (kind: intoLane / outOfLane, laneName: 目标道名或原道名))`，记下每张的原位置 / 原 laneId 和新位置 / 新 laneId；失败不 record。
  - addNodeAtViewportCenter（第 110–132 行）不用改：它走 addNodeFromMenu。
- lib/features/canvas/widgets/stage/node_card_slot.dart（由 canvas-view-split 新建在 `widgets/stage/` 下；main 上是 canvas_view.dart 第 1283 行 _NodeCardSlot、第 1348–1412 行 _commitDrag）：W3 已把「换道」那一支改成 record MoveNodesCommand + `showCanvasUndoSnackWith`；本片把**不换道的普通拖动**也 record（label kind = move，不弹卡）。drop.delta == Offset.zero 不进栈。
- lib/features/canvas/widgets/shot_config_inspector.dart：_generateFromNotes（main 第 138–183 行）建节点 + 叙事边：两步都成功 record 一条 kind=linked；连线失败（第 170 行那支，节点留着）record 一条 kind=single。
- lib/features/canvas/util/canvas_history_actions.dart（由 undo-shortcuts-ui 新建；W4 无人占用）：在出「已撤销 · X」胶囊的那一处加一个分支：撤掉的是 CreateNodesCommand 且 `leftRunningJobs` 为真 → 胶囊文案追加「 · 任务仍在运行」。只加这一个分支。
- test/features/canvas/util/canvas_tool_actions_undo_test.dart（新建）、test/features/canvas/widgets/canvas_lane_drag_test.dart、test/features/canvas/widgets/shot_config_inspector_sb4_test.dart。

## 不许碰的文件
- 同波：generation/providers/batch_results_controller.dart、batch_results_grid.dart、batch_slot_parts.dart、batch_compare_overlay.dart、util/batch_slot_view.dart、inspector_history_panel.dart、providers/current_take_controller.dart、models/commands/set_current_take_command.dart、models/commands/set_current_slot_command.dart（tc-batch-slot-set-current）；canvas_view.dart 骨架、node_card.dart、widgets/stage/stage_lane_layer.dart、util/drop_placement.dart、models/canvas_drag_payload.dart、providers/canvas_drop_hover.dart、widgets/stage_drop/*、theme/primitives/ink_dashed_outline.dart（stage-drop-target）；ink_window_chrome / ink_menu_bar / ink_menu_panel.dart / shell_*、features/shell/providers/*（win-menubar）；storage/schema、migrations、columns.dart、core/di/repositories.dart（export-records-table）。
- canvas_nodes_controller.dart（W1 nodes-batch-ops 的 removeNodes / restoreAll / moveNodes 直接用，不改）；canvas_edges_controller.dart（W5 undo-edges）；canvas_snackbars.dart（W3 已改好）；models/commands/move_nodes_command.dart（W3 的，只用）；node_active_job.dart 只读。

## 具体改动
```dart
// models/commands/create_nodes_command.dart（独立文件）
enum NodeCreateKind { single, linked, duplicate }

class CreateNodesCommand extends CanvasCommand {
  CreateNodesCommand({
    required NodeCreateKind kind,
    required List<String> nodeIds,       // 已建好的节点 id（record 时这一步已生效）
    CanvasNodeType? nodeType,            // single / linked 时给步名用
  });                                    // 非 const：撤销后要存 NodeDeletion 令牌
  @override String label(AppLocalizations l);           // 见「步名」
  @override Set<String> get affectedNodeIds;            // = nodeIds
  bool get leftRunningJobs;              // 最近一次 revert 时有没有在途任务（给胶囊）
  @override Future<CanvasCommandOutcome> revert(CanvasCommandEnv env);  // env.canvasId / env.ref
  @override Future<CanvasCommandOutcome> apply(CanvasCommandEnv env);
}
```
- revert：先查 `env.ref.read(nodeActiveJobProvider(id))`（node_active_job.dart:11，非 null = 在途）记进 leftRunningJobs；再取 nodes 控制器内存里**还活着**的 nodeIds，一个都不剩 → 返回 `CanvasCommandOutcome.gone`（undo-stack 丢步并出「这一步已无法撤销」）；否则 `CanvasNodesController.removeNodes(alive)`（W1，一个事务、级联软删边；W6 起它多一个 `bridge` 参数、默认 false，这里不传）→ 保存返回的 `List<NodeDeletion>` → `done`。InkError 不吞（undo-stack 把它当 failed）。不取消任务、不碰 jobsRegistry。
- apply（重做）：`restoreAll(_deletions)`（W1，一个事务；返回复原行数，0 ⇒ `gone`；同 id 回来，连带新建菜单那条线也按原 id 回来——这是我们自己软删的行，不存在被系统改写的问题，所以这里按 id 复原合规）。没有 _deletions（从没撤过）时 apply 返回 `done` 什么也不做。
- MoveNodesCommand：用 W3 的（见「允许改的文件」）。revert 已是「按此刻位置算位移回到 before、一次 moveNodes、全部不在 ⇒ gone」，本片只负责构造：普通拖动 `label: (kind: MoveNodesLabelKind.move, laneName: null)`（步名 W3 的 `canvasCommandMoveNodes(count)`）；加入 / 移出泳道用 intoLane / outOfLane。
  - 位置类型：W3 的 MoveNodesCommand 直接复用 `util/drop_placement.dart` 的 `NodePlacement = ({Offset world, String? laneId})`（世界坐标字段名是 `world`），before / after 写成 `{id: (world: 位置, laneId: 道)}`。
- 步名（`label(l)`）：single → `l.canvasCommandCreateNode(type)`「新建 {type}」；linked → `l.canvasCommandCreateNodeLinked(type)`「新建 {type}并连线」；duplicate → `l.canvasCommandDuplicateNodes(count)`「复制一份 · {count} 个节点」。{type} 用现有 canvasCreateMenuImageConfig / canvasCreateMenuVideoConfig / canvasNodeTextType / canvasNodeShotType。

## 行为规则与边界情况
1. 任一入口建节点成功（含连线成功）⇒ 栈深 +1，栈顶是 CreateNodesCommand，affectedNodeIds = [新 id]；重做栈清空（undo-stack 的 record 语义）。
2. 建节点失败 / 连线失败回滚（addNodeFromMenu 第 397 行那支）⇒ 栈不变。
3. 镜头检查器连线失败、节点留下 ⇒ 进栈一步 kind=single（撤销时把孤零零的节点删掉）。
4. 撤销新建 ⇒ 节点和它的线软删（deleted_at 非空），从画布消失；重做 ⇒ 同一个 id 回来，线也回来；连做两次 undo/redo 仍同 id。
5. 撤销新建时节点有在途任务 ⇒ 照删、任务继续跑；胶囊文案带「任务仍在运行」；任务跑完 result 节点落成未入链结果（generation 原有路径，不改）。
6. 撤销新建前用户已手动删掉这个节点（那一步也在栈里、但被卡片 undoSpecific 抽走等情况）⇒ 对象已消失 ⇒ 丢步、提示「这一步已无法撤销」，不连带撤下一步。
7. 复制一份 3 张 ⇒ 一步；撤销 3 张一起没；部分写失败只记成功的那几张。
8. 普通拖动（不换道）⇒ 进栈一步、不弹卡；拖动位移为 0 ⇒ 不进栈。换道 ⇒ W3 的行为不变（进栈 + 卡）。
9. 右键「加入泳道 ›」/「移出泳道」⇒ 一步；撤销回到原位置（按此刻位置算位移，期间被别处挪过也回得去）和原 laneId（含 null）。已在目标道里的卡不参与（laneMoveCandidates 判据不变）。
10. moveNodes 写失败 ⇒ 不进栈，原有「节点移动失败」卡照旧。
11. revert 写库失败 ⇒ 由 undo-stack 统一处理（留栈顶 + undoFailed）；命令内部不吞 InkError。
12. mac / Windows 无差异（键位归 undo-shortcuts-ui）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasCommandCreateNode | Create {type} | 新建 {type} |
| canvasCommandCreateNodeLinked | Create {type} and link | 新建 {type}并连线 |
| canvasCommandDuplicateNodes | Duplicate · {count} nodes | 复制一份 · {count} 个节点 |
| canvasCommandJobStillRunning | Task still running | 任务仍在运行 |
（前缀 `canvasCommand` 跟 W3 undo-adopt-existing 的 canvasCommandDeleteNodes / canvasCommandMoveNodes 统一；移动 / 移入 / 移出泳道的步名复用 W3 的 canvasCommandMoveNodes / canvasCommandMoveIntoLane / canvasCommandMoveOutOfLane，不新加。）

## 测试
test/features/canvas/util/canvas_tool_actions_undo_test.dart（新建；用 _harness/fake_repositories.dart 的 InMemoryNodeRepository / InMemoryEdgeRepository / InMemoryStyleLaneRepository + fake_unit_of_work.dart 的 FakeUnitOfWork + 真的 CanvasNodesController / CanvasEdgesController / CanvasHistoryController；pumpInkApp 挂一个 Consumer 拿 BuildContext + WidgetRef 调动作）
- 「addNodeFromMenu 成功进栈一步」：栈深 1，栈顶 is CreateNodesCommand，affectedNodeIds == [新 id]。
- 「撤销新建 = 软删，重做 = 同 id 复原」：undo 后 repo 行 deleted_at 非空、nodes state 不含；redo 后 state 含同一 id。
- 「新建并连线一步撤两样」：带 CreateMenuEdge；undo 后节点和边都不在；redo 后边按原 id 回来。
- 「连线失败回滚不进栈」：InMemoryEdgeRepository 让 create 抛 InkError；栈深 0。
- 「复制一份 3 张算一步」：duplicateNodes 3 个 config 节点；栈深 1；undo 后 3 张全没。
- 「移入泳道撤销回原位原道」：moveNodesToLane(laneId: L)；undo 后 position == 原值、laneId == null。
- 「撤销新建时任务在途：照删 + 胶囊带任务仍在运行」：override jobsRegistryProvider 放一条该节点的非终态 JobState；undo 后节点不在、jobs 里那条仍在（未取消）、canvasCapsuleProvider 文案含「任务仍在运行」。
- 「对象已消失丢步」：新建 → 直接 removeNodes 删掉 → undo：栈深变 0，提示「这一步已无法撤销」（按 undo-stack 契约断言）。
test/features/canvas/widgets/canvas_lane_drag_test.dart（追加）
- 「普通拖动也进栈、不弹卡」：拖 60px 不跨道；RecordingToastService 无 undo 卡；栈深 1；undo 后 position 回原值。
- 「位移为 0 不进栈」。
test/features/canvas/widgets/shot_config_inspector_sb4_test.dart（追加）
- 「生成视频 = 一步」：点按钮后栈深 1；undo 后新 video 节点与 shot→video 叙事边都不在。

## 变异点
1. addNodeFromMenu 删掉 record ⇒「addNodeFromMenu 成功进栈一步」红。
2. CreateNodesCommand.apply 改成 addNode 重建（换 id）⇒「撤销新建 = 软删，重做 = 同 id 复原」红。
3. 回滚路径也 record ⇒「连线失败回滚不进栈」红。
4. duplicateNodes 每张各 record 一次 ⇒「复制一份 3 张算一步」红（栈深 3）。
5. MoveNodesCommand.revert 用 after.laneId ⇒「移入泳道撤销回原位原道」红。
6. node_card_slot 只在 drop.changed 时 record ⇒「普通拖动也进栈、不弹卡」红。
7. revert 里去掉 nodeActiveJobProvider 检查（leftRunningJobs 恒 false）⇒「撤销新建时任务在途」红；revert 里加 jobs cancel ⇒ 同一条红（jobs 里那条被取消）。
8. revert 不判活着的 id 直接 removeNodes ⇒「对象已消失丢步」红。

## 验收
- flutter analyze lib test；flutter test test/features/canvas --exclude-tags golden；逐条做上面变异。
- 截图：CanvasScreen + InMemory 仓储，种 1 个 image config 节点并给它一条在途 JobState；按 G 建一个视频配置 → Ctrl Z → 截胶囊「已撤销 · 新建 视频配置 · 任务仍在运行」（这里任务挂在被撤节点上）；再截空白处右键「重做 新建 视频配置」。

## 风险与不确定
- （复核已定）CanvasCommand 契约 = undo-stack 派工单：`label(AppLocalizations)` 方法、`revert/apply(CanvasCommandEnv) → CanvasCommandOutcome`、`record` 不执行命令；MoveNodesCommand 用 W3 的多卡版本。
- moveNodesToLane 的「逐张 → 一次 moveNodes」改写归本片（W1 没做），canvas_lane_drag_test / canvas_node_menu_test 里记 moveNode 的 fake 要补 moveNodes。
- canvas_history_actions.dart（W2 新建）不在本波归属表里，本片只加一个胶囊文案分支；已在回报里提出。
- shot_config_inspector 本片只动 _generateFromNotes；W5 undo-params 会改同文件的 _save / _onChanged，串行无冲突。
