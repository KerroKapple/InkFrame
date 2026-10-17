# tc-stale-marks · 过期标记：只比当前 take 的快照；成片卡「已过期」+ 原因卡 + 重新生成 约 $x；配置卡「当前 take 已过期」；左栏大纲角标

- 波次 W7 / lane A / 基底：origin/main〔W0–W6 已合入〕
- 依赖切片：current-take（W1，currentResultFor）、gen-inputs-snapshot（W2，`lib/features/generation/services/gen_inputs_snapshot.dart`，result.type_config.gen_inputs）、node-cost（W2，estimateNodeCost）、tc-take-edge-follow（W5，线跟着当前 take 走——上游换 take 才会体现成本镜「首帧换成 take N」）、menu-split（W0，CanvasMenuPopover）
- 阻塞决定：无（TC-Q3 按建议 C 写）

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 生成之后改了提示词、种子、模型参数、运镜、泳道 / 画布风格、挂载角色或输入图，当前那张成片卡状态行变成琥珀色「已过期 · take 2」，卡片描边换成琥珀淡边；点它弹原因卡，列出变了哪几项，上游也过期时多一句，底部「重新生成 约 $0.75」。
- 配置卡状态行写「当前 take 已过期」；左栏大纲这一镜行尾出琥珀「过期」角标。
- 改回原值，标记自己消失；旧 take、没快照的老产物一律不标。

## 设计依据
- TakesCost.dc.html「过期标记」（标题副句「比对快照得出；改回原值，标记自己消失」）：
  - 成片卡：状态行 `dirty` 图标 + 「已过期」（accent）+「· take 2」，描边 washBorder（= tokens `accentWashBorder`）。
  - 原因卡 256 宽：标题「生成这张之后，输入变了」（dirty 图标 accent）；每行左 50px 键名（fg5）右值（fg2）：「提示词 「…雾气渐散」→「…晨光破雾」」「种子 4127 → 88」「泳道风格 「水墨风格」改过」「首帧 镜头 01 换成 take 3」；fg6 一行「上游 镜头 01 也已过期」；右下 accent 主按钮 run 图标「重新生成」+ 等宽「约 $0.75」。
  - 左栏大纲：行尾 dirty 图标 +「过期」（accent，10px）；配置卡状态行「当前 take 已过期」。
  - 规则：「只标当前 take；旧 take 是历史不标；没快照的老产物不标」「不算变化：改名、位置、层级、批量张数、原本就随机的种子」「清除：重新生成，或换一张不过期的设为当前」「跨项目粘贴…剥掉源 id 的 take 记作『没快照』，不标过期」。
- 需要你定 Q3「过期往下游传多深」：按 TC-Q3 建议 C——只标输入真变了的那张（A），原因卡里提一句上游。
- 设计缺口：原因卡没画「模型参数」「运镜」「负向」「画布底稿风格」「挂载角色」「加了 / 去掉了输入」这几行的写法（本片按下表文案）；没画配置卡上点「当前 take 已过期」会怎样（本片：同样开原因卡）；没画「重新生成」在没 Key / 提示词空 / 正在生成时的样子（本片：置灰 + tooltip 用生成判据的原因）；没画算不出价格时（本片：金额位写「—」，跟 node-cost）；文本节点经 data 边并进提示词，快照里只有源 id 和 image_url，改了文本正文判不出（本片不判，记缺口）；角色只比 id 列表，改角色描述判不出。

## 允许改的文件
- `lib/features/canvas/util/take_staleness.dart`（新建，纯函数）：快照 vs 现在 → 原因列表；整张画布 → 过期表；提示词片段截取。
- `lib/features/canvas/providers/stale_takes_provider.dart`（新建）：`staleTakesProvider` family(canvasId) autoDispose，watch 节点 / 边 / 泳道 / `canvasBaseStyleProvider(canvasId)`。
- `lib/features/canvas/widgets/stale_reason_popover.dart`（新建）：原因卡 + 「重新生成」。
- `lib/features/canvas/widgets/node_card.dart`：`_StatusRow`（现 :525–575）读过期、可点开原因卡；成片卡过期时描边换 `accentWashBorder`（现 :277 `final Color edge = highlighted ? colors.accent : colors.outline;`，选中仍优先 accent）。**不改 `nodeStatusOf` 的签名和枚举**（大纲共用，过期是叠加层）。
- `lib/features/canvas/util/outline_model.dart`：`OutlineShot` 加 `stale`；`buildCanvasOutline` 加 `Set<String> staleConfigIds = const <String>{}`。
- `lib/features/canvas/widgets/left_rail/outline_panel.dart`：OutlinePanelState（现 :89–125）watch 过期表传进去；`_StatusBadge`（现 :383）在 done 态且 stale 时画「过期」角标。
- `lib/features/generation/services/gen_inputs_snapshot.dart`（由 gen-inputs-snapshot 新建；W7 无人占用）：**只在** W2 没导出纯的「读快照」与「由现在的输入算一份快照」函数时，把它们从写入路径里拆出来（写入行为不变）。
- 测试：`test/features/canvas/util/take_staleness_test.dart`（新建）、`test/features/canvas/widgets/stale_reason_popover_test.dart`（新建）、`test/features/canvas/util/outline_model_test.dart`、`test/features/canvas/widgets/left_rail/outline_panel_test.dart`、`test/features/canvas/node_card_test.dart`、`test/features/generation/services/gen_inputs_snapshot_test.dart`（只在拆函数时追加）。

## 不许碰的文件
- `node_card_slot.dart`、`node_drag_delta.dart`、`edge_painter.dart`、`stage_edge_layer.dart`、`stage_overlays.dart`（cm-drag-insert-narrative）；`canvas_nodes_controller.dart`、`blank_menu_entries.dart`、`node_menu_entries.dart`、`canvas_node_delete.dart`（canvas-clipboard）；`lane_title_bar.dart`、`stage_lane_layer.dart`、`canvas_menu/canvas_menu_host.dart`（cm-lane-menu）；`shell_menu_bar.dart`、`ink_menu_bar.dart`、`ink_shell.dart`、`app.dart`、`main.dart`（menubar）。
- `generation_controller.dart`、`canvas_tool_actions.dart`（只调用 `generateNode`，不改）、`node_artifacts.dart`、`take_numbers.dart`、`node_cost.dart`（只调用）。
- W7 clipboard-paste 的 `lib/features/canvas/widgets/canvas_view.dart`（只加一层 MouseRegion）；W7 lane E 的 shell 菜单栏文件（`lib/app.dart`、`lib/main.dart`、`lib/features/shell/**`、`windows/runner/flutter_window.cpp`）。

## 具体改动
```dart
// take_staleness.dart
enum StaleField { prompt, negativePrompt, seed, model, camera, laneStyle, baseStyle, characters, input }
enum StaleInputChange { added, removed, switchedTake, imageChanged }

@immutable
class StaleReason {
  final StaleField field;
  final String? before;              // 标量字段的旧值（提示词为截好的片段）
  final String? after;
  final EdgeRole? inputRole;         // field == input：首帧 / 尾帧 / 参考
  final StaleInputChange? inputChange;
  final String? inputNodeId;         // 上游显示名取它的配置节点（result → sourceNodeId）
  final String? inputResultId;       // switchedTake 的新源，取 take 号
}

@immutable
class TakeStaleness {
  final String configNodeId;
  final String resultNodeId;
  final int? takeNumber;                     // takeNumbersOn；名下只有一个 → null（写「成片」那档不写号）
  final List<StaleReason> reasons;           // 非空才进表
  final List<String> staleUpstreamConfigIds; // Q3 C：data 入边的上游配置里，当前 take 也过期的
}

@immutable
class StaleTakes {
  final Map<String, TakeStaleness> byResult;
  final Map<String, TakeStaleness> byConfig;
  static const StaleTakes empty;
}

List<StaleReason> diffGenInputs({required GenInputs snapshot, required GenInputs now});
StaleTakes computeStaleTakes({
  required List<CanvasNode> nodes, required List<CanvasEdge> edges,
  required List<StyleLane> lanes, required ({String prefix, String suffix}) baseStyle,
});
(String, String) promptDiffSnippet(String before, String after, {int maxChars = 12});

// stale_takes_provider.dart
final staleTakesProvider = Provider.autoDispose.family<StaleTakes, String>(...);

// stale_reason_popover.dart
void showStaleReasonPopover(BuildContext context, WidgetRef ref, {required String canvasId, required String nodeId, required Offset globalAnchor});
class StaleReasonCard extends ConsumerWidget { const StaleReasonCard({required this.canvasId, required this.configNodeId, required this.onClose}); }
```
`GenInputs` 指 gen_inputs_snapshot.dart 导出的快照类型与读写函数（W2 名字为准）。比较时用 W2 写快照的**同一个**构造函数，从「现在」的配置 type_config、泳道风格、画布底稿风格、data 入边（源 id + 源 image_url）算一份 `now`，再逐字段比——不要在本片另写一份「快照里该有什么」。
`staleTakesProvider`：watch `canvasNodesControllerProvider(canvasId)`、`canvasEdgesControllerProvider(canvasId)`、`canvasLanesControllerProvider(canvasId)`、`canvasBaseStyleProvider(canvasId)`；任一还没值 → `StaleTakes.empty`（不先标再撤）。卡片用 `.select((s) => s.byResult[node.id])` / `byConfig[node.id]`，别的卡不跟着重建。
`_StatusRow`：result 节点有 `byResult` 条目 → 文案 `nodeStatusStaleTake(n)`（无号用 `nodeStatusStale`），dirty 图标 + accent，整行可点（InkActivatable，键盘可达）开原因卡；config 节点没有活动 job 且有 `byConfig` 条目 → `nodeStatusCurrentTakeStale`，同样可点。活动 job（running / queued）优先显示进度，不画过期。
原因卡：用 menu-split 的 `CanvasMenuPopover`（全局坐标 OverlayPortal，不随画布缩放）挂在状态行下方；「重新生成」= `generateNode(ref, nodeId: configNodeId)` 后关卡；金额 = `estimateNodeCost(config, …)`，算不出写「—」。

## 行为规则与边界情况
1. 只看每个 image / video 配置节点的**当前 take**（`currentResultFor`）；旧 take 永远不标；text / shot 节点不参与。
2. 当前 take 的 type_config 没有 `gen_inputs` → 不标（老产物）；快照里有任何一条 data 输入缺源 id（被 `stripUnmappedGenInputs` 剥过）→ 整张当「没快照」，不标。
3. 比较的字段：提示词、负向、种子、模型参数（provider、分辨率、画幅、时长、镜头语言等 W2 记进去的键）、运镜、泳道风格（实际生效的风格文本，含 `ignore_lane_style`）、画布底稿风格（prefix + suffix）、挂载角色 id 列表（有序）、每条 data 入边（按 role + 源配置归组：源换了 take = switchedTake，源同一个但 image_url 变了 = imageChanged，多了 / 少了 = added / removed）。
4. 不算变化：改名、位置、层级、所在泳道换成同样风格的泳道、批量张数（batch_size）。
5. 种子：快照里种子为空（原本就随机）→ 不比；快照有种子、现在不同或清空 → 「种子 4127 → 88」/「4127 → 随机」。
6. 改回原值（含撤销栈撤回）→ 下一次 provider 重算即无原因，标记、描边、角标一起消失；原因卡开着时自动关。
7. Q3 C：上游配置的当前 take 也过期，**不会**让本镜变过期；只有本镜自己有原因时，原因卡多一行「上游 X 也已过期」（多个用「、」连），只看直接上游一层。
8. 上游换了当前 take（W5 把线挪到新 take）→ 本镜原因「首帧 镜头 01 换成 take 3」（无号写「成片」）。
9. 清除：重新生成出的新 take 成为当前（没固定时）→ 新 take 的快照等于现在，不标；或把一张不过期的 take 设为当前。固定在过期 take 上时再生成，标记仍在（当前仍是那张）。
10. 「重新生成」：生成判据（`generate_gate` 的提示词空 / 缺 Key）挡住时置灰、tooltip 写原因；该配置正在生成时置灰；点下后关卡，提交失败走现有错误卡路径。
11. 原因卡关闭：Esc、点卡外、再点一次状态行、节点被删、过期消失。打开时焦点进卡，关闭后焦点回画布。
12. 大纲：镜头行在 done 态且 stale → 行尾「过期」（dirty 图标 + accent）取代绿勾；在生成中仍画进度。筛选不影响角标。
13. 性能：拖动卡片只改 node_drag_delta，不触发重算；松手改位置会重算一次，结果不变，`select` 让卡片不重建。
14. mac / Windows 无差异。

## 新文案键
| key | en | zh |
|---|---|---|
| nodeStatusStale | Stale | 已过期 |
| nodeStatusStaleTake | Stale · take {number} | 已过期 · take {number} |
| nodeStatusCurrentTakeStale | Current take is stale | 当前 take 已过期 |
| leftRailOutlineStale | Stale | 过期 |
| staleReasonTitle | Inputs changed since this was generated | 生成这张之后，输入变了 |
| staleReasonPrompt | Prompt | 提示词 |
| staleReasonNegative | Negative | 负向 |
| staleReasonSeed | Seed | 种子 |
| staleReasonModel | Model | 模型参数 |
| staleReasonCamera | Camera | 运镜 |
| staleReasonLaneStyle | Lane style | 泳道风格 |
| staleReasonBaseStyle | Canvas style | 画布底稿风格 |
| staleReasonCharacters | Characters | 挂载角色 |
| staleReasonFirstFrame | First frame | 首帧 |
| staleReasonLastFrame | Last frame | 尾帧 |
| staleValueFromTo | {before} → {after} | {before} → {after} |
| staleValueQuoted | “{value}” | 「{value}」 |
| staleValueEdited | “{value}” edited | 「{value}」改过 |
| staleValueChanged | Changed | 改过 |
| staleSeedRandom | random | 随机 |
| staleInputSwitchedTake | {node} switched to take {number} | {node} 换成 take {number} |
| staleInputSwitchedFinal | {node} switched to a new final | {node} 换了成片 |
| staleInputImageChanged | {node} changed its image | {node} 换了图 |
| staleInputAdded | Added {node} | 加了 {node} |
| staleInputRemoved | Removed {node} | 去掉了 {node} |
| staleUpstreamAlso | Upstream {names} is also stale | 上游 {names} 也已过期 |
| staleRegenerate | Regenerate | 重新生成 |
| staleCostApprox | ≈ {cost} | 约 {cost} |
「参考」那一行键名复用现有 `canvasEdgeLabelReference`。`staleCostApprox` 若 node-cost 已有同义键（如提示词条金额的「约 $x」），复用它。

## 测试
- `test/features/canvas/util/take_staleness_test.dart`（新建，节点 / 边 / 泳道直接构造；gen_inputs 用 W2 的写入函数造，保证与真实快照同形）：
  - `没改任何输入 → 不过期`
  - `改提示词 → 原因 prompt，片段去掉共同前缀、超长前加省略号`（另测 `promptDiffSnippet`）
  - `改回原提示词 → 不过期`
  - `改名 / 挪位置 / 改 z / 改 batch_size → 不过期`
  - `快照种子为空、现在设了种子 → 不过期；快照 4127 现在 88 → seed 4127→88；现在清空 → 4127→随机`
  - `改模型参数（分辨率）/ 运镜 / 负向 / 画布底稿风格 / 角色列表 → 各出对应字段`
  - `泳道风格改了 → laneStyle；换到风格文本相同的另一条泳道 → 不过期；ignore_lane_style 打开 → laneStyle`
  - `上游配置换了当前 take（边源从 R1 变 R3）→ input switchedTake，takeNumber = 3`
  - `上游同一个 result 换了图 → imageChanged；多一条参考边 → added；删掉首帧边 → removed`
  - `只标当前 take：旧 take 有差也不进表；固定在旧 take 时标固定的那张`
  - `没有 gen_inputs → 不标；有一条输入缺源 id → 整张不标`
  - `Q3 C：上游过期、本镜输入没变 → 本镜不进表；本镜也有原因 → staleUpstreamConfigIds 含上游`
  - `text / shot 配置不参与`
- `test/features/canvas/widgets/stale_reason_popover_test.dart`（新建，ProviderScope override 节点 / 边 / 泳道 / 底稿风格控制器，`test/_harness/test_app.dart` 包壳）：
  - `列出每个原因行，键名与值按表文案`
  - `上游也过期时多一行「上游 X 也已过期」，否则没有`
  - `重新生成显示 约 $x；estimateNodeCost 算不出时写 —`
  - `点重新生成 → 调到 submitWithPending（override inspectorSubmitControllerProvider 记录调用），卡关闭`
  - `提示词为空 / 缺 Key → 重新生成置灰且不可点`
  - `Esc 关闭；过期消失时自动关闭`
- `test/features/canvas/node_card_test.dart`：`过期成片卡状态行「已过期 · take 2」+ accentWashBorder 描边`、`选中时描边仍是 accent`、`配置卡「当前 take 已过期」；有活动 job 时显示进度不显示过期`、`点状态行开原因卡`。
- `test/features/canvas/util/outline_model_test.dart`：`staleConfigIds 里的配置 → OutlineShot.stale == true；默认参数全 false`。
- `test/features/canvas/widgets/left_rail/outline_panel_test.dart`：`过期镜头行尾出「过期」角标取代绿勾`、`改回原值后角标消失`。

## 变异点
1. `diffGenInputs` 里把 batch_size 也比 → 「改 batch_size → 不过期」红。
2. 种子规则去掉「快照为空不比」→ 「快照种子为空、现在设了种子 → 不过期」红。
3. `computeStaleTakes` 改成遍历全部 result（不只当前 take）→ 「只标当前 take」红。
4. 没有 gen_inputs 时当成全部变化 → 「没有 gen_inputs → 不标」红。
5. Q3 改成沿链传递（上游过期则本镜过期）→ 「上游过期、本镜输入没变 → 本镜不进表」红。
6. 泳道风格按 lane id 比而不是生效文本 → 「换到风格文本相同的另一条泳道 → 不过期」红。
7. `_StatusRow` 去掉活动 job 优先 → 「有活动 job 时显示进度不显示过期」红。
8. 原因卡金额 null 时写 `$0.00` → 「算不出时写 —」红。
9. 大纲 `_StatusBadge` 不看 stale → 「过期镜头行尾出『过期』角标」红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/util/take_staleness_test.dart test/features/canvas/widgets/stale_reason_popover_test.dart test/features/canvas/node_card_test.dart test/features/canvas/util/outline_model_test.dart test/features/canvas/widgets/left_rail`；逐条变异。
- 截图：示例画布两镜（镜头 01 → 首帧 → 镜头 02），两镜都已生成且带 gen_inputs：
  1. 改镜头 02 的提示词和种子：截成片卡「已过期 · take 2」+ 配置卡「当前 take 已过期」+ 左栏大纲角标；
  2. 点成片卡状态行：截原因卡（提示词 / 种子两行 + 重新生成 约 $x）；
  3. 再把镜头 01 换一个 take 设为当前且改镜头 01 提示词：截原因卡多出「首帧 镜头 01 换成 take 3」与「上游 镜头 01 也已过期」；
  4. 把镜头 02 提示词改回、种子改回：截标记消失。

## 风险与不确定
- gen_inputs 的键名和读写函数完全以 W2 gen_inputs_snapshot.dart 为准；若 W2 只导出了「写」没有纯的「算」，本片要拆它（行为不变，W2 测试不能改断言）。
- 「以该种子重跑」（seedOverride）若 W2 把覆盖后的种子记进快照，配置上的种子没变，这张会立刻被判「种子 88 → 4127」过期。需要 W2 在快照里区分（如记 `seed_override: true`）或本片在比较时跳过——以 W2 写法为准，回报里提醒主 Agent。
- node_card.dart 本波只归本片；W8 node-disabled-flag 紧接着改 `_StatusRow`，改动集中在一个私有 widget 里。
- CanvasMenuPopover 的 API（锚点、关闭回调、Esc 是否走 escape_ladder 登记）以 menu-split / esc-ladder 合入为准；若原因卡要进 Esc 梯子，只在 escape_ladder 的登记口追加一层。
- 文本节点正文改动、角色描述改动判不出过期（快照不含），是已知缺口。
