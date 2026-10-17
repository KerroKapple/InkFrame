# media-import-service · 媒体导入服务：复制进 canvases/<id>/imports/，建无来源的导入式产物节点
- 波次 W2 / lane E / 基底 origin/main（届时已含 W0–W1，尤其 nodes-batch-ops 给 CanvasNodesController 加的 `patchTypeConfigMany`）；依赖切片：nodes-batch-ops（方法）、multi-select-core（无直接依赖）；阻塞决定：无（IS-Q2 跨画布素材、IS-Q6 导入视频不入链都按建议 A，见下）。
- 本片只做服务、控制器、卡片显示与孤儿判据；**没有用户入口**（Ctrl U / 右键 / 更多 / ⌘K 归 W3 import-media-command，拖入 / 粘贴 / 素材拖放归后续切片）。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/media-import-service`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
- 给后续四个入口（Ctrl U、OS 拖入、粘贴图片、跨画布素材）一条共用的导入路：选中的图片 / 视频被复制进本画布 `imports/`，画布上立刻出现带「复制中 48%」的产物卡，复制完变成正常的图 / 视频卡，状态行写「导入 · 1920×1080」。
- 复制失败不留任何东西（没有半截文件、没有空卡）；导入的节点不会被当成孤儿结果或孤儿文件。

## 设计依据
- ImportSearch.dc.html ›「导入媒体」：
  - 「可多选；图片 png / jpg / webp，视频 mp4 / mov / webm」。
  - 「复制进 canvases/<id>/imports/（file_resolver 不许越出画布根）；导入、拖入、粘贴图片、跨画布素材都落这里」。
  - 「建产物节点（无来源配置），type_config 记相对路径 + origin: import + 原文件名」。
  - 「复制中节点为 uploading（库里已有这档）；视频随后抽首帧、探时长写 duration_ms」。
  - 样稿卡片：「雾江.jpg · 导入 · 1920×1080」「船桨.mp4 · 48% · 复制中」。
- ImportSearch 需要你定：按建议：IS-Q2 → A（跨画布素材复制进本画布 imports/）；IS-Q6 → A（导入视频不入叙事链，和产物一样，序列 / 导出不改）。
- UndoClipboard.dc.html ›「粘贴到哪 · 带什么」：「先复制文件再写库，失败删掉复制件、零残留」；「同画布共用一个文件安全：引用按路径计，回收器只读」。
- critic.txt 第二节第 8 条：媒体统一放 `canvases/<id>/imports/`，因为 resolve 不许越出画布根。
- plan.md §0：`core/di/` 一个服务一个文件；§3 W2：先写 `.partial` 再改名、零残留；reaper 不把 `imports/` 当孤儿。
- 设计缺口：①复制中途能否取消——画板没画，本片不做取消；②文件大小上限——画板没写，本片不设上限（磁盘满按复制失败处理）；③UploadingStatus 卡片在缩放 < 0.6 紧凑态的样子——没画，紧凑态只画类型图标（同现有）。

## 允许改的文件
- `lib/core/interfaces/media_import_service.dart`（新）：契约 + 扩展名白名单 + 纯函数 `mediaImportKindOf`。
- `lib/services/file_media_import_service.dart`（新）：`FileMediaImportService implements MediaImportService`。
- `lib/core/di/media_import.dart`（新）：`mediaImportServiceProvider`（app-scoped）+ 文件选择 seam `mediaFilesPickerProvider`（给 W3 用，测试可 override）。
- `lib/features/canvas/models/canvas_node_import.dart`（新）：`extension CanvasNodeImport on CanvasNode`。
- `lib/features/canvas/providers/media_import_controller.dart`（新）：建壳节点 → 复制 → 回写；进度 state。
- `lib/features/canvas/providers/canvas_nodes_controller.dart`：`addNode` 的断言放宽（第 82–85 行）；`addNode` 加可选 `String? projectId`（写进内存节点，否则新卡 resolve 不出图）；新增 `discardImportShell(String id)`。
- `lib/services/orphan_file_reaper.dart`：`kOrphanMediaSubdirs` 加 `'imports'`；头注释「#3 目录白名单」同步。
- `lib/storage/repositories/postgres_node_repository.dart`：`listOrphanResults` 的 WHERE 加 `AND COALESCE(n.type_config->>'origin','') <> 'import'`；`softDeleteEmptyOrphanResults` 不改（理由见规则 9）。
- `lib/features/canvas/widgets/node_card.dart`：`_StatusRow` 对导入节点改写状态文字 / 右侧 meta；`_ResultBody` 上叠复制中进度条（`InkProgressBar`）。
- 测试：`test/services/file_media_import_service_test.dart`（新）、`test/features/canvas/providers/media_import_controller_test.dart`（新）、`test/features/canvas/models/canvas_node_import_test.dart`（新）、`test/features/canvas/widgets/node_card_import_test.dart`（新）、`test/services/orphan_file_reaper_test.dart`（改白名单用例）、`test/storage/repositories/repository_sql_templates_test.dart`（加一条）、`test/features/canvas/canvas_nodes_controller_test.dart`（改断言用例）。

## 不许碰的文件
- lane-ops-core（同波 lane D）：`providers/canvas_lanes_controller.dart`、`util/lane_dissolve.dart`、`util/canvas_lane_actions.dart`、`stage/stage_lane_layer.dart`、`lane_title_bar.dart`、`lane_toolbar.dart`。
- undo-shortcuts-ui：`shortcuts/undo_keys.dart`、`canvas_menu/undo_menu_items.dart`、`util/canvas_history_actions.dart`。
- node-cost：`canvas_prompt_bar.dart`、`cost_estimator.dart`、`node_cost.dart`、图像 / 视频配置检查器、`cost_breakdown_tooltip.dart`。
- gen-inputs-snapshot：`generation_controller.dart`、`services/import/import_remapper.dart`、`gen_inputs_snapshot.dart`、`project_archive_service.dart`（项目包本来就整目录打包 `canvases/<c>/`，imports/ 自动带上，不用改）。
- 也不碰：`canvas_node.dart`（只加 extension）、`node_repository.dart` 接口、`canvas_tool_actions.dart`、`job_queue/*`、四张注册表。
- （主 Agent 自查补充）node-cost：`image_config_inspector.dart`、`video_config_inspector.dart`、`inspector_status_panel.dart`；gen-inputs-snapshot：`lib/core/models/gen_inputs.dart`（新）。

## 具体改动
```dart
// lib/core/interfaces/media_import_service.dart（无 Flutter import）
const List<String> kImportImageExtensions = <String>['png', 'jpg', 'jpeg', 'webp'];
const List<String> kImportVideoExtensions = <String>['mp4', 'mov', 'webm'];
const String kImportsSubdir = 'imports';
enum MediaImportKind { image, video }
MediaImportKind? mediaImportKindOf(String path);           // 扩展名小写比对；无扩展名 / 不在白名单 ⇒ null
String importOriginalName(String path, {p.Context? context}); // basename，测试用 p.windows / p.posix 注入
class ImportedMedia { const ImportedMedia({required this.relativePath, required this.kind, required this.bytes, this.width, this.height}); final String relativePath; final MediaImportKind kind; final int bytes; final int? width; final int? height; }
abstract class MediaImportService {
  /// 复制 [sourcePath] 到画布 imports/<uuid>.<小写扩展名>：先写 .partial、flush、rename；返回画布相对路径。
  /// 不在白名单 / 源不可读 / 0 字节 / 写盘失败 ⇒ 抛 LocalIOError(extra: {'reason': unsupported|unreadable|empty|copy_failed})，且磁盘上不留 .partial。
  Future<ImportedMedia> copyIntoCanvas({required String projectId, required String canvasId, required String sourcePath, void Function(double fraction)? onProgress});
  Future<void> discard({required String projectId, required String canvasId, required String relativePath}); // 尽力删，失败吞掉记日志
}

// lib/core/di/media_import.dart
final mediaImportServiceProvider = Provider<MediaImportService>(...);   // FileMediaImportService(resolver, logger, uuid, imageSizeProbe)
typedef MediaFilesPicker = Future<List<String>> Function();               // 取消 ⇒ 空列表
final mediaFilesPickerProvider = Provider<MediaFilesPicker>(...);        // file_selector openFiles，一组 XTypeGroup：label 'media'，extensions = 两个白名单合并

// lib/features/canvas/models/canvas_node_import.dart
const String kNodeOriginImport = 'import';
extension CanvasNodeImport on CanvasNode { bool get isImported; String? get originalFileName; } // type_config['origin'] == 'import'；['original_name']

// lib/features/canvas/providers/media_import_controller.dart
typedef MediaImportRequest = ({String path, NodePlacement placement});
enum MediaImportSkipReason { unsupported, unreadable, copyFailed }
typedef MediaImportSkip = ({String fileName, MediaImportSkipReason reason});
typedef MediaImportBatchResult = ({List<String> nodeIds, List<MediaImportSkip> skipped});
final mediaImportControllerProvider = NotifierProviderFamily<MediaImportController, Map<String, double>, String>(...); // canvasId → {nodeId: 0..1}；非 autoDispose：导入比画面活得久
class MediaImportController extends FamilyNotifier<Map<String, double>, String> {
  Future<MediaImportBatchResult> importFiles({required String projectId, required List<MediaImportRequest> requests});
}

// canvas_nodes_controller.dart
Future<CanvasNode> addNode({..., String? projectId}); // assert 改为 role != result || sourceNodeId != null || typeConfig['origin'] == 'import'
Future<void> discardImportShell(String id);            // 仅限 isImported 且无 url 的节点：repo.hardDelete + 从内存去掉（不是软删：失败壳不进回收站）
```
- `importFiles` 流程：①对每个请求 `mediaImportKindOf`，null ⇒ 记 unsupported 跳过；②其余按顺序 `addNode(role: result, type: image|video, label: 原文件名截 200, laneId/position 取 placement, typeConfig: {origin: 'import', original_name}, projectId)`，并把 `nodeId: 0.0` 放进 state——全部壳先建好（用户一次看到全部占位）；③逐个 `copyIntoCanvas`（onProgress 每变化 ≥ 1% 才写 state）；④成功 ⇒ 组 patch：图片 `{image_url, width?, height?}`；视频再读 `thumbnailServiceProvider`（可空）抽首帧到 `imports/<同 uuid>.jpg`，`{video_url, thumbnail_url?, duration_ms?, width?, height?}`（抽帧失败吞掉，同 job_media_persister 第 431–470 行口径）；⑤回写：节点控制器还在（`ref.exists`）⇒ `patchTypeConfigMany`，否则直写 `nodeRepository.patchTypeConfig`；⑥失败 ⇒ `discard` 文件 + `discardImportShell`，记 copyFailed / unreadable；⑦从 state 去掉该 nodeId。
- 图片宽高：PNG 走 `core/media/png_dimensions.dart`；JPG / WebP 走注入的 `ImageSizeProbe`（默认实现用 dart:ui `ImageDescriptor.encoded` 只读头），探不出 ⇒ 不写键。
- nodes.status 列不写（CanvasNode 没有 status 字段，读路径不读它）；「复制中」由 `mediaImportControllerProvider` 的内存进度表达。

## 行为规则与边界情况
1. 扩展名大小写不敏感：`雾江.JPG`、`a.Mp4` 被接受；`.jpeg` 归图片；`notes.pdf`、无扩展名 ⇒ unsupported 跳过、不建节点。
2. 目标文件名一律 `<uuid>.<小写扩展名>`，原名只进 `original_name` 与节点 label：不撞名、不受 Windows 大小写不敏感 / 非法字符、macOS NFD 文件名影响。
3. 写盘顺序：`<uuid>.<ext>.partial` → flush → rename；任何一步失败删 .partial，抛 LocalIOError，目录里不留文件。
4. 路径一律经 FileResolverService.resolve（画布根内）；相对路径形如 `imports/<uuid>.png`，库里只存相对路径。
5. 复制中：卡片状态行「复制中 48%」（accent），缩略区叠进度条；完成后状态行「导入」，右侧 meta「1920×1080」（有宽高才写），视频 meta 写时长不写（交给 duration-format 后续统一）。
6. 失败（源被删 / 无权限 / 0 字节 / 磁盘满）：该文件的壳节点被**硬删**、文件不留；同批其它文件不受影响；结果里点名 `(fileName, reason)`。
7. 全部跳过 / 全部失败：返回 `nodeIds` 为空，画布上什么也不剩。
8. 并发：同一画布两批导入可同时进行，进度 map 各管各的节点；同一批内按顺序复制（不并行，避免磁盘抖动）。
9. 崩溃 / 退出时正在复制：壳节点（无 url）由启动时 `softDeleteEmptyOrphanResults` 收进回收站（现有逻辑，判据是三个 url 都空，完成的导入节点永远不满足，所以不加豁免）；残留 .partial 只会被 reaper 记成候选日志（reaper 不删文件）。
10. 关画布 / 删画布中途：控制器非 autoDispose，复制继续；节点控制器已释放时直写仓储，重开画布时看到完成的卡。中途用户删了这张壳卡：复制完照常回写库（撤销删除时能看到完整的图）。
11. 孤儿判据：`listOrphanResults` 不再列 origin=import 的节点；reaper 现在也扫 `imports/`，被任何节点（含软删）引用的导入文件不算孤儿，7 天以上无人引用的才记候选日志。
12. 撤销：本片不进撤销栈、不弹卡（没有入口）；返回的 nodeIds 供 W3 建 ImportMediaCommand。
13. 导入节点是产物：`sourceNodeId == null`，不进叙事链（IS-Q6 A），序列 / 导出 / 大纲链判据不改。
14. mac / Windows：picker 在 macOS 依赖 `com.apple.security.files.user-selected.read-*` entitlement（Release 已有 read-write；DebugProfile 没开沙箱）；Windows 路径反斜杠、盘符大小写不影响（只取 basename 与扩展名）；`importOriginalName` 用注入的 `p.Context` 测两种分隔符。

## 新文案键
| key | en | zh |
|---|---|---|
| nodeStatusImported | Imported | 导入 |
| nodeStatusImporting | Copying {percent}% | 复制中 {percent}% |

（percent int，description 写「Status line of an imported media node while its file is being copied into the canvas」。）

## 测试
- `test/services/file_media_import_service_test.dart`（临时目录 + DefaultFileResolverService）
  - 「png 复制进 imports/<uuid>.png，返回相对路径与字节数」；「.JPG 落成 .jpg」；「宽高：PNG 读头」。
  - 「onProgress 单调递增、最后一次为 1.0」。
  - 「源不存在 ⇒ LocalIOError(reason unreadable)，imports/ 为空（无 .partial）」；「0 字节 ⇒ empty」；「pdf ⇒ unsupported」。
  - 「rename 失败（目标目录只读 / 注入失败的写入器）⇒ .partial 被删」。
  - 「两次导入同名文件 ⇒ 两个不同 uuid 文件」。
  - 「importOriginalName：p.windows `C:\\a\\雾江.JPG` → 雾江.JPG；p.posix 同理」；「mediaImportKindOf 大小写表驱动」。
- `test/features/canvas/providers/media_import_controller_test.dart`（ProviderContainer + InMemory 仓储 + 假服务）
  - 「两张图一视频：先建 3 个壳（type_config 只有 origin / original_name），再逐个回写 url」。
  - 「复制中 state 有 nodeId 进度，完成后移除」。
  - 「其中一个复制失败：该节点被 hardDelete、服务 discard 被调，其余两张正常；skipped 点名 copyFailed」。
  - 「pdf 不建节点，skipped 点名 unsupported」。
  - 「视频：thumbnailService 返回 duration 5000 ⇒ duration_ms 5000、thumbnail_url imports/<uuid>.jpg；thumbnailService 为 null ⇒ 只有 video_url」。
  - 「节点控制器已释放 ⇒ 走 repo.patchTypeConfig」。
  - 「新节点带 projectId」。
- `test/features/canvas/canvas_nodes_controller_test.dart`：用例「result 节点必须带 sourceNodeId（assert）」保留，并加「origin=import 的 result 节点可不带 sourceNodeId」；「discardImportShell 硬删且只限无 url 的导入节点」。
- `test/features/canvas/models/canvas_node_import_test.dart`：isImported / originalFileName。
- `test/features/canvas/widgets/node_card_import_test.dart`：「进度 0.48 ⇒ 状态行 Copying 48% + InkProgressBar」；「完成 ⇒ Imported + 1920×1080」；「非导入产物状态行不变」。
- `test/services/orphan_file_reaper_test.dart`：白名单用例改为 images / videos / imports 都扫，exports / characters / 画布根不扫；新增「被引用的 imports 文件不算孤儿；未引用且 >7d 的算」。
- `test/storage/repositories/repository_sql_templates_test.dart`：「listOrphanResults 排除 origin=import」（spy SQL 含 `'origin'` 与 `<> 'import'`）。

## 变异点
1. `mediaImportKindOf` 去掉 `toLowerCase` →「.JPG 落成 .jpg」「大小写表驱动」红。
2. 直接写目标文件不经 .partial（或失败不删 .partial）→「rename 失败 ⇒ .partial 被删」「源不存在 imports/ 为空」红。
3. 目标名用原文件名 →「两次导入同名文件 ⇒ 两个不同文件」红。
4. 失败时 `removeNode`（软删）代替 `discardImportShell` →「该节点被 hardDelete」红。
5. 不先建全部壳、改成边复制边建 →「先建 3 个壳」红。
6. 进度完成后不从 state 移除 →「完成后移除」红。
7. assert 不放宽 →「origin=import 的 result 节点可不带 sourceNodeId」红（debug 下抛 AssertionError）。
8. `kOrphanMediaSubdirs` 不加 imports →「未引用且 >7d 的算」红；加了但把 imports 当一律孤儿（忽略引用集）→「被引用的不算」红。
9. `listOrphanResults` 不加排除 → SQL 模板用例红。
10. `_StatusRow` 不读进度 →「Copying 48%」红。
11. addNode 不写 projectId →「新节点带 projectId」红。

## 验收
- `flutter analyze lib test`；`flutter test test/services test/features/canvas test/storage/repositories/repository_sql_templates_test.dart`；逐条变异。
- 截图：`NodeCard` 三态——导入图片完成（雾江.jpg · Imported · 1920×1080）、导入视频复制中 48%、导入视频完成（首帧缩略）；用 InMemory 节点 + 覆盖 `mediaImportControllerProvider` 状态。
- docs/CLAUDE.md 快照由主 Agent 补：core/interfaces/media_import_service.dart、services/file_media_import_service.dart、core/di/media_import.dart、canvas/models/canvas_node_import.dart、canvas/providers/media_import_controller.dart 各一行。

## 风险与不确定
- 偏离 contract：canvas_nodes_controller 多了 `addNode(projectId:)` 与 `discardImportShell`（都是本片已归属文件内的加法）；`core/di/media_import.dart` 顺带放 `mediaFilesPickerProvider`，让 W3 不必再碰 core/di。公开名 `MediaImportService`、`mediaImportServiceProvider`、`media_import_controller.dart`（`MediaImportController` / `mediaImportControllerProvider`）均保持。
- 依赖 nodes-batch-ops 的 `patchTypeConfigMany` 签名；若合入名不同按实际改并回报。
- `softDeleteEmptyOrphanResults` 不加豁免与 plan「孤儿结果判定豁免导入节点」字面不一致：完成的导入节点必有 url，永远不会被它收；收走的只会是崩溃留下的空壳，这正是「零残留」想要的。
- 项目包会把残留 .partial 一起打包（整目录打包）；量小，记入后续。
