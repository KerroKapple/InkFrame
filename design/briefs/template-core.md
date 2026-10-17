# template-core · 模板核心：画布 / 选中 → 模板骨架，插入换新 id、落到视口中心、单事务；内置模板与短剧示例共用一套建法
- 波次：W16；lane：B；基底：origin/main（W0–W15 全部已合入后的 main）
- 依赖切片：
  - 硬依赖：undo-stack（W0，`canvas_history_controller.dart` + `canvas_command.dart`）、multi-select-core（W0，选中控制器 `selectAll`）、canvas-capsule（W1，插入后的撤销胶囊由 W17 调用方出，本片只保证命令能进栈）——都已在 main。
  - 软依赖：mention-token-core（W11，`lib/core/text/character_mention.dart` 的 `stripToNames`）、tc-gen-inputs-snapshot（W2，`gen_inputs` 键）、tc-current-take-core（W1，`pinned_result_id` 键）——都已在 main；本片只按键名剥掉，不调用它们的改写函数。
- 阻塞决定：无（RailScript-R6 按建议 A：模板不带图；IS-Q3 已在 W11 定为 A，记号格式 `@{角色 id}`）

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
本片不出界面，只落「模板」这一层：把画布（或选中）抓成不含产物 / 媒体 / 角色的骨架，再把骨架插回任意画布（新 id、落到视口中心、一个事务、选中全部、进撤销栈）。
内置三套模板（三幕短片 / 单镜试拍 · 图生视频 / 短剧示例）以代码常量提供；「创建示例项目」改走同一个骨架写入函数，用户看到的示例项目与改造前逐项相同。

## 设计依据
画板 `RailScript.dc.html`（文本版 boards/RailScript.txt）「模板 · P2 · 开局用的镜头链」规则：
- 内置 = 代码常量，与短剧示例同一套建法（`canvas_bootstrap_controller`）。
- 存为模板：整张画布或选中的；存节点、叙事 / 数据边、泳道与风格词；**不存产物、媒体、角色**。
- 插入：新 UUID（照 `import_remapper` 重映射），整体移到视口中心，单事务；插完选中全部 + 撤销通知。
- 插入时一并改写：提示词里的 `@{角色 id}` 剥成纯名字（模板不带角色）；`gen_inputs` 的源节点 id 换新、指向模板外的剥掉。
- 卡片计数：「12 节点 · 9 镜 · 3 泳道 · 11 条线 · 不含产物」；三张内置卡副标题「9 镜 · 3 泳道」「1 镜 · 图像 → 视频」「4 镜 · 1 泳道」。
`TakesCost.dc.html`「过期标记」：「插入模板：模板不带产物，`gen_inputs` 与 `pinned_result_id` 两样都不该出现，出现就剥掉」。
`ImportSearch.dc.html`「提示词里 @角色」：模板没带该角色 ⇒ 记号降成纯文字「@名字」；名字取不到就删掉记号。
`UndoClipboard.dc.html`「什么进栈」：粘贴 / 导入类一次用户编辑 = 一步；反馈只走画布底部胶囊。
设计缺口：画板没说模板落进已有泳道的画布时，模板自己的泳道排在哪、视口中心对不上泳道带时怎么办（本单定：追加在已有泳道之后，主轴居中、横截轴由泳道带决定，插完不在视口就平移相机）；没说跨方向（横向画布抓的模板插进竖向画布）怎么办（本单定：坐标按「主轴 / 横截轴」存，自动转向）。

## 允许改的文件
- `lib/features/templates/models/canvas_template.dart`（新建）：手写不可变模型 + JSON 编解码（不用 freezed，理由同 export-records-table：payload 要原样进 JSONB，结构简单）。
- `lib/features/templates/util/template_capture.dart`（新建，纯函数）：抓骨架 + 计数。
- `lib/features/templates/util/template_remap.dart`（新建，纯函数）：算插入后的泳道序、每张卡的世界坐标与泳道归属、包围盒。
- `lib/features/templates/util/template_writer.dart`（新建）：在一个 `RepositoryScope` 里按「泳道 → 节点 → 边」写入，返回 key → 新 id 表。
- `lib/features/templates/providers/template_insert_controller.dart`（新建）：插入当前画布 / 用模板新建画布两个入口。
- `lib/features/templates/builtin_templates.dart`（新建）：三套内置模板的 payload 构造。
- `lib/features/templates/util/builtin_template_strings.dart`（新建）：`builtinTemplateStringsOf(AppLocalizations l)`，写法照 `lib/features/canvas/util/sample_seed.dart`。
- `lib/features/canvas/providers/canvas_bootstrap_controller.dart`：把「泳道 + 两镜 config + 叙事边」改成 `sampleTemplatePayload(seed)` + `placeTemplate` + `writePlacedTemplate`；成片种子 `_seedArtifactNodes` 用返回的 id 表，其余行为一字不改。
- `lib/features/canvas/models/canvas_command.dart`（由 undo-stack 新建，W0）：追加一个子类 `InsertTemplateCommand` + 标签枚举加一项（只追加，不动已有子类）。
- `test/features/templates/util/template_capture_test.dart`（新建）
- `test/features/templates/util/template_remap_test.dart`（新建）
- `test/features/templates/providers/template_insert_controller_test.dart`（新建）
- `test/features/templates/builtin_templates_test.dart`（新建）

## 不许碰的文件
- 同波其他切片足迹：`lib/theme/typography.dart`、`lib/features/canvas/widgets/node_card.dart`、`providers/canvas_compact_cards.dart`、`util/node_position.dart`、`util/edge_geometry.dart`、`util/viewport_fit.dart`、`widgets/text_node_inspector.dart`、`util/outline_model.dart`（只许 import 读 `narrativeChainMembers`，不许改）（note-heading-style）；`notifications/widgets/toast_layer.dart`、`notifications/models/notification_prefs.dart`、`settings/providers/notification_prefs_controller.dart`、`settings/widgets/notifications_section.dart`、`core/models/app_preferences.dart`（toast-corner）；`left_rail/assets_model.dart`、`left_rail/assets_panel.dart`、`gallery/**`（assets-gallery-import-origin）；`theme/components/ink_split_button.dart`、`export/**`、`shell/widgets/shell_tab_bar.dart`、`shell/widgets/tabs/export_tab.dart`、`command_palette/command_actions.dart`（export-one-click）。
- 热点：`canvas_tool_actions.dart`、`canvas_nodes_controller.dart`、`canvas_lanes_controller.dart`、`canvas_edges_controller.dart`、`canvas_view.dart` 与 `stage_*`、`import_remapper.dart`、`generation_controller.dart`、`create_menu_model.dart`、所有左栏 widget。
- `lib/core/text/character_mention.dart`（只调用，不改）；`test/features/canvas/providers/canvas_bootstrap_controller_test.dart`（**不改**，它是本片重构的护栏）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W16 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - note-heading-style：`lib/features/canvas/models/canvas_node_note_style.dart`、`lib/features/canvas/providers/heading_note_zoom.dart`、`lib/features/canvas/util/drop_placement.dart`、`lib/features/canvas/util/note_geometry.dart`、`lib/features/canvas/util/selection_geometry.dart`、`lib/features/canvas/util/viewport_focus.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/node_inline_text_editor.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`lib/theme/typography.dart`、`test/features/canvas/util/drop_placement_test.dart`、`test/features/canvas/util/note_geometry_test.dart`、`test/features/canvas/util/viewport_focus_test.dart`、`test/features/canvas/widgets/node_card_note_style_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/theme/typography_test.dart`
  - toast-corner：`lib/core/models/app_preferences.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/notifications/util/toast_placement.dart`、`lib/features/notifications/widgets/toast_layer.dart`、`lib/features/settings/providers/notification_prefs_controller.dart`、`lib/features/settings/widgets/notifications_section.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/notifications/util/toast_placement_test.dart`、`test/features/notifications/widgets/toast_layer_test.dart`、`test/features/settings/notification_prefs_controller_test.dart`、`test/features/settings/notifications_section_test.dart`
  - assets-gallery-import-origin：`assetsOfKind`、`assets_panel`、`lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`、`lib/features/canvas/widgets/left_rail/assets_model.dart`、`lib/features/canvas/widgets/left_rail/assets_panel.dart`、`lib/features/gallery/providers/gallery_filter.dart`、`lib/features/gallery/util/gallery_meta.dart`、`lib/features/gallery/widgets/gallery_filter_panel.dart`、`lib/features/gallery/widgets/gallery_tile.dart`、`lib/features/gallery/widgets/imported_badge.dart`、`test/features/canvas/widgets/left_rail/asset_captions_test.dart`、`test/features/canvas/widgets/left_rail/assets_model_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/gallery/providers/gallery_filter_test.dart`、`test/features/gallery/util/gallery_meta_test.dart`、`test/features/gallery/widgets/gallery_tile_test.dart`
  - export-one-click：`lib/features/export/open_export_dialog.dart`、`lib/features/export/providers/one_click_export_controller.dart`、`lib/features/export/util/export_file_name.dart`、`lib/features/export/util/last_export_settings.dart`、`lib/features/export/util/one_click_export_plan.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/shell/widgets/shell_tab_bar.dart`、`lib/features/shell/widgets/tabs/export_tab.dart`、`lib/theme/components/ink_split_button.dart`、`test/features/export/providers/one_click_export_controller_test.dart`、`test/features/export/util/export_file_name_test.dart`、`test/features/export/util/last_export_settings_test.dart`、`test/features/export/util/one_click_export_plan_test.dart`、`test/features/export/widgets/export_video_dialog_test.dart`、`test/features/shell/shell_tab_bar_test.dart`、`test/theme/components/ink_split_button_test.dart`

## 具体改动
```dart
// models/canvas_template.dart
const int kTemplatePayloadFormat = 1;
@immutable class TemplateLane { final String key; final String label; final String stylePrompt; final String? tintColor; final double size; }
@immutable class TemplateNode { final String key; final CanvasNodeType type; final String label; final String? laneKey;
  final double main; final double cross; final Map<String, Object?> typeConfig; }
@immutable class TemplateEdge { final String sourceKey; final String targetKey; final EdgeType edgeType; final EdgeRole role; final int sortOrder; }
@immutable class CanvasTemplatePayload { final List<TemplateLane> lanes; final List<TemplateNode> nodes; final List<TemplateEdge> edges;
  final String baseStylePrefix; final String baseStyleSuffix;
  Map<String, Object?> toJson(); static CanvasTemplatePayload? fromJson(Object? json); }   // JSON 顶层键 format / lanes / nodes / edges / base_style_prefix / base_style_suffix；format != 1 或结构不对 ⇒ null
@immutable class TemplateCounts { final int nodes; final int shots; final int lanes; final int edges; }
@immutable class CanvasTemplate { final String id; final String name; final CanvasTemplatePayload payload; final TemplateCounts counts; final bool builtin;
  final String? tagline; }   // 卡片副标题第二段的覆盖文案（只有内置「单镜试拍」用：「图像 → 视频」）；null ⇒ 用泳道数

// util/template_capture.dart
const Set<String> kTemplateStrippedKeys = {'image_url','video_url','thumbnail_url','character_ids','pinned_result_id','gen_inputs','origin','original_name'};
const Set<String> kTemplateTextKeys = {'prompt','negative_prompt','shot_notes','text'};
CanvasTemplatePayload captureTemplate({required List<CanvasNode> nodes, required List<CanvasEdge> edges,
  required List<StyleLane> lanes, required List<({String id, double size})> laneSlices, required LaneDirection direction,
  Set<String>? selection, required String? Function(String characterId) characterNameOf,
  String baseStylePrefix = '', String baseStyleSuffix = ''});
TemplateCounts countTemplate(CanvasTemplatePayload payload);
Map<String, Object?> sanitizeTemplateTypeConfig(Map<String, Object?> tc, String? Function(String) characterNameOf);

// util/template_remap.dart
@immutable class PlacedLane { final String key; final TemplateLane lane; final int sortOrder; }
@immutable class PlacedNode { final TemplateNode node; final Offset world; final String? templateLaneKey; final String? existingLaneId; }
@immutable class PlacedTemplate { final List<PlacedLane> lanes; final List<PlacedNode> nodes; final List<TemplateEdge> edges; final Rect worldBounds; }
PlacedTemplate placeTemplate({required CanvasTemplatePayload payload,
  required List<({String id, double size})> existingLaneSlices, required int nextLaneSortOrder,
  required LaneDirection direction, required double scale, required Offset anchorWorld, required bool centerOnAnchor});

// util/template_writer.dart
@immutable class TemplateWriteResult { final Map<String, String> laneIdByKey; final Map<String, String> nodeIdByKey; final List<String> edgeIds; }
Future<TemplateWriteResult> writePlacedTemplate(RepositoryScope scope, {required String canvasId, required PlacedTemplate placed});

// builtin_templates.dart
typedef BuiltinTemplateStrings = ({String threeActName, List<String> threeActLanes, List<String> threeActNotes,
  String Function(String index) shotLabel, String singleShotName, String singleShotTagline, String imageConfigLabel, String videoConfigLabel, String sampleName});
List<CanvasTemplate> builtinTemplates(BuiltinTemplateStrings s, SampleSeed sample);   // 顺序固定：三幕短片、单镜试拍、短剧示例
// canvas_bootstrap_controller.dart 新增（同文件顶层）：
CanvasTemplatePayload sampleTemplatePayload(SampleSeed seed);

// providers/template_insert_controller.dart
final templateInsertControllerProvider = Provider.family<TemplateInsertController, String>(...); // 不 autoDispose，理由照 scriptImportControllerProvider 头注
class TemplateInsertController { Future<TemplateInsertResult> insertIntoCanvas(CanvasTemplate template); }
@immutable class TemplateInsertResult { final List<String> nodeIds; final List<String> edgeIds; final List<String> laneIds;
  final String? historyStepId; }   // 推栈返回的步 id，W17 胶囊上的「撤销」= undoSpecific(这一步)；空模板为 null
final templateCanvasCreatorProvider = Provider<TemplateCanvasCreator>(...);
class TemplateCanvasCreator { Future<String> createCanvasFromTemplate({required String projectId, required CanvasTemplate template}); } // 返回新画布 id
```
- 坐标约定：`main` = 沿泳道方向（横向画布是 x），`cross` = 横截方向。泳道里的卡 `cross` 相对本道起始边（抓取时用 `laneStartOf(laneId, laneSlices)`，切片是有效厚度，与 `menuNodePlacement` 同一套）；不在道里的卡 `cross` 相对这些卡的最小横截值；`main` 相对全体卡的最小主轴值。
- `placeTemplate`：新道追加在已有道之后，`sortOrder = nextLaneSortOrder + i`，起始边 = 已有切片厚度之和 + 前面新道的 size；道内卡 `cross世界 = 起始边 + cross`。主轴：`centerOnAnchor` 为真时整体主轴跨度的中点对准 `anchorWorld` 的主轴分量，否则主轴起点 = `anchorWorld` 主轴分量。不在道里的卡横截同理对 `anchorWorld` 横截分量（居中或起点）；之后按 `resolveLaneDrop`（drop_placement.dart:24）判它落进了哪条**已有**道，落进了就写 `existingLaneId` 并按该道锚定换算横截坐标（与新建节点同一判定）。所有世界坐标过 `clampIntoWorldReach`。
- `insertIntoCanvas`：await 之前同步读完：节点 / 泳道控制器现值、`canvasLaneDirectionProvider`、`laneCollapseProvider`、`canvasTransformControllerProvider(canvasId).value`、`canvasViewportSizeProvider`；锚点 = 视口中心的世界坐标（`viewportToWorld`，drop_placement.dart:156），视口未上报（`Size.isEmpty`）时锚点 = `kSampleNodePosition`；`centerOnAnchor: true`。再按 `sanitizeTemplateTypeConfig(…, (_) => null)` 过一遍每张卡（防御：内置与库里的 payload 都不该带这些键）。`uow.run` 里调 `writePlacedTemplate`；提交后 invalidate 节点 / 边 / 泳道三个控制器，`canvasSelectionControllerProvider(canvasId).notifier.selectAll(nodeIds)`，往 `canvasHistoryController` 推一条 `InsertTemplateCommand(name, nodeIds, edgeIds, laneIds)`；插入矩形（按 `nodeStageRect` 的并集）不全在视口内时，用 `transformCenteringRect`（viewport_focus.dart:39）只平移、不改缩放。
- `InsertTemplateCommand`：撤销 = 一个事务软删这批边、节点、泳道；重做 = 一个事务按泳道 → 节点 → 边 restore；对象已被硬删时按 undo-stack 的约定丢掉这一步。
- `createCanvasFromTemplate`：一个事务里 `scope.canvas.create(projectId, name: template.name, baseStylePrefix/Suffix: payload 里的)` + `placeTemplate(existingLaneSlices: [], nextLaneSortOrder: 0, direction: horizontal, scale: 1, anchorWorld: kSampleNodePosition, centerOnAnchor: false)` + `writePlacedTemplate`；提交后 `container.invalidate(workspaceProjectsProvider)`（写法照 bootstrap 的 ME-27 注释）。不进撤销栈（「项目与画布增删」不进栈）。导航由调用方做。
- 内置模板：
  - 三幕短片：3 条道（标签 = 三幕名，tint 依次取 `kLaneTintChoices[0..2]`，stylePrompt 为空串，size 用 `kDefaultLaneSize`）；每道 1 个 text 节点（text = 该幕说明）+ 3 个 shot 配置节点（label = `shotLabel('01'..'09')`）；叙事边 9 镜顺序相连 8 条（sortOrder 0）；每幕 text → 本幕第一镜 data 边（role reference）3 条 ⇒ 12 节点 · 9 镜 · 3 泳道 · 11 条线。
  - 单镜试拍 · 图生视频：无道；image 配置（label = 图像配置）→ video 配置（label = 视频配置），data 边 role firstFrame ⇒ 2 节点 · 1 镜 · 0 泳道 · 1 条线；`tagline = singleShotTagline`。
  - 短剧示例：`sampleTemplatePayload(sample)`（与「创建示例项目」同一个函数，不含成片）。
- 计数 `shots`：payload 内叙事边两端都在的节点数（同 `narrativeChainMembers` 口径）；没有叙事边时 = 非 text 配置节点里没有出向 data 边的个数。

## 行为规则与边界情况
1. 抓取只收 `role == config` 的节点；产物节点、它们的边（含 generationSource）全部不收。
2. 边只收两端都在被抓集合里的 narrative / data 边；sortOrder 原样保留。
3. 选中抓取：只带选中的配置节点，泳道只带「至少有一张被抓的卡」的道，道的相对顺序不变；整画布抓取带全部道（含空道）。
4. type_config 剥 `kTemplateStrippedKeys` 全部键；`kTemplateTextKeys` 四个键里的 `@{id}` 用 `stripToNames` 换成「@名字」，`characterNameOf` 返回 null ⇒ 删掉记号。
5. 插入时再剥一遍（内置与入库 payload 都走），所以模板里不可能带进 `gen_inputs` / `pinned_result_id`（以 TakesCost 板「出现就剥掉」为准，见风险 1）。
6. 新 id 全部来自仓储 `create` 的返回值；边两端按 key → 新 id 表改写；key 找不到的边丢弃（不抛）。
7. 空模板（0 节点）：`insertIntoCanvas` 直接返回空结果，不开事务、不进栈。
8. 写库任一步抛 `InkError` ⇒ 整个事务回滚、原样 rethrow，三个控制器不 invalidate、选中不变、不进栈。
9. 视口已上报：插入后全部卡的包围盒主轴中点 = 视口中心主轴坐标（误差 < 1px）；不在道里的卡横截中点 = 视口中心横截坐标。
10. 目标画布已有 2 条道：模板的道排在第 3、4 位，sortOrder = 已有最大值 + 1 起；目标画布道是折叠的，起始边按折叠后厚度算（与新建节点同一套切片）。
11. 竖向画布插入横向画布抓的模板：主轴 / 横截轴互换后落位，道仍是 2 条、相对顺序不变。
12. 撤销一步：插入的节点、边、泳道全部软删；重做全部回来；撤销后选中按 undo-stack 的通用规则处理。
13. 新画布：画布名 = 模板名；底稿风格取 payload；第一张卡的世界坐标 = `kSampleNodePosition` 起排；不进撤销栈。
14. 「创建示例项目」重构前后：项目 / 画布 / 泳道（label、stylePrompt、size 600、sortOrder 0）/ 两镜位置与 typeConfig / 叙事边 sortOrder / 成片节点完全一致——现有 `canvas_bootstrap_controller_test.dart` 不改动全绿。
15. 并发：同一画布连点两次插入，第二次读的是第一次 invalidate 之后的控制器值或旧值都可以，但两次的泳道 sortOrder 不得相同——`nextLaneSortOrder` 在 `uow.run` 内用 `scope.styleLanes.listByCanvas` 重新取最大值（不信控制器缓存）。
16. mac / Windows 无差异。

## 新文案键
| key | en | zh |
|---|---|---|
| templateBuiltinThreeActName | Three-act short | 三幕短片 |
| templateBuiltinThreeActLane1 | Act I · Setup | 第一幕 · 建置 |
| templateBuiltinThreeActLane2 | Act II · Confrontation | 第二幕 · 对抗 |
| templateBuiltinThreeActLane3 | Act III · Resolution | 第三幕 · 结局 |
| templateBuiltinThreeActNote1 | Introduce the protagonist and their world. | 交代主角和他所在的世界。 |
| templateBuiltinThreeActNote2 | The conflict escalates; the protagonist is pushed to the edge. | 冲突升级，主角被逼到绝境。 |
| templateBuiltinThreeActNote3 | The climax resolves the conflict; show what has changed. | 高潮化解冲突，交代改变了什么。 |
| templateBuiltinShotLabel | Shot {index} | 镜头 {index} |
| templateBuiltinSingleShotName | Single-shot test · image to video | 单镜试拍 · 图生视频 |
| templateBuiltinSingleShotTagline | image → video | 图像 → 视频 |
| templateBuiltinSampleName | Short drama sample | 短剧示例 |
| canvasCommandInsertTemplate | Insert template “{name}” | 插入模板「{name}」 |
图像配置 / 视频配置复用现有 `canvasCreateMenuImageConfig` / `canvasCreateMenuVideoConfig`。`templateBuiltinShotLabel` 的 `{index}` 是 String（调用方补零）。

## 测试
先写会失败的用例。
- `test/features/templates/util/template_capture_test.dart`
  - `抓取不收产物节点和挂在产物上的边`：画布 2 config + 1 result + data 边 result→config ⇒ payload 2 节点 0 边。
  - `type_config 剥掉媒体 / 角色 / 固定 / 快照键`：输入含 kTemplateStrippedKeys 全部键 + prompt/provider_id ⇒ 只剩 prompt/provider_id。
  - `提示词记号换成名字，取不到名字的删掉`：`'@{c1} 与 @{c9}'`，c1→渔夫 ⇒ `'@渔夫 与 '`（以 stripToNames 实际输出为准，断言不含 `@{`）。
  - `选中抓取只带有卡的泳道`：3 条道、选中只在第 2 条 ⇒ 1 条道。
  - `道内卡的 cross 相对本道起始边`：第二条道起始 360、卡 y=400 ⇒ cross 40。
  - `JSON 往返不丢字段`；`未知 format 返回 null`。
  - `计数：三幕短片 12/9/3/11、单镜试拍 2/1/0/1`。
- `test/features/templates/util/template_remap_test.dart`
  - `新道追加在已有道之后`：已有切片 [(a,300),(b,36)]、模板 2 道 ⇒ 起始边 336 / 336+size，sortOrder = next、next+1。
  - `主轴居中于锚点`：包围盒主轴中点 == anchor.dx。
  - `centerOnAnchor 为假时第一张卡主轴 = 锚点`。
  - `不在道里的卡落进已有道时写 existingLaneId`。
  - `竖向画布主横互换`。
- `test/features/templates/providers/template_insert_controller_test.dart`（FakeUnitOfWork + InMemory* 仓储，`test/_harness/fake_unit_of_work.dart` / `fake_repositories.dart`）
  - `一个事务写入，边两端是新 id`；`插完选中全部新节点`；`推一条 InsertTemplateCommand，撤销后全部软删、重做全部恢复`；`写边失败整体回滚、不进栈、选中不变`；`空模板不开事务`；`连插两次泳道 sortOrder 不重复`；`createCanvasFromTemplate 建画布 + 骨架，画布名 = 模板名`。
- `test/features/templates/builtin_templates_test.dart`
  - `三套内置顺序与计数`；`短剧示例 payload 与 sampleTemplatePayload 相同`。
- 护栏（不改）：`test/features/canvas/providers/canvas_bootstrap_controller_test.dart` 全绿。

## 变异点
1. `template_capture.dart` 里「只收 config」判据去掉 ⇒ `抓取不收产物节点和挂在产物上的边` 红。
2. `kTemplateStrippedKeys` 删掉 `character_ids` ⇒ `type_config 剥掉媒体 / 角色 / 固定 / 快照键` 红。
3. `placeTemplate` 新道起始边少加已有切片厚度 ⇒ `新道追加在已有道之后` 红。
4. 居中公式改成「起点 = 锚点」⇒ `主轴居中于锚点` 红。
5. writer 里边的 source 用模板 key 而不是新 id ⇒ `一个事务写入，边两端是新 id` 红。
6. 删掉推栈那一行 ⇒ `推一条 InsertTemplateCommand…` 红。
7. `nextLaneSortOrder` 改回读控制器缓存 ⇒ `连插两次泳道 sortOrder 不重复` 红。
8. bootstrap 里示例泳道 size 改成 `kDefaultLaneSize` ⇒ 现有 `canvas_bootstrap_controller_test` 的落点用例红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/templates test/features/canvas/providers/canvas_bootstrap_controller_test.dart test/features/canvas/util`；逐条做上面的变异。
- 无 UI，不截图。主 Agent 另核：`docs/CLAUDE.md` 的 Project Structure 增加 `lib/features/templates/`（models / util / providers / builtin_templates.dart）一段。

## 风险与不确定
1. 画板 RailScript 写「gen_inputs 源 id 换新、模板外的剥掉」，TakesCost 写「模板不带产物，出现就剥掉」。`gen_inputs` 只写在产物节点上（tc-gen-inputs-snapshot），模板根本不收产物，本单按 TakesCost 一律剥掉，不调用 `stripUnmappedGenInputs`。
2. 画板「短剧示例 4 镜」与代码现状（`kSampleShotCount = 2`）不一致；以代码为准，内置卡会显示「2 镜 · 1 泳道」。要 4 镜得改示例本身（另开片）。
3. `CanvasCommand` 若是 sealed，子类必须写在 `canvas_command.dart` 里；若 undo-stack 用的是注册表 / 非 sealed 接口，就把 `InsertTemplateCommand` 放进新文件 `lib/features/templates/providers/insert_template_command.dart`，`canvas_command.dart` 只加标签枚举一项。执行时以 main 上实际形状为准。
4. 三幕短片的 text → shot data 边：生成侧只对 image / video 配置合并关联文本；shot 节点「用本镜备注生成」不读它。线条只起说明作用，不影响生成。若 link 规则不允许 text → shot，改成 text 不连线并把计数改成 12 节点 · 8 条线，同步更新测试。
5. 模型按计划写成手写不可变类（不是 freezed），与 docs/CLAUDE.md「ALL models use freezed」有出入，沿用 gallery_graph / shell_state 的先例。
