# outline-rename-menu · 大纲行双击就地改名（写 nodes.label，一步撤销）+ 右键弹节点右键菜单原样
- 波次 W9 / lane E / 基底：叠在 rail-drag-characters 之后（文件不相交）；依赖切片：menu-split（W0，CanvasMenuPopover + buildNodeMenuGroups / runNodeMenuPick）、undo-stack（W0，CanvasHistoryController + canvas_command.dart）、node-disabled-flag（W8，outline_panel.dart 上一手）；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
左栏大纲里双击一行镜头的名字，名字原地变成输入框：↵ 或点别处保存、Esc 放弃，清空保存就回到类型名（「图像」「镜头」…）。改名立刻反映到画布卡片、⌘K、序列，Ctrl Z 一步撤回。
在大纲行（镜头行、产物子行）上右键，弹出与画布卡片右键完全相同的节点菜单；没选中的行先被单选。仓库里第一次有了改节点名的入口。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/GapsPanels.dc.html` ›「大纲行：改名 · 右键 · 拖动排序」：
  - 双击 = 就地改名（↵ / 失焦存，Esc 放弃，清空回类型名），写 nodes.label，一步撤销。
  - 右键 = 节点右键菜单原样（同一份 node_menu_model）。
  - 拖行改叙事序属于 W13 outline-drag-reorder，本片不做，但改名框不能吞掉后续拖动手势（见规则 13）。
- `b2/project/KeyMap.dc.html` ›「还没有板：… 大纲行双击改名」——本片即补上它；›「Esc 阶梯」第 4 层「文字输入框失焦」；改名框的 Esc 必须是「放弃」，不能落到第 4 层变成「失焦 = 保存」。
- slices.json › undo-params 备注：「代码里还没有节点改名功能，『重命名』的步名等改名入口落地再接」——本片接上。
- 代码核对：`nodes.label TEXT NOT NULL DEFAULT ''`，`CHECK (char_length(label) <= 200)`（`lib/storage/schema/001_init.sql` 第 86、103 行）；显示名 `nodeDisplayName`（`widgets/node_card.dart` 第 457 行）在 label 为空时回退 `nodeTypeLabel`——所以「清空回类型名」= 存空串。
- 代码核对：`NodeRepository.update(String id, Map<String, Object?> patch) → Future<int>`（`lib/core/interfaces/node_repository.dart` 第 27 行），列名常量 `NodeCol.label`（`lib/core/db/columns.dart` 第 81 行）。
- 设计缺口：键盘怎么进改名没画（F2 / 行上 ↵）。本片只做双击；大纲行持焦时 ↵ 仍是「定位」（InkActivatable 现有行为）。
- 设计缺口：超长名（>200 字）没画。本片输入框 maxLength 200，不显示计数。
- 设计缺口：改名中节点被别处删掉 / 列表因 job 完成重建，画板没画。见规则 9、10。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/widgets/left_rail/outline_panel.dart`：
  - `_OutlinePanelState` 记 `String? _editingNodeId`；`_ShotRow` 的名字 Text 在编辑态换成单行输入框（InkInput 或同族组件，核对 theme/components 里的单行变体）。
  - 名字区外包原始指针 `Listener`（不进手势竞技场）判双击：两次 PointerDown 间隔 ≤ kDoubleTapTimeout 且位移 ≤ kDoubleTapSlop ⇒ 进编辑；单击仍立即走现有 onTap（定位），不被延迟。
  - 镜头行与产物子行外包右键检测（按下记点、抬起时未挪出 kTouchSlop 才开，与画布 `_SecondaryClickDetector` 同口径，但本文件自写一个私有类）；开菜单前「没选中 ⇒ 单选这一行，已在选中集里 ⇒ 保持」，然后用 `CanvasMenuPopover` 在全局坐标开 `buildNodeMenuGroups(ref, l, targets)`，选中项交 `runNodeMenuPick(context, ref, canvasId, targets, pick)`。
  - 保存成功后向 `canvasHistoryControllerProvider(canvasId)` 推一条 `RenameNodeCommand`。
- `lib/features/canvas/providers/canvas_nodes_controller.dart`：新增 `renameNode`（见下），走 `repo.update(id, {NodeCol.label: …})`，乐观更新 + 失败回滚，串行化（SerialMutationQueue）。
- `lib/features/canvas/models/canvas_command.dart`（undo-stack 新建；W9 唯一可改者）：新增 `RenameNodeCommand` 子类 + 标签枚举加 `renameNode` 一档。
- 测试：见「测试」小节的 4 个新文件。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- `widgets/character_library_panel.dart`、`util/ref_image_budget.dart`、`util/canvas_character_drop_actions.dart`（rail-drag-characters，同 lane 前一片）。
- `widgets/canvas_view.dart`、`widgets/shortcuts/clipboard_keys.dart`、`util/canvas_paste_actions.dart`（os-drop-paste-image）；`widgets/canvas_screen.dart`、`widgets/node_card_slot.dart`、`widgets/node_card.dart`、`util/escape_ladder.dart`（canvas-find-bar）。
- `widgets/canvas_inspector_panel.dart`、`image_config_inspector.dart`、`video_config_inspector.dart`（multi-select-inspector）。
- `pubspec.yaml` 等依赖文件（dep-drop-pasteboard）；`postgres_job_repository.dart`（job-eta）；`lib/features/generation/services/`（batch-run-planner）。
- `util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_menu/blank_menu_entries.dart`、`canvas_menu/canvas_menu_host.dart`（只读用 CanvasMenuPopover）、`widgets/canvas_shortcuts.dart` 骨架与注册表、`util/outline_model.dart`（W13 outline-drag-reorder 用）、`widgets/node_card.dart`（nodeDisplayName 只读）。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：rail-drag-characters：`lib/features/canvas/widgets/characters_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// providers/canvas_nodes_controller.dart
/// 改名：[label] 去首尾空白；空串 = 回类型名（显示走 nodeDisplayName 的回退）；超过 200 字截到 200。
/// 与现值相同 / 节点不在内存 ⇒ 不写库、返回 null。成功返回改名前的 label（撤销用）。
/// 乐观更新内存，DB 失败回滚并 rethrow InkError。
Future<String?> renameNode(String id, String label);

// models/canvas_command.dart（以 undo-stack 落地的 CanvasCommand 形状为准）
final class RenameNodeCommand extends CanvasCommand {
  const RenameNodeCommand({required String canvasId, required String nodeId, required String before, required String after});
  // undo = renameNode(nodeId, before)；redo = renameNode(nodeId, after)；节点已不在 ⇒ 按 undo-stack 规则丢弃这一步
  // label: CanvasCommandLabel.renameNode（ARB：重命名「{name}」，name = after 为空时用类型名）
}

// widgets/left_rail/outline_panel.dart（私有）
class _RenameField extends StatefulWidget { /* nodeId, initial, onCommit(String), onCancel() */ }
class _SecondaryClick extends StatelessWidget { /* onSecondaryClick(Offset globalDown) */ }
static Key OutlinePanel.renameFieldKey(String nodeId); // 测试锚点
```
改名框状态机：idle →（名字区双击）→ editing(文本 = 当前 label 原文，全选)→ ↵ ⇒ commit；失焦 ⇒ commit；Esc ⇒ cancel（先置 _cancelled 再收焦点，失焦回调看到标志不提交）→ idle。commit：`await renameNode`，返回非 null 才推 `RenameNodeCommand`；InkError ⇒ 错误通知卡「改名失败」，名字回原值。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 双击镜头行名字区进编辑；第一下单击照旧立即定位（单选 + 居中），不因等双击而延迟。
2. 编辑框初值是 label 原文（空 label 时为空，占位文字显示类型名），进框即全选。
3. ↵ 保存；点框外 / 焦点离开保存；两者都只写一次库（↵ 后失焦不再写第二次）。
4. Esc 放弃：label 不变、不写库、不进撤销栈；Esc 被改名框自己消费，不落到画布 Esc 阶梯（选中不清空、不触发「失焦 = 保存」）。
5. 保存值去首尾空白；空串存 ''，大纲 / 卡片显示类型名；与现值相同不写库、不进撤销栈。
6. 输入上限 200 字（与 DB CHECK 一致）；粘贴超长内容截断到 200。
7. 写库失败：内存回滚到旧名，出错误通知卡「改名失败」，撤销栈不变。
8. 成功：画布卡片标题、⌘K 镜头组、序列视图同时显示新名（都读同一个节点控制器）；撤销栈多一步「重命名「新名」」。
9. Ctrl Z（画布持焦）撤回改名：名字回旧值，再 Ctrl Y 回新值；节点被删后再撤这一步 ⇒ 按 undo-stack 规则丢弃，不报错。
10. 编辑中该节点被删（别处删 / 撤销新建）：编辑框消失，不写库、不报错。
11. 编辑中列表重建（job 完成刷新节点、筛选框文字变化）：同一节点的编辑框保持（按 nodeId 的 key），已输入内容不丢；若被筛选滤掉 ⇒ 视为失焦，按规则 3 保存。
12. 同一时间只有一行在编辑；在另一行双击 ⇒ 先按失焦保存当前行，再进新行。
13. 编辑框持焦时画布单键（V / I / G / Del / Ctrl D …）全部让位文本（现有 `_EditingAwareAction` 机制），Ctrl Z 归文本框自己的撤销。
14. 连续两次快速改名（第一次写库未回）：renameNode 串行执行，最终库内与内存都是第二次的值，撤销栈两步。
15. 右键镜头行 / 产物子行：抬起时开菜单，按下到抬起挪出 kTouchSlop 不开；没选中的行先单选（不挪相机），已在多选集里保持多选；菜单项、置灰与执行结果与画布上右键同一张卡完全相同（同一份 buildNodeMenuGroups / runNodeMenuPick）。
16. 「生成中…」子行没有节点可作用，右键不开菜单；编辑框内右键归文本框（系统上下文菜单），不开节点菜单。
17. 菜单里选「删除」：被删行从大纲消失，带撤销卡（同画布）；选「在序列中定位」等需要相机 / 标签的动作照画布行为执行。
18. 菜单开着时 Esc 关菜单；点外面关菜单；焦点按 CanvasMenuPopover 的交接规则回去（以落地为准）。
19. macOS 与 Windows 同键：双击 / 右键；macOS 上 Ctrl + 左键单击不当右键（与画布一致，不额外处理）。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| canvasRenameNodeFailed | Couldn't rename | 改名失败 |
| leftRailOutlineRenameLabel（改名框 semantics） | Rename | 重命名 |
| canvasUndoStepRenameNode（name:String；以 undo-stack 标签→ARB 的命名规则为准） | Rename “{name}” | 重命名「{name}」 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/providers/canvas_nodes_controller_rename_test.dart`（新）
  - 「renameNode 写 label 列」：fake update 收到 `{'label': '雾中老人'}`，返回旧名。
  - 「去首尾空白；全空白 ⇒ 存 ''」。
  - 「与现值相同 ⇒ 不调 update、返回 null」。
  - 「超 200 字截断到 200」。
  - 「update 抛 InkError ⇒ 内存回到旧名并 rethrow」。
  - 「两次连写串行：最终内存为第二次的值，update 顺序与调用顺序一致」。
- `test/features/canvas/models/rename_node_command_test.dart`（新）
  - 「undo 写回 before、redo 写回 after」；「节点已不在 ⇒ undo 视为失效步被丢弃」（按 undo-stack 的失效约定断言）。
- `test/features/canvas/widgets/left_rail/outline_rename_test.dart`（新）
  - 「双击进编辑、框内全选；单击仍立即定位」。
  - 「↵ 保存一次：update 调用 1 次，卡片标题变新名」；「↵ 后失焦不再写」。
  - 「Esc 放弃：不写库、选中不清空、撤销栈不变」。
  - 「清空保存 ⇒ 行显示类型名」。
  - 「失败出改名失败卡、行回旧名」。
  - 「编辑中筛选滤掉该行 ⇒ 保存」；「编辑中节点被删 ⇒ 框消失不写」。
  - 「保存后撤销栈 +1，Ctrl Z 回旧名」。
- `test/features/canvas/widgets/left_rail/outline_context_menu_test.dart`（新）
  - 「右键未选中的行 ⇒ 单选它并开节点菜单」；「右键已在多选集里的行 ⇒ 保持多选」。
  - 「菜单分组与画布同卡右键一致」：同数据下两处 buildNodeMenuGroups 结果相等（比 value 列表）。
  - 「选复制一份 ⇒ 多一张副本」；「按下后拖出 slop 再抬起不开菜单」；「生成中子行右键不开」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. renameNode 去掉 trim ⇒「去首尾空白」红。
2. renameNode 去掉「相同不写」判断 ⇒「与现值相同 ⇒ 不调 update」红。
3. 去掉 200 截断 ⇒「超 200 字截断」红。
4. 失败分支去掉 `state = AsyncData(previous)` ⇒「update 抛 InkError ⇒ 内存回到旧名」红。
5. 改名框 Esc 不消费按键（返回 ignored）⇒「Esc 放弃：选中不清空 / 不写库」红。
6. 去掉 `_cancelled` 标志 ⇒「Esc 放弃：不写库」红（失焦会提交）。
7. commit 之后不置 `_committed`（↵ + 失焦各写一次）⇒「↵ 后失焦不再写」红。
8. 双击判定改成 GestureDetector.onDoubleTap ⇒「单击仍立即定位」红（单击被延迟）。
9. 右键前不先单选 ⇒「右键未选中的行 ⇒ 单选它」红。
10. 推命令改成成功前推 ⇒「失败 … 撤销栈不变」红。
11. RenameNodeCommand.undo 写 after ⇒「undo 写回 before」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑 `flutter analyze lib test`、`flutter test test/features/canvas --exclude-tags golden`，逐条变异。
- 截图（OutlinePanel，ProviderScope 覆盖内存仓储：泳道「水墨风格」三镜 01 山脊远景 / 02 雾中老人 / 03 两人对视 + 未分泳道 04）：
  1. 默认；2. 02 双击后编辑态（全选高亮）；3. 清空后保存，02 行显示「图像配置」类型名；4. 右键 03 开出节点菜单（与画布同卡右键对比截图）；5. 改名失败通知卡。

## 风险与不确定
- CanvasMenuPopover、buildNodeMenuGroups / runNodeMenuPick、CanvasHistoryController.push、CanvasCommand 的构造与失效约定都以 W0 落地为准；若 Popover 需要舞台坐标而不是全局坐标，要在 canvas_menu_host 里改，那不归本片——回报主 Agent。
- outline_panel.dart 在 W8（node-disabled-flag 加停用样式）之后、W11（batch-run-dialog 组头「运行这组」）与 W13（outline-drag-reorder）之前；本片只动 `_ShotRow` 名字区、行外包右键检测与 State 字段，组头不动，降低 rebase 冲突。W13 的拖动若用 LongPress / Draggable，需确认不与本片的原始指针 Listener 抢事件（Listener 不进竞技场，理论上不冲突）。
- undo-params（W5）原本把「重命名」步名挂在改名入口落地后——标签枚举与 ARB 键名以 W0 定的命名规则为准，本片新增一档。
- 产物子行改名不做（画板只说镜头行）；产物节点的 label 沿用原值。
