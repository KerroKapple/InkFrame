# cm-edge-menu · 连线右键菜单 + 中点工具条；选中连线时 Del 删线

- 波次 W6 / lane B / 基底 origin/main〔W0–W5 已合入〕
- 依赖切片：canvas-view-split（W0）、menu-split（W0）、esc-ladder（W0）、undo-stack（W0）、narrative-splice（W1）、nodes-batch-ops（W1）、undo-adopt-existing（W3）、undo-edges（W5）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 右键一条连线：先选中它，再在按下点开「连线菜单」：改语义 › ｜ 插入节点…（只对叙事线）｜ 删除（Del）。
- 选中连线时，中点不再是红色 ✕ 圆钮，换成一条小工具条：「当前语义 ▾」+ 垃圾桶；点「当前语义 ▾」直接开同一张改语义表。
- 改语义表四行：叙事 / 首帧 / 尾帧 / 参考；当前那行打勾，不可用的置灰并在行尾写原因。
- 选中连线时按 Del / Backspace 删线（现在只删节点）；产出线（generation_source 存量边 + 推导线）点不中、没有菜单。

## 设计依据
画板 ContextMenus.dc.html（生成脚本 /home/user/plan/design/b2_wires.js 第 1 栏「连线：右键 + 中点工具条」，副标题「两处打开同一张『改语义』表」）：
- 连线菜单：`改语义 ›`（子菜单）｜`插入节点…`（非叙事线时置灰，行尾「仅叙事线」）｜分隔｜`删除`（danger，键位 Del）。宽 168。
- 改语义子菜单（宽 156）：每行前导是线型小样（叙事 fg4 实线、首帧 teal、尾帧 peach、参考 sky 虚线）；示例里「叙事 · 源是产物」「尾帧 · 模型不支持」置灰，「首帧」打勾。
- 中点工具条：26 高胶囊（s4 底、overlayBorder 边、圆角 13、阴影），左「线型小样 + 当前语义名 + ▾」、竖分隔、右垃圾桶 24×22。
- 规则：右键线 = 先选中再开菜单；产出线点不中，没有菜单。置灰写原因——叙事：两端都是非文本配置节点、不成环；首 / 尾帧：源带图、目标是视频配置且模型支持；参考：源带图。改成首 / 尾帧时目标原有同角色线同一事务降为参考（updateRole 现成）。数据 ↔ 叙事 = 换 edge_type（changeEdgeType，narrative-splice 已建）。插入节点… 只对叙事线：锚点在线中点，A → 新 → B 一次接好。工具条替换红色 ✕；选中线时 Del 删线。
- 菜单行通则（板顶说明）：不可用的置灰不隐藏，键位从快捷键表取。
- 设计缺口（按下列默认实现，见回报）：①「插入节点…」开出来的菜单长什么样没画——按新建菜单同款（带搜索框、宽 236），只列可插类型「镜头 / 图像配置 / 视频配置」；②工具条随缩放是否变大没说——按屏幕尺寸恒定（反缩放）；③同一对节点已有同类线时（uq_edges_live = 同 source+target+edge_type）没画原因——写「已有同类线」；④菜单行用 8px 方色点代替线型小样（InkMenuEntry 现成的 swatch，不为它扩 leading 组件）；⑤叙事两端有一端是产物但不是源时——写「目标是产物」。

## 允许改的文件
- `lib/features/canvas/widgets/canvas_view.dart`（骨架；canvas-view-split 后 main 第 536–580 行的 `edgeAt` / `onEdgeLayerTap` / `onBlankDoubleDown` / `onBlankSecondaryClick` 仍在骨架的 `_CanvasStage.build` 里——「外面的 BlankPointerDetector + GestureDetector(onTapDown) 留在骨架里包 StageEdgeLayer」；W6 骨架归本片）：
  - `_CanvasBody` 的 `_handleNodeTap`（main 第 313 行起）开头加一句清空选中连线（点卡 = 节点选中，连线选中让位）；
  - `edgeAt` 只在 `hittableEdges(edges)` 上判（排除 generationSource）；
  - `onEdgeLayerTap` 命中连线时：选中连线 + 清空节点选中；
  - `onBlankSecondaryClick` 碰到连线（main 第 566–567 行现在是直接 `return`）改为：选中该线 + 清空节点选中 + `openEdge(anchor, edgeId)`。别处不动。
- `lib/features/canvas/widgets/stage/stage_edge_layer.dart`（由 canvas-view-split 新建；main 第 918–956 行的选中边删除钮 → `StageEdgeDeleteOverlay`）：`StageEdgeDeleteOverlay` 里中点的 `_EdgeDeleteButton` 换成 `EdgeToolbar`。W3 undo-adopt-existing 已删掉 `_handleEdgeDelete` / `_restoreEdge`、改调 `util/canvas_edge_delete.dart` 的 `deleteEdgeWithUndo(context, ref, {canvasId, edgeId})`——本片三处删线入口（菜单 / 工具条垃圾桶 / Del）都直接调这个现成函数，**不搬、不另写一份**。`StageEdgeLayer`（W5 group-drag 改过）不动。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`（由 menu-split 新建；`CanvasMenuKind` / `CanvasMenuRequest` / `CanvasMenuController` 都在这里；链：W5 rail-drag-assets → W6 本片 → W7 cm-lane-menu）：`CanvasMenuKind` 加 `edge`；`CanvasMenuRequest` 加 `edgeId`、`edgeView`；`CanvasMenuController.openEdge`。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`（由 menu-split 新建，W5 改过）：宿主分派 `edge` 种类到 `edge_menu_entries.dart`；加静态 `CanvasMenuHost.viewportPointOf`（全局坐标 → 菜单锚点坐标，工具条与 W7 泳道菜单共用）。
- `lib/features/canvas/widgets/canvas_menu/edge_menu_entries.dart`（新）：三种视图的分组构造 + 选中后的分派。
- `lib/features/canvas/widgets/edge_toolbar.dart`（新）：中点工具条。
- `lib/features/canvas/util/edge_menu_model.dart`（新）：纯判据。
- `lib/features/canvas/util/canvas_edge_actions.dart`（新）：改语义 / 插入节点两个动作的唯一实现（删线用 W3 的 `deleteEdgeWithUndo`，见上）。
- `lib/features/canvas/providers/selected_edge_controller.dart`：`select` 不变；加 `clearIf(String id)`（被删的正是选中那条才清）。
- `lib/features/canvas/widgets/shortcuts/core_canvas_keys.dart`（esc-ladder 把 main canvas_shortcuts.dart 第 578–586 行的 `_deleteSelection` 搬成了这里 `canvasDelete` 绑定调用的公开顶层回调；W6 无他片占用）：只改那一个回调——先看选中连线。不碰 canvas_shortcuts.dart。
- `lib/features/canvas/models/commands/edge_menu_commands.dart`（新，独立文件，不是 part；放 `InsertOnEdgeCommand` 与 `ChangeEdgeTypeCommand` 两个类；不改 canvas_command.dart）。
- `lib/theme/components/ink_menu_panel.dart`（由 menu-split 新建；W3 help-actions 加了 `disabledReason`、W4 win-menubar 加了 `rowHeight` / `onArrowOut`；W6 无他片占用）：`InkMenuEntry` 加可选 `String? note`（10 号 fg6，排在键位前；置灰行照样显示）。悬停原因用 W3 的 `disabledReason`，`note` 只负责行尾常显的小字（「仅叙事线」「3 个」），两个字段都设时同一句话可以都填。
- 测试：`test/features/canvas/util/edge_menu_model_test.dart`（新）、`test/features/canvas/widgets/canvas_edge_menu_test.dart`（新）、`test/features/canvas/widgets/canvas_shortcuts_test.dart`、`test/features/canvas/edge_hit_test_test.dart`（只加用例，若 hittableEdges 测在 model 测里则不动）、`test/theme/components/ink_menu_panel_test.dart`（只在加了 note 时加一条）。

## 不许碰的文件
- 同波 snapping：`node_card.dart`、`widgets/stage/node_card_slot.dart`、`widgets/stage/stage_overlays.dart`、`canvas_menu/snap_menu_items.dart`、`providers/node_drag_delta.dart`、`providers/canvas_snap_guides.dart`、`widgets/snap_guides_layer.dart`、`util/drag_snap.dart`、`core/di/canvas_snap.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`、`settings/widgets/canvas_appearance_section.dart`。
- 同波 cm-delete-bridge：`providers/canvas_nodes_controller.dart`、`util/canvas_node_delete.dart`、`util/delete_bridge_preview.dart`、`canvas_menu/node_menu_entries.dart`、`util/canvas_snackbars.dart`、`models/commands/delete_nodes_command.dart`。
- 同波 undo-lanes：`providers/canvas_lanes_controller.dart`、`widgets/stage/stage_lane_layer.dart`、`lane_title_bar.dart`、`lane_edit_dialog.dart`、`lane_toolbar.dart`、`util/canvas_lane_actions.dart`、`models/commands/lane_edit_command.dart`、`util/canvas_tool_actions.dart`（只调用其中 `menuNodePlacement` 等现有函数，不改文件）。
- 同波 export 片：`features/export/**`、`shell/widgets/tabs/export_tab.dart`。
- 本片不改 `providers/canvas_edges_controller.dart`（W5 归 undo-edges，已合；只调用 updateRole / setRoles / changeEdgeType / applySplice / removeEdge）、`util/edge_ends.dart` 与 `models/commands/edge_link_command.dart`（W5 的，只用）、`util/canvas_edge_delete.dart`（W3 的，只用）、`util/edge_hit_test.dart`（过滤放在调用方）、`create_node_menu.dart`（barrel，不动）、`canvas_menu/create_menu_entries.dart`、`canvas_shortcuts.dart`。
- W6 lane E 导出两片的文件：`lib/features/export/**`（含 open_export_dialog.dart、run_delivery.dart、widgets/export_video_dialog.dart、models/delivery_writer_registry.dart）、`lib/features/shell/widgets/tabs/export_tab.dart`。

## 具体改动
```dart
// util/edge_menu_model.dart
enum EdgeKind { narrative, firstFrame, lastFrame, reference }
enum EdgeKindBlock { sourceIsResult, targetIsResult, textEndpoint, wouldCycle, pairTaken,
                     sourceHasNoImage, targetNotVideoConfig, modelUnsupported }
@immutable class EdgeKindOption { final EdgeKind kind; final bool current; final EdgeKindBlock? block; bool get enabled; }
EdgeKind? edgeKindOf(CanvasEdge e);                         // generationSource ⇒ null
List<CanvasEdge> hittableEdges(List<CanvasEdge> edges);     // 去掉 generationSource
List<EdgeKindOption> edgeKindOptions({required CanvasEdge edge, required List<CanvasNode> nodes,
    required List<CanvasEdge> edges, required ProviderCapabilities? targetCaps});
bool wouldCreateNarrativeCycle({required String sourceId, required String targetId,
    required List<CanvasEdge> edges, String? exceptEdgeId});
bool canInsertOnEdge(CanvasEdge e);                         // == edgeType == narrative
List<CanvasNodeType> insertableTypes();                      // shot / image / video，与 narrative_splice.canInsertType 一致
// util/canvas_edge_actions.dart（删线不在这里：用 W3 util/canvas_edge_delete.dart 的 deleteEdgeWithUndo）
Future<void> changeEdgeKind(BuildContext c, WidgetRef ref, {required String canvasId, required String edgeId, required EdgeKind to});
Future<void> insertNodeOnEdge(BuildContext c, WidgetRef ref, {required String canvasId, required String edgeId,
    required CanvasNodeType type, required Offset viewportMidpoint});
ProviderCapabilities? edgeTargetCaps(WidgetRef ref, CanvasNode target); // resolveConfigProviderId + providerCapabilitiesListProvider
// canvas_menu_request.dart
enum EdgeMenuView { full, kinds, insert }
void openEdge(Offset anchor, String edgeId, {EdgeMenuView view = EdgeMenuView.full}); // CanvasMenuController
// canvas_menu_host.dart
static Offset? viewportPointOf(BuildContext context, Offset global);                    // CanvasMenuHost
// edge_toolbar.dart
class EdgeToolbar extends ConsumerWidget { const EdgeToolbar({required String canvasId, required CanvasEdge edge, required double scale}); }
// models/commands/edge_menu_commands.dart（独立文件）
class InsertOnEdgeCommand extends CanvasCommand {
  // 令牌：新节点 id、W1 spliceInsert 返回的 `SpliceApplied.token`（SpliceUndoToken）、让位位移 Map<String, NodeMove>（含各自原 laneId）、撤销时存的 List<NodeDeletion>
  @override String label(AppLocalizations l);   // l.canvasCommandInsertNodeOnEdge
}
class ChangeEdgeTypeCommand extends CanvasCommand {
  // 令牌：before / after 的 EdgeEnds（W5 util/edge_ends.dart，内含 W0 EdgeEndpoints：两端 + edgeType + role）+ 被降级那几条的 EdgeEnds 与原角色
  @override String label(AppLocalizations l);   // l.canvasCommandChangeEdgeRole(edgeKindStepLabel(l, after.type, after.role))——复用 W5 的「改为 {kind}」与 edgeKindStepLabel
}
```
- `changeEdgeKind`：数据角色之间（参考 / 首帧 / 尾帧）走 `updateRole` 拿 W5 的 `EdgeRoleChange` 令牌，record W5 undo-edges 的 `ChangeEdgeRoleCommand`（models/commands/edge_link_command.dart，按 `EdgeEnds` 找边），与检查器入边下拉同一条路；叙事 ↔ 数据走 W1 的 `changeEdgeType(edgeId, {to, role})` → `({CanvasEdge removed, CanvasEdge created, Set<String> demotedIds})?`（一个事务软删旧边 + 建新边，改成首 / 尾帧时内部降级；返回 null = 没做事），record 本片的 `ChangeEdgeTypeCommand`：revert = `findEdgeByEnds(after)` 找到新边 → `changeEdgeType` 回 before 类型，再 `setRoles`（W5）回被降级的那几条；apply = `findEdgeByEnds(before)` 再换一次。找不到 ⇒ `CanvasCommandOutcome.gone`。不改 edge_link_command.dart。
- `insertNodeOnEdge` 顺序（用 W1 narrative-splice 的便捷入口 `spliceInsert`）：`addNode`（落点 = 中点减去半张卡的屏幕尺寸后过 `createNodePlacement`，泳道照常判）→ `CanvasEdgesController.spliceInsert(edgeId, created.id)` → `SpliceApplied?`（= 用当前内存边集算 insertPlan 再 applySplice；null ⇒ 不可插、没碰库，当失败处理） → `shifts = makeRoomShifts(edge: A→B, nodes:, edges:, direction:)`（`Map<String, Offset>`）非空时 `moveNodes({id: (delta: shift, laneId: 该节点此刻 laneId)})` → 定位请求单选新节点 → record `InsertOnEdgeCommand`。`spliceInsert` 失败（抛 InkError 或返回 null）：`removeNode(created.id)` 回滚 + `canvasAddNodeFailed` 错误卡（与 addNodeFromMenu 同一手法，canvas_tool_actions.dart 第 395–405 行）；让位失败只记日志，不回滚插入。
- `InsertOnEdgeCommand.revert`：`inverse = invertSplice(token, 现边集)`（null ⇒ `gone`）→ `applySplice(inverse)`（删 A→新、新→B，按原 sortOrder 重建 A→B，全程按两端不按 id）→ `removeNodes({新节点})` 存令牌 → 让位节点 `moveNodes` 反向位移回原道。apply：`restoreAll(令牌)` → 用 W0 `findEdgeByEndpoints` 按 A、B 两端找到此刻的 A→B（撤销时重建过、id 已变）→ 重新 `spliceInsert(找到的 id, 新节点)`（换新 token；找不到 ⇒ gone）→ 再让位。
- `EdgeToolbar`：外层 `Transform.scale(1/scale)` 以中点为原点，屏幕尺寸恒定；左按钮 = 线型色点 + `kindLabel` + caret，点它 `openEdge(viewportPointOf(按钮左下角), id, view: kinds)`；右按钮垃圾桶 = `deleteEdgeWithUndo`。尺寸 / 颜色全走 tokens（不足的只追加常量到 tokens.dart）。
- core_canvas_keys.dart 里的删除回调（原 `_deleteSelection`）：`final edgeId = ref.read(selectedEdgeControllerProvider(id)); if (edgeId != null) { deleteEdgeWithUndo(...); return; }` 再走节点删除。

## 行为规则与边界情况
1. 右键碰到可命中的连线（10px 阈值，`hitTestEdge` 现成）：选中这条线、清空节点选中、在按下点开 `edge` 菜单；不开空白处菜单。
2. 产出线（存量 generation_source 边、推导的 lineage）左键 / 右键都点不中：右键那一点按空白处处理（开空白处菜单）。
3. 双击连线仍不开新建菜单（现状，main 第 561 行）。
4. 改语义表：当前语义那一行打勾、不可点；其余按 `edgeKindOptions`，判序固定：叙事 = 源是产物 → 目标是产物 → 任一端是文本 → 会成环 → 已有同类线；首 / 尾帧 = 源不带图（`sourceCarriesImage`）→ 目标不是视频配置 → 模型不支持（目标节点按 `resolveConfigProviderId` 解析出的供应商的 `supportsFirstFrame` / `supportsLastFrame`；解析不出 ⇒ 不支持，与 node_inputs_section 第 128 行同口径）→ 已有同类线（从叙事改成数据且同一对已有 data 边）；参考 = 源不带图 → 已有同类线。只显示第一个原因。
5. 改成首 / 尾帧：目标上原有同角色入边在同一事务里降为参考（updateRole / changeEdgeType 内部已做）；撤销一次回到改之前，被降级那条一并回来（undo-edges 的令牌）。
6. 改语义写库失败：控制器已回滚内存，弹 `canvasEdgeKindChangeFailed` 错误卡；不进撤销栈。
7. 「插入节点…」只对叙事线可点；数据线置灰并写「仅叙事线」。点它在线中点（视口坐标）开 `insert` 视图：搜索框 + 镜头 / 图像配置 / 视频配置；Esc / 点外面关，什么都不建。
8. 插入成功：画布上出现 A → 新 → B，原 A→B 软删，新叙事边 A→新 沿用原 sortOrder；新节点被单选；一次 Ctrl Z 撤掉整组（节点、两条新边、恢复 A→B、让位挪回）。
9. 插入时 `spliceInsert` 失败：新节点被删、画布无残留、弹「添加节点失败」；栈里没有这一步。
10. 删除（菜单 / 工具条垃圾桶 / Del）三处同一个 `deleteEdgeWithUndo`：撤销卡与进栈沿用 W3 的行为；删后清选中连线。
11. Del / Backspace：选中连线时只删线，不删选中的节点（选中连线时节点选中本已被清；万一两者并存也以线优先）；没有选中连线才删节点。文本框持焦时让位（esc-ladder 的 `CanvasKeyGate.notEditingText` 门槛不变）。
12. 点一张卡：清掉选中连线（工具条消失）。Esc 仍按现有层序清选中（菜单开着先关菜单）。
13. 菜单开着时那条线被删（撤销 / 别处删）：`edge` 菜单不出任何项，显示 emptyText（与节点菜单同款，create_node_menu.dart 第 599 行）；工具条随几何为 null 消失。
14. 折叠道里端点的线不画、点不中、没有工具条（选中几何只看可见节点，现状）。
15. 平移工具（H / 空格）下舞台不收指针：右键线不开菜单、工具条点不动（StagePanGate 现状）。
16. mac：Del 键位提示显示 ⌫（`canvasShortcutLabel` 从注册表取，两平台各取首个可显示的）；Windows 显示 Delete。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasEdgeMenuChangeKind | Change type | 改语义 |
| canvasEdgeMenuInsertNode | Insert node… | 插入节点… |
| canvasEdgeMenuDelete | Delete | 删除 |
| canvasEdgeKindNarrative | Narrative | 叙事 |
| canvasEdgeMenuReasonNarrativeOnly | Narrative links only | 仅叙事线 |
| canvasEdgeMenuReasonSourceIsResult | Source is a take | 源是产物 |
| canvasEdgeMenuReasonTargetIsResult | Target is a take | 目标是产物 |
| canvasEdgeMenuReasonTextNode | Text can't join the chain | 文本不入链 |
| canvasEdgeMenuReasonCycle | Would loop | 会成环 |
| canvasEdgeMenuReasonPairTaken | Already linked | 已有同类线 |
| canvasEdgeMenuReasonNoImage | Source has no image | 源不带图 |
| canvasEdgeMenuReasonTargetNotVideo | Target isn't a video config | 目标不是视频配置 |
| canvasEdgeMenuReasonModelUnsupported | Model doesn't support it | 模型不支持 |
| canvasEdgeKindChangeFailed | Couldn't change the link type | 改语义失败 |
| canvasCommandInsertNodeOnEdge | Insert node | 插入节点 |
（中点工具条删除键的文案复用 W3 的 `canvasCommandDeleteEdge`（同为「删除连线」），不新加 canvasEdgeToolbarDelete（主 Agent 跨批核对补充）；首帧 / 尾帧 / 参考三行复用现有 `inspectorRoleFirstFrame` / `inspectorRoleLastFrame` / `inspectorRoleReference`，不新加 canvasEdgeKind 三键；「改语义」步名复用 W5 的 `canvasCommandChangeEdgeRole`；插入失败复用 canvasAddNodeFailed，搜索提示复用 canvasCreateMenuSearchHint，类型名复用 canvasCreateMenuShot / ImageConfig / VideoConfig。）

## 测试
`test/features/canvas/util/edge_menu_model_test.dart`（新，纯函数）
- `源是产物 → 叙事置灰，原因 sourceIsResult`：result→video config 的参考边，narrative option.block == sourceIsResult。
- `两端配置节点、无环 → 叙事可点`；`目标已经能沿叙事走回源 → wouldCycle`（A→B→C 叙事，C→A 数据边改叙事）。
- `任一端是文本 → textEndpoint`。
- `目标不是视频配置 → 首帧 targetNotVideoConfig`；`供应商 supportsLastFrame=false → 尾帧 modelUnsupported`；`targetCaps == null → 首帧 modelUnsupported`。
- `源不带图 → 参考 sourceHasNoImage`；`图像配置源 → 参考可点`。
- `当前语义打勾且不可点`；`同一对已有 data 边时 叙事→首帧 pairTaken`。
- `hittableEdges 去掉 generationSource`；`canInsertOnEdge 只认 narrative`。
`test/features/canvas/widgets/canvas_edge_menu_test.dart`（新，ProviderScope + test/_harness/fake_canvas.dart 的 FakeNodesController / FakeEdgesController，toast 用 fake_toast_service.dart 的 RecordingToastService）
- `右键连线：选中它、清空节点选中、开连线菜单三项（改语义 / 插入节点… / 删除）`。
- `右键存量 generation_source 边：不开连线菜单，开空白处菜单`。
- `数据线：插入节点… 置灰且行尾写「仅叙事线」`。
- `选中连线后中点出工具条、不再有 Icons.close 圆钮；点「语义 ▾」开只有四行的改语义表`。
- `改成首帧调用 updateRole(firstFrame)；参考↔叙事调用 changeEdgeType`（fake 记录调用）。
- `插入：叙事线 A→B 上选「视频配置」→ addNode + spliceInsert 各一次，新节点被单选，撤销栈深 +1`。
- `叙事线改成参考后 undo：changeEdgeType 被调回 narrative`（真 CanvasHistoryController + FakeEdgesController 记录调用）。
- `插入时 spliceInsert 抛 LocalIOError → removeNode(新 id) 被调用，错误卡 canvasAddNodeFailed`。
- `工具条垃圾桶 → removeEdge + 撤销卡`。
- `点一张卡 → 选中连线清空，工具条消失`。
`test/features/canvas/widgets/canvas_shortcuts_test.dart`（追加）
- `选中连线 + 选中节点时 Delete 只删线`：removeEdge 一次、removeNodes 零次。
- `只选中节点时 Delete 仍删节点`（现有用例保持绿）。
`test/theme/components/ink_menu_panel_test.dart`（只在本片加了 note 字段时）：`置灰行仍显示 note 文字`。

## 变异点
1. edge_menu_model：删掉叙事判据里的「源是产物」分支 → `源是产物 → 叙事置灰` 红。
2. edge_menu_model：`wouldCreateNarrativeCycle` 恒返回 false → `wouldCycle` 用例红。
3. edge_menu_model：首 / 尾帧不看 `supportsLastFrame` → `modelUnsupported` 用例红。
4. `hittableEdges` 改成原样返回 → `右键存量 generation_source 边` 红。
5. core_canvas_keys.dart 的删除回调 去掉选中连线分支 → `选中连线 + 选中节点时 Delete 只删线` 红。
6. `insertNodeOnEdge` 去掉 removeNode 回滚 → `spliceInsert 抛 → removeNode 被调用` 红。
7. `canInsertOnEdge` 返回 true → `数据线：插入节点… 置灰` 红。
8. stage_edge_layer 选中连线时不清节点选中 → `右键连线：…清空节点选中` 红。
9. `_handleNodeTap` 去掉清选中连线 → `点一张卡 → 选中连线清空` 红。
10. 改叙事↔数据后不 record `ChangeEdgeTypeCommand` → `叙事线改成参考后 undo` 红。
11. 插入成功后不 record `InsertOnEdgeCommand` → `插入：…撤销栈深 +1` 红。

## 验收
- 主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas test/theme/components --exclude-tags golden`，逐条做上表变异。
- 截图场景（widget = CanvasView，FakeNodes：图像配置「成片」+ 视频配置「镜头 02」，一条 data firstFrame 边；视频配置的供应商 fakeVideoCapabilities 设 supportsLastFrame=false）：①选中连线时中点工具条；②右键菜单 + 展开的改语义子菜单（首帧打勾、尾帧「模型不支持」置灰）；③换成两张配置节点间的叙事线，菜单里「插入节点…」可点，点开后的插入菜单。

## 风险与不确定
- `ink_menu_panel.dart` 不在约定表的本片名单里，但同波无人占用；若主 Agent 不同意，退而在 edge_menu_entries 里把原因拼进 label（「尾帧 · 模型不支持」），测试改断言 label。已在回报里提出。
- （复核已定）签名都已在上面写死：W1 `spliceInsert(edgeId, newNodeId) → SpliceApplied?` / `applySplice` / `invertSplice` / `makeRoomShifts` / `changeEdgeType`，W5 `EdgeEnds` / `findEdgeByEnds` / `setRoles` / `ChangeEdgeRoleCommand` / `edgeKindStepLabel`，W3 `deleteEdgeWithUndo`。
- 插入是三步（建节点、拼接事务、让位）：拼接失败回滚节点，让位失败不回滚（只是挤在一起），撤销命令按两端找边复原。
- （复核已定）esc-ladder 已把 Delete 的回调搬进 `shortcuts/core_canvas_keys.dart`（公开顶层函数），本片只改那一个函数，已列入允许清单。
