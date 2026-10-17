# undo-stack · 画布撤销栈底座（CanvasHistoryController + CanvasCommand + EdgeEndpoints）
- 波次 W0 / lane D / 基底 origin/main（f64f56e）；依赖切片：无；阻塞决定：无（UndoClipboard Q1 按建议 → A，只影响 undoSpecific）。同 lane 之后串 naming-shot-unify（文件不相交）。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/<切片id>`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
用户这一片**看不到**任何变化：只落撤销栈的状态与契约，不出 UI、不接任何具体命令。后续 undo-shortcuts-ui（W2）、undo-adopt-existing（W3）、undo-node-create-move / undo-edges / undo-params / undo-lanes、tc-set-current 等都按这里的名字写命令、调栈。
现存的撤销卡（删节点 / 删线 / 换道）这一片**不动**，W3 才并进栈。

## 设计依据
UndoClipboard.dc.html：
- 「撤销 / 重做」规则：每个画布一个栈，最多 100 步，重启清空；有新操作就清空重做栈；名字 =「撤销 / 重做」+ 这一步，菜单、⌘K、按钮提示共用一份（→ `CanvasCommand.label`）。
- 「什么进栈」末两条：反向找边一律按两端，不按边 id（→ `EdgeEndpoints`）；撤销失败整步回滚、留在栈顶；要撤的对象已不在就丢掉这一步，提示「这一步已无法撤销」，不连带撤下一步。
- 「和撤销卡的关系」：卡片是提醒、栈才是本体；关闭画布 / 项目丢掉它的栈并收起它的卡（→ `bindCard` + 监听外壳）。
- 「要补的底座」：CanvasHistoryController(canvasId) keepAlive、深度 100；CanvasCommand = 名字 + 受影响节点 + apply / revert，只持快照；撤销前冲掉检查器 500ms 防抖 patch。
- 按建议：Q1 → A（卡上点哪步撤哪步，从栈里抽掉，其余步互不影响）。
- 设计缺口：undoSpecific 抽走的**非栈顶**一步进不进重做栈没画——本单定为不进（重做只能按栈序）；抽的恰是栈顶时等同 Ctrl Z、进重做栈。
- 设计缺口：「关闭画布」没说「切到同项目另一张画布」算不算——外壳同一时刻只开一张画布（ShellState.canvasId 单值，换画布即旧画布页销毁），本单定为算关闭、丢栈。
- 设计缺口：撤销进行中再按一次（busy）、栈空时按，板上都没画——本单只返回状态，反馈由 W2 定。

## 允许改的文件
- `lib/features/canvas/models/canvas_command.dart`（新）：`CanvasCommandOutcome` / `CanvasCommandEnv` / `CanvasCommand`，签名见下；不放任何具体命令。
- `lib/features/canvas/models/edge_endpoints.dart`（新）：`EdgeEndpoints` + `findEdgeByEndpoints`。
- `lib/features/canvas/providers/canvas_history_controller.dart`（新）：provider、状态值对象、控制器。
- `test/_harness/fake_canvas_command.dart`（新）：`ScriptedCanvasCommand` 测试替身（按脚本依次返回 outcome，记调用日志），后续 undo-* 切片复用。
- `test/features/canvas/providers/canvas_history_controller_test.dart`（新）。
- `test/features/canvas/edge_endpoints_test.dart`（新，与现有 `test/features/canvas/canvas_edge_test.dart` 同级）。

## 不许碰的文件
- menu-split：`lib/features/canvas/widgets/create_node_menu.dart`、`lib/features/canvas/widgets/canvas_menu/**`、`lib/theme/components/ink_menu_panel.dart`。
- canvas-view-split：`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/stage/**`。
- esc-ladder → zoom-reset-100：`lib/features/canvas/widgets/canvas_shortcuts.dart`、`lib/features/canvas/widgets/shortcuts/**`、`lib/features/settings/util/shortcut_catalog.dart`、`lib/features/canvas/util/escape_ladder.dart`、`lib/features/canvas/providers/canvas_escape_ladder.dart`、`lib/features/canvas/util/canvas_zoom.dart`。
- multi-select-core → duration-format：`lib/features/canvas/providers/canvas_selection_controller.dart`、`lib/features/canvas/util/selection_geometry.dart`、`lib/l10n/duration_format.dart`。
- naming-shot-unify（同 lane 下一片）：`lib/features/storyboard/widgets/script_import_dialog.dart`。
- 另外本片不碰：`canvas_nodes_controller.dart`、`canvas_edges_controller.dart`、`canvas_node_delete.dart`、`canvas_snackbars.dart`（W1 / W3 的）。

## 具体改动
```dart
// models/canvas_command.dart
enum CanvasCommandOutcome { done, gone, failed }
abstract class CanvasCommandEnv { String get canvasId; Ref get ref; }
abstract class CanvasCommand {           // 不用 sealed：具体命令在 models/commands/<x>_command.dart 各自成文件
  const CanvasCommand();
  String label(AppLocalizations l);
  Set<String> get affectedNodeIds;
  Future<CanvasCommandOutcome> revert(CanvasCommandEnv env);
  Future<CanvasCommandOutcome> apply(CanvasCommandEnv env);
}

// models/edge_endpoints.dart（手写不可变值对象，同 canvas_edge.dart 写法；==/hashCode 覆盖四个字段）
@immutable class EdgeEndpoints {
  const EdgeEndpoints({required this.sourceNodeId, required this.targetNodeId, required this.edgeType, this.role = EdgeRole.reference});
  final String sourceNodeId; final String targetNodeId; final EdgeType edgeType; final EdgeRole role;
  static EdgeEndpoints of(CanvasEdge e);
  bool matches(CanvasEdge e);   // 只比 source / target / edgeType，不比 role、不比 id
}
CanvasEdge? findEdgeByEndpoints(Iterable<CanvasEdge> edges, EdgeEndpoints k);

// providers/canvas_history_controller.dart
const int kCanvasHistoryDepth = 100;
final canvasHistoryControllerProvider =
    NotifierProvider.family<CanvasHistoryController, CanvasHistoryState, String>(CanvasHistoryController.new,
        name: 'canvasHistoryControllerProvider');            // keepAlive（不是 autoDispose）
@immutable class CanvasHistoryStep { const CanvasHistoryStep({required this.id, required this.command}); final String id; final CanvasCommand command; }
@immutable class CanvasHistoryState { final List<CanvasHistoryStep> undo; final List<CanvasHistoryStep> redo; final bool busy; } // 列表不可变，栈顶 = last
enum CanvasUndoStatus { done, gone, failed, empty, busy }
typedef CanvasUndoResult = ({CanvasUndoStatus status, CanvasHistoryStep? step});
class CanvasHistoryController extends FamilyNotifier<CanvasHistoryState, String> {
  String record(CanvasCommand command);
  void bindCard(String stepId, ToastHandle card);
  Future<CanvasUndoResult> undo();
  Future<CanvasUndoResult> redo();
  Future<CanvasUndoResult> undoSpecific(String stepId);
  CanvasHistoryStep? get nextUndo;
  CanvasHistoryStep? get nextRedo;
}
```
- 入栈方法名就是 `record`（不叫 `push`），且只登记、不执行 apply（操作已由调用方做完）；W4 起若干派工单写成 `push`，主 Agent 跨批核对时已记录，以本名为准。
- 步 id：控制器内自增计数，`'$canvasId#$n'`（确定性，便于测）。
- `CanvasCommandEnv` 由控制器内私有类实现：`canvasId = arg`、`ref = this.ref`。
- build 里 `ref.listen<ShellState>(shellControllerProvider, ...)`：`prev?.canvasId == arg && next.canvasId != arg` ⇒ 丢栈（清 undo / redo、dismiss 全部绑定卡、纪元 +1）。
- 撤销 / 重做 / 抽步前都 `await ref.read(pendingWriteRegistryProvider).flushAll()`（app 级、永不抛、2s 封顶）。
- 只 `on InkError` 捕获命令抛出（视同 failed）；其他异常照常上抛，但 `busy` 在 finally 里复位。

## 行为规则与边界情况
1. `record` 在操作**已经执行成功之后**调用；入栈到 undo 顶、清空 redo、返回步 id。栈满（已有 100 步）再 record ⇒ 挤掉最老一步并 dismiss 它绑定的卡。
2. `undo()`：busy ⇒ 立即返回 `(busy, null)`，不冲写、不调命令。否则置 busy → 冲挂起写入 → **冲完再取栈顶**（冲写可能让后续切片登记新步）→ 栈空返回 `(empty, null)`。
3. revert 返回 done ⇒ 该步出 undo、进 redo 顶（redo 同样封顶 100），dismiss 它的卡，返回 `(done, step)`。
4. revert 返回 failed（或抛 InkError）⇒ 该步原样留在栈顶，redo 不变，卡不收，返回 `(failed, step)`。
5. revert 返回 gone ⇒ 该步丢弃（不进 redo），收卡，返回 `(gone, step)`；**不**接着撤下一步。
6. `redo()` 与 2–5 对称：done ⇒ 回到 undo 顶（**不**清 redo 其余步）；failed ⇒ 留在 redo 顶；gone ⇒ 丢弃。
7. `undoSpecific(id)`：id 在 undo 栈顶 ⇒ 完全等同 `undo()`；在栈中间 ⇒ revert 成功后只从 undo 里抽掉，不进 redo，其余步顺序不变；failed 原地不动；gone 抽掉。id 不在 undo（已撤 / 已丢 / 别的画布）⇒ `(empty, null)`，不调任何命令。busy 同规则 2。
8. 撤销在途时 `record` 了新步（用户又做了别的）⇒ 那次撤销完成后它的步**不**进 redo（record 已清 redo，晚到的旧步不许复活）；用记录代数比较实现。
9. 撤销在途时画布被关（丢栈）⇒ 完成后什么也不放回；返回状态照实，但 undo / redo 都保持空。
10. `bindCard(id, card)`：id 已不在 undo 栈 ⇒ 立即 `card.dismiss()`；同一步再绑 ⇒ 先 dismiss 旧卡。步以任何方式离开 undo 栈（撤销成功、gone、被挤掉、丢栈）都 dismiss 它的卡；failed 不收卡。
11. 关画布 = 外壳 `canvasId` 从本画布变成别的值或 null（`openCanvas` 别的画布、`closeCanvas`、`closeProject`、`resetSession`）；切标签不算。丢栈后同一 canvasId 再打开是空栈。
12. 每个 canvasId 一份栈（family），互不影响；纯内存，重启即空。
13. `nextUndo` / `nextRedo` 只读栈顶；`busy` 期间照常返回栈顶（菜单置灰由调用方看 `state.busy`）。
14. 并发：控制器只用 busy 闸、不排队；命令内部经各 controller 的 `serialize` 排队写库，本控制器不另加串行队列。
15. mac / Windows：本片无差异（键位在 W2）。
16. `findEdgeByEndpoints`：按 source / target / edgeType 找**在世**的那条（库上 uq_edges_live 保证至多一条）；role 不参与匹配（被 updateRole 改过角色的边仍能找到），role 只给复原用。

## 新文案键
无（本片不出 UI；「这一步已无法撤销」等键由 undo-shortcuts-ui 加）。

## 测试
`test/features/canvas/providers/canvas_history_controller_test.dart`（ProviderContainer；覆盖 `pendingWriteRegistryProvider` 为记录 `flush` 的 spy；命令用 `ScriptedCanvasCommand`，日志与 spy 共用一个 `List<String>`；卡用 `RecordingToastService().show(...)` 拿句柄看 `dismissed`）：
- `record：入 undo 顶、返回步 id、清空 redo` —— 先 record A → undo → record B ⇒ redo 为空、undo = [B]。
- `深度 100：第 101 步挤掉最老一步并收起它的卡` —— undo.length == 100、首步 id 为第 2 步，第 1 步卡 dismissed。
- `undo done：步进 redo、卡收起、返回 done`。
- `undo failed：步留在栈顶、redo 不变、卡不收`。
- `revert 抛 InkError ⇒ 视同 failed`。
- `undo gone：丢掉这一步、不连带撤下一步` —— 第二步的 revert 调用次数 0、返回 gone。
- `撤销前先冲挂起写入` —— 日志顺序 `['flush', 'revert:A']`。
- `撤销进行中再按 ⇒ busy、revert 只调一次`（第一条命令 revert 挂 Completer）。
- `栈空 ⇒ empty，不冲写也不报错`（日志里没有 revert）。
- `redo done 回 undo 顶；redo failed 留在 redo 顶；redo gone 丢弃`。
- `undoSpecific 栈顶 = undo（进 redo）`；`undoSpecific 抽中间一步 ⇒ 不进重做栈、其余步顺序不变`；`undoSpecific 未知 id ⇒ empty、不调命令`。
- `撤销在途时 record 新步 ⇒ 旧步完成后不进 redo`。
- `画布关掉（openCanvas 别的 / closeCanvas / closeProject）⇒ 栈清空、绑定的卡全部 dismissed`（三个子用例；切标签 goTab 不丢栈另一条）。
- `撤销在途时画布被关 ⇒ 完成后 undo / redo 都空`。
- `bindCard 到已不在栈里的步 ⇒ 立即 dismiss`。
- `两个 canvasId 的栈互不影响`。
`test/features/canvas/edge_endpoints_test.dart`：
- `of 拷四个字段`；`按两端 + 类型找到在世边，不看 id`（同端点不同 id 能找到）；`改过角色的边仍能找到`；`类型不同不算同一条`（同两端一条 data 一条 narrative 各找各的）；`找不到 ⇒ null`。

## 变异点
- 把 `canvas_history_controller.dart` 里 `kCanvasHistoryDepth = 100` 改成 `101` → 「深度 100」红。
- 把 `record` 里清空 redo 的赋值删掉 → 「record：…清空 redo」红。
- 把 failed 分支改成和 done 一样出栈 → 「undo failed：步留在栈顶」红。
- 把 `on InkError` 捕获删掉 → 「revert 抛 InkError ⇒ 视同 failed」红（异常冒出）。
- 把 gone 分支改成「丢弃后继续撤下一步」→ 「undo gone：…不连带撤下一步」红。
- 把 `flushAll()` 挪到 revert 之后 → 「撤销前先冲挂起写入」红。
- 删掉入口的 busy 判断 → 「撤销进行中再按 ⇒ busy」红（revert 调两次）。
- 把 undoSpecific 非栈顶分支改成也推进 redo → 「undoSpecific 抽中间一步」红。
- 删掉记录代数比较 → 「撤销在途时 record 新步」红。
- 删掉 build 里的 `ref.listen(shellControllerProvider, …)` → 「画布关掉…」三个子用例红。
- 把 `EdgeEndpoints.matches` 改成比较 role → 「改过角色的边仍能找到」红；改成不比 edgeType → 「类型不同不算同一条」红。

## 验收
主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas/providers/canvas_history_controller_test.dart test/features/canvas/edge_endpoints_test.dart`，再逐条做上面的变异。无 UI，无截图。docs/CLAUDE.md 的目录树需补 models/canvas_command.dart、models/edge_endpoints.dart、providers/canvas_history_controller.dart 三行——在回报里给一句描述，由主 Agent 加。

## 风险与不确定
- `ref.listen` 只在 provider 已建出时生效：画布从没建过历史就关掉不需要丢栈，无害；但 W2 / W3 必须保证「出卡之前先 read 过 provider」（bindCard 本身就会建出它）。
- 命令经 `env.ref.read(canvasNodesControllerProvider(id).notifier)` 拿的是 autoDispose 的 controller：画布开着时有人在 watch，安全；画布已关则栈已丢，不会走到。
- tc-take-edge-follow（W5）若要「上游所属配置节点」级别的找边，需在 EdgeEndpoints 之外另写匹配函数，不改本文件的 `matches` 语义。
