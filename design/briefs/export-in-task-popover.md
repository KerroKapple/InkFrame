# export-in-task-popover · 导出 / 交付进任务弹层
- 波次：W14 / lane：E / 基底：origin/main（W0–W13 已合入）；同 lane 后面叠 delivery-clips-tab
- 依赖切片：duration-format（W0：`formatElapsed(AppLocalizations l, Duration d)` 在 `lib/l10n/duration_format.dart`）、job-timing（W8：`JobTiming` 旁表；弹层每秒刷新是 `shell_task_popover.dart` 里的私有 `_ElapsedMeta`（`Timer.periodic(1s)`，终态不起 Timer）；文案键 `taskElapsedRunning` / `taskElapsedTook`）、batch-run-executor（W10：弹层先按 BatchRun 分组再 `orderTasks`、有 `_BatchPendingRow`；胶囊有 `withBatchWaiting(TaskCapsuleSummary, int)`）、export-records-recording（W6：`export_history_recorder.dart`，两个控制器已在完成 / 失败处记历史）
- 阻塞决定：ShellExport Q2 → 选 A（进任务弹层，作为另一类行，只放内存、不写 jobs 表）

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W13 已合入）起新分支 `feat/export-in-task-popover`。delivery-clips-tab 会叠在你的分支后面。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行。本片不碰任何注册表。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法。本片不写库、不碰 jobs 表与 JobState（freezed 生成件）。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 注册在**控制器里**做（导出对话框、交付面板都不改）：任何入口发起的导出 / 交付都会进弹层。

## 目标
mp4 拼接导出和交付在跑的时候，状态栏任务胶囊把它们算进「生成中 N」，任务弹层里多出一类行：名字（「导出视频 · 8 镜」/「交付 · EDL」）、
进度条、已用时间，行尾「取消」。做完 / 失败后留在弹层里显示「完成 / 失败 · 用时 m:ss」，可被「清除已完成」清掉。关掉应用即消失（不落库）。

## 设计依据
- `b2/project/ShellExport.dc.html` ›「需要你定」Q2（抽文：SCRATCH/boards/ShellExport.txt 第 157–159 行）：
  「A 进，作为另一类行，只在内存不落 jobs 表 · B 不进，只看进度卡；建议 A：长任务都在一处看、一处取消」——按 A。
- 同板 ›「任务弹层显示耗时」（第 221–250 行）：
  「进行中：已用 = 现在 − 提交；排队：现在 − 入队。弹层开着才每秒刷新」；「终态：用时 = 完成 − 提交（不算排队）」；
  「一个格式函数（formatElapsed，纯函数）：不到 60 秒写『N 秒』，满 60 秒写 m:ss」。导出没有排队态，只有已用 / 用时。
- 设计缺口：导出 / 交付行的样子没画。本片定为：与生成行同一个 `_TaskRow` 版式（名字一行 + meta 一行 + 运行中 4 高进度条），
  名字前不加图标；meta =「类别 · 状态 · 已用 / 用时」；交付进度未知（媒体 0 个）时进度条不画。
- 设计缺口：终态导出行要不要「打开文件夹」动作没画。本片不做终态动作（导出历史在导出标签，W6 已有）。

## 允许改的文件
- `lib/features/export/providers/export_task_registry.dart`（新建）：内存任务表（见下）。
- `lib/features/export/providers/export_controller.dart`：`export()` 开始时登记、进度 / 收尾时回写。
- `lib/features/export/providers/delivery_controller.dart`：`run()` 同上；取消接现有 `cancel()`。
- `lib/features/shell/widgets/shell_task_popover.dart`（W14 归它）：混排两类行、导出行渲染、「清除已完成」清两张表。
- `lib/features/shell/widgets/shell_task_capsule.dart`（W14 归它）：摘要把导出计入。
- 测试：`test/features/export/providers/export_task_registry_test.dart`（新建）、`test/features/shell/shell_task_popover_test.dart`（新建）、
  `test/features/shell/shell_task_capsule_test.dart`（加用例）、`test/features/export/providers/export_controller_test.dart`（加用例）、
  `test/features/export/providers/delivery_execute_test.dart`（加用例）。

## 不许碰的文件
- 同 lane 后序 delivery-clips-tab：`lib/features/export/widgets/delivery_panel.dart`、`export/widgets/delivery_clips_tab.dart`。
- `export/widgets/export_video_dialog.dart`、`export/run_delivery.dart`、`export/providers/export_history_recorder.dart`（W6 建，只保持调用不动）。
- W14 其他片：note-variant（`create_menu_model`、`node_card.dart`、`stage_edge_layer.dart`、`generation_controller.dart` 等）、panel-resize（`canvas_screen.dart`、`app_preferences.dart`、`file_preferences_service.dart`）、
  assets-hover-preview（`assets_panel.dart`）、character-kind（`character*`、`import_remapper.dart`、`columns.dart`、迁移）。
- `generation/providers/jobs_registry.dart`、`generation/models/job_state.dart`、`services/job_queue_service.dart`、`services/job_queue/job_timing.dart`（W8 建，只读）、
  `notifications/**`、`shell_tab_bar.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W14）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- note-variant：`lib/features/app_actions/app_action_catalog.dart`（只换 newNote 占位行）、`lib/features/canvas/models/canvas_node_note.dart`、`lib/features/canvas/providers/link_action_controller.dart`、`lib/features/canvas/util/canvas_note_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/shortcuts/note_keys.dart`、`lib/features/canvas/widgets/stage/stage_edge_layer.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`lib/features/generation/generation_controller.dart`、`test/features/canvas/link_action_controller_test.dart`、`test/features/canvas/models/canvas_node_note_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/outline_model_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`test/features/canvas/widgets/note_node_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/features/generation/generation_controller_prompt_test.dart`
- panel-resize：`lib/core/models/app_preferences.dart`、`lib/features/canvas/providers/panel_widths.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/panel_resize_handle.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/providers/panel_widths_test.dart`、`test/features/canvas/widgets/canvas_inspector_tabs_test.dart`、`test/features/canvas/widgets/inspector_auto_save_row_test.dart`、`test/features/canvas/widgets/inspector_history_panel_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/panel_resize_test.dart`
- assets-hover-preview：`lib/core/interfaces/video_player_service.dart`、`lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`、`lib/features/canvas/widgets/left_rail/assets_panel.dart`、`lib/services/media_kit_video_player_service.dart`、`test/features/canvas/widgets/left_rail/asset_hover_preview_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/sequence/widgets/sequence_monitor_test.dart`
- character-kind：`lib/core/db/columns.dart`、`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/mention_candidates.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`lib/features/canvas/widgets/mention_popover.dart`、`lib/services/import/import_remapper.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/schema/schema_v11.dart`、`test/core/db/columns_schema_test.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/mention_candidates_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`、`test/quality/import_schema_sync_test.dart`、`test/quality/migration_registry_test.dart`、`test/services/import/import_remapper_test.dart`、`test/storage/repositories/project_import_writer_integration_test.dart`、`test/storage/schema/populated_migration_test.dart`
- delivery-clips-tab：`lib/features/export/util/delivery_clip_rows.dart`、`lib/features/export/widgets/delivery_clips_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/util/delivery_clip_rows_test.dart`、`test/features/export/widgets/delivery_clips_tab_test.dart`

## 具体改动
现有 API（已核对）：
- `ExportController.export({required String projectId, required List<CanvasNode> nodes, String? outputBaseName})`、`cancelExport()`、`ExportVideoBusy({double? progress})`（export_controller.dart 约第 74–90 行；`exportControllerProvider` 是 autoDispose 单例，导出中 `ref.keepAlive()`）。
- `DeliveryController.run({required String projectId, required DeliveryPlan plan})`、`cancel()`、`DeliveryRunning({done, total}).fraction`（delivery_controller.dart 约第 96–185 行；app-scoped）。
- `ExportCancelToken.cancel()` 幂等（core/interfaces/video_export_service.dart 约第 10 行）。
- `clockProvider` → `Clock.nowUtc()`（core/di/clock.dart；core/logging/logger_service.dart 约第 52 行）。
- `taskCapsuleSummaryOf(List<JobState>)` → `({int running, int queued, int terminal, int failed})`（shell_task_capsule.dart 约第 37 行）；
  `orderTasks(List<JobState>)`（shell_task_popover.dart 约第 41 行）；`JobsRegistry.clearTerminated()`。
- `deliveryTargetLabel(AppLocalizations l, DeliveryTarget t)`（export/util/delivery_target_labels.dart 约第 10 行）；`DeliveryTarget`（export/models/delivery_settings.dart 约第 23 行）。
- `formatElapsed`（W0 duration-format）；弹层每秒刷新沿用 job-timing 在同一文件里的 `_ElapsedMeta`（把「起点时刻」做成参数，生成行与导出行共用，不另起第二个 Timer 写法）。
- W10 batch-run-executor 的分组：`orderTaskRows` 保留批次分组段（批次组 → 散 job → 导出），导出行不进任何批次。

新增签名：
```dart
// export/providers/export_task_registry.dart
enum ExportTaskKind { mp4, delivery }
enum ExportTaskStatus { running, succeeded, failed, cancelled }

@immutable
class ExportTask {
  final String id;                 // 'export-<n>' 自增，只在本次会话唯一
  final ExportTaskKind kind;
  final int shotCount;             // mp4 = 输入视频数；交付 = plan.shots.length
  final DeliveryTarget? target;    // 仅交付
  final DateTime startedAt;        // clock.nowUtc()
  final DateTime? finishedAt;
  final double? progress;          // 0..1；null = 不确定
  final ExportTaskStatus status;
  final InkError? error;
  bool get isTerminal; bool get isCancellable; // == running
  // ==/hashCode 按值（进度回调频繁，避免同值唤醒）
}

final exportTaskRegistryProvider = NotifierProvider<ExportTaskRegistry, List<ExportTask>>(...); // app-scoped，非 autoDispose

class ExportTaskRegistry extends Notifier<List<ExportTask>> {
  String start({required ExportTaskKind kind, required int shotCount, DeliveryTarget? target, required VoidCallback onCancel});
  void progress(String id, double? fraction);            // 非 running 时忽略
  void finish(String id, ExportTaskStatus status, {InkError? error}); // 写 finishedAt；丢掉 onCancel
  void cancel(String id);                                // 调登记时的 onCancel；幂等；非 running 不动
  void clearTerminated();
}

// shell_task_popover.dart（追加）
sealed class TaskRowItem {}  final class JobRowItem(JobState job); final class ExportRowItem(ExportTask task);
/// 活动在前（生成 job 按注册序，再导出按开始序）、终态在后（同样两段）。
List<TaskRowItem> orderTaskRows(List<JobState> jobs, List<ExportTask> exports);

// shell_task_capsule.dart（追加）
TaskCapsuleSummary exportCapsuleSummaryOf(List<ExportTask> tasks); // running→running，失败→terminal+failed，完成/取消→terminal
TaskCapsuleSummary addSummaries(TaskCapsuleSummary a, TaskCapsuleSummary b);
```
控制器接线：`export()` 在 `state = ExportVideoBusy()` 同处 `start(kind: mp4, shotCount: inputs.length, onCancel: token.cancel)`；
onProgress 里同步 `progress(id, p)`；成功 / `CancelledError` / `InkError` / `PathSecurityError` 各分支对应 `finish(succeeded / cancelled / failed / failed)`。
`run()` 在 `state = DeliveryRunning(...)` 同处 `start(kind: delivery, shotCount: effective.shots.length, target: plan.settings.target, onCancel: token.cancel)`；
writer 缺失的早退分支不登记。registry 的 notifier 在第一个 await 之前取好；await 之后的回写都在控制器 `_alive` 为真时才做。
弹层：`_TaskRow` 保持给 JobState 用；新增 `_ExportTaskRow`（同版式、同 `_ActionLink` / `_ProgressBar`）。行 Key：`ShellTaskPopover.exportRowKey(id)` / `exportCancelKey(id)` / `exportProgressKey(id)`。
「清除已完成」：两张表任一有终态即可点，点了两张表各清一次。胶囊：`withBatchWaiting(taskCapsuleSummaryOf(jobs), waiting)`（W10 现有写法）再与 `ref.watch(exportTaskRegistryProvider.select(exportCapsuleSummaryOf))` 相加（`addSummaries`）。

## 行为规则与边界情况
- R1 mp4 导出开始 ⇒ 弹层多一行「导出视频 · N 镜」，状态「导出中 · 已用 N 秒」，有进度条；进度未知（任一输入缺时长）时进度条不画。
- R2 交付开始 ⇒「交付 · <目标名>」，进度 = done/total；total 为 0（全是占位镜）不画进度条。
- R3 胶囊「生成中 N」= 运行中的 job + 运行中的导出；导出不计入「排队 M」。只有导出在跑、注册表无 job 时胶囊照样出现。
- R4 弹层里点导出行「取消」⇒ 对应 ExportCancelToken.cancel ⇒ 控制器走 CancelledError 分支 ⇒ 行变「已取消」；mp4 对话框若开着回到可编辑态（现有行为）；交付回 DeliveryIdle。
- R5 取消不写导出历史（W6 recorder 现有规则，本片不能破坏：CancelledError 分支只 finish(cancelled)）。
- R6 完成 ⇒「完成 · 用时 m:ss」（finishedAt − startedAt，formatElapsed）；失败 ⇒「失败 · 用时 …」，meta tooltip 为本地化错误（l10nError）。
- R7 已用时间只在弹层开着时每秒刷新（复用 job-timing 的 ticker）；胶囊摘要不因进度变动重建（select + 值相等）。
- R8 「清除已完成」同时清 job 与导出两类终态；运行中的导出不清。
- R9 只在内存：不写 jobs 表、不进 JobState；应用重启后不见。退出时控制器 onDispose 取消令牌，registry 随容器一起销毁，不再回写。
- R10 cancel 幂等：连点两次、或行已终态时点（竞态）不报错、不二次回调。
- R11 mp4 与交付可同时各有一条在跑，两行并列；同一类第二次发起被控制器 isBusy 挡住，不登记。
- R12 与撤销栈无关（不改画布）。无平台差异：不涉及平台通道；ffmpeg 子进程的 kill 由现有服务负责。

## 新文案键
| key | en | zh |
|---|---|---|
| taskPopoverExportMp4 | Export video · {count} shots | 导出视频 · {count} 镜 |
| taskPopoverExportDelivery | Delivery · {target} | 交付 · {target} |
| taskPopoverExportRunning | Exporting | 导出中 |

`{count}` 为 int（ICU 复数：`{count, plural, =1{1 shot} other{{count} shots}}`，zh 不分复数）；`{target}` 为 String。
完成 / 失败 / 已取消复用现有 `renderQueueStatusDone` / `renderQueueStatusFailed` / `renderQueueStatusCancelled`；已用 / 用时复用 W8 job-timing 的 `taskElapsedRunning(d)` / `taskElapsedTook(d)`，`d = formatElapsed(l, …)`。

## 测试
`test/features/export/providers/export_task_registry_test.dart`（覆写 clockProvider 为 fake 时钟）
- `'start adds running task with clock time'`；`'progress ignored after finish'`；
- `'finish records finishedAt and status'`；`'cancel invokes onCancel once and is idempotent'`；
- `'cancel on terminal task does nothing'`；`'clearTerminated keeps running tasks'`。
`test/features/export/providers/export_controller_test.dart`（加）
- `'export registers task and finishes succeeded'`；`'cancel from registry cancels export and marks cancelled'`（fake 服务挂起直到令牌取消）；
- `'failed export marks task failed'`。
`test/features/export/providers/delivery_execute_test.dart`（加）
- `'delivery registers task with target and progress'`；`'cancel from registry ends delivery idle'`；`'missing writer does not register'`。
`test/features/shell/shell_task_capsule_test.dart`（加）
- `'export counts as running in capsule summary'`；`'capsule shows when only export runs'`。
`test/features/shell/shell_task_popover_test.dart`（新建）
- `'orderTaskRows puts active exports before terminal jobs'`；`'export row shows name, elapsed and cancel'`；
- `'tap cancel on export row calls registry cancel'`；`'clear done clears both registries'`；`'unknown progress hides progress bar'`。

## 变异点
- M1 `ExportTaskRegistry.cancel` 不判 running → `'cancel on terminal task does nothing'` 红。
- M2 `cancel` 不记已取消（二次调用 onCancel）→ `'cancel invokes onCancel once and is idempotent'` 红。
- M3 export_controller 的 CancelledError 分支 finish 成 failed → `'cancel from registry cancels export and marks cancelled'` 红。
- M4 delivery_controller 不调 `start` → `'delivery registers task with target and progress'` 红。
- M5 `exportCapsuleSummaryOf` 把运行中算进 queued → `'export counts as running in capsule summary'` 红。
- M6 胶囊空判据只看 jobs → `'capsule shows when only export runs'` 红。
- M7 `orderTaskRows` 去掉活动 / 终态分段 → `'orderTaskRows puts active exports before terminal jobs'` 红。
- M8 「清除已完成」只清 jobsRegistry → `'clear done clears both registries'` 红。

## 验收
- `flutter analyze lib test`；`flutter test --exclude-tags golden test/features/export test/features/shell`；变异 M1–M8 逐条红。
- 截图场景：`ShellTaskPopover()` 外包 ProviderScope，覆写 `jobsRegistryProvider`（1 个 JobRunning、1 个 JobFailed）、`exportTaskRegistryProvider`（mp4 running 0.4、交付 succeeded）、clockProvider 固定；
  截 ① 弹层四行混排；② 胶囊「生成中 2」（1 job + 1 导出）；③ 只有一条导出在跑时的胶囊。

## 风险与不确定
- job-timing（W8）与 W10 batch-run-executor 已改过 `shell_task_popover.dart` / `shell_task_capsule.dart`（耗时 meta、批次分组、`withBatchWaiting`）；导出行与之同口径。job-timing 的弹层 meta 用的是 `formatDurationLabel`（四舍五入），画板要求计时用 `formatElapsed`（向下取整）——本片导出行用 `formatElapsed`；两者在整秒边界会差 1 秒，回报里提醒主 Agent 是否统一。
- export-records-recording（W6）在两个控制器里加的记录调用位置以合入后为准；本片的 finish 必须与它同处、互不改动其判据。
- system-notifications（W10）的「≥10 秒」读 JobTiming；导出若也要发系统通知，需它读 ExportTask.startedAt——不在本片范围。
- 交付在途时标签条被锁（deliveryBusyProvider），但状态栏不锁：从弹层取消交付是新入口，原「只有关窗才取消」的语义被放宽（Q2 建议 A 的直接后果）。
- 设计缺口两条见「设计依据」：导出行版式、终态动作。
