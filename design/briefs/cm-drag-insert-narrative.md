# cm-drag-insert-narrative · 拖到叙事线上插一镜
- 波次 W7 / lane B / 基底 origin/main〔W0–W6 已合入〕
- 依赖切片：narrative-splice（W1：insertPlan / makeRoomShifts / canInsertType + CanvasEdgesController.spliceInsert）、nodes-batch-ops（W1：moveNodes）、undo-stack（W0）、undo-adopt-existing（W3：showCanvasUndoSnack 登记栈步）、group-drag（W5：`NodeDragDelta.ids`、`_filterDrag` / `_commitDrag`、resolveGroupDrop）、snapping（W6：`NodeDragDelta.precise`、`isPreciseDropPressed`）、canvas-view-split（W0）
- 阻塞决定：无（ContextMenus-W4 按建议 B：已在链上的节点不触发）

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
拖一张还没入链的镜头 / 图像配置 / 视频配置卡，卡片中心离某条叙事线 12 个屏幕像素以内时，那条线加粗变琥珀色，舞台顶上出「插入到 A 与 B 之间」。松手就把它插进 A→B 之间；A、B 之间放不下一张卡时，B 和链上它后面的镜整体往后让一格。按住 Ctrl（mac ⌘）= 原样放下，不插。插入 + 让位 + 换道在撤销栈里是一步。

## 设计依据
- ContextMenus.dc.html ·「拖到叙事线上 = 插一镜 · P1」（b2_wires.js 208–234 行）：
  - 拖动单张、未入链的镜头 / 图像配置 / 视频配置（文本、便签、产物不可插）；卡片中心离叙事线 ≤ 12px 即命中：线加粗变琥珀、顶上出提示。示意图：命中线 = 2.5 宽 accent 实线 + 4 宽 25% 透明度 accent 光晕；提示 = 舞台顶部居中胶囊（wash 底 / washBorder 边 / accent 字）「插入到 镜头 01 与 03 之间」；B 下方标「让位 →」。
  - 松手：一个事务软删 A→B，建 A→新（沿用原 sortOrder）和 新→B。
  - 让位：A、B 沿主轴放不下一张卡时，B 及链上其后的节点整体后移一格。
  - 按住 Ctrl（⌘）= 原样放下：不插入、也不吸附；Shift 只锁轴，照常可插。
  - 泳道归属沿用 resolveCardDrop（拖过 18px、跨带边界、进新带 ≥ 12px）。
  - 插入 + 让位 + 换道算撤销栈里的一步。
- ContextMenus · 需要你定 W4「已在链上的节点拖到另一条叙事线上？」→ 按建议 B：不触发，只有未入链的能插（A 留到后面）。
- 设计缺口：松手后插入的卡停在哪没写——本片停在松手处（含吸附），不自动对齐到 A–B 中间。
- 设计缺口：插入成功后的反馈没画——本片出一张撤销卡「已插入「A」与「B」之间」，替代换道卡（一次拖动只出一张卡）。
- 设计缺口：插入失败的提示没画——本片出错误卡「没能插进叙事链」。
- 设计缺口：Esc 能不能在拖动途中取消插入没写——本片不处理。

## 允许改的文件
- 新 `lib/features/canvas/util/narrative_drop_insert.dart`：命中与资格纯函数。
- 新 `lib/features/canvas/util/canvas_narrative_drop_actions.dart`：松手后的插入动作（moveNodes + spliceInsert + 推命令 + 卡片）。
- 新 `lib/features/canvas/models/commands/narrative_drop_insert_command.dart`（`part of '../canvas_command.dart';`）。
- `lib/features/canvas/models/canvas_command.dart`（由 undo-stack 新建）：追加一行 part + 一个 `CanvasCommandLabel.narrativeInsert`。
- `lib/features/canvas/providers/node_drag_delta.dart`：新增 `narrativeInsertHitProvider`。
- `lib/features/canvas/widgets/node_card_slot.dart`（由 canvas-view-split 新建，W5/W6 改过）：`_filterDrag` 末尾算命中并写 provider；`_commitDrag` 命中时分流到插入动作。
- `lib/features/canvas/widgets/edge_painter.dart`：插入目标线的高亮画法。
- `lib/features/canvas/widgets/stage_edge_layer.dart`（由 canvas-view-split 新建）：把命中边 id 和 accent 色传给 EdgePainter。
- 新 `lib/features/canvas/widgets/narrative_insert_hint.dart` + `lib/features/canvas/widgets/stage_overlays.dart`（本波归本片）：顶部提示挂在 stage_overlays 的浮层 Stack 里，top = `InkToolbarSize.stageTopInset`、水平居中（与「已选 N」chip 同位置；插入只在单张拖动时出现，那时 chip 不显示，`count < 2` 见 main canvas_view.dart:1572）。
- 测试：见「测试」节。

## 不许碰的文件
- W7 其他切片：`node_card.dart`、`util/take_staleness.dart`、`providers/stale_takes_provider.dart`、`widgets/stale_reason_popover.dart`、`left_rail/outline_panel.dart`、`util/outline_model.dart`（tc-stale-marks；本片只 import outline_model 的 `narrativeChainMembers`，不改）；`providers/canvas_clipboard.dart`、`util/clipboard_snapshot.dart`、`util/paste_placement.dart`、`util/canvas_paste_actions.dart`、`providers/canvas_nodes_controller.dart`、`shortcuts/clipboard_keys.dart`、`canvas_menu/blank_menu_entries.dart`、`canvas_menu/node_menu_entries.dart`、`util/canvas_node_delete.dart`（clipboard）；`lane_title_bar.dart`、`stage_lane_layer.dart`、`canvas_menu/canvas_menu_host.dart`、`canvas_menu/lane_menu_entries.dart`、`util/lane_menu_model.dart`、`providers/lane_collapse_controller.dart`（cm-lane-menu）；shell 菜单栏相关（lone-alt / mac-platform-menubar）。
- 也不碰：`providers/canvas_edges_controller.dart`、`util/narrative_splice.dart`（只调用）、`util/edge_style.dart`（EdgePalette 不加槽）、`util/edge_geometry.dart` / `edge_hit_test.dart`（只调用）、`canvas_view.dart` 骨架。

## 具体改动
```dart
// narrative_drop_insert.dart
const double kNarrativeInsertHitScreenPx = 12;
typedef NarrativeInsertHit = ({String edgeId, String sourceId, String targetId});
bool canDragInsert({
  required CanvasNode node,            // 抓住的那张
  required int groupSize,              // NodeDragDelta.ids.length
  required bool precise,               // NodeDragDelta.precise
  required Set<String> chainMembers,   // narrativeChainMembers(nodes, edges)
});
// = groupSize == 1 && !precise && canInsertType(node)（narrative-splice）&& !chainMembers.contains(node.id)
NarrativeInsertHit? hitNarrativeInsert({
  required Offset cardCenterStage,     // 渲染位置 + delta + kNodeCardSize/2
  required List<CanvasEdge> edges,
  required List<CanvasNode> drawnNodes, // displacedNodes，已去掉折叠道里的卡与抓住的那张
  required LaneDirection direction,
  required double scale,
});
// 只看 EdgeType.narrative、两端都在 drawnNodes 里的边；阈值 12/scale；先 edgeBoundsMayHit 预筛，再 distanceToEdgePath
// （edge_geometry.dart:90 / :111，锚点 edgeSourceAnchor / edgeTargetAnchor）；取最近的一条。

// node_drag_delta.dart
final narrativeInsertHitProvider =
    StateProvider.autoDispose.family<NarrativeInsertHit?, String>((_, __) => null, name: 'narrativeInsertHitProvider'); // canvasId

// canvas_narrative_drop_actions.dart
Future<void> insertDroppedNodeIntoNarrative(
  WidgetRef ref, {
  required String canvasId,
  required CanvasNode node,
  required GroupMove move,             // resolveGroupDrop 给抓住那张的 (delta, laneId)
  required NarrativeInsertHit hit,
  required NarrativeInsertMessages messages, // 卡片文案在 await 前取齐（见 _commitDrag 头注）
  required ToastService toasts,
  required ProviderContainer container,
});

// models/commands/narrative_drop_insert_command.dart
final class NarrativeDropInsertCommand extends CanvasCommand {
  // label: CanvasCommandLabel.narrativeInsert；affectedNodeIds: 插入的节点 + 让位的节点
  // 记：moves（id → 位移 + 新旧 laneId）、插入的两端（A、B、新节点 id，按两端找边，不存边 id）
  // apply：moveNodes(moves) → spliceInsert(A→B, 新)；revert：splice 的反向令牌（软删 A→新、新→B，恢复 A→B）→ moveNodes(反向位移 + 原道)
}
```
- `_filterDrag` 末尾（吸附之后）：`canDragInsert` 不过 → 若 provider 非 null 写 null；过了 → `hitNarrativeInsert`，结果与上一帧不同才写 provider（record 按值比较）。拖动结束 / 取消清成 null。
- `_commitDrag`：先读 `isPreciseDropPressed` 与资格，再用最终位移重算一次 `hitNarrativeInsert`（不信 provider 上的旧值）；命中 → `insertDroppedNodeIntoNarrative`，不走普通的 moveNodes + MoveNodesCommand 路径，也不弹换道卡；未命中 → 原路径不变。
- 插入动作流程：
  1. `makeRoomShifts`（narrative-splice）算让位：入参用 A、B、链上 B 之后的节点、新节点落点、方向、kNodeCardSize；出 id → 位移。合并 moves = {新节点: move} ∪ {让位节点: (位移, 原 laneId)}。
  2. `moveNodes(moves)`；失败 → `nodeMoveFailed` 错误卡，结束。
  3. `spliceInsert`（按 W1 落地签名：边 A→B + 新节点 id）；失败 → 补偿 `moveNodes(反向)`，`canvasNarrativeInsertFailed` 错误卡，结束（补偿也失败只记日志）。
  4. 成功 → 按 canvas_history_controller 的约定登记一条 `NarrativeDropInsertCommand`（若 push 会执行 apply，就把 1–3 写进 apply、这里只 push），`showCanvasUndoSnack` 文案 `canvasNarrativeInserted(A 名, B 名)`，「撤销」= 该栈步 undoSpecific。
- EdgePainter：新参数 `String? insertTargetEdgeId`、`Color? insertHighlightColor`；该边先画 `kNarrativeInsertHaloWidth = 4`、alpha 0.25 的光晕，再画 `kNarrativeInsertEdgeWidth = 2.5` 的实线（两个常量写在 edge_painter.dart 顶部），箭头同色；shouldRepaint 加两项比较。stage_edge_layer：`ref.watch(narrativeInsertHitProvider(canvasId).select((h) => h?.edgeId))`，色 = `colors.accent`（不是用户自定义连线色——画板要琥珀）。
- `NarrativeInsertHint(canvasId)`：watch provider；null → `SizedBox.shrink()`；否则按 A / B 节点名（`nodeDisplayName`，node_card.dart:457）画胶囊 `canvasNarrativeInsertHint(from, to)`，IgnorePointer，样式 wash / washBorder / accent / InkRadius.pill / typo.micro。

## 行为规则与边界情况
1. 资格：单张拖动、类型过 canInsertType、不在任何叙事链上；文本、产物、已入链、多张整组拖动都不出高亮与提示。
2. 命中：卡片中心（渲染位置 + 当前位移）到叙事线路径 ≤ 12 屏幕 px；缩放 0.5 时世界 24 以内。多条线同时在阈值内取最近。data 边、产出线不参与。
3. 端点在折叠泳道里（卡不画）的叙事线不参与。
4. 拖动中按下 Ctrl（mac ⌘）：高亮与提示立即消失（W6 的键盘重算会再过一次 `_filterDrag`）；松开恢复。Shift 只锁轴，照常可插。
5. 松手命中：A→B 软删，建 A→新（沿用 A→B 原 sortOrder）与 新→B；新节点按 resolveCardDrop 换道（与普通拖动一样）。
6. 让位：A、B 主轴间放不下一张卡（判据在 makeRoomShifts）→ B 及链上其后所有节点沿主轴后移一格；放得下 → 不动任何别的卡。让位的卡不换道。
7. 一次 Ctrl Z（或卡上「撤销」）：边回到 A→B，新节点回原位、原道，让位的卡回原位。重做再来一遍。
8. 撤销时某条边或节点已被别处删掉：按 undo-stack 的口径丢这一步并提示，不半撤。
9. moveNodes 失败：位置全回，错误卡，栈无新步；spliceInsert 失败：位置补偿回去，错误卡「没能插进叙事链」，栈无新步。
10. 松手没命中（含拖出阈值后松手）：与普通拖动完全一致（换道卡照旧）。
11. 性能：命中 provider 只在命中边翻转时通知；连线层本来每帧重绘，不额外重建卡片；提示只在命中变化时重建。
12. 拖动中抓住的卡被删：现有 dispose 兜底清 nodeDragDelta；本片在 `_endDrag` 之外再于 slot 的取消路径清命中 provider，autoDispose 兜底。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasNarrativeInsertHint（from String, to String） | Insert between {from} and {to} | 插入到 {from} 与 {to} 之间 |
| canvasNarrativeInserted（from String, to String） | Inserted between “{from}” and “{to}” | 已插入「{from}」与「{to}」之间 |
| canvasNarrativeInsertFailed | Couldn't insert into the sequence | 没能插进叙事链 |
| 撤销步名（前缀照 undo-stack 落地的 CanvasCommandLabel 文案键，如 canvasHistoryStep…） | Insert shot | 插入一镜 |

## 测试
- `test/features/canvas/util/narrative_drop_insert_test.dart`（新）：
  - `scale 1：中心离线 11.9 命中、12.1 不中`
  - `scale 0.5：世界 23 命中、25 不中`
  - `两条叙事线都在阈值内取最近`
  - `data 边不参与`
  - `端点不在 drawnNodes（折叠道）不参与`
  - `canDragInsert：文本 / 产物 false；已在链上 false；groupSize 2 false；precise false；未入链 shot / image / video config true`
- `test/features/canvas/widgets/canvas_drag_insert_test.dart`（新；A→B→D 横向链 + 自由 shot 卡 C；FakeEdgesController 子类记录 spliceInsert，本地 nodes 子类记录 moveNodes）：
  - `拖 C 中心到 A→B 线上：EdgePainter.insertTargetEdgeId == A→B，出现 “Insert between A and B”；拖开后两者消失`
  - `松手插入：spliceInsert 收到 (A→B, C)；A、B 间距不够时 B 与 D 同时后移一格，C 停在松手处`
  - `A、B 间距够：只有 C 移动`
  - `按住 Ctrl（windows）拖到线上：无高亮、无提示，松手只 moveNodes、不调 spliceInsert`
  - `macOS 按 ⌘ 同上；按 Shift 仍可插`
  - `已在链上的 B 拖到另一条线：不高亮`
  - `插入后 Ctrl Z 一次：边回到 A→B、C / B / D 回原位原道，栈深度回到插入前`
  - `spliceInsert 抛 InkError：C / B / D 位置补偿回原处，错误卡 “Couldn't insert into the sequence”，栈深度不变`
  - `插入成功只弹一张卡 “Inserted between “A” and “B””（即使 C 同时换了道）`
- `test/features/canvas/widgets/edge_painter_test.dart`（追加）：`insertTargetEdgeId → 先画 4 宽 alpha 0.25 光晕再画 2.5 宽 accent 实线`；`insertTargetEdgeId 变化 → shouldRepaint true`。

## 变异点
1. 阈值不除 scale → `scale 0.5` 红。
2. canDragInsert 去掉「已在链上」判据 → 单测与 `已在链上的 B` 用例红。
3. 去掉 precise 判断 → `按住 Ctrl` 用例红。
4. 命令 revert 只撤 splice、不撤 moveNodes → `Ctrl Z 一次` 红。
5. splice 失败不补偿位置 → `spliceInsert 抛 InkError` 红。
6. 让位只挪 B、不挪链上其后的 D → `B 与 D 同时后移` 红。
7. EdgePainter 不画光晕 → edge_painter 用例红。
8. `_commitDrag` 信 provider 旧值而不重算 → 拖开后立刻松手的用例（`拖开后两者消失` 之后松手不应插入，加在同一用例尾部）红。
9. 插入路径仍弹换道卡 → `只弹一张卡` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas`；逐条变异。
- 截图：CanvasView 横向链 镜头 01 → 镜头 03（间距 260）+ 一张未入链的「镜头 02」；截 (1) 拖到线上：琥珀加粗线 + 顶部提示，(2) 松手后：三镜成链、03 让位、撤销卡，(3) 按住 Ctrl 拖到线上：无高亮。

## 风险与不确定
- 插入 = moveNodes 与 spliceInsert 两个事务，不是一个 DB 事务；中间失败靠补偿。若要真单事务，需要 CanvasEdgesController.spliceInsert 接受一组节点位移在同一个 UoW 里写——canvas_edges_controller 不在本片文件里，留给后续或回报主 Agent。
- narrative-splice 的 makeRoomShifts / spliceInsert 实际签名以 W1 落地为准；「一格」的长度由它定。
- 新增 `CanvasCommandLabel.narrativeInsert` 后，若 undo-stack 有对该枚举的穷举 switch（标签 → 文案）在别的文件里，那个文件也得加一行；它不在本片允许列表里——执行前先 grep，若在 W7 他人占用的文件里回报主 Agent。
- `narrativeChainMembers` 在 outline_model.dart（W7 tc-stale-marks 占用），本片只 import 不改；对方若改名会冲突。
