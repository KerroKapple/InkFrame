# batch-run-executor · 批量运行执行器
- 波次 W10 / lane A / 基底：origin/main（W0–W9 已合入）；依赖切片：batch-run-planner（W9：`BatchRunStep`）、tc-take-edge-follow（W5：新 take 到达时把下游 data 边挪过去）、gen-inputs-snapshot（W2：建 job 的事务里写 gen_inputs）、job-timing（W8：已改过 shell_task_popover）；阻塞决定：TC-Q1 → A（改写边；下游读到的新 take 由 W5 tc-take-edge-follow 挪边保证，本片不改生成侧解析，只补「源是配置节点」那一种，见第 9 条）

## 目标（用户看到什么变化，2–4 行）
一次提交一整批：没有上游的节点立即进队；有上游的先等着，上游成功了再提交，读到的是新的当前 take；上游失败的，下游不提交。
任务弹层里，同一批的任务归在一个批次头下面。等上游的、上游失败没提交的也各有一行，可以一键「取消这一批」。
状态栏胶囊把等上游的节点也算进「排队」。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
`b2/project/TakesCost.dc.html`「花费预告 · 批量运行」：
- 顺序：批内有上游的，下游等它成功后用新的当前 take 再提交；整体受全局并发和 provider 上限约束。
- 上游失败，下游不提交。任务胶囊可以取消这一批（parameters.run_group，不用迁移）。
- 「需要你定」Q1：建议 A，改写连线，生成侧读边的代码不用改。
- 设计缺口：任务弹层里批次怎么画，画板没画（没有批次头，没有等上游、上游失败那两种行）。本片定为：一个批次头，加上成员行。成员行在成员提交前用节点名占位；提交后就是那个 job 的普通行，挂在批次头下面。
- 设计缺口：上游失败的下游那一行写什么，画板只写了规则。本片写「上游失败 · 未提交」，提交时报错（缺 Key、配置不合法）的写「提交失败」。
- 设计缺口：胶囊计数里算不算等上游的节点，画板没画。本片把它们算进「排队 M」，免得批次还没跑完胶囊就消失了。
- 设计缺口：应用退出后批次怎么办。批次只放在内存里，退出就丢了；已经提交的 job 按现有的孤儿回收处理，等上游的不会再提交。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/generation/providers/batch_run_controller.dart`（新建）：批次模型（手写不可变类，与 shell_state 同例外：build_runner 跑不了）、`batchRunSubmitterProvider`（提交缝，可在测试里 override）、`batchRunControllerProvider`（keepAlive）。
- `lib/features/generation/generation_controller.dart`：
  - `submitFromConfigNode`（现在在第 169 行）加命名参数 `String? runGroup`。
  - 建 job 时的 `parameters`（现在第 327–342 行）追加 `'run_group': ?runGroup`。
  - 第 9 条那一处小修，只在核对后确有需要时才做。
- `lib/features/shell/widgets/shell_task_popover.dart`：按批次分组；批次头带「取消这一批」；加上没有 job 的成员行。
- `lib/features/shell/widgets/shell_task_capsule.dart`：把等上游的成员数并进 `queued`。
- 测试：
  - `test/features/generation/providers/batch_run_controller_test.dart`（新建）。
  - `test/features/generation/generation_controller_test.dart`（追加 run_group 用例）。
  - `test/features/shell/shell_task_popover_batch_test.dart`（新建）。
  - `test/features/shell/shell_task_capsule_test.dart`（追加用例）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- next-shot：`util/next_shot.dart`、`providers/next_shot_controller.dart`、`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`、`shortcuts/next_shot_keys.dart`、`widgets/shot_config_inspector.dart`。
- tc-next-shot-first-frame：`util/next_shot_frame.dart`、`util/canvas_next_frame_actions.dart`、`canvas_menu/next_frame_menu_entries.dart`、`widgets/video_config_inspector.dart`。
- script-tables：`lib/storage/schema/*`、`lib/storage/migrations/*`、`lib/core/db/columns.dart`、`lib/core/di/repositories.dart`、`lib/core/interfaces/unit_of_work.dart`、`lib/storage/postgres_unit_of_work.dart`、`lib/services/project_archive_service.dart`、`lib/services/import/import_remapper.dart` 等。
- system-notifications：`pubspec.yaml`、`lib/main.dart`、`lib/features/notifications/providers/toast_center.dart`、`models/toast_entry.dart`、`models/notification_prefs.dart`、`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`、`lib/features/notifications/widgets/job_notification_listener.dart`。
- 全波禁区：
  - `util/canvas_tool_actions.dart`、`util/node_menu_model.dart`、`canvas_menu/node_menu_entries.dart`、`widgets/canvas_shortcuts.dart`（骨架和注册表）。
  - `lib/features/generation/models/job_state.dart` / `.freezed.dart`（不加字段）、`providers/jobs_registry.dart`、`lib/services/job_queue_service.dart`、`lib/core/interfaces/job_queue_service.dart`。
  - `services/batch_run_planner.dart`（W9 已定，只 import）。
- 同波新文件（别片新建，本片不碰）：next-shot 的 `util/next_shot.dart` / `providers/next_shot_controller.dart` / `shortcuts/next_shot_keys.dart`；tc-next-shot-first-frame 的 `util/next_shot_frame.dart` / `util/canvas_next_frame_actions.dart` / `canvas_menu/next_frame_menu_entries.dart` / `models/commands/replace_role_edge_command.dart`；script-tables 的 `lib/storage/schema/schema_v10.dart` / `lib/core/interfaces/script_repository.dart` / `lib/storage/repositories/postgres_script_repository.dart` / `lib/features/storyboard/models/script_document.dart`；system-notifications 的 `lib/core/interfaces/system_notification_service.dart` / `lib/services/local_notifier_system_notification_service.dart` / `lib/services/noop_system_notification_service.dart` / `lib/core/di/system_notification.dart` / `lib/features/settings/providers/system_notify_pref_controller.dart`。注册表 `canvas_shortcut_registry.dart`、`menu_registry.dart` 本片不追加。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：script-tables：`lib/core/interfaces/project_archive_reader.dart`、`lib/core/models/import_plan_data.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/repositories/postgres_project_archive_reader.dart`、`lib/storage/repositories/postgres_project_import_writer.dart`；system-notifications：`lib/core/interfaces/toast_service.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/settings/widgets/notifications_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// generation_controller.dart
Future<String> submitFromConfigNode(String configNodeId, {int? seedOverride, String? runGroup});

// batch_run_controller.dart
enum BatchMemberStatus { waiting, submitting, submitted, succeeded, failed, cancelled, upstreamFailed, submitFailed }

@immutable class BatchMember {
  final String nodeId; final Set<String> dependsOn;
  final BatchMemberStatus status; final String? jobId;
  bool get isTerminal; // succeeded / failed / cancelled / upstreamFailed / submitFailed
}
@immutable class BatchRun {
  final String runGroup;            // UUID v4
  final String canvasId;
  final List<BatchMember> members;  // 与 planner steps 同序
  int get waitingCount; int get doneCount; int get failedCount; bool get isFinished; bool get isCancellable;
}

typedef BatchRunSubmit = Future<String> Function(String configNodeId, {required String runGroup});
final batchRunSubmitterProvider = Provider<BatchRunSubmit>(...);        // 默认：generationControllerProvider.future → submitFromConfigNode(id, runGroup: g)
final batchRunControllerProvider = NotifierProvider<BatchRunController, Map<String, BatchRun>>(...); // keepAlive，app 级

class BatchRunController extends Notifier<Map<String, BatchRun>> {
  /// 建批次并立刻提交所有 dependsOn 为空的成员；返回 runGroup。
  Future<String> start({required String canvasId, required List<BatchRunStep> steps});
  /// waiting → cancelled；submitting / submitted 且 job 还没到终态的 → JobQueueService.cancel(jobId)（幂等）。
  Future<void> cancel(String runGroup);
  /// 批次全部到终态后从表里移除（弹层「清除已完成」同时调用）。
  void dismissFinished();
  BatchRun? runOfJob(String jobId);
}
```
成员状态机：
```
waiting ──(所有上游 succeeded)──► submitting ──submit 返回 jobId──► submitted ──registry 终态──► succeeded / failed / cancelled
   │                                   └──抛 GenerationError / InkError──► submitFailed
   ├──(任一上游 failed / cancelled / upstreamFailed / submitFailed)──► upstreamFailed（递归传给它的下游）
   └──(cancel)──► cancelled
```
- 等上游：在 `build` 里对 `jobsRegistryProvider` 做 `ref.listen`。每次注册表变化时：把每个 submitted 成员的 jobId 对上它的 JobState；到了终态就改成员状态，然后重排调度。
- 已提交的 jobId 从注册表里消失，又没见过它的终态（被溢出剔除了）：按 failed 处理。
- 提交顺序：同一时刻能提交的成员，按 members 的顺序 await 着一个一个提交，保证 JobQueue 里的入队顺序就是计划顺序。并发不由本片控制。
- 第 9 条：核对 W5 tc-take-edge-follow 落地后的 `_resolveRefImages`。如果源是配置节点的 data 边，仍然读配置自己的 `image_url`（恒为空），就在这里改成：源是配置节点时，取它的当前 take，判据与 `currentResultFor` 同口径（pinned_result_id 活着就用它，否则取最新的、有 image_url 的 result 行）。在行级实现，不 import canvas 的 provider。
- 弹层：`orderTasks` 之前先分组。每个 BatchRun 一组，组内按 members 的顺序：有 jobId 的画原 `_TaskRow`，没有的画 `_BatchPendingRow`（节点名 + 状态字）。不属于任何批次的 job 照原来的样子排在后面。
- 批次头：`taskPopoverBatchTitle(done, total)`；还有能取消的成员时，右侧画「取消这一批」（cancelBatchKey(runGroup)）。
- 胶囊：`taskCapsuleSummaryOf` 签名不动；在 `build` 里另外 select 所有批次的 waitingCount 之和，把它加到 queued 上。新加一个顶层纯函数 `TaskCapsuleSummary withBatchWaiting(TaskCapsuleSummary s, int waiting)`。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. `start` 之后，dependsOn 为空的成员立即按序提交；有上游的保持 waiting，`submitFromConfigNode` 对它一次都没调过。
2. 上游 JobSucceeded 之后才提交下游：上游处于 queued、submitting、running 的时候都不提交。
3. 上游 failed / cancelled / submitFailed：下游变成 upstreamFailed，永远不提交，并且递归传到下游的下游。
4. 一个成员有两个上游，一个成功一个失败：变成 upstreamFailed。两个都成功才提交。
5. 每次 job 都在 `jobs.parameters.run_group` 里写入同一个 runGroup。不传 runGroup 时（单个生成），parameters 里不出现 `run_group` 这个键。
6. 提交抛 MissingApiKeyError / InvalidGenerationConfigError / ProviderNotRegisteredError / InkError：这个成员记 submitFailed，下游记 upstreamFailed，批次里别的分支照常跑。只捕获具体类型，不 catch Exception。
7. 取消这一批：所有 waiting 的变成 cancelled、不再提交；已提交但还没到终态的逐个调 `JobQueueService.cancel`；已经到终态的不动。对同一个批次 cancel 两次是幂等的。
8. 取消那一刻正有成员在 await submit：submit 返回 jobId 以后马上 cancel 这个 jobId（cancel 赢），这个成员最终记 cancelled，不会漏下一个在跑的 job。
9. 下游等到上游成功后提交时，读到的是 W5 已经挪好的边：`_track` 成功分支里挪边要先写库，再 upsert JobSucceeded。本片在 generation_controller_test 里钉住这个顺序；顺序不对时由本片改成「先挪边后 upsert」。
10. 并发：几个批次可以同时存在，互相独立（按 runGroup 分）。全局并发和 provider 上限仍由 JobQueue 管，本片不额外排队或节流。
11. 成员节点在等上游期间被删了：轮到它时 submit 抛 `config node not found`，按第 6 条处理。
12. 画布关了、换了项目：批次照常推进（controller 是 app 级 keepAlive，不依赖画布是否挂载）。
13. 已提交的 job 被注册表剔除，又没见到终态：按 failed 处理，下游记 upstreamFailed。
14. 弹层：批次头的计数是 doneCount / total。等上游的行写「等上游」，upstreamFailed 写「上游失败 · 未提交」，submitFailed 写「提交失败」。没有 job 的行没有「取消」「定位」。
15. 胶囊：只有等上游的成员（注册表是空的）时，胶囊照样画成活动态，显示「排队 M」。
16. 「清除已完成」：在 clearTerminated 之外，再 dismiss 掉已经全部到终态的批次。
17. 撤销栈：生成本来就不进撤销栈，本片也不进。mac / Windows 没有差异（本片不加快捷键）。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| taskPopoverBatchTitle | Batch run · {done}/{total} | 批量运行 · {done}/{total} |
| taskPopoverBatchCancel | Cancel batch | 取消这一批 |
| taskPopoverBatchWaiting | Waiting for upstream | 等上游 |
| taskPopoverBatchUpstreamFailed | Upstream failed · not submitted | 上游失败 · 未提交 |
| taskPopoverBatchSubmitFailed | Submit failed | 提交失败 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
`test/features/generation/providers/batch_run_controller_test.dart`：ProviderContainer + 真的 JobsRegistry；override `batchRunSubmitterProvider` 为记录器（返回 `job-<id>`），override jobQueueServiceProvider 为记 cancel 的 fake。
- `无依赖的立即提交，有依赖的等着`：steps [U, D←U] → 提交记录只有 U。
- `上游非终态不放行`：依次 upsert U 为 queued / running，D 仍是 waiting。
- `上游成功后提交下游且带同一 runGroup`：upsert JobSucceeded(U) → 记录 [U, D]，两次的 runGroup 相同。
- `上游失败下游不提交`：JobFailed(U) → D 是 upstreamFailed，提交记录里没有 D。
- `失败递归传递`：U → D → E，U 失败 → D、E 都是 upstreamFailed。
- `两个上游一成一败`。
- `提交抛错记 submitFailed`：记录器对 D 抛 InvalidGenerationConfigError → D submitFailed，E←D upstreamFailed，另一条分支照跑。
- `取消这一批`：waiting 变 cancelled；已提交的 jobId 收到 cancel；第二次 cancel 不重复调用。
- `取消与在途 submit 竞态`：记录器用 Completer 挂住，这时 cancel，再完成 → 返回的 jobId 被 cancel，成员是 cancelled。
- `job 被剔除按失败处理`。
- `多个批次互不干扰`。

`test/features/generation/generation_controller_test.dart` 追加：
- `submitFromConfigNode 带 runGroup 写进 parameters`：`jobs.creates.first['parameters']['run_group'] == 'g1'`。
- `不带 runGroup 时没有 run_group 键`。
- `成功分支先挪边再 upsert succeeded`：fake 边仓记录 update 的时刻，registry 记录 upsert 的时刻，比较两者先后（只在 W5 落地后的代码上补）。
- （若做了第 9 条）`源是配置节点的首帧边解析到它的当前 take`。

`test/features/shell/shell_task_popover_batch_test.dart`：
- `批次头与成员行`：一个批次（U 已提交 running，D 等上游）→ 批次头写「批量运行 · 0/2」，D 那一行写「等上游」，没有取消按钮。
- `取消这一批调 controller.cancel`。
- `上游失败行文案`。

`test/features/shell/shell_task_capsule_test.dart` 追加：
- `等上游的成员算进排队`：注册表为空、有 1 个 waiting → 胶囊是活动态，显示「排队 1」。
- `withBatchWaiting 纯函数`。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. 调度条件「所有上游 succeeded」改成「所有上游 isTerminal」→ 「上游失败下游不提交」红。
2. 改成「上游已提交就放行」→ 「上游非终态不放行」红。
3. parameters 里删掉 `'run_group': ?runGroup` → 「带 runGroup 写进 parameters」红。
4. upstreamFailed 不递归 → 「失败递归传递」红。
5. 提交抛错时不改成员状态（停在 submitting）→ 「提交抛错记 submitFailed」红。
6. cancel 只处理 waiting、不调 JobQueueService.cancel → 「取消这一批」红。
7. 删掉竞态补丁（submit 返回以后不检查批次是否已取消）→ 「取消与在途 submit 竞态」红。
8. jobId 消失时不处理 → 「job 被剔除按失败处理」红。
9. 胶囊不加 waiting → 「等上游的成员算进排队」红。
10. 弹层不画没有 job 的成员行 → 「批次头与成员行」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test` 干净；`test/features/generation/`、`test/features/shell/` 全绿；上面 10 条变异逐条变红。
- 验收要点：上游失败，下游不提交；run_group 写进 parameters。
- 截图（ShellTaskPopover，单独挂在 ProviderScope 里，override batchRunControllerProvider 和 jobsRegistryProvider 的初值）：
  - ① 批次进行中：U running、D 等上游、E 等上游。
  - ② U 失败：D、E 是「上游失败 · 未提交」，批次头没有「取消这一批」。
  - ③ 批次 + 两个零散 job 混排。
  - 再截状态栏胶囊：只剩等上游的成员时的样子。

## 风险与不确定
- generation_controller.dart 在 W10 归本片，W11 归 mention-token-core。本片改动只限：签名加一个参数、parameters 加一个键、第 9 条一处，以免 rebase 冲突。
- W8 job-timing 已经改过 shell_task_popover（耗时 / 排队时间）。本片以它合入后的版本为基底，分组时保留它的计时字段。
- 第 9 条取决于 W5 的实际落地。如果 W5 已经覆盖了「源是配置节点」的边，这一条就不做，在 PR 描述里写明。
- 提交前的挂起编辑（防抖还没落盘的提示词）不归本片管：batch-run-dialog 在调 `start` 之前先冲刷。本片直接调 `submitFromConfigNode`，读的是库里那一行。
- 批次只放在内存里，应用重启就丢；要做持久化，得另开一片按 run_group 从 jobs 表恢复。
