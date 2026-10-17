# align-distribute-arrange · 对齐 · 分布 · 排布 · 整理叙事链
- 波次 W8 / lane B / 基底：origin/main（W0–W7 已合入）；依赖切片：multi-select-core（W0，selectionBounds）、nodes-batch-ops（W1，moveNodes）、undo-stack（W0）、undo-node-create-move（W4，MoveNodesCommand）、esc-ladder（W0，快捷键注册表）、menu-split（W0，menu_registry）、canvas-capsule（W1）；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
多选后右键出「对齐 ›」子菜单：对齐（左 / 水平居中 / 右 / 顶 / 垂直居中 / 底）、分布（水平等距 / 垂直等距，至少 3 个）、排布（一行 / 一列 / 网格）、整理叙事链。
键盘：Alt A / D / W / S / H / V 对齐，Alt Shift H / V 分布（mac 是 ⌥）。每次操作卡片一起挪、一次写库、Ctrl Z 一步撤回；泳道里的卡不会被挤出自己的道。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/Selection.dc.html` ›「对齐 · 分布 · 排布 · 吸附」：对齐按选区包围盒，分布按卡片中心；一次操作 = 一次 moveNodes；网格列数 ⌈√n⌉、间距 48，先叙事序再位置；整理叙事链 = 沿链一行，产物按 result_placement；跨轴对齐夹在各自的带里；Alt 字母保留（Windows 菜单栏只认单独按下再松开的 Alt，不做 Alt+字母助记键）。面板：对齐 6 格 | 分布 · 至少 3 个 | 排布 3 格 | 分隔线 | 整理叙事链。
- `b2/project/KeyMap.dc.html` 组合键表：Alt A/D/W/S（⌥）左 / 右 / 上 / 下对齐；Alt H/V 水平 / 垂直居中；Alt Shift H/V（⌥⇧）水平 / 垂直分布；「⌥ 字母按 logicalKey 匹配」；「文字让位」表：Alt 字母交给输入框。「单独按 Alt」：Alt↓ A↓ = 左对齐、菜单栏不动。
- `b2/project/ContextMenus.dc.html` ›「多选」：对齐 › / 分布 › 两行；对齐整批一个事务。
- critic.txt 第 21 条 + revise-summary.txt 第 199、241–245 行：Alt 键与菜单栏不冲突的理由。
- 设计缺口：ContextMenus 写「横截轴对齐只在目标同属一条道时可点」，Selection 写「夹在各自的带里」，两条冲突。本片按 Selection（本片的主板）：不置灰，跨道时各自夹在自己道的带里；回报主 Agent 让 W12 cm-multi-select-menu 别再加置灰判据。
- 设计缺口：ContextMenus 把「分布 ›」画成单独一行，Selection 把它画进「对齐 ›」同一块。本片按 Selection 只出一行「对齐 ›」，块内含分布；W12 若要拆两行再拆。
- 设计缺口：整理叙事链时产物是否跟着动、配置节点之间要不要给产物列让位，板没写。本片定：所选链上配置节点名下的全部现存产物都按 `resultNodePosition` 重排（不管是否被选中），链上相邻两镜的主轴间距给产物列让出位置。
- 设计缺口：操作数不够（对齐 < 2、分布 < 3）时按快捷键给什么反馈，板没画。本片定：胶囊一句「至少选中 2 个才能对齐」/「分布至少要 3 个」。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/util/node_arrange.dart`（新，纯函数）：对齐 / 分布 / 排布 / 整理叙事链的位移计算 + 跨轴夹带。
- `lib/features/canvas/util/canvas_arrange_actions.dart`（新）：读选中 / 节点 / 泳道 / 相机，调纯函数，一次 `moveNodes` + 推一步 `MoveNodesCommand`，不够数时出胶囊、失败出错误卡。
- `lib/features/canvas/widgets/shortcuts/arrange_keys.dart`（新）：8 个 Intent + activator + 注册表条目（对文字让位、`includeRepeats: false`）。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（W0 menu-split / esc-ladder 新建，以落地为准）：只追加一行（引入 arrange_keys 的条目表）。
- `lib/features/canvas/widgets/canvas_menu/align_menu_entries.dart`（新）：节点菜单「对齐 ›」一行 + 子菜单分组。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（W0 menu-split / esc-ladder 新建，以落地为准）：节点菜单分组表只追加一行。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- node-disabled-flag：`widgets/node_card.dart`、`widgets/left_rail/outline_panel.dart`、`models/canvas_node_disabled.dart`、`util/canvas_disable_actions.dart`、`canvas_menu/disable_menu_entries.dart`。
- wrap-in-lane：`providers/canvas_lanes_controller.dart`、`widgets/lane_title_bar.dart`、`util/lane_wrap.dart`、`providers/lane_rename_request.dart`、`util/canvas_wrap_actions.dart`、`shortcuts/wrap_lane_keys.dart`、`canvas_menu/wrap_lane_menu_entries.dart`、`models/canvas_command.dart`。
- clipboard-text-paste：`util/canvas_paste_actions.dart`、`util/clipboard_snapshot.dart`、`widgets/shortcuts/clipboard_keys.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`。
- job-timing：`lib/services/job_queue_service.dart`、`lib/core/di/job_queue.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`lib/features/notifications/widgets/job_notification_listener.dart` 及其新文件。
- 全波禁区：`util/canvas_tool_actions.dart`、`util/node_menu_model.dart`、`canvas_menu/node_menu_entries.dart`、`canvas_menu/blank_menu_entries.dart`、`canvas_menu/create_menu_entries.dart`、`util/create_menu_model.dart`、`widgets/canvas_shortcuts.dart` 骨架、`canvas_shortcut_registry.dart` 除追加一行外的内容、`widgets/canvas_view.dart` 与 `stage_*.dart` / `node_card_slot.dart`、`providers/canvas_nodes_controller.dart`、`util/viewport_focus.dart`、`util/result_placement.dart`、`util/narrative_order.dart`、`lib/features/settings/util/shortcut_catalog.dart`（从注册表自动取）。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/node_arrange.dart —— 输入是「画出来的矩形」（nodeStageRect：世界 + 分道位移，舞台坐标），输出是每张卡的世界位移。
// 依据：同一缩放下分道位移是每道常量，Δ舞台 = Δ世界，所以在舞台矩形里对齐 = 屏幕上对齐。
enum AlignEdge { left, hCenter, right, top, vCenter, bottom }
enum DistributeAxis { horizontal, vertical }
enum ArrangeLayout { row, column, grid }
const double kArrangeGap = InkSpacing.xxl; // 48，与板同值，不新写死数

Map<String, Offset> alignDeltas(Map<String, Rect> rects, AlignEdge edge);          // < 2 个 ⇒ 空 map
Map<String, Offset> distributeDeltas(Map<String, Rect> rects, DistributeAxis axis); // < 3 个 ⇒ 空；按中心排序，首尾不动，等距；中心相同按 id
Map<String, Offset> layoutDeltas(List<String> orderedIds, Map<String, Rect> rects, ArrangeLayout layout); // 锚 = 包围盒左上；网格列 = ceil(sqrt(n))，行优先
int gridColumns(int n);
/// 整理叙事链：chainIds 已按 orderByNarrativeChain 排好；首镜不动，沿 [mainAxis] 排一行；resultsOf[configId] = 该配置名下现存产物（resultsFor 的顺序）。
Map<String, Offset> tidyChainDeltas({required List<String> chainIds, required Map<String, Rect> rects, required Map<String, List<String>> resultsOf, required Axis mainAxis});
/// 跨轴夹带：位移后卡心按 laneMoveDelta(node: moved, toLaneId: moved.laneId, …) 收回自己道的带内；不在道里的不动。
Map<String, Offset> clampIntoOwnLanes({required Map<String, Offset> deltas, required List<CanvasNode> nodes, required List<({String id, double size})> laneSlices, required LaneDirection direction, required double scale});

// util/canvas_arrange_actions.dart
enum ArrangeOp { alignLeft, alignHCenter, alignRight, alignTop, alignVCenter, alignBottom, distributeH, distributeV, row, column, grid, tidyChain }
bool canRunArrange(ArrangeOp op, {required int visibleCount, required int chainCount}); // 对齐 / 排布 ≥2、分布 ≥3、整理 chainCount ≥2
Future<void> runArrange(BuildContext context, WidgetRef ref, {required String canvasId, required ArrangeOp op, Set<String>? targets}); // targets 缺省 = 选中集

// widgets/shortcuts/arrange_keys.dart
class CanvasArrangeIntent extends Intent { const CanvasArrangeIntent(this.op); final ArrangeOp op; }
abstract final class ArrangeKeys { static const SingleActivator alignLeft = SingleActivator(LogicalKeyboardKey.keyA, alt: true, includeRepeats: false); /* D W S H V；distributeH/V = keyH/keyV + alt + shift */ }
// 注册表条目形态以 esc-ladder 落地为准；动作必须对文字让位（现为 canvas_shortcuts.dart 私有的 _EditingAwareAction，以落地后的公开名为准）。
```
- 数据：`rects` 由 `nodeStageRect`（`util/viewport_focus.dart`，只读调用）+ `collapseLaneSlices` + `canvasLaneDirectionProvider` + `canvasTransformControllerProvider` 求得，与 `_fitNodes` 同一份取值（`canvas_tool_actions.dart` 第 247–293 行，只看不改）。
- 排序：排布用 `orderByNarrativeChain(nodes: 选中节点, edges: 全部边)`（两端都在选中里的边才算数，链外的按位置追加）——即「先叙事序再位置」。整理叙事链用 `narrativeChainMembers`（`util/outline_model.dart`）过滤出选中的链上配置节点，再 `orderByNarrativeChain(include: …)`。
- 整理叙事链主轴：画布泳道方向 horizontal（或没有泳道）⇒ x；vertical ⇒ y。相邻两镜间距 = 卡片主轴尺寸 + 48；该镜名下有产物时，横向再让出 `kResultColumnGap + 卡宽`，竖向让出产物列高度（`k × (卡高 + kResultRowGap)`）。产物位置 = `resultNodePosition(configPosition: 新位置, index: k)`。
- 写库：`CanvasNodesController.moveNodes({id: (delta, laneId: 原 laneId)})` 一次（laneId 不变，本片从不换道）；成功后推一条 `MoveNodesCommand`（W4，标签以落地为准，不改 canvas_command.dart）。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 参与计算的 = 目标集里不在折叠泳道中的卡（同 `_fitNodes` 的 visible）；折叠道里的卡不动、不计数。
2. 左对齐：每张卡左缘 = 包围盒左缘；右 / 顶 / 底同理；水平居中 = 卡心 x = 包围盒中心 x；垂直居中同理。
3. 分布：按卡心在该轴上排序，首末两张不动，中间卡心等距；中心重合按 id 字典序定先后；结果与输入顺序无关。
4. 一行：按「先叙事序再位置」顺序，从包围盒左上起往右排，间距 48，全部顶对齐；一列同理往下；网格列数 ⌈√n⌉（n = 5 ⇒ 3 列 2 行），行列间距都是 48。
5. 跨轴（泳道 horizontal 时是 y，vertical 时是 x）的位移算完后逐张夹回自己道的带内；任何操作后每张卡 `laneId` 不变、卡心仍在原道带内。不在道里的卡不夹。
6. 整理叙事链：只认选中里的链上配置节点（≥ 2）；首镜位置不动；产物落在新位置右侧一列，按 take 先后从上往下；选中里不在链上的节点不动。
7. 位移全为零（已经对齐）⇒ 不写库、不推撤销步、不出提示。
8. 够数才执行：对齐 / 排布 < 2、分布 < 3、整理叙事链链上节点 < 2 ⇒ 菜单项置灰；按快捷键时出胶囊「至少选中 2 个才能对齐」或「分布至少要 3 个」/「选中里至少要有 2 镜在叙事链上」，不写库。
9. 一次操作 = 一次 `moveNodes`（一个事务）+ 撤销栈一步；Ctrl Z 全部回原位，Ctrl Y 再到对齐后的位置。
10. 写库失败：`moveNodes` 整批回滚，弹错误卡「节点移动失败」（复用 `nodeMoveFailed`），不推撤销步。
11. 并发：有卡片正在拖动（`nodeDragDeltaProvider` 非空）或正在框选时，快捷键与菜单都不执行（直接返回）；写库进行中再按一次，排在控制器的串行队列后面、以前一次的结果为基准重算。
12. 对文字让位：焦点在提示词条 / 检查器输入框里时 Alt 字母交给输入框（mac 上 ⌥A 会打出 å），画布不动。
13. 快捷键 `includeRepeats: false`：按住不放只执行一次。
14. Windows：Alt↓ A↓ 只执行左对齐，菜单栏不获得焦点（lone-alt-menubar 的「期间有别的键就不聚焦」规则，本片写测试钉住）；本应用不做 Alt+字母助记键，所以不冲突。mac：同一组键是 ⌥，菜单在系统菜单栏，不涉及 Alt 聚焦。
15. 菜单：单张右键时「对齐 ›」行置灰（原因：至少选中 2 个）；子菜单里各项分别按规则 8 置灰；菜单行右侧键位从 activator 取（Windows「Alt A」、mac「⌥A」）。
16. 撤销后再对齐：以撤销后的实际位置为基准（不缓存上次结果）。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| arrangeMenuAlign | Align | 对齐 |
| arrangeGroupAlign | Align | 对齐 |
| arrangeGroupDistribute | Distribute · 3 or more | 分布 · 至少 3 个 |
| arrangeGroupLayout | Arrange | 排布 |
| arrangeAlignLeft | Align left | 左对齐 |
| arrangeAlignHCenter | Align horizontal centers | 水平居中 |
| arrangeAlignRight | Align right | 右对齐 |
| arrangeAlignTop | Align top | 顶对齐 |
| arrangeAlignVCenter | Align vertical centers | 垂直居中 |
| arrangeAlignBottom | Align bottom | 底对齐 |
| arrangeDistributeH | Distribute horizontally | 水平等距 |
| arrangeDistributeV | Distribute vertically | 垂直等距 |
| arrangeLayoutRow | Row | 一行 |
| arrangeLayoutColumn | Column | 一列 |
| arrangeLayoutGrid | Grid | 网格 |
| arrangeTidyChain | Tidy narrative chain | 整理叙事链 |
| arrangeNeedTwo | Select at least 2 to align | 至少选中 2 个才能对齐 |
| arrangeNeedThree | Distribute needs at least 3 | 分布至少要 3 个 |
| arrangeNeedChain | Select at least 2 shots on the narrative chain | 选中里至少要有 2 镜在叙事链上 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/node_arrange_test.dart`（新，纯函数）
  - `左/右/顶/底对齐到包围盒边`：三张不同位置的矩形，断言各自位移后边对齐且等于原包围盒边。
  - `水平/垂直居中对齐到包围盒中心`。
  - `少于 2 个对齐返回空`；`少于 3 个分布返回空`。
  - `分布首末不动、中间等距`：四张，断言首末位移为 0、相邻中心差相等；`输入顺序打乱结果相同`；`中心重合按 id 定序`。
  - `一行：间距 48、顶对齐、按给定顺序`；`一列同理`；`网格 n=5 → 3 列`、`gridColumns(1/4/5/10) = 1/2/3/4`。
  - `整理叙事链：首镜不动、相邻间距含产物列让位、产物按 resultNodePosition 排`。
  - `竖向泳道时整理沿 y`。
  - `clampIntoOwnLanes：跨两道的顶对齐后每张卡心仍在自己道内、laneId 不变`；`不在道里的卡不夹`。
- `test/features/canvas/util/canvas_arrange_actions_test.dart`（新，ProviderScope + fake 控制器）
  - `对齐一次只调一次 moveNodes 且 laneId 都是原值`。
  - `成功推一步撤销，undo 全部回原位`。
  - `已对齐时不写库不推步`。
  - `折叠道里的卡不动不计数`：两张可见 + 一张折叠 → 只两张参与；可见一张时出「至少选中 2 个」胶囊。
  - `写库失败不推步并弹 nodeMoveFailed`。
  - `排布按叙事序`：A→B 叙事边，B 在 A 左侧，一行后 A 在左。
  - `拖动中不执行`。
- `test/features/canvas/widgets/canvas_arrange_shortcuts_test.dart`（新）
  - `Alt A 左对齐`、`Alt Shift H 水平分布`、`Alt D/W/S/H/V 各映射到对应 op`（逐键断言 intent.op）。
  - `焦点在输入框里 Alt A 不动卡片`。
  - `按住 Alt A 重复事件只执行一次`。
  - `所有 activator 都是 includeRepeats: false`。
- `test/features/canvas/widgets/canvas_align_menu_test.dart`（新）：多选 3 张右键 → 有「对齐 ›」，子菜单含 6 + 2 + 3 + 1 项；单张右键 → 「对齐 ›」置灰；两张时「水平等距」置灰；点「左对齐」后位置变化且 Ctrl Z 复原。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. `alignDeltas` 左对齐改用第一张卡的左缘而非包围盒 → `左/右/顶/底对齐到包围盒边` 红。
2. 分布按卡片左缘而非中心排序 / 计算 → `分布首末不动、中间等距`（混入不同宽度会失败；用例需含一张宽度不同的矩形，或断言中心差）红。
3. `distributeDeltas` 门槛改成 ≥ 2 → `少于 3 个分布返回空` 红。
4. `kArrangeGap` 改成 24 → `一行：间距 48` 红。
5. `gridColumns` 改 `floor(sqrt(n))` → `网格 n=5 → 3 列` 红。
6. 排布不用 orderByNarrativeChain、只按位置 → `排布按叙事序` 红。
7. 去掉 `clampIntoOwnLanes` 调用 → `跨两道的顶对齐后卡心仍在自己道内` 红。
8. 逐张 `moveNode` 代替一次 `moveNodes` → `对齐一次只调一次 moveNodes` 红。
9. 位移为零也写库 → `已对齐时不写库不推步` 红。
10. 不过滤折叠道 → `折叠道里的卡不动不计数` 红。
11. 动作不对文字让位（普通 CallbackAction）→ `焦点在输入框里 Alt A 不动卡片` 红。
12. 某个 activator 漏 `includeRepeats: false` → 守卫用例红。
13. 整理叙事链不给产物列让位 → `整理叙事链：相邻间距含产物列让位` 红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑：`flutter analyze lib test`；`flutter test test/features/canvas --exclude-tags golden`；上面 13 条变异。
- 截图（CanvasScreen + 假仓库）：数据 = 横向两条泳道「水墨风格」「白天」，四张卡错位（两张在各自道里、两张不在道里）；截：对齐前 / Alt W 顶对齐后（看两道的卡各自夹在带里）/ Alt Shift H 分布后 / 网格排布后 / 整理叙事链后（镜头 01→02 各带一张成片）；再截右键「对齐 ›」子菜单展开（Windows 键位文本与 mac ⌥ 各一张，用 `debugDefaultTargetPlatformOverride`）。

## 风险与不确定
- 撤销步名：主 Agent 裁决 canvas_command.dart 不扩权，本片沿用 `MoveNodesCommand` 与通用标签，步名写「移动 N 个节点」——后续波次补专用标签（「对齐 N 个节点」等）。
- mac 上 ⌥ + 字母的 `logicalKey`：Flutter macOS 按不带修饰的字符给 logicalKey（⌥A → keyA），但非美式键盘布局可能不同；验收时在 mac 真机上按一次 ⌥A / ⌥⇧H。
- Windows：Alt + Shift 是系统默认的「切换输入法」热键（多语言用户），按 Alt Shift H 时可能先切了输入法；Alt + 未被处理的字母会有系统提示音——需在 Windows 真机确认已处理时不响。
- 跨道选区的跨轴对齐结果随当前缩放变（各道以自己起始边锚定缩放）；同道或都不在道里的选区不受影响。这是泳道模型本身的性质，写进行为规则 5 的测试只断言「夹在带内」，不断言换缩放后仍对齐。
- 整理叙事链「产物跟着动」包含没被选中的产物，可能挪到用户刻意摆开的位置；按设计缺口里的决定执行，回报主 Agent。
