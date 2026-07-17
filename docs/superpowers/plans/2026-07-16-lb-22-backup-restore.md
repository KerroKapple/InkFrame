# LB-22 备份还原路径（app 内）Implementation Plan · rev2

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> rev2 = 初版经三镜头设计评审（数据安全/生命周期/UX，2026-07-16，10×P1）全面修订。初版的
> `--clean` 案、keep-7 混池、widget 级 busy、「invalidate 即成功」语义全部废弃，勿回退。

**Goal:** app 内完成备份的另一半——列出备份、立即备份、一键还原（设置页 + 启动失败视图），还原失败时用户数据分毫无损。

**Architecture:** 三族命名分池备份（daily/manual/prerestore 各自保留配额 + `.meta.json` sidecar 记 sha256/schemaVersion）。还原核心=「**scratch 库 + 改名对换**」：`pg_restore --single-transaction` 灌进 `inkframe_restore_tmp`，成功才 rename 对换原库（失败=原库未动）；对换后旧库 DROP。编排 `DatabaseRestoreFlow`（flow 级单飞）：settle 链 → 目标校验 → 预备份（设置页失败即中止/启动面 best-effort）→ 终结 JobQueue → 关池 → swap-restore → invalidate 链 → **await 重建成功才算 restored** → 预热 JobQueue。UI：barrier 模态罩住全程；确认框亮出目标备份名+日期。

**Tech Stack:** postgres v3（维护连接走 template1）、ProcessRunner、crypto（sha256）、Riverpod。

## Global Constraints

- 分支 `feat/lb-22-backup-restore`；conventional commits；每 commit 过 `flutter analyze lib test` + `flutter test --exclude-tags golden`（flutter 绝对路径）。
- 注释中文；内部字符串 English-only；ARB en+zh 同 commit + gen-l10n。零硬编码样式。InkError 链。plain test() 做真 IO（TD-003）。
- 备份=housekeeping 失败不阻断；**还原=显式动作，失败必须可见**（app 级 toast 跨 gate 存活——UX 评审已核实机制成立）。
- ProcessRunner 无超时是既有债（BOARD EX-3 行），本卡不修，挂死风险由 barrier 模态 + 债表登记承接。

## 语义拍板 rev2（勿再摇摆）

1. **还原 = scratch 库对换**（数据安全 P1-1/P1-2 终案）：
   `DROP DATABASE IF EXISTS inkframe_restore_tmp` → `CREATE DATABASE inkframe_restore_tmp` →
   `pg_restore --single-transaction -d inkframe_restore_tmp <file>`（失败→DROP tmp，原库未动）→
   若 `postgres` 库存在：`ALTER DATABASE "postgres" RENAME TO "<retired>"`（retired=`inkframe_retired_<ts>`）→
   `ALTER DATABASE "inkframe_restore_tmp" RENAME TO "postgres"` → `DROP DATABASE "<retired>"`（drop 失败仅 warn）。
   **自愈**：进门发现 `postgres` 不存在（上次对换夹缝崩溃）→ 跳过 rename-away 直接把 tmp/还原产物换上。
   维护 SQL 全部经 template1 的一次性 Connection（注入 seam，可 fake）。
2. **三族命名分池**：daily `inkframe-YYYY-MM-DD.dump`（keep 7，不变）/ manual `inkframe-manual-YYYY-MM-DD-HHMMSS.dump`（keep 3）/ prerestore `inkframe-prerestore-YYYY-MM-DD-HHMMSS.dump`（keep 3）。剪枝按族独立——预备份永不吃每日历史，也永不删还原目标（数据 P1-3、UX P1-3）。
3. **sidecar `<name>.meta.json`**：`{"sha256","schemaVersion","appVersion","createdAtUtc"}`，成功发布后写、剪枝连带删。还原前：sidecar 存在则校验 sha256（不符→failedCorrupt）与 schemaVersion≤当前（超→failedVersionNewer，拒绝降级循环）；无 sidecar（存量备份）跳过校验。
4. **预备份分策略**（数据 P1-4）：检查**返回值**（backup 服务失败是返回值不是异常，try/catch 是死代码）。设置页 `requirePreBackup=true`：非 created → `abortedPreBackup` 中止；启动面 false：warn 继续（库已坏 dump 不出来不拦路）。
5. **restored = 链重建成功**（UX P2-1 / 生命周期 P2-3）：flow 在 invalidate 后 `await pgMigratedPoolProvider.future`，失败翻 failed。toast 从此等价于验收「数据可见」。
6. **「重建在途」三态守卫**（生命周期 P1-1/P1-2）：flow 进门 settle 链（await pgPoolProvider.future，错误吞成 null）；flow 级单飞（`_inflight ??=`，两入口共享）；`PgController.start()` 加单飞 memo；busy 用 app-scoped provider 展示。
7. **JobQueue 先终结再关池**（生命周期 P1-3）：flow 关池前 `jobQueueServiceProvider.valueOrNull?.dispose()`（dispose 需幂等，无则加 `_disposed` 卫）；顺手修 HI-01 盲区两处（`_runJob` 两个 catch 里 `persistFailure` 包 try 保 `_emitFailure` 必达；`dispose` 里 `unawaited(persistCancel)` 补 `catchError`）。
8. **还原范围=仅数据库**：媒体目录不回滚——确认框文案言明；BOARD 给 LB-13 记「reaper 转真删前必须 restore-aware」不变量债。

---

### Task 1: ✅ 已完成（2d4fc0b）——locator.pgRestore getter

### Task 2: 备份服务 rev2——三族命名 / sidecar / backupNow(kind) / 分池剪枝

**Files:**
- Modify: `lib/core/interfaces/database_backup_service.dart`、`lib/services/database_backup_service.dart`
- Modify: `pubspec.yaml`（`flutter pub add crypto`）
- Test: `test/services/database_backup_service_test.dart`

**Interfaces（Produces）:**

```dart
enum BackupKind { daily, manual, preRestore }

class BackupFileInfo {
  const BackupFileInfo({required this.name, required this.kind,
    required this.sizeBytes, required this.modified});
  final String name; final BackupKind kind;
  final int sizeBytes; final DateTime modified;
}

class BackupNowResult {
  const BackupNowResult({required this.outcome, this.fileName});
  final BackupOutcome outcome; final String? fileName; // created 时非空
}

abstract class DatabaseBackupService {
  Future<BackupOutcome> backup(BackupConnection connection);          // 每日（原样）
  Future<BackupNowResult> backupNow(BackupConnection connection,
      {required BackupKind kind});                                    // manual / preRestore
  List<BackupFileInfo> listBackups();                                 // 新→旧，仅识别名
}
// 服务文件顶层纯函数：
BackupKind? backupKindOf(String name);        // 识别名→族，非法→null
String backupSortKey(String name);            // date + (time ?? '000000')
```

- [ ] 红测：`backupNow(manual)` 命名/当日不跳过/写 `<name>.meta.json`（含 sha256=实际文件哈希、schemaVersion=kAppMigrations.last.version）；`backupNow(preRestore)` 命名族；**分池剪枝**——7 daily + 4 manual + 4 prerestore 混布 → daily 不动、manual/prerestore 各剪到 3、sidecar 连带删；`listBackups` 过滤/排序/kind；`backupKindOf` 拒绝穿越与杂名。
- [ ] 实现：`_dumpTo(target, conn)` 抽取复用；发布成功后算 sha256（`crypto` 包，`sha256.convert(bytes)`——备份文件 MB 级，一次读入可接受）写 sidecar；`_applyRetention` 改按族分组各按 cap 剪（cap：daily 7 / manual 3 / preRestore 3 常量）。
- [ ] 跑绿 → Commit `feat(storage): LB-22 备份服务 rev2——三族分池 + meta sidecar + backupNow`

### Task 3: DatabaseRestoreService——scratch 库对换

**Files:**
- Create: `lib/core/interfaces/database_restore_service.dart`
- Create: `lib/services/database_restore_service.dart`
- Test: `test/services/database_restore_service_test.dart`

**Interfaces（Produces）:**

```dart
enum RestoreOutcome {
  restored, failed, failedNoBinaries, failedCorrupt, failedVersionNewer,
  abortedPreBackup, // flow 层用；service 不返回
}

abstract class DatabaseRestoreService {
  /// 校验（识别名/存在/sidecar sha+version）→ scratch 灌入 → 对换。
  /// 除 restored 外原库保证未被改动（对换夹缝崩溃除外，见自愈）。
  Future<RestoreOutcome> restore(BackupConnection connection, String backupFileName);
}
```

实现 `PgSwapRestoreService`（构造注入 paths/locator/runner/clock/logger + `MaintenanceSessionFactory`）：

```dart
/// 维护连接 seam：默认实现连 template1 执行 CREATE/DROP/ALTER DATABASE。
typedef MaintenanceSessionFactory = Future<Connection> Function(BackupConnection conn);
```

流程（拍板 1 全文）；日志 module `db.restore`；库名常量 `kRestoreTmpDb='inkframe_restore_tmp'`、retired 前缀 `inkframe_retired_`。自愈分支：`SELECT 1 FROM pg_database WHERE datname=@n` 探测。

- [ ] 红测（fake runner + fake 维护连接记录 SQL 序）：
  - 成功序：`DROP IF EXISTS tmp → CREATE tmp → pg_restore(--single-transaction, -d tmp) → rename postgres→retired → rename tmp→postgres → DROP retired`；PGPASSWORD 经 env；trust=null 不设
  - pg_restore 非零退出 → `DROP tmp`、**无任何 rename**、failed
  - sidecar sha 不符 → failedCorrupt，进程零调用；schemaVersion>当前 → failedVersionNewer
  - 无 sidecar 存量备份 → 跳过校验直走
  - 非法名/文件缺失 → failed 零调用；无二进制 → failedNoBinaries
  - 自愈：探测 `postgres` 不存在 → 跳过 rename-away
  - DROP retired 失败 → 仍 restored（仅 warn）
- [ ] 实现 → 跑绿 → Commit `feat(storage): LB-22 PgSwapRestoreService——scratch 库对换,失败原库未动`

### Task 4: 生命周期前置加固（PgController 单飞 + JobQueue HI-01 盲区）

**Files:**
- Modify: `lib/storage/pg_controller.dart`（start 单飞）
- Modify: `lib/services/job_queue_service.dart`（dispose 幂等 + persistFailure 包 try + unawaited catchError）
- Test: `test/storage/pg_controller_test.dart`、`test/services/job_queue_service_test.dart` 各加用例

- [ ] 红测：并发两次 `start()` → pg_ctl 只跑一次、拿同一 runtime；start 失败后单飞清空可重试。dispose 两次调用无副作用；`_runJob` 中 persistFailure 抛 StateError 时 handle 仍收到 failure（fake state persister 抛错注入）。
- [ ] 实现：`Future<PgRuntime>? _startInflight; start() { return _startInflight ??= _doStart().whenComplete(() => _startInflight = null); }`（注意 whenComplete 清 memo=单飞非永久缓存）。JobQueue：`bool _disposed` 卫；两个 catch 内 `try { await _state.persistFailure(...) } catch (_) { /* 池已关：内存路径必达优先 */ } _emitFailure(handle, err);`；`unawaited(_state.persistCancel(...).catchError((_) {}))`。
- [ ] 跑绿 → Commit `fix(storage): LB-22 前置——PgController.start 单飞 + JobQueue 关池场景 handle 必达`

### Task 5: DatabaseRestoreFlow rev2 + busy provider

**Files:**
- Create: `lib/core/di/database_restore.dart`
- Test: `test/core/di/database_restore_flow_test.dart`

**Interfaces（Produces）:**

```dart
class RestoreFlowResult {
  const RestoreFlowResult({required this.outcome, this.preBackupFileName});
  final RestoreOutcome outcome; final String? preBackupFileName;
}
final databaseRestoreBusyProvider = StateProvider<bool>((_) => false);
final databaseRestoreServiceProvider = Provider<DatabaseRestoreService>(...);
final databaseRestoreFlowProvider = Provider<DatabaseRestoreFlow>(...);
class DatabaseRestoreFlow {
  Future<RestoreFlowResult> run(String backupFileName, {required bool requirePreBackup});
}
```

flow 主体（拍板 4/5/6/7 全文）：

```dart
Future<RestoreFlowResult> run(String f, {required bool requirePreBackup}) {
  return _inflight ??= _run(f, requirePreBackup: requirePreBackup)
      .whenComplete(() => _inflight = null);
}

Future<RestoreFlowResult> _run(String f, {required bool requirePreBackup}) async {
  _ref.read(databaseRestoreBusyProvider.notifier).state = true;
  try {
    // 0) 服务器可用 + settle 链（生命周期 P1-1：loading 必须等出确定态）。
    final controller = _ref.read(pgControllerProvider);
    final PgRuntime runtime;
    try { runtime = controller.runtime ?? await controller.start(); }
    on PgLifecycleError { ...log; return failed; }
    Pool<void>? pool;
    try { pool = await _ref.read(pgPoolProvider.future); } catch (_) { pool = null; }
    final conn = BackupConnection(host/port/kPgSuperuser/kPgDatabaseName/runtime.password);
    // 1) 预备份（拍板 4：查返回值）。
    String? preName;
    final pre = await _ref.read(databaseBackupServiceProvider)
        .backupNow(conn, kind: BackupKind.preRestore);
    preName = pre.fileName;
    if (pre.outcome != BackupOutcome.created) {
      log.warn(...);
      if (requirePreBackup) return RestoreFlowResult(outcome: abortedPreBackup);
    }
    // 2) 终结 JobQueue（拍板 7）→ 3) 关池。
    _ref.read(jobQueueServiceProvider).valueOrNull?.dispose();
    if (pool != null) await pool.close();
    // 4) swap-restore。
    final outcome = await _ref.read(databaseRestoreServiceProvider).restore(conn, f);
    // 5) 无条件重建链 + await 出确定态（拍板 5）。
    _ref.invalidate(pgPoolProvider);
    _ref.invalidate(pgMigratedPoolProvider);
    try { await _ref.read(pgMigratedPoolProvider.future); }
    catch (_) { return RestoreFlowResult(outcome: RestoreOutcome.failed, preBackupFileName: preName); }
    // 6) 预热 JobQueue（孤儿回收立刻跑，画廊无幽灵 job）。
    unawaited(_ref.read(jobQueueServiceProvider.future).catchError((_) {}));
    return RestoreFlowResult(outcome: outcome, preBackupFileName: preName);
  } finally {
    _ref.read(databaseRestoreBusyProvider.notifier).state = false;
  }
}
```

- [ ] 红测（fake 全套 + `_FakePool implements Pool<void>` noSuchMethod）：成功序 `preBackup → jq.dispose → pool.close → restore → invalidate×2 → await migrated`；requirePreBackup 且 pre failed → abortedPreBackup 且 restore 零调用；requirePreBackup=false 且 pre failed → 继续；**pgPoolProvider loading → 先 settle 再 close**（override 为延迟完成的 FutureProvider 断言 close 在 settle 后）；链 error 态 → pool=null 跳过 close；restore failed → 仍双 invalidate+await；重建 await 抛 → failed；**单飞**：run 在途时二次 run 返回同一 future（restore 只跑一次）；busy provider 置/复位。
- [ ] 实现 → 跑绿 → Commit `feat(di): LB-22 RestoreFlow rev2——settle 链/单飞/JobQueue 先终结/await 重建`

### Task 6: 设置页 BackupSection + l10n

**Files:**
- Create: `lib/features/settings/widgets/backup_section.dart`
- Modify: `lib/features/settings/settings_screen.dart`（StoragePathSection 后）
- Modify: ARB ×2 + gen-l10n
- Test: `test/features/settings/backup_section_test.dart`

ARB 键（settings 侧统一 `settingsBackup*` 前缀——UX P3-1）：
`settingsBackupSection`（Backups & restore/备份与还原）、`settingsBackupHint`（Daily cold backups of your local database, kept 7. Restore replaces the database only — media files on disk stay as-is./本地数据库每日自动冷备，保留 7 份。还原只替换数据库——磁盘上的媒体文件不回滚）、`settingsBackupNow`（Back up now/立即备份）、`settingsBackupDone`（Backup created/已创建备份）、`settingsBackupNoBinaries`（Bundled PostgreSQL tools not found — reinstall InkFrame to restore them/未找到内置 PostgreSQL 工具——请重新安装 InkFrame）、`settingsBackupFailed`（Backup failed/备份失败）、`settingsBackupsEmpty`（No backups yet/暂无备份）、`settingsBackupMetaLine`（`{size} · {date}` 带 DateTime 占位，format 仿 studioProjectMetaLine）、`settingsBackupKindDaily`（Daily/每日）、`settingsBackupKindManual`（Manual/手动）、`settingsBackupKindPreRestore`（Pre-restore/还原前）、`settingsRestore`（Restore/还原）。
restore 家族（跨 surface 共享，无 settings 前缀——与 `studioDeleteConfirmTitle` 同构惯例）：
`restoreConfirmTitle`（Restore from backup?/从备份还原？）、`restoreConfirmBody`（`Replace current data with "{file}" ({date})? We'll try to create a safety backup first. Running generations will be cancelled, and you'll be returned to the home screen./用 "{file}"（{date}）替换当前数据？还原前会尽量先备份一次；进行中的生成任务会被取消，完成后将回到主页。`）、`restoreDone`（Restore complete/还原完成）、`restoreFailed`（Restore failed — your data was not changed/还原失败——你的数据未被改动）、`restoreFailedCorrupt`（Backup file failed verification/备份文件校验未通过）、`restoreFailedVersionNewer`（This backup was made by a newer version of InkFrame/该备份来自更新版本的 InkFrame）、`restoreAbortedPreBackup`（Safety backup failed — restore cancelled/安全备份失败——已取消还原）、`restoreInProgress`（Restoring…/正在还原…）、`startupErrorRestoreLatest`（Restore latest backup/从最近备份还原）。

- [ ] 红测（overrides：backup service fake / flow fake / busy provider / toast recording / logger / controller runtime fake）：
  - 列表渲染 kind 标签 + metaLine；空态
  - 立即备份：runtime 有 → backupNow(manual) + 成功 toast + 列表刷新；**runtime=null → 走 controller.start() 再备份**（UX P2-4，ensure-started 与 flow 对齐）；start 抛 → settingsBackupFailed toast；skippedNoBinaries → 专属 toast
  - 还原：确认框含文件名+日期文案 → 确认 → **barrier 模态出现**（restoreInProgress，barrierDismissible=false）→ flow.run(name, requirePreBackup: true)；取消不调
  - 成功 → 会话重置（currentScreen→studio、canvasId→null、画廊→null；notifier 全部首 await 前 read——#188 P1-1）+ restoreDone toast；failed/failedCorrupt/failedVersionNewer/abortedPreBackup/failedNoBinaries → 各自文案 toast（NoBinaries 复用 settingsBackupNoBinaries——UX P2-5）
  - `databaseRestoreBusyProvider=true` 时两按钮禁用（flow 级守卫的 UI 呈现——widget 重挂不失守）
- [ ] 实现（barrier 模态：`showDialog(barrierDismissible:false)` 包 flow.run，NavigatorState 首 await 前捕获，完成后 pop）→ 跑绿 → Commit `feat(settings): LB-22 备份与还原区`

### Task 7: StartupErrorView 入口 + _reboot busy 收口

**Files:**
- Modify: `lib/features/startup/widgets/startup_error_view.dart`
- Test: `test/features/startup/startup_error_view_test.dart`（无则新建）

- [ ] 红测：有非 preRestore 备份 → 按钮出现；最近目标 = 排序键最新的 daily/manual（**排除 prerestore**——UX P1-2 坏库 dump 循环）；确认框含文件名+日期；确认 → flow.run(latest, requirePreBackup: false)；失败 → toast（app 级 messenger，view 卸载也可见）+ 按钮复位；无备份不渲染；busy（databaseRestoreBusyProvider 或 flow 在途）禁用还原与重试两钮。
- [ ] 顺手修：`_reboot` 的 `_rebooting` 复位改为 await `pgMigratedPoolProvider.future` 出确定态（成败均复位；生命周期 P1-1 修法 3）。
- [ ] 实现 → 跑绿 → Commit `feat(startup): LB-22 启动失败面还原入口 + 重试 busy 收口`

### Task 8: SETUP.md + 文档 + 闸门 + PR + 对抗评审

- [ ] SETUP.md「Database backups & recovery」改写：in-app 还原为首选；scratch 对换语义一句话（失败不动原库）；手工 pg_restore 降为进阶。
- [ ] BOARD：近期落地行 + 债表两行（①LB-13 reaper 转真删前必须 restore-aware；②ProcessRunner 无超时既有 EX-3 行补 pg_dump/pg_restore 消费方备注）。MASTERPLAN：LB-22 ✅ + 进度行。docs/CLAUDE.md：services/settings/startup 快照。
- [ ] 全量闸门（Docker PG 带 TEST_PG_URL）→ push → PR（body 含 rev2 八条拍板 + 三镜头评审链接说明）→ 对抗评审（复审重点=对换序正确性/自愈/单飞）→ 修 P1/P2 → CI 真绿核验（sleep 75 再 watch + 合并前一次性 checks）→ squash 合并。

## Self-Review 结论（rev2）

- 三镜头 10×P1 全部有对应 Task 落点：数据 P1-1/2（Task 3 对换+--single-transaction）、P1-3（Task 2 分池）、P1-4（Task 5 返回值+分策略）；生命周期 P1-1（Task 4 单飞+Task 5 settle）、P1-2（Task 5 flow 级单飞）、P1-3（Task 4/5 JobQueue）；UX P1-1（toast 跨 gate+preName）、P1-2（确认框亮目标+排除 prerestore）、P1-3（分池）。
- P2 落点：sha/version sidecar（Task 2/3）、await 重建=restored（Task 5）、会话重置+文案（Task 6）、runtime=null（Task 6）、NoBinaries 对称（Task 6）、metaLine/kind 键（Task 6）、JobQueue 预热（Task 5）、barrier 模态（Task 6）、database.dart 注释文案修正（Task 5 顺手）。
- 有意留白：还原进度百分比（barrier 模态只转圈）；pg_dump/restore 超时（既有 EX-3 债）；retired 库残留的启动期清扫（DROP 失败仅 warn，空间代价可接受，记随 LB-12 同窗盘点）。
