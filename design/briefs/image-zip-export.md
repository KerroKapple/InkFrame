# image-zip-export · 图片 ZIP 导出：每镜选定的图片产物 + metadata.json
- 波次：W15 / lane：E / 基底：叠在 delivery-history-tab 之后（从 `feat/delivery-history-tab` 起分支）
- 依赖切片：export-tab-history（W6：`export_new_cards.dart` 的「图片 ZIP」格子由常量 `ExportFormatsLanded.imageZip = false` 门住；`re_export.dart` 的 `kReExportHandlers: Map<ExportKind, ReExportHandler>`，「后续 PDF / ZIP 片各追加一行」）、export-records-recording（W6：`exportHistoryRecorderProvider` → `ExportHistoryRecorder.record(ExportRecordDraft)`，`ExportRecordDraft.failed(...)`）、export-records-table（W4：`ExportKind.zip` / `ExportRecordStatus`）、current-take（W1：`latestTakeNodeIds` 已改名 `currentTakeNodeIds(candidates, {pinnedBySource})`，配 `pinnedResultIdsBySource(nodes)`（`canvas/models/canvas_node_take.dart`））、delivery-history-tab（同 lane 前序，只为串行 rebase）
- 阻塞决定：无（不加 pub 依赖：`archive: ^4.0.9` 已在 `pubspec.yaml` 第 58 行）

## 执行约定
1. 在你自己的工作树里，从 `feat/delivery-history-tab`（若已合入则 origin/main）起新分支 `feat/image-zip-export`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。docs/CLAUDE.md 的项目结构（新服务 / 新 di 文件）由主 Agent 补，回报里列出要补的三行。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行——本片一行都不加（⌘K 入口留给以后）。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法——本片只读节点。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 本片补充：一个服务一个 di 文件（plan 第 0 节）——新建 `lib/core/di/image_zip_export.dart`，**不要**往 `core/di/video_export.dart` 里加（slices.json 写的是它，以 plan 为准）。服务只在 `lib/core/di/` 里 new（`no_direct_instantiation_test`）。不 catch `Exception`；资源清理边界的兜底 `catch` 照 `project_archive_service.dart` 约第 178 行的豁免写法并注释理由。

## 目标
导出标签「新导出」里的「图片 ZIP」格子从「置灰」变成可点：打开一个小对话框，显示「N 镜 · N 张图片 + metadata.json」，可改文件名，点「导出」把当前画布每一镜选定的图片产物按叙事链顺序打成 `exports/<名字>.zip`（`001_镜头名.png` …）+ `metadata.json`。完成后对话框给「打开文件夹 / 复制路径」，导出历史里多一行 kind = zip；失败也记一行，取消不记。

## 设计依据
- 画板 `b2/project/ShellExport.dc.html` 「导出第二批」：新导出格子「图片 ZIP · 每镜选定产物 · 新」；规则行「图片 ZIP：每镜选定产物 + metadata.json，用现成 archive」；「三条路径（导出对话框 / 交付 / PDF·ZIP）完成或失败各记一行，取消不记；文件不在了就划掉，只给『重新导出』」。
- slices notes：镜序用 `export_order.dart`（叙事链），take 用 `export_take_selection.dart`；metadata.json 键为英文协议字面量（镜号、文件名、prompt、provider、seed、尺寸）；先写 `.partial` 再改名，不留半个文件。
- 设计缺口：①画板没画 ZIP 对话框——本单按 R1–R4 自定（沿用 `export_video_dialog.dart` 的 InkInput + InkProgressBar + InkErrorBanner 骨架）；②没说「链上某镜没有图片产物」怎么办——跳过并在对话框里点名个数（R3）；③没说孤儿 / 导入式图片（无源配置节点）算不算一镜——按 `latestTakeNodeIds` 现有口径各自成镜、排在链后（R2）；④历史行「重新导出」对 zip 怎么走没画——见风险。

## 允许改的文件
- `lib/core/interfaces/image_zip_export_service.dart`（新建）：抽象 + `ImageZipEntry` / `ImageZipOutcome`。
- `lib/services/archive_image_zip_export_service.dart`（新建）：`ArchiveImageZipExportService implements ImageZipExportService`。
- `lib/core/di/image_zip_export.dart`（新建）：`imageZipExportServiceProvider`。
- `lib/features/export/util/image_zip_manifest.dart`（新建）：纯函数——选镜、命名、metadata 映射。
- `lib/features/export/util/export_order.dart`（**归属表外**，W15 无人占用）：抽出通用 `orderResultNodesForExport`，`orderVideoNodesForExport` 改为委托它（行为不变）；加 `exportableImageNodes`。
- `lib/features/export/providers/image_zip_export_controller.dart`（新建，归属表外的新文件）：状态机 + 调 recorder。
- `lib/features/export/widgets/image_zip_export_dialog.dart`（新建）：`showImageZipExportDialog`。
- `lib/features/export/widgets/export_new_cards.dart`（export-tab-history 新建）：`ExportFormatsLanded.imageZip` 改 `true`，「图片 ZIP」格子 onTap 开对话框（`exportNewZipPendingTooltip` 从此无人引用，回报里请主 Agent 按 Zero-BC 删键）。
- `lib/features/export/re_export.dart`（export-tab-history 新建；W15 无他片占用）：`kReExportHandlers` 追加一行 `ExportKind.zip: _reExportZip`（快照 `output_base_name` 预填后打开 `showImageZipExportDialog`；画布已删时由 W6 的 `canReExport` 判掉）。
- 测试：`test/features/export/util/image_zip_manifest_test.dart`、`test/services/archive_image_zip_export_service_test.dart`、`test/features/export/providers/image_zip_export_controller_test.dart`、`test/features/export/widgets/image_zip_export_dialog_test.dart`（均新建）；`test/features/export/util/export_order_test.dart`（只追加用例，现有用例不改）。

## 不许碰的文件
- 同 lane 前序：`export/widgets/delivery_panel.dart`、`delivery_history_tab.dart`、`delivery_clips_tab.dart`。
- W6 / W4 的历史链路：`export_history_recorder.dart`（只调用）、`export_history_provider.dart`、`export_history_list.dart`、`export_history_row.dart`、`shell/widgets/tabs/export_tab.dart`、`export_record*.dart`、`export_snapshot.dart`、迁移文件（`re_export.dart` 只追加 zip 一行，见允许列表）。
- `export/providers/export_controller.dart`、`delivery_controller.dart`、`export_task_registry.dart`（W14 export-in-task-popover 的；ZIP 不进任务弹层，见风险）、`export/widgets/export_video_dialog.dart`、`export/util/export_take_selection.dart`（只调用）、`export/models/delivery_plan.dart`、`core/di/video_export.dart`。
- W15 其他 lane 的文件（node_card / node_card_slot / text_node_inspector / inspector_submit_controller / left_rail_state / canvas_inspector_panel / canvas_screen / script_panel / script_document_controller / characters_controller / character_edit_dialog / character_library_panel / character_usage）。
- `create_node_menu.dart`、`canvas_node.dart`、ARB / generated / docs/CLAUDE.md、`pubspec.yaml`。

**同波（W15）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- text-inline-edit：`lib/features/canvas/providers/inline_edit_node.dart`、`lib/features/canvas/providers/inspector_submit_controller.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/stage/node_card_slot.dart`、`lib/features/canvas/widgets/node_inline_text_editor.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`test/features/canvas/providers/inline_edit_node_test.dart`、`test/features/canvas/providers/inspector_submit_controller_test.dart`、`test/features/canvas/widgets/text_inline_edit_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`
- collapse-all-panels：`lib/features/app_actions/app_action_ids.dart`（追加一行）、`lib/features/canvas/providers/inspector_expanded.dart`、`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/shortcuts/collapse_panels_keys.dart`、`test/features/canvas/providers/inspector_expanded_test.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/widgets/canvas_collapse_panels_test.dart`
- script-characters-row：`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`
- character-usage-links：`lib/features/canvas/providers/character_usage.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`test/features/canvas/providers/character_usage_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`
- delivery-history-tab：`lib/features/export/widgets/delivery_history_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/widgets/delivery_history_tab_test.dart`

## 具体改动
已有 API（main 上已核对）：
- `List<CanvasNode> orderVideoNodesForExport({required List<CanvasNode> allNodes, required List<CanvasEdge> edges})`、`List<CanvasNode> exportableVideoNodes(List<CanvasNode> nodes)`（`export_order.dart`）。
- `Set<String> currentTakeNodeIds(List<CanvasNode> candidates, {Map<String, String> pinnedBySource = const {}})`（`export_take_selection.dart`，W1 current-take 由 `latestTakeNodeIds` 改名而来）+ `Map<String, String> pinnedResultIdsBySource(Iterable<CanvasNode> nodes)`（W1，`canvas/models/canvas_node_take.dart`）。
- `List<CanvasNode> orderByNarrativeChain({required nodes, required edges, include})`（`canvas/util/narrative_order.dart` 第 27 行）；`resultsFor` / `currentResultFor`（`canvas/util/node_artifacts.dart`；W1 之后 `latestResultFor` 可能已按 Zero-BC 删除，不要用）。
- `ResultParams resultParamsOf(CanvasNode result, CanvasNode? source)`、`CanvasNode? resultSourceNode(CanvasNode result, List<CanvasNode> nodes)`（`canvas/util/result_params.dart`；provider / prompt 取源配置，width / height / seed 取产物自身）。
- `String deliveryMediaFileName({required int index, required String shotName})`（`delivery_plan.dart` 约第 163 行，返回 `NNN_名.mp4`，清洗规则含把 `.` 换掉）——本片取它去掉 `.mp4` 的主体再接源扩展名，**不复制清洗规则**。
- `bool isValidExportBaseName(String name)`（`export_file_name.dart`）。
- `File resolveInProject({required String projectId, required String relativePath})`（项目根相对，`PathSecurityError`）。
- 写 zip 的现成套路：`ZipFileEncoder` + `.partial` + `closeSync` 后再删 + `renameSync`（`services/project_archive_service.dart` 约第 76–200 行）。
- `Clock.nowUtc()`（`core/logging/logger_service.dart` 第 52 行）、`clockProvider`、`loggerProvider`、`fileResolverServiceProvider`。
- `ExportCancelToken`（`core/interfaces/video_export_service.dart` 第 10 行，复用，不另造）。
- `LocalIOError({extra, cause, stackTrace})`、`CancelledError.byUser({extra})`、`ProviderError(code: InkErrorCode.invalidParameter, extra: ...)`。
- 前序：`exportHistoryRecorderProvider` / `ExportRecordDraft`（W6 export-records-recording）、`ExportNewCards` / `ExportNewCell` / `ExportFormatsLanded`（W6 export-tab-history）——名字按派工单，合入后有出入以代码为准。

新增：
```dart
// core/interfaces/image_zip_export_service.dart
@immutable class ImageZipEntry { final String sourceRelativePath; /* 项目根相对 */ final String archiveName; }
@immutable class ImageZipOutcome { final String relativePath; /* exports/x.zip */ final int sizeBytes; final int fileCount; }
abstract class ImageZipExportService {
  Future<ImageZipOutcome> writeZip({
    required String projectId,
    required List<ImageZipEntry> entries,
    required String metadataJson,
    String? outputBaseName,                 // null/空 → 'images_<UTC ms>'
    void Function(double progress)? onProgress, // 按已写入条数 0..1，单调，成功前收口 1.0
    ExportCancelToken? cancelToken,
  });
}
// core/di/image_zip_export.dart
final imageZipExportServiceProvider = Provider<ImageZipExportService>(...); // fileResolver + clock + logger

// export_order.dart（新增，旧函数行为不变）
List<CanvasNode> exportableImageNodes(List<CanvasNode> nodes); // role=result, type=image, imageUrl!=null, canvasId!=null
List<CanvasNode> orderResultNodesForExport({required List<CanvasNode> allNodes, required List<CanvasEdge> edges, required List<CanvasNode> candidates});

// util/image_zip_manifest.dart
@immutable class ImageZipShot { final int number; final CanvasNode result; final String archiveName; final String sourceRelativePath; final ResultParams params; }
@immutable class ImageZipPlan { final List<ImageZipShot> shots; final int skippedChainShots; bool get isEmpty; }
ImageZipPlan buildImageZipPlan({required List<CanvasNode> nodes, required List<CanvasEdge> edges});
Map<String, Object?> imageZipMetadata({required ImageZipPlan plan, required String projectName, required String canvasId, required DateTime exportedAtUtc});
const String kImageZipMetadataFileName = 'metadata.json';
const int kImageZipMetadataVersion = 1;

// providers/image_zip_export_controller.dart（照 ExportController 的四态 + keepAlive + _alive 写法）
sealed class ImageZipExportState; // Idle / Busy(progress?) / Success(ImageZipOutcome) / Failure(InkError)
final imageZipExportControllerProvider = AutoDisposeNotifierProvider<ImageZipExportController, ImageZipExportState>(...);
Future<void> export({required String projectId, required String projectName, required String canvasId, required ImageZipPlan plan, String? outputBaseName});
void cancelExport();

// widgets/image_zip_export_dialog.dart
Future<void> showImageZipExportDialog(BuildContext context, WidgetRef ref, {required String canvasId});
```
metadata.json 形状（键全英文、`null` 显式写出）：
```json
{"format":"inkframe.image_zip","version":1,"project":"Alpha","canvas_id":"c1","exported_at":"2026-…Z",
 "shots":[{"shot":1,"file":"001_镜头01.png","node_id":"r1","source_node_id":"n1",
           "prompt":"…","provider":"gemini-image","seed":42,"width":1920,"height":1080}]}
```

## 行为规则与边界情况
- R1 候选 = `exportableImageNodes(当前画布节点)`；顺序 = `orderResultNodesForExport(candidates: …)`（叙事链序，链外按 position.x 追加）；只留 `currentTakeNodeIds(candidates, pinnedBySource: pinnedResultIdsBySource(当前画布节点))` 里的（每镜一张；固定的 take 优先，与导出 mp4 对话框同口径）。`number` 从 1 连续编号。
- R2 无源配置的孤儿 / 导入式图片各自成一镜，排在链上镜之后（沿用两函数现有口径，不另判）。
- R3 `skippedChainShots` = 叙事链上 `type == image` 的配置节点里名下没有图片产物的个数；对话框显示 `imageZipSkipped(count)`（>0 才显示）。视频配置节点不算跳过。
- R4 文件名 = `deliveryMediaFileName(index: number, shotName: 源配置节点 label，无源用产物 label)` 去掉 `.mp4` + 源 `imageUrl` 的小写扩展名（无扩展名就不加）。名字清洗后为空 → 只剩 `NNN.ext`。编号唯一 ⇒ zip 内不重名。
- R5 `sourceRelativePath = 'canvases/<canvasId>/<imageUrl>'`（与 `projectRelativeVideoPath` 同一换算）。
- R6 输出 `exports/<base>.zip`；`outputBaseName` 非空时须过 `isValidExportBaseName`，对话框提前拦截（不合法时导出按钮禁用 + 提示），服务侧再校验一次，不合法抛 `ProviderError(invalidParameter, reason: 'invalid_output_name')`。
- R7 落盘：先写 `<target>.partial`，全部条目 + `metadata.json` 写完后 close，删同名旧文件再 `renameSync`。任何失败 / 取消：先 close 再删 `.partial`；同名旧 zip 全程不动。rename 失败（旧文件被占用）抛 `LocalIOError(reason: 'output_replace_failed', partial_relative_path: …)` 且**保留** `.partial`（已完整，「已成功不误删」）。
- R8 错误映射：entries 为空 → `ProviderError(invalidParameter, reason: 'empty_input_list')`；源文件不存在 → `LocalIOError(reason: 'input_not_found', relative_path: …)`；路径非法 → `PathSecurityError` 由 controller 翻成 `ProviderError(invalidParameter, reason: 'path_security')`；IO → `LocalIOError(reason: 'export_io_failed')`；取消 → `CancelledError.byUser(reason: 'export_cancelled')`。
- R9 取消：`cancelToken` 在每写完一个条目后检查；已经开始 rename 之后的取消不生效（产物完整就是成功）。
- R10 记录：controller 在 Success 与 Failure 终态各调一次 `ref.read(exportHistoryRecorderProvider).record(...)`：成功 = `ExportRecordDraft(projectId:, canvasId:, kind: ExportKind.zip, status: ExportRecordStatus.succeeded, outputRelativePath: outcome.relativePath, shotCount: plan.shots.length, sizeBytes: outcome.sizeBytes, snapshot: …)`；失败 = `ExportRecordDraft.failed(projectId:, canvasId:, kind: ExportKind.zip, error: e, shotCount: …)`（error code / reason 由它从 InkError 取）；快照 `{"canvas_id","node_ids":[…],"output_base_name"}`，键名若 W6 `export_snapshot.dart` 已有同义常量就用常量；取消（回 Idle）不记。recorder 写库失败只记日志，不改变导出成败（recorder 自己保证）。
- R11 对话框：标题 `imageZipDialogTitle`；摘要 `imageZipSummary(count)`；`imageZipSkipped`；名字输入框（占位 `imageZipNameHint`）；Busy 时进度条 + 「取消」；Success 时 `imageZipDone(path)` + 打开文件夹（`folderOpenerProvider.open(exports 绝对目录).ignore()`）+ 复制路径；Failure 时 `InkErrorBanner`（文案走 l10n_x 的 InkError 映射）+ 重试。`plan.isEmpty` 时导出按钮禁用并显示 `imageZipEmpty`。对话框中途关闭，导出照样走完（controller keepAlive），成功 / 失败照记历史。
- R12 「新导出」格子：项目与画布都有（ShellState.project != null && canvasId != null）才可点，否则禁用并给 W6 现有的禁用 tooltip 判据；可点后 onTap = `showImageZipExportDialog(context, ref, canvasId: …)`。去掉该格子的「待支持 / 置灰」原因。
- R13 并发：controller Busy 时再次 `export` 直接返回（同 ExportController）。
- R14 平台：zip 内路径一律 `/` 分隔；中文文件名按 UTF-8 写（archive 4 默认置 UTF-8 标志位，执行时用测试回读核对）；Windows 上 rename 前必须已 close encoder（句柄）——R7 已覆盖。除此无平台差异。

## 新文案键
| key | en | zh |
|---|---|---|
| imageZipDialogTitle | Export images as ZIP | 导出图片 ZIP |
| imageZipSummary | {count} shots · {count} images + metadata.json | {count} 镜 · {count} 张图片 + metadata.json |
| imageZipSkipped | {count} image shots on the chain have no result yet and will be skipped | 链上有 {count} 个图像镜还没有产物，将跳过 |
| imageZipEmpty | No image results on this canvas yet | 这张画布还没有图片产物 |
| imageZipNameHint | File name (leave blank for a timestamp) | 文件名（留空用时间戳） |
| imageZipNameInvalid | This name can't be used as a file name | 这个名字不能用作文件名 |
| imageZipDone | Saved to {path} | 已保存到 {path} |

count 为 int，path 为 String。复用（不新建）：「导出」= `exportVideoStart`、「打开文件夹」= `deliveryOpenFolder`、「复制路径」= `exportVideoCopyPath`、「重试」= `commonRetry`、「取消」= `commonCancel`。

## 测试
先写、先红。
`test/features/export/util/image_zip_manifest_test.dart`
- `orders shots by narrative chain and keeps one take per shot`：链 n1→n2，n1 有两张图（新旧）→ 只取新的，顺序 n1、n2。
- `orphan images follow chain shots`。
- `file names are numbered and keep the source extension`：`001_镜头01.png`、`002_x.jpg`；名字全非法 → `003.png`。
- `skipped counts only image config nodes without results`：链上 image 配置无产物 1 个、video 配置 1 个 → 1。
- `metadata uses english keys and writes nulls explicitly`：seed 缺 → `"seed": null`；键集合精确等于约定。
- `video results are never included`。
`test/features/export/util/export_order_test.dart`（追加）
- `orderResultNodesForExport matches orderVideoNodesForExport for video candidates`。
`test/services/archive_image_zip_export_service_test.dart`（临时目录 + fake resolver / clock）
- `writes entries and metadata then renames partial`：回读 zip 条目名与字节；目录里无 `.partial`。
- `missing source fails with input_not_found and leaves no partial`。
- `cancel after first entry removes partial and keeps old zip`：预置同名旧 zip，取消后旧 zip 字节不变。
- `empty entries are rejected`。
- `progress is monotonic and ends at 1`。
- `cjk entry names round-trip`。
`test/features/export/providers/image_zip_export_controller_test.dart`（fake service + fake recorder）
- `success records one zip row`；`failure records one failed zip row`；`cancel records nothing and returns idle`；`second export while busy is ignored`。
`test/features/export/widgets/image_zip_export_dialog_test.dart`
- `empty plan disables export`；`invalid name disables export`；`busy shows progress and cancel`；`success shows open folder`（fake folderOpener 收到 exports 目录）。

## 变异点
- M1 manifest 里去掉 `currentTakeNodeIds` 过滤（或不传 `pinnedBySource`）→ `orders shots … one take per shot` 变红（另加一例：固定旧 take ⇒ 取旧的）。
- M2 文件名改成固定 `.png` → `file names … keep the source extension` 变红。
- M3 skipped 判据不看 `type == image` → `skipped counts only image config nodes` 变红。
- M4 metadata 里 null 字段省略不写 → `metadata uses english keys and writes nulls explicitly` 变红。
- M5 服务直接写目标文件不经 `.partial` → `cancel after first entry … keeps old zip` 变红。
- M6 失败路径不删 `.partial` → `missing source fails … leaves no partial` 变红。
- M7 controller 在 CancelledError 分支也调 recorder → `cancel records nothing` 变红。
- M8 controller Failure 不调 recorder → `failure records one failed zip row` 变红。
- M9 `orderVideoNodesForExport` 委托时丢掉链外追加 → 现有 `export_order_test` 与新追加用例变红。
- M10 对话框不校验名字 → `invalid name disables export` 变红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/export test/services/archive_image_zip_export_service_test.dart test/features/shell test/quality`（排除 golden）。
- 逐条做 M1–M10。
- 截图：`showImageZipExportDialog`，shellController 播种项目 Alpha + canvas c1，画布 3 镜图片（1 镜缺产物）；截①初始（摘要 + 跳过 1）②Busy 50% ③成功 ④失败（input_not_found）；再截导出标签「新导出」格子行（图片 ZIP 已可点）。

## 风险与不确定
- recorder（`ExportRecordDraft` / `exportHistoryRecorderProvider`）、`ExportFormatsLanded`、`kReExportHandlers` 都按 W6 派工单写死在上文；合入后有出入以代码为准。
- 导出历史「重新导出」：W6 留了按 kind 追加一行的分派表 `kReExportHandlers`（`re_export.dart`），本片在那里追加 zip 一行，不碰 export_history_row。
- 默认 take 判据用 W1 的 `currentTakeNodeIds`（固定的优先），不自己再写。
- ZIP 不进任务弹层（export_task_registry 是 W14 的，且 Q2 只点名导出 / 交付）；进度只在对话框里。
- 改 `export_order.dart` 不在归属表里（W15 无人占用），已在回报里说明；`deliveryMediaFileName` 借用是为了不复制清洗规则，若主 Agent 更愿意把清洗函数公开成 `exportFileSegment`，那要动 `delivery_plan.dart`（本片不做）。
