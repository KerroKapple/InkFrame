# tc-set-current · 设为当前（固定 take）+ 进撤销栈

- 波次 W3 · lane C · 基底：叠在 current-take、menu-split、undo-stack 之后（W0–W2 全部合入后的 origin/main：含 W1 nodes-batch-ops、W1 canvas-capsule、W2 node-cost、W2 undo-shortcuts-ui，以及 W2 media-import-service 改过的 `node_card.dart`——本片是 node_card 链上 W2 之后的下一手）
- 依赖切片：current-take（`currentResultFor`、`CanvasNodeTake.pinnedResultId`、`pinnedBySource`）、menu-split（`menu_registry.dart`）、undo-stack（`CanvasCommand`、`canvasHistoryControllerProvider`、`EdgeEndpoints`）、nodes-batch-ops（`patchTypeConfigMany`）、canvas-capsule（`canvasCapsuleProvider`）
- **阻塞决定：TC-Q1 → A（按建议，改写边）**。本片只定撤销命令的形状：命令记「旧 pinned_result_id + 被挪的边」，边按两端（`EdgeEndpoints`）找、不按 id；**实际改写下游 data 边归 W5 tc-take-edge-follow**，本片命令**不**预留 `movedEdges` 字段：W4 tc-batch-slot-set-current 会把固定改成事务内写入（`writePinInScope` / `PinToken`），挪边信息由 W5 加进 `PinToken.movedEdges`，只此一份（主 Agent 跨批核对补充）。批量 slot 的「设为当前」归 W4 tc-batch-slot-set-current。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（已含上述前序切片）起分支 `feat/tc-set-current`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行——本片只在 `menu_registry.dart` 追加 `...setCurrentMenuItems,` 一行。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法；写固定走 `CanvasNodesController.patchTypeConfigMany`（一个事务、失败回滚内存）。
> - 新画布动作写进新文件；不碰 canvas_tool_actions.dart。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
满意的 take 可以「设为当前」：之后序列、导出、画廊、⌘K、大纲都用它，新 take 出来也不顶替它。入口三处：检查器「历史」页每行、成片检查器动作行最前、take 卡右键菜单。画布上当前 take 描边换琥珀色、固定时带图钉，其余 take 图区半透明，比当前新的标「未采用」。固定后又出了新 take，完成通知写「当前仍是 take N」并给「设为当前」。导出对话框里固定的那行标「固定」。一次设为当前 = 一步撤销。

## 设计依据
- **TakesCost.dc.html · 当前 take · 固定**：卡片「take 3 / 3 · 未采用」「take 2 / 3 · 当前」；注解「当前 take：琥珀描边 + 图钉 / 其余 take：图区半透明 /「未采用」= 比当前新，但当前是固定的」。历史页「镜头 01 的全部 take · 当前那张往下游流」，行「take 2 · 在用」+「设为当前」。规则：「固定的被删 → 回落最新；撤销删除时一起回来」「撤销：「设为当前」连同它改写的 data 边算一步（Q1 选 A 时）；反向按边两端的节点找边，不按边 id」「固定时出了新 take：通知写「当前仍是 take 2」+「设为当前」」「导出默认勾当前 take，行尾标「固定」」「成片检查器（已有 定位来源节点 / 在序列中定位 / 播放）加一个「设为当前」，是当前就显示打勾置灰」。
- **UndoClipboard.dc.html · 什么进栈**：「设为当前（含批量 slot），连同它改写的线 → 菜单名「设为当前 · take 3」」「「设为当前」和它改写的 data 边是一步；系统自动改写的边不进栈，所以反向找边一律按两端（下游节点 + 端口 + 上游所属配置节点）」「反馈只走画布底部胶囊」。critic 第 17 条同。
- **GapsPanels.dc.html · 产物检查器**：「预留：「设为当前」排动作行最前」。
- 按建议：TakesCost Q1 → A；Q2 → A（没固定时最新即当前，故「最新那张」的入口显示已是当前、置灰）；UndoClipboard Q3 → A（只影响 W4 slot 片）。
- **设计缺口**：① 没有「取消固定」入口，也就无法把「最新那张」钉住（它显示为已是当前、置灰）——板上没画，本片不做。② 当前 take 的琥珀描边与选中描边同为 `accent`，选中时无法区分——本片规定：选中优先，图钉仍画。③ 画布没打开时（节点控制器不在）新 take 到达，拿不到固定信息，通知照旧不写「当前仍是…」。④ 设为当前写库失败的错误卡文案没画，复用通用写失败文案。

## 允许改的文件
- `lib/features/canvas/providers/current_take_controller.dart`（新）：`currentTakeControllerProvider` + `CurrentTakeController.setCurrent`。
- `lib/features/canvas/models/commands/set_current_take_command.dart`（新）：`SetCurrentTakeCommand`。
- `lib/features/canvas/util/take_status.dart`（新，纯）：`ResultTakeStatus` + `resultTakeStatusOf`（卡片、导出、历史页共用的「当前 / 固定 / 未采用 / 第几个 take」判据，号走 `takeNumbersOn`）。
- `lib/features/canvas/widgets/canvas_menu/set_current_menu_items.dart`（新）：`setCurrentMenuItems`。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`：只追加一行 `...setCurrentMenuItems,`。
- `lib/features/canvas/widgets/inspector_history_panel.dart`：`_TakeRow` 加当前徽标（图钉 + 「当前」，固定时画图钉）与「设为当前」按钮；原 `current` 参数（= 选中高亮）改名 `highlighted`；头注第 12 行「稿上的图钉「固定」没有数据模型，不画」改写。
- `lib/features/canvas/widgets/result_inspector_parts.dart`：`ResultActions` 最前加「设为当前」；`_ActionButton` 加可选 `checked`（打勾 + 置灰）。
- `lib/features/canvas/widgets/image_result_inspector.dart` / `video_result_inspector.dart`：只在 `ResultActions` 需要新参数时跟改（预计不改；不改就别动）。
- `lib/features/canvas/widgets/node_card.dart`：result 卡按 `ResultTakeStatus` 画描边 / 图钉 / 半透明 / 状态行文案（第 275–277 行 `edge`、第 323–336 行图区、第 525–568 行 `_StatusRow`）。
- `lib/features/notifications/widgets/job_notification_listener.dart`：`_notifySucceeded`（第 84 行起）加「当前仍是 take N」body + secondary「设为当前」。
- `lib/features/export/widgets/export_video_dialog.dart`：第 271–274 行行尾标记改三态：当前且固定 →「固定」；比当前新 →「未采用」；其余非当前 →「旧 take」（原样）。
- 测试见「测试」。

## 不许碰的文件
- W3 undo-adopt-existing：`lib/features/canvas/util/canvas_node_delete.dart`、`lib/features/canvas/util/canvas_snackbars.dart`、`lib/features/canvas/widgets/stage/stage_edge_layer.dart`、`lib/features/canvas/widgets/stage/node_card_slot.dart`、`lib/features/canvas/widgets/node_inputs_section.dart`、它新建的 `models/commands/*`（本片只新建自己的 `set_current_take_command.dart`）。
- W3 marquee-select：`lib/features/canvas/widgets/stage/stage_pointer_layer.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/providers/canvas_tool_mode.dart`、`widgets/marquee_layer.dart`、`providers/canvas_marquee.dart`。
- W3 import-media-command：`shortcuts/import_media_keys.dart`、`util/canvas_import_actions.dart`、`canvas_menu/import_media_menu_items.dart`。
- W3 help-actions：`app_actions/help_actions.dart`、`left_rail/help_menu_popover.dart`、`left_rail/canvas_left_rail.dart`、`settings/widgets/diagnostics_section.dart`、`startup/widgets/startup_error_view.dart`、`services/github_update_check_service.dart`、`settings/providers/update_check_controller.dart`、`settings/providers/settings_page.dart`；`app_action_catalog.dart`（本片不加动作行）。
- 归 W4 tc-batch-slot-set-current：`lib/features/generation/providers/batch_results_controller.dart`、`lib/features/canvas/widgets/batch_results_grid.dart`、`lib/features/canvas/widgets/batch_compare_overlay.dart`。
- 归 W12 cm-multi-select-menu：`lib/features/canvas/util/node_menu_model.dart`（不改共享判据）；`canvas_menu/node_menu_entries.dart`（菜单项只走注册表）。
- 只读依赖：`canvas_nodes_controller.dart`、`canvas_history_controller.dart`、`canvas_command.dart`、`edge_endpoints.dart`、`node_artifacts.dart`、`take_numbers.dart`、`canvas_capsule.dart`。
- （主 Agent 自查补充）help-actions：`lib/core/constants/app_repo.dart`（新）、`lib/theme/components/ink_menu_panel.dart`（只加可选 `disabledReason`）、`lib/theme/primitives/ink_activatable.dart`（只加可选 `focusNode`）、`lib/features/settings/widgets/diagnostics_section.dart`、`lib/features/startup/widgets/startup_error_view.dart`、`lib/services/github_update_check_service.dart`。

## 具体改动
```dart
// models/commands/set_current_take_command.dart
// （不定义 MovedDataEdge——挪边归 W4 / W5 的 PinToken）
class SetCurrentTakeCommand extends CanvasCommand {
  const SetCurrentTakeCommand({required this.configNodeId, required this.previousPinnedResultId,
      required this.pinnedResultId, required this.takeNumber});
  final String configNodeId; final String? previousPinnedResultId; final String pinnedResultId;
  final int? takeNumber;            // null = 名下只有一个（「成片」）
  @override String label(AppLocalizations l);          // takeNumber 有 ⇒ l.canvasCommandSetCurrentTake(n)，否则 l.takeSetCurrent
  @override Set<String> get affectedNodeIds;            // {configNodeId, pinnedResultId}
  @override Future<CanvasCommandOutcome> revert(CanvasCommandEnv env); // 配置节点不在 ⇒ gone；patch pinned=previous（null 写 JSON null）
  @override Future<CanvasCommandOutcome> apply(CanvasCommandEnv env);  // 配置或 pinnedResult 不在 ⇒ gone；patch pinned=pinnedResultId
}

// util/take_status.dart
typedef ResultTakeStatus = ({int? number, int total, bool current, bool pinned, bool notAdopted});
/// result 节点在同源兄弟里的状态；孤儿 / 非 result / 无产物 url ⇒ null。total = resultsFor 的个数。
ResultTakeStatus? resultTakeStatusOf(CanvasNode result, List<CanvasNode> nodes);

// providers/current_take_controller.dart
enum SetCurrentTakeOutcome { done, alreadyCurrent, noSource, failed }
final currentTakeControllerProvider = Provider.autoDispose.family<CurrentTakeController, String>(...); // by canvasId
class CurrentTakeController {
  /// 找 result 的来源配置 → 已是当前则 alreadyCurrent → patchTypeConfigMany({config: {pinned_result_id: id}})
  /// → record(SetCurrentTakeCommand) → 胶囊 CanvasCapsuleMessage(text: 步名, kind: action, actionLabel: l.commonUndo, actionHint: 本平台撤销键串,
  ///   onAction: runCanvasUndoStep(ref.read, canvasId:, stepId:, l:, isMac:))——W2 undo-shortcuts-ui 的执行口，内部 undoSpecific 并统一出胶囊 / 失败卡。
  /// 写失败：内存已由 patchTypeConfigMany 回滚，出错误卡（ToastKind.error），不入栈，返回 failed。
  Future<SetCurrentTakeOutcome> setCurrent(String resultNodeId, {required AppLocalizations l});
}

// canvas_menu/set_current_menu_items.dart
final List<CanvasMenuItemDef> setCurrentMenuItems; // 一项：id 'take.setCurrent'，scope node，group 20（take 组），order 10
```
- 菜单项 `build`：`targets.length == 1` 且目标是 result、`resultTakeStatusOf` 非 null、来源配置节点在画布上，否则 null（不出现）；已是当前 ⇒ `checked: true, enabled: false`。`run` = `setCurrent`。
- 进行中保护：`setCurrent` 期间持 `ref.keepAlive()`，结束 close（同 inspector_submit_controller 的写法）。

## 行为规则与边界情况
1. 点非当前 take 的「设为当前」：配置节点 `type_config.pinned_result_id` = 它；序列 / 导出默认勾选 / 画廊 / ⌘K / 大纲立即跟随（current-take 已接好）。
2. 已是当前（含「没固定、它是最新」）：三处入口都打勾置灰；直接调 `setCurrent` 返回 alreadyCurrent，不写库、不入栈。
3. 来源配置已删 / 孤儿产物：菜单项不出现；历史页行不画按钮；动作行按钮置灰；`setCurrent` 返回 noSource。
4. 写库失败：内存回滚、出错误卡、不入栈、不出胶囊；再点一次可重试。
5. 成功：入撤销栈一步，名「设为当前 · take N」（只有一个时「设为当前」）；胶囊同文案 +「撤销」，点撤销 = `runCanvasUndoStep(…, stepId:)`（内部 `undoSpecific(stepId)`；不要直接调控制器，否则 gone / failed 的反馈与 Ctrl Z 不一致）。
6. Ctrl Z：pinned 回到旧值（旧值缺省则写 null = 没固定 → 回落最新）；Ctrl Y / ⇧⌘Z 重做再设回。
7. 撤销时配置节点已删 → `gone`，「这一步已无法撤销」，不连带撤下一步；旧固定 take 已删 → 仍 `done`（判据回落最新）。重做时新固定 take 已删 → `gone`。
8. 撤销 / 重做不碰任何边；W5 改写下游 data 边时，挪动的边记在 W4 抽出的 `PinToken.movedEdges` 里，命令本身不带边（主 Agent 跨批核对补充）。
9. 快速连点两个不同 take：两次写经 `CanvasNodesController` 串行，栈里两步，最终是后点的那个。
10. 卡片：同源 ≥ 2 个 take 时，当前那张描边 `accent`（未选中时）、固定时右上角 `InkGlyph.pin`；非当前图区 `Opacity(0.5)`；状态行写 `l.takeCardCaption(n, total)`，当前写 `l.takeCardCaptionCurrent(n, total)`，比当前新且当前是固定的写 `l.takeCardCaptionNotAdopted(n, total)`；只有一个 take 的卡不变。
11. 卡片订阅用 `canvasNodesControllerProvider(canvasId).select((v) => resultTakeStatusOf(node, v.valueOrNull ?? const []))`——记录结构相等，兄弟状态不变时不重建。
12. 新 take 到达（JobSucceeded）：来源配置在内存、有固定且固定 take 活着且 ≠ 新 result ⇒ 完成卡 body = `l.jobNotifyStillCurrentTake(n)`（n = `takeNumbersOn(nodes)[pinned] ?? 1`——新 result 还没进内存时固定那张若是唯一一张就是 take 1），secondary = `l.takeSetCurrent` → `setCurrent(job.resultNodeId)`；没固定 / 画布不在内存 ⇒ 卡片与今天一样。
13. 导出对话框：固定的当前 take 行尾「固定」；比当前新的行「未采用」；更旧的仍「旧 take」；勾选默认值仍由 `currentTakeNodeIds` 定（current-take）。
14. 历史页：当前那行缩略左侧画图钉（固定时）并写「当前」；其他行右侧「设为当前」按钮（InkActivatable，可 Tab / 回车）；点按钮不触发行的「单选 + 居中」。
15. mac / Windows：撤销键位由 W2 undo-shortcuts-ui 提供，本片不加键；菜单 keyHint 不写（「设为当前」无快捷键，P 键未分配）。

## 新文案键
| key | en | zh |
|---|---|---|
| `takeSetCurrent` | `Set as current` | `设为当前` |
| `takeCurrentBadge` | `Current` | `当前` |
| `takePinnedBadge` | `Pinned` | `固定` |
| `takeNotAdopted` | `Not used` | `未采用` |
| `takeCardCaption`（number: int, total: int） | `take {number} / {total}` | `take {number} / {total}` |
| `takeCardCaptionCurrent`（number, total） | `take {number} / {total} · current` | `take {number} / {total} · 当前` |
| `takeCardCaptionNotAdopted`（number, total） | `take {number} / {total} · not used` | `take {number} / {total} · 未采用` |
| `canvasCommandSetCurrentTake`（number: int；步名键统一 canvasCommand* 前缀，原拟 undoSetCurrentTake，主 Agent 跨批核对改名） | `Set as current · take {number}` | `设为当前 · take {number}` |
| `jobNotifyStillCurrentTake`（number: int） | `Current is still take {number}` | `当前仍是 take {number}` |

（导出「固定」「未采用」用 `takePinnedBadge` / `takeNotAdopted`，不另开键。）

## 测试
- `test/features/canvas/util/take_status_test.dart`（新）：`'没固定：最新是当前，其余非当前，无 notAdopted'`；`'固定旧的：它 current+pinned，更新的 notAdopted，更旧的都不是'`；`'固定的被删（不在 nodes）→ 回落最新为当前'`；`'只有一个 take：number null、total 1、current'`；`'孤儿 / 非 result → null'`。
- `test/features/canvas/models/commands/set_current_take_command_test.dart`（新，用 ProviderContainer + 假节点仓库）：`'label：有号「设为当前 · take 3」，无号「设为当前」'`；`'revert 写回旧 pinned；旧值缺省写 null'`；`'revert：配置节点已删 → gone'`；`'apply：新固定 take 已删 → gone'`；`'movedEdges 默认空，revert 不调边控制器'`。
- `test/features/canvas/providers/current_take_controller_test.dart`（新）：`'setCurrent：写 pinned_result_id、入栈一步、出胶囊'`；`'已是当前 → alreadyCurrent，不写库不入栈'`；`'来源配置不在 → noSource'`；`'写库失败 → 内存回滚、错误卡、不入栈'`；`'Ctrl Z（history.undo）→ pinned 回旧值；redo 再设回'`；`'胶囊「撤销」= undoSpecific 这一步'`。
- `test/features/canvas/widgets/inspector_history_panel_test.dart` 追加：`'当前那行写「当前」，固定时带图钉'`；`'非当前行有「设为当前」，点它固定且不改选中'`。
- `test/features/canvas/widgets/canvas_node_menu_test.dart` 追加：`'右键非当前 take 卡：take 组出「设为当前」，点了固定'`；`'右键当前 take：「设为当前」打勾置灰'`；`'右键配置卡：没有「设为当前」'`（现有「六项按稿的顺序」用例不改仍绿）。
- `test/features/canvas/widgets/video_result_inspector_test.dart` 追加：`'动作行第一个是「设为当前」；已是当前时置灰'`。
- `test/features/canvas/widgets/node_card_take_test.dart`（新）：`'固定旧 take：它描边 accent + 图钉，更新的那张状态行「未采用」且图区半透明'`；`'没固定：最新那张写「当前」、无图钉'`。
- `test/features/notifications/widgets/job_notification_listener_test.dart` 追加：`'固定了 take 2 后新 take 完成：body「当前仍是 take 2」+「设为当前」，点了固定新 take'`；`'没固定：卡片与原来一样（无 body、无 secondary）'`。
- `test/features/export/widgets/export_video_dialog_test.dart` 追加：`'固定的当前行标「固定」，更新的行标「未采用」，更旧的仍「旧 take」'`。

## 变异点
1. `setCurrent` 不判已是当前 → `'已是当前 → alreadyCurrent…'` 红。
2. 成功后不 `record` → `'setCurrent：写 pinned_result_id、入栈一步…'`、`'Ctrl Z（history.undo）…'` 红。
3. 写失败仍入栈 → `'写库失败 → 内存回滚、错误卡、不入栈'` 红。
4. `revert` 写成删除固定而不是写回旧值 → `'revert 写回旧 pinned…'` 红。
5. `revert` 配置节点不在时返回 done → `'revert：配置节点已删 → gone'` 红。
6. `resultTakeStatusOf` 的 notAdopted 不看「当前是固定的」→ `'没固定：…无 notAdopted'` 红。
7. 菜单项对已是当前不置灰 → `'右键当前 take：「设为当前」打勾置灰'` 红。
8. 菜单项对配置卡也出 → `'右键配置卡：没有「设为当前」'` 红。
9. 通知不看固定 / 号取错（不 `?? 1`）→ `'固定了 take 2 后新 take 完成…'` 红。
10. 卡片不画图钉 → `node_card_take_test` `'固定旧 take：它描边 accent + 图钉…'` 红。
11. 导出行尾不分「未采用」→ `export_video_dialog_test` 新用例红。
12. 历史页按钮点击冒泡到行（改了选中）→ `'非当前行有「设为当前」，点它固定且不改选中'` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas test/features/notifications test/features/export`；上面 12 条变异。
- 截图（主 Agent 用测试 harness 截）：画布一张图像配置 + 3 个 take，固定 take 2：① 舞台局部（三张 take 卡：take 2 琥珀 + 图钉、take 3「未采用」半透明、take 1 半透明）；② 检查器历史页；③ take 3 卡右键菜单；④ 成片检查器动作行（take 2 选中，「设为当前」打勾置灰）；⑤ 新 take 完成卡「当前仍是 take 2」。

## 风险与不确定
- 本片已接近 L 上限：若超 ~1500 行，按 plan 把 `job_notification_listener.dart` 的通知改动与导出「固定 / 未采用」标签拆成一个 S 片（tc-set-current-notify），主片先合。
- 偏离约定：多建一个纯函数文件 `util/take_status.dart`（卡片 / 导出 / 历史页共用判据，避免三处各算一遍）。
- ⌘K 导出入口若仍未走 `openExportVideoDialogForCanvas`（见 current-take 风险），那条路径上「固定」标签不出——验收时用导出标签入口截图。
- 全卡片 `select` 每次节点变化都会对每张 result 卡跑一遍 `resultsFor`（O(n²)）；几百张卡内可接受，若 `node_card_golden_test` / 性能基线有回退再收成一个按画布缓存的 provider。
