# tc-take-edge-follow · 下游 data 边跟着当前 take 走（设为当前 / 没固定时来了新 take，一个事务挪边）
阻塞决定：TC-Q1 按建议 A 写；若改选 B 本片作废

- 波次 W5 / lane E / 基底：origin/main〔W0–W4 已合入〕
- 依赖切片：tc-set-current（W3，current_take_controller.dart + SetCurrentTakeCommand）、gen-inputs-snapshot（W2，generation_controller 里写 gen_inputs）、tc-batch-slot-set-current（W4，抽出的 `writePinInScope` / `revertPinInScope` / `invalidateAfterPin` 与 SetCurrentSlotCommand）、current-take（W1，currentResultFor / pinnedResultId extension）、undo-stack（W0）
- 阻塞决定：TC-Q1（下游连线怎么跟当前 take）按建议 A「改写连线」写。若拍板改成 B（连线不动、生成时解析到当前 take），本片整片作废，改为改 `generation_controller._resolveRefImages`，撤销命令形状也跟着变。

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 线永远画在当前 take 上：用户「设为当前」（历史页、成片检查器、右键菜单、批量 slot）时，原来接在旧当前 take 上的 data 出边（首帧 / 尾帧 / 参考）一起挪到新当前，同一个事务。
- 没固定时出了新 take：新 take 成为当前，接在旧当前上的 data 边自动挪过去；画布没开也照挪，打开画布看到的就是挪好的线。
- 撤销「设为当前」时边一起回去，算一步；系统自动挪的不进撤销栈。

## 设计依据
- TakesCost.dc.html「需要你定」Q1：A「改写连线：设为当前、或没固定时出了新 take，就把接在旧当前上的 data 边挪过去，线永远画在当前 take 上」，建议 A（所见即所用，生成侧读边的代码不用改）。按 TC-Q1 建议 A。
- TakesCost.dc.html「当前 take · 固定」：「撤销：『设为当前』连同它改写的 data 边算一步（Q1 选 A 时）；反向按边两端的节点找边，不按边 id」；「固定 = 新 take 不顶替它」。
- UndoClipboard.dc.html「什么进栈」规则：「『设为当前』和它改写的 data 边是一步；系统自动改写的边不进栈，所以反向找边一律按两端（下游节点 + 端口 + 上游所属配置节点），不按边 id」；「任务建的产物节点」不进栈。
- 设计缺口：画板没说下游节点就是本配置节点自己时（img2img 迭代：take → 自己的配置）挪不挪——本片规定不挪（挪了新 take 一出来就立刻「过期」，见规则 5）；没说新当前已经有一条到同一目标的线怎么办（本片：旧线软删，撤销时按两端重建）；没说删掉当前 take 后线去哪（删节点连带删线，本片不处理）；没说挪边时给不给用户提示（本片不提示）。

## 允许改的文件
- `lib/features/canvas/util/current_take_edges.dart`（新建）：纯函数 plan + 事务内执行 / 回滚 + 「哪些画布新进 succeeded」判据。只 import canvas models、node_artifacts、core interfaces，不 import Riverpod provider 文件（generation_controller 要用它）。
- `lib/features/canvas/providers/current_take_controller.dart`（由 tc-set-current 新建，W4 抽出了 writePinInScope 等）：`writePinInScope` 写 pin 前先算旧当前、写后挪边，`PinToken` 加 `movedEdges`；`revertPinInScope` 先回边再回 pin；`invalidateAfterPin` 加 `canvasEdgesControllerProvider(canvasId)`。重做时重新规划，不复用旧的 movedEdges。**`writePinInScope(scope, {configNodeId, resultNodeId})` 的签名不改**（W4 的 batch_results_controller 与 SetCurrentTakeCommand 都在调，本片不碰调用方）：需要的 canvasId 在事务里 `scope.nodes.findById(configNodeId)` 读配置行的 `canvas_id`。
- `lib/features/generation/generation_controller.dart`：`_track` 成功分支（现 :485–497，`_readArtifactPath` 之后、`jobsRegistry.upsert(JobState.succeeded…)` 之前）加 `_followEdgesToNewTake`。
- `lib/features/canvas/widgets/canvas_job_listener.dart`：对新进 succeeded 的画布 `ref.invalidate(canvasEdgesControllerProvider(canvasId))`。
- （复核已定，不改命令文件）W4 tc-batch-slot-set-current 已把 W3 的 `SetCurrentTakeCommand` 改成持 `PinToken`、revert / apply 走 `revertPinInScope` / `writePinInScope`，W3 也不再预留 `movedEdges` / `MovedDataEdge`；W4 的 `SetCurrentSlotCommand` 同样走这两个函数。所以挪边信息只放在 `PinToken.movedEdges`，两个命令文件本片都不碰——改这两个函数就自动生效。
- 测试：`test/features/canvas/util/current_take_edges_test.dart`（新建）、`test/features/generation/generation_controller_test.dart`、`test/features/canvas/providers/current_take_controller_test.dart`、`test/features/canvas/widgets/canvas_screen_job_listener_test.dart`、`test/features/generation/providers/batch_results_controller_test.dart`（只追加一条）。

## 不许碰的文件
- `canvas_edges_controller.dart`、`link_action_controller.dart`、`canvas_tool_actions.dart`、`node_inputs_section.dart`、`util/edge_ends.dart`、`models/commands/edge_link_command.dart`（undo-edges）；`node_card.dart`、`widgets/stage/node_card_slot.dart`、`node_drag_delta.dart`、`drop_placement.dart`、`edge_painter.dart`、`widgets/stage/stage_edge_layer.dart`（group-drag）；`inspector_submit_controller.dart` 及各检查器、`canvas_prompt_bar.dart`、`canvas_inspector_panel.dart`、`models/commands/param_patch_command.dart`（undo-params）；`left_rail/assets_*`、`canvas_menu/canvas_menu_host.dart`、`canvas_menu/canvas_menu_request.dart`、`widgets/stage_drop/stage_drop_registry.dart`、`models/commands/asset_drop_command.dart`（rail-drag-assets）。
- `models/commands/set_current_take_command.dart`、`models/commands/set_current_slot_command.dart`（W4 已改好，只靠 writePinInScope / revertPinInScope 生效）。
- `canvas_job_effects.dart`（不改纯决策，新判据写在 current_take_edges.dart）；`batch_results_controller.dart`（W4 已改走 writePinInScope，本片不动）；`edge_repository.dart` / `node_repository.dart`（不加方法，用现有 `listByCanvas` / `listOutgoing` / `update` / `softDelete` / `create`）。

## 具体改动
```dart
// current_take_edges.dart
@immutable
class TakeEdgeMove {
  final String targetNodeId;
  final EdgeRole role;
  final int sortOrder;
  final String fromSourceId;   // 旧当前 result
  final String toSourceId;     // 新当前 result
  final bool dropped;          // 新当前已有到同一目标的 live data 边（uq_edges_live 不让两条）→ 旧边软删，没改写
}

/// 纯函数：旧当前 [fromResultId] 的 data 出边 → 挪到 [toResultId] 的计划。
List<TakeEdgeMove> planTakeEdgeFollow({
  required String configNodeId,
  required String? fromResultId,
  required String toResultId,
  required List<CanvasEdge> liveEdges,
});

/// 新 take 到达时：它是否接管当前（没固定或固定的已删，且它就是 currentResultFor 的结果）；接管时返回被顶替的旧当前 id，否则 null。
String? previousCurrentIfTakeOver({
  required CanvasNode config,
  required List<CanvasNode> nodes,
  required String newResultId,
});

/// 事务内执行：读 scope.edges.listByCanvas → plan → update(source_node_id) 或 softDelete。返回实际执行的步。
Future<List<TakeEdgeMove>> followEdgesInScope(RepositoryScope scope, {
  required String canvasId, required String configNodeId,
  required String? fromResultId, required String toResultId,
});

/// 事务内回滚：按两端找边（source == toSourceId && target && role && edge_type == data），不按 id。
Future<void> revertEdgeMovesInScope(RepositoryScope scope, {required String canvasId, required List<TakeEdgeMove> moves});

/// jobsRegistry 前后两版 → 有 job 新进 JobSucceeded 的画布 id。
Set<String> canvasesWithNewSuccess(List<JobState> prev, List<JobState> next);

// current_take_controller.dart（改 W4 抽出的类型）
class PinToken { ...; final List<TakeEdgeMove> movedEdges; }

// generation_controller.dart
Future<void> _followEdgesToNewTake({required String canvasId, required String configNodeId, required String resultNodeId});
```
`writePinInScope` 新流程（同一个 scope）：`scope.nodes.listByCanvas(canvasId)` → `CanvasNodeMapping.fromRow` → `old = currentResultFor(config)` → 写 `pinned_result_id` → `old?.id != resultNodeId` 时 `followEdgesInScope(from: old?.id, to: resultNodeId)` → token 带上 moves。
`_followEdgesToNewTake`：一个 `uow.run`：读画布节点 → 配置节点不在 / 不是 config 就返回 → `previousCurrentIfTakeOver` 为 null 就返回 → `followEdgesInScope`。整个函数 `on InkError` 只 `logger?.warn(_logModule, 'take edge follow failed', extra: {job_id, config_node_id, reason})`，不影响 job 成功；成功挪了 n 条记一条 info（module 同 `generation.controller`，英文）。`GenerationController` 构造参数不变（已有 `uow`）。

## 行为规则与边界情况
1. 只挪 edge_type == data 的出边（三种 role 都挪），narrative / generation_source 不动；只挪「旧当前」那一个 result 的出边，同配置下别的旧 take 上用户手接的线不动。
2. 挪 = `edges.update(id, {source_node_id: toResultId})`，target / role / sort_order 不变。
3. 新当前已经有到同一目标的 live data 边：旧边软删（`dropped: true`），不改写、不报错。
4. 目标节点就是本配置节点自己（take → 自己的配置，img2img 迭代）的边不挪。
5. （第 4 条的理由，可测）挪了之后本配置的输入变了，新 take 一出来就会被 tc-stale-marks 判过期；本片用「目标是自己」的 plan 用例钉住。
6. 设为当前（W3 的各入口 + W4 批量 slot）：pin 和挪边同一事务、同一步撤销；撤销先按两端把边挪回、再回 pin；重做重新规划（期间边可能已变）。
7. 回滚找不到对应的边（用户后来删了它）→ 跳过这一条，其余照回；旧源到目标已经有 live data 边（用户后来手接了）→ 把挪过去的那条软删，不 update（避免撞 uq_edges_live）；dropped 的那条回滚 = 按原 role / sort_order 重新 `create`（已存在就跳过）。
8. 新 take 到达（`_track` 成功分支）：配置节点固定着且固定的那个还活着 → 不挪；固定的已删 → 按「最新」判；新 take 不是 currentResultFor 的结果（晚提交的先完成，再完成早提交的那个）→ 不挪；名下第一个 take（没有旧当前）→ 不写。
9. 新 take 的挪边写库在 `jobsRegistry.upsert(succeeded)` **之前**，这样 CanvasJobListener 收到 succeeded 去 invalidate 边控制器时读到的是挪好的库。
10. 挪边失败（InkError）：job 照常 succeeded，边保持原样，记 warn；不出错误卡。
11. 失败 / 取消（含批量部分成功后取消、结果节点保留）不挪边。
12. 新 take 自动挪边不进撤销栈（UndoClipboard：任务做的不算）；所以之后用户撤销别的步骤时按两端找边不会被它打乱。
13. 画布没开：库照写；`CanvasJobListener` 挂在 InkShell，invalidate 一个没人 watch 的边控制器是空操作，下次打开画布 build 读到新库。
14. 画布开着：`canvasesWithNewSuccess` 命中的画布 invalidate 边控制器，线在同一帧跟到新 take；进度 tick、failed、cancelled 不 invalidate 边。
15. 两个 job 同一配置并发完成：每个 job 各自在自己的 uow 里判断「我是不是当前」，晚完成但早提交的那个不挪（规则 8），不会把线挪回旧 take。
16. 序列 / 导出 / 生成侧读边的代码不改（Q1 A 的前提）。

## 新文案键
无。

## 测试
- `test/features/canvas/util/current_take_edges_test.dart`（新建，纯函数用 CanvasNode / CanvasEdge 直接构造；scope 函数用 `test/_harness/fake_repositories.dart` 的 `InMemoryNodeRepository` / `InMemoryEdgeRepository` + `fake_unit_of_work.dart` 的 `FakeRepositoryScope`）：
  - `plan：旧当前的三种 role data 出边都挪到新当前，target / role / sortOrder 不变`
  - `plan：narrative 与 generation_source 出边不动`
  - `plan：同配置下其他旧 take 的出边不动`
  - `plan：目标是本配置节点自己的边不挪`
  - `plan：新当前已有到同一目标的 data 边 → 旧边记 dropped`
  - `plan：from 为 null 或 from == to → 空计划`
  - `previousCurrentIfTakeOver：没固定 → 返回旧最新；固定且活着 → null；固定的已删 → 按最新；新 take 不是最新 → null；第一个 take → null`
  - `follow + revert 往返：边回到旧当前，按两端找（中途把边删掉重建换了 id 也能回）`
  - `revert：一条已被删 → 跳过，其余照回`
  - `revert：旧源到目标已有手接的边 → 软删挪过去的那条`
  - `revert dropped：按原 role / sortOrder 重建`
  - `canvasesWithNewSuccess：只收新进 succeeded 的画布；failed / cancelled / running 进度变化不算`
- `test/features/generation/generation_controller_test.dart`（新 group `新 take 到达：下游 data 边跟到新 take`；`_FakeEdgeRepo` 补 `listByCanvas` / `listOutgoing` / `update` / `softDelete` 的真实 rows 实现，`FakeRepositoryScope` 补 `edges: edges`；节点行要带 `type_config.image_url` 与 `created_at`）：
  - `没固定：旧当前 R1 的 data 出边改到新 R2`
  - `写库发生在 succeeded 推进注册表之前`（`_RecordingRegistry.upsert` 时读 edges.rows 断言已挪）
  - `固定着 R1：边不动`
  - `名下第一个 take：一条 edges.update 都没有`
  - `挪边抛 InkError：job 照常 succeeded，logger 有一条 warn`
  - `job 失败 / 取消：边不动`
- `test/features/canvas/providers/current_take_controller_test.dart`：
  - `设为当前 R1→R3：边挪到 R3；撤销栈只多一步`
  - `撤销：边回 R1、pin 回旧值；重做：重新规划后再挪到 R3`
  - `设为当前后边控制器被 invalidate（重新 listByCanvas 一次）`
- `test/features/generation/providers/batch_results_controller_test.dart`：`批量 slot 设为当前：较旧 take 上的 slot 也会把下游边挪过来，撤销一起回`。
- `test/features/canvas/widgets/canvas_screen_job_listener_test.dart`：`job 成功 → 该画布边控制器重新读库`、`job 失败 → 边控制器不重读`。

## 变异点
1. `planTakeEdgeFollow` 去掉「目标是本配置节点自己」的过滤 → 「plan：目标是本配置节点自己的边不挪」红。
2. plan 不过滤 edge_type（narrative 也挪）→ 「narrative 与 generation_source 出边不动」红。
3. `previousCurrentIfTakeOver` 去掉固定判断 → 「固定着 R1：边不动」与对应纯函数用例红。
4. `previousCurrentIfTakeOver` 去掉「新 take 是不是 currentResultFor 结果」的判断 → 「新 take 不是最新 → null」红。
5. `_followEdgesToNewTake` 挪到 `jobsRegistry.upsert(succeeded)` 之后 → 「写库发生在 succeeded 推进注册表之前」红。
6. `revertEdgeMovesInScope` 改成按 edge id `update` → 「中途把边删掉重建换了 id 也能回」红。
7. `writePinInScope` 不挪边 → 「设为当前 R1→R3：边挪到 R3」与批量 slot 用例红。
8. CanvasJobListener 改成任何终态都 invalidate 边 → 「job 失败 → 边控制器不重读」红。
9. `_followEdgesToNewTake` 的 InkError 往外抛 → 「挪边抛 InkError：job 照常 succeeded」红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/util/current_take_edges_test.dart test/features/generation test/features/canvas/providers/current_take_controller_test.dart test/features/canvas/widgets/canvas_screen_job_listener_test.dart`；逐条变异。
- 截图：用示例画布（canvas_bootstrap_controller 建的两镜）：镜头 01 有 take 1、take 2，镜头 01 当前 take 用首帧线接到镜头 02 的视频配置；截「设为当前 take 1 后线画在 take 1 上」，再按 Ctrl Z 截「线回到 take 2」。

## 风险与不确定
- （复核已定）W4 派工单已写死 `PinToken` / `writePinInScope(scope, {configNodeId, resultNodeId})` / `revertPinInScope(scope, token)` / `invalidateAfterPin(Ref, {canvasId})`，并让 SetCurrentTakeCommand 走它们；本片不碰命令文件。
- `writePinInScope` 读整张画布的节点行来算旧当前，节点多的画布每次设为当前多一次 listByCanvas；可接受（同 `_resultPlacement` 已有一次）。
- （复核已定）W3 tc-set-current 明确不做「取消固定」入口（设计缺口①），本片不用处理。
- 删掉当前 take 时下游线跟着删掉，不挪到新的当前（设计缺口，留给后续片）。
- generation_controller.dart 下一波 W10 batch-run-executor 也会改 `_track`，本片改动要集中在一个私有方法里。
