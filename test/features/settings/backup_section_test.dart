// BackupSection widget 测试：列表/立即备份/还原确认→flow/成败 toast/会话重置/busy 禁钮。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/database_backup.dart';
import 'package:inkframe/core/di/database_restore.dart';
import 'package:inkframe/core/interfaces/database_backup_service.dart';
import 'package:inkframe/core/interfaces/database_restore_service.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/settings/widgets/backup_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:inkframe/theme/app_theme.dart';

class _FakeController implements PgController {
  _FakeController({PgRuntime? runtime, this.failStart = false}) : _rt = runtime;
  PgRuntime? _rt;
  bool failStart;
  int startCalls = 0;

  @override
  PgRuntime? get runtime => _rt;

  @override
  Future<PgRuntime> start() async {
    startCalls++;
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
  List<BackupFileInfo> backups = const <BackupFileInfo>[];
  BackupOutcome nowOutcome = BackupOutcome.created;
  int listCalls = 0;
  BackupConnection? lastConn;
  BackupKind? lastKind;

  @override
  Future<BackupOutcome> backup(BackupConnection connection) async =>
      BackupOutcome.created;

  @override
  Future<BackupNowResult> backupNow(
    BackupConnection connection, {
    required BackupKind kind,
  }) async {
    lastConn = connection;
    lastKind = kind;
    return BackupNowResult(
      outcome: nowOutcome,
      fileName: nowOutcome == BackupOutcome.created ? 'x.dump' : null,
    );
  }

  @override
  List<BackupFileInfo> listBackups() {
    listCalls++;
    return backups;
  }
}

class _FakeFlow implements DatabaseRestoreFlow {
  _FakeFlow();
  RestoreOutcome outcome = RestoreOutcome.restored;
  String? lastFile;
  bool? lastRequire;
  int calls = 0;

  @override
  Future<RestoreFlowResult> run(
    String backupFileName, {
    required bool requirePreBackup,
  }) async {
    calls++;
    lastFile = backupFileName;
    lastRequire = requirePreBackup;
    return RestoreFlowResult(outcome: outcome);
  }
}

class _RecordingToast implements ToastService {
  final List<({String message, ToastKind kind})> shown = [];

  @override
  void show(String message, {ToastKind kind = ToastKind.info}) {
    shown.add((message: message, kind: kind));
  }
}

BackupFileInfo _info(String name, BackupKind kind) => BackupFileInfo(
      name: name,
      kind: kind,
      sizeBytes: 2048,
      modified: DateTime.utc(2026, 7, 15, 9, 30),
    );

void main() {
  late _FakeController controller;
  late _FakeBackup backup;
  late _FakeFlow flow;
  late _RecordingToast toast;

  setUp(() {
    controller = _FakeController(
      runtime: PgRuntime(
        host: '127.0.0.1',
        port: 5544,
        dataDir: Directory.systemTemp,
        password: 'pw',
      ),
    );
    backup = _FakeBackup();
    flow = _FakeFlow();
    toast = _RecordingToast();
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        pgControllerProvider.overrideWithValue(controller),
        databaseBackupServiceProvider.overrideWithValue(backup),
        databaseRestoreFlowProvider.overrideWithValue(flow),
        toastServiceProvider.overrideWithValue(toast),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: BackupSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('空态与列表渲染（kind 标签 + metaLine）', (tester) async {
    await pump(tester);
    expect(find.text('No backups yet'), findsOneWidget);

    backup.backups = [
      _info('inkframe-2026-07-15.dump', BackupKind.daily),
      _info('inkframe-manual-2026-07-14-090000.dump', BackupKind.manual),
    ];
    await tester.pumpWidget(Container()); // 重挂载读新列表。
    await pump(tester);

    expect(find.text('inkframe-2026-07-15.dump'), findsOneWidget);
    expect(find.textContaining('Daily · '), findsOneWidget);
    expect(find.textContaining('Manual · '), findsOneWidget);
    expect(find.textContaining('2.0 KB'), findsNWidgets(2));
  });

  testWidgets('立即备份：runtime 有 → backupNow(manual) + 成功 toast + 列表刷新',
      (tester) async {
    await pump(tester);
    final before = backup.listCalls;

    await tester.tap(find.text('Back up now'));
    await tester.pumpAndSettle();

    expect(backup.lastKind, BackupKind.manual);
    expect(backup.lastConn?.port, 5544);
    expect(toast.shown.single.message, 'Backup created');
    expect(toast.shown.single.kind, ToastKind.success);
    expect(backup.listCalls, greaterThan(before));
    expect(controller.startCalls, 0); // runtime 已有，不重复 start。
  });

  testWidgets('立即备份：runtime=null → 先 start；start 炸 → 失败 toast',
      (tester) async {
    controller = _FakeController(); // runtime null。
    await pump(tester);
    await tester.tap(find.text('Back up now'));
    await tester.pumpAndSettle();
    expect(controller.startCalls, 1);
    expect(toast.shown.single.message, 'Backup created');

    // 第二种：start 失败。
    controller = _FakeController(failStart: true);
    toast.shown.clear();
    await tester.pumpWidget(Container());
    await pump(tester);
    await tester.tap(find.text('Back up now'));
    await tester.pumpAndSettle();
    expect(toast.shown.single.message, 'Backup failed');
    expect(toast.shown.single.kind, ToastKind.error);
  });

  testWidgets('无二进制 → 专属 reinstall 文案', (tester) async {
    backup.nowOutcome = BackupOutcome.skippedNoBinaries;
    await pump(tester);
    await tester.tap(find.text('Back up now'));
    await tester.pumpAndSettle();
    expect(toast.shown.single.message, contains('reinstall InkFrame'));
  });

  testWidgets('还原：确认框亮文件名+时间 → flow.run(name, requirePreBackup: true)；成功重置会话',
      (tester) async {
    backup.backups = [_info('inkframe-2026-07-15.dump', BackupKind.daily)];
    final container = await pump(tester);
    container.read(currentScreenProvider.notifier).state = AppScreen.settings;
    container.read(currentCanvasIdProvider.notifier).state = 'c1';

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    // 确认框内容含目标名与时间。
    expect(find.textContaining('inkframe-2026-07-15.dump'), findsWidgets);
    expect(find.textContaining('2026-07-15'), findsWidgets);

    await tester.tap(find.text('Restore').last); // 对话框确认钮。
    await tester.pumpAndSettle();

    expect(flow.calls, 1);
    expect(flow.lastFile, 'inkframe-2026-07-15.dump');
    expect(flow.lastRequire, isTrue);
    expect(toast.shown.single.message, 'Restore complete');
    expect(container.read(currentScreenProvider), AppScreen.studio);
    expect(container.read(currentCanvasIdProvider), isNull);
  });

  testWidgets('还原：取消不调 flow；失败 outcome → 对应文案', (tester) async {
    backup.backups = [_info('inkframe-2026-07-15.dump', BackupKind.daily)];
    await pump(tester);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(flow.calls, 0);

    flow.outcome = RestoreOutcome.failedVersionNewer;
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    expect(toast.shown.single.message, contains('newer version'));
    expect(toast.shown.single.kind, ToastKind.error);
  });

  testWidgets('databaseRestoreBusyProvider=true → 备份/还原钮均不可用', (tester) async {
    backup.backups = [_info('inkframe-2026-07-15.dump', BackupKind.daily)];
    final container = await pump(tester);
    container.read(databaseRestoreBusyProvider.notifier).state = true;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back up now'));
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(backup.lastKind, isNull);
    expect(flow.calls, 0);
    expect(find.text('Restore from backup?'), findsNothing);
  });
}
