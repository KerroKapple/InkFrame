# rail-drag-assets · 左栏素材格拖进画布：落空白建导入式产物节点，落配置节点弹「当参考 / 替换首帧 / 当尾帧」
- 波次 W5 / lane D / 基底 origin/main〔W0–W4 已合入〕；依赖切片：stage-drop-target（W4）、media-import-service（W2）、narrative-splice（W1，replaceRoleEdge）、undo-stack（W0）、undo-adopt-existing（W3，showCanvasUndoSnack 登记栈步）、menu-split（W0）；阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 左栏「素材」页的格子可以按住拖进画布：松在空白处 = 在松手点建一个导入式产物节点（同画布指向同一个文件，别的画布的素材先复制进本画布 `imports/`）。
- 松在图像 / 视频配置节点上 = 在松手点弹一个小菜单「放到「镜头 02」」：当参考 / 当首帧（已有首帧时写「替换首帧」）/ 当尾帧，provider 不支持的置灰并写原因；选了就连上线。
- 每次放入都是一步撤销（Ctrl Z）；替换首帧 / 尾帧另弹一张带「撤销」的卡。

## 设计依据
- ImportSearch.dc.html ·「从左栏拖进画布」（colB）mock + 规则：
  - 「素材拖到空白处：建导入式产物节点；同画布 = 同画布粘贴（新节点指向同一文件，不复制），跨画布先复制进本画布 imports/」——按 IS-Q2 建议 A（复制进本画布 `canvases/<id>/imports/`）。
  - 「拖到配置节点：松手弹菜单，只列合法项：参考恒有，首 / 尾帧看 provider 能力位，不支持的置灰写原因」；菜单 mock：标题行「放到「镜头 02」」（9px fg5），三行各带一个 8px 色点（参考 sky / 首帧 teal / 尾帧 peach = 现有 edgeReference / edgeFirstFrame / edgeLastFrame 色），置灰行副标题「万相 2.2 不支持尾帧」、整行 45% 透明。
  - 「已有首帧时写「替换首帧」，一次撤销复原；视频素材没有合法项，按落空白处理」。
  - 拖动中的跟手缩略：60×34、圆角 3、accent 1px 描边、阴影；左栏原格子在拖动中降到 35% 不透明 + 虚线描边（mock 里的「远山参考」）。
- 目标卡琥珀虚线高亮由 stage-drop-target 提供（本片只答 `acceptsCard`）。
- IS-Q6 建议 A：导入节点是产物，不入叙事链——本片只连 data 边（参考 / 首帧 / 尾帧），从不建 narrative 边。
- 设计缺口：①尾帧已有时写不写「替换尾帧」（板只画了首帧）——本片对称处理，写「替换尾帧」；②同一张素材已经以同角色连在这个配置上时怎么办——本片置灰并写「已连着」；③配置节点解析不出 provider（候选为空）时首 / 尾帧写什么原因——本片写「没有可用的模型」；④落配置时新建的素材节点放哪——板没画，本片放在配置节点左侧一列（见规则 7）；⑤除替换外是否要提示——板没写，本片不弹卡（线和节点当场出现，Ctrl Z 可撤）。

## 允许改的文件
- `lib/features/canvas/widgets/left_rail/assets_panel.dart`：`_AssetTile`（main 第 475–555 行）外面包 `CanvasPayloadDraggable`（由 stage-drop-target 新建）；payload = `AssetDragPayload.fromGalleryItem(item, projectId: project.id)`；feedback = `_AssetDragFeedback`（新私有组件：60×34 缩略、`InkRadius.s3`、accent 1px、`InkShadow.overlay`）；拖动中原格子 35% 不透明（`Draggable.childWhenDragging`）。点格子定位（`_locate`）不变。改掉头注第 5 行「稿上「拖进画布即建节点…」那行不画：这一轮不做拖放」——现在画那行说明（`LeftPanelNote`，文案见新键）。
- `lib/features/canvas/widgets/left_rail/assets_model.dart`：只加 `String assetOriginalName(GalleryItem item)`（取相对路径 basename，导入节点的 original_name 用）。
- `lib/features/canvas/util/asset_drop_model.dart`（新，纯函数）。
- `lib/features/canvas/util/canvas_asset_drop_actions.dart`（新）：`AssetStageDropHandler` + `dropAssetOnBlank` + `attachAssetToConfig`。**不碰 canvas_tool_actions.dart、canvas_edges_controller.dart**。
- `lib/features/canvas/widgets/stage_drop/stage_drop_registry.dart`（由 stage-drop-target 新建）：在 `kStageDropHandlers` 里**追加一行** `AssetStageDropHandler(),`。不改 canvas_view.dart。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`（由 menu-split 新建；W5 归本片）：`CanvasMenuKind` 加 `assetDrop`；`CanvasMenuRequest` 加字段 `final AssetDropMenuTarget? assetDrop;`；`CanvasMenuController` 加 `openAssetDrop(Offset anchor, {required AssetDragPayload asset, required String configNodeId})`；宿主按 kind 分派到 `buildAssetDropMenu` 并在 pick 时调 `attachAssetToConfig`。
- `lib/features/canvas/widgets/canvas_menu/asset_drop_menu_entries.dart`（新）：菜单条目构造；`CanvasMenuKeys` 风格的测试锚点 `AssetDropMenuKeys.panel` / `.item(AssetDropRole)`。
- `lib/features/canvas/models/commands/asset_drop_command.dart`（新，`part of '../canvas_command.dart';`）+ `lib/features/canvas/models/canvas_command.dart` **追加一行 part + 枚举值 `assetDrop`**（`CanvasCommandLabel`）。
- 测试：`test/features/canvas/util/asset_drop_model_test.dart`（新）、`test/features/canvas/util/canvas_asset_drop_actions_test.dart`（新）、`test/features/canvas/widgets/left_rail/assets_drag_to_canvas_test.dart`（新）。

## 不许碰的文件
- `node_card.dart`、`node_card_slot.dart`、`providers/node_drag_delta.dart`、`util/drop_placement.dart`、`widgets/edge_painter.dart`、`stage_edge_layer.dart`（W5 group-drag）。
- `providers/canvas_edges_controller.dart`、`providers/link_action_controller.dart`、`canvas_tool_actions.dart`、`widgets/node_inputs_section.dart`（W5 undo-edges）。
- `providers/inspector_submit_controller.dart`、`characters_section.dart`、`image_config_inspector.dart`、`video_config_inspector.dart`、`shot_config_inspector.dart`、`text_node_inspector.dart`（W5 undo-params）。
- `util/current_take_edges.dart`、`providers/current_take_controller.dart`、`generation/generation_controller.dart`、`widgets/canvas_job_listener.dart`（W5 tc-take-edge-follow）。
- `canvas_view.dart`（分派点已由 W4 挂好，本片只改注册表）、`create_node_menu.dart`（menu-split 后只剩 barrel）、`models/canvas_drag_payload.dart`（W4 已定义 AssetDragPayload）。

## 具体改动
```dart
// util/asset_drop_model.dart
enum AssetDropRole { reference, firstFrame, lastFrame }
enum AssetDropBlock { providerUnsupported, noProvider, alreadyLinked }
@immutable class AssetDropItem {
  const AssetDropItem({required this.role, this.replaces = false, this.block});
  final AssetDropRole role; final bool replaces; final AssetDropBlock? block;
  bool get enabled => block == null;
}
/// 舞台命中判据：只有图片素材、落在图像 / 视频「配置」节点上才算目标卡；其余（视频素材、产物、文本、镜头）当空白。
bool assetDropAcceptsCard(AssetDragPayload asset, CanvasNode card);
/// 菜单项（固定三行、顺序 参考 → 首帧 → 尾帧）。caps = 该配置此刻的 provider 能力（解析链同 generate_gate.resolveConfigProviderId）。
/// reuseSourceId 非空 = 素材节点就在本画布、将直接从它连线：同源同角色已有 live data 边 → alreadyLinked。
List<AssetDropItem> assetDropItems({required CanvasNode config, required ProviderCapabilities? caps,
  required List<CanvasEdge> edges, String? reuseSourceId});
/// 素材从哪来：reuseNode = 直接用画布上那个产物节点连线；sameFile = 新建导入节点、指向同一个文件；copy = 先复制进本画布 imports/。
enum AssetSourceMode { reuseNode, sameFile, copy }
AssetSourceMode assetSourceMode(AssetDragPayload asset, {required String targetCanvasId, required bool forEdge});
/// 落配置时新建的素材节点：配置左侧一列（x − kNodeCardSize.width − InkSpacing.xl，y 同配置），与配置同道。
({Offset world, String? laneId}) assetSourcePlacement(CanvasNode config);
/// 导入式产物节点的 type_config：image_url | video_url（+ thumbnail_url / duration_ms）、origin: 'import'、original_name。
/// origin 键名与 media-import-service 的 isImported extension 用同一个常量。
Map<String, Object?> assetImportTypeConfig(AssetDragPayload asset, {required String relativePath,
  String? thumbnailRelativePath, required String originalName});
EdgeRole edgeRoleOf(AssetDropRole role);

// util/canvas_asset_drop_actions.dart
class AssetStageDropHandler extends StageDropHandler<AssetDragPayload> {
  const AssetStageDropHandler();
  @override bool acceptsCard(AssetDragPayload p, CanvasNode card) => assetDropAcceptsCard(p, card);
  @override Future<void> onDrop(StageDropContext ctx, AssetDragPayload p, {required StageDrop drop, CanvasNode? card});
  // card == null → dropAssetOnBlank；否则 canvasMenuRequestProvider.openAssetDrop(drop.viewportPoint, ...)
}
Future<void> dropAssetOnBlank(BuildContext context, WidgetRef ref, {required String canvasId,
  required AssetDragPayload asset, required NodePlacement placement});
Future<void> attachAssetToConfig(BuildContext context, WidgetRef ref, {required String canvasId,
  required AssetDragPayload asset, required String configNodeId, required AssetDropRole role});

// models/commands/asset_drop_command.dart（part of '../canvas_command.dart'）
/// 一次放入素材：可能新建的素材节点 + 新连的边（按两端 + 角色找）+ 被替换掉的旧边（按两端 + 角色找）。
final class AssetDropCommand extends CanvasCommand { ... createdNodeId?, edgeEnds?, replacedEdgeEnds? }
```
- 跨画布复制：经 media-import-service 的 `MediaImportService`（`core/di/media_import.dart` 的 provider）把源文件（`fileResolverServiceProvider.resolve(projectId, asset.canvasId, relativePath)`）复制进目标画布 `imports/`，拿回相对路径；视频的 `thumbnailRelativePath` 一并复制。**先复制、后写库**；写库失败调该服务的删除 / 回滚把复制件删掉。具体方法名以 W2 的接口为准（不要另写 copier）。
- 同画布节点写入走 `CanvasNodesController.addNode(role: NodeRole.result, type: image|video, sourceNodeId: null, laneId:, position:, typeConfig: assetImportTypeConfig(...))`（W2 已为 origin import 放宽 result 必须有 sourceNodeId 的断言）。
- 连线：参考 → `CanvasEdgesController.addEdge(role: reference)`；首帧 / 尾帧 → `CanvasEdgesController.replaceRoleEdge`（由 narrative-splice 新建：同一 UoW 软删目标上同角色的旧 data 边 + 建新边；没有旧边时只建新边；返回被软删的旧边，签名以该片为准）。
- 落配置时若要新建素材节点（sameFile / copy）：`addNode` 成功 → 连线；连线失败 → `removeNode(新节点)` + 删复制件 → 错误卡。全程零残留。
- 菜单打开期间**不复制、不写库**；选了一项才开始。Esc / 点外面关菜单 = 什么都不发生。
- 撤销：`CanvasHistoryController(canvasId).push(AssetDropCommand(...))`。revert：删新边（按两端 + 角色找边）→ 恢复旧边（按两端 + 角色找已软删的那条，用 `restore`）→ 软删新建的素材节点；apply（重做）：restore 素材节点 → 再走一遍连线 / 替换。替换首帧 / 尾帧另调 `showCanvasUndoSnack`（undo-adopt 已让卡上「撤销」= undoSpecific 这一步）。
- 放入后选中：落空白 → 单选新节点（不挪相机）；落配置 → 单选该配置（检查器里能看到新入边）。

## 行为规则与边界情况
1. 图片素材落空白（同画布、非批量 slot）：新建 result 节点，type_config.image_url 与原产物同一个相对路径，origin = import，original_name = 文件 basename；不复制文件。
2. 同画布的批量 slot（asset.slotIndex ≠ null）落空白：同规则 1，image_url = slot 的 outputUrl。
3. 别的画布的素材落空白：先复制进本画布 `imports/`（视频连同缩略图），再建节点指向复制件；复制失败 → 不建节点、弹错误卡「素材复制失败」。
4. 落点 = 松手点的 `drop.placement`（泳道归属已判好，进道就写 laneId）。
5. 视频素材压在任何卡上都不高亮，松手按落空白处理（规则 1 / 3）。
6. 图片素材压在产物 / 文本 / 镜头卡上不高亮，按落空白处理。
7. 图片素材落在图像 / 视频配置上：弹菜单（锚点 = 松手点）。素材在本画布且非 slot → 直接从原产物节点连线（不建新节点）；否则在 `assetSourcePlacement(config)` 新建素材节点再连。
8. 菜单三行：「当参考」恒可点；首帧行：provider `supportsFirstFrame` 才可点，配置已有 live 首帧入边时文案「替换首帧」否则「当首帧」；尾帧行同理（「替换尾帧」/「当尾帧」）。不可点的写原因：`{provider} 不支持首帧` / `{provider} 不支持尾帧`（provider = caps.displayName ?? providerId）；解析不出 provider → 首 / 尾帧都写「没有可用的模型」；同源同角色已连着 → 「已连着」。
9. 选「当参考」：新增一条 reference data 边；不动别的边。
10. 选「替换首帧」：旧首帧边被软删、新首帧边建立，一个事务；弹卡「已替换「{name}」的首帧」带撤销。选「当首帧」（原本没有）：只建边，不弹卡。
11. 撤销（Ctrl Z 或卡上撤销）一次复原：新边没了、旧首帧边回来、新建的素材节点（若有）被软删；重做一次回到放入后。复制件不删（软删节点仍引用它，回收器只读）。
12. 撤销时对象已不在（比如配置节点被删了）：按 undo-stack 规则丢这一步并提示，不连带别的。
13. 写库失败：节点 / 边都回滚（各控制器已有乐观回滚），复制件删掉，弹「放入素材失败」错误卡；不进撤销栈。
14. 拖动中左栏原格子 35% 不透明；拖回左栏松手 = 什么都不发生。点格子（不拖）仍是定位。
15. 当前画布还没载入节点（控制器 loading）：舞台不在，DragTarget 不存在，拖不进来——不需要额外处理。
16. mac / Windows 无差异（应用内拖放）。

## 新文案键
| key | en | zh |
|---|---|---|
| leftRailAssetsDragHint | Drag into the canvas to add a node, or onto a config node to use as input | 拖进画布即建节点，拖到配置节点上当输入 |
| canvasAssetDropMenuTitle | Drop on “{name}” | 放到「{name}」 |
| canvasAssetDropAsReference | Use as reference | 当参考 |
| canvasAssetDropAsFirstFrame | Use as first frame | 当首帧 |
| canvasAssetDropReplaceFirstFrame | Replace first frame | 替换首帧 |
| canvasAssetDropAsLastFrame | Use as last frame | 当尾帧 |
| canvasAssetDropReplaceLastFrame | Replace last frame | 替换尾帧 |
| canvasAssetDropNoFirstFrame | {provider} doesn't support first frames | {provider} 不支持首帧 |
| canvasAssetDropNoLastFrame | {provider} doesn't support last frames | {provider} 不支持尾帧 |
| canvasAssetDropNoProvider | No model available | 没有可用的模型 |
| canvasAssetDropAlreadyLinked | Already linked | 已连着 |
| canvasAssetDropReplacedFirstFrame | Replaced the first frame of “{name}” | 已替换「{name}」的首帧 |
| canvasAssetDropReplacedLastFrame | Replaced the last frame of “{name}” | 已替换「{name}」的尾帧 |
| canvasAssetDropCopyFailed | Couldn't copy the asset into this canvas | 素材复制失败 |
| canvasAssetDropFailed | Couldn't place the asset | 放入素材失败 |
| （撤销步名，前缀跟 undo-stack 已有步名键）…AssetDrop | Place asset | 放入素材 |

## 测试
- `test/features/canvas/util/asset_drop_model_test.dart`：
  - `视频素材不认任何卡`、`图片素材只认图像 / 视频配置`（产物 / 文本 / 镜头 → false）。
  - `参考恒可点`；`首帧看 supportsFirstFrame`（fakeVideoCapabilities(supportsFirstFrame: false) → block = providerUnsupported）；`尾帧同理`。
  - `已有首帧写替换`：edges 里有 live firstFrame 入边 → replaces = true；只有 reference 入边 → false。
  - `caps 为空时首尾帧都是 noProvider`；`同源同角色已连着 → alreadyLinked`（reuseSourceId 给定）。
  - `assetSourceMode`：同画布非 slot 连线 → reuseNode；同画布落空白 → sameFile；slot 连线 → sameFile；跨画布 → copy。
  - `assetSourcePlacement 在配置左侧一列、同道`。
- `test/features/canvas/util/canvas_asset_drop_actions_test.dart`（ProviderContainer + 记录型 FakeNodes / FakeEdges（replaceRoleEdge 记录调用）+ 记录型 MediaImportService fake + FakeToastService + 真 CanvasHistoryController）：
  - `同画布落空白不复制、指向同一文件`：addNode 的 typeConfig.image_url == asset.relativePath，origin == import；copy 调用 0 次。
  - `跨画布落空白先复制再建节点`：copy 1 次，addNode 的 image_url == 复制件路径；laneId == placement.laneId。
  - `复制失败零写库`：copy 抛错 → addNode 0 次，错误卡 1 张。
  - `替换首帧走 replaceRoleEdge 并弹撤销卡`。
  - `连线失败回滚新节点与复制件`：跨画布落配置、replaceRoleEdge 抛 InkError → removeNode(新节点) 被调、复制件删除被调。
  - `一步撤销复原`：替换首帧后 undo → 新边删除、旧边 restore、栈里只少一步；redo 再次替换。
  - `落配置后选中配置、落空白后选中新节点`。
- `test/features/canvas/widgets/left_rail/assets_drag_to_canvas_test.dart`（AssetsPanel + CanvasView 并排；画廊数据用 galleryControllerProvider override）：
  - `拖格子到空白建节点`；`拖到视频配置弹菜单`（三行，尾帧行置灰 + 原因文案）；`Esc 关菜单什么都不写`；`拖动中原格子降透明`；`点格子仍是定位`。

## 变异点
1. `assetDropItems` 里首帧不看 `supportsFirstFrame` → `首帧看 supportsFirstFrame` 红。
2. `replaces` 改成恒 true → `已有首帧写替换` 红。
3. `assetDropAcceptsCard` 去掉 kind == image 判断 → `视频素材不认任何卡` 红。
4. `assetSourceMode` 跨画布返回 sameFile → `跨画布落空白先复制再建节点` 红。
5. 去掉连线失败时的 `removeNode` 补偿 → `连线失败回滚新节点与复制件` 红。
6. `AssetDropCommand.revert` 不恢复旧边 → `一步撤销复原` 红。
7. `dropAssetOnBlank` 写死 `laneId: null` → `跨画布落空白先复制再建节点` 的 laneId 断言红。
8. 菜单宿主在开菜单时就复制文件（把复制挪到 onDrop）→ `Esc 关菜单什么都不写`（copy 调用 0）红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/util/asset_drop_model_test.dart test/features/canvas/util/canvas_asset_drop_actions_test.dart test/features/canvas/widgets/left_rail/ test/features/canvas/widgets/canvas_stage_drop_target_test.dart`。
- 变异 1–8 逐条。
- 截图（widget：CanvasScreen 带左栏素材页，项目两张画布；当前画布一张视频配置（provider = fakeVideoCapabilities(supportsFirstFrame: true, supportsLastFrame: false)，已有一条首帧入边）+ 一张图像产物）：①拖动中压在视频配置上（琥珀虚线 + 跟手缩略 + 原格子降透明）；②松手后的菜单（标题「放到「镜头 02」」、「替换首帧」、尾帧置灰带原因）；③选「替换首帧」后的画布 + 撤销卡；④拖到空白建出的导入节点。

## 风险与不确定
- `replaceRoleEdge`、`MediaImportService` 复制 / 删除方法、导入节点 origin 常量都由前序片定义，签名以它们为准；若 W2 的接口只有「外部 File → 建 uploading 节点」的整套流程而没有单独的复制 / 删除方法，本片需要在 `core/interfaces/media_import_service.dart` + `services/file_media_import_service.dart` 补两个方法（W5 无人占用这两个文件，但不在约定表里）——遇到时先回报主 Agent。
- 落配置且要新建素材节点时，「建节点」与「连线」不在同一个事务（两个控制器各自 UoW），靠补偿做到零残留；若 narrative-splice 的 `addEdgesInTx` 能接收外部 scope，可改成一个 UoW，但那要碰 canvas_edges_controller（W5 归 undo-edges），本片不做。
- 撤销步名的 label → 文案映射方式以 undo-stack 为准；本片只加一个 `CanvasCommandLabel.assetDrop`，替换 / 参考的区别放在命令参数里。
- 同一时刻 W5 undo-edges 也在给连线加撤销；本片的命令是独立类，不复用它的命令，避免跨片依赖。
