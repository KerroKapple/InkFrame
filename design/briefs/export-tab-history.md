# export-tab-history · 导出标签重做：「新导出」五格 + 「导出历史」列表
- 波次 W6 / lane E 第二片 / 基底：叠在 export-records-recording 之后（origin/main〔W0–W5 已合入〕+ export-records-recording）
- 依赖切片：export-records-table（W4：`ExportRecordRepository` / `exportRecordRepositoryProvider` / `ExportRecord` / `ExportKind` / `ExportRecordStatus` / `FakeExportRecordRepo`）、export-records-recording（W6：`export_snapshot.dart` 的读取函数、`exportHistoryRevisionProvider`、`RecordingExportHistoryRecorder`）、menu-split（W0：`InkMenuPanel` / `InkMenuEntry`、`CanvasMenuPopover`）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
导出标签不再只有居中一颗「导出视频」按钮：左边「新导出」一列五格（拼接视频 / 交付包 / 分镜 PDF / 图片 ZIP / 剪映草稿·FCPXML），右边「导出历史」列表，可切「全部 / 本画布」。每行能打开文件夹、重新导出或重试；文件已经不在的划掉；右键一行出「打开文件 · 复制路径 · 从历史移除」。

## 设计依据
- ShellExport.dc.html「导出第二批」（b2_shell.js 第 261–335 行 `exportTab` / `fmtRow` / `histRow`）：
  - 左列「新导出」：拼接视频（mp4 · 现有对话框，默认高亮）、交付包（EDL + 媒体 · 序列标签）、分镜 PDF（每页 6 镜，「新」）、图片 ZIP（每镜选定产物，「新」）、剪映草稿（FCPXML 同，「待支持」灰）。行高 32、图标 16。
  - 右侧头：「导出历史」+ 胶囊「全部 / 本画布」。行高 32：图标 14 | 文件名（等宽 10.5）+ 副行（9.5）| 时间（宽 58，右对齐）| 动作（宽 56，accent 色）。
  - 四种行：成功 mp4「示例项目_画布1.mp4 / 画布 1 · 8 镜 · 00:42 · 38.2 MB / 今天 14:20 / 打开文件夹」；交付「示例项目.edl + 8 mp4 / 交付 · Resolve · 1 处占位」；文件不在「划线 + 文件不在了 / 重新导出」；失败「error 图标 danger 色 / 失败 · 找不到 ffmpeg / 重试」。
  - 底注：右键一行：打开文件 · 复制路径 · 从历史移除（不删文件）。
  - 规则 2：文件不在了就划掉，只给「重新导出」。规则 4：剪映草稿 / FCPXML 灰着写「待支持」，可选性只问 `DeliveryWriterRegistry`，接上写出器当场可选。
- ShellExport-Q3 按建议 A：一直留，用户手动「从历史移除」。
- slices.json notes：PDF / ZIP 两格在各自切片（image-zip-export W15、storyboard-pdf-export W18）合入前置灰，原因写清楚；保留现在的禁用 tooltip 判据（hasVideoResult / hasProject）和必须订阅边控制器那段注释；「重新导出」用行里的设置快照重新走对应路径。
- 设计缺口（本片的处理写在规则里）：①没有画布时整页空态（沿用现有 ShellEmptyState，不画历史）；②历史为空 / 本画布为空 / 读取失败 / 加载中四个状态没画；③「从历史移除」没有撤销；④交付行「重新导出」在哪儿交付没画（定为跳到序列标签的交付面板，因为交付前检查只在那里）；⑤来源画布已删除的行怎么显示没画；⑥行的键盘可达（右键菜单的键盘入口）没画。

## 允许改的文件
- `lib/features/shell/widgets/tabs/export_tab.dart`：整体改成「新导出列 | 历史」两栏；保留第 25–36 行空态、第 37–50 行两条判据与第 44–50 行边控制器订阅（含原注释原样搬）。
- 新 `lib/features/export/widgets/export_new_cards.dart`：`ExportNewCards` + `ExportNewCell` + `ExportFormatsLanded`。
- 新 `lib/features/export/widgets/export_history_list.dart`：头 + 列表 + 四个空/错/载状态 + 标签可见边刷新。
- 新 `lib/features/export/widgets/export_history_row.dart`：一行 + 右键菜单。
- 新 `lib/features/export/providers/export_history_provider.dart`：`ExportHistoryEntry`、`exportHistoryProvider`、`exportHistoryScopeProvider`、`filterExportHistory`、`removeExportRecord`。
- 新 `lib/features/export/util/export_history_format.dart`：行文案拼装的纯函数（时间、大小、文件名、副行）。
- 新 `lib/features/export/models/export_dialog_preset.dart`：`ExportDialogPreset` + `applyExportPreset` 纯函数。
- 新 `lib/features/export/re_export.dart`：`reExportFromRecord` + 按 kind 分派的表（后续 PDF / ZIP 片各追加一行）。
- 新 `lib/features/export/export_history_keys.dart`：测试锚点 Key（照 delivery_keys.dart）。
- `lib/features/export/open_export_dialog.dart`：`openExportVideoDialogForCanvas(context, ref, canvasId, {ExportDialogPreset? preset})`，把 preset 透传。
- `lib/features/export/widgets/export_video_dialog.dart`：`showExportVideoDialog(..., ExportDialogPreset? preset)`；`initState`（现第 77–83 行）有 preset 时用 `applyExportPreset` 定 `_rows` / `_selected`，`_nameCtrl.text = preset.outputBaseName ?? ''`。其余不动。
- `lib/features/export/models/delivery_writer_registry.dart`：**不改**（只经 `deliveryWriterRegistryProvider` 读 `supports`）。列在这里是因为 slices.json 把它登记给了本片。
- 测试：新 `test/features/shell/tabs/export_tab_test.dart`、新 `test/features/export/widgets/export_history_list_test.dart`、新 `test/features/export/providers/export_history_provider_test.dart`、新 `test/features/export/util/export_history_format_test.dart`、新 `test/features/export/models/export_dialog_preset_test.dart`、新 `test/features/export/widgets/export_video_dialog_preset_test.dart`（preset 用例单独成文件；`export_video_dialog_test.dart` 同波已归 export-records-recording，本片不改它）、`test/features/shell/shell_tabs_empty_state_test.dart`（「导出标签」组的 `_cta` / `_tooltip` 改按 Key 找格子；`_pumpExport` 加 overrides）。

## 不许碰的文件
- W6 其他 lane（同 export-records-recording 所列）：snapping、cm-edge-menu、cm-delete-bridge、undo-lanes 的全部文件，尤其 `canvas_menu_host.dart`、`canvas_menu_request.dart`、`menu_registry.dart`（W6 有两片各追加一行，本片不加）、`canvas_view.dart`、`shortcuts/core_canvas_keys.dart`、`canvas_tool_actions.dart`、`canvas_snackbars.dart`；以及 `theme/components/ink_menu_panel.dart`（W6 cm-edge-menu 在加 `note`，本片只用不改）。
- menu-split 的 `lib/theme/components/ink_menu_panel.dart` 与 `CanvasMenuPopover` 所在文件：只用不改。
- `lib/features/shell/widgets/shell_content_stack.dart`（不给 ExportTab 加 isVisible 参数——可见性自己从 ShellState 读）、`shell_tab_bar.dart`（标签栏右侧「导出视频」按钮不动）。
- `delivery_controller.dart` / `export_controller.dart` / `export_history_recorder.dart`（上一片已定稿，本片只读）。

## 具体改动

### export_new_cards.dart
```dart
/// 各格式是否已落地。PDF / ZIP 由各自切片把 false 改成 true（一行）。
abstract final class ExportFormatsLanded { static const bool storyboardPdf = false; static const bool imageZip = false; }
enum ExportNewKind { mp4, delivery, pdf, zip, nleDraft }
class ExportNewCell extends StatelessWidget {
  const ExportNewCell({super.key, required this.glyph, required this.label, required this.sub,
    required this.tooltip, this.onTap, this.tag, this.selected = false});
  final InkGlyph glyph; final String label; final String sub; final String tooltip;
  final VoidCallback? onTap; // null = 置灰
  final String? tag;          // 「待支持」
  final bool selected;        // 拼接视频默认 surface5 底
}
class ExportNewCards extends ConsumerWidget {
  const ExportNewCards({super.key, required this.canvasId, required this.hasVideoResult, required this.hasProject});
}
```
五格（glyph · 标签 · 副行 · 可点条件 · 点了做什么 · tooltip）：
1. `InkGlyph.export` · exportNewConcatLabel · exportNewConcatSub · `hasVideoResult && hasProject` · `openExportVideoDialogForCanvas(context, ref, canvasId)` · 判据与文案**原样沿用**现 export_tab.dart 第 55–61 行：`!hasVideoResult ? exportVideoNoResultsTooltip : !hasProject ? exportVideoNoProjectTooltip : exportVideoReadyTooltip`。
2. `InkGlyph.sequence` · exportNewDeliveryLabel · exportNewDeliverySub · `hasProject` · `shellControllerProvider.notifier.goTab(ShellTab.sequence)` · 可点 exportNewDeliveryTooltip / 不可点 exportVideoNoProjectTooltip。
3. `InkGlyph.script` · exportNewPdfLabel · exportNewPdfSub · `ExportFormatsLanded.storyboardPdf && hasProject` · 本片无动作（null）· exportNewPdfPendingTooltip；tag = exportNewSoonTag。
4. `InkGlyph.imageConfig` · exportNewZipLabel · exportNewZipSub · `ExportFormatsLanded.imageZip && hasProject` · 同上 · exportNewZipPendingTooltip。
5. `InkGlyph.more` · exportNewNleDraftLabel · exportNewNleDraftSub · `hasProject && (registry.supports(DeliveryTarget.jianying) || registry.supports(DeliveryTarget.finalCut))`，registry = `ref.watch(deliveryWriterRegistryProvider)` · 点了：取第一个受支持的目标（先 jianying 后 finalCut），`deliverySettingsProvider(projectId).notifier.save(current.copyWith(target: t))`，再 `goTab(ShellTab.sequence)` · 不可点 exportNewNleDraftPendingTooltip + tag exportNewSoonTag。
样式：列宽常量 `kExportNewColumnWidth = 220`，底 `surface3`，右边框 `borderStrong`；小标题「新导出」`micro` + `fg5`；格高 32，图标 16（`InkIcon`），标签 `body`（禁用 `fg6`），副行 `nano` + `fg6`；全部走 token（test/quality/no_inline_styles_test.dart）。

### export_history_provider.dart
```dart
enum ExportHistoryScope { all, canvas }
final exportHistoryScopeProvider = NotifierProvider<ExportHistoryScopeController, ExportHistoryScope>(…); // 默认 all，app 内存态，不落库
@immutable
class ExportHistoryEntry {
  final ExportRecord record;
  final String? absolutePath;   // outputPath 经 resolveInProject；越界 / 无路径 → null
  final bool fileExists;        // 只对有 absolutePath 的行查 File.exists()
  final String? canvasName;     // 来自 workspaceProjectsProvider；画布已删 → null
  bool get isGone => record.status == ExportRecordStatus.succeeded && !fileExists;
  bool get canvasAlive => canvasName != null;
}
final exportHistoryProvider = FutureProvider.autoDispose.family<List<ExportHistoryEntry>, String>((ref, projectId) async {
  ref.watch(exportHistoryRevisionProvider);
  … repo.listByProject → ExportRecord.fromRow（null 跳过）→ 查文件 + 配画布名
});
List<ExportHistoryEntry> filterExportHistory(List<ExportHistoryEntry> all, ExportHistoryScope scope, String? currentCanvasId);
/// 从历史移除：只删行不删文件；成功 bump revision；InkError → 交给调用方弹错误卡。
Future<void> removeExportRecord(WidgetRef ref, String recordId);
```

### export_history_format.dart（纯函数，便于单测）
```dart
String exportHistoryWhen(AppLocalizations l, DateTime atLocal, DateTime nowLocal); // 同日「今天 HH:mm」/ 前一日「昨天」/ 更早「M月d日」
String formatExportSize(int bytes);       // B / KB / MB / GB，一位小数；单位不进 ARB（同 backup_section.dart 第 144 行注释）
String exportHistoryFileLabel(AppLocalizations l, ExportRecord r); // mp4：outputPath 末段，失败无路径时 snapshotOutputBaseName + '.mp4'，再没有就 exportNewConcatLabel；delivery：exportHistoryDeliveryFiles(projectFile, mediaCount)，mediaCount 为 0 只写 projectFile
String exportHistorySubLabel(AppLocalizations l, ExportHistoryEntry e); // 见规则 3–6
```
时长用 duration-format（W0）的 `formatDurationLabel(AppLocalizations l, int ms)`（`lib/l10n/duration_format.dart`；<60 秒写「N 秒」，<1 小时 m:ss，否则 h:mm:ss——全仓统一这一套分档，不另做 mm:ss；板上「00:42」按它显示为「42 秒」）。分隔符 ` · ` 用 `parts.join(' · ')`，不做「字面量前缀 + l10n 插值」（test/quality/no_magic_strings_test.dart）。

### export_dialog_preset.dart
```dart
@immutable
class ExportDialogPreset {
  const ExportDialogPreset({required this.nodeIds, this.outputBaseName});
  factory ExportDialogPreset.fromSnapshot(Map<String, Object?> s); // snapshotNodeIds / snapshotOutputBaseName
  final List<String> nodeIds; final String? outputBaseName;
}
/// 预设里还在的节点按预设顺序排前面，其余按原顺序接在后面；预选 = 预设 ∩ 现有。
({List<CanvasNode> rows, Set<String> selected}) applyExportPreset(List<CanvasNode> rows, ExportDialogPreset preset);
```

### re_export.dart
```dart
typedef ReExportHandler = Future<void> Function(BuildContext context, WidgetRef ref, ExportHistoryEntry entry);
/// 按 kind 分派；pdf / zip 由各自切片追加一行。
final Map<ExportKind, ReExportHandler> kReExportHandlers = <ExportKind, ReExportHandler>{
  ExportKind.mp4: _reExportMp4,
  ExportKind.delivery: _reExportDelivery,
};
bool canReExport(ExportHistoryEntry e); // canvasAlive && kReExportHandlers.containsKey(kind)
Future<void> reExportFromRecord(BuildContext context, WidgetRef ref, ExportHistoryEntry entry);
```
- `_reExportMp4`：行的画布不是当前画布 → `openCanvas(canvasId)` 再 `goTab(ShellTab.export)`；然后对 `canvasNodesControllerProvider(id)` 与 `canvasEdgesControllerProvider(id)` 各 `ref.listenManual` 一个临时订阅撑住 autoDispose，`await` 两个 `.future`，关订阅（与 sequence/util/view_in_sequence.dart「临时订阅撑过一帧」同一个理由——不撑住边控制器，`orderVideoNodesForExport` 会静默退化成非链序）；`context.mounted` 再检查；`applyExportPreset` 后预选为空 → `toastServiceProvider` 弹 info `exportHistoryPresetMissing` 并不带 preset 打开；否则 `openExportVideoDialogForCanvas(context, ref, id, preset: …)`。
- `_reExportDelivery`：必要时先 `openCanvas(canvasId)`，然后 `goTab(ShellTab.sequence)`（交付前检查只在交付面板）。不改用户当前的交付设置。

### export_history_list.dart / export_history_row.dart
```dart
class ExportHistoryList extends ConsumerStatefulWidget { const ExportHistoryList({super.key, required this.projectId, required this.canvasId}); }
class ExportHistoryRow extends ConsumerWidget { const ExportHistoryRow({super.key, required this.entry, required this.onAction, required this.busy}); }
```
- 头高 30（`borderStrong` 下沿）：「导出历史」`bodyStrong` + 右侧两个胶囊（选中 `surface5` 底 + `fg1`，未选 `fg4`），Key 见 export_history_keys.dart。
- `ref.listen(shellControllerProvider.select((s) => s.isTabVisible(ShellTab.export)), …)`：false → true 时 `ref.invalidate(exportHistoryProvider(projectId))`（重新查文件在不在）。
- 列表 `ListView.builder`；行右键：`onSecondaryTapUp` 在抬起时开 `CanvasMenuPopover`（menu-split 新建），锚在 `details.globalPosition`，内容 `InkMenuPanel<_RowMenu>(width: InkMenuPanel.blankWidth, groups: [[打开文件, 复制路径], [从历史移除]], …)`。
- 动作列一个文字按钮（accent，`meta`）：成功且在 → `deliveryOpenFolder`；`isGone` → `exportHistoryReExport`；失败 → `deliveryRetry`。不可重新导出时置灰并挂 tooltip。
- 正在跑一次重新导出时（State 里一个 `_reExporting` 标记），所有行的动作按钮不响应。

## 行为规则与边界情况
1. 没有当前画布 → 整页仍是现有空态（`shellCanvasEmptyTitle` / `shellExportEmptyBody` / 去工作室），不画历史。
2. 有画布无项目上下文 → 五格按判据置灰；历史区显示 `deliveryNoProject`，不读仓储。
3. 成功 mp4 副行 = `画布名 · N 镜 · 时长 · 大小`，缺的段省略；画布已删写 `exportHistoryCanvasDeleted`。
4. 交付副行 = `交付 · <目标软件> · N 处占位`（目标软件走 `deliveryTargetLabel`，占位为 0 省略该段；快照解不出设置时省略目标段）。
5. 文件不在（成功行、`File.exists()` 为 false）→ 文件名加删除线、`fg6`；副行 `exportHistoryFileGone`；动作只有「重新导出」。
6. 失败行 → 图标 `InkGlyph.error` + `danger`；副行 `exportHistoryFailed(reason)`，reason：`error_reason == 'ffmpeg_not_found'` → `exportHistoryReasonFfmpegMissing`，否则 `l10nErrorCode(context, InkErrorCode.fromWire(error_code))`；动作「重试」= 与「重新导出」同一条路。
7. 时间列：本地时间同日「今天 14:20」、前一天「昨天」、更早「10月3日」；「现在」取 `clockProvider.nowUtc().toLocal()`。
8. 默认「全部」；「本画布」只留 `record.canvasId == currentCanvasId` 的行；切画布后「本画布」跟着换。
9. 空态：全部为空 → `exportHistoryEmpty`；本画布为空 → `exportHistoryEmptyCanvas`；加载中 → 只画头不画行；读取失败 → `l10nAsyncError` 文案一行。
10. 「打开文件夹」→ `folderOpenerProvider.open(p.dirname(absolutePath))`；「打开文件」→ `folderOpenerProvider.open(absolutePath)`（macOS `open` / Windows `explorer` 传文件即用默认程序打开）；两者都 `.ignore()` 失败（同 delivery_panel.dart 第 249 行）。文件不在时「打开文件」置灰。
11. 「复制路径」→ `Clipboard.setData(absolutePath)` + info 卡 `exportVideoPathCopied`；无路径（失败行）置灰。
12. 「从历史移除」→ 硬删这一行、文件不动；成功 info 卡 `exportHistoryRemoved`，列表即刻少一行（revision +1）；写库失败 → error 卡（`l10nError`），行还在。无撤销（设计缺口③）。
13. 「重新导出 / 重试」mp4：打开现有对话框，镜头按快照顺序排前、预选快照里还在的镜头、输出名预填；同名文件已存在时对话框照旧给覆盖警示。快照镜头全没了 → info 卡 `exportHistoryPresetMissing`，按当前默认打开。行的画布不是当前画布 → 先切到那个画布（停在导出标签），等节点与边都加载好再开。
14. 「重新导出 / 重试」交付：切到该画布的序列标签（交付面板），按钮 tooltip `exportHistoryDeliveryRerunTooltip`。
15. 来源画布已删（画布名为 null）→ 「重新导出 / 重试」置灰，tooltip `exportHistoryCanvasGoneTooltip`；「打开文件夹 / 打开文件 / 复制路径 / 移除」照常。
16. 剪映 / FCPXML 格：registry 里有对应写出器就当场可点（测试 override registry 自证），否则灰 + 「待支持」。
17. 导出完成后回到导出标签：recording 片 bump revision ⇒ 新行出现在最上面，不用切标签。
18. mac / Windows 差异只有规则 10 的系统命令（已由 SystemFolderOpener 处理）；右键菜单两边都在抬起时开。

## 新文案键
| key | en | zh |
|---|---|---|
| exportNewTitle | New export | 新导出 |
| exportNewConcatLabel | Joined video | 拼接视频 |
| exportNewConcatSub | mp4 · joined in narrative order | mp4 · 按叙事链拼接 |
| exportNewDeliveryLabel | Delivery package | 交付包 |
| exportNewDeliverySub | EDL + media · Sequence tab | EDL + 媒体 · 序列标签 |
| exportNewDeliveryTooltip | Open the delivery panel in the Sequence tab | 打开序列标签里的交付面板 |
| exportNewPdfLabel | Storyboard PDF | 分镜 PDF |
| exportNewPdfSub | 6 shots per page | 每页 6 镜 |
| exportNewPdfPendingTooltip | Storyboard PDF isn't available yet — it ships in a later update | 分镜 PDF 还没接上，会在后续版本提供 |
| exportNewZipLabel | Image ZIP | 图片 ZIP |
| exportNewZipSub | Chosen take per shot | 每镜选定产物 |
| exportNewZipPendingTooltip | Image ZIP isn't available yet — it ships in a later update | 图片 ZIP 还没接上，会在后续版本提供 |
| exportNewNleDraftLabel | Jianying draft / FCPXML | 剪映草稿 / FCPXML |
| exportNewNleDraftSub | Picked in the delivery panel | 在交付面板里选目标软件 |
| exportNewNleDraftPendingTooltip | Jianying draft and FCPXML writers aren't available yet | 剪映草稿和 FCPXML 的写出器还没接上 |
| exportNewSoonTag | Pending | 待支持 |
| exportHistoryTitle | Export history | 导出历史 |
| exportHistoryScopeAll | All | 全部 |
| exportHistoryScopeCanvas | This canvas | 本画布 |
| exportHistoryEmpty | No exports yet. Exported videos and deliveries will appear here. | 还没有导出记录。导出视频或交付后会出现在这里。 |
| exportHistoryEmptyCanvas | No exports from this canvas yet. | 这个画布还没有导出记录。 |
| exportHistoryShots | {count} shots | {count} 镜 |
| exportHistoryPlaceholders | {count} placeholders | {count} 处占位 |
| exportHistoryDeliveryKind | Delivery | 交付 |
| exportHistoryDeliveryFiles | {file} + {count} mp4 | {file} + {count} mp4 |
| exportHistoryFileGone | File no longer exists | 文件不在了 |
| exportHistoryFailed | Failed · {reason} | 失败 · {reason} |
| exportHistoryReasonFfmpegMissing | ffmpeg not found | 找不到 ffmpeg |
| exportHistoryCanvasDeleted | Deleted canvas | 已删除的画布 |
| exportHistoryToday | Today {time} | 今天 {time} |
| exportHistoryYesterday | Yesterday | 昨天 |
| exportHistoryDate | {month}/{day} | {month}月{day}日 |
| exportHistoryReExport | Export again | 重新导出 |
| exportHistoryOpenFile | Open file | 打开文件 |
| exportHistoryRemove | Remove from history | 从历史移除 |
| exportHistoryRemoved | Removed from history (the file is kept) | 已从历史移除（文件还在） |
| exportHistoryCanvasGoneTooltip | The source canvas was deleted, so this can't be exported again | 来源画布已删除，无法重新导出 |
| exportHistoryDeliveryRerunTooltip | Opens the delivery panel — check the settings, then deliver again | 打开交付面板，确认设置后再交付 |
| exportHistoryPresetMissing | The shots used last time are gone — preselected from the current sequence | 上次用到的镜头都不在了，已按当前序列预选 |

复用现有键：`exportVideoReadyTooltip` / `exportVideoNoResultsTooltip` / `exportVideoNoProjectTooltip`、`deliveryOpenFolder`、`deliveryCopyPath`、`deliveryRetry`、`exportVideoPathCopied`、`deliveryNoProject`、`sequenceTarget*`（经 deliveryTargetLabel）。

## 测试
- `test/features/export/util/export_history_format_test.dart`：`同日 → 今天 HH:mm`、`前一日 → 昨天`、`跨月更早 → M月d日`（zh 与 en 各一条）；`formatExportSize：1023 B / 1.0 KB / 38.2 MB / 2.0 GB`；`mp4 文件名取路径末段`；`失败无路径 → 输出名 + .mp4，再没有 → 拼接视频`；`交付文件名「x.edl + 8 mp4」，0 个媒体只写 x.edl`；`交付副行省略 0 处占位`。
- `test/features/export/models/export_dialog_preset_test.dart`：`预设顺序在前、其余按原序在后`；`预设里已删除的 id 被跳过`；`预选 = 预设 ∩ 现有`；`全不在 → selected 为空`。
- `test/features/export/providers/export_history_provider_test.dart`（ProviderContainer；FakeExportRecordRepo、临时目录 resolver、workspaceProjectsProvider override）：`成功行文件在 → fileExists true`；`文件删掉 → isGone`；`失败行不查文件`；`画布不在工作区列表 → canvasName null`；`坏行（未知 kind）跳过`；`bump revision 后重新读库`；`filterExportHistory 本画布只留当前画布`；`removeExportRecord 删行 + revision +1`；`removeExportRecord 写库失败抛 InkError、revision 不变`。
- `test/features/export/widgets/export_history_list_test.dart`（pumpInkApp，zh；overrides：shellControllerProvider 带 project p1 / canvas c1、FakeExportRecordRepo 预置四行（板上四种）、RecordingToastService、记录调用的 FakeFolderOpener、临时目录 resolver、FakeClock、workspaceProjectsProvider）：
  - `四种行文案与动作`：成功 mp4 行出「打开文件夹」；交付行副行含「交付 · Resolve · 1 处占位」；文件不在的行文件名 `TextDecoration.lineThrough` 且动作是「重新导出」；失败行副行「失败 · 找不到 ffmpeg」且动作「重试」。
  - `本画布只留当前画布的行`；`全部为空 → 空态文案`；`本画布为空 → 本画布空态文案`。
  - `打开文件夹 → FolderOpener 收到目录路径`。
  - `右键 → 菜单三项；文件不在时「打开文件」置灰`；`复制路径 → 剪贴板 + 已复制卡`。
  - `从历史移除 → 行消失、文件还在、出「已从历史移除」卡`；`移除失败 → 行还在、出错误卡`。
  - `来源画布已删 → 重新导出置灰 + tooltip`。
  - `标签由不可见变可见 → 重新查文件`：先可见、删文件、切到别的标签再切回 → 该行变为划线。
- `test/features/shell/tabs/export_tab_test.dart`：`五格都在且顺序为 拼接视频 / 交付包 / 分镜 PDF / 图片 ZIP / 剪映草稿`；`PDF 与 ZIP 置灰 + 待支持 + 各自 tooltip`；`registry 多一个 jianying-draft 写出器 → 剪映格可点，点了把目标存成 jianying 并切到序列标签`（override deliveryWriterRegistryProvider + InMemoryProjectRepository）；`交付包 → 切到序列标签`；`无项目 → 交付包置灰`。
- `test/features/shell/shell_tabs_empty_state_test.dart`「导出标签」组：`_cta` / `_tooltip` 改为按 `ExportHistoryKeys.newCell(ExportNewKind.mp4)` 找 `ExportNewCell`（`.onTap` 代替 `.onPressed`，label 断言改 `'Joined video'`），点击用同一个 Key；`_pumpExport` overrides 加 `exportRecordRepositoryProvider`（FakeExportRecordRepo）、`fileResolverServiceProvider`、`workspaceProjectsProvider`。tooltip 三条断言的期望值**一字不改**（判据保留的证明）。
- 新 `test/features/export/widgets/export_video_dialog_preset_test.dart`（overrides 照 export_video_dialog_test.dart 抄，含 recorder 假实现）：`带 preset 打开 → 行序按预设、只勾预设里的、输出名预填`；`不带 preset → 行为与现在一致`（另外现有 export_video_dialog_test.dart 全部不改仍绿即证）。

## 变异点
1. export_new_cards 的拼接视频格去掉 `&& hasProject` → shell_tabs_empty_state_test「有 video result 但无项目上下文 → 禁用」红。
2. export_tab.dart 删掉 `ref.watch(canvasEdgesControllerProvider(canvasId).select((_) => true))` → shell_tabs_empty_state_test现有用例「导出标签订阅了边控制器」（第 463 行，`container.exists(canvasEdgesControllerProvider('c1'))`）红（R49 链序用例在真 autoDispose 控制器下同样会红；该组用例只改 finder、断言不改）。
3. 剪映格的可选性改成常量 `false` → export_tab_test「registry 多一个写出器 → 剪映格可点」红。
4. `ExportFormatsLanded.storyboardPdf = true` → export_tab_test「PDF 与 ZIP 置灰」红。
5. `isGone` 改成 `!fileExists`（失败行也算不在）→ export_history_list_test「失败行动作是重试」红（会变成重新导出）。
6. `filterExportHistory` 忽略 scope → 「本画布只留当前画布的行」红。
7. 标签可见边不 invalidate → 「标签由不可见变可见 → 重新查文件」红。
8. `removeExportRecord` 不 bump revision → 「从历史移除 → 行消失」红。
9. 「从历史移除」顺手删文件 → 同一用例「文件还在」断言红。
10. `applyExportPreset` 不把剩余行接在后面（丢行）→ preset_test「其余按原序在后」红。
11. 「打开文件夹」传文件路径而不是目录 → 「打开文件夹 → FolderOpener 收到目录路径」红。
12. `canReExport` 去掉 canvasAlive 判断 → 「来源画布已删 → 重新导出置灰」红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/export test/features/shell test/quality`。
- 变异逐条按上表做。
- 截图场景（`test/_harness/screenshot.dart` / golden_scaffold；1280×800，zh，深色）：用 `ExportTab`，shellControllerProvider 指向 p1 / c1，FakeExportRecordRepo 预置板上四行（成功 mp4 38.2 MB 今天 14:20；交付 Resolve 8 mp4 1 处占位 今天 11:05；PDF 文件不在 昨天——kind=pdf 的行由 fake 直接塞；失败 mp4 ffmpeg 昨天），节点里有 video result。截四张：①默认「全部」；②「本画布」；③右键失败行菜单展开；④历史为空。另截一张无项目上下文态（五格置灰 + 历史区「请先打开一个项目」）。
- 合入后主 Agent 在 docs/CLAUDE.md export 段登记新文件（export_new_cards / export_history_list / export_history_row / export_history_provider / export_history_format / export_dialog_preset / re_export / export_history_keys）。

## 风险与不确定
- （复核已定）`CanvasMenuPopover<T>` 在 `lib/features/canvas/widgets/canvas_menu/canvas_menu_popover.dart`（menu-split，经 create_node_menu.dart barrel 也导出）：`CanvasMenuPopover({required Offset? anchor（全局坐标，null = 收起）, required groups, required onSelected, required onDismiss, required String emptyText, double width = InkMenuPanel.blankWidth, Key? panelKey, required Widget child})`，menu-split 写明它就是给「舞台外（大纲 / 更多 / 序列 / 菜单栏）」用的，不依赖画布舞台；行右键用它包住整行，`anchor` 存在 State 里。
- 「跨画布重新导出」要先切画布再等节点 / 边加载；`ref.listenManual` 撑 autoDispose 的写法照 view_in_sequence.dart，执行时打开该文件对齐。若加载失败（AsyncError）→ 不开对话框、弹 `l10nAsyncError` 卡。
- 交付行的「重新导出」只是带用户去交付面板，**没有**用快照里的设置自动重跑——自动重跑要么偷偷改项目的交付设置，要么在 run_delivery 里复制一份 deliveryPlanProvider 的拼装逻辑，两者都不好；属设计缺口④，需要主 Agent / 设计确认。
- 「打开文件」借用 `FolderOpener.open` 传文件路径：macOS `open`、Windows `explorer` 都会用默认程序打开文件，但接口名是「打开目录」。若主 Agent 不接受，需给 FolderOpener 加 `openFile`（要改 test/features/startup/startup_error_view_test.dart、test/features/settings/diagnostics_section_test.dart 两个 fake），留给后续片。
- 现有 shell_tabs_empty_state_test 的导出组要改 finder；label 断言从 'Export video' 改成 'Joined video' 是有意的（格子名照板改成「拼接视频」），标签栏右侧「导出视频」按钮的文案不受影响。
- export-one-click（W16）也要读 export_records 与 ExportFormatsLanded / re_export 分派表；本片把分派表做成按 kind 追加一行的形状，方便它复用。
