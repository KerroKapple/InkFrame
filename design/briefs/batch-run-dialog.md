# batch-run-dialog · 运行对话框与全部入口
- 波次 W11 / lane A / 基底：origin/main（W0–W10 已合入）；依赖切片：batch-run-planner（W9）、job-eta（W9：`provider_eta_provider`）、batch-run-executor（W10：`batchRunControllerProvider`）、tc-stale-marks（W7：`stale_takes_provider`）、node-cost（W2：`estimateNodeCost`）、node-disabled-flag（W8）、esc-ladder（W0：快捷键注册表）、app-action-table（W1）、duration-format（W0）、canvas-capsule（W1）；阻塞决定：无。按画板建议：TakesCost Q5 → C（对话框里切，记住上次，首次默认「只跑过期和没生成的」）；ContextMenus W5 → A（多选时 Ctrl ↵ 生成全部能生成的）。

## 目标（用户看到什么变化，2–4 行）
要跑的节点有 2 个及以上时，先弹「运行」对话框：逐行列出节点、模型、价格、状态，底部写合计、预计耗时、并发、单次上限。点「运行 N 个」后整批交给执行器。
只要跑 1 个时，和现在一样直接提交。
入口有五个，都走这一个对话框：多选后按 Ctrl ↵（mac 上是 ⌘↵）、左栏大纲组头的「运行这组」、工具条「更多」里的「运行叙事链…」、⌘K、以及 W12 右键菜单的「生成 N 个」。前四个由本片接好，第五个本片只提供 `openBatchRunDialog`。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
`b2/project/TakesCost.dc.html`「花费预告 · 批量运行」（生成脚本 `b2_takes.js` 的 runDialog / runRow）：
- 对话框尺寸与布局：
  - 宽 452；标题栏 40，sequence 图标 + 「运行叙事链 · 画布 1」，右侧是分段切换「只跑过期和没生成的 | 全部」。
  - 行高 30，五列（18 | 1fr | 132 | 40 | 86）：序号、节点名、模型、价格、状态。跳过的行透明度 .5。
  - 列表下面一行：「包括已固定的」勾选框，右侧写「预计 4:10 · 并发 2 · 单次最多 50」。
  - 底部：「4 个 · 约 $2.63 · 另 1 个价格未知」+「取消」+ 琥珀色的「▶ 运行 4 个」。
- 状态颜色：「等 01 · 首帧」用首帧色（sky），「已过期」用 accent，跳过的用 fg5。
- 确认规则只在这张板定：要跑的 ≥ 2 个才弹，1 个照旧不弹；单次最多 50；超出的写「另 N 个不在本次」，按钮写「运行 50 个」。
- 入口表：多选 Ctrl ↵、右键「生成 N 个」、大纲组头「运行这组」、更多「运行叙事链」、⌘K。
- Q5 选 C：在对话框里切，记住上次，第一次默认 A。
- `b2/project/Selection.dc.html`：「生成 N 个」只数配置节点，停用的不算，一个都没有就不出；它和多选 Ctrl ↵ 都打开这个对话框。
- `b2/project/ContextMenus.dc.html` W5 A。
- `b2/project/GapsCanvas.dc.html`「更多」：顺序是导入 | 叙事链 | 模板 | 切线 | 视图；画布上没有链时，「整理叙事链」「运行叙事链…」置灰。
- 设计缺口：InkOverlayDialog 的标题栏只收 String，放不下分段切换。本片把切换放在正文第一行的右侧（高 32），标题栏照组件原样画 ✕ 和 Esc。
- 设计缺口：从选中集进来时，「只跑过期」要不要用记住的那一档，画板没说。本片定为：从选中集进来（Ctrl ↵、生成 N 个）一律默认「全部」，切了也不写回偏好；记住上次只对「运行叙事链」「运行这组」「⌘K」生效。理由：用户是点名选的，不该悄悄跳过。
- 设计缺口：没有要跑的节点时（都已是最新）的空态，画板没画。本片在正文写一行说明，「运行」按钮置灰。
- 设计缺口：大纲组头的「运行这组」长什么样，画板没画。本片用一个 run 图标键，悬停或获得焦点时显示，tooltip 写「运行这组」。
- 设计缺口：行首序号取什么，画板没说。本片取序列镜号（`sequenceShotNumbers`，两位数），不在链上的写「—」。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/widgets/batch_run_dialog.dart`（新建）：`BatchRunDialog`（ConsumerStatefulWidget，壳用 `InkOverlayDialog`），以及行、分段切换、勾选框这几个私有子部件。
- `lib/features/canvas/util/canvas_batch_run_actions.dart`（新建）：入口动作和纯判据（见「具体改动」）。
- Ctrl ↵ 所在的核心键文件（esc-ladder 拆注册表后的去处，以落地为准；拆分前就是 `lib/features/canvas/widgets/canvas_shortcuts.dart` 第 692–707 行的 `_generateSelection`）：把函数体换成调用 `generateSelection`，别的不动。
- `lib/features/canvas/widgets/canvas_toolbar.dart`：「更多」菜单（`_MoreAction`，第 34 行；`_showMoreMenu`，第 184 行起）加一项 `runChain`，放在导入那一组后面、叙事链那一组里；画布没有链时 `enabled: false`。
- `lib/features/canvas/widgets/left_rail/outline_panel.dart`：`_GroupHeader`（第 159 行）加一个可选回调 `onRun` 和 run 图标键；`_OutlinePanelState` 在组里有能生成的节点时才把回调传下去。
- `lib/core/models/app_preferences.dart`：加字段 `batchRunMode`（String，`'stale_and_new' | 'all'`，默认 `'stale_and_new'`），同步改构造、copyWith、toMap（键 `batch_run_mode`）、fromMap（容错，非法值回落默认）、==、hashCode。hashCode：W10 system-notifications 已按需改成 `Object.hashAll`，本片只往列表里追加字段；若届时仍是 `Object.hash` 且会超过 20 个参数，才由本片改。
- `lib/services/file_preferences_service.dart`：核对后多半不用改（序列化走 toMap / fromMap）。不改就不提交，只补一条往返测试。
- app-action-table 的 `lib/features/app_actions/app_action_catalog.dart`：追加一行「运行叙事链…」。如果 W1 要求 id 常量，在 `lib/features/app_actions/app_action_ids.dart` 追加一个常量（主 Agent 裁定：随 app_action_catalog 算注册表例外，只许追加这一行）。
- 测试：
  - `test/features/canvas/widgets/batch_run_dialog_test.dart`（新建）。
  - `test/features/canvas/util/canvas_batch_run_actions_test.dart`（新建）。
  - `test/features/canvas/widgets/canvas_node_shortcuts_test.dart`（改写第 266 行那条「选中两张…不提交」）。
  - `test/features/canvas/widgets/left_rail/outline_panel_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`（各追加用例）。
  - `test/core/models/app_preferences_test.dart`、`test/services/file_preferences_service_test.dart`（各追加用例）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- node-menu-append-chain / result-inspector-align：新 `util/append_to_chain.dart`、`util/canvas_append_chain_actions.dart`、`canvas_menu/append_chain_menu_entries.dart`、`widgets/canvas_inspector_panel.dart`、`widgets/result_inspector_parts.dart`、`widgets/video_result_inspector.dart`、`widgets/image_result_inspector.dart`、`lib/theme/icons/ink_glyph.dart`（本片只用现有的 `InkGlyph.run` / `InkGlyph.sequence`，不加图标）。
- script-import：`lib/features/storyboard/providers/script_import_controller.dart`、`util/script_splitter.dart`、`widgets/script_import_dialog.dart`、`util/duration_estimate.dart`。
- mention-token-core：`lib/features/generation/generation_controller.dart`、`lib/services/import/import_remapper.dart`、`util/clipboard_snapshot.dart`、`lib/features/generation/services/prompt_assembler.dart`、新 `lib/core/text/character_mention.dart`。
- f6-notification-region：`lib/features/notifications/widgets/toast_layer.dart`、`notification_bell.dart`、`providers/toast_center.dart`、`lib/theme/components/ink_toast_card.dart`、`lib/features/settings/util/shortcut_catalog.dart`。
- 全波禁区：
  - `util/canvas_tool_actions.dart`（`generateNode` 只调用，不改）、`util/node_menu_model.dart`（`isGenerableNode` / `generationTarget` 只调用）、`canvas_menu/node_menu_entries.dart`。
  - 快捷键注册表除本片那一个核心键文件之外的内容。
  - `lib/theme/components/ink_overlay_dialog.dart`（不改组件）。
  - W9 / W10 的 `batch_run_planner.dart`、`batch_run_controller.dart`、`provider_eta_provider.dart`、`shell_task_popover.dart`、`shell_task_capsule.dart`。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：f6-notification-region：`lib/features/settings/widgets/shortcuts_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/canvas_batch_run_actions.dart
enum BatchRunSource { selection, chain, group }

sealed class BatchEntryDecision { const BatchEntryDecision(); }
class BatchEntryNone extends BatchEntryDecision {}
class BatchEntrySingle extends BatchEntryDecision { final String nodeId; }
class BatchEntryDialog extends BatchEntryDecision { final List<String> candidateIds; }

/// 选中集入口：能生成的恰好 1 个（停不停用都算）→ Single；能生成且没停用的 ≥ 2 → Dialog；
/// 只有 1 个没停用 → Single(它)；否则 None。
BatchEntryDecision decideSelectionEntry(List<CanvasNode> selected);
/// 链 / 组入口：能生成的 ≥ 2 → Dialog（停用的也列进去，由 planner 标跳过）；== 1 → Single；0 → None。
BatchEntryDecision decideGroupEntry(List<CanvasNode> candidates);

List<CanvasNode> narrativeChainCandidates(List<CanvasNode> nodes, List<CanvasEdge> edges); // narrativeChainMembers ∩ isGenerableNode，按链序
bool canRunNarrativeChain(List<CanvasNode> nodes, List<CanvasEdge> edges);               // narrativeChainMembers 非空

/// 预计耗时：按 steps 顺序贪心排到 concurrency 个槽里，下游最早在所有上游结束后开工；
/// etaOf 返回 null 的步骤按 0 算；所有步骤都是 null 时返回 null（显示「—」）。
int? estimateBatchEtaMs({required List<BatchRunStep> steps, required Map<String, CanvasNode> byId,
    required int? Function(CanvasNode node) etaOf, required int concurrency});

Future<void> generateSelection(BuildContext context, WidgetRef ref, {required String canvasId, required Set<String> selected});
Future<void> runNarrativeChain(BuildContext context, WidgetRef ref, {required String canvasId});
Future<void> runOutlineGroup(BuildContext context, WidgetRef ref, {required String canvasId, required OutlineGroup group});
/// W12 cm-multi-select-menu、W13 selection-toolbar 从这里接。
Future<void> openBatchRunDialog(BuildContext context, WidgetRef ref, {required String canvasId,
    required BatchRunSource source, required List<String> candidateIds, String? title});

// widgets/batch_run_dialog.dart
class BatchRunDialog extends ConsumerStatefulWidget {
  const BatchRunDialog({super.key, required this.canvasId, required this.source, required this.candidateIds, required this.title});
  static const Key runKey, cancelKey, modeStaleKey, modeAllKey, includePinnedKey, footerKey;
  static Key rowKey(String nodeId);
}
```
- 对话框状态：`mode`（初值：source == selection 时取 `all`，否则取 `AppPreferences.batchRunMode`）和 `includePinned`（初值 false，不记住）。
- 对话框每次 build 都重算计划：`planBatchRun(candidates, nodes, edges, mode, includePinned, staleNodeIds, activeNodeIds, costOf)`。
  - candidates：用 candidateIds 去 watch 节点控制器拿。
  - staleNodeIds：取 `stale_takes_provider`（以落地为准）。
  - activeNodeIds：取 `jobsRegistryProvider` 里没到终态的 sourceNodeId。
  - costOf：包一层 `estimateNodeCost`，把它的 `usd?` 交出来。
- 预计耗时：etaOf 包一层 `provider_eta_provider`（以落地为准）。并发取 `kDefaultGlobalConcurrency`，与任务弹层同一来源。时长用 `formatDurationLabel(l, ms)`。
- 点「运行」：
  1. 先关对话框。
  2. 对每个要跑的 id：`ref.exists(inspectorSubmitControllerProvider(id))`，而且 `hasPendingWrites` 为真，就 await `flushPendingWrites()`。
  3. 再 `ref.read(batchRunControllerProvider.notifier).start(canvasId: …, steps: plan.steps)`。
- 状态列取字的优先级：跳过原因 > 等上游（取第一条依赖的镜号和角色）> 价格未知 > 已过期 > 没生成过 > 重新生成。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. Ctrl ↵（Windows / Linux）和 ⌘↵（macOS）都绑在同一个 Intent 上。
   - 选中 1 张能生成的：和现在一样直接 `generateNode`，不弹框。
   - 选中 ≥ 2 张能生成且没停用的：弹框。
   - 选中的都不能生成：什么都不做。
2. 选中 2 张能生成的，其中 1 张停用：只剩 1 张能跑，直接提交那张，不弹框。只选中 1 张停用的：照常生成。停用只在批量里跳过（ContextMenus W2 A）。
3. 打字时让位不变：提示词条或检查器里有文字焦点时，Ctrl ↵ 归文本框（提示词条自己的 ⌘↵ 仍然只提交一次）。
4. 链 / 组入口：能生成的 ≥ 2 个就弹框，不论 mode 下能跑几个。只有 1 个就直接提交。一个都没有就出画布胶囊「这里没有能生成的节点」，不弹框。
5. 第一次打开链 / 组入口时，mode 是「只跑过期和没生成的」。用户切到「全部」后立刻写回偏好；下次打开链 / 组入口就是「全部」。
6. 从选中集进来，mode 恒为「全部」。切了也不写偏好（断言 PreferencesService.update 没被调用）。
7. 「包括已固定的」：勾上后，跳过 · 已固定的那些行变成要跑，合计跟着变。关掉对话框不记住。
8. 已停用的行一直写「跳过 · 已停用」，透明度 .5，点不了，也没有任何勾选能把它带回来。
9. 超过 50 个：按钮写「运行 50 个」，底部多一行「另 N 个不在本次」。
10. 合计：「N 个 · 约 $x」；有价格未知的，再加「 · 另 K 个价格未知」；全部都价格未知时写「N 个 · 价格未知」。
11. 空态：要跑的是 0 个（比如都是最新的）时，列表上方写空态说明，「运行」置灰，↵ 也无效。
12. 对话框开着时，数据有变（某张卡开始生成、有 job 完成、过期标记变了），行和合计实时更新。生成中的节点写「生成中 · 跳过」。
13. 键盘：↵ = 运行（按钮可用时），Esc = 取消（走 InkOverlayDialog 和路由本身的关闭）。对话框开着时，画布快捷键不抢焦点（沿用「所在路由上面压着对话框」的判据）。
14. 点「取消」、按 Esc、点遮罩关闭：什么都不提交，偏好只保留已经切过的 mode。
15. 运行之前，先冲掉那几个节点挂起的防抖编辑，再交给执行器；一次 start 只建一个批次（runGroup）。连按两次「运行」只会 start 一次，因为第一次已经把对话框关了。
16. 「更多 › 运行叙事链…」：画布上没有叙事链时置灰。⌘K 的同名动作同一判据：置灰，写原因「画布上还没有叙事链」。
17. 大纲组头的 run 键：组里没有能生成的节点时不画。点了等于对这一组的节点走 `runOutlineGroup`，标题「运行这组 · <组名>」。「未入链」组也有这个键。
18. 撤销栈：批量运行不进撤销栈（生成本来就不进），对话框不碰历史。
19. mac 和 Windows 的区别只在键位显示：「运行」按钮的 tooltip 用 `formatShortcutActivator` 按平台出「⌘↵」或「Ctrl ↵」。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| batchRunTitleChain | Run narrative chain · {canvas} | 运行叙事链 · {canvas} |
| batchRunTitleGroup | Run group · {group} | 运行这组 · {group} |
| batchRunTitleSelection | Generate {count} | 生成 {count} 个 |
| batchRunModeStaleAndNew | Stale and never generated | 只跑过期和没生成的 |
| batchRunModeAll | All | 全部 |
| batchRunIncludePinned | Include pinned | 包括已固定的 |
| batchRunStatusNeverGenerated | Never generated | 没生成过 |
| batchRunStatusStale | Stale | 已过期 |
| batchRunStatusRerun | Regenerate | 重新生成 |
| batchRunStatusWaitsFirstFrame | Waits for {shot} · first frame | 等 {shot} · 首帧 |
| batchRunStatusWaitsLastFrame | Waits for {shot} · last frame | 等 {shot} · 尾帧 |
| batchRunStatusWaitsReference | Waits for {shot} · reference | 等 {shot} · 参考 |
| batchRunStatusPriceUnknown | Price unknown | 价格未知 |
| batchRunSkipPinned | Skipped · pinned | 跳过 · 已固定 |
| batchRunSkipDisabled | Skipped · disabled | 跳过 · 已停用 |
| batchRunSkipMissingFirstFrame | No first frame · skipped | 缺首帧 · 跳过 |
| batchRunSkipMissingLastFrame | No last frame · skipped | 缺尾帧 · 跳过 |
| batchRunSkipGenerating | Generating · skipped | 生成中 · 跳过 |
| batchRunModelBatch | {provider} × {count} | {provider} × {count} 张 |
| batchRunModelVideo | {provider} {seconds}s {resolution} | {provider} {seconds} 秒 {resolution} |
| batchRunTotal | {count} · about {cost} | {count} 个 · 约 {cost} |
| batchRunTotalAllUnknown | {count} · price unknown | {count} 个 · 价格未知 |
| batchRunUnknownPriced | {count} more with unknown price | 另 {count} 个价格未知 |
| batchRunOverflow | {count} more not in this run | 另 {count} 个不在本次 |
| batchRunMeta | Est. {eta} · concurrency {n} · max {max} per run | 预计 {eta} · 并发 {n} · 单次最多 {max} |
| batchRunRun | Run {count} | 运行 {count} 个 |
| batchRunEmpty | Nothing to run — everything is up to date. Switch to All to regenerate. | 没有要跑的：都已是最新。切到「全部」可以重跑。 |
| batchRunNothingGenerable | Nothing here can be generated | 这里没有能生成的节点 |
| batchRunGroupAction | Run this group | 运行这组 |
| canvasMoreRunChain | Run narrative chain… | 运行叙事链… |
| batchRunNoChainReason | No narrative chain on this canvas yet | 画布上还没有叙事链 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
`test/features/canvas/util/canvas_batch_run_actions_test.dart`（纯函数）：
- `选中集：1 张直接提交`、`2 张能生成的弹框`、`2 张里 1 张停用直接提交另一张`、`只选 1 张停用的照常 Single`、`都不能生成 None`。
- `链 / 组：≥2 弹框（含停用）`、`==1 Single`、`0 None`。
- `narrativeChainCandidates 只取链上能生成的，按链序`、`canRunNarrativeChain 没有叙事边为假`。
- `estimateBatchEtaMs`：并发 2、三个各 60 s、没有依赖 → 120 s；D 依赖 U → U + D 串行；全部为 null → null；部分为 null 按 0 算。

`test/features/canvas/widgets/batch_run_dialog_test.dart`（ProviderScope，override 节点 / 边控制器、stale、eta、preferencesServiceProvider 用 InMemory、batchRunControllerProvider 用记录 start 的 fake）：
- `逐行渲染画板六行`：用 TakesCost 那六行的数据，断言各行状态字、价格「—」、跳过行透明度 .5。
- `合计与价格未知`：「4 个 · 约 $2.63 · 另 1 个价格未知」。
- `包括已固定的会改合计`。
- `已停用勾不回`：勾上「包括已固定的」以后，停用那一行仍然写「跳过 · 已停用」。
- `超过 50 个`：按钮写「运行 50 个」，底部出「另 3 个不在本次」。
- `首次默认只跑过期，切到全部写回偏好`、`从选中集进来默认全部且不写偏好`。
- `空态置灰运行`。
- `运行：先冲刷挂起编辑再 start`：给一个节点制造挂起的防抖编辑 → 断言先看到 flushPendingWrites、后看到 start；start 收到的 steps 等于计划的 steps。
- `Esc / 取消不提交`。

`test/features/canvas/widgets/canvas_node_shortcuts_test.dart`：
- 改写原来的「选中两张 / 选中的不能生成：不提交」：拆成「选中两张能生成的：开对话框，不直接提交」和「选中的不能生成：不提交」。
- 新增「macOS 上 ⌘↵ 同样开对话框」（debugDefaultTargetPlatformOverride = macOS）。
- 原来的「提示词条里 Ctrl+↵ 只提交一次」不改，仍要绿。

其余追加用例：
- `outline_panel_test.dart`：`组里有能生成的节点才出运行键`；`点运行键开对话框，标题是这一组`。
- `canvas_toolbar_test.dart`：`更多菜单有运行叙事链`；`没有链时置灰`。
- `app_preferences_test.dart`：`batchRunMode 默认 stale_and_new`；`非法值回落默认`；`toMap / fromMap 往返`；`copyWith 改它会让 == 和 hashCode 都变`。
- `file_preferences_service_test.dart`：`batch_run_mode 落盘往返`。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. 核心键文件改回 `generationTarget` 分支 → 「选中两张能生成的：开对话框」红。
2. `decideSelectionEntry` 的 `>= 2` 改成 `> 2` → 「2 张能生成的弹框」红。
3. 改成 `>= 1` 就弹框 → 「1 张直接提交」红。
4. 选中集入口不排除停用 → 「2 张里 1 张停用直接提交另一张」红。
5. 选中集入口也读 / 写偏好 → 「从选中集进来默认全部且不写偏好」红。
6. 切换 mode 后不调 PreferencesService.update → 「切到全部写回偏好」红。
7. fromMap 默认值改成 `'all'` → 「batchRunMode 默认 stale_and_new」红。
8. 运行时不冲刷挂起编辑 → 「先冲刷挂起编辑再 start」红。
9. 合计里漏掉「另 K 个价格未知」→ 「合计与价格未知」红。
10. 按钮数字用 candidates.length，而不是 runCount → 「超过 50 个」红。
11. 空态时运行按钮仍可点 → 「空态置灰运行」红。
12. `canRunNarrativeChain` 恒为真 → 「没有链时置灰」红。
13. 去掉 `_EditingAwareAction`（Ctrl ↵ 不再对文本让位）→ 原来的「提示词条里只提交一次」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test` 干净；`test/features/canvas/`、`test/core/models/`、`test/services/` 全绿；上面 13 条变异逐条变红。
- 验收要点：选 1 张直接提交，选 ≥ 2 张弹框，单次上限 50。
- 截图（BatchRunDialog，ProviderScope 塞 TakesCost 板上的六行数据，深色主题）：
  - ① 默认态（只跑过期，「包括已固定的」没勾）。
  - ② 勾上「包括已固定的」。
  - ③ 切到「全部」。
  - ④ 空态。
  - ⑤ 53 个节点的超限态（底部「另 3 个不在本次」）。
  - 另外截：左栏大纲组头悬停时的 run 键；「更多」菜单的有链态和无链态。

## 风险与不确定
- Ctrl ↵ 核心键文件的真名和位置取决于 esc-ladder 的落地，以落地为准。本片只替换 `_generateSelection` 的函数体。
- app_preferences 每一波最多给一片：W10 system-notifications 刚加过字段，本片要 rebase 在它后面。hashCode 参数个数很可能已经超过 20（W6 snapping 也加过字段），要用 `Object.hashAll`。
- `app_action_ids.dart`：主 Agent 已裁定随 app_action_catalog 算注册表例外，只追加一个常量。
- 冲刷挂起编辑用的是 `flushPendingWrites()`，B8 那个顾虑仍在：这一笔写失败会按「已用尽」记账，那个节点读到的就是库里的旧提示词。好在多选状态下一般没有挂起编辑（防抖只在单选时的提示词条里有）。要彻底解决，就得给 InspectorSubmitController 加一个「只落盘不提交」的口，那个文件这一波不归本片。
- 「更多」菜单在 W18 才改成画布菜单组件。本片沿用 `showMenu` 的 PopupMenuItem，置灰的项没法挂原因 tooltip；原因只在 ⌘K 那一行出。
- 标题栏放不下分段切换，已在设计依据里写成设计缺口；如果要严格照画板，得改 InkOverlayDialog，加一个 `titleTrailing` 插槽（theme 层，这一波没有切片拥有它）。
