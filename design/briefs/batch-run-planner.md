# batch-run-planner · 批量运行计划（纯函数）
- 波次 W9 / lane B / 基底：origin/main（W0–W8 已合入）；依赖切片：current-take（W1：`util/node_artifacts.dart` 的 `currentResultFor({sourceNodeId, nodes, accept, pinnedResultId})`、`models/canvas_node_take.dart` 的 `extension CanvasNodeTake { String? get pinnedResultId; }`）、node-cost（W2：`estimateNodeCost`，本片只经 `costOf` 回调间接用）、node-disabled-flag（W8：`models/canvas_node_disabled.dart` 的 `extension CanvasNodeDisabled { bool get isDisabled; }`）、tc-stale-marks（W7，只借它的输出形状，本片不 import）；阻塞决定：无（TakesCost Q4 → A 默认跳过已固定可勾回；Q8 → A 取前 50 个；Q5 只影响 mode 的默认值，由 batch-run-dialog 管）

## 目标（用户看到什么变化，2–4 行）
本片没有界面。产出一个纯函数：给一组候选节点，算出「这次跑哪些、按什么顺序、每行什么状态、一共多少钱、还有几个不在本次」。
W10 的执行器（batch-run-executor）照它的顺序提交，W11 的运行对话框（batch-run-dialog）照它逐行出字。两边都不再自己排序，也不再自己判断跳过不跳过。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
`b2/project/TakesCost.dc.html`，小节「花费预告 · 批量运行」：
- 顺序（只在这张板定）：按 data 边依赖排，批内有上游的，下游等上游成功；没有依赖的按叙事链序。
- 超过 50 个：按上面的顺序取前 50 个，底部写「另 N 个不在本次」，按钮写「运行 50 个」（Q8 A）。
- 不跑批外的上游：用它现在的当前 take；没有 take 就记「缺首帧 · 跳过」。草稿（没提示词）不列。
- 已停用（type_config.disabled）的列一行「跳过 · 已停用」：不计数、不计价、不能勾回。
- 已固定的列「跳过 · 已固定」，勾上「包括已固定的」可以勾回（Q4 A）。
- 合计行写「N 个 · 约 $x · 另 N 个价格未知」；算不出价的那一格写「—」。
- 示例行的状态：没生成过 / 等 01 · 首帧 / 已过期 / 价格未知 / 跳过 · 已固定 / 跳过 · 已停用。
- `b2/project/ContextMenus.dc.html` W2（停用只在批量运行时跳过）；`b2/project/Selection.dc.html`「生成 N 个只数配置节点（停用的不算）」。
- 设计缺口：mode = 只跑过期和没生成的时，已经是最新的节点列不列，画板没画。本片定为不列（同草稿），由对话框给空态。
- 设计缺口：mode = 全部时，已是最新的节点那一行写什么，画板没画。本片定状态 `rerun`，对话框写「重新生成」。
- 设计缺口：缺的是尾帧时写什么，画板只写了「缺首帧」。本片把尾帧也算成跳过，另给 `missingRole`；参考图缺了照跑，因为生成侧本来就会静默跳过它。
- 设计缺口：同一个节点已经有任务在跑时怎么办，画板没画。本片定为列一行「生成中 · 跳过」，由调用方传 `activeNodeIds`。
- 设计缺口：mode = 只跑过期和没生成的时，上游在本批要重跑、下游是最新的，下游跟不跟着跑，画板没说。本片定为跟着跑：上游一重跑，下游马上就会过期，状态记 `stale`。
- 设计缺口：data 边成环，画板没说。本片定为环里的节点按叙事链序排，环内的依赖不算，各自用当前 take。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/generation/services/batch_run_planner.dart`（新建）：下面「具体改动」里的全部类型和 `planBatchRun`。只 import canvas 的 models / util（canvas_node、canvas_edge、narrative_order、node_artifacts，`node_menu_model.dart` 的 `isGenerableNode`，以及 W8 的 `models/canvas_node_disabled.dart`、current-take 新建的 `models/canvas_node_take.dart`）。不 import Riverpod、Flutter widgets、stale_takes_provider、node_cost。
- `test/features/generation/services/batch_run_planner_test.dart`（新建）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- canvas-find-bar：`lib/features/canvas/widgets/canvas_screen.dart`、`widgets/stage/node_card_slot.dart`、`widgets/node_card.dart`、`lib/theme/tokens.dart`（W9 只归它追加）、`app_action_catalog.dart` 的「查找」行、新 `util/canvas_find_model.dart` / `providers/canvas_find_controller.dart` / `widgets/canvas_find_bar.dart` / `shortcuts/find_keys.dart`。
- 同波另有：os-drop-paste-image 的 `util/canvas_import_actions.dart`（抽公开入口）与新 `widgets/os_file_drop_overlay.dart` / `util/import_drop_summary.dart` / `util/canvas_import_drop_actions.dart`；dep-drop-pasteboard 的新 `lib/core/interfaces/system_clipboard_image_service.dart` / `lib/services/pasteboard_clipboard_image_service.dart` / `lib/core/di/clipboard_image.dart`；multi-select-inspector 的新 `widgets/multi_select_inspector.dart` / `util/multi_select_params.dart` / `providers/multi_select_patch_controller.dart`；rail-drag-characters 的 `widgets/stage_drop/stage_drop_registry.dart`（追加一行）与新 `util/canvas_character_drop_actions.dart`；outline-rename-menu 的新 `models/commands/rename_node_command.dart`。
- job-eta（同 lane，排在本片之后）：`lib/storage/repositories/postgres_job_repository.dart`、新 `lib/core/interfaces/job_duration_history.dart`、`lib/core/di/job_duration_history.dart`、`lib/features/generation/providers/provider_eta_provider.dart`。
- dep-drop-pasteboard / os-drop-paste-image：`pubspec.yaml`、`pubspec.lock`、平台插件注册文件、`widgets/canvas_view.dart`、`widgets/shortcuts/clipboard_keys.dart`、`util/canvas_paste_actions.dart`。
- multi-select-inspector：`widgets/canvas_inspector_panel.dart`、`widgets/image_config_inspector.dart`、`widgets/video_config_inspector.dart`、新 `util/provider_capability_fields.dart`。
- rail-drag-characters / outline-rename-menu：`widgets/character_library_panel.dart`、`util/ref_image_budget.dart`、`widgets/left_rail/outline_panel.dart`、`providers/canvas_nodes_controller.dart`、`models/canvas_command.dart`。
- 全波禁区：`util/canvas_tool_actions.dart`、`util/node_menu_model.dart`、`canvas_menu/node_menu_entries.dart`、`widgets/canvas_shortcuts.dart`（骨架和注册表）、`lib/features/generation/generation_controller.dart`、`util/narrative_order.dart`（只复用）、`lib/features/generation/services/node_cost.dart` 和 `cost_estimator.dart`（只经回调使用）、tc-stale-marks 的 `util/take_staleness.dart` / `providers/stale_takes_provider.dart`。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：rail-drag-characters：`lib/features/canvas/widgets/characters_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
const int kBatchRunMax = 50;

enum BatchRunMode { staleAndNew, all }          // 只跑过期和没生成的 / 全部
enum BatchRunReason { neverGenerated, stale, rerun }
enum BatchSkipReason { pinned, disabled, missingFrame, generating }

@immutable class BatchRunDependency {            // 批内上游
  const BatchRunDependency({required this.upstreamId, required this.role});
  final String upstreamId; final EdgeRole role;
}

@immutable class BatchRunRow {
  final CanvasNode node;
  final BatchRunReason? reason;        // 要跑时非空
  final BatchSkipReason? skip;         // 跳过时非空；两者恰有一个
  final EdgeRole? missingRole;         // skip == missingFrame 时：firstFrame / lastFrame
  final List<BatchRunDependency> waitsFor; // 只在要跑时可能非空，按 upstream 在计划里的顺序
  final double? costUsd;               // 要跑时 = costOf(node)；跳过的恒为 null
  final bool canIncludeBack;           // 只有 skip == pinned 为 true
  bool get runs;
}

@immutable class BatchRunStep {                  // 给执行器
  final String nodeId; final Set<String> dependsOn; // dependsOn ⊆ 本计划的 steps
}

@immutable class BatchRunPlan {
  final List<BatchRunRow> rows;   // 先列要跑的（按运行顺序，最多 max 个），再列跳过的（按叙事链序）
  final List<BatchRunStep> steps; // 与 rows 里要跑的那几行一一对应、同序
  final int runCount;             // == steps.length
  final double knownCostUsd;      // 要跑且价格已知的之和
  final int unknownCostCount;     // 要跑但 costOf 返回 null 的个数
  final int overflowCount;        // 能跑但排在第 max 个之后的个数（「另 N 个不在本次」）
  bool get isEmpty;               // runCount == 0
}

BatchRunPlan planBatchRun({
  required List<CanvasNode> candidates,   // 入口给的节点（选中集 / 链上 / 组内）
  required List<CanvasNode> nodes,        // 画布全部节点（找上游、当前 take）
  required List<CanvasEdge> edges,
  required BatchRunMode mode,
  required bool includePinned,
  required Set<String> staleNodeIds,      // 当前 take 已过期的配置节点 id（调用方从 stale_takes_provider 取）
  Set<String> activeNodeIds = const <String>{}, // 已有非终态 job 的配置节点（调用方从 jobsRegistry 取）
  required double? Function(CanvasNode node) costOf, // 调用方包一层 estimateNodeCost；null = 价格未知
  int max = kBatchRunMax,
});
```
算法分五步，都在 `planBatchRun` 里，可以拆成私有函数：
1. 过滤：候选里 `isGenerableNode` 为假的直接丢掉，不列。复用 `node_menu_model.isGenerableNode`，只 import 不改。
2. 初判每个节点：
   - 停用 → `skip = disabled`。
   - 生成中 → `skip = generating`。
   - 已固定且没勾「包括已固定的」→ `skip = pinned`。已固定的判据：pinnedResultId 非空，并且 `currentResultFor` 返回的就是它。
   - 其余节点：没有当前 take 记 `neverGenerated`；在 staleNodeIds 里记 `stale`；都不是记 `rerun`。mode = staleAndNew 时，`rerun` 的不列。
3. 上游传播（只在 staleAndNew 下）：一个 `rerun` 的节点，只要有 data 入边的上游配置会跑，就改成 `stale` 加进来。重复到不再变化为止。
4. 缺帧检查：对要跑的 D，逐条看它首帧 / 尾帧角色的 data 入边。
   - 找上游配置：边的源是产物，上游配置 = 产物的 sourceNodeId；边的源是配置，上游配置就是它自己。
   - 上游配置这次会跑，就记一条依赖。
   - 上游配置不跑：源是产物，看产物的 imageUrl；源是配置，看 `currentResultFor(上游).imageUrl`。都没有图，就记 `skip = missingFrame` 和 `missingRole`。
   - 一个节点改成跳过，会让它的下游也缺帧，所以第 3、4 步交替重复，直到不再变化。参考图角色不判缺。
5. 排序：先用 `orderByNarrativeChain(nodes: nodes, edges: edges)` 给每个节点一个叙事序号，再做 Kahn 拓扑排序，入度同为 0 的按叙事序号排。
   - 排完还剩下的节点在环里：按叙事序号追加，环内的依赖从 dependsOn 里去掉。
   - 取前 max 个当 steps，剩下的计入 overflowCount；被截掉的行不进 rows。
   - 合计只算 steps 里的节点。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 没有提示词的配置节点、文本节点、镜头节点、产物节点：不进 rows。
2. 已停用的节点：一律 `skip = disabled`。includePinned、mode 都不影响它，`canIncludeBack == false`，不计入 runCount 和两项合计。
3. 已固定的节点：includePinned = false 时列 `skip = pinned`，两种 mode 都列，`canIncludeBack == true`。includePinned = true 时按第 2 步重新判，并且照常计价。
4. 固定指向的产物已经被删：按没固定处理（`currentResultFor` 已经回落到最新）。
5. mode = staleAndNew：只有 `neverGenerated`、`stale`（含第 3 步加进来的）这两种进 steps；最新的节点不列。mode = all：最新的也跑，记 `rerun`。
6. D 的首帧来自批内会跑的 U：D 的 waitsFor 含 (U, firstFrame)，`steps` 里 D 排在 U 后面，`D.dependsOn ∋ U`。
7. D 的首帧来自不跑的 U（不在候选里，或被跳过）：U 有当前图就照跑，D.dependsOn 不含 U；没有当前图就 `skip = missingFrame`、`missingRole = firstFrame`。尾帧同理。
8. 连锁缺帧：A 缺首帧被跳过，B 的首帧来自 A，B 也记 `missingFrame`（第 3、4 步交替重复）。
9. 参考图来自批内的 U：照样记依赖（等 U 跑完，好用新的 take）；来自批外、而且没有图的 U：不跳过。
10. 没有依赖的节点按叙事链序排；不在链上的排在后面，按位置 (dx, dy, id) 排，与 `orderByNarrativeChain` 的口径一致。
11. 同样的输入永远得到同样的 rows / steps（确定性），每个候选节点最多出现一次。
12. data 边成环：环里所有节点都进 steps，没有一个丢掉，dependsOn 里不含环内的边，函数会结束。
13. 能跑的 51 个：steps 取 50 个，`overflowCount == 1`；拓扑序保证任何一步的上游都在它前面，不会被截掉。
14. costOf 返回 null 的要跑节点：只加 `unknownCostCount`，不加进 `knownCostUsd`（不当 0 算）。跳过的行不调 costOf，也不计价。
15. activeNodeIds 里的节点：`skip = generating`，不计数。同一个节点重复出现在两个批次里，就靠这条挡住。
16. candidates 为空，或全部被滤掉：返回 `isEmpty == true`、rows 为空、所有计数为 0，不抛异常。
17. 纯函数：不读时钟，不读 provider，不分平台。撤销栈、mac / Windows 差异与本片无关（快捷键在 batch-run-dialog）。

## 新文案键（key · en · zh 表；没有写无）
无（纯函数，不出字；文案由 batch-run-dialog 按 `reason` / `skip` / `missingRole` 映射）。

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
`test/features/generation/services/batch_run_planner_test.dart`：手写 CanvasNode / CanvasEdge 构造器，`costOf` 用表驱动。先写这些用例，确认在空实现上是红的，再实现。
- `草稿和非配置节点不列`：没提示词的 image config、text、shot 都不在 rows 里。
- `已停用列跳过且不计价不能勾回`：includePinned = true、mode = all 时仍然是 `skip == disabled`、`canIncludeBack == false`，runCount 和 knownCostUsd 都不含它，costOf 一次都没对它调过（记录调用）。
- `已固定默认跳过可勾回`：includePinned = false 时 `skip == pinned`；改成 true 后进 steps，价格计入合计。
- `固定的产物被删按没固定处理`。
- `staleAndNew 不列最新的，all 列成 rerun`。
- `上游重跑带上最新的下游`：mode = staleAndNew，U 没生成过，D 最新、首帧来自 U 的产物 → D 在 steps 里，reason 为 stale，D.dependsOn = {U}。
- `批内上游排在前面`：叙事链序是 D、U，但 D 依赖 U → steps 为 [U, D]。
- `无依赖的按叙事链序`：三个节点位置打乱，链是 b→a→c → steps 为 [b, a, c]。
- `批外上游有当前 take 照跑`、`批外上游没有 take 记缺首帧`、`缺尾帧记 missingRole = lastFrame`、`缺参考图照跑`。
- `源是配置节点的首帧边`：上游配置在批内就记依赖；不在批内时看它的当前 take。
- `连锁缺帧`：A 缺首帧，B←A、C←B → 三个都跳过。
- `生成中跳过`。
- `成环不丢节点`：U↔D 互为首帧来源 → 两个都在 steps 里，函数会结束，dependsOn 不含彼此。
- `上限 50`：构造 53 个能跑的 → runCount 50、overflowCount 3、rows 里要跑的只有 50 行；`max: 2` 时同理。
- `价格未知单独计数`：两个 0.13、一个 null → knownCostUsd ≈ 0.26，unknownCostCount 1。
- `空输入返回空计划`。
- `确定性`：把候选顺序打乱跑两次，rows / steps 一样。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. 停用判断删掉（停用节点当普通节点）→ 「已停用列跳过…」红。
2. 停用改成和固定一样受 includePinned 控制 → 同上红。
3. includePinned 被忽略、固定的一律跳过 → 「已固定默认跳过可勾回」红。
4. 叙事序号改成按位置排 → 「无依赖的按叙事链序」红。
5. 去掉 Kahn 排序、只按叙事序 → 「批内上游排在前面」红。
6. 缺帧时不跳过（当成有图）→ 「批外上游没有 take 记缺首帧」红。
7. 去掉第 3、4 步的重复，只做一遍 → 「连锁缺帧」红。
8. 去掉第 3 步上游传播 → 「上游重跑带上最新的下游」红。
9. staleAndNew 也收 rerun → 「staleAndNew 不列最新的…」红。
10. `isGenerableNode` 过滤删掉 → 「草稿和非配置节点不列」红。
11. 价格 null 按 0 加进合计、不计 unknown → 「价格未知单独计数」红。
12. 截断用 `> max` 写成 `>= max`（或者 overflowCount 只算 1）→ 「上限 50」红。
13. 环检测删掉（剩下的节点丢弃）→ 「成环不丢节点」红。
14. activeNodeIds 不看 → 「生成中跳过」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test` 干净；`flutter test test/features/generation/services/` 全绿；上面 14 条变异逐条变红。
- 依赖方向：`batch_run_planner.dart` 不 import `stale_takes_provider`、`node_cost`、flutter_riverpod（grep 断言）。
- 非 UI 片，不截图。

## 风险与不确定
- 上游名字「以落地为准」：current-take 的 `currentResultFor` 签名和 pinnedResultId extension 的文件名、W8 的 `isDisabled`（`models/canvas_node_disabled.dart`）、W2 的 `estimateNodeCost`（这里只经 costOf 回调，不直接依赖签名）。
- 源是配置节点的 data 边（图像配置连到视频上当首帧，是连线模式现有的智能默认）：现在 `generation_controller._resolveRefImages` 读的是源节点自己的 `image_url`，配置节点上永远是空的，所以生成侧实际上拿不到这张首帧。本片按画板（「等 01 · 首帧」）把它算作依赖。生成侧要不要改，交给 batch-run-executor 核对 W5 落地后的代码，在那一片里收口。
- 模型不支持首帧却连了首帧边：生成侧会抛 `first_frame_unsupported`，本片不预判，到执行时变成「提交失败」。要不要在计划里提前标出来，画板没说，记作设计缺口。
- 第 3 步「上游重跑带上下游」是本片补的规则，主 Agent 若不认可，删掉第 3 步和对应的那条测试即可，不影响别的部分。
