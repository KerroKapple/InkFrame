# node-disabled-flag · 节点停用 / 启用
- 波次 W8 / lane A / 基底：origin/main（W0–W7 已合入）；依赖切片：menu-split（W0，`menu_registry.dart` 的 `CanvasMenuItemDef` / `kCanvasMenuItems`）、esc-ladder（W0，`canvas_key_binding.dart` 的 `CanvasKeyBinding` / `CanvasKeyGate` 与 `kCanvasKeyRegistry`）、nodes-batch-ops（W1，patchTypeConfigMany / replaceTypeConfig）、undo-stack（W0，`CanvasCommand` / `canvasHistoryControllerProvider.record`）、undo-params（W5，`inspectorRevisionProvider` / `settle()` 与「缺键撤销时删键」算法）、tc-stale-marks（W7，node_card.dart 前一手）；阻塞决定：无（ContextMenus W2 → A「只在批量运行时跳过」；KeyMap Q4 → B Shift D（主 Agent 已准许本片新建 disable_keys.dart）；canvas_command.dart 不扩权，沿用通用标签）

## 目标（用户看到什么变化，2–4 行）
节点右键菜单多一项「停用 / 启用」。停用后卡片图区盖一层斜条纹、内容变淡，状态行写「已停用」；左栏大纲那一行行尾也写「已停用」。
停用只是「批量运行先别花钱」的标记：单独点生成、Ctrl ↵、序列、导出照常；连线一条不动。一次操作算一步撤销。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/ContextMenus.dc.html` ›「停用 · 切线」（P2）：`type_config.disabled = true`（JSONB，不迁移）；卡片条纹 + 内容降透明度，状态行「已停用」；节点右键「停用 / 启用」；连线保留；运行对话框列「跳过 · 已停用」（该行归 TakesCost 片，不在本片）。
- 同板「需要你定」W2 → 建议 A：只在批量生成时跳过；单独生成、序列、导出照常。
- 生成脚本 `b2_wires.js` 第 263–272 行：条纹 `135°`、6px 实 / 6px 空、白 α 0.06；内容 `opacity: 0.4`；状态字 10px fg5。
- `b2/project/KeyMap.dc.html` Q4 → 建议 B（Shift D）；多选时「有启用的就全停，否则全启，一步撤销」——这条切换规则本片在菜单上照做。
- revise-summary.txt「节点右键补项」：顺序 … · 停用 · 删除（停用紧挨删除之前）。
- 设计缺口：停用节点正在生成（单独生成被允许）时状态行写什么——板没画。本片定：有活动 job 时按 job 报（进行中 / 排队中），job 结束后回到「已停用」。
- 设计缺口：哪些节点能停用——板只画了视频配置。本片定：只有 image / video 的配置节点（批量运行只跑这两种）；镜头 / 文本 / 产物不可停用，菜单项对它们置灰。
- 设计缺口：停用操作本身没有提示卡 / 胶囊；本片不弹（卡片外观即反馈），只在失败时弹错误卡。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/models/canvas_node_disabled.dart`（新）：`kNodeDisabledKey`、extension `CanvasNodeDisabled`（`isDisabled`、`canBeDisabled`）。
- `lib/features/canvas/util/canvas_disable_actions.dart`（新）：纯判据 `disableToggleFor` + 动作 `toggleNodesDisabled`（patchTypeConfigMany + 推一步撤销 + 失败卡）。
- `lib/features/canvas/models/commands/patch_nodes_type_config_command.dart`（新，**独立成文件**，按 undo-stack 约定「具体命令在 models/commands/<x>_command.dart 各自成文件」，不是 `part of`，不改 canvas_command.dart）：多节点版 type_config 命令 `PatchNodesTypeConfigCommand`。W5 的 `PatchTypeConfigCommand` 只收单个 nodeId、且必须带 `ParamEditField`，W0–W7 也没有组合命令，所以由本片补这一个；W9 multi-select-inspector 复用它，不再另建。
- `lib/features/canvas/widgets/canvas_menu/disable_menu_entries.dart`（新）：`final List<CanvasMenuItemDef> disableNodeMenuItems`（menu-split 的条目形状：id `node.toggleDisabled`、scope `CanvasMenuScope.node`、**group 80**、order 10——menu-split 头注的分组约定「节点 10 做 / 20 take / 30 归类·定位 / 80 停用 / 90 删除」，自然排在删除组之前）。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（由 menu-split 新建）：`kCanvasMenuItems` 只追加一行 `...disableNodeMenuItems,`。
- `lib/features/canvas/widgets/shortcuts/disable_keys.dart`（新，主 Agent 准许）：`CanvasToggleDisabledIntent` + Shift D activator + `final List<CanvasKeyBinding> disableKeys`（esc-ladder `shortcuts/canvas_key_binding.dart` 的绑定形状）；作用于选中集，走 `toggleNodesDisabled`。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（由 esc-ladder 新建）：`kCanvasKeyRegistry` 只追加一行 `...disableKeys,`。
- `lib/features/canvas/widgets/node_card.dart`：`NodeStatusKind` 加 `disabled`；`nodeStatusOf` 加停用分支（第 491–523 行一带，行号为 f64f56e，以落地为准）；`_StatusRow` 的 switch 加文案；图区（第 335–347 行 `_NodeBody` 外）包一层透明度 + 条纹覆盖层（新私有 `_DisabledStripesPainter`）。
- `lib/features/canvas/widgets/left_rail/outline_panel.dart`：`_StatusBadge`（第 383–441 行）加 `NodeStatusKind.disabled` 分支（fg6 字「已停用」）。
- `lib/theme/tokens.dart`：只追加 `class InkDisabledNode`（常量：contentOpacity、stripeAlpha、stripeWidth、stripeGap、stripeAngle）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- align-distribute-arrange：`util/node_arrange.dart`、`util/canvas_arrange_actions.dart`、`shortcuts/arrange_keys.dart`、`canvas_menu/align_menu_entries.dart`。
- wrap-in-lane：`providers/canvas_lanes_controller.dart`、`util/lane_wrap.dart`、`util/canvas_wrap_actions.dart`、`models/commands/wrap_in_lane_command.dart`、`shortcuts/wrap_lane_keys.dart`、`canvas_menu/wrap_lane_menu_entries.dart`、`models/canvas_command.dart`（W8 只有 wrap-in-lane 能改）、`lib/features/app_actions/app_action_catalog.dart` 的「包成泳道」行；W7 的 `widgets/lane_title_bar.dart` / `providers/lane_rename_controller.dart` 本波谁都不改。
- clipboard-text-paste：`util/canvas_paste_actions.dart`、`util/clipboard_snapshot.dart`、`widgets/shortcuts/clipboard_keys.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`。
- job-timing：`lib/services/job_queue_service.dart`、`lib/core/di/job_queue.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`lib/features/notifications/widgets/job_notification_listener.dart` 及其新文件（`lib/core/interfaces/job_timing_source.dart`、`lib/services/job_queue/job_timing.dart`、`lib/core/di/job_timing.dart`）。
- 全波禁区：`util/canvas_tool_actions.dart`、`util/node_menu_model.dart`（`isGenerableNode` / `generationTarget` 一字不改）、`canvas_menu/node_menu_entries.dart`、`canvas_menu/blank_menu_entries.dart`、`canvas_menu/create_menu_entries.dart`、`util/create_menu_model.dart`、`widgets/canvas_shortcuts.dart` 骨架、`shortcuts/canvas_shortcut_registry.dart` / `canvas_menu/menu_registry.dart` / `lib/features/app_actions/app_action_catalog.dart` 除追加一行外的内容、`widgets/canvas_view.dart` 及 `widgets/stage/*.dart`（含 `stage/node_card_slot.dart`）、`providers/canvas_nodes_controller.dart`、`models/canvas_node.dart`、`models/canvas_command.dart`、`models/commands/` 下已有的命令文件（只 import）、`lib/features/generation/**`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// models/canvas_node_disabled.dart
const String kNodeDisabledKey = 'disabled';
extension CanvasNodeDisabled on CanvasNode {
  bool get isDisabled;      // typeConfig['disabled'] == true；其余（缺键 / false / null / 非 bool）都是 false
  bool get canBeDisabled;   // role == config && type ∈ {image, video}
}

// util/canvas_disable_actions.dart
enum DisableToggle { disable, enable }
/// 目标里能停用的节点为空 ⇒ null（菜单置灰）；其中有任一张未停用 ⇒ disable；全停用 ⇒ enable。
DisableToggle? disableToggleFor(List<CanvasNode> targets);
/// 只改 canBeDisabled 的节点；patchTypeConfigMany 一个事务写 {'disabled': true/false}；成功后
/// canvasHistoryControllerProvider(canvasId).notifier.record(PatchNodesTypeConfigCommand(...)) 推一步。
Future<void> toggleNodesDisabled(BuildContext context, WidgetRef ref, {required String canvasId, required Set<String> nodeIds});

// models/commands/patch_nodes_type_config_command.dart（独立文件；签名照 undo-stack 的 CanvasCommand）
final class PatchNodesTypeConfigCommand extends CanvasCommand {
  PatchNodesTypeConfigCommand({   // canvasId 从 CanvasCommandEnv 取（与 W5 PatchTypeConfigCommand 同）
      required Map<String, Map<String, Object?>> before, required Map<String, Set<String>> beforeAbsent,   // nodeId → 键 → 旧值 / 原来没有的键
      required Map<String, Map<String, Object?>> after,  required Map<String, Set<String>> afterAbsent,
      required String Function(AppLocalizations l) labelOf});
  @override String label(AppLocalizations l) => labelOf(l);
  @override Set<String> get affectedNodeIds;               // before.keys
  @override Future<CanvasCommandOutcome> revert(CanvasCommandEnv env); // 见下
  @override Future<CanvasCommandOutcome> apply(CanvasCommandEnv env);
}
// revert：对此刻还在节点表里的 id，先 await inspectorSubmitControllerProvider(id).notifier.settle()（W5，ref.exists 时才调），
//   再按 W5 PatchTypeConfigCommand 同一算法（现值上：before 的键写回、beforeAbsent 的键删掉、别的键不动）逐个
//   CanvasNodesController.replaceTypeConfig(id, full)（W1）；每个节点 inspectorRevisionProvider(id) +1（W5）。
//   一个都不在 ⇒ gone；任一 InkError ⇒ failed（已写的不回退——W1 没有多节点 replace，逐节点写不是一个事务，写进风险）。
// apply：同上换成 after / afterAbsent。

// widgets/shortcuts/disable_keys.dart
class CanvasToggleDisabledIntent extends Intent { const CanvasToggleDisabledIntent(); }
abstract final class DisableKeys { static const SingleActivator toggle = SingleActivator(LogicalKeyboardKey.keyD, shift: true, includeRepeats: false); } // 两个平台同键（mac 显示 ⇧D）
final List<CanvasKeyBinding> disableKeys; // id 'canvasToggleDisabled'；gate: CanvasKeyGate.notEditingText（esc-ladder 的门槛枚举，即原 _EditingAwareAction 语义）；
// group: ShortcutGroup.edit；label: (l) => l.settingsShortcutCanvasToggleDisabled；onInvoke：选中为空或 disableToggleFor == null ⇒ 不执行，否则 toggleNodesDisabled。

// widgets/node_card.dart
enum NodeStatusKind { running, queued, done, pending, ready, draft, disabled }
// nodeStatusOf 签名不变；判序：活动 job > 停用（仅 config）> 原有分支。

// lib/theme/tokens.dart（追加）
class InkDisabledNode { static const double contentOpacity = 0.4; static const double stripeAlpha = 0.06; static const double stripeWidth = 6; static const double stripeGap = 6; static const double stripeAngleDeg = 135; }
```
- 条纹颜色 = `context.inkColors.fg1.withValues(alpha: InkDisabledNode.stripeAlpha)`（亮 / 暗主题都看得见，不写 Color 字面量）。
- 启用写 `disabled: false`（jsonb `||` 合并，不删键）；撤销由 PatchNodesTypeConfigCommand 还原旧值，原来没有这个键的撤销后删键（W5 规则）。
- 撤销步名：`labelOf = (l) => count 个节点里本次是停用 ? l.canvasCommandDisableNodes(n) : l.canvasCommandEnableNodes(n)`——命令独立成文件、标签由调用方给，不需要改 canvas_command.dart，所以不必再沿用「修改参数」。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. `isDisabled` 只认 `typeConfig['disabled'] == true`；`'true'` 字符串、`1`、null 都不算。
2. 卡片：`isDisabled` 时图区内容透明度 `InkDisabledNode.contentOpacity`，上盖 135° 条纹；标题行、继承行、端口、选中描边不变淡、可照常点选 / 拖动 / 连线。
3. 状态行：无活动 job 且停用 ⇒「已停用」（fg5）；有活动 job ⇒ 照旧「进行中 N% / 排队中」；job 进终态后回「已停用」。
4. 大纲：同一 `nodeStatusOf` 判据；停用优先于「完成 / 就绪 / 待填写」（名下有产物也写「已停用」）；进行中 / 排队中优先于停用。
5. 菜单项文案：`disableToggleFor` = disable ⇒「停用」，enable ⇒「启用」，null ⇒「停用」置灰。多选混合（有启用有停用）⇒「停用」，点了全部停用。
6. 目标里的镜头 / 文本 / 产物节点不写、不报错；只有它们 ⇒ 置灰。
7. 一次点击 = 一次 `patchTypeConfigMany`（一个事务）+ 撤销栈一步；Ctrl Z 一次全部复原，Ctrl Y 再全部停用。
8. 写库失败：控制器整批回滚（W1 规则），卡片不出现半停用；弹错误卡「停用失败」/「启用失败」；撤销栈不推步。
9. 停用不改 `isGenerableNode` / `generationTarget` / `generate_gate`：停用节点单选时提示词条「生成」、Ctrl ↵ / ⌘↵、右键「生成」都照常可点并能提交。
10. 停用不删、不改任何边；叙事链、序列视图、导出顺序与停用前一致。
11. 停用中的节点被单独生成：生成照常，状态按规则 3；产物节点不继承 `disabled`（生成侧不读这个键）。
12. 「复制一份」/ 粘贴照抄 typeConfig ⇒ 副本也是停用（本片不加特判，写进测试钉住现状）。
13. 节点被删后再撤销删除：`disabled` 随 typeConfig 一起回来。
14. 缩放到紧凑卡（< 0.6，只画类型图标）时条纹与降透明度照样盖在图区上。
15. 快捷键 Shift D（两个平台同键，Windows 显示「Shift D」、mac 显示「⇧D」）：作用于选中集，规则同菜单（有启用的就全停，否则全启，一步撤销）；选中为空或全是不可停用类型 ⇒ 不执行；`includeRepeats: false`，按住只切一次；焦点在输入框里时 Shift D 交给输入框（打出大写 D），画布不动。不与 Ctrl D（复制一份）冲突：必须不带 Ctrl / ⌘。
16. 菜单行「停用 / 启用」右侧显示 Shift D 的键位（从 activator 取，不另抄）。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| nodeStatusDisabled | Disabled | 已停用 |
| canvasNodeMenuDisable | Disable | 停用 |
| canvasNodeMenuEnable | Enable | 启用 |
| canvasNodeMenuDisableUnavailable | Only image and video config nodes can be disabled | 只有图像 / 视频配置节点能停用 |
| nodeDisableFailed | Couldn't disable nodes | 停用失败 |
| nodeEnableFailed | Couldn't enable nodes | 启用失败 |
| leftRailStatusDisabled | Disabled | 已停用 |
| settingsShortcutCanvasToggleDisabled | Disable / enable selected | 停用 / 启用选中 |
| canvasCommandDisableNodes（count:int） | {count, plural, =1{Disable 1 node} other{Disable {count} nodes}} | 停用 {count} 个节点 |
| canvasCommandEnableNodes（count:int） | {count, plural, =1{Enable 1 node} other{Enable {count} nodes}} | 启用 {count} 个节点 |

（菜单键沿用仓库现有前缀 `canvasNodeMenu*`（canvasNodeMenuDuplicate 等）；快捷键页文案沿用 `settingsShortcutCanvas*`；撤销步名沿用 W4–W7 的 `canvasCommand*`（canvasCommandEditParam / canvasCommandLinkEdge 等）。）

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/models/canvas_node_disabled_test.dart`（新）
  - `isDisabled 只认 true`：`{disabled:true}` → true；`false` / 缺键 / `'true'` / `1` / null → false。
  - `canBeDisabled`：image / video config → true；shot、text config、image result → false。
- `test/features/canvas/util/canvas_disable_actions_test.dart`（新）
  - `全未停用 → disable`、`全停用 → enable`、`混合 → disable`、`只有镜头/文本/产物 → null`、`空列表 → null`。
  - `toggle 一次只调一次 patchTypeConfigMany`：fake 控制器记录调用，断言 1 次、patch 只含能停用的节点、值为 true。
  - `成功推一步撤销`：history 栈深 +1；undo 后两张卡 `isDisabled` 回原值（含原本缺键的被删键）。
  - `写库失败不推步并弹错误卡`：fake 抛 InkError → 栈深不变、FakeToastService 收到「停用失败」。
- `test/features/canvas/models/commands/patch_nodes_type_config_command_test.dart`（新）：`revert 删掉原来没有的键、写回旧值、别的键不动`；`节点全不在 → gone`；`apply 回到 after`；`每个节点 inspectorRevision +1`。
- `test/features/canvas/widgets/node_status_disabled_test.dart`（新）
  - `停用 config 无 job → disabled`；`停用 + running → running`；`停用 + queued → queued`；`停用 + hasArtifact → disabled`；`未停用原口径不变`（抽样 ready / draft / done）。
  - `停用不影响 isGenerableNode / generationTarget`：停用且有提示词的 image config → `generationTarget([n]) == n`。
- `test/features/canvas/widgets/node_card_disabled_test.dart`（新，非 golden）
  - `停用卡状态行写「已停用」`；`图区有 Opacity(0.4) 祖先`（find.ancestor 查 Opacity.opacity == InkDisabledNode.contentOpacity）；`有条纹 CustomPaint`（按 painter 类型查）；`未停用卡没有条纹层`；`紧凑卡也有条纹`；`停用 + nodeActiveJob running → 「进行中」`。
- `test/features/canvas/widgets/left_rail/outline_disabled_status_test.dart`（新）：`停用且有产物的行尾写「已停用」`、`进行中优先`。
- `test/features/canvas/widgets/canvas_disable_shortcut_test.dart`（新）：`选中两张未停用 image config 按 Shift D → 都停用、栈深 +1`；`再按 → 都启用`；`一停一启按 Shift D → 全停`；`输入框有焦点时 Shift D 不切换`；`按住 Shift D 重复事件只切一次`；`Ctrl D 仍是复制一份、不停用`；`activator 为 includeRepeats: false 且不带 control / meta`；`空选中按 Shift D 不写库`。
- `test/features/canvas/widgets/canvas_disable_menu_test.dart`（新）：菜单行显示 Shift D 键位；右键单张未停用 image config → 有「停用」可点，点后卡状态行变「已停用」、Ctrl Z 复原；右键镜头节点 → 「停用」置灰；多选一停一启 → 显示「停用」；菜单里「停用」紧挨「删除」之前。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. `isDisabled` 改成 `typeConfig['disabled'] != null` → `isDisabled 只认 true` 红。
2. `nodeStatusOf` 里把停用分支挪到 job 分支之前 → `停用 + running → running` 红。
3. 去掉停用分支（停用节点走原 ready）→ `停用 config 无 job → disabled`、卡片 / 大纲文案用例红。
4. 停用分支放在 `hasArtifact` 之后 → `停用 + hasArtifact → disabled` 红。
5. `disableToggleFor` 混合时返回 enable → `混合 → disable` 红。
6. 循环里逐张调 `patchTypeConfig` 代替一次 `patchTypeConfigMany` → `toggle 一次只调一次` 红。
7. 不推撤销命令 → `成功推一步撤销` 红；失败分支也推 → `写库失败不推步` 红。
8. 在 `isGenerableNode` 加 `&& !n.isDisabled`（即便越界改了）→ `停用不影响 generationTarget` 红。
9. 去掉 Opacity 包裹或条纹层 → `node_card_disabled_test` 对应用例红。
10. `canBeDisabled` 放开到所有 config → `只有镜头/文本/产物 → null`、菜单置灰用例红。
11. Shift D 动作改成普通 CallbackAction（不对文字让位）→ `输入框有焦点时 Shift D 不切换` 红。
12. activator 去掉 `includeRepeats: false` → `按住 Shift D 只切一次` 与守卫用例红。
13. activator 去掉 `shift: true`（变成单键 D）→ `activator … 不带 control / meta` 守卫与 `Shift D` 用例红（单键 D 不触发 Shift D 的意图断言）。
14. 注册表那一行删掉 → `按 Shift D → 都停用` 红；菜单键位提示删掉 → `菜单行显示 Shift D 键位` 红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑：`flutter analyze lib test`；`flutter test test/features/canvas --exclude-tags golden`；上面 14 条变异逐条。
- 截图：`NodeCard`，数据 = 视频配置「镜头 04」提示词「夜色里渔火一点点亮起，镜头缓慢拉远。」；四个状态：未停用 / 停用 / 停用 + 进行中 42% / 停用 + 紧凑卡（缩放 0.5）；亮暗主题各一张。`OutlinePanel` 一组三行：已停用、进行中、完成。节点右键菜单两张：单张未停用（「停用」）、全停用多选（「启用」）。
- `node_card_golden_test` 不新增 golden 用例（golden 只在 CI 出基线）；现有 golden 必须不变（未停用卡外观零改动）。

## 风险与不确定
- Shift D：主 Agent 已准许本片新建 `shortcuts/disable_keys.dart` 并在注册表追加一行。mac 上 Shift D 不与系统键冲突；需确认 W7 mac-platform-menubar 的系统菜单没有绑 ⇧D。
- `menu_registry`：menu-split 已约定 group 80 = 停用、90 = 删除，本片的条目用 group 80 即排在删除之前，不需要挪别的行。
- 撤销命令：W5 `PatchTypeConfigCommand` 只收单节点且要 `ParamEditField`，W0–W7 没有任何组合命令，所以本片新建独立文件的 `PatchNodesTypeConfigCommand`（不碰 canvas_command.dart，符合主 Agent「canvas_command.dart 不扩权」的裁决）。W9 multi-select-inspector 复用它。
- 命令契约按 undo-stack：`String label(AppLocalizations l)`、`revert / apply(CanvasCommandEnv) → CanvasCommandOutcome`、canvasId 从 env 取；W4–W7 的派工单也已统一成这个形状（独立文件、无 `CanvasCommandLabel` 枚举）。落地若与契约不符，停下回报主 Agent，不自行改 canvas_command.dart。
- 撤销 / 重做是逐节点 `replaceTypeConfig`（W1 没有多节点整列覆盖，`patchTypeConfigMany` 是 jsonb `||` 合并、删不掉键），中途某个节点写失败会留下半步；按 failed 处理并出撤销失败胶囊（undo-shortcuts-ui 的现有口径）。
- node_card.dart 是 11 片长链：本片之前 W7 tc-stale-marks 刚改过状态行附近，rebase 时以落地为准，状态判序以本单规则 3 为准。
