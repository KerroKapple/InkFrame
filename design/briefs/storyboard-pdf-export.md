# storyboard-pdf-export · 分镜 PDF 导出（每页 6 镜，打包中文字体）
决定：SE-Q4 按建议 A（打包 Noto Sans SC，安装包约 +10 MB，OFL 授权，登记进 `lib/core/licenses.dart`）

- 波次：W18；lane：E；基底：origin/main
- 依赖切片（执行时都已合入 main）：
  - export-tab-history（硬依赖，W6）：导出标签的「新导出」格子在 `lib/features/export/widgets/export_new_cards.dart`，其中「分镜 PDF」格目前是置灰的；导出历史列表、行和 `export_history_provider.dart` 都已经有了。
  - export-records-recording（硬依赖，W6）：`lib/features/export/providers/export_history_recorder.dart`，终态时写一条导出历史，取消时不写。
  - image-zip-export（W15）：结构最接近本片的样板，包括接口、服务、DI、纯函数清单、对话框、点亮格子、调用 recorder 写 `kind = zip`。**本片照它的写法和调用方式来做**。
  - export-one-click（W16）：`export_file_name.dart` 里的 `uniqueOutputName`。
  - duration-format（W0）：统一时长函数（不到 60 秒写「N 秒」，否则写 m:ss）。
  - current-take（W1）：序列 / 交付按「当前 take」取产物，`sequenceLensProvider` 已经跟着改了。
- 阻塞决定：SE-Q4 → 按建议 A 执行（新依赖 `pdf` + 打包字体）。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 本片额外约定：`pubspec.lock` 由主 Agent 跑 `flutter pub get` 生成，执行代理只改 `pubspec.yaml`。字体文件需要下载（见「具体改动」）。如果拿不到 TrueType 版本，就停下来回报，不要换成别的字体。

## 目标
导出标签「新导出」里的「分镜 PDF」格变成可用。点它弹出一个小对话框：显示「N 镜 · M 页」，可以填文件名，然后点导出。导出的 PDF 写到项目的 `exports/` 目录。每页排 6 镜，每镜一格，内容是缩略图、镜号和名字、景别 · 运镜 · 时长、提示词摘要。中英文在 Windows 和 macOS 上排版一致。导完出完成卡，导出历史里多一条 `kind = pdf`。

## 设计依据
画板 `ShellExport`，小节「导出第二批」：
- 「新导出」五格之一是「分镜 PDF」，副标题「每页 6 镜」，标「新」。
- 「分镜 PDF：每页 6 镜（缩略图 · 镜号 · 景别运镜 · 时长 · 提示词摘要），需新依赖 `pdf` + 中文字体」。
- 「三条路径（导出对话框 / 交付 / PDF·ZIP）完成或失败各记一行，取消不记；文件不在了就划掉，只给「重新导出」」。
- 历史行的样例是「分镜_画布1.pdf」，说明默认文件名是「分镜_<画布名>」。
- Q4 建议 A：「打包 Noto Sans SC（安装包 +10 MB 量级）……两个平台排版一致，授权清楚」。

画板没画、按建议补的部分：
- 设计缺口：对话框长什么样没画。按建议：沿用 image_zip_export_dialog 的骨架。内容依次是标题「导出分镜 PDF」、一行摘要「N 镜 · M 页」、文件名输入框（预填「分镜_<画布名>」，校验用 `isValidExportBaseName`）、进度条、取消和导出两个按钮；失败时在框里显示 `InkErrorBanner`。
- 设计缺口：PDF 页面版式没画。按建议：
  - A4 横向，边距统一；
  - 页眉左边写「项目名 · 画布名」，右边写导出日期；
  - 正文 3 列 × 2 行；
  - 页脚居中写「第 N / M 页」；
  - 每格从上到下：16:9 缩略图框，然后「001  镜头名」，然后「中景 · 推近 · 5 秒」，最后是提示词摘要（最多 3 行，超出用省略号）；
  - 没有产物的镜，缩略框里写「还没有画面」。
- 设计缺口：没有任何镜（序列为空）时怎么办，画板没说。按建议：格子置灰，tooltip 写「这张画布还没有镜头」。

## 允许改的文件
- `pubspec.yaml`：在 dependencies 里加 `pdf: ^3.11.3`；把「界面无衬线字体（Noto Sans SC）不打包」那行注释改成「界面不打包；分镜 PDF 用的 NotoSansSC-Regular.ttf 只作资源，不注册成字体族」。`assets/fonts/` 目录已经在 assets 里了，不需要再加条目。
- `assets/fonts/NotoSansSC-Regular.ttf`（新建，二进制）、`assets/fonts/OFL-NotoSansSC.txt`（新建，OFL 1.1 全文）。
- `lib/core/licenses.dart`：头注的「覆盖对象」里补一行；新增一条 `LicenseRegistry.addLicense`，包名是 `'Noto Sans SC (font)'`，正文读 `assets/fonts/OFL-NotoSansSC.txt`。
- `lib/core/interfaces/storyboard_pdf_service.dart`（新建）：`StoryboardPdfService`、`StoryboardThumbnailLoader` 两个接口，以及它们用到的值对象。
- `lib/services/pdf_storyboard_service.dart`（新建）：用 `package:pdf` 实现 PDF 生成。
- `lib/services/ui_storyboard_thumbnail_loader.dart`（新建）：用 `dart:ui` 的 `instantiateImageCodec(targetWidth:)` 解码并缩小图片，输出 rawRgba。
- `lib/core/di/storyboard_pdf.dart`（新建）：`storyboardPdfServiceProvider`、`storyboardThumbnailLoaderProvider`。按 plan 第 0 节「新服务新建 `core/di/<name>.dart`」，**不改** `core/di/video_export.dart`。
- `lib/features/export/util/storyboard_pages.dart`（新建）：纯函数，负责分页和每格的原始字段，不做本地化。
- `lib/features/export/providers/storyboard_pdf_controller.dart`（新建）：一个状态机，状态是 idle / busy / success / failure；负责调服务和 recorder。
- `lib/features/export/widgets/storyboard_pdf_dialog.dart`（新建）：对话框。在这里用 `context` 把字段本地化，再交给控制器。
- `lib/features/export/widgets/export_new_cards.dart`（由 export-tab-history 新建）：`ExportFormatsLanded.storyboardPdf` 由 false 改 true（export-tab-history 留的一行开关），第 3 格「分镜 PDF」的 onTap 接打开对话框（可点条件按 export-tab-history 的 `ExportFormatsLanded.storyboardPdf && hasProject`，再加「lens 非空」）。
- `lib/features/export/re_export.dart`（由 export-tab-history 新建）：`kReExportHandlers` 只追加一行 `ExportKind.pdf: _reExportPdf`（export-tab-history 原话「pdf / zip 由各自切片追加一行」），`_reExportPdf` 打开对话框并用 `snapshotOutputBaseName(entry.record.settingsSnapshot)` 预填文件名。不改 `export_history_row.dart`。（image-zip-export 的派工单没有加 zip 那一行，不是本片的事。）
- `lib/theme/tokens.dart`：只追加一个常量类 `InkStoryboardPrint`，放 PDF 版式的尺寸、字号和颜色（颜色写成 ARGB int）。PDF 是打印介质，不跟深色 / 浅色主题走。
- 测试：
  - `test/features/export/util/storyboard_pages_test.dart`（新建）
  - `test/services/pdf_storyboard_service_test.dart`（新建）
  - `test/features/export/providers/storyboard_pdf_controller_test.dart`（新建）
  - `test/features/export/widgets/storyboard_pdf_dialog_test.dart`（新建）
  - `test/core/licenses_test.dart`

## 不许碰的文件
- 同波 W18 其他切片：
  - more-dropdown-panel：`canvas_toolbar.dart`、`canvas_more_menu.dart`、`more_menu_model.dart`（除了注册表追加一行）、`command_palette/command_actions.dart`；
  - create-menu-notes-characters：`create_menu_model.dart`、`create_menu_entries.dart`、`characters_controller.dart`、`character.dart`、`ink_menu_panel.dart`；
  - back-to-content-chip：`back_to_content_chip.dart`、`viewport_fit.dart`、`canvas_screen.dart`；
  - node-library-section / node-library-drag-recents：`left_rail/node_library_section.dart`、`templates_panel.dart`、`node_library_model.dart`、`canvas_library_actions.dart`、`prompt_preset_apply.dart`、`drag_payloads/node_library_payloads.dart`、`stage_drop/node_library_drop_handler.dart`、`canvas_drag_payload.dart`、`image_config_inspector.dart`、`prompt_presets_controller.dart`。
- `lib/core/di/video_export.dart`、`export_controller.dart`、`export_history_recorder.dart`、`export_record_repository.dart`、数据库迁移（本片不建表，`kind` 列本来就允许 `pdf`）。
- `lib/features/canvas/util/camera_labels.dart`、`sequence_lens.dart`、`sequence_lens_provider.dart`（只读复用）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W18 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - more-dropdown-panel：`lib/features/canvas/widgets/canvas_more_menu.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`test/features/canvas/util/more_menu_model_test.dart`、`test/features/canvas/widgets/canvas_more_menu_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`
  - create-menu-notes-characters：`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/canvas_character_create_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/theme/components/ink_menu_panel_test.dart`
  - back-to-content-chip：`lib/features/canvas/util/viewport_fit.dart`、`lib/features/canvas/widgets/back_to_content_chip.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`test/features/canvas/util/viewport_fit_test.dart`、`test/features/canvas/widgets/back_to_content_chip_test.dart`
  - node-library-section：`lib/features/canvas/util/canvas_library_actions.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`test/features/canvas/util/node_library_model_test.dart`、`test/features/canvas/widgets/left_rail/node_library_section_test.dart`
  - node-library-drag-recents：`lib/features/canvas/models/canvas_drag_payload.dart`、`lib/features/canvas/models/drag_payloads/node_library_payloads.dart`、`lib/features/canvas/util/canvas_library_actions.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/features/canvas/util/prompt_preset_apply.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`lib/features/canvas/widgets/stage_drop/node_library_drop_handler.dart`、`lib/features/canvas/widgets/stage_drop/stage_drop_registry.dart`、`test/features/canvas/util/node_library_model_test.dart`、`test/features/canvas/util/prompt_preset_apply_test.dart`、`test/features/canvas/widgets/left_rail/node_library_drag_test.dart`、`test/features/canvas/widgets/stage_drop/node_library_drop_handler_test.dart`

## 具体改动
```dart
// core/interfaces/storyboard_pdf_service.dart（不依赖 Flutter）
@immutable class StoryboardThumb { final Uint8List rgba; final int width; final int height; }
abstract class StoryboardThumbnailLoader {
  /// 解码并按 [maxWidth] 等比缩小；文件不存在或解码失败返回 null，不抛。
  Future<StoryboardThumb?> load(String absolutePath, {required int maxWidth});
}
@immutable class StoryboardPdfCell { final String number; final String title; final String meta; final String prompt; final String? imageAbsolutePath; }
@immutable class StoryboardPdfLabels { final String header; final String date; final String noImage; final String Function(int page, int total) pageOf; }
@immutable class StoryboardPdfResult { final String relativePath; final int sizeBytes; final int pageCount; }
abstract class StoryboardPdfService {
  /// 写到 exports/<outputBaseName>.pdf：先写 `.partial` 再 rename；失败或取消时只清 `.partial`。
  /// 错误都是 InkError：LocalIOError(reason: font_load_failed | export_io_failed)；取消时抛 CancelledError.byUser。
  Future<StoryboardPdfResult> export({required String projectId, required List<StoryboardPdfCell> cells,
    required StoryboardPdfLabels labels, required String outputBaseName, ExportCancelToken? cancelToken});
}

// util/storyboard_pages.dart（纯函数）
const int kStoryboardShotsPerPage = 6;
const int kStoryboardPromptMaxChars = 140;
@immutable class StoryboardEntry { final int index; final String nodeId; final String label;
  final ShotLanguage shotLanguage; final CameraMovement? camera; final int durationMs;
  final String? prompt; final String? canvasId; final String? imageRelativePath; }
List<StoryboardEntry> storyboardEntries(SequenceLens lens, List<CanvasNode> nodes);
List<List<T>> paginate<T>(List<T> items, {int perPage = kStoryboardShotsPerPage});
String promptExcerpt(String? prompt, {int maxChars = kStoryboardPromptMaxChars}); // 合并空白，超长时截断并加「…」

// providers/storyboard_pdf_controller.dart
sealed class StoryboardPdfState; // Idle / Busy / Success(relativePath, pageCount) / Failure(InkError)
final storyboardPdfControllerProvider = AutoDisposeNotifierProvider<StoryboardPdfController, StoryboardPdfState>(...);
Future<void> export({required String projectId, required String canvasId, required List<StoryboardPdfCell> cells,
  required StoryboardPdfLabels labels, required String outputBaseName, required int shotCount, required int durationMs});
void cancel();
```
- 每一镜从哪来：`sequenceLensProvider(canvasId).shots`。它已经是叙事链序、每镜取当前 take、带时长，和序列标签以及交付用的是同一个口径。
  - 镜号 = 下标 + 1，补成 3 位（「001」）；
  - 名字取 `SequenceShot.label`，为空时用节点类型名；
  - 景别取 `nodes` 里 `nodeId` 对应节点的 `shotLanguage`，运镜取 `parseCameraMovement(node.cameraName)`；
  - 提示词取 `node.promptText`，为空时退到 `SequenceShot.notes`；
  - 图片：kind 是 image 时用 `relativePath`，kind 是 video 时用 `thumbnailRelativePath`，kind 是 none 时为 null。
- 本地化放在对话框里做：景别用 `shotSizeLabel`，运镜用 `cameraMovementLabel`（这两个都在 `canvas/util/camera_labels.dart`），时长用 duration-format 的函数，三者用「 · 」拼起来，空的那一项跳过。绝对路径用 `fileResolverServiceProvider.resolve(projectId:, canvasId:, relativePath:)` 取，遇到 `PathSecurityError` 就当作没图（null）。
- 服务端的做法：
  - 字体字节通过构造参数注入一个 `Future<ByteData> Function()`。生产环境用 `rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf')`；`pw.Font.ttf(...)` 设成整份文档的 `theme`。构造参数里再加一个 `bool compress = true`，透传给 `pw.Document(compress:)`，只给测试用。
  - 缩略图走 `StoryboardThumbnailLoader.load(path, maxWidth: InkStoryboardPrint.thumbDecodeWidth)`，拿到后用 `pw.RawImage` 画出来。这样不会把 4K 原图整张塞进 PDF。
  - 每画完一页检查一次 `cancelToken`。
  - 字节写到 `.partial`，然后 rename 成正式文件。rename 失败时报 `LocalIOError(reason: 'export_io_failed')`。
- 文件名：对话框预填 `storyboardPdfDefaultName(canvasName)`。如果它不合法（画布名里有 `/` 之类的字符），退到 `storyboard_<yyyyMMdd_HHmm>`。提交时用 `uniqueOutputName(name, taken)` 加「(2)」，永不覆盖，和一键导出同一套规则。
- recorder：成功和失败时各调一次 `export_history_recorder`，调用形状照 image-zip-export：`kind = pdf`；`shotCount` 填镜数；`durationMs` 填 `lens.totalMs`；`sizeBytes` 成功时才有；快照 = `{ExportSnapshotKeys.version: kExportSnapshotVersion, ExportSnapshotKeys.outputBaseName: name, 'per_page': 6}`（输出名沿用 export-records-recording 的键 `output_base_name`，「重新导出」才能用 `snapshotOutputBaseName` 读回；`per_page` 是新键，写英文字面量）。经 `ref.read(exportHistoryRecorderProvider).record(ExportRecordDraft(kind: ExportKind.pdf, …))` 写，不 await。取消时不调。写库失败只记日志，不能把导出本身也变成失败（recorder 已经保证这一点）。
- 字体文件：用 Google Fonts 提供的 **静态 TrueType** `NotoSansSC-Regular.ttf`（glyf 轮廓，约 10 MB），OFL 正文用同一个仓库里的 `OFL.txt`。**不能用 `.otf`**：Noto CJK 的 OTF 是 CFF 轮廓，`package:pdf` 的 TtfParser 只认 glyf，加载时会失败或者显示成方块。

## 行为规则与边界情况
1. 13 镜分成 3 页，每页依次是 6、6、1 镜。最后一页空着的格子不画框。
2. 一镜都没有（lens 为空）：格子置灰，tooltip 写「这张画布还没有镜头」，对话框打不开。外壳没有项目上下文时，也置灰，复用现有的无项目文案。
3. 没有产物的镜（kind 为 none）、图片文件丢失、或图片解码失败：缩略框画「还没有画面」，这一镜照常导出，不报错。
4. 提示词超过 140 字时截断，末尾加「…」；连续的空白和换行合并成一个空格。
5. 没有景别、运镜、时长时，对应的那一项跳过，不显示「null」或空的分隔符。
6. 文件名不合法：导出按钮置灰，输入框下面写现有的 `exportVideoInvalidName` 文案。同名文件已存在时，自动加「(2)」。
7. 点取消：生成停止，`.partial` 被删掉，不写导出历史，对话框回到可编辑状态。
8. 失败，包括字体加载失败和写盘失败：对话框里显示 `InkErrorBanner`，导出历史写一条失败记录，对话框不关闭。
9. 成功：对话框关闭；出完成卡，标题「已导出 <文件名>.pdf」，按钮「打开文件夹」，用 `folderOpenerProvider` 打开 exports 目录，`chime: true`，类别 `ToastCategory.exportDone`（toast-category-mute）；导出历史多一行 pdf，可以打开、复制路径、从历史中移除。
10. 从历史里对 pdf 行点「重新导出」或「重试」：打开同一个对话框，文件名预填快照里的 `output_base_name`。
11. 导出过程中对话框不能关（`PopScope(canPop: !busy)`），这一点和视频导出对话框一样。
12. PDF 里的所有字段名都按当前界面语言显示，因为它们来自 ARB，经对话框传进去；页眉日期用 `intl` 按当前 locale 格式化。
13. Windows 和 macOS 都用打包的字体，版式完全一致；整个流程不依赖系统字体。

## 新文案键
| key | en | zh |
|---|---|---|
| storyboardPdfDialogTitle | Export storyboard PDF | 导出分镜 PDF |
| storyboardPdfSummary | {shots} shots · {pages} pages | {shots} 镜 · {pages} 页 |
| storyboardPdfNameLabel | File name | 文件名 |
| storyboardPdfDefaultName | Storyboard_{canvas} | 分镜_{canvas} |
| storyboardPdfStart | Export | 导出 |
| storyboardPdfNoImage | No image yet | 还没有画面 |
| storyboardPdfPageOf | Page {page} / {total} | 第 {page} / {total} 页 |
| storyboardPdfHeader | {project} · {canvas} | {project} · {canvas} |
| storyboardPdfDone | Exported {fileName} | 已导出 {fileName} |
| storyboardPdfNoShots | This canvas has no shots yet | 这张画布还没有镜头 |

（「打开文件夹」「取消」优先复用已有的键。）

## 测试
先写下面这些用例，确认它们失败后再实现。
- `storyboard_pages_test.dart`：
  - `paginate：13 镜 → [6, 6, 1]；0 镜 → 空`
  - `storyboardEntries：按 lens 顺序编号 1..N，取节点的 shotLanguage / camera / prompt`
  - `video 镜用 thumbnailRelativePath，none 镜图片为 null`
  - `promptExcerpt：合并空白；超过 140 截断加「…」；null → 空串`
- `pdf_storyboard_service_test.dart`（字体从磁盘读 `assets/fonts/NotoSansSC-Regular.ttf`；缩略图用假 loader，返回 4×4 RGBA，或者对某个路径返回 null；FileResolverService 指向临时目录）：
  - `7 格 → pageCount 2，exports/x.pdf 存在、以 %PDF 开头、没有 .partial 残留`
  - `含中文标题时嵌入了 Noto Sans SC`：构造服务时传 `compress: false`，断言输出字节里出现 `NotoSansSC`（BaseFont 名）
  - `loader 返回 null 时照样成功`
  - `预先取消 → CancelledError，且 exports/ 下无 x.pdf / x.pdf.partial`
  - `字体加载抛错 → LocalIOError(reason: font_load_failed)`
- `storyboard_pdf_controller_test.dart`（假服务 + 假 recorder）：
  - `成功 → Success 且 recorder 收到 kind pdf、shotCount、sizeBytes`
  - `失败 → Failure 且 recorder 收到失败行`
  - `取消 → Idle 且 recorder 未被调用`
- `storyboard_pdf_dialog_test.dart`：
  - `显示「N 镜 · M 页」与预填名「分镜_画布1」`
  - `非法名 → 导出按钮不可点`
- `test/core/licenses_test.dart`：
  - 期望集合加上 `'Noto Sans SC (font)'`；条目数改成 `greaterThanOrEqualTo(4)`。

## 变异点
1. `paginate` 每页改成 5 个，会被 `paginate：13 镜 → [6, 6, 1]…` 抓住。
2. `storyboardEntries` 对 video 镜用 `relativePath`（mp4），会被 `video 镜用 thumbnailRelativePath…` 抓住。
3. `promptExcerpt` 去掉截断，会被 `promptExcerpt：…超过 140 截断加「…」` 抓住。
4. 服务直接写正式文件、不经过 `.partial`，并且取消时不清理，会被 `预先取消 → …无 x.pdf / x.pdf.partial` 抓住。
5. 控制器取消时也调 recorder，会被 `取消 → Idle 且 recorder 未被调用` 抓住。
6. `licenses.dart` 漏登记 Noto Sans SC，会被 `test/core/licenses_test.dart` 抓住。
7. 服务没有把字体设进文档 theme（回退到 Helvetica），会被 `含中文标题时嵌入了 Noto Sans SC` 抓住。注意：pdf 包遇到缺字形只会打警告、不会抛异常，所以必须断言字体名真的出现在输出里。

## 验收
- 主 Agent 先 `flutter pub get`，提交 pubspec.lock。然后跑 `flutter analyze lib test`、`flutter test test/features/export test/services/pdf_storyboard_service_test.dart test/core/licenses_test.dart`，并按上面每条变异做一次。
- 截图场景：
  - 用 `ExportNewCards`（导出标签）截「分镜 PDF」格的可用和置灰两种状态；
  - 用 `StoryboardPdfDialog` 截三种状态：空闲（「13 镜 · 3 页」）、进行中、失败条；
  - 打开生成的 PDF，截第 1 页：中文镜名、景别运镜、时长、提示词三行截断、一格「还没有画面」都要看得到。
- 主 Agent 另外核对：安装包增量约 10 MB；关于页的许可列表里有 Noto Sans SC。

## 风险与不确定
- **字体格式和计划不一致**：plan 和 slices.json 写的是 `NotoSansSC-Regular.otf`。`package:pdf` 不支持 CFF/OTF，本片改成 `.ttf`，请主 Agent 确认。如果坚持用 OTF，就需要换 PDF 方案，或者先把字体转成 TTF。
- 执行代理需要能联网下载字体和 OFL 正文；下载不到就停下来回报。字体大约 10 MB，进仓库后会让 clone 变大，这是 SE-Q4 已经接受的代价。
- `pdf` 包会传递引入 `image`、`barcode` 等依赖，主 Agent 跑 pub get 后要看一下有没有版本冲突。
- 「重新导出」的分派点是 export-tab-history 的 `re_export.dart` / `kReExportHandlers`（按派工单）；main 上若不同，以 main 为准，找不到分派点就只点亮「新导出」格并在回报里说明。
- export_history_recorder 的调用签名以 W6 和 W15 合入后的代码为准。
- `StoryboardThumbnailLoader` 的生产实现依赖 `dart:ui` 解码，单测里用假的；真实解码只在截图验收时验证。
