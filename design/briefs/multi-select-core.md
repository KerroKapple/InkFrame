# multi-select-core · 选中控制器补批量方法 + 选区几何纯函数（框选命中 / 选区包围盒）
- 波次 W0 / lane E / 基底 origin/main（f64f56e）；同 lane 之后串 duration-format（文件不相交）
- 依赖切片：无；阻塞决定：无（Selection Q1 未拍板，按建议 A）

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/<切片id>`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标（用户看到什么变化，2–4 行）
用户暂时看不到变化（纯底座，无 UI、无文案）。
给后面的框选（W3 marquee-select）、浮动工具条、对齐分布、粘贴落点、Ctrl G 包成泳道提供同一套「选中集合运算」与「哪些卡在框里 / 选区包围盒」判据，避免每片各写一份几何。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- Selection.dc.html「框选与加减选」：
  - 「拖框：不按键替换；Shift 加选；Ctrl（mac 用 ⌘）反选」→ `MarqueeMode { replace, add, invert }`。
  - 「碰到框就算选中（Q1）；折叠泳道里的卡不参与；便签、文本照常可选」→ `marqueeHits` 只看几何，不看节点类型；跳过折叠道里的卡。
  - 「需：选中控制器补 replace / addAll / toggleAll」。
- Selection.dc.html「对齐 · 分布 · 排布」：「对齐按选区包围盒」→ `selectionBounds`。
- 按建议：Selection Q1 → A（碰到就算，与 tldraw / Figma 一致）。判据集中在一个私有谓词 `_touches(Rect a, Rect b)`，日后改 B / C 只换它。
- 设计缺口：画板没说「恰好贴边（交集面积为 0）」算不算碰到——本片定为算（闭区间），写进测试。
- 设计缺口：选区包围盒里含折叠道里的卡时怎么算没写——本片定为跳过（与命中口径一致：看不见的卡不参与几何）。

## 允许改的文件（逐个路径 + 每个文件改什么）
- `lib/features/canvas/providers/canvas_selection_controller.dart`：在现有 `select` / `selectAll` / `clear` / `removed` 之后追加 `replace` / `addAll` / `toggleAll` / `removeAll`；`selectAll` 的方法体改为调用 `replace`（行为不变，Ctrl+A 仍走 selectAll）。不改 provider 名、不改 autoDispose。
- `lib/features/canvas/util/selection_geometry.dart`（新，纯 Dart，只 import flutter/widgets 的几何类型与 canvas 的 model / util）。
- `test/features/canvas/canvas_selection_controller_test.dart`：在现有 group 里追加用例（不改已有用例）。
- `test/features/canvas/util/selection_geometry_test.dart`（新）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- menu-split：`create_node_menu.dart`、`widgets/canvas_menu/**`、`lib/theme/components/ink_menu_panel.dart`。
- canvas-view-split：`canvas_view.dart`、`widgets/stage/**`（本片**不接 UI**，舞台怎么用这些函数归 W3 marquee-select）。
- esc-ladder → zoom-reset-100：`canvas_shortcuts.dart`、`widgets/shortcuts/**`、`util/escape_ladder.dart`、`providers/canvas_escape_ladder.dart`、`settings/util/shortcut_catalog.dart`、`util/canvas_zoom.dart`。
- undo-stack → naming-shot-unify：`models/canvas_command.dart`、`models/edge_endpoints.dart`、`providers/canvas_history_controller.dart`、`storyboard/widgets/script_import_dialog.dart`。
- 另外只读：`util/viewport_focus.dart`（复用 `nodeStageRect`）、`util/viewport_fit.dart`（`nodesStageBounds` 不改）、`util/lane_pin_geometry.dart`、`util/lane_geometry.dart`、`models/canvas_node.dart`。
- （主 Agent 自查补充）duration-format（同 lane 后叠）：`lib/l10n/duration_format.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// canvas_selection_controller.dart（追加）
/// 整体替换为 [ids]；集合相等不改 state 引用。
void replace(Iterable<String> ids);
/// 并入 [ids]；没有新增就不改 state 引用。
void addAll(Iterable<String> ids);
/// 对 [ids] 逐个取反（在的去掉、不在的加上）；[ids] 为空不改 state 引用。
void toggleAll(Iterable<String> ids);
/// 去掉 [ids]；一个都不在选中里就不改 state 引用。
void removeAll(Iterable<String> ids);

// util/selection_geometry.dart
enum MarqueeMode { replace, add, invert }

/// 舞台坐标的框 [stageRect] 碰到（闭区间相交，含贴边）哪些卡。卡的矩形走 nodeStageRect（世界 + kStageOrigin + 分道位移，
/// 与卡片 Positioned 同源）；laneId 在 [collapsedLaneIds] 里的卡跳过；节点类型不参与判断。
Set<String> marqueeHits({
  required Rect stageRect,
  required List<CanvasNode> nodes,
  required List<({String id, double size})> lanes, // 有效厚度切片（collapseLaneSlices 之后）
  required LaneDirection direction,
  required Matrix4 transform,
  Set<String> collapsedLaneIds = const <String>{},
});

/// 框选结果：replace = hits；add = before ∪ hits；invert = before △ hits（对称差）。
Set<String> applyMarquee(Set<String> before, Set<String> hits, MarqueeMode mode);

/// [ids] 里的卡（跳过不在 [nodes] 里的 id 与折叠道里的卡）在舞台坐标下的包围盒；一张都没有 ⇒ null。
Rect? selectionBounds({
  required Set<String> ids,
  required List<CanvasNode> nodes,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required Matrix4 transform,
  Set<String> collapsedLaneIds = const <String>{},
});
```
- `stageRect` 允许起点在右下（调用方用 `Rect.fromPoints`，已规范化）；宽或高为 0 的框照样按闭区间判。
- 不新增 provider；不改 `nodesStageBounds`（它按「纯缩放矩阵」问，给适应视口用；本片的 `selectionBounds` 按当前 transform 问，给浮动条 / 对齐用）。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 碰到即算：框与卡矩形有任何重叠（含只碰到一角、只贴着一条边）就命中；整张框住当然命中。
2. 卡的位置按渲染位置算：泳道里的卡在缩放 ≠ 1 时带分道位移（`lanePinDisplacement`），框按屏幕上看到的卡判，不按世界坐标判。
3. 折叠道（id 在 `collapsedLaneIds`）里的卡不命中、不计入包围盒；laneId 指向已不存在的道的卡按无道卡算（nodeStageRect 现成行为）。
4. 文本、便签（将来的 variant）、产物、配置节点一视同仁。
5. `applyMarquee` 不改入参集合，返回新集合；`before` 为空时 add / invert 都等于 hits。
6. 选中控制器四个新方法在「结果与当前集合相等」时不赋值（不触发重建），与现有 `selectAll` / `clear` 的约定一致。
7. 空输入：`replace([])` = 清空（当前非空时）；`addAll([])` / `toggleAll([])` / `removeAll([])` 不改引用。
8. 与撤销栈：选中是纯 UI 态，不进撤销栈。
9. mac / Windows 无差异（修饰键 → 模式的映射归 W3 marquee-select）。

## 新文案键（key · en · zh 表；没有写无）
无。

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
`test/features/canvas/canvas_selection_controller_test.dart`（追加，沿用文件里的 container / ctrl / s()）：
- 「replace 整体替换」：先 select('a')，replace(['b','c']) → {'b','c'}。
- 「replace 集合相等时不改变 state 引用」：`identical(before, s())`。
- 「addAll 并入，已在的不重复」：{'a'} + ['a','b'] → {'a','b'}；「addAll 没有新增时不改变引用」。
- 「toggleAll 逐个取反」：{'a','b'} toggleAll(['b','c']) → {'a','c'}。
- 「removeAll 只去掉在的」：{'a','b'} removeAll(['b','x']) → {'a'}；「removeAll 一个都不在时不改变引用」。
- 「selectAll 仍整体替换（改走 replace 后行为不变）」：现有两条 selectAll 用例保持原样即覆盖。

`test/features/canvas/util/selection_geometry_test.dart`（新；数据：kNodeCardSize = 224×191，kStageOrigin = (50000, 50000)，横向泳道 `lanes = [(id:'L1', size:400), (id:'L2', size:300)]`，`Matrix4.identity()` 或 `Matrix4.diagonal3Values(0.5, 0.5, 1)`）：
- 「整张框住：命中」：无道节点 a 世界 (0,0)，框 = kStageOrigin + (-10,-10) → (+300,+300) → {'a'}。
- 「只碰到一角也算（Q1-A）」：框 = 卡右下角往外 1px 起、往里 5px 的小框 → {'a'}。
- 「恰好贴着边（交集面积 0）也算」：框左边 x = 卡右边 x → {'a'}。
- 「离开 1px 不算」：框左边 x = 卡右边 x + 1 → {}。
- 「折叠道里的卡不命中」：b 在 L1、collapsedLaneIds = {'L1'}，框整张盖住 b → {}；同一框不传 collapsed → {'b'}。
- 「泳道里的卡按分道位移后的位置命中（缩放 0.5）」：c 在 L2、世界 (0,0)；scale 0.5 时分道位移 = (400·0.5)/0.5 = 400（纵向）；框 kStageOrigin + (10,410)→(20,420) 命中 {'c'}；框 kStageOrigin + (10,10)→(20,20) 不命中。
- 「节点类型不影响命中」：文本节点与图像配置节点同框 → 两个都在。
- 「applyMarquee：replace / add / invert 三种」：before {'a','b'}、hits {'b','c'} → {'b','c'} / {'a','b','c'} / {'a','c'}；「before 为空时 add、invert 都等于 hits」。
- 「selectionBounds：两张卡的并集矩形」：a (0,0)、d (500,100) → 左上 kStageOrigin，右下 kStageOrigin + (724, 291)。
- 「selectionBounds：跳过不存在的 id 与折叠道里的卡；全被跳过返回 null」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写，每条注明哪条测试抓住它）
1. `selection_geometry.dart` `_touches` 改成整张包含（`stageRect.contains(r.topLeft) && stageRect.contains(r.bottomRight)`）→「只碰到一角也算（Q1-A）」红。
2. `_touches` 改成 `Rect.overlaps`（开区间）→「恰好贴着边（交集面积 0）也算」红。
3. `marqueeHits` 去掉 collapsedLaneIds 跳过 →「折叠道里的卡不命中」红。
4. `marqueeHits` 用 `node.position + kStageOrigin` 代替 `nodeStageRect` →「泳道里的卡按分道位移后的位置命中（缩放 0.5）」红。
5. `applyMarquee` 的 invert 分支改成 `before.union(hits)` →「applyMarquee：replace / add / invert 三种」红。
6. `selectionBounds` 去掉折叠道跳过 →「selectionBounds：跳过不存在的 id 与折叠道里的卡…」红。
7. `canvas_selection_controller.dart` `addAll` 去掉「没有新增就 return」→「addAll 没有新增时不改变引用」红。
8. `toggleAll` 写成只 add →「toggleAll 逐个取反」红。
9. `removeAll` 去掉「一个都不在就 return」→「removeAll 一个都不在时不改变引用」红。
10. `replace` 去掉 setEquals 短路 →「replace 集合相等时不改变 state 引用」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test` 零告警；`flutter test test/features/canvas/canvas_selection_controller_test.dart test/features/canvas/util/selection_geometry_test.dart` 全绿；`flutter test test/features/canvas --exclude-tags golden` 不回归。
- 非 UI 片，不截图。

## 风险与不确定
- `selectionBounds` 与 `viewport_fit.dart` 的 `nodesStageBounds` 口径接近但不同（前者用当前 transform、跳过折叠道；后者用纯缩放矩阵、不跳过）。后续对齐 / 浮动条切片必须用本片的函数，适应视口继续用 nodesStageBounds；两者若要合并另开切片。
- 节点矩形恒为 kNodeCardSize（与 drop_placement 的 topmostNodeAt 同口径）；将来便签若尺寸不同，要在 nodeStageRect 一处改，本片函数自动跟上。
