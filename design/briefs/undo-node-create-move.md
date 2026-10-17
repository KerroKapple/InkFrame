# undo-node-create-move · 新建 / 复制一份 / 移动 / 加入·移出泳道进栈（含新建菜单里建好并连线算一步）
- 波次 W4 / lane A / 基底 origin/main〔W0–W3 已合入〕
- 依赖切片：undo-stack（W0）、undo-shortcuts-ui（W2）、canvas-capsule（W1）、nodes-batch-ops（W1）、undo-adopt-existing（W3）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

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
- lib/features/canvas/models/commands/node_create_move_command.dart（新建，`part of '../canvas_command.dart';`）：CreateNodesCommand（+ 若 W3 未定义则 MoveNodesCommand，见下）。
- lib/features/canvas/models/canvas_command.dart（由 undo-stack 新建）：只追加一行 `part 'commands/node_create_move_command.dart';` + 一个枚举值 `CanvasCommandLabel.createNodes`；若 label → 文案的 switch 也在本文件里，追加对应 case（算在这一行配额内，主 Agent rebase 合并）。
- lib/features/canvas/util/canvas_tool_actions.dart：
  - addNodeFromMenu（main 第 343–422 行）：节点 + 线都成功后 push 一条 CreateNodesCommand；回滚路径（第 397–407 行 removeNode）不 push。
  - duplicateNodes（第 440–496 行）：created 非空就 push 一条（部分失败也只记成功复制出来的那几张）。
  - moveNodesToLane（第 554–603 行；W1 nodes-batch-ops 已改成一个 moveNodes 事务）：成功后 push MoveNodesCommand，记下每张的原位置 / 原 laneId 和新位置 / 新 laneId；失败不 push。
  - addNodeAtViewportCenter（第 110–132 行）不用改：它走 addNodeFromMenu。
- lib/features/canvas/widgets/node_card_slot.dart（由 canvas-view-split 新建；main 上是 canvas_view.dart 第 1283 行 _NodeCardSlot、第 1348–1412 行 _commitDrag）：W3 已把「换道」那一支改成进栈的 MoveNodesCommand + 卡；本片把**不换道的普通拖动**也进栈（不弹卡）。drop.delta == Offset.zero 不进栈。
- lib/features/canvas/widgets/shot_config_inspector.dart：_generateFromNotes（main 第 138–183 行）建节点 + 叙事边：两步都成功 push 一条 kind=linked；连线失败（第 170 行那支，节点留着）push 一条 kind=single。
- lib/features/canvas/util/canvas_history_actions.dart（由 undo-shortcuts-ui 新建；W4 无人占用）：在出「已撤销 · X」胶囊的那一处加一个分支：撤掉的是 CreateNodesCommand 且 `leftRunningJobs` 为真 → 胶囊文案追加「 · 任务仍在运行」。只加这一个分支。
- test/features/canvas/util/canvas_tool_actions_undo_test.dart（新建）、test/features/canvas/widgets/canvas_lane_drag_test.dart、test/features/canvas/widgets/shot_config_inspector_sb4_test.dart。

## 不许碰的文件
- 同波：generation/providers/batch_results_controller.dart、batch_results_grid.dart、batch_slot_parts.dart、batch_compare_overlay.dart、util/batch_slot_view.dart、current_take_controller.dart（tc-batch-slot-set-current）；canvas_view.dart 骨架、node_card.dart、util/drop_placement.dart、models/canvas_drag_payload.dart、providers/canvas_drop_hover.dart（stage-drop-target）；ink_window_chrome / ink_menu_bar / shell_*（win-menubar）；storage/schema、migrations、columns.dart（export-records-table）。
- canvas_nodes_controller.dart（W1 nodes-batch-ops 的 removeNodes / restoreAll / moveNodes 直接用，不改）；canvas_edges_controller.dart（W5 undo-edges）；canvas_snackbars.dart（W3 已改好）；node_active_job.dart 只读。

## 具体改动
```dart
// models/commands/node_create_move_command.dart  (part of '../canvas_command.dart')
enum NodeCreateKind { single, linked, duplicate }

final class CreateNodesCommand extends CanvasCommand {
  CreateNodesCommand({
    required String canvasId,
    required NodeCreateKind kind,
    required List<String> nodeIds,       // 已建好的节点 id（push 时这一步已生效）
    CanvasNodeType? nodeType,            // single / linked 时给步名用
  });
  // label = CanvasCommandLabel.createNodes；affectedNodeIds = nodeIds
  bool get leftRunningJobs;              // 最近一次 revert 时有没有在途任务（给胶囊）
  @override Future<void> revert(...);   // 签名以 undo-stack 为准
  @override Future<void> apply(...);
}
```
- revert：先查 `nodeActiveJobProvider(id)`（node_active_job.dart:11，非 null = 在途）记进 leftRunningJobs；再取 nodes 控制器内存里**还活着**的 nodeIds，一个都不剩 → 按 undo-stack 约定的「对象已消失」信号返回（丢步）；否则 `CanvasNodesController.removeNodes(alive)`（W1，一个事务、级联软删边）→ 保存返回的 `List<NodeDeletion>`。不取消任务、不碰 jobsRegistry。
- apply（重做）：`restoreAll(_deletions)`（W1，一个事务；同 id 回来，连带新建菜单那条线也按原 id 回来——这是我们自己软删的行，不存在被系统改写的问题，所以这里按 id 复原合规）。没有 _deletions（从没撤过）时 apply 什么也不做。
- MoveNodesCommand：**W3 undo-adopt-existing 若已定义就复用**（conventions 约定先合的定义），不另起名字。
  - W3 没定义 ⇒ 本片在 node_create_move_command.dart 里定义 `final class MoveNodesCommand`，形状 `Map<String, ({Offset position, String? laneId})> before / after`，可装多张卡（W5 group-drag 要用）。
  - W3 定义了但只装单张 ⇒ 不在本片另起一个类，停下在回报里提给主 Agent（那个文件不归本片）。
  - revert = 按「此刻位置」算位移回到 before（同 _commitDrag 现有 undo 的算法，canvas_view.dart:1379–1394），apply = 回到 after；全部节点都不在 → 丢步，部分不在 → 只挪还在的。
- 步名（label 文案）：single →「新建 {type}」；linked →「新建 {type}并连线」；duplicate →「复制一份 · {count} 个节点」。{type} 用现有 canvasCreateMenuImageConfig / canvasCreateMenuVideoConfig / canvasNodeTextType / canvasNodeShotType。

## 行为规则与边界情况
1. 任一入口建节点成功（含连线成功）⇒ 栈深 +1，栈顶是 CreateNodesCommand，affectedNodeIds = [新 id]；重做栈清空（undo-stack 的 push 语义）。
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
（前缀与 cm-edge-menu 的 canvasCommandInsertNodeOnEdge 对齐；若 undo-shortcuts-ui 已定了别的前缀，按它统一改名。）

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
1. addNodeFromMenu 删掉 push ⇒「addNodeFromMenu 成功进栈一步」红。
2. CreateNodesCommand.apply 改成 addNode 重建（换 id）⇒「撤销新建 = 软删，重做 = 同 id 复原」红。
3. 回滚路径也 push ⇒「连线失败回滚不进栈」红。
4. duplicateNodes 每张各 push 一次 ⇒「复制一份 3 张算一步」红（栈深 3）。
5. MoveNodesCommand.revert 用 after.laneId ⇒「移入泳道撤销回原位原道」红。
6. node_card_slot 只在 drop.changed 时 push ⇒「普通拖动也进栈、不弹卡」红。
7. revert 里去掉 nodeActiveJobProvider 检查（leftRunningJobs 恒 false）⇒「撤销新建时任务在途」红；revert 里加 jobs cancel ⇒ 同一条红（jobs 里那条被取消）。
8. revert 不判活着的 id 直接 removeNodes ⇒「对象已消失丢步」红。

## 验收
- flutter analyze lib test；flutter test test/features/canvas --exclude-tags golden；逐条做上面变异。
- 截图：CanvasScreen + InMemory 仓储，种 1 个 image config 节点并给它一条在途 JobState；按 G 建一个视频配置 → Ctrl Z → 截胶囊「已撤销 · 新建 视频配置 · 任务仍在运行」（这里任务挂在被撤节点上）；再截空白处右键「重做 新建 视频配置」。

## 风险与不确定
- CanvasCommand 的 apply / revert 签名、「对象已消失」信号、label→文案 映射写在哪，都以 undo-stack 实际代码为准；若映射 switch 在 canvas_command.dart 里，本片追加的 case 超出「一行」配额，请主 Agent rebase 时统一合。
- MoveNodesCommand 的归属：W3 若只做单张，需要主 Agent 决定是 W3 补丁还是本片接管 W3 的命令文件（回报已提）。
- canvas_history_actions.dart（W2 新建）不在本波归属表里，本片只加一个胶囊文案分支；已在回报里提出。
- shot_config_inspector 本片只动 _generateFromNotes；W5 undo-params 会改同文件的 _save / _onChanged，串行无冲突。
