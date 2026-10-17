# multi-select-inspector · 多选检查器
- 波次 W9 / lane D / 基底：origin/main（W0–W8 已合入）；依赖切片：node-cost（W2，estimateNodeCost）、nodes-batch-ops（W1，patchTypeConfigMany）、undo-stack（W0）、undo-params（W5，PatchTypeConfigCommand / 组合命令）、multi-select-core（W0）、node-disabled-flag（W8，isDisabled）；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
选中 2 个及以上节点时，右侧检查器不再是「选中一个节点以编辑参数」，而是：已选 N 个节点 + 各类型计数 + 总预估（另 N 个价格未知）+ 逐个节点的清单与单价。
全部是同一类型的配置节点（图像 / 视频 / 镜头）时多一组「共有参数 · 改一处写全部」：值不一样的写「多个值」；改一处 = 一个事务写全部、Ctrl Z 一步撤回；换成同一个模型时按它的能力重算其余字段、清掉不支持的并就地提示。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/Selection.dc.html` ›「多选检查器」（数量 + 总价 + 共有参数）：mock = 「已选 3 个节点 / 视频配置 ×3 / 总预估 约 $2.10 / 共有参数 · 改一处写全部：模型 万相 2.2 · 图生视频、时长 多个值、画幅 16:9、种子 多个值 / 提示词、首尾帧、参考图、角色各自单独改 / 清单：镜头 02 · 江上孤舟 $0.70 … / 生成 3 个 · 约 $2.10」。规则：同类型配置节点才列共有参数，混选只列数量、总价、清单；值不一样写「多个值」，不碰不写，改一次写全部；换成同一模型后按能力位重算其余字段，不支持的清掉并提示；总价 = 各节点相加（USD，formatCostUsd），算不出写「另 N 个价格未知」；生成按钮走 TakesCost 运行对话框；文本、便签、产物只计数。
- `b2/project/TakesCost.dc.html` 运行对话框：停用的「跳过 · 已停用」不计价（多选检查器的总价与它同口径）。
- slices.json `multi-select-inspector` notes：能力位重算复用 image / video config inspector 的判据，抽成共享函数；对话框没落地前生成按钮先隐藏。
- 设计缺口：mock 里视频配置有「画幅 / 种子」，但现在的单选视频检查器（`video_config_inspector.dart` 头注第 10 行）不画画幅，也不画种子。本片按单选检查器现有字段走：图像 = 模型 / 画幅 / 种子，视频 = 模型 / 时长，镜头 = 时长；视频的画幅 / 种子等单选检查器补上后再加。
- 设计缺口：清单行能不能点（跳到那张卡）、停用节点在清单和总价里怎么显示——板没画。本片定：清单行只读不可点；停用节点行尾写「已停用」、不计入总价也不计入「价格未知」。
- 设计缺口：多选时「历史」页签显示什么——板没画。本片定：沿用现有空态那一句。
- 设计缺口：有节点正在生成时能不能改共有参数——板没画。本片定：任一目标有活动 job 时共有参数整组置灰，并写一句原因。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/widgets/canvas_inspector_panel.dart`：`build` 里 `selected.length > 1` 且属性页时渲染 `MultiSelectInspector`（第 53–90 行一带）；历史页与单选逻辑不变；`_NodeSummary` 不动。
- `lib/features/canvas/widgets/multi_select_inspector.dart`（新）：头部（数量 + 类型计数）、总预估、共有参数组、「各自单独改」说明、清单。
- `lib/features/canvas/util/multi_select_params.dart`（新，纯函数）：选区分类、共有值求交（「多个值」）、选项求交、总价求和与未知计数、每个字段的写入 patch。
- `lib/features/canvas/util/provider_capability_fields.dart`（新，纯函数）：从两个配置检查器抽出的能力位判据 + 换模型重算 `providerSwitchPatch`。
- `lib/features/canvas/providers/multi_select_patch_controller.dart`（新）：冲挂起写入 → 算 patch → 一次 `patchTypeConfigMany` → 推一步撤销；返回被调整的字段供提示。
- `lib/features/canvas/widgets/image_config_inspector.dart`：只把 `initState`（第 93–131 行）的钳制、`_selectedCaps`（第 158–164 行）、批量 / 种子 / 负向的显示条件改成调用共享函数；provider 下拉 `onChanged`（第 221–247 行）的「重置到第一个」行为不变。
- `lib/features/canvas/widgets/video_config_inspector.dart`：同上，只改 `initState`（第 54–80 行）的时长钳制与 `_selectedCaps`（第 88–94 行）。
- （行号为 f64f56e；W2 node-cost、W5 undo-params 改过这两个文件，以落地为准。）

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- canvas-find-bar：`widgets/canvas_screen.dart`、`widgets/node_card_slot.dart`、`widgets/node_card.dart`、`util/escape_ladder.dart`、`util/canvas_find_model.dart`、`providers/canvas_find_controller.dart`、`widgets/canvas_find_bar.dart`、`shortcuts/find_keys.dart`。
- batch-run-planner → job-eta：`lib/features/generation/services/batch_run_planner.dart`、`lib/storage/repositories/postgres_job_repository.dart`、`lib/core/interfaces/job_duration_history.dart`、`lib/core/di/job_duration_history.dart`、`lib/features/generation/providers/provider_eta_provider.dart`。
- dep-drop-pasteboard → os-drop-paste-image：`pubspec.yaml`、`pubspec.lock`、平台插件注册文件、`widgets/canvas_view.dart`、`widgets/os_file_drop_overlay.dart`、`util/import_drop_summary.dart`、`util/canvas_import_drop_actions.dart`、`widgets/shortcuts/clipboard_keys.dart`、`util/canvas_paste_actions.dart`、剪贴板图片的 interface / service / di。
- rail-drag-characters → outline-rename-menu：`widgets/character_library_panel.dart`、`util/canvas_character_drop_actions.dart`、`util/ref_image_budget.dart`、`widgets/left_rail/outline_panel.dart`、`providers/canvas_nodes_controller.dart`、`models/canvas_command.dart`（W9 只归 outline-rename-menu）。
- 全波禁区：`util/canvas_tool_actions.dart`、`util/node_menu_model.dart`（`generationTarget` 不改，TakesCost 片的事）、`canvas_menu/node_menu_entries.dart`、`canvas_menu/blank_menu_entries.dart`、`widgets/canvas_shortcuts.dart`、`lib/features/generation/services/node_cost.dart` 与 `cost_estimator.dart`（只读调用）、`widgets/shot_config_inspector.dart`（只读 `kShotDurationOptions`）、`widgets/characters_section.dart`、`widgets/node_inputs_section.dart`、`providers/inspector_submit_controller.dart`、`util/generate_gate.dart`（只读调用）。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/provider_capability_fields.dart —— 单选检查器与多选检查器的唯一判据
ProviderCapabilities? selectedCapsOf(String? providerId, List<ProviderCapabilities> all); // 原 _selectedCaps：找不到回落 all.first
Resolution? initialResolution(Object? saved, ProviderCapabilities? caps);   // 现状口径：saved ?? 第一个（不校验 saved）
AspectRatio? initialAspect(Object? saved, ProviderCapabilities? caps);      // saved 在支持集里 ? saved : 第一个 / null
int initialBatch(Object? saved, ProviderCapabilities? caps);                // 1..maxBatchSize 之外 ⇒ 1
int? initialDurationSec(Object? savedMs, ProviderCapabilities? caps);       // 在 supportedDurations 里 ? saved : 第一个 / null
bool showsBatch(ProviderCapabilities? c); bool showsSeed(ProviderCapabilities? c); bool showsNegativePrompt(ProviderCapabilities? c); bool showsAspect(ProviderCapabilities? c);
enum CapabilityField { resolution, aspectRatio, seed, negativePrompt, batchSize, duration }
/// 换成 [next] 后这一个节点要写的 patch：provider_id + 支持集外的分辨率 / 画幅 / 时长改成第一个、
/// 不支持的 seed / negative_prompt 写 null、batch_size 超限写 1；cleared = 真被改动的字段。
({Map<String, Object?> patch, Set<CapabilityField> cleared}) providerSwitchPatch({required CanvasNodeType type, required Map<String, Object?> typeConfig, required ProviderCapabilities next});

// util/multi_select_params.dart
enum MultiSelectKind { image, video, shot, mixed }           // 全是同一 type 的 config 且 type ∈ {image, video, shot} 才不是 mixed
sealed class SharedValue<T> {}  final class Same<T> extends SharedValue<T> { final T? value; }  final class Mixed<T> extends SharedValue<T> {}
enum MultiSelectField { provider, aspectRatio, seed, durationSec }
MultiSelectKind multiSelectKindOf(List<CanvasNode> nodes);
List<MultiSelectField> fieldsFor(MultiSelectKind kind, {required List<ProviderCapabilities> effectiveCaps}); // 图像：provider + (全部 showsAspect 才有) aspect + (全部 showsSeed 才有) seed；视频：provider + duration；镜头：duration；mixed：空
SharedValue<Object> sharedValueOf(MultiSelectField f, List<CanvasNode> nodes, {required String? lastUsedProviderId, required List<ProviderCapabilities> caps}); // 有效值 = 单选检查器 initState 的同一默认链
List<Object> optionsFor(MultiSelectField f, List<CanvasNode> nodes, {required List<ProviderCapabilities> caps}); // 各节点有效 provider 支持集的交集；镜头时长 = kShotDurationOptions + 未设置
typedef MultiSelectCost = ({double usdSum, int unknownCount, int pricedCount});
MultiSelectCost sumCosts(List<CanvasNode> nodes, double? Function(CanvasNode) usdOf); // 只计未停用的 image / video config；usdOf 返回 null ⇒ unknown
Map<String, Map<String, Object?>> patchesFor(MultiSelectField f, Object? value, List<CanvasNode> nodes, {required List<ProviderCapabilities> caps}); // 值已相同的节点不进 map

// providers/multi_select_patch_controller.dart
sealed class MultiSelectPatchState {}  // Idle / Saving / Failed(InkError) / Adjusted(modelName, Set<CapabilityField>)
final multiSelectPatchControllerProvider = /* AutoDisposeNotifierProviderFamily<MultiSelectPatchController, MultiSelectPatchState, String canvasId> */;
class MultiSelectPatchController { Future<void> apply(Set<String> nodeIds, MultiSelectField field, Object? value); }

// widgets/multi_select_inspector.dart
class MultiSelectInspector extends ConsumerWidget { const MultiSelectInspector({super.key, required this.canvasId, required this.nodeIds}); }
```
- 单价：`estimateNodeCost(node, …)`（node-cost 落地签名为准）的 `usd`；格式 `formatCostUsd`；总价前缀「约」。
- `apply` 流程：`pendingWriteRegistryProvider` 先 flush → 以当前节点表过滤掉已不存在的 id → `patchesFor` → 空则什么都不做 → `CanvasNodesController.patchTypeConfigMany(patches)` 一个事务 → 成功推一条 PatchTypeConfigCommand（多节点或 W5 组合命令，记每个节点每个键的旧值，原来没有的键撤销时删掉）→ 换模型时同步 `preferencesService.update(lastImageProviderId / lastVideoProviderId)`（与单选同）→ state = Adjusted（有 cleared 时）。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 选中 ≥ 2 且在「属性」页 ⇒ 渲染多选检查器；= 1 走原单选路径；= 0 原空态；「历史」页多选仍是原空态。
2. 头部：「已选 N 个节点」；下面按类型计数，如「视频配置 ×3」「图像配置 ×1 · 文本 ×2 · 产物 ×1」。
3. 共有参数组只在 `multiSelectKindOf != mixed` 时出现；mixed（含文本、产物，或图像 + 视频混选）只有头部、总价、清单。
4. 共有值：各节点有效值全相同 ⇒ 显示该值；有不同 ⇒「多个值」（下拉 hint / 输入框 hint）。有效值按单选检查器的默认链取（节点已存 > 上次使用 > 第一个），所以没存 provider 的节点与单选看到的一致。
5. 不碰不写：只打开下拉、不选或选回「多个值」占位 ⇒ 不写库；种子框只聚焦后失焦、文字没变 ⇒ 不写。
6. 改一处：选一个值 ⇒ 只给值不同的节点写，一次 `patchTypeConfigMany`（一个事务）+ 一步撤销；Ctrl Z 全部回各自的旧值，Ctrl Y 再统一。
7. 换模型：对每个节点按新模型的能力位重算（分辨率 / 画幅 / 时长不在支持集 ⇒ 第一个；不支持种子 / 负向 ⇒ 清掉；批量超限 ⇒ 1），与 provider_id 同一事务、同一步撤销；有被调整的字段 ⇒ 模型行下方一行「已按「X」的能力调整：种子、负向提示词」，选区变化后消失。
8. 选项求交：画幅 / 时长的选项是各节点有效模型支持集的交集；交集为空 ⇒ 该行不出现；种子行只在全部有效模型都支持种子时出现。
9. 种子：输入整数 ↵ 或失焦写入全部；清空 ⇒ 全部写 null（= 随机）；非整数 ⇒ 不写、恢复原显示。
10. 总价：未停用的 image / video 配置节点单价相加，显示「约 $x」；单价算不出（`usd == null`）的数进「另 N 个价格未知」；全部未知 ⇒ 只显示「—」+「另 N 个价格未知」；镜头 / 文本 / 产物不计价也不计未知。
11. 清单：每个节点一行「名称 · 单价」，名称用 `nodeDisplayName`；停用节点行尾「已停用」；不可计价的类型不写价格；只读不可点。
12. 忙：任一目标有活动 job（`nodeActiveJobProvider` 非空）⇒ 共有参数整组置灰 + 一句「有节点正在生成，生成完再改」；job 结束自动恢复。
13. 写库失败：控制器整批回滚（W1 规则），显示回原值；弹错误卡「批量修改失败」；不推撤销步。
14. 并发：写入进行中控件置灰（Saving）；写入期间选区变化 ⇒ 写入照常完成（用发起时的 id），「已调整」提示只在选区未变时显示；目标节点在写入前被删 ⇒ 跳过，全被删 ⇒ 不写不推。
15. 撤销前冲挂起写入（W0 规则）；本片发起写入前也先 flush，避免单选时没落盘的防抖 patch 盖掉批量值。
16. 底部「生成 N 个」按钮本片不画（TakesCost 运行对话框 W11 才有）；留一个 `MultiSelectInspector.generateSlot` 注释位，不出任何 UI。
17. 单选图像 / 视频检查器行为零变化：初始钳制、显示条件、换模型「重置到第一个」与改前一致（现有测试不改即绿）。
18. mac / Windows 无差异；检查器宽 301 不变，长名称单行省略。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| multiSelectTitle | {count} nodes selected | 已选 {count} 个节点 |
| multiSelectTypeCount | {type} ×{count} | {type} ×{count} |
| multiSelectTotalEstimate | Total estimate | 总预估 |
| costApproxUsd | ≈ {amount} | 约 {amount} |
| costUnknownMore | {count} more without a price | 另 {count} 个价格未知 |
| multiSelectSharedParams | Shared · one change writes all | 共有参数 · 改一处写全部 |
| multiSelectMixedValue | Multiple values | 多个值 |
| multiSelectEditSeparately | Prompts, first / last frames, references and characters are edited one by one | 提示词、首尾帧、参考图、角色各自单独改 |
| multiSelectAdjusted | Adjusted for "{model}": {fields} | 已按「{model}」的能力调整：{fields} |
| multiSelectBusy | Some nodes are generating — edit after they finish | 有节点正在生成，生成完再改 |
| multiSelectSaveFailed | Couldn't update the selected nodes | 批量修改失败 |
| multiSelectResultType | Result | 产物 |
（`costApproxUsd` / `costUnknownMore`：若 node-cost（W2）已落地同义键，复用其键名，不新增；W11 运行对话框与 W12 多选菜单复用同一键。类型名复用 `leftRailTypeImageConfig` / `leftRailTypeVideoConfig` / `nodeTypeLabel`；字段名复用 `inspectorSeedLabel` 等现有键；「已停用」复用 W8 的 `nodeStatusDisabled`。）

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/provider_capability_fields_test.dart`（新）
  - `initialAspect：支持集里保留、否则第一个、空集 null`；`initialResolution 保留现状口径（saved 不校验）`；`initialBatch 超限回 1`；`initialDurationSec 不支持回第一个`；`selectedCapsOf 找不到回落第一个`。
  - `providerSwitchPatch：新模型不支持种子 → seed:null 且 cleared 含 seed`；`不支持负向 → negative_prompt:null`；`画幅支持则保留、不支持改第一个并记 cleared`；`批量 4 → 新模型 max 1 → batch_size:1`；`视频时长不支持改第一个`；`全支持 → cleared 空、patch 只有 provider_id`。
- `test/features/canvas/util/multi_select_params_test.dart`（新）
  - `kind：3 个视频 config → video；视频 + 图像 → mixed；含文本 / 产物 → mixed；3 个镜头 → shot`。
  - `sharedValue：值全同 → Same；有不同 → Mixed；没存 provider 的按上次使用补`。
  - `fieldsFor：图像全支持种子才有种子行；视频只有模型 + 时长；mixed 空`。
  - `optionsFor 画幅取交集；交集空 → 不出行`。
  - `sumCosts：两个 $0.70 + 一个 null → usdSum 1.40、unknown 1`；`停用节点不计价不计未知`；`文本 / 产物不计未知`。
  - `patchesFor 跳过值已相同的节点`；`换模型 patch 合并 providerSwitchPatch`。
- `test/features/canvas/providers/multi_select_patch_controller_test.dart`（新，fake 节点控制器 + 历史）
  - `一次 apply 只调一次 patchTypeConfigMany`；`成功推一步、undo 后各节点回旧值、原来没有的 seed 键被删`；`无变化不写不推`；`写失败不推步、state = Failed、弹「批量修改失败」`；`apply 前先 flush pendingWriteRegistry`（fake registry 记录调用顺序）；`已删除节点被跳过`；`换模型 → state = Adjusted 且字段集正确`。
- `test/features/canvas/widgets/multi_select_inspector_test.dart`（新）
  - `选中 3 个视频 config：标题「已选 3 个节点」、「视频配置 ×3」、总价「约 $2.10」、四行清单`；`时长不同显示「多个值」`；`改时长后三张卡 duration_ms 全变、Ctrl Z 复原`。
  - `混选只有头部 / 总价 / 清单，没有共有参数组`；`一个节点在跑 → 共有参数置灰 + 原因句`；`自定义接口节点 → 「另 1 个价格未知」`；`底部没有生成按钮`。
  - `单选仍渲染原检查器`（`find.byType(VideoConfigInspector)`）。
- 现有 `test/features/canvas/image_config_inspector_test.dart`、`test/features/canvas/widgets/video_config_inspector_test.dart` 不改、必须仍绿（抽函数零行为变化）。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. `providerSwitchPatch` 不清 seed（不支持也保留）→ `新模型不支持种子 → seed:null` 红，组件用例「已调整」提示消失也红。
2. `patchesFor` 不跳过值已相同的节点 → `跳过值已相同的节点` 红。
3. `apply` 改成逐个节点 `patchTypeConfig` → `一次 apply 只调一次 patchTypeConfigMany` 红。
4. 每个节点各推一条撤销 → `成功推一步` 红（栈深 3 而非 1）。
5. 撤销命令不记「原来没有的键」→ `undo 后 seed 键被删` 红。
6. 去掉 apply 前的 flush → `apply 前先 flush` 红。
7. `sharedValueOf` 用 `first` 的值而不比较 → `有不同 → Mixed` 红。
8. `optionsFor` 用并集 → `画幅取交集` 红。
9. `sumCosts` 把 null 当 0 → `unknown 1` 红；不排除停用 → `停用节点不计价` 红。
10. `multiSelectKindOf` 把含文本的选区当 video → `含文本 → mixed` 红。
11. `canvas_inspector_panel` 的多选分支条件写成 `>= 1` → `单选仍渲染原检查器` 红。
12. 单选检查器 `initialResolution` 改成校验支持集 → 现有 image_config_inspector_test 中保存值用例或本片 `保留现状口径` 红。
13. 忙判据去掉 → `一个节点在跑 → 置灰` 红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑：`flutter analyze lib test`；`flutter test test/features/canvas --exclude-tags golden`；上面 13 条变异。
- 截图（`CanvasInspectorPanel` + 假仓库 + 假能力表）：①3 个视频配置「镜头 02 · 江上孤舟 / 03 · 回望 / 04 · 远山」各 $0.70，时长 5 / 5 / 10（「多个值」）；②换成不支持种子的模型后的「已按「X」的能力调整：种子」；③混选（图像配置 + 文本 + 产物）只有计数与清单；④含自定义接口节点「另 1 个价格未知」；⑤一个节点生成中整组置灰；⑥含一个停用节点（行尾「已停用」，不进总价）。亮暗主题各一张①。

## 风险与不确定
- `estimateNodeCost` 的签名与「算不出」的表达（null 还是带标记的记录）以 node-cost 落地为准；本片只依赖「usd 可能为空」。
- PatchTypeConfigCommand 若只支持单节点，就用 W5 的组合命令把 N 条包成一步；本片不改 canvas_command.dart（W9 归 outline-rename-menu）。撤销步名沿用 W5 的「修改参数」类标签。
- 多选的换模型用「支持集外才改第一个」，单选检查器换模型是「一律重置到第一个」——两处口径不同是有意保留单选现状；要统一需另起一片改单选行为。
- 视频画幅 / 种子缺字段（见设计缺口），板上的 mock 暂时对不上；回报主 Agent。
- W2 node-cost 已把两个配置检查器的内联估价换成 node_cost，W5 undo-params 在同两文件加了编辑会话；本片只碰钳制与显示条件几处，rebase 时以落地为准。
