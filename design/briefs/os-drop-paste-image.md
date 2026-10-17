# os-drop-paste-image · 从系统拖入文件 + Ctrl V 粘贴剪贴板图片 → 无源配置的导入产物节点
- 波次 W9 / lane C / 基底：叠在 dep-drop-pasteboard 之后；依赖切片：dep-drop-pasteboard（W9）、media-import-service（W2）、import-media-command（W3）、stage-drop-target（W4）、clipboard-paste（W7）、clipboard-text-paste（W8）、canvas-capsule（W1）；阻塞决定：IS-Q1 → A（desktop_drop + pasteboard）

## 目标（用户看到什么变化，2–4 行）
- 从 Finder 或资源管理器把图片 / 视频拖到画布上，舞台出现琥珀色虚线框「松手导入文件」。松手后文件落在松手处，变成导入产物节点：先显示「复制中」，复制完就是成片。不支持的文件在通知卡里点名跳过，卡上带「撤销」。
- 截图或在浏览器里复制一张图，到画布按 Ctrl V（mac ⌘V），粘出一张图像产物节点，没有源配置，文件写进本画布 `imports/`。
- Ctrl V 的顺序是：本应用复制的节点 → 剪贴板里的文件 → 剪贴板图片 → 文字（W8）。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/ImportSearch.dc.html`「导入媒体 · Ctrl U · 拖入文件 · Ctrl V 粘贴图片」：
  - 浮层是 1.5 px 琥珀虚线框 + wash 底 + upload 图标，标题「松手导入 3 个文件」，副行「图片 2 · 视频 1 · 落在松手处」；
  - 文件复制进 `canvases/<id>/imports/`，导入、拖入、粘贴图片、跨画布素材都落这里；
  - 落点：快捷键在视口中心散布，拖入 / 粘贴图片在松手处；
  - 一次一张通知带撤销，不支持的点名跳过（「跳过 1 个：notes.pdf 不是图片或视频」）。
- `b2/project/UndoClipboard.dc.html`「系统剪贴板」：
  - 剪贴板是图片 → 图像产物节点，无源配置，与导入媒体同一条路；
  - 示意卡标题是「剪贴板图像」，状态行「粘贴 · 未入链」。
- slices.json `os-drop-and-paste-image` 注：Ctrl V 分派是应用内剪贴板有节点就粘节点，没有就读系统剪贴板图片；哪片后合入就由哪片把分支接到同一个 Intent 上，本片就是后合入的那一片。
- 设计缺口：desktop_drop 在 mac 和 Windows 上，进入 / 悬停事件只带坐标、不带文件列表（`DropEventDetails` 只有 localPosition / globalPosition），松手前拿不到「N 个文件 · 图片 2 · 视频 1」。所以浮层改写成不带数字的「松手导入文件 · 图片或视频 · 落在松手处」，数字放到松手后的通知卡里。
- 设计缺口：拖进来的是文件夹、文件已经读不到、或者只拖了网页链接（没有本地文件），画板没写跳过理由。本片补三条理由（见文案键）。文件夹不递归。
- 设计缺口：Finder / 资源管理器「复制文件」后按 Ctrl V，画板没说怎么处理。本片按「与拖入同一条路，落在粘贴锚点」处理，而且排在读图片之前，因为 mac 上读 NSImage 可能读出文件图标。
- 设计缺口：拖到某张配置卡上，画板只给应用内素材定义了「松手弹菜单」。本片规定：系统文件不弹菜单，按落空白处理，落在松手处。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/widgets/canvas_view.dart`（骨架，W9 唯一）：
  - 用 `OsFileDropZone(canvasId:, child: …)` 包住舞台，与 W4 舞台 DragTarget 同一个盒，这样 `localPosition` 就是视口点。只加这一层包裹和 import。
  - （应用内载荷的分派不在 canvas_view.dart：W4 stage-drop-target 的约定是「新载荷 = 在 `widgets/stage_drop/stage_drop_registry.dart` 的 `kStageDropHandlers` 追加一行」，W9 rail-drag-characters 自己追加 `CharacterStageDropHandler()`。本片与它没有接线关系。）
- `lib/features/canvas/util/canvas_import_actions.dart`（W3 import-media-command 新建；W9 只归本片）：把 `importMediaViaPicker` 里「选完文件之后」那一段（`sortForImport` → `importGridOrigins` → 过相机 → `menuNodePlacement` → 进度卡 → `mediaImportControllerProvider(canvasId).notifier.importFiles(projectId:, requests:)` → 选中 / `record(ImportMediaCommand)` / 结果卡 + `bindCard`）原样抽成公开函数 `importMediaFiles`（签名见下），picker 入口改调它，行为与测试不变。这样拖入和粘贴文件与 Ctrl U 是同一条导入路、同一张结果卡、同一个撤销命令，不再另起一份。
- 新 `lib/features/canvas/widgets/os_file_drop_overlay.dart`：
  - `OsFileDropZone`：包 desktop_drop 的 `DropTarget`，管自己的悬停态，画浮层，松手时调动作；
  - `OsFileDropOverlay`：纯展示的虚线框，自绘虚线 painter 放在本文件，颜色 / 圆角 / 线宽全取 tokens，不改 theme 层。
- 新 `lib/features/canvas/util/import_drop_summary.dart`：纯函数，把投放项分成图片 / 视频 / 跳过（带理由）。
- 新 `lib/features/canvas/util/canvas_import_drop_actions.dart`：
  - `importDroppedFiles`：拖入和 Ctrl V 文件分支共用；
  - `pasteClipboardImage`：读剪贴板图 → 交给导入入口 → 无论成败都 `releaseTemp`。
- `lib/features/canvas/util/canvas_paste_actions.dart`：在 W8 的有序分派链里，把「文件 / 图片」两个分支插在「指纹对得上的节点」之后、「文字」之前。
- `lib/features/canvas/widgets/shortcuts/clipboard_keys.dart`：只为分派改调用处（如需），不新增键。
- 新测试：`test/features/canvas/util/import_drop_summary_test.dart`、`test/features/canvas/util/canvas_paste_image_test.dart`、`test/features/canvas/widgets/canvas_os_drop_test.dart`。
- W8 的 `test/features/canvas/util/canvas_paste_source_test.dart` 只追加用例，不改原有断言；W3 的 `test/features/canvas/util/canvas_import_actions_test.dart` / `test/features/canvas/widgets/canvas_import_media_test.dart` 不改、必须仍绿（抽取 `importMediaFiles` 的回归闸），另追加 `importMediaFiles with preSkipped folder lists it in the result card`、`empty paths + preSkipped → mediaImportNothing card, no importFiles call`。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- dep-drop-pasteboard（上一片）：`pubspec.yaml`、`pubspec.lock`、平台注册文件、`lib/core/interfaces/system_clipboard_image_service.dart`、`lib/services/pasteboard_clipboard_image_service.dart`、`lib/core/di/clipboard_image.dart`。只调用它们，不改；不得再建第二个 reader。
- canvas-find-bar：`widgets/canvas_screen.dart`、`widgets/stage/node_card_slot.dart`、`widgets/node_card.dart`、`lib/theme/tokens.dart`、`app_action_catalog.dart` 的「查找」行、新 `util/canvas_find_model.dart` / `providers/canvas_find_controller.dart` / `widgets/canvas_find_bar.dart` / `shortcuts/find_keys.dart`。
- multi-select-inspector：`widgets/canvas_inspector_panel.dart`、`widgets/image_config_inspector.dart`、`widgets/video_config_inspector.dart`，及新 `widgets/multi_select_inspector.dart` / `util/multi_select_params.dart` / `util/provider_capability_fields.dart` / `providers/multi_select_patch_controller.dart`。
- rail-drag-characters：`widgets/character_library_panel.dart`、`widgets/characters_section.dart`、`util/ref_image_budget.dart`、`util/canvas_character_drop_actions.dart`、`widgets/stage_drop/stage_drop_registry.dart`。
- batch-run-planner / job-eta：新 `lib/features/generation/services/batch_run_planner.dart`、`lib/core/interfaces/job_duration_history.dart`、`lib/core/di/job_duration_history.dart`、`lib/features/generation/providers/provider_eta_provider.dart`。
- outline-rename-menu：`widgets/left_rail/outline_panel.dart`、`providers/canvas_nodes_controller.dart`、`models/canvas_command.dart`。
- job-eta：`lib/storage/repositories/postgres_job_repository.dart`。
- W2 / W3 的导入实现：`lib/core/interfaces/media_import_service.dart`、`lib/services/file_media_import_service.dart`、`providers/media_import_controller.dart`、`models/commands/import_media_command.dart`、`shortcuts/import_media_keys.dart`、`canvas_menu/import_media_menu_items.dart`。只调用，不改（`util/canvas_import_actions.dart` 例外，见允许改的文件）。
- W4 / W9 的应用内拖放：`widgets/stage_drop/stage_drop_target.dart`、`widgets/stage_drop/stage_drop_registry.dart`（W9 归 rail-drag-characters 追加一行）。
- 通用：
  - `util/canvas_tool_actions.dart`（只调用 `menuNodePlacement` / `viewportCenteredNodePoint`）；
  - `canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_menu/blank_menu_entries.dart`；
  - `widgets/canvas_shortcuts.dart` 骨架与注册表；
  - `util/drop_placement.dart`、`providers/canvas_drop_hover.dart`、`models/canvas_drag_payload.dart`。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：rail-drag-characters：`lib/features/canvas/widgets/characters_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/import_drop_summary.dart（纯，不碰磁盘）
enum ImportKind { image, video }
enum ImportSkipReason { unsupportedType, folder, unreadable }
typedef DroppedEntry = ({String path, String name, bool isDirectory, bool exists});
@immutable class ImportDropSummary {
  final List<String> imagePaths; final List<String> videoPaths;
  final List<({String name, ImportSkipReason reason})> skipped;
  List<String> get acceptedPaths;     // 保持投放顺序
  bool get isEmpty;                   // 一个可导入的都没有
}
ImportDropSummary summarizeDrop(List<DroppedEntry> entries);   // 类型判据直接调 W2 的 mediaImportKindOf(path)（kImportImageExtensions / kImportVideoExtensions，小写比对），不另抄白名单
// util/canvas_import_actions.dart（W3 文件，本片只做抽取）
/// importMediaViaPicker 选完文件之后的那段原样搬来；picker 入口改成 `importMediaFiles(..., paths: 选中的, anchorViewport: anchorViewport)`。
/// [preSkipped]：调用方在进来之前就筛掉的（文件夹 / 读不到），并进结果卡的跳过说明；空列表 ⇒ 与原行为一字不差。
/// paths 为空且 preSkipped 非空 ⇒ 不调 importFiles，直接出 mediaImportNothing 卡（kind warning，无撤销）。
Future<void> importMediaFiles(BuildContext context, WidgetRef ref, {required String canvasId,
    required List<String> paths, Offset? anchorViewport, List<({String name, ImportSkipReason reason})> preSkipped = const []});
// util/canvas_import_drop_actions.dart
Future<void> importDroppedFiles(BuildContext context, WidgetRef ref,
    {required String canvasId, required List<DroppedEntry> entries, required Offset viewportPoint});
Future<void> pasteClipboardImage(BuildContext context, WidgetRef ref,
    {required String canvasId, required ClipboardImagePng image, required Offset viewportPoint});
// widgets/os_file_drop_overlay.dart
class OsFileDropZone extends ConsumerStatefulWidget { const OsFileDropZone({required String canvasId, required Widget child}); }
class OsFileDropOverlay extends StatelessWidget { const OsFileDropOverlay(); }
class OsFileDropKeys { static const overlay = ValueKey<String>('os-file-drop-overlay'); }
```
- 状态机（`_OsFileDropZoneState`，局部状态，不建 provider）：
  - `idle --onDragEntered--> hovering(viewportPoint)`，`--onDragUpdated-->` 更新点；
  - `hovering --onDragExited--> idle`（取消）；
  - `hovering --onDragDone--> idle`，然后调 `importDroppedFiles`。
- `DropTarget.enable` 由三个条件取与，任何一个为假就禁用（插件文档要求被遮住时禁用）：
  1. `ref.watch(shellControllerProvider.select((s) => s.isTabVisible(ShellTab.canvas)))`；
  2. `ModalRoute.isCurrentOf(context) ?? true`；
  3. `canvasId` 不为空。
- 两条入口如何调导入：
  - 拖入：`entries` 由 `DropDoneDetails.files` 映射而来。是 `DropItemDirectory`，或者 `FileSystemEntity.isDirectorySync(path)` 为真，就算文件夹：Windows 的 `performOperation` 一律给 `DropItemFile`，所以必须两条一起判。`File(path).existsSync()` 为假算读不到。`summarizeDrop` 之后调 `importMediaFiles(context, ref, canvasId:, paths: summary.acceptedPaths, anchorViewport: 松手的视口点, preSkipped: summary.skipped 里的 folder / unreadable)`——网格散布、`menuNodePlacement` 判泳道、uploading → success、`ImportMediaCommand` 一步撤销、结果卡与 `bindCard` 全在 W3 那一段里；不支持的类型照传给 importFiles，由 W2 控制器记成 `MediaImportSkipReason.unsupported`，结果卡用 W3 的 `mediaImportReasonUnsupported` 点名。
  - Ctrl V：在 W8 分派链上插两步，见规则 11。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 拖着文件进入舞台时，`OsFileDropKeys.overlay` 出现。离开窗口或舞台（onDragExited）后浮层消失，节点数不变，栈不变。
2. 在视口点 P 松手，拖入 `a.jpg`、`b.mp4`：建 2 个导入产物节点（`role == result`、无 sourceNodeId、`origin: import`）。第一个节点的落点 = `menuNodePlacement(P)`。P 在某泳道带里时 `laneId` = 该道。
3. 混入 `notes.pdf`、一个文件夹、一个已删的文件：只导入合法的那几个，结果卡（W3 `mediaImportSkipBody` 的格式：「跳过 N 个：」+ 按理由分行、每行最多点 3 个名字）点名「notes.pdf 不是图片或视频」「x.png 读不出来」，外加本片的一行「素材 是文件夹」。
4. 全部不合法：不建节点、栈不变，只出一张卡（W3 `mediaImportNothing`「没有导入任何文件」）+ 跳过点名，卡上没有撤销。
5. 扩展名大小写不敏感（`A.JPG` 算图片），白名单与 W2 一致，不另抄一份。
6. 拖入的所有文件算一步撤销，一次 Ctrl Z 撤掉全部；卡上「撤销」撤的是同一步（W3 / W0 撤销卡规则）。
7. 被遮住时不接收：设置浮层打开、画布标签不可见、或画布上压着对话框时，`enable == false`，松手不建节点。
8. 拖入期间又松手第二批：两批各自独立导入、各自一步撤销，互不覆盖。
9. 只拖网页链接（`files` 为空、`rawText` 非空）：不建节点，胶囊「只能拖入本机文件」。
10. Ctrl V 粘贴剪贴板图片（`readImage` → `ClipboardImagePng`）：建 1 个图像导入节点，落在粘贴锚点（指针在画布 → 指针；右键「粘贴」→ 按下点；都没有 → 视口中心 + 散布）。导入完成后 `releaseTemp` 被调用恰好一次。导入失败时也调用，零残留。
11. Ctrl V 分派顺序：
    1. 让位文本编辑；
    2. 指纹对得上的应用内节点（W8）；
    3. `readFilePaths()` 非空 → 与拖入同一条 `importDroppedFiles`，落在粘贴锚点；
    4. `readImage()`：`Png` → 规则 10；`Unsupported(format)` → 胶囊「剪贴板里的图片格式不支持」；`Unsupported(tooLarge)` → 胶囊「剪贴板里的图片太大」；`ReadFailed` → W8 的「读取剪贴板失败，再试一次」，不再往下试；`None` → 继续；
    5. 文字（W8）；
    6. 都没有 → W8 的「剪贴板里没有能粘贴的内容」。
12. 剪贴板同时有对得上的节点指纹文字和图片时，粘节点，不读图片：`readImage` 一次都不调用。
13. 导入写库或复制失败（W2 抛 InkError）：画布上不留 uploading 卡（W2 负责回滚），临时文件被 release，出 W3 的失败卡，栈里不留这一步。
14. Ctrl V 按住不放只粘一次（W8 已设 `includeRepeats: false`）。快速按两次粘出两张，各自一步撤销。
15. mac / Windows：
    - 粘贴键 ⌘V / Ctrl V，沿用 W7 键位；
    - 拖入源是 Finder / 资源管理器；mac 从浏览器拖图片走文件承诺（fromPromise），也是本地临时路径，照常导入；
    - 剪贴板图片格式差异（mac 给 PNG、Windows 给 BMP）全在 SystemClipboardImageService 里，本片看不到。
16. 导入节点的标题：W2 的 `MediaImportRequest = ({String path, NodePlacement placement})` 不收标签，`importFiles` 一律用原文件名（截 200）。所以拖入的文件用原文件名，剪贴板图片就是 `clipboard-<时间>.png`（写进风险；要「剪贴板图像」得先给 W2 加标签字段，另排一片）。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| canvasOsDropTitle | Drop to import files | 松手导入文件 |
| canvasOsDropSubtitle | Images or videos · placed where you drop | 图片或视频 · 落在松手处 |
| mediaImportReasonFolder（String names） | `{names}: folder` | `{names} 是文件夹` |
| canvasOsDropLinksOnly | Only files on this computer can be dropped | 只能拖入本机文件 |
| canvasPasteImageUnsupported | The image on the clipboard isn't a supported format | 剪贴板里的图片格式不支持 |
| canvasPasteImageTooLarge | The image on the clipboard is too large | 剪贴板里的图片太大 |

跳过理由与结果卡沿用 W3 import-media-command 已定的键：`mediaImportReasonUnsupported`（不是图片或视频）、`mediaImportReasonUnreadable`（读不出来）、`mediaImportNothing`（没有导入任何文件）、`mediaImportSkippedHeader` / `mediaImportMoreNames` / `mediaImportNameSeparator`；本片只补「文件夹」一条，命名与占位（`names`，已用分隔符拼好）跟 W3 同族。原先的 `canvasImportSkipFolder` / `canvasImportSkipUnreadable` / `canvasImportNothingImportable` 与 W3 同义，删掉；`canvasClipboardImageLabel` 因 W2 不收标签（规则 16）用不上，删掉。

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/import_drop_summary_test.dart`（新）：
  - `splits images and videos keeping order`；
  - `uppercase extension accepted`（规则 5）；
  - `pdf / folder / missing get the right reasons in order`（规则 3）；
  - `all skipped → isEmpty`（规则 4）。
- `test/features/canvas/util/canvas_paste_image_test.dart`（新；fake `SystemClipboardImageService` 记录调用、fake 导入入口、mock 系统文字剪贴板）：
  - `png on clipboard imports one image node at anchor`（规则 10）；
  - `releaseTemp called once on success and on import failure`（规则 10、13）；
  - `clipboard files take precedence over image`（规则 11.3：files 非空时 readImage 调用 0 次）；
  - `fingerprint-matched nodes skip image read`（规则 12）；
  - `unsupported / tooLarge / readFailed show their capsules, no node`（规则 11.4）；
  - `none falls through to text node`（与 W8 衔接）。
- `test/features/canvas/widgets/canvas_os_drop_test.dart`（新）：
  - 用 `OsFileDropZone` 包一个 SizedBox；
  - 测试里通过 `MethodChannel('desktop_drop')` 的 `handlePlatformMessage` 发 `entered` / `updated` / `exited` / `performOperation` 事件（核对 desktop_drop 0.8.4 `channel.dart` 的方法名）；
  - 用例：
    - `entered shows overlay, exited hides and imports nothing`（规则 1）；
    - `drop at P imports at menuNodePlacement(P) with lane`（规则 2）；
    - `drop with pdf and folder names skipped`（规则 3）；
    - `drop while settings overlay open does nothing`（规则 7：把 ShellState 置为 overlay = settings）；
    - `links-only drop shows capsule`（规则 9）；
    - `one undo step removes all dropped nodes`（规则 6）。
- `test/features/canvas/util/canvas_paste_source_test.dart`（W8 的）：追加 `files branch sits between nodes and text`。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. 分派里把 `readFilePaths` 挪到 `readImage` 之后 → `clipboard files take precedence over image` 变红。
2. 分派里先读图片再判指纹 → `fingerprint-matched nodes skip image read` 变红。
3. `pasteClipboardImage` 去掉 finally 里的 `releaseTemp` → `releaseTemp called once … on import failure` 变红。
4. `enable` 去掉 isTabVisible / overlay 条件 → `drop while settings overlay open does nothing` 变红。
5. `summarizeDrop` 扩展名比较不转小写 → `uppercase extension accepted` 变红。
6. 文件夹不判跳过、直接交给导入 → `pdf / folder / missing get the right reasons` 变红。
7. 落点直接用 `viewportToWorld(P)`、不走 `menuNodePlacement`（丢泳道）→ `drop at P … with lane` 变红。
8. onDragExited 不清悬停态 → `entered shows overlay, exited hides` 变红。
9. `ReadFailed` 后继续读文字 → `readFailed shows capsule, no node` 变红（会建文本节点）。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/features/canvas --exclude-tags golden`；逐条跑上面 9 个变异。
- 截图：`CanvasScreen`，画布有一条泳道和 1 个图像配置节点。截四张：
  1. 模拟 entered 事件、指针在空白处：浮层虚线框 +「松手导入文件 · 图片或视频 · 落在松手处」；
  2. 松手两张图后：两张导入卡处在 uploading「复制中」（fake 导入入口卡在半途）；
  3. 完成后：结果卡「已导入 2 个文件 · 跳过 1 个：notes.pdf 不是图片或视频 · 撤销」；
  4. Ctrl V 粘贴剪贴板图片后：新卡被选中，状态行显示「导入」。
- 真机冒烟（发版前）：
  - mac：Finder 拖 3 个文件；⌘⌃⇧4 截图后 ⌘V；
  - Windows：资源管理器拖入；Win+Shift+S 截图后 Ctrl V；资源管理器复制文件后 Ctrl V。

## 风险与不确定
- W3 只有带 picker 的入口 `importMediaViaPicker(context, ref, {canvasId, Offset? anchorViewport})`，没有「给路径就导入」的入口；本片在 W3 的 `canvas_import_actions.dart` 里把 picker 之后那段抽成 `importMediaFiles`（W9 无别片占用这个文件；主 Agent 已认可这次改 W3 文件），W3 的现有测试必须原样绿。W2 的 `media_import_controller.dart` 不改（不收标签，见规则 16）。
- rail-drag-characters 的角色拖放走 W4 的 `kStageDropHandlers` 注册表（stage_drop_registry.dart 追加一行），不经 canvas_view.dart；本片与它没有接线关系，也不碰那张注册表。
- Windows 以管理员身份运行时，系统 UIPI 会拦截普通权限资源管理器拖进来的文件，表现为拖不进来。这不是本片能修的，写进发版说明。
- IndexedStack 保活时，隐藏标签的盒子与可见标签重叠，desktop_drop 按盒子判命中。所以 `enable` 必须依赖 isTabVisible（规则 7 的测试守住）。
- 浮层不显示文件个数（设计缺口一），与画板的数字版不一致，需要设计确认。
