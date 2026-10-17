# job-eta · 按 provider 历史估算耗时
- 波次 W9 / lane B / 基底：叠在 batch-run-planner 之后（文件不相交，只为同 lane 串行）；依赖切片：duration-format（W0，`lib/l10n/duration_format.dart`）；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
- 本片不直接上屏：提供「这个 provider 一次大概要多久」的估算，供 W11 batch-run-dialog 的「预计 4:10」和后续入口用。
- 估算 = jobs 表同 provider 最近 10 次成功任务 `completed_at − submitted_at` 的中位数；没有历史就显示「—」。
- 显示格式统一用 W0 的 `formatDurationLabel(l, ms, estimated: true)`。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/TakesCost.dc.html` · 运行对话框规则「耗时」：= jobs 表同 provider 最近 10 次 completed_at − submitted_at 的中位数；没历史写「—」。格式全应用共用：不到 60 秒写「N 秒」，满 60 秒写 m:ss。
- `b2/project/TakesCost.dc.html` · 运行对话框样稿底部「预计 4:10 · 并发 2 · 单次最多 50」。
- slices.json `tc-job-eta`：只算 status 是 completed 的行（库里成功态的值是 `success`，见 `lib/core/constants/job_statuses.dart`）；索引用现有 `idx_jobs_completed`，不加新索引。
- 设计缺口：对话框「预计 4:10」是全批合计，画板没给合计公式（每行估算怎么按并发折算、未知行怎么算）。本片只给单 provider 估算，合计公式留给 W11 batch-run-dialog 定。
- 设计缺口：同 provider 下批量数（batch_size）与视频时长（5 秒 / 10 秒）差异很大，画板只说「同 provider」。本片照画板不分桶，写进风险。
- 设计缺口：加载中 / 读库失败该显示什么画板没画。本片定：都显示「—」，不出错误条。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- 新 `lib/core/interfaces/job_duration_history.dart`：小接口 `JobDurationHistory`，一个方法 `recentDurationsMs`。
- `lib/storage/repositories/postgres_job_repository.dart`：类声明改为 `implements JobRepository, JobDurationHistory`，加 `recentDurationsMs` 实现（一条 SELECT）。`JobRepository` 接口文件不动。
- 新 `lib/core/di/job_duration_history.dart`：`jobDurationHistoryProvider`（FutureProvider，从 `pgMigratedPoolProvider` 起一个 `PostgresJobRepository`，与 `lib/core/di/repositories.dart` 第 55–58 行同写法）。
- 新 `lib/features/generation/providers/provider_eta_provider.dart`：纯函数 `medianMs`、`providerEtaProvider`（按 providerId family）、显示用 `providerEtaLabel`。
- 测试（新建）：`test/features/generation/providers/provider_eta_provider_test.dart`、`test/storage/repositories/job_duration_history_sql_test.dart`、`test/storage/repositories/job_duration_history_integration_test.dart`（`@Tags(['pg'])`，无 TEST_PG_URL 时 markTestSkipped，照 postgres_repositories_integration_test 的 req() 写法）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- canvas-find-bar：`widgets/canvas_screen.dart`、`widgets/node_card_slot.dart`、`widgets/node_card.dart`、`util/escape_ladder.dart`。
- batch-run-planner（同 lane 前一片）：`lib/features/generation/services/batch_run_planner.dart`（只读，不 import 也不改）。
- dep-drop-pasteboard / os-drop-paste-image：`pubspec.yaml`、`pubspec.lock`、平台插件注册文件、`widgets/canvas_view.dart`、`widgets/shortcuts/clipboard_keys.dart`、`util/canvas_paste_actions.dart`。
- multi-select-inspector：`widgets/canvas_inspector_panel.dart`、`widgets/image_config_inspector.dart`、`widgets/video_config_inspector.dart`。
- rail-drag-characters / outline-rename-menu：`widgets/character_library_panel.dart`、`util/ref_image_budget.dart`、`widgets/left_rail/outline_panel.dart`、`providers/canvas_nodes_controller.dart`、`models/canvas_command.dart`。
- 全波不归任何人：`util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_shortcuts.dart` 骨架、注册表（除追加一行）。
- 本片额外不碰：`lib/core/interfaces/job_repository.dart`、`lib/core/di/repositories.dart`、`test/quality/job_repository_reachability_test.dart`、所有 schema / migrations 文件（不加索引、不加迁移）、`lib/services/job_queue/job_timing.dart`（W8 job-timing 的内存表，与本片无关）。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：rail-drag-characters：`lib/features/canvas/widgets/characters_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// lib/core/interfaces/job_duration_history.dart
abstract class JobDurationHistory {
  /// 同 provider 最近 [limit] 次成功任务的 completed_at − submitted_at（毫秒），按 completed_at 新 → 旧。
  /// 只算 status = success 且两列都非空、completed_at ≥ submitted_at 的行；limit 夹在 1..50。
  Future<List<int>> recentDurationsMs(String providerId, {int limit = 10});
}

// lib/core/di/job_duration_history.dart
final jobDurationHistoryProvider = FutureProvider<JobDurationHistory>(..., name: 'jobDurationHistoryProvider');

// lib/features/generation/providers/provider_eta_provider.dart
const int kProviderEtaSampleSize = 10;
/// 空 ⇒ null；奇数取中间；偶数取中间两个的平均（四舍五入到整毫秒）。不改入参。
int? medianMs(List<int> samples);
/// 估算毫秒；没历史 ⇒ null。
final providerEtaProvider = FutureProvider.autoDispose.family<int?, String>(..., name: 'providerEtaProvider');
/// 显示串：loading / error / null ⇒ providerEtaUnknown（「—」）；否则 formatDurationLabel(l, ms, estimated: true)。
String providerEtaLabel(AppLocalizations l, AsyncValue<int?> eta);
```
- SQL 骨架（`guard('recentDurationsMs', 'jobs', ...)` 包住，与同文件其他方法一致）：
  `SELECT (EXTRACT(EPOCH FROM (completed_at - submitted_at)) * 1000)::bigint FROM jobs WHERE provider_id = @pid AND status = '${JobStatuses.success}' AND submitted_at IS NOT NULL AND completed_at IS NOT NULL AND completed_at >= submitted_at ORDER BY completed_at DESC LIMIT @lim`。
  ORDER BY completed_at 走现有部分索引 `idx_jobs_completed`（`lib/storage/schema/schema_v1.dart:203` / `001_init.sql:181`）。
- `providerEtaProvider` 刷新：watch `jobsRegistryProvider.select(...)` 取「该 providerId 的 JobSucceeded 个数」，个数变了就重算——新完成一次估算立即跟上，别的 provider 完成不触发。
- 读库抛 InkError（`guard` 翻译出来的）：provider 进 AsyncError，`providerEtaLabel` 照样给「—」；不吞非 InkError。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 只算成功：error / cancelled / timeout / 进行中的行一律不进样本。
2. 只取同 provider：providerId 精确匹配（自定义接口按它自己的 providerId 算）。
3. 取最近 10 条：按 completed_at 倒序；第 11 条及更早的不影响结果。
4. 中位数：[3,1,2] ⇒ 2；[1,2,3,4] ⇒ 3（2.5 四舍五入）；[] ⇒ null。
5. 没历史（0 条）⇒ 显示「—」；1 条 ⇒ 就是那一条。
6. 脏数据：submitted_at 为空（排队中被取消的老行）或 completed_at < submitted_at（时钟回拨）不进样本。
7. 新完成一次同 provider 任务后 provider 重算；别的 provider 完成不重算（计数 select 隔开）。
8. 加载中、读库失败 ⇒「—」，不弹错误卡、不写日志以外的东西。
9. 显示走 `formatDurationLabel(estimated: true)`：45 000 ⇒ 估算 45 秒；250 000 ⇒ 估算 4:10（「~」前缀与否以 W0 落地为准）。
10. jobs 表没有 deleted_at：已删画布的历史任务照样计入（这是 provider 速度统计，不是画布数据），表按 30 天 / 每画布 500 条自动清（purgeExpired / purgePerCanvasCap），样本自然滚动。
11. 不进撤销栈。mac / Windows 无差异。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| providerEtaUnknown | — | — |

（若 W2 node-cost 已有同义的「—」键，主 Agent 合并成一个，以落地为准。）

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/generation/providers/provider_eta_provider_test.dart`
  - 「medianMs 奇数取中间」[3,1,2] ⇒ 2；「偶数取平均四舍五入」[1,2,3,4] ⇒ 3；「空 ⇒ null」；「不改入参顺序」。
  - 「providerEtaProvider 用最近 10 条的中位数」：覆盖 `jobDurationHistoryProvider` 为假实现，返回 10 个值，断言结果；断言假实现收到 `limit: 10` 与正确 providerId。
  - 「没历史 ⇒ null，label = —」。
  - 「读库抛 InkError ⇒ label = —」。
  - 「同 provider 完成一次 ⇒ 重算」：往 jobsRegistry upsert 一个该 provider 的 JobSucceeded，假实现被调用次数 +1；upsert 别的 provider 的成功 ⇒ 次数不变。
  - 「label 走 estimated」：ms = 250 000 ⇒ 与 `formatDurationLabel(l, 250000, estimated: true)` 相等。
- `test/storage/repositories/job_duration_history_sql_test.dart`（自带 Session spy，照 repository_sql_templates_test 的 _SpySession 写法）
  - 「只取 success」：lastSql 含 `status = 'success'`。
  - 「同 provider + 两列非空 + 不倒挂」：含 `provider_id = @pid`、`submitted_at IS NOT NULL`、`completed_at >= submitted_at`。
  - 「按 completed_at 倒序 + LIMIT」：含 `ORDER BY completed_at DESC`、params['lim'] == 10；传 limit: 999 ⇒ 50，传 0 ⇒ 1。
  - 「返回行 → int 列表」：spy 返回 [[72000],[18000]] ⇒ [72000, 18000]。
- `test/storage/repositories/job_duration_history_integration_test.dart`（pg 标签）
  - 造 12 条 success（耗时 1..12 s）+ 1 条 error + 1 条别的 provider，断言返回最近 10 条、不含 error 与别的 provider。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. SQL 去掉 `status = 'success'` 条件 ⇒「只取 success」与集成测红。
2. `ORDER BY completed_at DESC` 改成 `ASC` ⇒「按 completed_at 倒序」与集成测红。
3. `medianMs` 偶数分支改成取 `samples[n ~/ 2]` ⇒「偶数取平均四舍五入」红。
4. `medianMs` 不排序直接取中间 ⇒「奇数取中间」红。
5. provider 不 watch 注册表计数 ⇒「同 provider 完成一次 ⇒ 重算」红。
6. select 改成数全部 provider 的成功 ⇒ 同一用例「别的 provider 不重算」红。
7. `providerEtaLabel` 不传 `estimated: true` ⇒「label 走 estimated」红。
8. limit 不夹 ⇒ 「LIMIT 夹在 1..50」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/features/generation test/storage/repositories --exclude-tags golden`；有 TEST_PG_URL 的环境加跑 pg 标签。
- `test/quality/job_repository_reachability_test.dart` 不改仍绿（新方法不在 JobRepository 接口上）。
- 无 UI，不截图；W11 batch-run-dialog 合入后在它的截图里看「预计」。

## 风险与不确定
- 新方法挂在 `PostgresJobRepository` 上但不进 `JobRepository` 接口，所以 job_repository_reachability_test 的「每个方法都有生产调用点」闸管不到它；生产调用点只有 `providerEtaProvider`，W11 之前它没有屏幕消费者（这一波里是「有调用点、没观众」）。主 Agent 若嫌它悬空，可要求 W11 合入前不发版。
- 不按 batch_size / 视频时长分桶，批量 4 张与单张混在一起取中位数，估算会偏；画板没要求，留作后续。
- `idx_jobs_completed` 是 completed_at 上的部分索引，provider_id 过滤要回表；jobs 每画布最多 500 条、30 天清，量级可接受，不加索引（ADR-0012：加索引要新迁移，本片不做）。
- 「—」是否做 ARB 键、`estimated: true` 的确切呈现，以 W0 / W2 落地为准。
