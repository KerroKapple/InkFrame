# job-timing · 任务计时旁表 + 任务弹层显示「已用 / 排队 / 用时」
- 波次 W8 / lane E / 基底：origin/main（W0–W7 已合入）；依赖切片：duration-format（W0，`lib/l10n/duration_format.dart` 的 `formatElapsed(AppLocalizations l, Duration d)`）；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
- 状态栏胶囊点开的任务弹层里，每行 meta 显示耗时：排队的写「Gemini · 排队 8 秒」，跑着的写「万相 2.2 · 已用 1:12」，终态写「可灵 · 失败 · 用时 2:03」。
- 弹层开着时耗时每秒走一次；关着不走。
- 生成完成的通知卡多一行出处小字「用时 1:12」。
- 给 W10 system-notifications（判「用时 ≥ 10 秒」）留同一张 jobId → 时刻表（W9 job-eta 读库，不读这张表）。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/ShellExport.dc.html` ·「任务弹层显示耗时」：
  - 进行中：已用 = 现在 − 提交；排队：现在 − 入队。弹层开着才每秒刷新。
  - 终态：用时 = 完成 − 提交（不算排队）。
  - 一个格式函数：不到 60 秒写「N 秒」，满 60 秒写 m:ss；任务弹层、通知卡、系统通知都用它（W0 duration-format 已落成两个函数：片长 / 估时用 `formatDurationLabel(l, int ms, {estimated})`（四舍五入），**计时（已用 / 排队 / 用时）用 `formatElapsed(l, Duration d)`**（向下取整、负值当 0、不带 ~）。本片只用 `formatElapsed`，不新建格式函数；W14 export-in-task-popover 也按 `formatElapsed` 引用本片。）
  - JobQueueService 在写 submitted_at / completed_at 处同时记时刻，进 jobId → JobTiming 旁表；不改 JobState（freezed 生成件，build_runner 卡点）。系统通知的 ≥ 10 秒读同一张表。
- `b2/project/ShellExport.dc.html` ·「系统通知」样稿正文「万相 2.2 · 图生视频 · 用时 1:12」、「F6 跳到通知区」样稿「Gemini · 图像 · 用时 18 秒」：卡片上的「用时」与弹层同一格式。
- critic.txt 第 20 条（耗时格式不一致 → 共用一个格式函数）。
- 设计缺口：注册表里 JobQueued 要等首个进度才变 JobRunning（generation_controller.dart:398 只 upsert queued），可 provider 实际已提交——画板没说状态字和耗时谁说了算。本片定：耗时阶段以计时表为准（有提交时刻就写「已用」），状态字只在终态行保留。
- 设计缺口：排队中被取消的任务（从没提交）终态行没有「用时」可写——本片定：只写「已取消」，不加耗时。
- 设计缺口：失败卡要不要也加「用时」画板没画（F6 样稿失败卡正文是错误原因）——本片只给完成卡加。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：不给 JobQueueService（10 个实现）、JobRepository（9 个实现）加抽象方法。

- 新 `lib/core/interfaces/job_timing_source.dart`：只读小接口 `JobTimingSource` + 手写不可变值类 `JobTiming` + 纯函数 `jobElapsedOf`（阶段与毫秒数）。不依赖 Flutter。
- 新 `lib/services/job_queue/job_timing.dart`：`InMemoryJobTimingTable implements JobTimingSource`，带三个写方法（入队 / 提交 / 完成），时钟注入。
- 新 `lib/core/di/job_timing.dart`：`jobTimingTableProvider`（app-scoped）+ `jobTimingSourceProvider`（以接口类型暴露同一个实例）。
- `lib/services/job_queue_service.dart`：构造函数加可选 `InMemoryJobTimingTable? timing`；三处记时刻（见「具体改动」）。不改 `JobQueueService` 接口。
- `lib/core/di/job_queue.dart`：构造 `InMemoryJobQueueService` 时传 `timing: ref.watch(jobTimingTableProvider)`。
- `lib/features/shell/widgets/shell_task_popover.dart`：行 meta 换成带耗时的写法；新增每秒刷新的私有小部件；删头注第 10 行「不显示耗时：JobState 没有起止时间（与原渲染队列一样）。」并改写成本片规则。
- `lib/features/notifications/widgets/job_notification_listener.dart`：`_notifySucceeded` 的 `show(...)` 加 `meta: 用时 …`（读 `jobTimingSourceProvider`）。
- 测试（新建，不与同波撞名）：`test/services/job_queue/job_timing_test.dart`、`test/services/job_queue_service_timing_test.dart`、`test/features/shell/shell_task_popover_elapsed_test.dart`、`test/features/notifications/widgets/job_notification_listener_elapsed_test.dart`。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- node-disabled-flag：`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/left_rail/outline_panel.dart`、`lib/theme/tokens.dart`，及新文件 `models/canvas_node_disabled.dart`、`util/canvas_disable_actions.dart`、`models/commands/patch_nodes_type_config_command.dart`、`canvas_menu/disable_menu_entries.dart`、`shortcuts/disable_keys.dart`。
- wrap-in-lane：`lib/features/canvas/providers/canvas_lanes_controller.dart`、`lib/features/canvas/models/canvas_command.dart`、`lib/features/app_actions/app_action_catalog.dart`（那一行），及新文件 `util/lane_wrap.dart`、`util/canvas_wrap_actions.dart`、`models/commands/wrap_in_lane_command.dart`、`shortcuts/wrap_lane_keys.dart`、`canvas_menu/wrap_lane_menu_entries.dart`。
- align-distribute-arrange：新文件 `util/node_arrange.dart`、`util/canvas_arrange_actions.dart`、`shortcuts/arrange_keys.dart`、`canvas_menu/align_menu_entries.dart`。
- clipboard-text-paste：`lib/features/canvas/util/canvas_paste_actions.dart`、`lib/features/canvas/util/clipboard_snapshot.dart`、`lib/features/canvas/widgets/shortcuts/clipboard_keys.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`。
- 全波不归任何人：`lib/features/canvas/util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_shortcuts.dart` 骨架、注册表（除追加一行）。
- 本片额外不碰：`lib/core/interfaces/job_queue_service.dart`、`lib/features/generation/models/job_state.dart`（及 `.freezed.dart`）、`lib/features/generation/providers/jobs_registry.dart`、`lib/features/generation/generation_controller.dart`、`lib/features/shell/widgets/shell_task_capsule.dart`、`lib/services/job_queue/job_state_persister.dart`（库里 submitted_at / completed_at 的写法不动）。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// lib/core/interfaces/job_timing_source.dart
@immutable
class JobTiming {
  const JobTiming({required this.enqueuedAt, this.submittedAt, this.completedAt}); // 全 UTC
  final DateTime enqueuedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;
}
enum JobElapsedPhase { queued, running, finished }
typedef JobElapsed = ({JobElapsedPhase phase, int ms});
/// t == null ⇒ null；completedAt 有、submittedAt 无（排队中取消）⇒ null；负值夹到 0。
JobElapsed? jobElapsedOf(JobTiming? t, DateTime nowUtc);
abstract class JobTimingSource {
  JobTiming? timingOf(String jobId);
}

// lib/services/job_queue/job_timing.dart
const int kJobTimingTableCap = 500; // 超过时按入队序剔除最旧的已完成条目
class InMemoryJobTimingTable implements JobTimingSource {
  InMemoryJobTimingTable({required Clock clock});
  void markQueued(String jobId);    // 已存在则不动
  void markSubmitted(String jobId); // 未入队 / 已有提交时刻则不动
  void markCompleted(String jobId); // 未入队 / 已完成则不动（首写为准）
  @override
  JobTiming? timingOf(String jobId);
}

// lib/core/di/job_timing.dart
final jobTimingTableProvider = Provider<InMemoryJobTimingTable>(..., name: 'jobTimingTableProvider');
final jobTimingSourceProvider = Provider<JobTimingSource>(..., name: 'jobTimingSourceProvider');
```
- job_queue_service.dart 的三处（行号以 f64f56e 为准）：
  - 入队：`submit()` 里查重之后、`_pending.add(pendingJob)`（第 128 行）之前 `markQueued(task.jobId)`。
  - 提交：`_runJob()` 里 `persistTransition(... to: JobStatuses.submitted, extra: {JobCol.submittedAt: ...})`（第 253–258 行）之前 `markSubmitted(task.jobId)`。
  - 完成：所有终态都经两处发出——成功在第 456 行 `handle.emit(status)` 之前；失败 / 取消 / 超时 / dispose 都走 `_emitFailure`（第 499 行），在它第一行 `markCompleted(handle.jobId)`。第 446 行写 completed_at 的成功分支不另加，避免与第 456 行重复（首写为准也兜得住）。
- 弹层：`_TaskRow` 的 meta 改为三段式：
  - 非终态 + 计时阶段 queued：`provider · taskElapsedQueued(d)`；running：`provider · taskElapsedRunning(d)`；
  - 终态 + finished：`provider · 状态字 · taskElapsedTook(d)`；终态无耗时 / 查不到计时：保持现在的 `provider · 状态字`。
  - `d = formatElapsed(l, Duration(milliseconds: ms))`。新增私有 `_ElapsedMeta extends ConsumerStatefulWidget`：非终态行在 initState 起 `Timer.periodic(1 s)`、dispose 取消；终态行不起 Timer。现在时刻取 `clockProvider`。弹层本体由 OverlayPortal 按需建，关上即卸载，所以「开着才刷新」不需要额外开关。
- 监听器：成功卡 `meta: l.taskElapsedTook(formatElapsed(l, Duration(milliseconds: ms)))`，`ms` 取 `jobElapsedOf(timingOf(jobId), now)`，阶段不是 finished 就不传 meta。在 `await` 之前取好（同文件头注约定）。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 入队时刻 = `submit()` 被调用那一刻（时钟取 `clockProvider`）。同一 jobId 重复 submit 抛 StateError 时不改表。
2. 提交时刻 = 拿到并发槽、写 submitted_at 之前那一刻；排队期等槽的时间不计入「用时」。
3. 完成时刻在 handle 发出终态之前写入：`handle.done` 结算时 `timingOf(jobId).completedAt` 已非空。
4. 失败、超时、取消（运行中）、dispose 都写完成时刻；终态行「用时 = 完成 − 提交」。
5. 排队中取消：有完成时刻、无提交时刻 ⇒ `jobElapsedOf` 返回 null ⇒ 行上只写「已取消」。
6. 弹层：排队行「排队 N」= 现在 − 入队；运行行「已用 N」= 现在 − 提交；终态行时长固定不再走。
7. 弹层开着：非终态行每秒重画一次；关上后不存在任何周期 Timer（widget 测试结束无挂起 Timer）。
8. 计时表查不到（例如测试里没注入、或被上限剔除）：行退回现在的「provider · 状态字」，不报错。
9. 格式：59 999 ms 写「59 秒」，60 000 ms 写「1:00」，72 000 ms 写「1:12」（由 `formatElapsed` 的向下取整保证——换成四舍五入的 `formatDurationLabel` 会把 59 999 ms 写成「1:00」；本片只测接线，但要有一条 59 999 ms 的用例钉住用的是 formatElapsed）。
10. 并发：两个 job 同时跑，各自计时互不影响；全局并发上限卡住的第三个保持「排队」并持续走秒。
11. 表上限 500：超过时只剔除已完成的最旧条目，进行中的永不剔除。
12. 完成卡：成功卡 meta 为「用时 1:12」；失败卡不变；取消不出卡（现有行为）。
13. 不进撤销栈。mac / Windows 无差异（纯内存、墙钟取注入时钟）。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| taskElapsedQueued（占位 duration） | Queued {duration} | 排队 {duration} |
| taskElapsedRunning（占位 duration） | Elapsed {duration} | 已用 {duration} |
| taskElapsedTook（占位 duration） | Took {duration} | 用时 {duration} |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/services/job_queue/job_timing_test.dart`
  - 「jobElapsedOf 排队阶段 = now − enqueued」：入队 T0，now = T0+8 s ⇒ (queued, 8000)。
  - 「运行阶段 = now − submitted，不含排队」：入队 T0、提交 T0+5 s、now = T0+77 s ⇒ (running, 72000)。
  - 「终态 = completed − submitted」：提交 T0+5、完成 T0+128 ⇒ (finished, 123000)，与 now 无关。
  - 「排队中取消 ⇒ null」「t 为 null ⇒ null」「时钟回拨夹到 0」。
  - 「markSubmitted / markCompleted 首写为准、未入队 no-op」。
  - 「超上限只剔除已完成的最旧条目」：塞 501 条（第 1 条进行中），断言第 1 条还在、最旧的已完成条目没了。
- `test/services/job_queue_service_timing_test.dart`（FakeClock + 现有 job_queue_service_test 的假 provider 写法）
  - 「submit 记入队时刻」：submit 后立即 `timingOf` 的 enqueuedAt == FakeClock 当前值。
  - 「排队时间不计入用时」：并发 1，两个 job；第二个等 10 s 才拿到槽、再跑 3 s ⇒ finished.ms == 3000。
  - 「done 结算时已有完成时刻」：在 `handle.done.then` 回调里断言 completedAt 非空（成功、失败各一条）。
  - 「排队中 cancel：有完成、无提交」。
  - 「不注入 timing 时行为不变」：现有用例全绿（不改它们）。
- `test/features/shell/shell_task_popover_elapsed_test.dart`（ProviderScope 覆盖 jobsRegistryProvider、jobTimingSourceProvider、clockProvider=FakeClock）
  - 「排队行写 排队 8 秒」「运行行写 已用 1:12」「失败行写 失败 · 用时 2:03」「排队中取消行只写 已取消」。
  - 「开着每秒走」：FakeClock.advance(1 s) + `tester.pump(1 s)` ⇒「已用 1:13」。
  - 「终态行不走」：advance 10 s 后文字不变。
  - 「查不到计时退回老 meta」。
- `test/features/notifications/widgets/job_notification_listener_elapsed_test.dart`
  - 「成功卡 meta = 用时 1:12」（RecordingToastService.shown.single.meta）。
  - 「失败卡 meta 为 null」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. `jobElapsedOf` 终态分支把 `completedAt − submittedAt` 改成 `completedAt − enqueuedAt` ⇒「排队时间不计入用时」「终态 = completed − submitted」红。
2. 删掉 `_runJob` 里的 `markSubmitted` ⇒「运行阶段 …」（服务测试）与弹层「已用」用例红。
3. 把 `_emitFailure` 里的 `markCompleted` 挪到 `handle.complete` 之后 ⇒「done 结算时已有完成时刻（失败）」红。
4. 删掉第 456 行前的 `markCompleted` ⇒「done 结算时已有完成时刻（成功）」红。
5. `_ElapsedMeta` 不起 Timer ⇒「开着每秒走」红。
6. 终态行也起 Timer 并读 now ⇒「终态行不走」红（或 widget 测试报挂起 Timer）。
7. 排队中取消分支返回 (finished, 0) 而不是 null ⇒「排队中取消行只写 已取消」红。
8. 监听器不传 meta ⇒「成功卡 meta = 用时 1:12」红。
9. 上限剔除不区分进行中 ⇒「超上限只剔除已完成的最旧条目」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/services test/features/shell test/features/notifications --exclude-tags golden`。
- `grep -n "不显示耗时" lib/features/shell/widgets/shell_task_popover.dart` 无结果。
- 截图：`ShellTaskPopover`，四行数据——排队 8 秒（Gemini）、运行已用 1:12（万相 2.2，progress 0.4）、失败用时 2:03（可灵）、排队中取消；深浅主题各一张。另截一张成功通知卡（`InkToastCard` 经 ToastLayer）带「用时 1:12」。

## 风险与不确定
- `formatElapsed(l, Duration)` 的确切签名与 en 文案以 W0 duration-format 落地为准；本片只调用它，不用 `formatDurationLabel`（后者是片长 / 估时口径，四舍五入）。
- 计时取注入时钟，库里 submitted_at / completed_at 仍是 `DateTime.now()`（job_state_persister / job_queue_service 原样），两者可能差几毫秒；W9 job-eta 读的是库里的值，不读本表。
- 弹层行状态字与计时阶段可能不一致（注册表 queued、计时 running），按「设计依据」第一条缺口以计时为准；若主 Agent 想让状态字也跟着变，需要改 generation_controller（W8 不归本片）。
- W10 batch-run-executor 也改 shell_task_popover.dart（行分组）：本片把耗时逻辑收在私有 `_ElapsedMeta` 里，方便它 rebase。
