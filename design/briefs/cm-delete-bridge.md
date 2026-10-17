# cm-delete-bridge · 删链中间的镜时前后两镜自动接上

- 波次 W6 / lane C / 基底 origin/main〔W0–W5 已合入〕
- 依赖切片：menu-split（W0）、undo-stack（W0）、narrative-splice（W1，bridgePlan）、nodes-batch-ops（W1，removeNodes / restoreAll）、undo-adopt-existing（W3，删除节点进栈 + 撤销卡登记栈步）
- 阻塞决定：无（ContextMenus-W1 按建议 A：默认接上，菜单另给「删除（不接上）」）

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 删掉叙事链中间的一镜（Del、卡片删除键、节点菜单「删除」），它前后两镜自动用一条叙事线接上，序列不断。
- 多选删除按「连续被删的一段」算：段前一镜接段后一镜；有分叉 / 汇合的段不接。
- 撤销卡第二行写清楚：「镜头 01 与 镜头 03 已接上」或「前后有分叉，未接上」；一次撤销 = 节点和边全回来、接上的那条消失。
- 节点菜单在「删除」下面多一行「删除（不接上）」。

## 设计依据
画板 ContextMenus.dc.html（生成脚本 b2_wires.js 第 6 栏「删链中间的镜 → 前后接上」，P1）：
- 删前：镜头 01 → 镜头 02（红框）→ 镜头 03；删后：镜头 01 —琥珀线→ 镜头 03，中间留虚线空位。
- 撤销卡：undo 图标 | 标题「已删除 镜头 02」+ 小字「镜头 01 与 03 已接上」| 琥珀「撤销」按钮。
- 规则：被删的节点恰好一条叙事入边、一条叙事出边时接上，新边沿用入边的 sortOrder；多选按连续被删的一段算，段前一镜接段后一镜；有分叉 / 汇合不接，撤销卡写「前后有分叉，未接上」；同一事务完成；撤销 = 复原节点及其边并软删接上的那条（NodeDeletion 需记下新建边 id）。
- 需要你定 W1：按建议 A（默认接上；菜单另给「删除（不接上）」），理由「撤销卡一键就能回退」。
- 设计缺口（按下列默认实现，见回报）：①「删除（不接上）」放在菜单哪一格、何时可点没画——放在删除组「删除」之后，danger 色、无键位；这次删除接不上任何东西时置灰（与「删除」效果相同）；②多段 / 混合结果的撤销卡文案没画——见新文案键 `nodesDeleteBridgedCount` / `nodesDeleteBridgeMixed`；③撤销卡标题沿用现有「节点已删除 / N 个节点已删除」（undo-adopt 已接管的卡），只加第二行；板上标题带节点名属于删除卡统一改版，不在本片；④小字里的名字用 `nodeRefName` 全名（「镜头 01 与 镜头 03」），不做板上「03」的省略。

## 允许改的文件
- `lib/features/canvas/providers/canvas_nodes_controller.dart`：
  - `typedef NodeDeletion`（main 第 33 行）加第三个字段 `List<String> bridgedEdgeIds`；`removeNode`（main 第 136 行）返回 `bridgedEdgeIds: const []`。
  - `removeNodes(Set<String> ids, {bool bridge = false})`（由 nodes-batch-ops 新建）：`bridge` 为 true 时，在同一个 UoW 里、软删节点与级联边之前，按 `bridgePlan` 建接上的叙事边（`scope.edges.create(edgeType: 'narrative', role: 'reference', sortOrder: 入边 sortOrder)`）；新边 id 记在该段第一个被删节点的那条 `NodeDeletion.bridgedEdgeIds` 上。
  - `restore` / `restoreAll`（restoreAll 由 nodes-batch-ops 新建）：同一事务里先复原节点和边，再 `scope.edges.softDelete` 全部 `bridgedEdgeIds`（去重）。
- `lib/features/canvas/util/canvas_node_delete.dart`：`deleteNodeWithUndo` / `deleteNodesWithUndo` 加 `{bool bridge = true}`，单选也走 `removeNodes({id}, bridge: …)`；删除前用 `bridgePreview` 算撤销卡第二行。
- `lib/features/canvas/util/canvas_snackbars.dart`：`showCanvasUndoSnack` 加可选 `String? body`，透传给 `ToastService.show(body:)`（W3 已加的栈步 id 参数不动）。
- `lib/features/canvas/widgets/canvas_menu/node_menu_entries.dart`（由 menu-split 新建）：「删除（不接上）」条目构造 + 执行体。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（注册表，只追加一行）：节点菜单删除组追加上面那条。
- `lib/features/canvas/util/delete_bridge_preview.dart`（新）：纯函数，给菜单置灰与撤销卡文案共用。
- undo-adopt-existing 新建的删除节点命令文件（`lib/features/canvas/models/commands/` 下，grep `class .*Delete.*Nodes.*Command`）：加 `final bool bridge` 字段，重做时 `removeNodes(ids, bridge: bridge)`；撤销仍是 `restoreAll(deletions)`（新字段由 restoreAll 自己处理）。不新加 CanvasCommandLabel。
- 测试 fake（记录字面量要补第三个字段）：`test/_harness/fake_canvas.dart`（第 38 行）、`test/features/canvas/widgets/canvas_view_test.dart`（第 56、137 行）、`test/features/canvas/widgets/canvas_create_menu_test.dart`（第 127 行）、`test/features/canvas/widgets/canvas_node_menu_test.dart`（第 220 行），以及 W1–W5 新增的同类构造（执行代理 `grep -rn "edgeIds:" test lib` 补齐）。
- 测试：`test/features/canvas/canvas_nodes_controller_test.dart`、`test/features/canvas/util/delete_bridge_preview_test.dart`（新）、`test/features/canvas/widgets/canvas_node_menu_test.dart`、`test/features/canvas/widgets/canvas_node_delete_undo_test.dart`（由 undo-adopt 新建，追加用例）、`test/storage/transaction_integration_test.dart`（追加一条）。

## 不许碰的文件
- 同波 cm-edge-menu：`canvas_view.dart`、`stage_edge_layer.dart`、`canvas_menu/canvas_menu_host.dart`、`canvas_menu/edge_menu_entries.dart`、`edge_toolbar.dart`、`util/edge_menu_model.dart`、`util/canvas_edge_actions.dart`、`providers/selected_edge_controller.dart`、`canvas_shortcuts.dart`（Delete 键仍调 `deleteNodesWithUndo`，默认 bridge=true，本片不需要碰它）。
- 同波 snapping：`node_card.dart`、`node_card_slot.dart`、`stage_overlays.dart`、`canvas_menu/blank_menu_entries.dart`。
- 同波 undo-lanes：`canvas_lanes_controller.dart`、`stage_lane_layer.dart`、`lane_title_bar.dart`、`canvas_tool_actions.dart`。
- `util/node_menu_model.dart`（W12 才改共享判据；本条目自带执行体，不加 NodeMenuAction 枚举值）、`util/narrative_splice.dart`（W1 已定，只调用）、`providers/canvas_edges_controller.dart`。
- W6 lane E 导出两片的文件：`lib/features/export/**`（含 open_export_dialog.dart、run_delivery.dart、widgets/export_video_dialog.dart、models/delivery_writer_registry.dart）、`lib/features/shell/widgets/tabs/export_tab.dart`。

## 具体改动
```dart
// canvas_nodes_controller.dart
typedef NodeDeletion = ({CanvasNode node, List<String> edgeIds, List<String> bridgedEdgeIds});
Future<List<NodeDeletion>> removeNodes(Set<String> ids, {bool bridge = false});
// util/delete_bridge_preview.dart
@immutable class BridgePreview {
  final List<(CanvasNode from, CanvasNode to)> bridged; // 会接上的段（段前一镜, 段后一镜）
  final int skipped;                                   // 有分叉 / 汇合、不接的段数
  bool get any => bridged.isNotEmpty;
}
BridgePreview bridgePreview({required Set<String> deletedIds, required List<CanvasNode> nodes, required List<CanvasEdge> edges});
String? bridgeUndoBody(AppLocalizations l, BridgePreview p, String Function(CanvasNode) nameOf); // 无接无跳 ⇒ null
// canvas_node_delete.dart
Future<void> deleteNodeWithUndo(BuildContext c, WidgetRef ref, {required String canvasId, required String nodeId, bool bridge = true});
Future<void> deleteNodesWithUndo(BuildContext c, WidgetRef ref, {required String canvasId, required Set<String> nodeIds, bool bridge = true});
// canvas_snackbars.dart
void showCanvasUndoSnack(BuildContext c, {required String message, required VoidCallback onUndo, String? body /* + W3 已有参数 */});
```
- 事务内的计划用事务里读到的边算（`listIncoming` / `listOutgoing` 已在读，`CanvasEdgeMapping.fromRow` 转换后交给 `bridgePlan`），不信内存态；`bridgePreview` 是同一个 `bridgePlan` 跑在内存态上，只用于文案与菜单置灰。
- 段前一镜与段后一镜之间已有一条活着的叙事边（`uq_edges_live`）：不再建，记为「已接上」、`bridgedEdgeIds` 不含它（撤销不能删掉用户原有的线）。

## 行为规则与边界情况
1. 单删 B，B 恰好一条叙事入边 A→B、一条叙事出边 B→C：删除后存在活的 A→C 叙事边，sortOrder = A→B 的 sortOrder；A→B、B→C 随 B 软删。
2. 链头 / 链尾（只有一侧叙事边）、不在链上的节点、产物、文本：不接，撤销卡没有第二行（与现在一样）。
3. B 有两条叙事出边（分叉）或两条叙事入边（汇合）：不接，撤销卡第二行「前后有分叉，未接上」。
4. 段外的分叉不算：A 另有一条出边 A→X 不影响删 B 时接 A→C（以 bridgePlan 判据为准，测试钉住）。
5. 多选删 B、C（A→B→C→D）：接 A→D 一条，sortOrder = A→B；多选删 B、D（A→B→C→D→E）：接 A→C、C→E 两条，卡片「已接上 2 处」。
6. 混合：一段接上、一段有分叉：卡片「已接上 1 处 · 1 处有分叉未接上」。
7. 建接上的边、软删节点、软删级联边在一个事务里；事务任一步失败：全部回滚（节点回到画布、无新边）、弹 `nodeDeleteFailed`，不进撤销栈。
8. 撤销（卡上「撤销」或 Ctrl Z，二者都是 undo-adopt 的同一步）：一个事务里复原节点与原有边、软删接上的边；撤销后 A→C 不在，A→B→C 回来。
9. 重做：再次按原 `bridge` 值删除，重新接上（新边 id 不同，令牌按 restoreAll 返回的为准）。
10. 节点菜单「删除（不接上）」：对目标集（右键的卡在选中集里 = 整个选中集）删除、`bridge: false`；`bridgePreview(...).any == false` 时置灰。「删除」本身不变（Del 键位提示不变），默认接上。
11. 卡片上的删除键、Delete / Backspace、节点菜单「删除」、多选删除：全部 `bridge: true`。内部回滚用的 `removeNode`（addNodeFromMenu 回滚、W4 撤销新建）不接。
12. 节点在生成中也照删（UndoClipboard Q2-A，undo-adopt 已定），接线规则不变。
13. 删除时 provider 已 dispose（关画布）：沿用 `_alive` 守卫，不抛 StateError。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasNodeMenuDeleteNoBridge | Delete (don't reconnect) | 删除（不接上） |
| nodeDeleteBridged | {from} and {to} reconnected | {from} 与 {to} 已接上 |
| nodeDeleteBridgeSkipped | Branches on either side, not reconnected | 前后有分叉，未接上 |
| nodesDeleteBridgedCount | {count, plural, one{Reconnected 1 place} other{Reconnected {count} places}} | 已接上 {count} 处 |
| nodesDeleteBridgeMixed | Reconnected {bridged} · {skipped} with branches left open | 已接上 {bridged} 处 · {skipped} 处有分叉未接上 |

## 测试
`test/features/canvas/util/delete_bridge_preview_test.dart`（新）
- `A→B→C 删 B → bridged == [(A,C)]`；`B 两条出边 → skipped == 1`；`链尾 → 既不接也不跳，bridgeUndoBody == null`。
- `删 B、C 连续段 → [(A,D)]`；`删 B、D 两段 → 两处`；`混合 → body 用 nodesDeleteBridgeMixed`。
`test/features/canvas/canvas_nodes_controller_test.dart`（追加，InMemoryNodeRepository / InMemoryEdgeRepository + FakeUnitOfWork）
- `removeNodes(bridge: true) 建 A→C 叙事边，sortOrder 沿用 A→B`：edges 仓储里有活的 A→C，sortOrder 断言。
- `removeNodes(bridge: false) 不建边`。
- `分叉时不建边，bridgedEdgeIds 为空`。
- `restoreAll 复原后 A→C 被软删、A→B / B→C 复活`。
- `A→C 已存在时不重复建，restore 后原 A→C 仍活着`。
- `edges.create 抛 LocalIOError → 节点仍在 state，抛给调用方`（FakeUnitOfWork 不回滚 DB，断言内存回滚 + 异常）。
`test/storage/transaction_integration_test.dart`（追加）：`removeNodes 接上边时 nodes.softDelete 失败 → 新边也不在`（真事务）。
`test/features/canvas/widgets/canvas_node_delete_undo_test.dart`（追加）
- `删链中间一镜：撤销卡 body == 「镜头 01 与 镜头 03 已接上」`（RecordingToastService 断言 body）。
- `分叉：body == nodeDeleteBridgeSkipped`。
- `点撤销 → restoreAll 一次，A→C 消失`。
`test/features/canvas/widgets/canvas_node_menu_test.dart`（追加）
- `链中间的镜：节点菜单删除组有「删除（不接上）」且可点；点它 → removeNodes(bridge: false)`。
- `链尾的镜：「删除（不接上）」置灰`。

## 变异点
1. removeNodes 里去掉建边那一步 → `removeNodes(bridge: true) 建 A→C` 红。
2. 新边 sortOrder 写死 0 → 同一用例的 sortOrder 断言红（入边 sortOrder 种成 3）。
3. 分叉时也建边（忽略 bridgePlan 的「不接」）→ `分叉时不建边` 红。
4. restore / restoreAll 不软删 bridgedEdgeIds → `restoreAll 复原后 A→C 被软删` 红。
5. 菜单「删除（不接上）」传 bridge: true → `点它 → removeNodes(bridge: false)` 红。
6. 建边挪到 uow.run 外面单独写 → transaction_integration `nodes.softDelete 失败 → 新边也不在` 红。
7. bridgeUndoBody 分叉分支返回 null → `分叉：body == nodeDeleteBridgeSkipped` 红。
8. 已有 A→C 时仍记进 bridgedEdgeIds → `A→C 已存在…restore 后原 A→C 仍活着` 红。

## 验收
- 主 Agent 跑 `flutter analyze lib test`（NodeDeletion 记录形状变了，analyze 会抓漏改的 fake）、`flutter test test/features/canvas test/storage/transaction_integration_test.dart --exclude-tags golden`，逐条做变异。
- 截图场景（widget = CanvasView + 外壳通知层 ToastLayer，FakeNodes：镜头 01 → 镜头 02 → 镜头 03 叙事链）：①右键镜头 02 的节点菜单（删除组两行）；②Del 后画布上 01→03 接上 + 右下撤销卡两行；③把镜头 02 改成有两条出边，再删：卡片「前后有分叉，未接上」。

## 风险与不确定
- NodeDeletion 是记录类型，加字段会让所有 `(node:, edgeIds:)` 字面量编译失败——已列出已知 5 处，执行代理须 grep 补齐 W1–W5 新增的；选这条路是为了让 undo-adopt 的删除命令、restoreAll 不改就自动带上「删掉接上的那条」。
- `bridgePlan` 的输入输出形状在 W1 合入代码里，本单只定语义；若它只吃 id 集合 + 边集合，事务内要先把读到的行转成 CanvasEdge。
- 删除命令文件不在约定表的本片名单里（W6 无人占用 models/commands/ 的既有文件），只加一个 bool 字段；若主 Agent 要求不碰，可改为在 canvas_node_delete 里 push 一个新命令 `DeleteNodesBridgedCommand`（新文件 + canvas_command.dart 追加一行），回报里已提。
- `nodeRefName` 在 widgets/node_card.dart，canvas_node_delete（util）只 `show nodeRefName` 引入；若层次守卫测试不允许 util → widgets，改由调用方传 `nameOf` 回调。
