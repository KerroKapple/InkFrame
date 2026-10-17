# tc-batch-slot-set-current · 批量 slot：点 slot = promote + 设为当前，同一事务，带撤销令牌；「转正」「设为产物」退场

- 波次 W4 / lane B / 基底：origin/main〔W0–W3 已合入〕
- 依赖切片：current-take（W1，currentResultFor + pinnedResultId extension）、undo-stack（W0，CanvasHistoryController / CanvasCommand）、tc-set-current（W3，current_take_controller.dart + SetCurrentTakeCommand + 「设为当前」文案）；并掉了 undo-set-current
- 阻塞决定：无（UC-Q3 按建议 A「全回」写，不阻塞）

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 批量 take 的 slot（检查器内联网格、全屏对比浮层）上原来的「转正」「设为产物」统一换成「设为当前」；点 slot 缩略图或动作词，一个事务里同时做完：result 节点换主图、slot 单选标记、配置节点 `pinned_result_id` 指向这个 result。
- 「当前」只给真正是本镜当前 take 的那一格；已选（promoted）但 take 不是当前的格仍可点「设为当前」。
- 这一步进撤销栈，名字与 tc-set-current 同为「设为当前 · take N」；撤销 = 原主图、原 promoted slot、原 pinned_result_id 全回。

## 设计依据
- TakesCost.dc.html「当前 take · 固定」：右栏规则「批量 take 展开成 slot；点 slot = 现有 promote + 设为当前，同一事务。『转正』『设为产物』退场」；左栏「当前 = 固定的 ?? 最新的」「撤销：『设为当前』连同它改写的 data 边算一步（Q1 选 A 时）；反向按边两端的节点找边，不按边 id」；历史页 mock 里 take 3 下面一排 4 个 slot，选中那格琥珀描边 + 右上角琥珀勾，其余 0.7 透明。
- UndoClipboard.dc.html「什么进栈」：「设为当前（含批量 slot），连同它改写的线」→ 菜单名「设为当前 · take 3」；「提交生成 / 取消 / 重跑 slot」不进栈。需要你定 3 按建议 A：全回原主图、原 promoted slot、原当前 take；反向令牌记旧 image_url、旧 promoted slot、旧 pinned_result_id。
- 被挪的 data 边（Q1 A）不在本片：W5 tc-take-edge-follow 会把边的挪动塞进本片抽出的 `writePinInScope` / `revertPinInScope`，所以本片的命令只经这两个函数写 pin，不自己写 `pinned_result_id`。
- 设计缺口：画板没画「已选但 take 不是当前」那一格的样子（本片规定：保留「已选」徽标与琥珀描边，动作词是「设为当前」）；没画对比浮层里撤销怎么办（浮层是对话框，Ctrl Z 到不了画布，本片不在浮层里接撤销键）；没画孤儿 result（没有配置节点）的 slot（本片：只换主图，不写 pin，仍进栈）。

## 允许改的文件
- `lib/features/generation/providers/batch_results_controller.dart`：`promote` 换成 `setSlotCurrent`；抽出事务内的 apply / revert 两个顶层函数和令牌类型；成功后 push 命令进栈。
- `lib/features/canvas/util/batch_slot_view.dart`：`batchSlotCanPromote` 删掉，换成带 `takeIsCurrent` 的 `batchSlotCanSetCurrent` / `batchSlotIsCurrent`。
- `lib/features/canvas/widgets/batch_slot_parts.dart`：加 `resultIsCurrentTake(WidgetRef, CanvasNode)`（网格与浮层共用），改 BatchTappable 头注里的「设为产物」字样。
- `lib/features/canvas/widgets/inspector_history_panel.dart`（条件允许；W4 无他片占用）：先 `grep -rn "\.promote(" lib`。若 W3 tc-set-current 在历史页画了 slot 条并调用了旧 `promote`，只把那几处调用改成 `setSlotCurrent`、文案键换成新键；没有调用就不动这个文件。main 上调用只在网格 :326 和浮层 :149 / :516。
- `lib/features/canvas/widgets/batch_results_grid.dart`：动作词 / 缩略图点击 / 脚注换新判据和新键（现 :156 `batchPromoteHint`、:318–330 `promoted`/`success` 两支）。
- `lib/features/canvas/widgets/batch_compare_overlay.dart`：主按钮（现 :500–520）、↵（现 :143–150）、底部提示（`batchOverlayHint`）换新判据。
- `lib/features/canvas/providers/current_take_controller.dart`（由 tc-set-current 新建）：若 W3 没有，抽出事务内写 pin 的 `writePinInScope` / `revertPinInScope` / `invalidateAfterPin`，W3 的 SetCurrentTakeCommand 也改走它们（行为不变）。
- `lib/features/canvas/models/commands/set_current_slot_command.dart`（新建，`part of '../canvas_command.dart';`）。
- `lib/features/canvas/models/canvas_command.dart`（由 undo-stack 新建）：只追加一行 `part 'commands/set_current_slot_command.dart';`；label 复用 tc-set-current 已加的「设为当前」枚举值，不再加新值（W3 若没加，才追加一个 `setCurrentTake`）。
- 测试：`test/features/generation/providers/batch_results_controller_test.dart`、`test/features/canvas/util/batch_slot_view_test.dart`、`test/features/canvas/widgets/batch_results_grid_test.dart`、`test/features/canvas/widgets/batch_compare_overlay_test.dart`、`test/features/canvas/providers/current_take_controller_test.dart`（由 tc-set-current 新建，只追加用例）。

## 不许碰的文件
- W4 其他片：`canvas_tool_actions.dart`、`node_card_slot.dart`、`shot_config_inspector.dart`（undo-node-create-move）；`canvas_view.dart`、`node_card.dart`、`util/drop_placement.dart`（stage-drop-target）；`ink_window_chrome.dart`、`shell_chrome.dart`、`shell_task_capsule.dart`（win-menubar）；`storage/schema/*`、`storage/migrations/*`、`core/db/columns.dart`（export-records-table）。
- `canvas_node.dart`、`node_repository.dart`、`generation_controller.dart`、`canvas_edges_controller.dart`（W5 edge-follow / undo-edges 要用）。

## 具体改动
```dart
// batch_results_controller.dart
@immutable
class SlotSetCurrentToken {
  final String canvasId;
  final String resultNodeId;
  final String slotId;
  final String newImageUrl;
  final String? previousImageUrl;        // 事务里写之前读 result 行 type_config.image_url
  final String? previousPromotedSlotId;  // 同节点写之前 promoted == true 的那一行（没有为 null）
  final PinToken? pin;                   // 孤儿 result（sourceNodeId == null）为 null
}

Future<SlotSetCurrentToken> applySlotSetCurrentInScope(
  RepositoryScope scope, {required String resultNodeId, required String slotId, required String imageUrl});
Future<void> revertSlotSetCurrentInScope(RepositoryScope scope, SlotSetCurrentToken token);

class BatchResultsController ... {
  /// 原 promote：返回 null = 没做事（已是当前 / 不可设 / 在途）。
  Future<SlotSetCurrentToken?> setSlotCurrent(BatchResult slot, {required bool takeIsCurrent});
}

// current_take_controller.dart（W3 已有等价函数就复用并在这里对齐名字）
@immutable
class PinToken { final String configNodeId; final String resultNodeId; final String? previousPinnedResultId; }
Future<PinToken> writePinInScope(RepositoryScope scope, {required String configNodeId, required String resultNodeId});
Future<void> revertPinInScope(RepositoryScope scope, PinToken token);
void invalidateAfterPin(Ref ref, {required String canvasId}); // 本片只 invalidate canvasNodesControllerProvider(canvasId)；W5 加边控制器

// batch_slot_view.dart
bool batchSlotIsCurrent(BatchResult slot, {required bool takeIsCurrent});      // promoted && takeIsCurrent
bool batchSlotCanSetCurrent(BatchResult slot, {required bool takeIsCurrent});  // success || (promoted && !takeIsCurrent)

// batch_slot_parts.dart
bool resultIsCurrentTake(WidgetRef ref, CanvasNode resultNode); // watch canvasNodesControllerProvider(canvasId).select(currentResultFor(...)?.id == resultNode.id)；孤儿 → true

// models/commands/set_current_slot_command.dart
final class SetCurrentSlotCommand extends CanvasCommand {
  SetCurrentSlotCommand(this.token, {required this.takeNumber}); // affectedNodeIds = {resultNodeId, configNodeId?}
  // apply(ref)：unitOfWork 里 applySlotSetCurrentInScope（用 token.slotId / newImageUrl 重放，并刷新 token）
  // revert(ref)：unitOfWork 里 revertSlotSetCurrentInScope；之后 invalidate batchResultsControllerProvider(resultNodeId) + invalidateAfterPin
}
```
apply 的事务顺序（一个 `uow.run`）：读 result 行（取 canvasId / sourceNodeId / 旧 image_url）→ 读同节点 slot 行找旧 promoted → `patchTypeConfig(result, {image_url})`（新旧相同就跳过）→ 清同节点别的 promoted → `markPromoted(slot)` → `sourceNodeId != null` 时 `writePinInScope(config, result)`。revert 反着来：`image_url ← previousImageUrl`（previous 为 null 写 JSON null）、本行 `promoted=false, promoted_node_id=null`、旧 promoted 行 `markPromoted`（行还在才写）、`revertPinInScope`（旧 pin 为 null 就写 `pinned_result_id: null`，pinnedResultId extension 把 null 读成没固定）。
进栈：`setSlotCurrent` 事务成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).push(SetCurrentSlotCommand(...))`——按 undo-stack 的 push 语义只记一步、不再写一次库（若 W0 的 push 会调 apply，则改成只建命令并 push，由 apply 写库，二选一，保证库只写一次）。take 号用 `takeNumbersOn(nodes)[resultNodeId]`，没有号写「成片」那一档，文案与 tc-set-current 同一条。

## 行为规则与边界情况
1. 点格子（成功格的缩略图或动作词「设为当前」）→ 一次事务写三处：result.image_url、slot 单选、config.pinned_result_id = resultNodeId。
2. 已选且 take 是当前：动作词「当前」（不挂手势，沿用「『当前』不是按钮」用例），缩略图点了也不做事，不进栈。
3. 已选但 take 不是当前（用户后来把别的 take 设为当前，或者没固定时来了新 take）：「已选」徽标照画，动作词换成「设为当前」；点了只写 pin，image_url 和 slot 行不动，仍算一步撤销。
4. 失败 / 生成中 / 产物 url 为空的格不可设；对比浮层 ↵ 落在这些格上什么都不做（沿用现有用例）。
5. 孤儿 result（sourceNodeId 为 null）：只换主图和 slot 标记，不写 pin；`resultIsCurrentTake` 当 true 处理（第 2 条的「当前」照常显示）。令牌 `pin == null`。
6. 事务抛 InkError：库回滚，`runBatchSlotAction` 出错误卡（现有 toast 路径），**不 push、不 invalidate**。
7. 在途防连点：`setSlotCurrent` 进行中再点（网格和浮层都算），第二次直接返回 null。
8. 撤销：image_url、旧 promoted slot、pinned_result_id 全回原值；批量网格与画布节点都刷新（invalidate `batchResultsControllerProvider(resultNodeId)` 和画布节点控制器）。重做 = 用令牌重放 apply。
9. 撤销时 result 节点已不在（被删，删的那一步不在它后面时）→ 按 undo-stack 约定报「对象已消失」丢步；slot 行已被清（job 30 天清理连带 CASCADE）→ 跳过 slot 两处，image_url 和 pin 照回。
10. 网格 / 浮层是否显示「当前」只看 `resultIsCurrentTake`，所以撤销栈撤回 pin 后，格子自己变回「设为当前」，不用另发通知。
11. 对比浮层（showDialog）开着时 Ctrl Z / ⌘Z 不处理（焦点在对话框里）；关掉浮层回到画布再撤。mac / Windows 无差异。
12. 「重跑」「取消」「以该种子重跑」不进栈（UndoClipboard「不进栈」）。
13. 画廊 `_chosenArtifactOf` 仍读 `promoted`，不受影响；DB 列 `promoted` 保留，不改 schema。

## 新文案键
| key | en | zh |
|---|---|---|
| batchActionSetCurrent | Set as current | 设为当前 |
| batchSetCurrentHint | Setting a slot as current makes it this take's image and this take the shot's current one; the other slots stay in the gallery and you can switch any time. | 设为当前即把该 slot 写成这个 take 的主图，并把这个 take 设为本镜的当前；其余 slot 保留在画廊，可随时改选。 |
| batchOverlayHint（改值，键不变） | ←→ switch · ↵ set as current · ⎘ rerun with this seed | ←→ 切换 · ↵ 设为当前 · ⎘ 以该种子重跑 |

删除（退场，en / zh 两边都删，generated 重生成）：`batchActionPromote`（Promote / 转正）、`batchPromoteHint`、`batchSetArtifact`（Set as artifact / 设为产物）、`batchCurrentArtifact`（Current artifact / 当前产物；浮层的已是当前态改用现有 `batchActionCurrent`「当前」）。
若 tc-set-current 已有通用「设为当前」键（如 `takeSetCurrent`），`batchActionSetCurrent` 不新增，直接复用那条——主 Agent 合并时去重。

## 测试
- `test/features/generation/providers/batch_results_controller_test.dart`（现 group 'promote' :177 改名 'setSlotCurrent'；`_FakeNodeRepo.findById` 要按 id 回 `source_node_id` / `type_config.image_url`，`patches` 要能看出写给谁）：
  - `一个事务：result 换图 + 清旧 promoted + 标本行 + 配置节点 pinned_result_id = 本 result` —— patches 同时含 `(result, {image_url})` 和 `(config, {pinned_result_id: result})`。
  - `令牌记下写之前的旧 image_url / 旧 promoted slot / 旧 pinned_result_id` —— 预置旧值，断言令牌三个字段等于预置值（不是新值）。
  - `revert：三处全回；旧 pin 为空时写 pinned_result_id: null` 。
  - `已选但 take 不是当前：只写 pin，不写 image_url、不动 slot 行`。
  - `已选且 take 是当前：一行不写，返回 null，不进栈`。
  - `孤儿 result：不写 pin，令牌 pin 为 null`。
  - `事务抛 InkError：不 push、不 invalidate 画布节点`。
  - `成功后撤销栈多一步，undo 后再 redo 与首次落库一致`。
  - `在途时第二次调用直接返回 null`。
  - 现有「不碰别的节点的 promoted 行」「产物为空的 slot 不可设」两条改名保留。
- `test/features/canvas/util/batch_slot_view_test.dart`：`batchSlotCanSetCurrent` 真值表（success × 2、promoted+当前=false、promoted+非当前=true、error / generating / 空 url = false）；`batchSlotIsCurrent` 同表。
- `test/features/canvas/widgets/batch_results_grid_test.dart`：:481 改成 `success=设为当前 / promoted+当前=当前+已选 / error=重跑 / generating=取消`；新增 `已选但 take 不是当前：动作词是「设为当前」且可点`、`点成功格的缩略图 = 设为当前`；:531 改成 `点「设为当前」→ 换图 + 本行 promoted + 旧行清零 + pin 写到配置节点`；:675 脚注用 `batchSetCurrentHint`；新增 `界面上不再出现 Promote / Set as artifact`（find.text 为空）。
- `test/features/canvas/widgets/batch_compare_overlay_test.dart`：:572 改成 `「设为当前」→ 落库并就地翻面成「当前」`；新增 `↵ 落在已选但非当前 take 的格上 = 设为当前`。
- `test/features/canvas/providers/current_take_controller_test.dart`：追加 `writePinInScope / revertPinInScope 往返`、`W3 的设为当前改走 writePinInScope 后行为不变`。

## 变异点
1. `applySlotSetCurrentInScope` 删掉 `writePinInScope` 调用 → 「一个事务…pinned_result_id = 本 result」红。
2. 令牌的 `previousPinnedResultId` 改成在写之后读 → 「令牌记下写之前的旧…」与 revert 用例红。
3. revert 不复标旧 promoted 行 → 「revert：三处全回」红。
4. `batchSlotCanSetCurrent` 改回 `batchSlotViewOf(slot) == BatchSlotView.success`（忽略 takeIsCurrent）→ slot_view 真值表「promoted+非当前=true」与网格「已选但 take 不是当前」红。
5. `setSlotCurrent` 里删掉 push → 「成功后撤销栈多一步」红。
6. 事务失败分支也 push → 「事务抛 InkError：不 push」红。
7. 网格脚注换回 `batchPromoteHint`（键已删会编译失败——用字面量 'Promote' 模拟）→ 「界面上不再出现 Promote」红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/generation/providers test/features/canvas/util/batch_slot_view_test.dart test/features/canvas/widgets/batch_results_grid_test.dart test/features/canvas/widgets/batch_compare_overlay_test.dart test/features/canvas/providers/current_take_controller_test.dart`；逐条跑变异。
- `grep -rn "batchActionPromote\|batchPromoteHint\|batchSetArtifact\|batchCurrentArtifact\|\.promote(" lib test` 为空。
- 截图：`BatchResultsGrid`（320 宽面板），4 格 = success / promoted 且当前 / error / generating，截一张；把配置节点 pin 到另一个 take 后同一网格再截一张（promoted 格出「设为当前」）；`showBatchCompareOverlay` 并排两格，截「设为当前」与「当前」两态。

## 风险与不确定
- W0 `push` 是否执行 apply、`CanvasCommand.apply(ref)` 的 ref 类型（`Ref` 还是 `WidgetRef`）以合入版本为准；`invalidateAfterPin` 的参数类型跟着改。
- W3 若已把写 pin 的事务写在 SetCurrentTakeCommand 里，本片把它挪进 `writePinInScope`，属于改 W3 的文件，行为必须不变（W3 的测试不能改断言）。
- promote 现在只写 image_url，不写 slot 的 width / height / seed 到 result 节点（main 上就是这样，job_media_persister.dart:343 只在首张写过）；本片不改，检查器参数行可能显示首张的种子——留给后续片。
- 新文案键与 tc-set-current 的「设为当前」键可能重复，需主 Agent 去重。
