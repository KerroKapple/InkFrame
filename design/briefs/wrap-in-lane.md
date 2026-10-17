# wrap-in-lane · Ctrl G 包成泳道 / Ctrl Shift G 移出泳道
- 波次 W8 / lane C / 基底：origin/main（W0–W7 已合入）；依赖切片：lane-ops-core（W2）、undo-stack（W0）、undo-lanes（W6，泳道命令）、undo-node-create-move（W4，进出泳道命令）、multi-select-core（W0）、cm-lane-menu（W7，LaneTitleBar 原地改名）、menu-split（W0）、esc-ladder（W0）、app-action-table（W1）；阻塞决定：无（Selection Q5 → B：新道插在选区所在道之后，不在道里放末尾）

## 目标（用户看到什么变化，2–4 行）
选中几张卡按 Ctrl G（mac ⌘G）：紧挨着它们原来那条道建一条新泳道，卡片整批移进去、彼此相对位置不变，新道标题直接进改名态；Ctrl Z 一步撤回（道和移动一起回去）。
卡片原来在别的道里时弹一张 8 秒撤销卡「N 张从「X」换到新泳道，风格变了」。Ctrl Shift G（⇧⌘G）把选中的卡移出泳道。F 不变，仍只开「新建泳道」对话框。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/Selection.dc.html` ›「包成泳道」（Ctrl G · 折叠已有）：建道、整批移入、标题进改名；相对位置不变，道厚 = 选区跨轴 + 48（≥400）；F 照旧只开对话框、不看选中；有卡原在别的道 → 弹撤销卡（8 秒）；建道 + 移入算一步撤销；Ctrl Shift G = 移出泳道；重排泳道时卡恒跟着走；「需：建道 + 定厚 + 排位 + 移节点一个事务；createLane 现在只追加、不收 size」。mock：标题输入框预填「新泳道」、撤销卡文案「1 张从「水墨风格」换到新泳道，风格变了」。
- 同板「需要你定」Q5 → 建议 B（卡片挪得最少，相机不用跟着跳）。
- `b2/project/KeyMap.dc.html`：Ctrl G / ⌘G 包成泳道，Ctrl Shift G / ⇧⌘G 移出泳道（画布范围，第二批）。
- `b2/project/ContextMenus.dc.html` ›「多选」：「包成泳道 Ctrl G」一行；「泳道」：改名 = 标题栏原地输入框，↵ 存 Esc 退（W7 已做）。
- revise-summary.txt 第 18–19、166、197 行：F 不看选中；RailScript 节点库「有选中时 = Ctrl G」调本片动作。
- 设计缺口：选区跨多条道时「选区所在那条道」是哪条——板没说。本片定：选区里 sortOrder 最大的那条道之后（新道紧贴在最下 / 最右一条来源道后面）。
- 设计缺口：卡来自多条道时撤销卡的「X」写什么。本片定：只有一条来源道写道名，多条写「N 张从 M 条泳道换到新泳道，风格变了」。
- 设计缺口：Ctrl G 没有选中时的反馈。本片定：胶囊「先选中要包进泳道的节点」，不建道。
- 设计缺口：KeyMap「文字让位」表没列 Ctrl G。本片定：焦点在输入框时 Ctrl G / Ctrl Shift G 交给输入框（与其余作用于选中的键一致）。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/util/lane_wrap.dart`（新，纯函数）：锚定道、插入位、道厚、节点新位置、后续道 sort_order 平移、风格变化计数。
- `lib/features/canvas/providers/canvas_lanes_controller.dart`：新增 `wrapNodesInLane` / `unwrapLane` / `rewrapLane`（各一个 UoW）；现有 `createLane` 等不改行为。
- `lib/features/canvas/providers/lane_rename_request.dart`（新）：`laneRenameRequestProvider`（按 canvasId family，autoDispose，值 = 要进改名态的 laneId）。
- `lib/features/canvas/widgets/lane_title_bar.dart`：watch `laneRenameRequestProvider(lane.canvasId)`，等于本道 id 时进入 W7 已有的原地改名态、全选文字，然后清掉请求。
- `lib/features/canvas/util/canvas_wrap_actions.dart`（新）：`wrapSelectionInLane`、`unwrapSelectionFromLane`。
- `lib/features/canvas/widgets/shortcuts/wrap_lane_keys.dart`（新）：两个 Intent + 四个 activator（⌘ / Ctrl 各一，`includeRepeats: false`）+ 注册表条目。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（W0 menu-split / esc-ladder 新建，以落地为准）：只追加一行。
- `lib/features/canvas/widgets/canvas_menu/wrap_lane_menu_entries.dart`（新）：节点菜单「包成泳道 Ctrl G」一行。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（W0 menu-split / esc-ladder 新建，以落地为准）：只追加一行。
- `lib/features/canvas/models/canvas_command.dart`（W8 唯一可改者）：新增 `WrapInLaneCommand` 子类 + 标签 `wrapInLane`。
- `lib/features/app_actions/app_action_catalog.dart`：只改「包成泳道」那一行的 isEnabled（W1 登记为禁用「即将推出」）并接上 `wrapSelectionInLane`。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- node-disabled-flag：`widgets/node_card.dart`、`widgets/left_rail/outline_panel.dart`、`models/canvas_node_disabled.dart`、`util/canvas_disable_actions.dart`、`canvas_menu/disable_menu_entries.dart`。
- align-distribute-arrange：`util/node_arrange.dart`、`util/canvas_arrange_actions.dart`、`shortcuts/arrange_keys.dart`、`canvas_menu/align_menu_entries.dart`。
- clipboard-text-paste：`util/canvas_paste_actions.dart`、`util/clipboard_snapshot.dart`、`widgets/shortcuts/clipboard_keys.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`。
- job-timing：`lib/services/job_queue_service.dart`、`lib/core/di/job_queue.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`lib/features/notifications/widgets/job_notification_listener.dart` 及其新文件。
- 全波禁区：`util/canvas_tool_actions.dart`（`addLaneViaDialog` / F 键 / `moveNodesToLane` 只调用不改）、`util/node_menu_model.dart`、`canvas_menu/node_menu_entries.dart`、`canvas_menu/blank_menu_entries.dart`、`canvas_menu/lane_menu_entries.dart`、`util/lane_menu_model.dart`、`widgets/canvas_shortcuts.dart` 骨架、注册表除追加一行外的内容、`widgets/canvas_view.dart` 与 `stage_lane_layer.dart` 等拆分文件、`providers/canvas_nodes_controller.dart`、`lib/core/interfaces/style_lane_repository.dart`（已收 size，不改）、`lib/storage/**`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/lane_wrap.dart
const double kLaneWrapPadding = InkSpacing.xxl; // 48，道厚 = 跨轴范围 + 48，卡离道起始边 24
typedef LaneWrapPlan = ({
  int sortOrder,                                  // 新道的 sort_order
  Map<String, int> shiftedSortOrders,             // 之后各道 sortOrder + 1（laneId → 新值）
  double size,                                    // max(kDefaultLaneSize, 跨轴范围 + 48)
  Map<String, Offset> positions,                  // 选中节点的新世界坐标（主轴不变）
  Map<String, ({Offset position, String? laneId})> prior,
  int styleChangedCount, Set<String> fromLaneIds,
});
String? wrapAnchorLaneId(List<CanvasNode> selected, List<StyleLane> lanes); // 选中里在现存道中、sortOrder 最大的那条；都不在 ⇒ null
LaneWrapPlan planLaneWrap({required List<CanvasNode> selected, required List<StyleLane> lanes, required Set<String> collapsed, required LaneDirection direction});

// providers/canvas_lanes_controller.dart（新增方法）
typedef LaneWrapToken = ({String laneId, String label, LaneWrapPlan plan});
Future<LaneWrapToken> wrapNodesInLane({required LaneWrapPlan plan, required String label}); // 一个 UoW：后移 sort_order → styleLanes.create(sortOrder, size, label) → nodes.update(position_x/y, lane_id)；成功后改 state 并 ref.invalidate(canvasNodesControllerProvider(arg))
Future<void> unwrapLane(LaneWrapToken token);  // 一个 UoW：节点回 prior → softDelete 新道 → sort_order 还原
Future<void> rewrapLane(LaneWrapToken token);  // 一个 UoW：styleLanes.restore(新道) → 同样后移 → 节点再移入

// providers/lane_rename_request.dart
final laneRenameRequestProvider = /* AutoDispose StateProvider.family<String?, String> */;

// util/canvas_wrap_actions.dart
Future<void> wrapSelectionInLane(BuildContext context, WidgetRef ref, {required String canvasId, Set<String>? nodeIds}); // nodeIds 缺省 = 选中集
Future<void> unwrapSelectionFromLane(BuildContext context, WidgetRef ref, {required String canvasId}); // 调 canvas_tool_actions.moveNodesToLane(laneId: null)

// models/canvas_command.dart
final class WrapInLaneCommand extends CanvasCommand { /* 持 LaneWrapToken；revert = unwrapLane；apply = rewrapLane；label = wrapInLane */ }

// widgets/shortcuts/wrap_lane_keys.dart
class CanvasWrapInLaneIntent extends Intent {}  class CanvasUnwrapFromLaneIntent extends Intent {}
abstract final class WrapLaneKeys { wrapMeta (keyG, meta) / wrapControl (keyG, control) / unwrapMeta (keyG, meta+shift) / unwrapControl (keyG, control+shift) —— 全部 includeRepeats: false }
```
- 新位置：跨轴世界坐标 = 新道起始边 + 24 +（该卡跨轴坐标 − 选区最小跨轴坐标），起始边按插入后的有效厚度切片（`collapseLaneSlices` + `laneStartOf`）算；道外与道内的卡在缩放 1 下世界坐标 = 泳道栈坐标（`lane_pin_geometry.dart` 的 `crossToScreen` 在 scale 1 时恒等），所以相对位置在缩放 1 下逐像素不变。
- 改名请求：`wrapSelectionInLane` 成功后写 `laneRenameRequestProvider(canvasId) = laneId`；LaneTitleBar 消费后写回 null。新道 label 预填 ARB「新泳道」。
- 撤销：成功后 `canvasHistoryControllerProvider(canvasId)` 推一条 `WrapInLaneCommand`（push 方法名以 W0 落地为准），返回 stepId；撤销卡的「撤销」调 `undoSpecific(stepId)`。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 插入位：选区有卡在现存道里 ⇒ 新道 sort_order = 锚定道 + 1，其后各道 +1；全不在道里 ⇒ 放末尾（max + 1，其余不动）。
2. 道厚 = max(400, 选区包围盒跨轴尺寸 + 48)；跨轴 = 泳道方向 horizontal 时的 y、vertical 时的 x；包围盒含卡片尺寸 `kNodeCardSize`。
3. 主轴坐标不变；跨轴按上面公式；卡片两两相对位置在缩放 1 下不变；每张卡心落在新道带内。
4. 建道 + 后移 sort_order + 移节点在一个事务里；任何一步失败 ⇒ 整体回滚：道没建、sort_order 不变、节点位置与 lane_id 不变；弹错误卡「包成泳道失败」；不推撤销步、不进改名态。
5. 成功后：新道标题栏进改名态（输入框预填「新泳道」并全选），↵ 存（改名另算一步，走 W6 的改名命令），Esc 退出保留「新泳道」。
6. 撤销栈：包成泳道 = 一步；Ctrl Z ⇒ 节点回原位原道、新道软删、其后各道 sort_order 还原；Ctrl Y ⇒ 新道恢复（同一 id）并再次移入。
7. 风格卡：选中里有原在别的（现存）道里的卡 ⇒ 弹 `ToastKind.undo`（8 秒）卡；单一来源道写「N 张从「X」换到新泳道，风格变了」，多条写「N 张从 M 条泳道换到新泳道，风格变了」；全部来自道外 ⇒ 不弹。卡上「撤销」= `undoSpecific(stepId)`，与 Ctrl Z 撤同一步。
8. 空选中按 Ctrl G ⇒ 胶囊「先选中要包进泳道的节点」，不建道、不推步。
9. 选中里包含折叠道里的卡：照常移入；新道不折叠。
10. Ctrl Shift G：选中里至少一张在现存道里才执行（`canRemoveFromLane` 同口径），走 `moveNodesToLane(laneId: null)`（屏幕上不动、算一步撤销，W4 已做）；都不在道里 ⇒ 不执行、不出提示。
11. F / 工具条「泳道」/ 新建菜单「泳道」不变：只开新建对话框、不看选中（写测试钉住）。
12. 菜单：节点菜单「包成泳道」显示键位（Windows「Ctrl G」/ mac「⌘G」）；目标 ≥ 1 张即可点。
13. 对文字让位：焦点在提示词条 / 检查器输入框 / 泳道改名框里时 Ctrl G 交给输入框；`includeRepeats: false`，按住只建一条道。
14. 并发：控制器的串行队列保证连按两次 Ctrl G 依次建两条道（第二次以第一次之后的泳道表为准）；包道进行中节点控制器另有写入在途时，以包道后 invalidate 重读的数据库内容为准。
15. 关掉画布：撤销栈随画布丢弃（W0 规则），已建的道保留。
16. mac 用 ⌘G / ⇧⌘G，Windows 用 Ctrl G / Ctrl Shift G；两组 activator 都注册（与现有 kCanvasShortcuts 同一做法），菜单与快捷键页按平台只显示一组。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| laneWrapMenuItem | Wrap in lane | 包成泳道 |
| laneWrapDefaultName | New lane | 新泳道 |
| laneWrapFailed | Couldn't wrap nodes in a lane | 包成泳道失败 |
| laneWrapNeedSelection | Select the nodes to wrap first | 先选中要包进泳道的节点 |
| laneWrapStyleChangedOne | {count} moved from "{lane}" to the new lane — style changed | {count} 张从「{lane}」换到新泳道，风格变了 |
| laneWrapStyleChangedMany | {count} moved from {laneCount} lanes to the new lane — style changed | {count} 张从 {laneCount} 条泳道换到新泳道，风格变了 |
| canvasCommandWrapInLane | Wrap in lane | 包成泳道 |
| laneUnwrapShortcutLabel | Remove from lane | 移出泳道 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/lane_wrap_test.dart`（新）
  - `锚定道 = 选中里 sortOrder 最大的道`；`都不在道里 → null`。
  - `插在锚定道之后、其后各道 +1`；`无锚定 → 末尾且不平移`。
  - `道厚至少 400`（两张同行卡）；`道厚 = 跨轴范围 + 48`（三行卡跨 700 → 748）；`竖向泳道按 x 算`。
  - `主轴坐标不变`；`相对位置不变`（两两差相等）；`首卡离起始边 24`；`每张卡心在新道带内`。
  - `styleChangedCount 只数原在别的现存道的卡`；`fromLaneIds` 去重。
- `test/features/canvas/providers/canvas_lanes_wrap_test.dart`（新，Fake 仓储 + FakeUnitOfWork）
  - `wrapNodesInLane 只走一次 uow.run`；`create 收到 size 与 sortOrder`；`其后各道 update sortOrder`；`节点 update 写 position + lane_id`；`成功后 state 含新道且按 sortOrder 排`；`节点控制器被 invalidate`（listen 计重建次数）。
  - `unwrapLane 复原 sort_order、软删新道、节点回 prior`；`rewrapLane 用 restore 而非 create`（同一 id）。
  - `create 抛错 → state 不变且上抛`。
- `test/storage/lane_wrap_transaction_test.dart`（新，`@Tags(['pg'])`，沿用 `schema/pg_test_harness.dart`）：`第 2 张节点写失败 → 道、sort_order、节点全不变`。
- `test/features/canvas/util/canvas_wrap_actions_test.dart`（新）
  - `成功推一步 WrapInLaneCommand、undo 后泳道数与节点 lane_id 复原`；`失败不推步、弹「包成泳道失败」、不写改名请求`。
  - `来自一条道弹单数卡、来自两条道弹复数卡、全来自道外不弹`；`卡上撤销调 undoSpecific(stepId)`。
  - `空选中出胶囊不建道`。
  - `Ctrl Shift G 走 moveNodesToLane(null)`；`都不在道里不执行`。
- `test/features/canvas/widgets/lane_title_bar_rename_request_test.dart`（新）：`请求等于本道 id → 出输入框且全选`；`消费后请求清空`；`别的道 id 不进改名`。
- `test/features/canvas/widgets/canvas_wrap_lane_shortcuts_test.dart`（新）：`Ctrl G 建道`、`⌘G 建道`（`debugDefaultTargetPlatformOverride = macOS`）、`输入框有焦点时 Ctrl G 不建道`、`按住 Ctrl G 只建一条`、`F 仍开对话框且不看选中`、`节点菜单有「包成泳道」且显示键位`。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. `wrapAnchorLaneId` 改成取 sortOrder 最小的道 → `锚定道 = sortOrder 最大` 红。
2. 去掉后续道 +1 平移 → `插在锚定道之后、其后各道 +1` 红。
3. 道厚下限 400 去掉 → `道厚至少 400` 红；padding 改 24 → `道厚 = 跨轴范围 + 48` 红。
4. 跨轴公式不减最小值（直接用原坐标）→ `首卡离起始边 24` / `卡心在新道带内` 红。
5. 主轴也重排 → `主轴坐标不变` 红。
6. 建道与移节点拆成两次 `uow.run` → `只走一次 uow.run` 红（pg 用例：`第 2 张写失败 → 全不变` 红）。
7. `rewrapLane` 用 `create` 新建 → `rewrapLane 用 restore`（id 相同）红。
8. 不推命令 → `成功推一步` 红；失败也推 → `失败不推步` 红。
9. 风格卡对道外卡也计数 → `全来自道外不弹` 红。
10. 不写改名请求 / LaneTitleBar 不 watch → 改名请求用例红。
11. 快捷键动作不对文字让位 → `输入框有焦点时 Ctrl G 不建道` 红；漏 `includeRepeats: false` → `按住只建一条` 红。
12. 把 F 改成「有选中时包道」→ `F 仍开对话框且不看选中` 红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑：`flutter analyze lib test`；`flutter test test/features/canvas test/storage/lane_wrap_transaction_test.dart --exclude-tags golden`（pg 用例在有 `TEST_PG_URL` 的 CI 跑）；上面 12 条变异。
- 截图（CanvasScreen + 假仓库）：横向两条道「水墨风格」（含镜头 02 视频配置 + 成片）与「白天」，道外一张镜头 03；选中这三张。截：按 Ctrl G 前 / 后（新道插在「水墨风格」之后、标题栏输入框「新泳道」全选、右下撤销卡「2 张从「水墨风格」换到新泳道，风格变了」）/ Ctrl Z 后（恢复原样）/ 竖向泳道同场景一张 / 节点右键菜单「包成泳道 Ctrl G」与 mac「⌘G」各一张。

## 风险与不确定
- 世界坐标与泳道栈坐标的换算以 `laneMoveDelta`（`util/node_menu_model.dart` 第 152–190 行，只读）同一套公式为准；若执行代理发现 scale ≠ 1 时卡片在包道后屏幕上跳动，以「缩放 1 下相对位置不变 + 卡心在带内」两条测试为准，不追求任意缩放下屏幕不动。
- 包道直接在 UoW 里写 nodes，绕过了节点控制器的串行队列，靠成功后 invalidate 重读；若与在途的拖动提交打架（极少），以库为准。不改 canvas_nodes_controller.dart（本波无人拥有，避免冲突）。
- canvas_command.dart 本波只归本片，且只加 `WrapInLaneCommand` 与 `wrapInLane` 标签；主 Agent 已裁决不替 align / disable 加标签（它们沿用通用标签，后续波次补）。
- W7 cm-lane-menu 落地的原地改名接口名（例如 LaneTitleBar 是否已是 Stateful、编辑态字段名）以落地为准；本片只加「外部请求进入改名」这一个入口。
