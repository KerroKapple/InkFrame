# node-menu-append-chain · 节点右键补「新建下一镜 Ctrl→」与「加入叙事链末尾」（多选按位置依次接上，一个事务、一步撤销）
- 波次 W11 / lane B / 基底：origin/main（W0–W10 已合入）；依赖切片：next-shot（W10，`nextShotControllerProvider(canvasId).createNextShot` / `isBusy`，绑定 id `canvasNextShot`）、narrative-splice（W1，`CanvasEdgesController.applySplice(SplicePlan)` → `SpliceApplied{token}`、`invertSplice`）、canvas-capsule（W1）、menu-split（W0，`CanvasMenuItemDef` / `kCanvasMenuItems`，分组约定 10 做 / 30 归类·定位）、undo-edges（W5，标签键 `canvasCommandLinkEdge` / `canvasCommandEdgeKindNarrative`；它的 `AddEdgeCommand` 只装单边，本片另建多边命令）、esc-ladder（W0，`canvasBindingLabel`）；阻塞决定：KM-Q1 / GC-N3 → A（随 next-shot）；N5 → A（只连线不挪位置）

## 目标（用户看到什么变化，2–4 行）
画布节点右键菜单多两项：「新建下一镜 Ctrl→」（与快捷键、拖线菜单同一条路）和「加入叙事链末尾」。
后者把选中的、还没入链的镜头 / 图像 / 视频配置（选中产物就取它的来源配置）按位置依次接到叙事链最后一镜后面；画布还没有链时，多选就连成一条新链。只连线、不挪卡片，完成后底部胶囊「已接到第 N 镜之后」，Ctrl Z 一步撤回。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/GapsCanvas.dc.html` ›「节点右键补项 · 右键一张不在链上的图像配置」：
  - 菜单示意：生成 Ctrl ↵ · 新建下一镜（新）Ctrl → · 复制一份 Ctrl D | 设为当前 · 当下一镜的首帧 ›（TakesCost）| 存为角色 · 加入泳道 › · 加入叙事链末尾（新）| 在序列中定位 · 在画廊中定位 | 停用（ContextMenus）· 删除 Del。
  - 分组：做 | take | 归类 | 定位 | 停用 · 删除；不可用的置灰不隐藏，悬停说原因。
  - 加入叙事链末尾：目标里**不在链上的**镜头 / 图像 / 视频配置（产物取来源配置）；末尾 = orderByNarrativeChain 只留链上节点后的最后一个。
  - 多选按位置（先主轴再横截轴）依次接上：末尾 → a → b；一个事务、撤销一步；不挪位置（N5 建议 A：「位置决定泳道，一挪可能换道换风格；要整齐用『整理叙事链』」）。
  - 画布还没有链：单选置灰「还没有叙事链」，多选就按位置连成一条新链；胶囊「已接到第 7 镜之后」。
- `b2/project/GapsCanvas.dc.html` ›「新建下一镜」：三个入口一条路（Ctrl→、拖线菜单、节点右键）——右键这一项调 next-shot 的 createNextShot。
- 代码核对：现有节点菜单分组（`create_node_menu.dart` 第 621–680 行，W0 搬进 node_menu_entries / menu_registry）：[生成, 复制一份] | [存为角色, 加入泳道 ›, 在序列中定位] | [删除]。目标集判据 `nodeMenuTargets`（`util/node_menu_model.dart`）：右键的卡在选中集里 = 整个选中集。
- 代码核对：链判据 `narrativeChainMembers`（`util/outline_model.dart` 第 34 行，narrative 边两端都在场）；顺序 `orderByNarrativeChain(nodes:, edges:, include:)`（`util/narrative_order.dart` 第 27 行）；镜号 `sequenceShotNumbers`（outline_model.dart，与大纲 / 序列 / ⌘K 同号）；锚点 `narrativeAnchorOf`、序号 `nextNarrativeSortOrder`（`util/create_menu_model.dart`）。
- 「已在链上的怎么处理」按画板字面：只取不在链上的；已在链上的跳过不动（不摘出、不重排——重排是 W13 outline-drag-reorder / 拖到线上插入的事）。
- 设计缺口：目标全都已在链上 / 全是文本或孤儿产物时置灰原因没画。本片定两句原因（见文案表）。
- 设计缺口：部分已在链上时胶囊要不要说跳过了几个没画。本片定：胶囊后缀「· 跳过 N 个已在链上的」。
- 设计缺口：链尾那一镜没有镜号（链上但序列折叠时被跳过的空节点）时「第 N 镜」写什么没画。本片定：改写「已接到「名字」之后」。
- 设计缺口：新链（画布原本无链）完成后的胶囊文案没画。本片定「已连成新叙事链 · N 镜」。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/util/append_to_chain.dart`（新，纯函数）：链尾、候选、置灰原因、连线计划。
- `lib/features/canvas/util/canvas_append_chain_actions.dart`（新）：`appendTargetsToChain`（读现值 → 计划 → `applySplice` → 推撤销步 → 胶囊 / 错误卡）与 `nextShotFromMenu`（调 `nextShotControllerProvider(canvasId).createNextShot`）。
- `lib/features/canvas/models/commands/append_chain_command.dart`（新，独立成文件，按 undo-stack 约定；不改 canvas_command.dart）：`AppendChainCommand`。W5 的 `AddEdgeCommand` 只装一条边，多条边算一步没有现成命令；narrative-splice 约定「W5 的命令用 `invertSplice` 撤」，但 W5 实际没建这种命令，由本片补。
- `lib/features/canvas/widgets/canvas_menu/append_chain_menu_entries.dart`（新）：`final List<CanvasMenuItemDef> appendChainNodeMenuItems`，两条（menu-split 的条目形状，build 出 `InkMenuEntry<String>`、run 收 `CanvasMenuContext`）：
  - id `node.nextShot`，scope node，group 10（做），order 15（生成 10 之后、复制一份 20 之前）；keyHint = `canvasBindingLabel('canvasNextShot', isMac:)`（esc-ladder，W10 next-shot 的绑定 id）。
  - id `node.appendToChain`，scope node，group 30（归类·定位），order 25（加入泳道 › 20 之后、在序列中定位 30 之前）。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（注册表例外，主 Agent 已准许本片追加两行、每项一行）：`kCanvasMenuItems` 追加 `...appendChainNodeMenuItems,`（一行装两条也行，主 Agent 的两行配额不用满）；不改任何既有行。
- 测试：见「测试」小节的 3 个新文件。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- `widgets/canvas_inspector_panel.dart`、`widgets/result_inspector_parts.dart`、`widgets/video_result_inspector.dart`、`widgets/image_result_inspector.dart`、`lib/theme/icons/ink_glyph.dart`（result-inspector-align，同 lane 下一片）。
- 新 `widgets/batch_run_dialog.dart`、`util/canvas_batch_run_actions.dart`、Ctrl ↵ 核心键文件、`widgets/canvas_toolbar.dart`、`widgets/left_rail/outline_panel.dart`、`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`（batch-run-dialog）。
- `lib/features/storyboard/providers/script_import_controller.dart`、`util/script_splitter.dart`、`widgets/script_import_dialog.dart`（script-import）。
- `lib/features/generation/generation_controller.dart`、`lib/services/import/import_remapper.dart`、`util/clipboard_snapshot.dart`、`lib/features/generation/services/prompt_assembler.dart`（mention-token-core）。
- `lib/features/notifications/widgets/toast_layer.dart`、`notification_bell.dart`、`providers/toast_center.dart`、`lib/theme/components/ink_toast_card.dart`、`lib/features/settings/util/shortcut_catalog.dart`（f6-notification-region）。
- `providers/canvas_edges_controller.dart`（addEdgesInTx 已在 W1，不再改）、`util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_menu/blank_menu_entries.dart`、`canvas_menu/create_menu_entries.dart` / `util/create_menu_model.dart`、`util/next_shot.dart` / `providers/next_shot_controller.dart`（W10 已定型，只调用）、`models/canvas_command.dart`、`widgets/canvas_shortcuts.dart` 骨架与注册表。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：f6-notification-region：`lib/features/settings/widgets/shortcuts_section.dart`、新 `lib/features/notifications/widgets/notification_region.dart`；batch-run-dialog 与 f6 都在 `app_action_catalog.dart` / `app_action_ids.dart` / `util/more_menu_model.dart` 追加行（本片不碰）；result-inspector-align 追加 `lib/theme/tokens.dart`；script-import 新 `lib/features/storyboard/util/duration_estimate.dart`；mention-token-core 新 `lib/core/text/character_mention.dart`；`models/commands/` 下已有命令文件只 import。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/append_to_chain.dart
enum AppendChainBlock { none, noChain, allChained, noEligible }
typedef AppendChainLink = ({String sourceId, String targetId, int sortOrder});
@immutable class AppendChainPlan {
  final String? tailId;              // null = 新链
  final List<AppendChainLink> links; // 末尾 → a → b …
  final List<String> appendedIds;    // 按接入顺序
  final int skippedChained;          // 目标里已在链上而跳过的个数（产物换成来源后去重再数）
}
/// 链尾：orderByNarrativeChain(include: narrativeChainMembers 包含) 的最后一个；无链 ⇒ null。
CanvasNode? narrativeChainTail(List<CanvasNode> nodes, List<CanvasEdge> edges);
/// 候选：targets 里产物换成来源配置（narrativeAnchorOf）、去掉文本 / 孤儿、去重、去掉已在链上的；
/// 排序 (主轴坐标, 泳道序号〔lanes 列表下标，无道排最后〕, 横截坐标, id)；主轴按 direction。
List<CanvasNode> appendCandidates({required List<CanvasNode> targets, required List<CanvasNode> nodes,
  required List<CanvasEdge> edges, required List<StyleLane> lanes, required LaneDirection direction});
AppendChainBlock appendChainBlock({/* 同上参数 */});
/// 可执行 ⇒ 计划；否则 null。末尾 → 第一个候选的 sortOrder = nextNarrativeSortOrder(tail)；其余 0。
AppendChainPlan? planAppendToChain({/* 同上参数 */});

// util/canvas_append_chain_actions.dart
Future<void> appendTargetsToChain(BuildContext context, WidgetRef ref, {required String canvasId, required Set<String> nodeIds});
void nextShotFromMenu(BuildContext context, WidgetRef ref, {required String canvasId, required String nodeId});

// canvas_menu/append_chain_menu_entries.dart（menu-split 的 CanvasMenuItemDef；目标集 = CanvasMenuContext.targets）
final List<CanvasMenuItemDef> appendChainNodeMenuItems; // node.nextShot / node.appendToChain，见「允许改的文件」

// models/commands/append_chain_command.dart（独立文件；签名照 undo-stack 的 CanvasCommand）
final class AppendChainCommand extends CanvasCommand {
  AppendChainCommand({required SplicePlan plan, required SpliceUndoToken token, required int edgeCount});
  // revert：invertSplice(token, 此刻的边) → null ⇒ gone；否则 applySplice(那份逆计划)（一个事务，按两端找边，id 变了也撤得掉）
  // apply：applySplice(plan) 换新 token
  // label(l) = l.canvasCommandLinkEdge(l.canvasCommandEdgeKindNarrative)（W5「连线 {kind}」，不加新键）；canvasId 从 CanvasCommandEnv 取；affectedNodeIds = plan 里所有边的两端
}
```
执行顺序：取现值（节点 / 边 / 泳道 / 方向）→ `planAppendToChain` → `ref.read(canvasEdgesControllerProvider(canvasId).notifier).applySplice(SplicePlan(addEdges: [for link: (sourceNodeId:, targetNodeId:, edgeType: EdgeType.narrative, role: EdgeRole.reference, sortOrder: link.sortOrder)]))`（W1，一个事务，返回 `SpliceApplied` 带 `token`）→ 成功 `record(AppendChainCommand(plan:, token: applied.token, edgeCount:))`（一步）→ `canvasCapsuleProvider(canvasId).notifier.show(CanvasCapsuleMessage(text: …))` 弹完成文案；InkError ⇒ 错误卡「加入叙事链失败」。选中与相机都不动。（不用 `addEdgesInTx`：它不出撤销令牌。）

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 「新建下一镜」：目标恰好一张且有叙事锚点（镜头 / 图像 / 视频配置，或有来源配置的产物）⇒ 可点，执行 = createNextShot（继承、落点、分叉胶囊、撤销全随 next-shot）；多选 / 文本 / 孤儿产物 / createNextShot 在途 ⇒ 置灰，原因「只对一张镜头或配置节点」。行尾键位提示取 `canvasBindingLabel('canvasNextShot', isMac:)`（esc-ladder 按绑定 id 出字，W10 next-shot 的绑定 id；Win「Ctrl+→」、mac「⌘→」）。
2. 「加入叙事链末尾」候选 = 目标里产物换成来源配置后，去掉文本 / 便签 / 孤儿产物、去重、去掉已在链上的。
3. 画布已有链：候选 ≥ 1 ⇒ 可点；接成 链尾 → c1 → c2 …；只建边、不挪任何卡片位置、不改 laneId。
4. 画布没有链：候选 = 1 ⇒ 置灰「还没有叙事链」；候选 ≥ 2 ⇒ 可点，连成 c1 → c2 … 一条新链（c1 是新链头）。
5. 目标全部已在链上 ⇒ 置灰「已在叙事链上」；目标全是文本 / 孤儿 ⇒ 置灰「只有镜头和图像 / 视频配置能入链」。判定优先级：无合格目标 > 全在链上 > 还没有链。
6. 排序：先主轴（横向道 = x，竖向道 = y；画布无道 = 横向）再泳道序号再横截，最后 id；同一组输入顺序与选中顺序无关。
7. 链尾 → c1 那条边的 sortOrder = 链尾现有叙事出边最大值 + 1（链尾有指回链内的边时也不打乱原分叉）；c(i) → c(i+1) 为 0。
8. 全部边在一个事务里（`applySplice`）：任一条失败（含唯一约束冲突）⇒ 一条都不留，错误卡「加入叙事链失败」，撤销栈不变、不弹胶囊。
9. 成功：撤销栈 +1 步，Ctrl Z 一次删掉本次全部新边、卡片位置不变；Ctrl Y 全部回来。
10. 胶囊：接到已有链 ⇒「已接到第 N 镜之后」（N = 链尾的 sequenceShotNumbers）；链尾没有镜号 ⇒「已接到「名字」之后」（nodeRefName）；新链 ⇒「已连成新叙事链 · N 镜」；有跳过的再加后缀「· 跳过 K 个已在链上的」。
11. 序列视图、大纲、导出顺序随新边即时更新（都读边控制器），不需要额外刷新。
12. 菜单在执行后关闭，焦点还给画布；菜单开着时目标被删 ⇒ 菜单项按 W0 规则消失，不执行。
13. 并发：本动作没有快捷键，只能从菜单触发；同一画布两次连续触发（菜单关闭后立刻再开再点）按 edges 控制器串行执行，第二次的计划以触发时的边为准，若与第一次重复命中唯一约束 ⇒ 按规则 8 整体失败并报错（不会出半条）。
14. macOS / Windows 无差异，除键位提示文案。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| canvasNodeMenuNextShot | New next shot | 新建下一镜 |
| canvasNodeMenuNextShotNeedsOne | Select one shot or config | 只对一张镜头或配置节点 |
| canvasNodeMenuAppendToChain | Add to end of narrative chain | 加入叙事链末尾 |
| canvasNodeMenuAppendNoChain | No narrative chain yet | 还没有叙事链 |
| canvasNodeMenuAppendAllChained | Already in the narrative chain | 已在叙事链上 |
| canvasNodeMenuAppendNotEligible | Only shots and image / video configs can join | 只有镜头和图像 / 视频配置能入链 |
| canvasAppendChainDone（n:int） | Added after shot {n} | 已接到第 {n} 镜之后 |
| canvasAppendChainDoneNamed（name:String） | Added after “{name}” | 已接到「{name}」之后 |
| canvasAppendChainNewChain（count:int） | New narrative chain · {count} shots | 已连成新叙事链 · {count} 镜 |
| canvasAppendChainSkipped（count:int） | · skipped {count} already in the chain | · 跳过 {count} 个已在链上的 |
| canvasAppendChainFailed | Couldn't add to the narrative chain | 加入叙事链失败 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/append_to_chain_test.dart`（新）
  - 「链尾 = 只留链上节点后的最后一个」：链 A→B→C + 链外 D（x 更大）⇒ 尾 C 不是 D。
  - 「分叉时链尾 = DFS 前序最后一个」：A→B、A→C(sortOrder 1) ⇒ 尾 C。
  - 「产物换成来源配置并去重」：选中配置 X 和 X 的产物 ⇒ 候选只有 X。
  - 「去掉文本 / 孤儿产物 / 已在链上的；skippedChained 计数正确」。
  - 「按主轴再横截排序」：横向道三张 (x=600,y=0)(x=0,y=300)(x=0,y=0) ⇒ (0,0)(0,300)(600,0)；竖向道换轴。
  - 「首条边 sortOrder = 尾部最大 + 1，其余 0」。
  - 「无链单候选 ⇒ noChain；无链两候选 ⇒ 新链计划 tailId=null、links 1 条」。
  - 「全在链上 ⇒ allChained；全是文本 ⇒ noEligible（优先级）」。
- `test/features/canvas/util/canvas_append_chain_actions_test.dart`（新）
  - 「一次 applySplice、plan 只有 addEdges、边全为 narrative、源目标顺序正确」（fake edges 控制器记录调用）。
- `test/features/canvas/models/commands/append_chain_command_test.dart`（新）：「revert 用 invertSplice 删掉全部新边（一次 applySplice）」；「新边被删后重建（id 变了）仍能撤掉」；「一条都对不上 ⇒ gone」；「apply 再 applySplice 原计划」。
  - 「不改任何节点位置 / laneId」：动作前后节点表逐个相等。
  - 「失败 ⇒ 错误卡、无胶囊、撤销栈不变」。
  - 「成功推一步；undo 后新边全无」。
  - 「胶囊文案：第 N 镜 / 名字回退 / 新链 / 跳过后缀」四条。
- `test/features/canvas/widgets/node_menu_append_chain_test.dart`（新，CanvasScreen + 内存仓储）
  - 「右键链外图像配置：菜单含新建下一镜（键位 Ctrl+→）与加入叙事链末尾，位置分别在做组 / 归类组」。
  - 「多选时新建下一镜置灰并带原因」。
  - 「无链单选：加入叙事链末尾置灰『还没有叙事链』」。
  - 「点加入叙事链末尾 ⇒ 序列视图镜数 +1、胶囊出现」。
  - 「点新建下一镜 ⇒ 与 Ctrl→ 建出的节点 typeConfig 一致」（同一锚点各做一次比较键集）。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. narrativeChainTail 去掉 include（不只留链上节点）⇒「链尾 = 只留链上节点后的最后一个」红。
2. 候选不把产物换成来源配置 ⇒「产物换成来源配置并去重」红。
3. 不去掉已在链上的 ⇒「去掉 … 已在链上的」红。
4. 排序只按 id ⇒「按主轴再横截排序」红；主轴不随方向换 ⇒ 竖向用例红。
5. 首条边 sortOrder 写死 0 ⇒「首条边 sortOrder = 尾部最大 + 1」红。
6. 无链单候选返回计划 ⇒「无链单候选 ⇒ noChain」红。
7. applySplice 换成逐条 addEdge ⇒「一次 applySplice」红。
8. 动作里调用 moveNode / moveNodes（改成挪到链尾后）⇒「不改任何节点位置」红。
9. 成功后不推撤销步 ⇒「成功推一步」红。
10. nextShotFromMenu 改成 addNodeFromMenu ⇒「与 Ctrl→ 建出的节点 typeConfig 一致」红。
11. 置灰判定优先级对调 ⇒「全是文本 ⇒ noEligible」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑 `flutter analyze lib test`、`flutter test test/features/canvas --exclude-tags golden`，逐条变异。
- 截图（CanvasScreen，水平泳道：链 镜头 01 → 02 → … → 07，链外两张图像配置 A、B）：
  1. 右键 A：节点菜单里两项新行分别在「做」组与「归类」组、可点（整体分组以主 Agent 调整后为准）；2. 多选 A、B 右键：新建下一镜置灰带原因；3. 点「加入叙事链末尾」后：07 → A → B 两条叙事线、卡片位置不变、胶囊「已接到第 7 镜之后」；4. 空链画布单选右键：置灰「还没有叙事链」；5. Ctrl Z 后两条线消失。

## 风险与不确定
- 菜单分组改成「做 | take | 归类 | 定位 | 停用 · 删除」不在本片：由主 Agent 合入时统一调整 menu_registry 既有行（现状 [生成, 复制一份] | [存为角色, 加入泳道, 在序列中定位] | [删除]），本片只追加两行；截图里的分组以合入调整后为准。
- 置灰「悬停说原因」：menu-split 的 `InkMenuEntry` 字段是 label / glyph / swatch / keyHint / enabled / danger / checked / submenu，没有原因字段；原因先不显示，回报主 Agent（W12 cm-multi-select-menu 也会碰到同一个缺口）。
- 多条边一步撤销：W5 只有单边的 `AddEdgeCommand`，所以本片用 W1 `applySplice` 拿 `SpliceUndoToken`，自建独立文件的 `AppendChainCommand`（按两端找边的 `invertSplice` 撤）。不改 canvas_command.dart（W11 无人拥有；undo-stack 契约是命令自带 `label(l)`，独立文件就够）。落地若与契约不符，停下回报主 Agent。
- next-shot 按派工单暴露 `NextShotController.isBusy`，「在途置灰」照用；落地若没有，只靠 next-shot 内部丢弃。
