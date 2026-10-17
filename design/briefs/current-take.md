# current-take · 「当前 take」判据收成 currentResultFor

- 波次 W1 · lane D · 基底：origin/main（W0 全部合入后；须含 menu-split 拆出的 `canvas_menu/`，本片只改 `util/create_menu_model.dart`）
- 依赖切片：无（W0 各片与本片文件不相交；`create_node_menu.dart` 已被 menu-split 拆开，本片只改 `util/create_menu_model.dart`）
- 阻塞决定：无（TakesCost Q2 按建议 A：没固定时最新的就是当前）

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（W0 已合入）起分支 `feat/current-take`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（本片不碰）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork（本片不写库）。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；W1 只有 canvas-capsule 能碰 canvas_tool_actions.dart。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
「这一镜现在用哪张」只剩一个判官：配置节点 `type_config.pinned_result_id` 指向的产物还活着就用它，否则用最新的。序列播放、序列交付计划、导出默认勾选、画廊血缘缩略、⌘K 镜头组缩略、左栏大纲、新建菜单的「带图像产物」判断全部改用它。本片**不提供固定入口**（W3 tc-set-current 才有），所以用户暂时看不到变化；数据里一旦有 `pinned_result_id`（W3 写、或手工包）各处就一致地跟随。

## 设计依据
- **TakesCost.dc.html · 当前 take · 固定**：「当前 = 固定的 ?? 最新的；判据收成 `currentResultFor`，序列 / 导出 / 画廊 / ⌘K 产物组共用」「存配置节点 type_config.`pinned_result_id`，JSONB 键，不用迁移」「固定的被删 → 回落最新；撤销删除时一起回来」「导出默认勾当前 take，行尾标「固定」；收 BOARD 第 200 行」（「固定」标签归 W3 tc-set-current）。
- 按建议：TakesCost Q2 → A（没固定时新 take 自动成为当前，就是现在的「取最新」）。
- plan.md 第 3 节验收：「固定的 take 被软删后回落到最新，撤销删除后又回来」。`listByCanvas` 只返回未删行，所以「回落 / 回来」不需要另写逻辑：固定 id 在候选里找不到就回落，restore 后又找得到。
- **设计缺口**：固定的 take 被删后，配置节点上的 `pinned_result_id` 是否清掉——板上没写。按建议：**不清**（留着才能在撤销删除后自然回来；悬空 id 无害，判据回落）。

## 允许改的文件
- `lib/core/constants/take_keys.dart`（新建）：`abstract final class TakeKeys { static const String pinnedResultId = 'pinned_result_id'; static const String genInputs = 'gen_inputs'; }`——放 core 是因为 W2 gen-inputs-snapshot 的 `import_remapper`（services 层）也要用，不能让 services 反向 import features。
- `lib/features/canvas/models/canvas_node_take.dart`（新建）：`extension CanvasNodeTake on CanvasNode { String? get pinnedResultId; }` + 顶层 `Map<String, String> pinnedResultIdsBySource(Iterable<CanvasNode> nodes)`。
- `lib/features/canvas/util/node_artifacts.dart`：加 `currentResultFor`；文件头注补「当前 = 固定 ?? 最新」。
- `lib/features/storyboard/util/sequence_builder.dart`：第 66、74 行 `latestResultFor` → `currentResultFor`（借后继产物那条也换）；头注第 5 行同步。
- `lib/features/storyboard/models/sequence_shot.dart`：只改第 69 行注释里的函数名。
- `lib/features/sequence/models/sequence_lens.dart`：第 112 行换 `currentResultFor`（只判有无，结果不变，为了全仓只剩一个判官）。
- `lib/features/export/util/export_take_selection.dart`：`latestTakeNodeIds` 改名 `currentTakeNodeIds` 并收 `pinnedBySource`；头注改写（「最新」→「当前」，第 31–32 行「需要节点级显式标记」那段改成「就是 pinned_result_id」）。
- `lib/features/export/widgets/export_video_dialog.dart`：`showExportVideoDialog` 加命名参数 `Map<String, String> pinnedBySource = const <String, String>{}`，透传给 `_ExportVideoDialog`；第 70–82 行 `_latestTakes` 改名 `_currentTakes`，用 `currentTakeNodeIds(_rows, pinnedBySource: …)`。「旧 take」标签判据不变（不在当前集 ⇒ 标），文案调整与「固定」标签归 W3。
- `lib/features/export/open_export_dialog.dart`：读到的 `allNodes` 顺手算 `pinnedResultIdsBySource(allNodes)` 传进去。
- `lib/features/gallery/util/gallery_meta.dart`：`_chosenArtifactOf`（第 312 行起）先看固定。
- `lib/features/command_palette/palette_search.dart`：第 101 行缩略取当前 take；抽一个 `@visibleForTesting String? shotThumbRelativePath(CanvasNode config, List<CanvasNode> nodes)` 顶层函数便于单测。
- `lib/features/canvas/util/outline_model.dart`：`OutlineShot.latest` 改名 `current`（第 89/99 行），`shotOf`（第 181 行起）用 `currentResultFor(…, pinnedResultId: n.pinnedResultId)`（桶里没有配置节点，必须显式传）。
- `lib/features/canvas/widgets/left_rail/outline_panel.dart`：只跟着改名 `shot.latest` → `shot.current`（第 239、340 行）。
- `lib/features/canvas/util/create_menu_model.dart`：第 75 行 `sourceCarriesImage` 换 `currentResultFor`。
- 测试：`test/features/canvas/util/node_artifacts_test.dart`、`test/features/canvas/models/canvas_node_take_test.dart`（新）、`test/features/export/util/export_take_selection_test.dart`、`test/features/storyboard/util/sequence_builder_test.dart`、`test/features/gallery/util/gallery_meta_test.dart`、`test/features/canvas/util/outline_model_test.dart`（第 347/363 行跟着改名）、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/command_palette/palette_shot_thumb_test.dart`（新）、`test/features/export/widgets/export_video_dialog_test.dart`（加一条）。

## 不许碰的文件
- W1 nodes-batch-ops：`lib/features/canvas/providers/canvas_nodes_controller.dart`、`lib/features/canvas/util/canvas_node_delete.dart`、`test/**/fake_repositories.dart`。
- W1 narrative-splice：`lib/features/canvas/providers/canvas_edges_controller.dart`、`lib/features/canvas/util/narrative_splice.dart`。
- W1 canvas-capsule：`lib/features/canvas/widgets/shortcuts/core_canvas_keys.dart`、`lib/features/canvas/util/canvas_tool_actions.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/canvas_zoom_bar.dart`、`lib/theme/components/ink_canvas_capsule.dart`、`lib/features/canvas/providers/canvas_capsule.dart`、`lib/features/canvas/widgets/canvas_capsule_host.dart`。
- W1 app-action-table：`lib/features/app_actions/**`、`lib/features/command_palette/command_actions.dart`、`lib/features/settings/util/shortcut_catalog.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/util/more_menu_model.dart`。
- 本片额外不碰：`lib/features/canvas/models/canvas_node.dart`（手写 `@immutable` 类，不是 freezed）、`lib/features/canvas/util/take_numbers.dart` 与 `inspector_history_panel.dart`（它们要「全部 take」，`resultsFor` 口径不变）、`lib/features/export/util/export_order.dart`（只排序列全部 take，不选「哪一个」）。

## 具体改动
```dart
// core/constants/take_keys.dart
abstract final class TakeKeys { static const String pinnedResultId; static const String genInputs; }

// canvas/models/canvas_node_take.dart
extension CanvasNodeTake on CanvasNode {
  /// type_config['pinned_result_id']；非空字符串才算，其余（缺键 / null / 空串 / 非字符串）= 没固定。
  String? get pinnedResultId;
}
/// 配置节点 id → 它固定的产物 id（只收有固定的配置节点）。
Map<String, String> pinnedResultIdsBySource(Iterable<CanvasNode> nodes);

// canvas/util/node_artifacts.dart
/// 当前 take = 固定的（仍在 resultsFor 的候选里）?? 最新的。
/// [pinnedResultId] 不给时，在 [nodes] 里按 id == sourceNodeId 找配置节点读它的 pinnedResultId；
/// 调用方手里的 nodes 不含配置节点（分桶 / 只给候选）时必须显式传。
CanvasNode? currentResultFor({
  required String sourceNodeId,
  required List<CanvasNode> nodes,
  bool Function(CanvasNode node)? accept,
  String? pinnedResultId,
});

// export/util/export_take_selection.dart
Set<String> currentTakeNodeIds(List<CanvasNode> candidates, {Map<String, String> pinnedBySource = const {}});

// export/widgets/export_video_dialog.dart
Future<void> showExportVideoDialog(BuildContext context, {required String projectId, required List<CanvasNode> videoNodes, Map<String, String> pinnedBySource = const {}});

// command_palette/palette_search.dart
@visibleForTesting
String? shotThumbRelativePath(CanvasNode config, List<CanvasNode> nodes);
```
- `currentResultFor` 内部：`final all = resultsFor(…, accept: accept)`；`pin = pinnedResultId ?? 配置节点.pinnedResultId`；`all` 里 id == pin 的那个优先，否则 `all.first`，空则 null。固定的必须满足 resultsFor 的全部候选条件（role=result、sourceNodeId 相符、有产物 url、过 accept）。
- `gallery_meta._chosenArtifactOf`：若 `u.pinnedResultId` 指向的容器在 `_resultContainersOf(nodes, u)` 里且有产物 url → 选它（它自己的 slot 里有 promoted 就写「名 #n」用 slot 的 outputUrl，否则写名、用它的 thumbnail/image）；否则维持现有逻辑（最新容器上的 promoted → `currentResultFor`）。

## 行为规则与边界情况
1. 没有 `pinned_result_id` → `currentResultFor` 与 `latestResultFor` 结果完全相同（现有全部用例不改仍绿）。
2. 固定的产物在候选里 → 返回它，即使有更新的 take。
3. 固定的产物不在 `nodes` 里（已软删，`listByCanvas` 不返回）→ 回落最新；把它放回 `nodes`（restore）→ 又返回它。
4. 固定 id 指向别的配置的产物 / 一个 config 节点 / url 为空的占位（生成中、失败）/ 被 `accept` 刷掉的产物 → 一律回落最新，不返回「错误的那张」。
5. `pinned_result_id` 为 null、空串、数字 → `pinnedResultId` 返回 null（当没固定）。
6. 显式传 `pinnedResultId` 时不再去 `nodes` 里找配置节点（大纲分桶路径）。
7. 导出：同一镜两个 take，固定的是旧的 → 默认只勾旧的；固定的不在候选（不是视频 / 已删）→ 勾最新；孤儿产物（sourceNodeId 为空）各自勾上，规则不变。
8. 导出对话框：`pinnedBySource` 缺省为空 ⇒ 行为与今天一致（⌘K 入口在 app-action-table 改走 `openExportVideoDialogForCanvas` 前就是这样，见风险）。
9. 序列：镜头借后继配置产物时也用当前 take（`sequence_builder` 第 74 行）。
10. 画廊血缘：上游配置固定了旧 take → 血缘行缩略是旧 take 的；固定的是批量容器且有 promoted slot → 名后缀「#n」、缩略用该 slot。
11. 纯函数改动，无写库、无并发、无撤销交互；mac / Windows 无差异。

## 新文案键
| key | en | zh |
|---|---|---|
| `exportVideoDialogHint`（**改值**，键不变） | `Selected clips are joined in list order. Re-runs of the same shot are listed too — only the current take of each is selected.`（原值 newest → current） | `选中的视频将按列表顺序拼接。同一镜重跑的旧 take 也会列出，默认只勾每镜当前的那一条。` |

## 测试
先写，旧实现下标「新」的用例应红。
- `test/features/canvas/util/node_artifacts_test.dart` 新 `group('currentResultFor')`（`_config` 加可选 `pinned` 参数写进 typeConfig）：
  - `'没固定 → 与 latestResultFor 同'`：两 take，断言 id = 'new'。
  - `'固定的 take 活着 → 取固定的'`：pinned='old'，断言 'old'。
  - `'固定的被软删（不在 nodes 里）→ 回落最新；放回后又是它'`：先不含 'old' 断言 'new'，再加回断言 'old'。
  - `'固定 id 指向别的配置的产物 → 回落最新'`。
  - `'固定的是 url 为空的占位 → 回落最新'`。
  - `'accept 刷掉固定的 → 回落'`：pinned 指向 image 产物、accept 只要 video。
  - `'显式 pinnedResultId 优先，nodes 里没有配置节点也生效'`。
- `test/features/canvas/models/canvas_node_take_test.dart`（新）：`'pinnedResultId：非空字符串才算'`（缺键 / null / '' / 42 → null）；`'pinnedResultIdsBySource 只收有固定的配置节点'`。
- `test/features/export/util/export_take_selection_test.dart`：调用改名；新增 `'固定旧 take → 默认勾旧的'`、`'固定的不在候选 → 勾最新'`。
- `test/features/storyboard/util/sequence_builder_test.dart`：新增 `'配置固定了旧 take → 这一镜播旧 take'`、`'借后继配置产物时同样用它的当前 take'`。
- `test/features/gallery/util/gallery_meta_test.dart`：新增 `'血缘：上游固定了旧 take → 缩略是旧 take'`。
- `test/features/canvas/util/outline_model_test.dart`：第 347/363 行改 `.current`；新增 `'固定旧 take → OutlineShot.current 是旧的，artifactCount 不变'`。
- `test/features/canvas/util/create_menu_model_test.dart`：不加用例——`sourceCarriesImage` 对 image 类型在前一行已短路，同一配置名下的产物与它同型，换成 `currentResultFor` 没有可区分的行为；现有用例不改仍绿即可（只为全仓一个判官）。
- `test/features/command_palette/palette_shot_thumb_test.dart`（新）：`'镜头组缩略取当前 take'`（固定旧的 → 旧的 thumbnail_url）。
- `test/features/export/widgets/export_video_dialog_test.dart`：新增 `'pinnedBySource 指向旧 take → 默认勾旧的、最新那行标「旧 take」'`。

## 变异点
1. `currentResultFor` 忽略固定、直接 `return all.isEmpty ? null : all.first` → `'固定的 take 活着 → 取固定的'` 红。
2. 固定 id 不在候选里时不回落、改为在**全部 nodes** 里按 id 找 → `'固定 id 指向别的配置的产物 → 回落最新'` 与 `'固定的是 url 为空的占位…'` 红。
3. 不把 `accept` 套到固定的上 → `'accept 刷掉固定的 → 回落'` 红。
4. 忽略显式 `pinnedResultId` 参数 → `'显式 pinnedResultId 优先…'` 与大纲 `'固定旧 take → OutlineShot.current 是旧的…'` 红。
5. `pinnedResultId` getter 接受空串 → `canvas_node_take_test` `'非空字符串才算'` 红。
6. `currentTakeNodeIds` 不用 `pinnedBySource` → `'固定旧 take → 默认勾旧的'` 红。
7. `open_export_dialog` / 对话框不透传 pins → `export_video_dialog_test` 新用例红。
8. `sequence_builder` 第 74 行留 `latestResultFor` → `'借后继配置产物时同样用它的当前 take'` 红。
9. `gallery_meta` 不看固定 → `'血缘：上游固定了旧 take…'` 红。
10. `palette_search` 留 `latestResultFor` → `palette_shot_thumb_test` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/util test/features/canvas/models test/features/export test/features/storyboard test/features/gallery test/features/command_palette test/features/sequence`；上面 10 条变异。
- `grep -rn "latestResultFor" lib` 无结果（见风险最后一条：无调用方即删）。
- 无 UI 变化，不截图。

## 风险与不确定
- **⌘K 导出入口**：`command_actions.dart` 第 124–145 行自己拼了一条 `_openExport`，不走 `openExportVideoDialogForCanvas`；它归 W1 app-action-table。在它改走 `openExportVideoDialogForCanvas` 之前，⌘K 打开的导出对话框不认固定（回落「最新」，不会出错）。请主 Agent 在 app-action-table 派工单里点名这一处。
- 偏离约定：`currentResultFor` 比 `latestResultFor` 多一个可选参数 `pinnedResultId`（大纲分桶、导出只给候选两处拿不到配置节点）；另新建 `core/constants/take_keys.dart`（供 W2 import_remapper 在 services 层用）。
- `latestResultFor` 改完后若 lib 里已无调用方，按 Zero-BC 删掉并把 `node_artifacts_test` 的 `group('latestResultFor')` 改写到 `currentResultFor`（没固定时同口径）。
