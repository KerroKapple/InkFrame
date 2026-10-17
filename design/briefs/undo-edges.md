# undo-edges · 连线 / 删线 / 改语义进栈；改首帧·尾帧连带降级的那条一起回
- 波次 W5 / lane B / 基底 origin/main〔W0–W4 已合入〕（canvas_tool_actions.dart 叠在 W4 undo-node-create-move 之后）
- 依赖切片：undo-stack（W0）、narrative-splice（W1）、undo-shortcuts-ui（W2）、undo-adopt-existing（W3）、undo-node-create-move（W4）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 连线模式点目标、从出端口拖到另一张卡上松手，连好的线可以 Ctrl Z 撤掉、Ctrl Y 再连回来。
- 检查器「关键帧」组里改一条入边的角色（参考 / 首帧 / 尾帧）算一步；改成首帧 / 尾帧时被顺带降成参考的那条，撤销时一起回到原角色。
- 删线（舞台删线按钮、检查器入边「移除输入」）已由 W3 进栈；本片核对两处都进栈，没进的补上。
- 撤销找边按两端（下游节点 + 角色 + 上游所属配置节点），不按边 id：系统改写过的边（tc-take-edge-follow 把线挪到新 take）也能撤。

## 设计依据
- 画板 UndoClipboard.dc.html（b2_history.js）「什么进栈」：「连线 / 删线 / 改语义 → 连线 首帧 · 改为 参考」。
- 同画板规则：「改成首帧 / 尾帧会把同节点原来那条降成参考（同一事务），撤销两条一起回」；「系统自动改写的边不进栈，所以反向找边一律按两端（下游节点 + 端口 + 上游所属配置节点），不按边 id」。
- 「要补的底座」：反向令牌补 updateRole（含降级那条）。
- critic.txt 第 17 条：TC-Q1 选 A 时系统改写 data 边、不进栈，之后再撤「连线 / 改语义」不能按 id 找边——本片的 EdgeEnds 就是答案。
- 设计缺口：画板没说「撤销连线」时这条线已被用户另改了角色怎么办——按栈序，改角色那一步更晚、会先被撤，所以按「当时的角色」找；找不到 = 对象已消失、丢步。
- 「改连线类型（叙事 ↔ data）」的入口在 W6 cm-edge-menu 的连线菜单，命令由那片做（可复用本片的 EdgeEnds）；本片不做。

## 允许改的文件
- lib/features/canvas/models/commands/edge_link_command.dart（新建，独立文件，不是 part）：AddEdgeCommand、ChangeEdgeRoleCommand。（不改 canvas_command.dart。）
- lib/features/canvas/util/edge_ends.dart（新建，纯函数）：EdgeEnds + edgeEndsOf + findEdgeByEnds。**复核结论**：W0 undo-stack 已建 `models/edge_endpoints.dart` 的 `EdgeEndpoints`（source / target / edgeType / role，`matches` 只比 source / target / edgeType）+ `findEdgeByEndpoints`，W1 narrative-splice 的 `SpliceUndoToken` 也用它；但它没有「上游所属配置节点」这一维，undo-stack 派工单风险段明确要求这类匹配「在 EdgeEndpoints 之外另写匹配函数、不改 matches 语义」。所以本文件**建在它上面**：`EdgeEnds` 持一个 `EdgeEndpoints key` + `sourceAnchorId`（不重抄四个字段），`findEdgeByEnds` 先调 `findEdgeByEndpoints(edges, ends.key)` 精确找，找不到再走 anchor 回退（回退时比 role）。
- lib/features/canvas/providers/canvas_edges_controller.dart：
  - updateRole（main 第 179–227 行）返回值 `Future<void>` → `Future<EdgeRoleChange?>`，记下改的那条的旧角色、被降级各条的 id 与旧角色（降级集就是第 189 行 _conflictingFrameRoles 算出的 demote）。没找到边 / 新旧角色相同返回 null。
  - 新增 `setRoles(Map<String, EdgeRole> roles)`：一个 UoW 事务按给定 id 写回角色，不跑降级（撤销是回到之前一个合法状态）；写完若同目标节点出现首帧 / 尾帧冲突，再用 _conflictingFrameRoles 把其余降成参考（防御）。乐观更新 + 失败回滚，与 updateRole 同口径；走 serialize。
- lib/features/canvas/providers/link_action_controller.dart：linkTo（第 37–77 行）addEdge 成功后（第 63 行 state = created 之前）record AddEdgeCommand；selfLink / duplicate（23505）/ failed 不 record。
- lib/features/canvas/widgets/node_inputs_section.dart：_InputRow 角色下拉 onChanged（第 199–204 行）改成 await updateRole 拿令牌 → record ChangeEdgeRoleCommand。「移除输入」W3 undo-adopt-existing 已改成 `deleteEdgeWithUndo`（util/canvas_edge_delete.dart，进栈 + 卡），本片不动那一行，只在测试里守住。
- lib/features/canvas/util/canvas_tool_actions.dart：linkByPortDrop（第 296–308 行）走 linkTo，进栈在 linkTo 里，原则上不改；只在注释写明。
- test/features/canvas/canvas_edges_controller_test.dart、test/features/canvas/link_action_controller_test.dart、test/features/canvas/util/edge_ends_test.dart（新建）、test/features/canvas/widgets/node_inputs_section_test.dart。

## 不许碰的文件
- 同波：node_card.dart、widgets/stage/node_card_slot.dart、providers/node_drag_delta.dart、util/drop_placement.dart、util/drag_axis_lock.dart、widgets/edge_painter.dart、widgets/stage/stage_edge_layer.dart、group_drag_hint.dart（group-drag）；inspector_submit_controller.dart、characters_section.dart、image/video/shot/text 检查器、canvas_prompt_bar.dart、canvas_inspector_panel.dart、providers/inspector_revision.dart、models/commands/param_patch_command.dart（undo-params）；left_rail/assets_*、canvas_menu/canvas_menu_host.dart、canvas_menu/canvas_menu_request.dart、asset_drop_*、widgets/stage_drop/stage_drop_registry.dart、models/commands/asset_drop_command.dart（rail-drag-assets）；current_take_controller.dart、models/commands/set_current_take_command.dart、generation_controller.dart、canvas_job_listener.dart、util/current_take_edges.dart（tc-take-edge-follow）。
- canvas_nodes_controller.dart、canvas_snackbars.dart、canvas_history_controller.dart、models/edge_endpoints.dart、util/canvas_edge_delete.dart（只用不改）。

## 具体改动
```dart
// util/edge_ends.dart
@immutable
class EdgeEnds {
  const EdgeEnds({required this.key, required this.sourceAnchorId});
  final EdgeEndpoints key;     // W0 models/edge_endpoints.dart：sourceNodeId（当时的上游）/ targetNodeId / edgeType / role
  final String sourceAnchorId; // 上游所属配置节点：上游是 result ⇒ 它的 sourceNodeId；否则上游自己
  String get sourceNodeId => key.sourceNodeId;
  String get targetNodeId => key.targetNodeId;
  EdgeRole get role => key.role;
  EdgeEnds withRole(EdgeRole r);
}
EdgeEnds edgeEndsOf(CanvasEdge e, List<CanvasNode> nodes);
/// 先按 sourceNodeId 精确找；找不到再找 target/type/role 相同且上游 anchor 相同的活边（系统把线挪到新 take 的情形）；
/// 多条候选取 sortOrder 最小、再按 id 字典序（确定性）；都没有返回 null。
CanvasEdge? findEdgeByEnds(EdgeEnds ends, List<CanvasEdge> edges, List<CanvasNode> nodes);

// canvas_edges_controller.dart
typedef EdgeRoleChange = ({String edgeId, EdgeRole from, EdgeRole to,
    List<({String edgeId, EdgeRole from})> demoted});
Future<EdgeRoleChange?> updateRole(String id, EdgeRole role);
Future<void> setRoles(Map<String, EdgeRole> roles);

// models/commands/edge_link_command.dart（独立文件；canvasId 从 CanvasCommandEnv 取，构造不收）
class AddEdgeCommand extends CanvasCommand {
  AddEdgeCommand({required EdgeEnds ends});
  @override String label(AppLocalizations l);   // l.canvasCommandLinkEdge(edgeKindLabel(l, ends))
  // affectedNodeIds = {ends.sourceNodeId, ends.targetNodeId}
}
class ChangeEdgeRoleCommand extends CanvasCommand {
  ChangeEdgeRoleCommand({required EdgeEnds changed /* 角色 = to */,
      required EdgeRole from, required List<({EdgeEnds ends /* 角色 = reference */, EdgeRole from})> demoted});
  @override String label(AppLocalizations l);   // l.canvasCommandChangeEdgeRole(角色 to 的名字)
  // affectedNodeIds = {changed.targetNodeId}
}
/// 给步名用的 {kind}；W6 cm-edge-menu 的 ChangeEdgeTypeCommand 复用它。
String edgeKindStepLabel(AppLocalizations l, EdgeType type, EdgeRole role);
```
- AddEdgeCommand.revert：在 `env.ref` 读 edges / nodes 控制器内存里 findEdgeByEnds → null 则返回 `CanvasCommandOutcome.gone`；否则 removeEdge(id)，记下返回的 CanvasEdge → `done`。apply（重做）：有记下的 CanvasEdge ⇒ `restore(edge)`（我们自己软删的行；restore 第 128–167 行自带首帧 / 尾帧防冲突降级）；没撤过 ⇒ `done` 不动。
- ChangeEdgeRoleCommand.revert：找 changed（按 to 角色）与每条 demoted（按 reference 角色）的活边 → `setRoles({changed: from, demotedᵢ: fromᵢ})` 一个事务；changed 找不到 ⇒ `gone`；某条 demoted 找不到（已被删）⇒ 只回找得到的。apply：找 changed（按 from 角色）→ updateRole(id, to)（降级重新计算）。InkError 都不吞（undo-stack 当 failed）。
- record 时机：linkTo 拿 addEdge 返回的 CanvasEdge → edgeEndsOf(edge, nodes) → record。node_inputs_section 拿 EdgeRoleChange → 换成 EdgeEnds（nodes 取 canvasNodesControllerProvider 现值）→ record。
- 步名：link →「连线 {kind}」；changeRole →「改为 {kind}」。{kind}：narrative「叙事线」、firstFrame「首帧」、lastFrame「尾帧」、reference「参考」。

## 行为规则与边界情况
1. 连线成功 ⇒ 一步；23505 重复 / 自连 / 失败 ⇒ 不进栈。连线模式和端口拖放走同一个 linkTo，两边都进栈。
2. 新建菜单「建好并连线」那条线属于 W4 的 CreateNodesCommand，不在这里重复进栈。
3. 撤销连线 ⇒ 这条线软删；重做 ⇒ 按原 id 复原（复原时目标已有首帧则按 restore 的降级规则处理）。
4. 改角色 B: 参考→首帧，同节点原首帧 A 被降成参考 ⇒ 一步；撤销 ⇒ B 回参考、A 回首帧，一个事务；重做 ⇒ B 首帧、A 参考。
5. 改角色无冲突（参考↔尾帧且无别的尾帧）⇒ 一步，撤销只回这一条。下拉选同一个值不进栈（现有第 200 行判据）。
6. 系统把 B 的上游从 take 1 挪到 take 2（tc-take-edge-follow，不进栈）之后撤销「连线 B」⇒ 按 anchor（同一个配置节点）找到挪过的那条并删掉。
7. 撤销时那条线已被删（另一步被卡片 undoSpecific 抽走）⇒ 对象已消失 ⇒ 丢步、提示，不连带撤下一步。
8. setRoles 事务失败 ⇒ 内存回滚、InkError 上抛，由 undo-stack 留栈顶 + 提示。
9. 删线（舞台删线按钮 / 入边「移除输入」）⇒ 进栈一步（W3）；本片的测试顺带守住入边「移除输入」进栈。
10. 检查器下拉改角色写失败 ⇒ 不进栈（控制器已回滚）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasCommandLinkEdge | Link {kind} | 连线 {kind} |
| canvasCommandChangeEdgeRole | Change to {kind} | 改为 {kind} |
| canvasCommandEdgeKindNarrative | narrative | 叙事线 |
| canvasCommandEdgeKindFirstFrame | first frame | 首帧 |
| canvasCommandEdgeKindLastFrame | last frame | 尾帧 |
| canvasCommandEdgeKindReference | reference | 参考 |

## 测试
test/features/canvas/util/edge_ends_test.dart（新建，纯函数）
- 「上游是 result 时 anchor = 它的源配置节点」。
- 「精确 source 命中优先」。
- 「source 被挪到同配置的新 take 仍能找到」：原边删掉、同 target/role 从 take 2 起一条 ⇒ 找到新那条。
- 「anchor 不同不算」：另一个配置节点的 result 连到同 target 同 role ⇒ null。
test/features/canvas/canvas_edges_controller_test.dart（追加；FakeUnitOfWork + InMemoryEdgeRepository）
- 「updateRole 返回降级令牌」：A 首帧、B 参考，updateRole(B, firstFrame) ⇒ from=reference、demoted=[(A, firstFrame)]。
- 「updateRole 无冲突 demoted 为空」；「同角色返回 null」。
- 「setRoles 一个事务写回两条」：断言 FakeUnitOfWork.run 调用 1 次、两条角色都回去。
- 「setRoles 失败整体回滚」：第二条 update 抛 InkError ⇒ state 等于调用前。
test/features/canvas/link_action_controller_test.dart（追加）
- 「linkTo 成功进栈一步，撤销删边，重做同 id 回来」。
- 「23505 重复不进栈」。
- 「系统挪过上游后撤销连线仍删得掉」（直接改 InMemoryEdgeRepository 模拟挪边，然后 invalidate edges）。
test/features/canvas/widgets/node_inputs_section_test.dart（追加）
- 「改成首帧一步撤两条」：撤销后 A 首帧、B 参考。
- 「移除输入进栈」：点 link_off 图标后栈深 1。

## 变异点
1. linkTo 删掉 record ⇒「linkTo 成功进栈一步…」红。
2. updateRole 不记 demoted（返回空列表）⇒「updateRole 返回降级令牌」和「改成首帧一步撤两条」红。
3. AddEdgeCommand.revert 把 findEdgeByEnds 换成按记下的 edge id 找 ⇒「系统挪过上游后撤销连线仍删得掉」红。
4. findEdgeByEnds 去掉 anchor 回退 ⇒「source 被挪到同配置的新 take 仍能找到」红。
5. findEdgeByEnds 不比 anchor（只比 target/role）⇒「anchor 不同不算」红。
6. setRoles 拆成两次独立 update（不进 UoW）⇒「setRoles 一个事务写回两条」红。
7. duplicate 分支也 record ⇒「23505 重复不进栈」红。

## 验收
- flutter analyze lib test；flutter test test/features/canvas --exclude-tags golden；逐条变异。
- 截图：VideoConfigInspector 的入边区（NodeInputsSection），种 video config + 两个 image 上游（A 首帧、B 参考）；截①改 B 为首帧后（A 显示参考帧）②Ctrl Z 后（A 首帧、B 参考）③空白处右键菜单显示「重做 改为 首帧」。

## 风险与不确定
- updateRole 改返回类型：现有调用只有 node_inputs_section.dart:201（.catchError）和测试；grep 确认没有别的 await 依赖 void。
- （复核已定）W0 undo-stack 的 `EdgeEndpoints` 是唯一的「按两端」类型（W1 narrative-splice 的令牌也用它）；本片的 `EdgeEnds` 包一层它 + anchor，不另抄字段，不改 `EdgeEndpoints.matches`。W5 同波 tc-take-edge-follow 在事务内按行（source == toSourceId && target && role && data）找边，是库行层面的另一回事，不用本文件。
- 「改连线类型」命令留给 W6 cm-edge-menu；若主 Agent 要本片顺带做，需要 narrative-splice changeEdgeType 令牌的确切形状。
- canvas_tool_actions.dart 本片很可能零改动；它在本波归本片只是为了 linkByPortDrop 的保险。
