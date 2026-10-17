# export-one-click · 「导出视频」改成分体按钮：主体按上次设置一键导出，▾ 打开现有对话框
- 波次：W16；lane：E；基底：origin/main
- 依赖切片（执行时都已合入 main）：
  - export-records-table（硬依赖，W4）：建了 `export_records` 表、`lib/core/interfaces/export_record_repository.dart`、`lib/storage/repositories/postgres_export_record_repository.dart`、手写模型 `lib/features/export/models/export_record.dart`（字段有 projectId、canvasId、kind、filePath、shotCount、durationMs、sizeBytes、status、errorCode、settings、createdAt），provider 在 `lib/core/di/repositories.dart`。
  - export-records-recording → export-tab-history（W6）：`ExportController` 在成功和失败两种终态都会经 `export_history_recorder.dart` 写一条记录，取消不写；还新建了 `export_history_provider.dart` 和 `widgets/export_new_cards.dart`（「新导出」里的「拼接视频」格）。
  - export-in-task-popover（W14）：`ExportController` 的运行会进任务弹层，一键导出跟着自动进。
  - current-take（W1）：导出的默认勾选改成「每镜当前 take」。
  - app-action-table（W1）：⌘K 的动作都来自 `lib/features/app_actions/app_action_catalog.dart`。
  - toast-category-mute（软依赖，W12）：`ToastService.show` 有 `category` 参数，导出完成用「导出完成」类别。
- 阻塞决定：无。GapsPanels E1 按建议 A：没有视频的镜照样导出，完成卡上写「跳过 N 镜」。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
画布标签栏右上角的「导出视频」，以及导出标签里「拼接视频」那一格，都改成分体按钮：
- 点主体：按本画布上次成功导出的规则直接开导，过程中出一张带「取消」的进度卡，导完出完成卡；
- 点 ▾：打开现有的导出对话框。

本画布从没导出过，或者预检没过时，点主体也是打开对话框，并在对话框顶上写明原因。⌘K 里多一条「按上次设置导出视频」。

## 设计依据
画板 `GapsPanels`，小节「导出视频：按上次设置一键」：
- 画的样子：「在序列中查看 | 导出视频 ▾」。展开后的说明：「用上次设置导出 / 每镜当前 take · 叙事链序 · 时间戳名 / 自定义导出… / 上次：今天 14:20 · 8 镜 · 42 秒」。
- 「标签栏、导出标签、⌘K 改分体按钮：主体 = 按上次设置直接导出，▾ = 现有对话框；没导出过主体也开对话框。」
- 「上次设置 = 本画布最近一次成功导出的规则快照（ShellExport 的 export_records）：每镜当前 take · 顺序 · 文件名规则 · 目录；不记勾选与手动排序。」
- 「不覆盖同名，自动加「(2)」；预检不过就开对话框、原因放顶上；完成卡归导出完成。」
- E1 建议 A：「照导，完成卡写「跳过 2 镜（没有视频）」」。
- 设计缺口：图上 ▾ 下面画了一个两项的小菜单（「用上次设置导出」「自定义导出…」，外加一行「上次：…」），但规则写的是「▾ = 现有对话框」。本片按规则做：▾ 直接打开对话框；图上「上次：…」那段信息放进主体的 tooltip。
- 设计缺口：一键导出进行中按钮长什么样，画板没画。按建议：整个分体按钮置灰，进度只看进度卡和任务弹层。

## 允许改的文件
- `lib/theme/components/ink_split_button.dart`（新建）：只负责展示。左边是主体（琥珀底，样式同 `InkPrimaryButton`），中间 1px `onAccent` 半透明分隔线，右边是 ▾ 段。两段各自接收 `onTap`，传 null 时那一段降到 50% 并且不可点。这个组件不认识任何导出类型。
- `lib/features/export/util/export_file_name.dart`：新增 `uniqueOutputName`。
- `lib/features/export/util/last_export_settings.dart`（新建）：纯函数，从导出记录里挑出「本画布最近一次成功的 mp4」，并解析出规则快照。
- `lib/features/export/util/one_click_export_plan.dart`（新建）：纯函数，决定是直接导出还是打开对话框，以及算出跳过了几镜。
- `lib/features/export/providers/one_click_export_controller.dart`（新建）：`lastExportSettingsProvider` + `OneClickExportController.prepare`。
- `lib/features/export/open_export_dialog.dart`：`openExportVideoDialogForCanvas` 加可选参数 `notice`；新增 `runOneClickExportForCanvas`，三个入口都只走它这一条路。
- `lib/features/export/widgets/export_video_dialog.dart`：`showExportVideoDialog` 加可选参数 `notice`，不为 null 时在标题下面画一条说明框。
- `lib/features/shell/widgets/shell_tab_bar.dart`：画布标签上的 `exportVideoKey` 按钮（现在点了是 `nav.goTab(ShellTab.export)`）换成 `InkSplitButton`；新增 `exportVideoMenuKey`。序列标签上的「导出 mp4」不改。
- `lib/features/export/widgets/export_new_cards.dart`（由 export-tab-history 新建，W6）：「拼接视频」那一格改用 `InkSplitButton`。如果这一格当时其实留在 `lib/features/shell/widgets/tabs/export_tab.dart` 里，就改那个文件；两个文件**只改其中一个**，并在回报里说明改的是哪个。
- `lib/features/app_actions/app_action_catalog.dart`：只追加一行动作 `exportVideoLastSettings`。如果表要求 id 常量，就在 `lib/features/app_actions/app_action_ids.dart` 里也追加一行。
- 测试：`test/theme/components/ink_split_button_test.dart`（新建）、`test/features/export/util/export_file_name_test.dart`、`test/features/export/util/last_export_settings_test.dart`（新建）、`test/features/export/util/one_click_export_plan_test.dart`（新建）、`test/features/export/providers/one_click_export_controller_test.dart`（新建）、`test/features/export/widgets/export_video_dialog_test.dart`、`test/features/shell/shell_tab_bar_test.dart`。

## 不许碰的文件
- 同波 W16 其他切片的文件：
  - toast-corner：`lib/features/notifications/**`、`lib/features/settings/**`、`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`。本片**不加任何偏好**，「上次设置」只从 export_records 读。
  - assets-gallery-import-origin：`left_rail/assets_*`、`asset_hover_preview.dart`、`gallery/` 各文件。
  - note-heading-style：`typography.dart`、`node_card.dart`、`viewport_fit.dart`、`outline_model.dart` 等。
  - template-core：`lib/features/templates/**`、`canvas_bootstrap_controller.dart`。
- `lib/features/command_palette/command_actions.dart`（W18 归 more-dropdown-panel；⌘K 只走 catalog 追加一行）。
- `lib/features/export/providers/export_controller.dart`、`export_history_recorder.dart`、`delivery_controller.dart`、`lib/core/interfaces/export_record_repository.dart`：不给仓储加抽象方法，按画布挑最近一条放在内存里过滤。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W16 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - note-heading-style：`lib/features/canvas/models/canvas_node_note_style.dart`、`lib/features/canvas/providers/heading_note_zoom.dart`、`lib/features/canvas/util/drop_placement.dart`、`lib/features/canvas/util/note_geometry.dart`、`lib/features/canvas/util/selection_geometry.dart`、`lib/features/canvas/util/viewport_focus.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/node_inline_text_editor.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`lib/theme/typography.dart`、`test/features/canvas/util/drop_placement_test.dart`、`test/features/canvas/util/note_geometry_test.dart`、`test/features/canvas/util/viewport_focus_test.dart`、`test/features/canvas/widgets/node_card_note_style_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/theme/typography_test.dart`
  - template-core：`lib/features/canvas/models/canvas_command.dart`、`lib/features/canvas/providers/canvas_bootstrap_controller.dart`、`lib/features/canvas/util/sample_seed.dart`、`lib/features/templates/builtin_templates.dart`、`lib/features/templates/models/canvas_template.dart`、`lib/features/templates/providers/template_insert_controller.dart`、`lib/features/templates/util/builtin_template_strings.dart`、`lib/features/templates/util/template_capture.dart`、`lib/features/templates/util/template_remap.dart`、`lib/features/templates/util/template_writer.dart`、`test/features/templates/builtin_templates_test.dart`、`test/features/templates/providers/template_insert_controller_test.dart`、`test/features/templates/util/template_capture_test.dart`、`test/features/templates/util/template_remap_test.dart`
  - toast-corner：`lib/core/models/app_preferences.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/notifications/util/toast_placement.dart`、`lib/features/notifications/widgets/toast_layer.dart`、`lib/features/settings/providers/notification_prefs_controller.dart`、`lib/features/settings/widgets/notifications_section.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/notifications/util/toast_placement_test.dart`、`test/features/notifications/widgets/toast_layer_test.dart`、`test/features/settings/notification_prefs_controller_test.dart`、`test/features/settings/notifications_section_test.dart`
  - assets-gallery-import-origin：`assetsOfKind`、`assets_panel`、`lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`、`lib/features/canvas/widgets/left_rail/assets_model.dart`、`lib/features/canvas/widgets/left_rail/assets_panel.dart`、`lib/features/gallery/providers/gallery_filter.dart`、`lib/features/gallery/util/gallery_meta.dart`、`lib/features/gallery/widgets/gallery_filter_panel.dart`、`lib/features/gallery/widgets/gallery_tile.dart`、`lib/features/gallery/widgets/imported_badge.dart`、`test/features/canvas/widgets/left_rail/asset_captions_test.dart`、`test/features/canvas/widgets/left_rail/assets_model_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/gallery/providers/gallery_filter_test.dart`、`test/features/gallery/util/gallery_meta_test.dart`、`test/features/gallery/widgets/gallery_tile_test.dart`

## 具体改动
```dart
// export_file_name.dart
/// [base] 没被占用就原样返回，否则依次试 '$base (2)'、'$base (3)' … 到 '$base ($maxAttempts)'；全被占用返回 null。
String? uniqueOutputName(String base, bool Function(String candidate) taken, {int maxAttempts = 99});

// last_export_settings.dart
@immutable
class LastExportSettings {
  final DateTime createdAt; final int shotCount; final int? durationMs;
  final String? outputBaseName; // null = 时间戳名（服务端默认）
}
/// 只看 kind == mp4、status == 成功、canvasId == [canvasId] 的记录，取 createdAt 最新的一条；没有就返回 null。
/// 快照里的输出名不合法（isValidExportBaseName 为 false）时按时间戳名处理。
LastExportSettings? lastExportSettingsFrom(List<ExportRecord> records, {required String canvasId});

// one_click_export_plan.dart
enum OneClickBlock { neverExported, ffmpegMissing, nameExhausted }
sealed class OneClickPlan { const OneClickPlan(); }
final class OneClickReady extends OneClickPlan { final List<CanvasNode> nodes; final String? outputBaseName; final int skippedShots; }
final class OneClickNeedsDialog extends OneClickPlan { final OneClickBlock reason; }
OneClickPlan planOneClickExport({required List<CanvasNode> allNodes, required List<CanvasEdge> edges,
  required LastExportSettings? last, required bool ffmpegAvailable, required bool Function(String) nameTaken});
/// 叙事链上（orderByNarrativeChain）没有任何可导出视频产物（exportableVideoNodes + resultsFor）的镜有几个。
int countShotsWithoutVideo({required List<CanvasNode> allNodes, required List<CanvasEdge> edges});

// one_click_export_controller.dart
final lastExportSettingsProvider = FutureProvider.autoDispose.family<LastExportSettings?, String /*canvasId*/>(...);
final oneClickExportControllerProvider = AutoDisposeNotifierProvider<OneClickExportController, bool /*preparing*/>(...);
class OneClickExportController { Future<OneClickPlan> prepare({required String projectId, required String canvasId}); }

// open_export_dialog.dart
void openExportVideoDialogForCanvas(BuildContext context, WidgetRef ref, String canvasId, {String? notice});
Future<void> runOneClickExportForCanvas(BuildContext context, WidgetRef ref, String canvasId);

// ink_split_button.dart
class InkSplitButton extends StatelessWidget {
  const InkSplitButton({super.key, required this.label, required this.onPrimary, required this.onMenu,
    required this.menuSemanticLabel, this.primaryTooltip, this.menuTooltip, this.primaryKey, this.menuKey});
}
```
- 导出节点和顺序：`orderVideoNodesForExport(allNodes, edges)`，再用 current-take 之后对话框**默认勾选**的那个函数（`export_take_selection.dart`，合入后的实际名字）过滤，只留每镜当前 take。这和对话框打开时的默认状态逐项相同。
- `lastExportSettingsProvider` 的数据来源：优先从 export-tab-history 的 `export_history_provider` 派生，因为导出完成后刷新的事它已经负责了。如果它的形状不合适（例如只按项目、不能 watch），就直接读仓储，并在 `runOneClickExportForCanvas` 成功后、以及对话框导出成功关闭后，各 invalidate 一次。
- `prepare` 里各项的来源：节点和边从 `canvasNodesControllerProvider(canvasId)`、`canvasEdgesControllerProvider(canvasId)` 读 `valueOrNull`。ffmpeg 用 `ffmpegLocatorProvider.locate()` 看结果是否为 null。名字是否被占用：`fileResolverServiceProvider.resolveInProject(projectId:, relativePath: 'exports/$name.mp4').existsSync()`，遇到 `PathSecurityError` 当作被占用。
- 判断顺序：没有 last → `neverExported`；ffmpeg 不可用 → `ffmpegMissing`；last 有名字但 `uniqueOutputName` 返回 null → `nameExhausted`；其余都是 `OneClickReady`。名字为 null 时（时间戳名）不检查是否占用。
- `runOneClickExportForCanvas` 的流程：
  1. 外壳没有项目上下文、`exportControllerProvider` 正忙、或没有可导出的视频时，静默返回。
  2. 调 `prepare`。结果是 `NeedsDialog` 时，打开对话框，并把原因文案作为 `notice` 传进去。
  3. 结果是 `Ready` 时：先把 toast、navigator、l10n、resolver 都取好，再弹进度卡。进度卡是 `ToastKind.progress`，类别是导出完成，secondary 是「取消」，点了调用 `exportControllerProvider.notifier.cancelExport()`；进度不显示比例。
  4. 然后 `await ExportController.export(...)`，参数照对话框 `_onExport` 的传法，包括 export-records-recording 加的设置快照参数；`outputBaseName` 传本次实际用的名字。
  5. 读终态：
     - 成功：`handle.complete(success, title: 已导出 <文件名>, body: skipped > 0 ? 跳过 N 镜（没有视频） : null, primary: 打开文件夹 → folderOpenerProvider 打开 exports 目录的绝对路径, chime: true)`；
     - 失败：`complete(error, title: 导出失败, body: 本地化错误, primary: 自定义导出… → context.mounted 时打开对话框)`；
     - 取消（Idle）：`handle.dismiss()`，什么记录都不写（recorder 已经保证了）。
- `shell_tab_bar.dart` 画布分支：
  - 主体的 onTap：`canExport && !busy` 时是 `runOneClickExportForCanvas`，否则为 null。`canExport` 是 `canExportVideo` 加上 `project != null`，和序列分支同口径；`busy` 读 `exportControllerProvider is ExportVideoBusy`。
  - ▾ 的 onTap：可导出且不忙时是 `openExportVideoDialogForCanvas`，否则为 null。
  - 主体 tooltip：有 last 时写规则加「上次：…」；没有 last 时写「还没导出过，点了打开导出设置」；不可点时写第一条阻断原因（复用 `exportVideoNoResultsTooltip` / `exportVideoNoProjectTooltip`）。
  - 画布标签挂着时边控制器本来就有人订阅；导出标签那一格要保留 export_tab 现在那段「必须显式订阅边控制器」的写法和注释。

## 行为规则与边界情况
1. 本画布从没成功导出过 mp4（失败的、交付、pdf、zip 记录都不算）时，点主体打开对话框，顶上写「这张画布还没导出过，先在这里设一次」。
2. 上次的输出名是「示例」，而 `exports/示例.mp4` 已经存在时，这次导出成「示例 (2)」；「(2)」也存在就用「(3)」。永远不覆盖已有文件。
3. 上次是时间戳名（快照里没有名字）时，这次也让服务生成时间戳名，不加「(n)」。
4. 一直排到「(99)」都被占用时，打开对话框，原因写「同名文件太多，请换个名字」。
5. 找不到 ffmpeg 时，打开对话框，原因写「找不到 ffmpeg」；对话框里照常可以操作（它自己的失败条也会再报一次）。
6. 叙事链上有 2 镜没有视频时，照常导出其余的镜，完成卡写「跳过 2 镜（没有视频）」；全部都有视频时不写这一行。
7. 一键导出进行中：标签栏和导出标签上的分体按钮整体不可点；对话框里的导出也被 `isBusy` 挡住（现有逻辑）。
8. 点进度卡上的「取消」：ffmpeg 被杀掉，进度卡收起，不出失败卡，不写导出历史。
9. 导出失败：出错误卡（不自动消失），导出历史写一条失败记录（由 recorder 完成）；卡上的「自定义导出…」打开对话框。
10. 「上次设置」不记勾选和手动排序：哪怕上次在对话框里手动取消了某一镜、调过顺序，一键导出仍然是「每镜当前 take + 叙事链序」。
11. 导出成功后，tooltip 里的「上次：…」马上变成刚才这一次（provider 已失效重算）。
12. 外壳切到别的画布后，按钮读的是新画布自己的上次设置，不会串画布。
13. Windows 和 macOS 的行为一样。「打开文件夹」走 `folderOpenerProvider`，它已经处理了平台差异。

## 新文案键
| key | en | zh |
|---|---|---|
| exportOneClickMenuTooltip | Custom export… | 自定义导出… |
| exportOneClickTooltip | Export with last settings: current take per shot · narrative order · {nameRule}. Last: {when} · {shots} shots · {duration} | 用上次设置导出：每镜当前 take · 叙事链序 · {nameRule}。上次：{when} · {shots} 镜 · {duration} |
| exportOneClickNameTimestamp | timestamp name | 时间戳名 |
| exportOneClickNameCustom | name “{name}” | 名称「{name}」 |
| exportOneClickNeverTooltip | Not exported yet — opens export settings | 还没导出过，点了打开导出设置 |
| exportOneClickNoticeNever | This canvas hasn't been exported yet. Set it up once here. | 这张画布还没导出过，先在这里设一次。 |
| exportOneClickNoticeFfmpeg | ffmpeg not found, so one-click export can't run. | 找不到 ffmpeg，没法一键导出。 |
| exportOneClickNoticeNames | Too many files with the same name. Choose another name. | 同名文件太多，请换个名字。 |
| exportOneClickRunning | Exporting video… | 正在导出视频… |
| exportOneClickDone | Exported {fileName} | 已导出 {fileName} |
| exportOneClickSkipped | Skipped {count} shots (no video) | 跳过 {count} 镜（没有视频） |
| exportOneClickFailed | Export failed | 导出失败 |
| exportOneClickOpenFolder | Open folder | 打开文件夹 |
| exportOneClickCancel | Cancel | 取消 |
| appActionExportVideoLastSettings | Export video with last settings | 按上次设置导出视频 |
（`{when}` 复用 `galleryTimeAgo`；`{duration}` 用 duration-format 的统一时长函数。如果已有通用的「取消」「打开文件夹」键，就复用，不新增。）

## 测试
先写下面这些用例，确认它们失败后再实现。
- `export_file_name_test.dart`：
  - `uniqueOutputName：没占用原样返回`
  - `占用 base 与 (2) → 返回 (3)`
  - `全部占用 → null`
  - `结果仍通过 isValidExportBaseName`
- `last_export_settings_test.dart`：
  - `只取本画布最新的成功 mp4（跳过失败 / delivery / 别的画布 / 更旧的）`
  - `快照无名或名不合法 → outputBaseName 为 null`
  - `没有记录 → null`
- `one_click_export_plan_test.dart`：
  - `last 为 null → NeedsDialog(neverExported)`
  - `ffmpeg 不可用 → ffmpegMissing`
  - `名字被占 → Ready 且名为「x (2)」`
  - `时间戳名不查占用`
  - `节点 = 每镜当前 take、叙事链序（同一镜两个 take 只取当前那个）`
  - `countShotsWithoutVideo：链上 3 镜其中 1 镜只有图 → 1`
- `one_click_export_controller_test.dart`（假仓储 + 假 FfmpegLocator + 临时目录里的 FileResolverService + 假 VideoExportService）：
  - `prepare 读到上次记录并在 exports/ 已有同名时加 (2)`
  - `prepare 无记录 → neverExported`
- `ink_split_button_test.dart`：
  - `点主体只触发 onPrimary、点 ▾ 只触发 onMenu`
  - `onPrimary 为 null 时主体不可点、▾ 仍可点`
- `export_video_dialog_test.dart`：
  - `notice 不为空时标题下出现说明文本；为空时不出现`
- `shell_tab_bar_test.dart`：
  - `画布标签：exportVideoKey 是分体按钮主体，没导出过时点它弹出对话框且带「还没导出过」说明`
  - `点 exportVideoMenuKey 直接弹对话框且没有说明`
  - `没有可导出视频时两段都不可点`

## 变异点
1. `uniqueOutputName` 改成直接返回 base，会被 `占用 base 与 (2) → 返回 (3)` 和 `prepare … 加 (2)` 抓住。
2. `lastExportSettingsFrom` 不过滤 status（失败的也算）或不过滤 canvasId，都会被 `只取本画布最新的成功 mp4…` 抓住。
3. `planOneClickExport` 用全部 take 而不是默认勾选集，会被 `节点 = 每镜当前 take…` 抓住。
4. `planOneClickExport` 去掉 `last == null` 的分支，会被 `last 为 null → NeedsDialog(neverExported)` 和 `shell_tab_bar` 第一条抓住。
5. `countShotsWithoutVideo` 恒返回 0，会被 `countShotsWithoutVideo：…→ 1` 抓住。
6. `shell_tab_bar` 里 ▾ 也调 `runOneClickExportForCanvas`，会被 `点 exportVideoMenuKey 直接弹对话框且没有说明` 抓住。
7. `InkSplitButton` 两段共用一个 onTap，会被 `点主体只触发 onPrimary…` 抓住。

## 验收
- 主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/export test/features/shell test/theme/components`，并按上面每条变异做一次。
- 截图场景：用 `ShellTabBar` 的画布分支（参照 shell_tab_bar_test 的搭法），数据是 1 个项目、1 张画布、3 镜视频产物。截四种状态：有上次记录时悬停主体显示 tooltip；没有可导出视频（置灰）；导出进行中（置灰）；导出对话框带「还没导出过」说明。
- 另外用 `ToastLayer` 截一张完成卡，带「跳过 2 镜（没有视频）」和「打开文件夹」。

## 风险与不确定
- ▾ 的行为：规则写的是「▾ = 现有对话框」，图上画的是两项小菜单，本片按规则做。如果主 Agent 要按图做菜单，需要用 menu-split 的 ink_menu_panel 在 `shell_tab_bar` 里多挂一个浮层，工作量会增加。
- export-records-recording 写快照时用的键名（输出名那一项）在本片写作时看不到。`lastExportSettingsFrom` 必须按它合入后的实际键名读；如果快照里压根没存输出名，就一律当作时间戳名，并在回报里写明。
- `ExportRecord.kind` 和 `status` 的字面量（`'mp4'`、成功态的写法）以 export-records-table 的实际常量为准，必须引用它的常量，不要写死。
- 文件名「(2)」只检查 `exports/` 目录里是否已有同名文件；同一时刻对话框和一键导出抢同一个名字的情况，会被 `ExportController.isBusy` 挡住，不会同时跑两个导出。
- toast-category-mute 的类别枚举名以实际代码为准；如果它没有合入，`category` 参数就不传。
