# export-records-recording · 拼接导出和交付完成或失败时各写一条导出历史（取消不写）
- 波次 W6 / lane E 第一片 / 基底 origin/main〔W0–W5 已合入，含 W4 export-records-table〕
- 依赖切片：export-records-table（W4，新建 `export_records` 表、`ExportRecordRepository`、`exportRecordRepositoryProvider`、`ExportRecord` / `ExportKind` / `ExportRecordStatus`、`test/_harness/fake_export_record.dart` 的 `FakeExportRecordRepo`）
- 阻塞决定：无
- 同 lane 后续：export-tab-history 叠在本片之后（读本片定义的快照与 revision）

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
界面上暂时看不到变化（列表在下一片）。每次「导出视频」（ffmpeg 拼接）或「交付」跑到成功 / 失败，库里多一行导出历史，带上能重新导出的设置快照；用户取消不留记录。写历史失败只进日志，导出本身照样算成功、照样弹成功卡。

## 设计依据
- ShellExport.dc.html「导出第二批」规则第 2 条：三条路径（导出对话框 / 交付 / PDF·ZIP）完成或失败各记一行，取消不记。本片接前两条；PDF / ZIP 由 storyboard-pdf-export（W18）、image-zip-export（W15）调用同一个 recorder。
- 同节规则第 1 条的列：kind · 文件 · 镜数 · 时长 · 大小 · status · 设置快照。
- plan.md 第 3 节 W4–W6 验收：取消不写记录；写库失败不影响导出本身成功。
- slices.json notes：recorder 只是薄层；快照里放 mp4 的镜头顺序、take 选择和输出名；交付放 DeliverySettings（含目标软件）。
- ShellExport-Q3 按建议 A（一直留），本片不做清理。
- 设计缺口：板上没说交付失败时「文件」写什么——本片定为 output_path = null（表 CHECK 允许失败行无路径）。

## 允许改的文件
- 新 `lib/features/export/providers/export_history_recorder.dart`：`ExportRecordDraft`、`ExportHistoryRecorder` 抽象、`RepositoryExportHistoryRecorder`、`exportHistoryRecorderProvider`、`exportHistoryRevisionProvider`、日志模块常量。
- 新 `lib/features/export/models/export_snapshot.dart`：快照的键常量 + 两个构造函数 + 容错读取函数（下一片「重新导出」读它）。
- `lib/features/export/providers/export_controller.dart`：成功 / 失败终态各调一次 recorder（不 await）。
- `lib/features/export/providers/delivery_controller.dart`：`run` 加可选 `canvasId`；成功 / 失败终态各调一次 recorder（不 await）。
- `lib/features/export/run_delivery.dart`：第 26–27 行 `.run(projectId: project.id, plan: plan)` 补 `canvasId: canvasId`。
- 测试：新 `test/features/export/providers/export_history_recorder_test.dart`、新 `test/features/export/models/export_snapshot_test.dart`、`test/features/export/providers/export_controller_test.dart`、`test/features/export/providers/delivery_execute_test.dart`（slices.json 写的 delivery_controller_test.dart 不存在，交付执行的测试就在这个文件）、`test/features/export/widgets/export_video_dialog_test.dart`（只在 overrides 里加一行）、新 `test/_harness/fake_export_history_recorder.dart`（`RecordingExportHistoryRecorder`）+ `test/_harness/README.md` 加一行。

## 不许碰的文件
- W6 其他 lane：drag_snap / snap_guides_layer / node_card.dart / node_card_slot.dart / stage_overlays.dart / snap_menu_items.dart / node_drag_delta.dart / core/di/canvas_snap.dart / app_preferences.dart / file_preferences_service.dart / canvas_appearance_section（snapping）；canvas_view.dart / stage_edge_layer.dart / canvas_menu_host.dart / canvas_menu_request.dart / edge_* / selected_edge_controller / shortcuts/core_canvas_keys.dart / theme/components/ink_menu_panel.dart（cm-edge-menu）；canvas_nodes_controller / canvas_node_delete / node_menu_entries / canvas_snackbars（cm-delete-bridge）；canvas_lanes_controller / stage_lane_layer / lane_* / canvas_tool_actions.dart（undo-lanes）。
- 本片不碰：`lib/features/shell/widgets/tabs/export_tab.dart`、`export_video_dialog.dart`、`open_export_dialog.dart`、`delivery_panel*.dart`（留给 export-tab-history）；export-records-table 建的 schema / 仓储 / 模型文件一字不改。
- `test/_harness/fake_export_record.dart`、`test/_harness/shell_app.dart` 不改（table 片已把 FakeExportRecordRepo 接进 sealedShellOverrides）。

## 具体改动

### export_snapshot.dart
```dart
const int kExportSnapshotVersion = 1;
abstract final class ExportSnapshotKeys {
  static const String version = 'v';
  static const String nodeIds = 'node_ids';                 // mp4：按导出顺序的已选 result 节点 id
  static const String outputBaseName = 'output_base_name';  // mp4：用户填的名，留空为 null
  static const String deliverySettings = 'delivery_settings'; // 交付：DeliverySettings.toMap()（含 target）
  static const String projectFile = 'project_file';         // 交付：工程文件名，如 示例项目.edl
  static const String mediaCount = 'media_count';
  static const String placeholderCount = 'placeholder_count';
}
Map<String, Object?> concatExportSnapshot({required List<String> nodeIds, String? outputBaseName});
Map<String, Object?> deliveryExportSnapshot({required DeliverySettings settings,
    required String projectFile, required int mediaCount, required int placeholderCount});
// 读：缺失 / 类型不符一律退空值，绝不抛（与 DeliverySettings.fromMap 同一纪律）。
List<String> snapshotNodeIds(Map<String, Object?> s);           // 非字符串元素跳过
String? snapshotOutputBaseName(Map<String, Object?> s);          // 空串当 null
DeliverySettings? snapshotDeliverySettings(Map<String, Object?> s); // 键缺失 → null；有 → DeliverySettings.fromMap
int snapshotMediaCount(Map<String, Object?> s);                 // 缺失 → 0
int snapshotPlaceholderCount(Map<String, Object?> s);           // 缺失 → 0
```

### export_history_recorder.dart
```dart
const String kExportHistoryLogModule = 'export.history';

@immutable
class ExportRecordDraft {
  const ExportRecordDraft({required this.projectId, this.canvasId, required this.kind,
    required this.status, this.outputRelativePath, this.shotCount = 0, this.durationMs,
    this.sizeBytes, this.errorCode, this.errorReason,
    this.snapshot = const <String, Object?>{}});
  /// 失败草稿：code = error.code.wire，reason = error.extra['reason'] 是 String 时取它。
  factory ExportRecordDraft.failed({required String projectId, String? canvasId,
    required ExportKind kind, required InkError error, int shotCount, int? durationMs,
    Map<String, Object?> snapshot});
  … // 字段同构造参数；== / hashCode 手写（测试要比较）
}

abstract class ExportHistoryRecorder {
  /// 写一条。契约：**永不抛 InkError**（写库失败只记 warn 日志）；调用方不 await。
  Future<void> record(ExportRecordDraft draft);
}

class RepositoryExportHistoryRecorder implements ExportHistoryRecorder {
  RepositoryExportHistoryRecorder(this._ref);
  final Ref _ref;
  @override Future<void> record(ExportRecordDraft draft);
}

final exportHistoryRecorderProvider = Provider<ExportHistoryRecorder>(
  (ref) => RepositoryExportHistoryRecorder(ref), name: 'exportHistoryRecorderProvider');

/// 历史行变了的信号：record 写成功 / 下一片「从历史移除」成功后 +1。
/// 下一片的 exportHistoryProvider watch 它，列表据此刷新。
final exportHistoryRevisionProvider =
    NotifierProvider<ExportHistoryRevision, int>(ExportHistoryRevision.new, name: 'exportHistoryRevisionProvider');
class ExportHistoryRevision extends Notifier<int> { int build() => 0; void bump(); }
```
`RepositoryExportHistoryRecorder.record` 步骤：
1. `kind == mp4 && status == succeeded && sizeBytes == null && outputRelativePath != null` 时量文件大小：`fileResolverServiceProvider` 的 `resolveInProject(projectId:, relativePath:)` → `File.length()`；`on PathSecurityError` / `on FileSystemException` → 大小 null，照写。
2. `final repo = await _ref.read(exportRecordRepositoryProvider.future);` → `repo.create(kind: draft.kind.wire, status: draft.status.wire, outputPath: draft.outputRelativePath, settingsSnapshot: draft.snapshot, …)`。
3. 写成功 → `_ref.read(exportHistoryRevisionProvider.notifier).bump()`。
4. `on InkError catch (e)` → `_ref.read(loggerProvider).warn(kExportHistoryLogModule, 'record_failed', extra: {...e.toLogJson(), 'kind': draft.kind.wire, 'status': draft.status.wire})`，不 bump、不 rethrow。只捕 InkError（docs/CLAUDE.md「NO catching Exception」）。

### export_controller.dart（`export()`，现第 81–147 行）
- 进 try 前算好：`canvasId` = 输入节点的 canvasId 全相同时取它，否则 null（新私有函数 `_commonCanvasId`）；`keptIds` = 进了 `inputs` 的节点 id（与 `inputs` 同序）；`snapshot = concatExportSnapshot(nodeIds: keptIds, outputBaseName: outputBaseName)`；并在 try 前 `final recorder = ref.read(exportHistoryRecorderProvider);`（dispose 后不能再 read）。
- 第 126 行成功后：`if (_alive) { state = ExportVideoSuccess(out); unawaited(recorder.record(ExportRecordDraft(kind: ExportKind.mp4, status: succeeded, outputRelativePath: out, shotCount: inputs.length, durationMs: totalMs, canvasId:, projectId:, snapshot:))); }`。
- 第 131 行 `on InkError`：`state = ExportVideoFailure(e)` 后 `unawaited(recorder.record(ExportRecordDraft.failed(kind: mp4, error: e, …)))`。
- 第 133–145 行 PathSecurityError 分支：用同一个翻译出来的 ProviderError 记一条失败。
- 第 127–129 行 `on CancelledError`：**不记**（加一行注释说明「取消不记，ShellExport 规则 2」）。
- `_alive == false`（应用退出期）时三处都不记。

### delivery_controller.dart（`run()`，现第 108–181 行）
- 签名：`Future<void> run({required String projectId, required DeliveryPlan plan, String? canvasId})`。
- 第 111–121 行「没有写出器」防御分支：**不记**（没有真正开跑，界面已禁掉）。
- 在构造 `texts` 后算：`projectFile = texts.first.fileName`；`snapshot = deliveryExportSnapshot(settings: plan.settings, projectFile:, mediaCount: media.length, placeholderCount: plan.placeholders.length)`；`durationMs = effective.shots` 的 `durationMs` 之和；`recorder = ref.read(exportHistoryRecorderProvider)`。
- 第 166 行成功：`state = DeliverySucceeded(outcome)` 后记 succeeded，`outputRelativePath: '${outcome.outputDirRelative}/$projectFile'`（工程文件，「打开文件」打开它，「打开文件夹」打开它的目录），`shotCount: effective.shots.length`，`sizeBytes: null`（交付是一组文件，不量）。
- 第 170 行 `on InkError`：记 failed（outputRelativePath null）。
- 第 167–169 行 `on CancelledError`：不记。

## 行为规则与边界情况
1. 拼接成功 → 恰好一条 `kind=mp4, status=succeeded, output_path=exports/<名>.mp4`；`shot_count` = 实际进了 ffmpeg 的输入数（缺 canvasId / videoUrl 被过滤的不算）。
2. 拼接失败（如 `LocalIOError(reason: ffmpeg_not_found)`）→ 一条 failed，`error_code='local_io_error'`、`error_reason='ffmpeg_not_found'`，无 output_path。
3. 用户点「取消导出」（CancelledError）→ 零条。关窗导致的取消同样零条。
4. 交付成功 → 一条 `kind=delivery`；快照里 `delivery_settings.target` = 当次目标软件（如 'resolve'）、`placeholder_count` = 占位镜数。
5. 交付失败（`delivery_source_missing` 等）→ 一条 failed；取消 → 零条；写出器缺失的防御返回 → 零条。
6. 写库失败（仓储抛 LocalIOError）→ 导出状态仍是 Success / DeliverySucceeded，成功卡照弹；日志多一条 warn（module `export.history`, msg `record_failed`）；revision 不变。
7. 写库很慢 / 挂起 → `export()` / `run()` 照常返回（recorder 不被 await）；对话框照常关、成功卡照常出。
8. mp4 成功后文件量不到（被删 / 路径越界）→ size_bytes 为 null，行照写。
9. 混合画布的节点列表（理论上 UI 不会给）→ canvas_id 为 null，行照写。
10. 每次写成功 revision +1；失败不变。
11. 与撤销栈无交互（导出不进画布撤销栈）。mac / Windows 无差异。

## 新文案键
无。

## 测试
- 新 `test/_harness/fake_export_history_recorder.dart`：`RecordingExportHistoryRecorder implements ExportHistoryRecorder`——`drafts` 列表在 `record` 被调用时**同步**追加；可选 `gate`（Completer）让 `record` 返回挂起的 future。
- 新 `test/features/export/models/export_snapshot_test.dart`：
  - `concat 快照往返：node_ids 顺序与 output_base_name`；`output_base_name 空串读成 null`；`node_ids 里混了数字 → 跳过非字符串`；`delivery 快照往返：target / tc 起点 / 四个开关原样回来`；`缺 delivery_settings 键 → null`；`空 Map 全部退默认，不抛`。
- 新 `test/features/export/providers/export_history_recorder_test.dart`（ProviderContainer；override `exportRecordRepositoryProvider` = FakeExportRecordRepo、`loggerProvider` = test/helpers/recording_logger.dart 的 RecordingLogger、`fileResolverServiceProvider` = 指向临时目录的 resolver）：
  - `成功草稿写一行，kind / status 用协议字面量`：fake 里一行，kind='mp4'、status='succeeded'。
  - `mp4 成功量文件大小`：临时目录放 5 字节的 `exports/a.mp4` → size_bytes == 5。
  - `文件不在 → size 为 null，照写`。
  - `写库失败不抛、记一条 warn、revision 不变`：`failCreate = true` → `await record(...)` 正常返回；`logger.byModule('export.history')` 一条 warn；revision 仍 0。
  - `写成功 revision +1`。
  - `ExportRecordDraft.failed 带上 code.wire 与 extra.reason`。
- `test/features/export/providers/export_controller_test.dart`：`_make` 的 overrides 加 `exportHistoryRecorderProvider.overrideWithValue(recorder)` 并把 recorder 一并返回；新用例：
  - `成功 → 一条 mp4 succeeded 草稿，带画布、镜数、顺序与输出名`：两节点 [n2, n1] → `snapshot.node_ids == ['n2','n1']`、`outputRelativePath == 'exports/out.mp4'`、`canvasId == 'c1'`、`shotCount == 2`。
  - `缺 videoUrl 的节点不计入 shot_count 与 node_ids`。
  - `失败 → 一条 failed 草稿，reason=ffmpeg_not_found`。
  - `取消 → 零条草稿`：沿用第 304 行现有取消用例的写法（gate + cancelExport，gate 以 `CancelledError.byUser(...)` 收敛），追加 `recorder.drafts` 为空的断言。
  - `recorder 挂起时 export() 照样返回且状态为 Success`：recorder.gate 不完成；`export()` 的 future 在 `pumpEventQueue()` 后已完成。
  - `节点来自两个画布 → canvasId 为 null`。
- `test/features/export/providers/delivery_execute_test.dart`：第 109 行建 container 的 overrides 加 recorder；新用例：
  - `交付成功 → 一条 delivery 草稿，output_path 指向工程文件、快照带目标软件与占位数`：沿用「两镜 + 一个占位镜」那组数据，`outputRelativePath == 'exports/<base>.edl'`、`snapshot.delivery_settings.target == 'resolve'`、`placeholder_count == 1`、`canvasId == 'c1'`（run 时传入）。
  - `源文件不存在 → 一条 failed，reason=delivery_source_missing`。
  - `取消 → 零条`（沿用第 338 行那组取消用例的写法，追加断言）。
  - `没有写出器 → 零条`（沿用第 461 行用例，追加断言）。
- `test/features/export/widgets/export_video_dialog_test.dart`：第 182 行 overrides 加 `exportHistoryRecorderProvider.overrideWithValue(RecordingExportHistoryRecorder())`（否则默认 recorder 会去起真 PG）。不加新用例。

## 变异点
1. export_controller 的 `on CancelledError` 分支里也调 recorder → 「取消 → 零条草稿」红。
2. 把 `unawaited(recorder.record(...))` 改成 `await recorder.record(...)` → 「recorder 挂起时 export() 照样返回」红。
3. `RepositoryExportHistoryRecorder` 去掉 `on InkError` 捕获 → 「写库失败不抛、记一条 warn」红。
4. 失败时也 bump revision → 同一条用例的「revision 不变」断言红。
5. `keptIds` 换成未过滤的 `nodes.map((n) => n.id)` → 「缺 videoUrl 的节点不计入」红。
6. delivery 成功时 `outputRelativePath` 写成 `outcome.outputDirRelative`（只写目录）→ 「交付成功 → output_path 指向工程文件」红。
7. `deliveryExportSnapshot` 漏掉 `delivery_settings` → 交付成功用例 target 断言红；snapshot_test 往返红。
8. delivery 的「没有写出器」分支也记一条 → 「没有写出器 → 零条」红。
9. 量大小时不捕 FileSystemException → 「文件不在 → size 为 null，照写」红（抛错后没写行）。

## 验收
- `flutter analyze lib test`；`flutter test test/features/export test/features/shell`。
- 变异逐条按上表做。
- 非 UI 片，无截图。合入后主 Agent 在 docs/CLAUDE.md 的 export 段登记 `providers/export_history_recorder.dart`、`models/export_snapshot.dart`。

## 风险与不确定
- 默认 recorder 一旦被调用就会解析 `exportRecordRepositoryProvider` → `pgMigratedPoolProvider`。凡是真的跑完导出 / 交付、又没走 `sealedShellOverrides` 的测试都必须 override recorder（已列出三处；执行时再 grep 一遍 `exportControllerProvider` / `deliveryControllerProvider.notifier).run` 确认没有漏）。
- export-in-task-popover（W14）也要改这两个 controller，排在本片之后；本片只在终态处加调用，不重排控制流，减少它的 rebase 冲突。
- 交付的 size_bytes 不量（一组文件），列表上交付行不显示大小——与板上交付行「交付 · Resolve · 1 处占位」一致。
