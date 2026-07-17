// DatabaseRestoreFlow 编排测试：顺序 / settle 链 / 单飞 / 预备份策略 / 重建 await。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/database_backup.dart';
import 'package:inkframe/core/di/database_restore.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/database_backup_service.dart';
import 'package:inkframe/core/interfaces/database_restore_service.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:postgres/postgres.dart';

import '../../helpers/recording_logger.dart';

class _FakeController implements PgController {
  _FakeController(this.order, {PgRuntime? runtime, this.failStart = false})
      : _rt = runtime;
  final List<String> order;
  PgRuntime? _rt;
  bool failStart;

  @override
  PgRuntime? get runtime => _rt;

  @override
  Future<PgRuntime> start() async {
    order.add('controller.start');
    if (failStart) throw PgLifecycleError('scripted');
    return _rt = PgRuntime(
      host: '127.0.0.1',
      port: 5544,
      dataDir: Directory.systemTemp,
      password: 'pw',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

class _FakeBackup implements DatabaseBackupService {
  _FakeBackup(this.order);
  final List<String> order;
  BackupOutcome nowOutcome = BackupOutcome.created;
  BackupConnection? lastConn;
  BackupKind? lastKind;
  String? lastPreserve;

  @override
  Future<BackupOutcome> backup(BackupConnection connection) async =>
      BackupOutcome.created;

  @override
  Future<BackupNowResult> backupNow(
    BackupConnection connection, {
    required BackupKind kind,
    String? preserve,
  }) async {
    order.add('backupNow');
    lastConn = connection;
    lastKind = kind;
    lastPreserve = preserve;
    return BackupNowResult(
      outcome: nowOutcome,
      fileName: nowOutcome == BackupOutcome.created
          ? 'inkframe-prerestore-2026-07-16-000000.dump'
          : null,
    );
  }

  @override
  List<BackupFileInfo> listBackups() => const <BackupFileInfo>[];
}

class _FakeRestore implements DatabaseRestoreService {
  _FakeRestore(this.order);
  final List<String> order;
  RestoreOutcome outcome = RestoreOutcome.restored;
  String? lastFileName;

  @override
  Future<RestoreOutcome> restore(
    BackupConnection connection,
    String backupFileName,
  ) async {
    order.add('restore');
    lastFileName = backupFileName;
    return outcome;
  }
}

class _FakePool implements Pool<void> {
  _FakePool(this.order);
  final List<String> order;
  bool wasClosed = false;

  @override
  Future<void> close({bool force = false}) async {
    wasClosed = true;
    order.add('pool.close');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

class _FakeJobQueue implements JobQueueService {
  _FakeJobQueue(this.order);
  final List<String> order;

  @override
  void dispose() {
    order.add('jq.dispose');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

void main() {
  late List<String> order;
  late _FakeController controller;
  late _FakeBackup backup;
  late _FakeRestore restore;
  late _FakePool pool;
  late int poolBuilds;
  late int migratedBuilds;
  late bool migratedShouldFail;

  setUp(() {
    order = <String>[];
    controller = _FakeController(
      order,
      runtime: PgRuntime(
        host: '127.0.0.1',
        port: 5544,
        dataDir: Directory.systemTemp,
        password: 'pw',
      ),
    );
    backup = _FakeBackup(order);
    restore = _FakeRestore(order);
    pool = _FakePool(order);
    poolBuilds = 0;
    migratedBuilds = 0;
    migratedShouldFail = false;
  });

  ProviderContainer build({Duration? poolDelay}) {
    final container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(RecordingLogger()),
        pgControllerProvider.overrideWithValue(controller),
        databaseBackupServiceProvider.overrideWithValue(backup),
        databaseRestoreServiceProvider.overrideWithValue(restore),
        jobQueueServiceProvider.overrideWith((ref) async => _FakeJobQueue(order)),
        pgPoolProvider.overrideWith((ref) async {
          poolBuilds++;
          if (poolDelay != null && poolBuilds == 1) {
            await Future<void>.delayed(poolDelay);
          }
          return pool;
        }),
        pgMigratedPoolProvider.overrideWith((ref) async {
          final p = await ref.watch(pgPoolProvider.future);
          migratedBuilds++;
          order.add('migrated.build');
          if (migratedShouldFail) throw const LocalIOError();
          return p;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('成功序：backupNow → jq.dispose → pool.close → restore → 重建 await', () async {
    final c = build();
    // 预热：让 pool/jobQueue/migrated 进入确定态（模拟 app 正常运行中）。
    await c.read(pgMigratedPoolProvider.future);
    await c.read(jobQueueServiceProvider.future);
    order.clear();

    final result = await c
        .read(databaseRestoreFlowProvider)
        .run('inkframe-2026-07-15.dump', requirePreBackup: true);

    expect(result.outcome, RestoreOutcome.restored);
    expect(result.preBackupFileName,
        'inkframe-prerestore-2026-07-16-000000.dump');
    expect(order, <String>[
      'backupNow',
      'jq.dispose',
      'pool.close',
      'restore',
      'migrated.build',
    ]);
    expect(backup.lastKind, BackupKind.preRestore);
    expect(backup.lastPreserve, 'inkframe-2026-07-15.dump',
        reason: '兜底备份剪枝必须排除正要还原的目标（#189 评审 P1-2）');
    expect(restore.lastFileName, 'inkframe-2026-07-15.dump');
    // invalidate 后重建：pool 共 2 次 build。
    expect(poolBuilds, 2);
    expect(migratedBuilds, 2);
  });

  test('requirePreBackup 且预备份失败 → abortedPreBackup，restore/关池零调用', () async {
    backup.nowOutcome = BackupOutcome.failed;
    final c = build();
    await c.read(pgMigratedPoolProvider.future);
    order.clear();

    final result = await c
        .read(databaseRestoreFlowProvider)
        .run('inkframe-2026-07-15.dump', requirePreBackup: true);

    expect(result.outcome, RestoreOutcome.abortedPreBackup);
    expect(order, <String>['backupNow']);
    expect(pool.wasClosed, isFalse);
  });

  test('requirePreBackup=false（启动失败面）预备份失败 → warn 后继续', () async {
    backup.nowOutcome = BackupOutcome.failed;
    final c = build();
    await c.read(pgMigratedPoolProvider.future);
    order.clear();

    final result = await c
        .read(databaseRestoreFlowProvider)
        .run('inkframe-2026-07-15.dump', requirePreBackup: false);

    expect(result.outcome, RestoreOutcome.restored);
    expect(result.preBackupFileName, isNull);
    expect(order, contains('restore'));
  });

  test('runtime=null → 先 controller.start 再走全流程', () async {
    controller = _FakeController(order); // runtime 为 null。
    final c = build();
    await c.read(pgMigratedPoolProvider.future);
    order.clear();

    final result = await c
        .read(databaseRestoreFlowProvider)
        .run('inkframe-2026-07-15.dump', requirePreBackup: true);

    expect(result.outcome, RestoreOutcome.restored);
    expect(order.first, 'controller.start');
  });

  test('start 抛 PgLifecycleError → failed，全链零调用', () async {
    controller = _FakeController(order, failStart: true);
    final c = build();

    final result = await c
        .read(databaseRestoreFlowProvider)
        .run('inkframe-2026-07-15.dump', requirePreBackup: true);

    expect(result.outcome, RestoreOutcome.failed);
    expect(order, <String>['controller.start']);
  });

  test('链 loading 态 → 先 settle 再 close（不与在途建池竞速）', () async {
    final c = build(poolDelay: const Duration(milliseconds: 120));
    // 触发在途 build（不 await）——模拟首启 PG 冷启动窗口。
    final settling = c.read(pgPoolProvider.future);

    final result = await c
        .read(databaseRestoreFlowProvider)
        .run('inkframe-2026-07-15.dump', requirePreBackup: false);

    expect(result.outcome, RestoreOutcome.restored);
    // close 必须发生在 restore 之前（settle 后拿到池再关，绝不跳过）。
    expect(order.indexOf('pool.close'), lessThan(order.indexOf('restore')));
    await settling;
  });

  test('链 error 态 → 无池可关，跳过 close 直接 restore', () async {
    final c = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(RecordingLogger()),
        pgControllerProvider.overrideWithValue(controller),
        databaseBackupServiceProvider.overrideWithValue(backup),
        databaseRestoreServiceProvider.overrideWithValue(restore),
        jobQueueServiceProvider.overrideWith((ref) async => _FakeJobQueue(order)),
        pgPoolProvider.overrideWith((ref) async {
          poolBuilds++;
          if (poolBuilds == 1) throw const LocalIOError(); // 首建失败（启动失败面）。
          return pool;
        }),
        pgMigratedPoolProvider.overrideWith((ref) async {
          final p = await ref.watch(pgPoolProvider.future);
          order.add('migrated.build');
          return p;
        }),
      ],
    );
    addTearDown(c.dispose);
    // 让首建失败落定。
    await expectLater(c.read(pgPoolProvider.future), throwsA(isA<LocalIOError>()));
    order.clear();

    final result = await c
        .read(databaseRestoreFlowProvider)
        .run('inkframe-2026-07-15.dump', requirePreBackup: false);

    expect(result.outcome, RestoreOutcome.restored);
    expect(order, isNot(contains('pool.close')));
    expect(order, contains('restore'));
  });

  test('restore failed → 仍重建链，failed 透传', () async {
    restore.outcome = RestoreOutcome.failed;
    final c = build();
    await c.read(pgMigratedPoolProvider.future);
    order.clear();

    final result = await c
        .read(databaseRestoreFlowProvider)
        .run('inkframe-2026-07-15.dump', requirePreBackup: true);

    expect(result.outcome, RestoreOutcome.failed);
    expect(order, contains('migrated.build')); // 池已关必须重建。
  });

  test('重建 await 失败（还原产物迁移炸）→ failed 而非 restored（toast 不说谎）', () async {
    final c = build();
    await c.read(pgMigratedPoolProvider.future);
    migratedShouldFail = true;
    order.clear();

    final result = await c
        .read(databaseRestoreFlowProvider)
        .run('inkframe-2026-07-15.dump', requirePreBackup: true);

    expect(result.outcome, RestoreOutcome.failed);
    expect(result.preBackupFileName, isNotNull);
  });

  test('单飞：在途时二次 run 返回同一 future，restore 只跑一次', () async {
    final c = build();
    await c.read(pgMigratedPoolProvider.future);
    order.clear();

    final flow = c.read(databaseRestoreFlowProvider);
    final f1 = flow.run('inkframe-2026-07-15.dump', requirePreBackup: true);
    final f2 = flow.run('inkframe-2026-07-15.dump', requirePreBackup: true);
    expect(identical(f1, f2), isTrue);
    await Future.wait([f1, f2]);
    expect(order.where((s) => s == 'restore'), hasLength(1));

    // 完成后单飞清空，可再跑。
    final f3 = flow.run('inkframe-2026-07-15.dump', requirePreBackup: true);
    expect(identical(f1, f3), isFalse);
    await f3;
  });

  test('busy provider：run 期间 true，完成复位 false', () async {
    final c = build();
    await c.read(pgMigratedPoolProvider.future);

    final flow = c.read(databaseRestoreFlowProvider);
    expect(c.read(databaseRestoreBusyProvider), isFalse);
    final f = flow.run('inkframe-2026-07-15.dump', requirePreBackup: true);
    expect(c.read(databaseRestoreBusyProvider), isTrue);
    await f;
    expect(c.read(databaseRestoreBusyProvider), isFalse);
  });
}
