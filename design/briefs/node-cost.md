# node-cost · 节点花费预估（算不出写「—」，提示词条常驻金额，悬停「生成」出明细）

- 波次 W2 · lane B · 基底：origin/main（W0–W1 全部合入后；f64f56e 起已含 #301：提示词条与检查器共用 generate_gate）；W0 duration-format 已合入（明细里的「5 秒」用它）
- 依赖切片：duration-format（`formatDurationLabel`）
- 阻塞决定：无（TakesCost 原 Q6 币种已定 USD）

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（W0–W1 已合入）起分支 `feat/node-cost`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（本片不碰）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（本片不写库）。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`（本片无）；不碰 canvas_tool_actions.dart。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
1. 自定义接口（价目 perCall 0）的检查器「预估费用」不再写 `$0.00`，改写「—」。
2. 画布底部提示词条在「生成」按钮左侧常驻一个金额（「约 $0.75」/「—」）。
3. 鼠标停在提示词条或检查器的「生成」上，出一张明细：服务商 · 时长 · 分辨率、计价式、「以服务商账单为准」。
4. 检查器与提示词条的金额来自同一个函数 `estimateNodeCost`，不再各自内联 `estimateCostUsd`。

## 设计依据
- **TakesCost.dc.html · 花费预告 · 批量运行**，右侧「预计」明细卡：「预计 / 约 $0.75 / 万相 图生视频 · 5 秒 · 720p / $0.30 / 秒（1080p）× 0.5 · 以服务商账单为准」；按钮「生成 Ctrl ↵」；示例「批量 $0.032 × 4 = $0.13」「自定义接口 —」「<$0.01」。
- 同节规则：「估算来自 `estimateCostUsd`，单位 USD，不读账单」「**价格未知**写「—」：自定义接口的 costModel 是 perCall 0，检查器现在会写成 $0.00，要改。合计行统一写「另 N 个价格未知」」「**币种**只用 USD（$，`formatCostUsd`）」「悬停任何「生成」出明细；提示词条在按钮左侧常驻金额」。
- critic 第 7 条（价格未知文案统一「另 N 个价格未知」）、第 22 条（币种 USD）。按建议：TakesCost 原 Q6 → A（USD），已在板上定。
- 本片只做单节点；合计行（`sumNodeCosts` + 「另 N 个价格未知」）只交付函数与键，渲染归 W11 batch-run-dialog / W12 cm-multi-select-menu。
- **设计缺口**：① 节点右键菜单「生成」项悬停出明细——菜单行没有悬停浮层的样子，本片不做（菜单项归注册表，W12 多选菜单再统一）。② 价格为 0 但「价目已知」的情况（例如免费额度）板上没区分：本片把**单价全为 0** 一律当「价格未知」。③ 视频没有选时长（provider 没有 supportedDurations）时的写法没画：按「价格未知」处理，明细写「没选时长」。④ 生成按钮置灰时悬停显示什么：本片规定只显示原有的置灰原因，不叠明细。

## 允许改的文件
- `lib/features/generation/services/cost_estimator.dart`：加 `isPriceUnknown`、`formatUnitPriceUsd`、`formatCostMultiplier`；`estimateCostUsd` / `formatCostUsd` 不变。
- `lib/features/generation/services/node_cost.dart`（新建）：`NodeCostEstimate`、`NodeCostUnknown`、`estimateNodeCost`、`formatNodeCost`、`sumNodeCosts`、`resolutionShortLabel`。
- `lib/features/canvas/widgets/cost_breakdown_tooltip.dart`（新建）：`CostBreakdownTooltip`（ConsumerWidget，读 `providerDisplayNamesProvider` 取服务商名）。
- `lib/features/canvas/widgets/image_config_inspector.dart`：第 318–333 行内联估算换成 `estimateNodeCost(... pending: 本地态)` + `formatNodeCost`；第 432–441 行 `InspectorStatusBinding` 传 `costEstimate`。
- `lib/features/canvas/widgets/video_config_inspector.dart`：第 191–203 行同上；第 320 行附近的 `InspectorStatusBinding` 传 `costEstimate`。
- `lib/features/canvas/widgets/inspector_status_panel.dart`（**偏离约定：contract 没列，但检查器「生成」按钮就在这里**，W2 无其他切片占用）：`InspectorStatusBinding` / `InspectorStatusPanel` 加可选 `NodeCostEstimate? costEstimate`，`_IdleButton` 可点时外包 `CostBreakdownTooltip`。
- `lib/features/canvas/widgets/canvas_prompt_bar.dart`：第 359–376 行底行，在字数与 `_GenerateButton` 之间插金额；`_GenerateButton` 可点时外包 `CostBreakdownTooltip`。
- 测试：`test/features/generation/services/node_cost_test.dart`（新）、`test/features/generation/services/cost_estimator_test.dart`、`test/features/canvas/widgets/canvas_prompt_bar_cost_test.dart`（新）、`test/features/canvas/widgets/inspector_status_panel_test.dart`、`test/features/canvas/widgets/video_config_inspector_test.dart`、`test/features/canvas/widgets/image_config_inspector_cost_test.dart`（新）。

## 不许碰的文件
- W2 gen-inputs-snapshot（同波）：`lib/features/generation/generation_controller.dart`、`lib/features/generation/services/gen_inputs_snapshot.dart`、`lib/core/models/gen_inputs.dart`、`lib/services/import/import_remapper.dart`、`test/features/generation/generation_controller*_test.dart`、`test/services/import/import_remapper_test.dart`。
- W2 undo-shortcuts-ui：`lib/features/canvas/widgets/shortcuts/undo_keys.dart`、`lib/features/canvas/widgets/canvas_menu/undo_menu_items.dart`、`lib/features/canvas/util/canvas_history_actions.dart`、`lib/features/app_actions/app_action_catalog.dart`。
- W2 lane-ops-core：`lib/features/canvas/providers/canvas_lanes_controller.dart`、`lib/features/canvas/util/lane_dissolve.dart`、`lib/features/canvas/widgets/stage/stage_lane_layer.dart`、`lane_toolbar.dart` / `lane_title_bar.dart`。
- W2 media-import-service：`lib/features/canvas/providers/canvas_nodes_controller.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/services/orphan_file_reaper.dart`、`lib/storage/repositories/postgres_node_repository.dart`、`lib/core/interfaces/media_import_service.dart`、`lib/services/file_media_import_service.dart`、`lib/core/di/media_import.dart`、`lib/features/canvas/models/canvas_node_import.dart`、`lib/features/canvas/providers/media_import_controller.dart`。
- （主 Agent 跨批核对补充）W2 undo-shortcuts-ui 还改 `lib/features/settings/util/shortcut_catalog.dart`（非注册表）；W2 lane-ops-core 新建 `lib/features/canvas/util/canvas_lane_actions.dart`。
- 本片额外不碰：`lib/features/canvas/util/generate_gate.dart`（只调用它的 `resolveConfigProviderId` / `configProviderCandidates`）、`lib/core/models/cost_model.dart`（freezed）、各 `lib/providers/*_provider.dart` 的价目。

## 具体改动
```dart
// cost_estimator.dart
/// 价目全为 0 ⇒ 算不出：PerCall(0)、PerSecondVideo(0)、PerCharInput(0, 0)。自定义接口模板就是 PerCall(0)。
bool isPriceUnknown(CostModel model);
/// 单价展示：最多 3 位小数、至少 2 位（0.032 → '$0.032'，0.3 → '$0.30'，0.041 → '$0.041'）。格式量，不入 ARB。
String formatUnitPriceUsd(double usd);
/// 倍率展示：去尾零（0.5 → '0.5'，2.0 → '2'）。
String formatCostMultiplier(double m);

// node_cost.dart
enum NodeCostUnknown { customEndpoint, providerMissing, noDuration }
class NodeCostEstimate {
  const NodeCostEstimate({required this.providerId, required this.usd, this.unknown, this.costModel,
      this.batch = 1, this.durationSeconds = 0, this.resolution = Resolution.p1080, this.promptChars = 0, this.isVideo = false});
  final String providerId; final double? usd; /* null ⇔ unknown != null */ final NodeCostUnknown? unknown;
  final CostModel? costModel; final int batch; final int durationSeconds; final Resolution resolution;
  final int promptChars; final bool isVideo;
}
/// 非 image / video 配置节点、或解析不出供应商 ⇒ null（不画金额）。
/// 供应商：resolveConfigProviderId(saved=合并后的 provider_id, lastUsed=[lastUsedProviderId], candidates=configProviderCandidates(node.type, capabilities))。
/// [pending] 是检查器 / 提示词条还没落库的本地值，盖在 node.typeConfig 上再算。
NodeCostEstimate? estimateNodeCost({required CanvasNode node, required List<ProviderCapabilities> capabilities,
    String? lastUsedProviderId, Map<String, Object?> pending = const <String, Object?>{}});
String formatNodeCost(NodeCostEstimate e);           // unknown ⇒ '—'，否则 formatCostUsd(usd)
typedef NodeCostTotal = ({double usd, int known, int unknown});
NodeCostTotal sumNodeCosts(Iterable<NodeCostEstimate?> estimates); // null 项不计
String resolutionShortLabel(Resolution r);           // 720p / 1080p / 2K / 4K

// cost_breakdown_tooltip.dart
class CostBreakdownTooltip extends ConsumerWidget {
  const CostBreakdownTooltip({super.key, required this.estimate, required this.child});
  final NodeCostEstimate? estimate; final Widget child;  // estimate == null ⇒ 原样返回 child
  static const Key contentKey; // 明细正文的测试锚点
}
```
- 取参口径（与 `GenerationController.submitFromConfigNode` 第 181–270 行一致）：分辨率 `resolution` 解析失败 ⇒ `Resolution.p1080`；批量只认 image 且 `batch_size` 为正整数，video 恒 1；视频时长 `duration_ms ~/ 1000`，缺省取所选供应商 `supportedDurations.first`，仍无 ⇒ 0；`promptChars = prompt.trim().length`。
- 供应商 id 解析出来但不在 `capabilities` 里（自定义接口被删）⇒ `unknown: providerMissing`。
- 每秒计价且时长 0 ⇒ `unknown: noDuration`（不再算出 $0.00）。
- 明细卡（Tooltip richMessage，样式全走 `context.inkTypography` / `inkColors`）四行：① 「预计」+ 金额（已知写 `l.costApprox(formatCostUsd)`，未知写「—」+ `l.costUnknown`）；② 服务商名 · 时长（video，`formatDurationLabel`）· 分辨率（video）；③ 计价式（见规则 6–9）；④ `l.costBreakdownDisclaimer`。
- 提示词条：`Text(e.usd == null ? '—' : l.costApprox(formatCostUsd(e.usd!)))`，mono、`fg5`；未知时金额自身也挂 `Tooltip(message: l.costUnknown)`。

## 行为规则与边界情况
1. 自定义接口（`kOpenAIImageTemplateCapabilities` 派生，perCall 0）：检查器「预估费用」与提示词条都写「—」，明细第 ③ 行写 `l.costUnknownCustom`；**不再出现 `$0.00`**。
2. 已知价目：万相图像 perCall 0.032、batch 1 → 「$0.03」；batch 4 → 「$0.13」，明细 ③ 写「批量 $0.032 × 4 = $0.13」。
3. 视频 perSecond 0.30、5 秒、720p 倍率 0.5 → 「$0.75」，明细 ② 「万相 图生视频 · 5 秒 · 720p」，③ 「$0.30 / 秒（1080p）× 0.5」；倍率 1.0 时 ③ 不写「× 1」。
4. 金额 < $0.01 → 「<$0.01」（`formatCostUsd` 原样）。
5. 非配置节点 / text / shot / 无候选供应商 → `estimateNodeCost` 返回 null，提示词条不画金额，按钮不包明细。
6. PerCall batch 1 → ③ `l.costFormulaPerCall(unit)`；batch > 1 → `l.costFormulaBatch(unit, count, total)`。
7. PerSecondVideo → ③ `l.costFormulaPerSecond(rate)`，倍率 ≠ 1 时 `l.costFormulaPerSecondScaled(rate, multiplier)`。
8. PerCharInput → ③ `l.costFormulaPerChar(perK, perImage, count)`。
9. 未知原因 → ③ 分别 `costUnknownCustom` / `costUnknownProvider` / `costUnknownDuration`。
10. 提示词条打字：金额随 `_prompt.text` 即时变（PerCharInput 才有差别），不等 500ms 防抖落库（走 `pending`）。
11. 检查器里改服务商 / 分辨率 / 时长 / 批量：金额随本地态即时变（`pending` 盖在 typeConfig 上）。
12. 「生成」可点时悬停出明细；置灰（空提示词 / 没 Key / 在途）时只出原有的原因 tooltip，不出明细。
13. `sumNodeCosts`：known 求和、unknown 计数、null 跳过；全未知 → `usd == 0, known == 0`。
14. 与撤销栈无交互（只读）；无写库、无并发。mac / Windows：明细卡用 Material `Tooltip`（悬停 500ms 默认等待），键盘聚焦到按钮同样出（InkActivatable 已可聚焦）；快捷键提示「Ctrl ↵ / ⌘↵」沿用 `submitShortcutLabel()`，不另写。

## 新文案键
| key | en | zh |
|---|---|---|
| `costApprox`（amount: String） | `≈ {amount}` | `约 {amount}` |
| `costUnknown` | `Price unknown` | `价格未知` |
| `costUnknownMore`（count: int，plural） | `{count, plural, =1{1 more with unknown price} other{{count} more with unknown price}}` | `另 {count} 个价格未知` |
| `costBreakdownTitle` | `Estimate` | `预计` |
| `costBreakdownDisclaimer` | `Your provider's bill is final` | `以服务商账单为准` |
| `costFormulaPerCall`（unit） | `{unit} per run` | `每次 {unit}` |
| `costFormulaBatch`（unit, count: int, total） | `Batch {unit} × {count} = {total}` | `批量 {unit} × {count} = {total}` |
| `costFormulaPerSecond`（rate） | `{rate} / s (1080p)` | `{rate} / 秒（1080p）` |
| `costFormulaPerSecondScaled`（rate, multiplier） | `{rate} / s (1080p) × {multiplier}` | `{rate} / 秒（1080p）× {multiplier}` |
| `costFormulaPerChar`（perK, perImage, count: int） | `{perK} / 1K chars + {perImage} × {count} images` | `每千字 {perK} + 每张 {perImage} × {count}` |
| `costUnknownCustom` | `Custom endpoints have no price list` | `自定义接口没有价目` |
| `costUnknownProvider` | `This provider is no longer available` | `找不到这个服务商` |
| `costUnknownDuration` | `No duration selected` | `没选时长` |

（`inspectorEstimatedCost` 现有键在 lib 里无人使用，本片不动；主 Agent 可顺手清。）

## 测试
- `test/features/generation/services/cost_estimator_test.dart` 追加：
  - `'isPriceUnknown：单价全为 0 才算'`：PerCall(0)、PerSecondVideo(0, {})、PerCharInput(0,0) → true；PerCall(0.032)、PerCharInput(0, 0.039) → false。
  - `'formatUnitPriceUsd 保留到 3 位小数'`：0.032→`$0.032`、0.3→`$0.30`、0.041→`$0.041`。
  - `'formatCostMultiplier 去尾零'`：0.5→`0.5`、2.0→`2`。
- `test/features/generation/services/node_cost_test.dart`（新），用手搭的 `ProviderCapabilities` 列表：
  - `'自定义接口（perCall 0）→ usd 为 null、unknown=customEndpoint、formatNodeCost 是 —'`。
  - `'万相图像 batch 4 → 0.128，formatNodeCost=$0.13'`。
  - `'video 不吃 batch_size'`：video + batch_size 4 → batch 1。
  - `'视频 5 秒 720p → 0.75，resolution=p720'`。
  - `'缺 resolution 按 p1080（与 GenerationController 同）'`。
  - `'缺 duration_ms 取 supportedDurations.first；仍无 → noDuration'`。
  - `'pending 盖在 typeConfig 上'`：节点存 provider A、pending provider B → 用 B 的价目。
  - `'供应商解析链：已存 > 上次使用 > 候选第一个'`（三条断言）。
  - `'供应商已不在列表 → providerMissing'`。
  - `'非配置节点 / text → null'`。
  - `'sumNodeCosts：已知求和、未知计数、null 跳过'`。
  - `'resolutionShortLabel'`：四档。
- `test/features/canvas/widgets/canvas_prompt_bar_cost_test.dart`（新），覆盖 `providerCapabilitiesListProvider` / `inspectorHasApiKeyProvider`：
  - `'已知价目：生成按钮左侧写「约 $0.13」'`（zh locale）。
  - `'自定义接口：写「—」，不出现 $0.00'`。
  - `'悬停生成按钮出明细：含「以服务商账单为准」与计价式'`（`tester.createGesture(kind: PointerDeviceKind.mouse)` 移到 `CanvasPromptBar.generateKey`，`pump(const Duration(seconds: 1))`，`find.byKey(CostBreakdownTooltip.contentKey)`）。
  - `'按钮置灰（没 Key）时悬停只出原因，不出明细'`。
  - `'改提示词即时刷新金额（PerCharInput）'`。
- `test/features/canvas/widgets/inspector_status_panel_test.dart` 追加：`'idle 可点 + costEstimate → 悬停出明细'`、`'idle 不可点 → 只出置灰原因'`。
- `test/features/canvas/widgets/video_config_inspector_test.dart` 追加：`'预估费用：5 秒 → $0.xx；换时长即时变'`。
- `test/features/canvas/widgets/image_config_inspector_cost_test.dart`（新）：`'自定义接口：预估费用写「—」'`、`'批量改 4 → 金额 ×4'`。

## 变异点
1. `isPriceUnknown` 对 PerCall 改回 `false`（即「把判据改回 0」）→ `node_cost_test` `'自定义接口（perCall 0）…'`、`canvas_prompt_bar_cost_test` `'自定义接口：写「—」…'`、`image_config_inspector_cost_test` `'自定义接口：预估费用写「—」'` 红。
2. `formatNodeCost` 未知时回退 `formatCostUsd(0)` → 同上三条红。
3. `estimateNodeCost` 不吃 `pending` → `'pending 盖在 typeConfig 上'`、`'改提示词即时刷新金额'`、`video_config_inspector_test` `'…换时长即时变'` 红。
4. 视频也吃 batch_size → `'video 不吃 batch_size'` 红。
5. 缺 resolution 默认改成 `supportedResolutions.first` → `'缺 resolution 按 p1080…'` 红。
6. 去掉 noDuration 分支（时长 0 照算）→ `'缺 duration_ms … 仍无 → noDuration'` 红。
7. 提示词条去掉 `CostBreakdownTooltip` 包裹 → `'悬停生成按钮出明细…'` 红。
8. 置灰时也包明细 → `'按钮置灰（没 Key）时悬停只出原因…'`、`'idle 不可点 → 只出置灰原因'` 红。
9. `formatUnitPriceUsd` 改成 2 位小数 → `'formatUnitPriceUsd 保留到 3 位小数'` 红。
10. `sumNodeCosts` 把未知当 0 计入 known → `'sumNodeCosts…'` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/generation/services test/features/canvas/widgets`；上面 10 条变异。
- `grep -n "estimateCostUsd" lib/features/canvas` 无结果（只剩 node_cost.dart 调用）。
- 截图（widget 测试里 `matchesGoldenFile` 不做，主 Agent 用测试 harness 手截）：`CanvasPromptBar`，节点 = 视频配置（万相 i2v、5 秒、720p、有 Key），三张：① 常态「约 $0.75」；② 悬停「生成」出明细卡；③ 换成自定义接口节点，金额「—」+ 明细「自定义接口没有价目」。`ImageConfigInspector` 自定义接口一张：「预估费用 —」。

## 风险与不确定
- 偏离约定：`estimateNodeCost` 的签名从 contract 的 `(node, registry)` 改为 `({node, capabilities, lastUsedProviderId, pending})`——widget 侧拿到的是 `providerCapabilitiesListProvider` 的列表而不是 registry，且检查器的本地未落库值必须能盖进去；名字不变。另多改了 `inspector_status_panel.dart`（检查器「生成」按钮所在）。
- 提示词条宽度下限 480，底行多一个金额后在最窄档可能挤压失败文案：失败文案本就是 `Expanded` + 两行省略，金额固定宽，风险低；截图 ① 用 480 宽再看一次。
- 明细卡用 Material `Tooltip.richMessage`：若 `no_inline_styles_test` 对 TextSpan 样式有误报，改用 `InkTypography` 的现成样式 `copyWith(color:)`，不写数字字号。
