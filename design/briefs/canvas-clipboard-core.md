# canvas-clipboard-core · 应用内剪贴板与快照改写（纯函数）：选区 → 快照，粘贴时换新 id、剥掉选区外引用、跨项目改写角色、算落点
- 波次 W7 / lane C 第一片 / 基底 origin/main〔W0–W6 已合入〕；依赖切片：multi-select-core（W0）、current-take（W1，pinned_result_id 键）、gen-inputs-snapshot（W2，gen_inputs 与 stripUnmappedGenInputs）；阻塞决定：无（UC-Q4 按建议 A）

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 本片不出界面，只做 clipboard-paste（同 lane 下一片）要用的底座：一个应用级剪贴板 provider，一套「选区 → 快照 → 粘贴草稿」的纯函数，一个「粘到哪」的纯函数。
- 用户侧没有可见变化；但规则全部在这里被单测钉死：只带两端都在选区里的线、产物只带当前主图、选区外的溯源断开（UC-Q4 A）、跨项目去掉角色。

## 设计依据
- UndoClipboard.dc.html ·「复制 / 粘贴节点」：带上两端都在选区里的线；产出线由 source_node_id 推导，跟着换新 id；不复制批量 slot 和任务记录，产物只带当前主图（image_url / video_url / thumbnail_url）；mock 里选区外的「远山参考」那条参考线不跟着走。
- 同板「粘贴到哪 · 带什么」：
  - 落点表：指针在画布上 → 选区包围盒中心对准指针；右键「粘贴」→ 右键按下那一点（与新建菜单同一锚点）；指针不在画布 · 同画布 → 原位置右下偏 lg、连按每次再偏一格；指针不在画布 · 别的画布 → 视口中心。
  - 跨界表：媒体文件 同画布引用同一个文件 / 别的画布与别的项目复制一份；溯源 选区内换新 id、选区外断开（按 **UC-Q4 建议 A**：断开，成为未入链的独立图）；角色引用 同画布 / 同项目保留，别的项目挂载和 @ 记号都去掉、胶囊提示；泳道按落点重新判（resolveLaneDrop），不带原泳道 id；参数原样。
- 同板「要补的底座」：粘贴改写 id 同 import_remapper：`pinned_result_id`、`gen_inputs` 里的源节点 id 选区内换新、选区外剥掉；跨项目再把提示词里的 `@{角色 id}` 换成角色名纯文字。
- ImportSearch.dc.html ·「提示词里 @角色」末条：角色没跟过来的——记号降成纯文字「@名字」，同时从 character_ids 剔除；名字取不到就删掉记号。记号格式按 **IS-Q3 建议 A**（`@{<角色 id>}`）。
- 设计缺口：①「右键按下那一点」是包围盒左上角还是中心——本片按「与新建菜单同一锚点」= 新卡片左上角落在锚点上，取**包围盒左上角**；②正在生成、还没有产物的 result 节点复制时怎么办——本片跳过（空壳不复制）；③泳道里的节点包围盒按世界坐标算（泳道锚定位移不计），粘贴后按「不在道里的卡」重判归属。

## 允许改的文件
- `lib/features/canvas/providers/canvas_clipboard.dart`（新）：应用级 `canvasClipboardProvider`（keepAlive，非 family）。
- `lib/features/canvas/util/clipboard_snapshot.dart`（新，纯函数）：快照、草稿、第二遍改写、角色降级、纯文字。
- `lib/features/canvas/util/paste_placement.dart`（新，纯函数）：落点。
- 测试：`test/features/canvas/util/clipboard_snapshot_test.dart`（新）、`test/features/canvas/util/paste_placement_test.dart`（新）、`test/features/canvas/providers/canvas_clipboard_test.dart`（新）。

## 不许碰的文件
- `node_card.dart`、`util/take_staleness.dart`、`left_rail/outline_panel.dart`、`util/outline_model.dart`（W7 tc-stale-marks）。
- `widgets/stage/node_card_slot.dart`、`providers/node_drag_delta.dart`、`widgets/edge_painter.dart`、`widgets/stage/stage_edge_layer.dart`、`widgets/stage/stage_overlays.dart`、`util/narrative_drop_insert.dart`、`util/canvas_narrative_drop_actions.dart`（W7 cm-drag-insert-narrative）。
- `lane_title_bar.dart`、`widgets/stage/stage_lane_layer.dart`、`canvas_menu/canvas_menu_host.dart`、`canvas_menu/canvas_menu_request.dart`、`canvas_menu/lane_menu_entries.dart`、`util/lane_menu_model.dart`、`providers/lane_collapse_controller.dart`、`util/canvas_lane_actions.dart`（W7 cm-lane-menu）；`node_card.dart`、`util/take_staleness.dart`、`providers/stale_takes_provider.dart`（W7 tc-stale-marks）。
- `shell/*`、`app.dart`、`main.dart`、`windows/runner/*`（W7 lone-alt / mac-platform-menubar）。
- `services/import/import_remapper.dart`（不在本波任何片的清单里；共享函数等 mention-token-core 再抽，见风险）、`canvas_nodes_controller.dart`、`canvas_paste_actions.dart`、键位与菜单（都归下一片 clipboard-paste）。

## 具体改动
```dart
// util/clipboard_snapshot.dart
@immutable class ClipNode {
  final String oldId; final CanvasNodeType type; final NodeRole role; final String label;
  final Offset position; /* 世界坐标 */ final Size size;
  final Map<String, Object?> typeConfig; // 已清洗：result 只留主图白名单键
  final String? sourceOldId; // 只在源配置也在选区里时保留（UC-Q4 A）
  List<String> get mediaPaths; // image_url / video_url / thumbnail_url 里非空的相对路径
}
@immutable class ClipEdge { final String sourceOldId, targetOldId; final EdgeType edgeType; final EdgeRole role; final int sortOrder; }
@immutable class ClipboardSnapshot {
  final String sourceProjectId, sourceCanvasId; final List<ClipNode> nodes; final List<ClipEdge> edges;
  final Rect bounds; // 世界坐标，节点矩形（position & size）之并
  final Map<String, String> characterNames; // 复制那一刻源项目的角色 id → 名字（跨项目降级用）
}
/// 选区 → 快照。选区里没有可复制的节点（全是空壳 result / id 都不在 nodes 里）→ null。
ClipboardSnapshot? buildClipboardSnapshot({required Set<String> selection, required List<CanvasNode> nodes,
  required List<CanvasEdge> edges, required String projectId, required String canvasId,
  required Map<String, String> characterNames});
enum PasteScope { sameCanvas, sameProject, otherProject }
PasteScope pasteScopeOf(ClipboardSnapshot s, {required String projectId, required String canvasId});
/// 第一遍：建节点用的草稿。顺序 = 被 sourceOldId 引用的在前（配置 / 文本 / 镜头先、产物后）；
/// 选区外的引用已剥掉；跨画布时媒体路径按 [mediaPathMap]（旧相对路径 → 目标画布里的新相对路径）改写；
/// otherProject 时 character_ids 删掉、prompt 里的记号降级。
@immutable class PasteNodeDraft { final ClipNode node; final Map<String, Object?> typeConfig; final String? sourceOldId; }
@immutable class PasteDraft { final List<PasteNodeDraft> nodes; final List<ClipEdge> edges; final int droppedCharacterRefs; final PasteScope scope; } // scope 由 draftPaste 记下，pasteSnapshot 第二遍要用
PasteDraft draftPaste(ClipboardSnapshot s, {required PasteScope scope, Map<String, String> mediaPathMap = const {}});
/// 第二遍：拿到旧 → 新 id 后要补的 type_config patch（pinned_result_id、gen_inputs）；不需要补 = null。内部就是对「原 type_config 里这两个键」调 W2 的 stripUnmappedGenInputs（见下）。
Map<String, Object?>? secondPassPatch(PasteNodeDraft d, Map<String, String> idMap, {required PasteScope scope});
/// `@{id}` → `@名字`；名字不在 [names] → 整个记号删掉。返回改写后的文字与被改写的个数。
({String text, int replaced}) degradeCharacterMentions(String text, Map<String, String> names);
/// 写进系统剪贴板的纯文字：每个节点一行「名称」或「名称: 提示词 / 正文」，按画布阅读顺序（y 再 x）。
String clipboardPlainText(ClipboardSnapshot s, {required String Function(ClipNode) displayName});

// util/paste_placement.dart
sealed class PasteAnchor { const PasteAnchor(); }
final class PointerPasteAnchor extends PasteAnchor { final Offset viewportPoint; }   // 指针在画布上
final class MenuPasteAnchor extends PasteAnchor { final Offset viewportPoint; }      // 右键「粘贴」
final class NoPointerPasteAnchor extends PasteAnchor { const NoPointerPasteAnchor(); }
/// 每个旧 id → 新节点左上角世界坐标 + 泳道归属。[repeat] = 同画布、指针不在画布时这份快照已经粘过几次（0 起）。
Map<String, NodePlacement> layoutPaste({required ClipboardSnapshot snapshot, required PasteAnchor anchor,
  required bool sameCanvas, required int repeat, required Matrix4 transform, required Size viewport,
  required List<({String id, double size})> laneSlices, required LaneDirection direction});

// providers/canvas_clipboard.dart
@immutable class CanvasClipboardState { final ClipboardSnapshot snapshot; final String systemText; final int repeatInSource; }
final canvasClipboardProvider = NotifierProvider<CanvasClipboard, CanvasClipboardState?>(CanvasClipboard.new, name: 'canvasClipboardProvider');
class CanvasClipboard extends Notifier<CanvasClipboardState?> {
  void put(ClipboardSnapshot s, {required String systemText}); // 新复制：repeatInSource 归零
  int takeRepeat(String canvasId); // 同画布、指针不在画布时取当前次数并 +1；别的画布恒 0、不计数
  void clear();
}
```
- 产物 type_config 白名单：`image_url`、`video_url`、`thumbnail_url`、`width`、`height`、`seed`、`duration_ms`、`gen_inputs`、导入来源键（`origin`、`original_name`，常量取 media-import-service 的）；其余（job / 批量相关）不带。配置 / 文本 / 镜头：type_config 原样（参数原样），只特殊处理 `pinned_result_id`、`character_ids`、`prompt` 里的记号。
- `pinned_result_id`（`TakeKeys.pinnedResultId`，current-take 在 `lib/core/constants/take_keys.dart` 定义）与 `gen_inputs`（`TakeKeys.genInputs`）：**第一遍一律从草稿 typeConfig 里拿掉**（建节点时还没有新 id）；原值留在 `ClipNode.typeConfig` 里给第二遍。
- 第二遍：`secondPassPatch` 对 `{pinned_result_id: 原值?, gen_inputs: 原值?}` 调 W2 gen-inputs-snapshot 的 `stripUnmappedGenInputs(typeConfig, mapNode: (old) => idMap[old], mapCharacter: scope == PasteScope.otherProject ? (_) => null : (id) => id)` → `({Map typeConfig, int dropped})`：映射得到的就改写成新 id，映射不到的**整个键删掉**（W2 的语义：gen_inputs 里任一源 / 角色映射不到 ⇒ 整份 gen_inputs 不要 = 「没快照」；pinned_result_id 映射不到 ⇒ 删键）。返回结果里还剩的键作为 patch（两个都没剩 ⇒ null）。不另写一套改写逻辑。
- 不带 `lane_id`（ClipNode 不存它）；落点里按 resolveLaneDrop 重判。
- `layoutPaste` 先定原点：Pointer → 包围盒中心 = viewportToWorld(指针)；Menu → 包围盒左上角 = viewportToWorld(锚点)；NoPointer 同画布 → 原位置 + kDuplicateOffset ×（repeat + 1）（`kDuplicateOffset` 从 canvas_tool_actions.dart 引，同一个常量）；NoPointer 别的画布 → 包围盒中心 = viewportToWorld(视口中心)。每个节点 = 原点 + 相对包围盒的偏移，按「不在道里的卡」走 `resolveLaneDrop(centerCrossWorld: 卡中心, fromLaneId: null)` 得 laneId 与横截坐标，最后 `clampIntoWorldReach`——与 `createNodePlacement` 同一套判法（drop_placement.dart:168）。

## 行为规则与边界情况
1. 只带两端都在选区里的存量边（data / narrative 都算），sortOrder 原样；一端在选区外的边丢掉。
2. 产物的源配置也在选区里 → sourceOldId 保留（粘贴后换新 id，产出线跟着出现）；不在 → null（断开溯源，UC-Q4 A），即使是同画布粘贴也断开。
3. 还没有任何主图的 result（image_url、video_url 都空）不进快照；选区只剩这类 → buildClipboardSnapshot 返回 null。
4. 批量 slot、任务记录不在快照里（它们不在 nodes 里，本来就不会带）；产物的主图就是 type_config 里那一张。
5. 配置的 pinned_result_id 指向选区内的产物 → 粘贴后指向新产物；指向选区外 → 键被去掉（新配置的当前 take 回落为最新）。
6. gen_inputs：所有源节点都在选区内（且 otherProject 时没有 character_ids）⇒ 换成新 id 带过去；任一源在选区外 / 跨项目带角色 ⇒ 整份不带（W2 `stripUnmappedGenInputs` 的口径；tc-stale-marks 对「没快照」的产物不标过期）。
7. sameCanvas / sameProject：character_ids 与 prompt 原样。otherProject：character_ids 整键删掉；prompt 里 `@{id}` → `@名字`（名字取复制时快照的 characterNames），取不到名字的记号删掉；`droppedCharacterRefs` = 删掉的挂载数 + 改写的记号数（> 0 时下一片出胶囊）。
8. sameCanvas 不改写任何媒体路径；其余 scope 按 mediaPathMap 改写，map 里没有的路径原样（下一片保证复制齐了才调）。
9. 落点四种情形按上面的原点规则；同画布、指针不在画布连粘三次 → 分别偏 1×、2×、3× lg；新复制一次后从 1× 重新开始；粘到别的画布不计数。
10. 落进泳道的判定逐个节点做：一组节点跨在两条道上，粘贴后也各归各的道。
11. 剪贴板是应用级：关掉源画布、切到别的项目后仍可粘贴（快照只持数据，不持 ref）。
12. 纯文字：文本节点写正文、配置写提示词、产物只写名称；空提示词只写名称。

## 新文案键
无（本片无界面；节点默认名由下一片通过 `displayName` 回调传入）

## 测试
- `test/features/canvas/util/clipboard_snapshot_test.dart`：
  - `只带两端都在选区里的边`：A→B 参考边 + 选区外 C→B → 快照只有 A→B。
  - `源配置在选区内保留溯源、在选区外断开`（同画布也断开）。
  - `空壳 result 不复制`；`全是空壳返回 null`。
  - `产物 type_config 只留白名单`（塞一个 job_id / batch 键 → 不在快照里）。
  - `pinned_result_id 选区内第二遍换新、选区外第一遍去掉`。
  - `gen_inputs：源全在选区内 ⇒ 换新 id；有一个源在选区外 ⇒ 整份不带；跨项目且快照带角色 ⇒ 整份不带`（用 W2 的真实函数）。
  - `跨项目去掉 character_ids 并降级记号`：`"@{c1} 站在船头"` + names{c1: 渔夫} → `"@渔夫 站在船头"`；未知 id → 记号删掉；droppedCharacterRefs 计数。
  - `同项目保留角色`；`同画布不改媒体路径、跨画布按 mediaPathMap 改`。
  - `草稿顺序：被引用的配置排在产物前`。
  - `纯文字按阅读顺序、文本写正文`。
- `test/features/canvas/util/paste_placement_test.dart`：
  - `指针在画布：包围盒中心对指针`（缩放 2、平移 ≠ 0）。
  - `右键粘贴：包围盒左上角对锚点`。
  - `同画布无指针：按 repeat 递增偏 lg`。
  - `别的画布无指针：包围盒中心对视口中心`。
  - `逐个节点判泳道`：两条横向泳道，一组跨道的节点各归各道。
  - `落点收进 ±kWorldReach`。
- `test/features/canvas/providers/canvas_clipboard_test.dart`：
  - `put 之后 repeat 从 0 起`；`takeRepeat 同画布递增、别的画布恒 0`；`新 put 归零`；`keepAlive：没有监听者也不丢`（container 里 read 后 pump，再 read 仍在）。

## 变异点
1. 边过滤改成「任一端在选区里」→ `只带两端都在选区里的边` 红。
2. 同画布时保留选区外的 sourceOldId → `源配置在选区内保留溯源、在选区外断开` 红。
3. 去掉空壳过滤 → `空壳 result 不复制` 红。
4. 产物 type_config 改成整份拷贝 → `产物 type_config 只留白名单` 红。
5. `secondPassPatch` 不写 pinned_result_id → `pinned_result_id 选区内第二遍换新` 红。
6. otherProject 不删 character_ids → `跨项目去掉 character_ids 并降级记号` 红。
7. `degradeCharacterMentions` 对未知 id 保留原记号 → 同一条测试的未知 id 断言红。
8. Menu 锚点改成对中心 → `右键粘贴：包围盒左上角对锚点` 红。
9. `layoutPaste` 忽略 repeat → `同画布无指针：按 repeat 递增偏 lg` 红。
10. 泳道只按包围盒中心判一次 → `逐个节点判泳道` 红。
11. `takeRepeat` 对别的画布也计数 → `takeRepeat 同画布递增、别的画布恒 0` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/util/clipboard_snapshot_test.dart test/features/canvas/util/paste_placement_test.dart test/features/canvas/providers/canvas_clipboard_test.dart`。
- 变异 1–11 逐条。无 UI，不截图。

## 风险与不确定
- 计划里说角色降级「可以和 import_remapper 抽一个共享函数」。import_remapper 在 W7 不归任何片，但它不在本 lane 的文件表里，而且 `@{id}` 的正式解析器归 W11 mention-token-core（IS-Q3）。本片把 `degradeCharacterMentions` 写在 clipboard_snapshot.dart，W11 那片把它挪进记号模块并让 import_remapper 共用——请主 Agent 在 W11 派工单里写上这一条。
- （复核已定）W2 的 `stripUnmappedGenInputs(Map typeConfig, {mapNode, mapCharacter}) → ({typeConfig, dropped})` 同时做「换新 id」与「剥」，并且连 `pinned_result_id` 一起处理；但它是「整份删」不是「只留选区内的源」——本片按它的口径（见规则 6），不另写。
- 板上「右键按下那一点」的语义按左上角解释（设计缺口 ①），若产品要中心，只改 layoutPaste 的 Menu 分支和对应测试。
- 包围盒用世界坐标、不计泳道锚定位移：缩放远离 1 时，道内节点粘出来的相对位置会与屏幕上看到的略有出入（设计缺口 ③）。
