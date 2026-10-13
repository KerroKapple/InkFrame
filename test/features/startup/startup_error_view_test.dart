// LB-09 启动失败 surface widget test：
//   - StartupErrorView 渲染标题 / 正文 / 日志目录路径 / 本地化错误 / 两个按钮
//   - "打开日志目录" 调 FolderOpener.open(logs 路径)
//   - _StartupGate：DB-ready AsyncError → 全屏 surface；AsyncLoading → 照常进 shell
//   - "重试" 先 await stop 再重建 start（顺序），重启中禁用防重复点击
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/database_backup.dart';
import 'package:inkframe/core/di/database_restore.dart';
import 'package:inkframe/core/di/folder_opener.dart';
import 'package:inkframe/core/di/orphan_reaper.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/database_backup_service.dart';
import 'package:inkframe/core/interfaces/database_restore_service.dart';
import 'package:inkframe/core/interfaces/folder_opener.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/startup/widgets/startup_error_view.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations_en.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:inkframe/theme/components/ink_button.dart';
import 'package:inkframe/theme/components/ink_overlay_dialog.dart';
import 'package:inkframe/theme/tokens.dart';
import 'package:postgres/postgres.dart';

import '../../_harness/fake_secure_storage.dart';
import '../../_harness/test_app.dart';

/// FolderOpener 探针：记录被请求打开的路径。
class _SpyFolderOpener implements FolderOpener {
  final List<String> opened = <String>[];

  @override
  Future<void> open(String path) async => opened.add(path);
}

/// 备份清单 fake（LB-22 还原入口测试用）。
class _FakeBackupService implements DatabaseBackupService {
  _FakeBackupService(this.backups);
  final List<BackupFileInfo> backups;

  @override
  Future<BackupOutcome> backup(BackupConnection connection) async =>
      BackupOutcome.created;

  @override
  Future<BackupNowResult> backupNow(
    BackupConnection connection, {
    required BackupKind kind,
    String? preserve,
  }) async =>
      const BackupNowResult(outcome: BackupOutcome.created, fileName: 'x');

  @override
  List<BackupFileInfo> listBackups() => backups;
}

class _FakeRestoreFlow implements DatabaseRestoreFlow {
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
  final List<String> shown = <String>[];

  @override
  void show(String message, {ToastKind kind = ToastKind.info}) {
    shown.add(message);
  }
}

BackupFileInfo _backupInfo(String name, BackupKind kind,
        {DateTime? modified}) =>
    BackupFileInfo(
      name: name,
      kind: kind,
      sizeBytes: 1,
      modified: modified ?? DateTime.utc(2026, 7, 15, 9, 30),
    );

/// 记录调用顺序的 PgController 假体：不起真进程，start/stop 只记账；
/// stop 可经 [stopGate] 卡住以观测「重启进行中」窗口（禁用重复点击 + 顺序）。
class _RecordingPgController extends PgController {
  _RecordingPgController(AppPaths paths)
      : super(
          paths: paths,
          locator: DefaultPgBinaryLocator(),
          secureStorage: FakeSecureStorage(),
        );

  final List<String> calls = <String>[];
  Completer<void>? stopGate;

  @override
  Future<void> stop() async {
    calls.add('stop');
    final Completer<void>? gate = stopGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<PgRuntime> start() async {
    calls.add('start');
    return PgRuntime(host: '127.0.0.1', port: 1, dataDir: dataDir);
  }
}

/// 仅需 logs 路径字符串——不落盘，无需 ensureInitialized。
AppPaths _tempPaths() {
  final Directory tmp = Directory.systemTemp.createTempSync('ink_startup_err_');
  addTearDown(() => tmp.deleteSync(recursive: true));
  return DefaultAppPaths.forRoot(tmp);
}

/// 挂载完整 InkFrameApp 的通用 boot 密封（gate 走 error/loading 分支各自覆盖 pg）。
List<Override> _bootSeals(AppPaths paths, FolderOpener opener) => <Override>[
      appPathsProvider.overrideWithValue(paths),
      anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
      orphanReapStartupProvider.overrideWith((_) async {}),
      folderOpenerProvider.overrideWithValue(opener),
      workspaceProjectsProvider
          .overrideWith((_) async => const <ProjectWithCanvases>[]),
    ];

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  testWidgets('StartupErrorView 渲染标题/正文/日志路径/错误/两个按钮',
      (tester) async {
    final AppPaths paths = _tempPaths();
    await pumpInkApp(
      tester,
      StartupErrorView(error: LocalIOError(cause: StateError('pg boom'))),
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        folderOpenerProvider.overrideWithValue(_SpyFolderOpener()),
      ],
      surfaceSize: const Size(1200, 900),
    );
    await tester.pump();

    expect(find.text(l10n.startupErrorTitle), findsOneWidget);
    expect(find.text(l10n.startupErrorBody), findsOneWidget);
    expect(find.text(l10n.startupErrorLogPathLabel), findsOneWidget);
    // 本地化的 InkError 详情（LocalIOError → errorLocalIO），非白屏。
    expect(find.text(l10n.errorLocalIO), findsOneWidget);
    // 日志目录以可选中文本呈现，内容即 AppPaths.logs 路径。
    final SelectableText pathText =
        tester.widget<SelectableText>(find.byType(SelectableText));
    expect(pathText.data, paths.logs.path);
    // Retry + Open log directory 按钮。
    expect(find.text(l10n.commonRetry), findsOneWidget);
    expect(find.text(l10n.startupErrorOpenLogDir), findsOneWidget);
  });

  // P7：中性灰重画。启动失败页原来是一列裸文本躺在 Scaffold 默认底色上，
  // 现在走与设置 / 回收站同一个浮层壳（surface1 整屏 + 居中面板）。
  // 重画不许丢诊断：标题 / 正文 / 本地化错误 / 日志路径（仍可选中复制）四件都在。
  testWidgets('重画后：整屏 surface1 + 共用浮层壳，四件诊断一条不少', (tester) async {
    final AppPaths paths = _tempPaths();
    await pumpInkApp(
      tester,
      StartupErrorView(error: LocalIOError(cause: StateError('pg boom'))),
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        folderOpenerProvider.overrideWithValue(_SpyFolderOpener()),
      ],
      surfaceSize: const Size(1200, 900),
    );
    await tester.pump();

    expect(find.byType(InkOverlayDialog), findsOneWidget);
    final ColoredBox backdrop = tester.widget<ColoredBox>(
      find.byKey(StartupErrorView.backdropKey),
    );
    expect(backdrop.color, InkColors.dark().surface1);

    expect(find.text(l10n.startupErrorTitle), findsOneWidget);
    expect(find.text(l10n.startupErrorBody), findsOneWidget);
    expect(find.text(l10n.errorLocalIO), findsOneWidget);
    final SelectableText pathText =
        tester.widget<SelectableText>(find.byType(SelectableText));
    expect(pathText.data, paths.logs.path);
  });

  testWidgets('点击"打开日志目录" → FolderOpener.open(logs 路径)', (tester) async {
    final AppPaths paths = _tempPaths();
    final _SpyFolderOpener spy = _SpyFolderOpener();
    await pumpInkApp(
      tester,
      StartupErrorView(error: LocalIOError(cause: StateError('x'))),
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        folderOpenerProvider.overrideWithValue(spy),
      ],
      surfaceSize: const Size(1200, 900),
    );
    await tester.pump();

    await tester.tap(find.text(l10n.startupErrorOpenLogDir));
    await tester.pump();

    expect(spy.opened, <String>[paths.logs.path]);
  });

  testWidgets('_StartupGate：pgMigratedPool AsyncError → 全屏 StartupErrorView',
      (tester) async {
    final AppPaths paths = _tempPaths();
    await tester.runAsync(() => paths.ensureInitialized());
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ..._bootSeals(paths, _SpyFolderOpener()),
          // 同步抛出 → 首帧即 AsyncError，gate 短路 StartupErrorView，
          // _UnlockedShell 从不构建。
          pgMigratedPoolProvider.overrideWith(
            (ref) => throw LocalIOError(cause: StateError('boom')),
          ),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(StartupErrorView), findsOneWidget);
    expect(find.byType(StudioHomeScreen), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('_StartupGate：pgMigratedPool AsyncLoading → 不显示错误 surface',
      (tester) async {
    final AppPaths paths = _tempPaths();
    await tester.runAsync(() => paths.ensureInitialized());
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ..._bootSeals(paths, _SpyFolderOpener()),
          // 永不结算 → 停在 loading。
          pgMigratedPoolProvider
              .overrideWith((ref) => Completer<Pool<void>>().future),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(StartupErrorView), findsNothing);
    expect(find.byType(StudioHomeScreen), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('点击"重试"：先 await stop 再重建 start（顺序）+ 重启中禁用防重复点击',
      (tester) async {
    final AppPaths paths = _tempPaths();
    await tester.runAsync(() => paths.ensureInitialized());
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _RecordingPgController fake = _RecordingPgController(paths);
    final Completer<void> gate = Completer<void>();
    fake.stopGate = gate; // 卡住 stop 以观测「重启进行中」窗口。

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ..._bootSeals(paths, _SpyFolderOpener()),
          pgControllerProvider.overrideWith((ref) => fake),
          // 重建时经假控制器 start() 记账，随后仍失败以保持 surface 在场。
          pgMigratedPoolProvider.overrideWith((ref) async {
            await ref.read(pgControllerProvider).start();
            throw LocalIOError(cause: StateError('still failing'));
          }),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(StartupErrorView), findsOneWidget);
    expect(fake.calls, <String>['start']);

    // 首次点击「重试」→ _reboot 进入，stop() 被 gate 卡住（进行中）。
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pump();

    // stop 已调用一次，start 尚未再触发；此刻「重试」按钮禁用。
    expect(fake.calls, <String>['start', 'stop']);
    final InkButton retryBtn = tester.widget<InkButton>(
      find.widgetWithText(InkButton, l10n.commonRetry),
    );
    expect(retryBtn.onPressed, isNull);

    // 重启进行中重复点击应无效——不产生第二次 stop。
    await tester.tap(find.text(l10n.commonRetry), warnIfMissed: false);
    await tester.pump();
    expect(fake.calls, <String>['start', 'stop']);

    // 放行 stop → 失效链 → pgMigratedPool 重建 → 第二次 start（严格晚于 stop）。
    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(fake.calls, <String>['start', 'stop', 'start']);
    expect(find.byType(StartupErrorView), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('LB-22：有备份 → 「从最近备份还原」出现；确认框亮目标名+时间 → flow(best-effort)',
      (tester) async {
    final AppPaths paths = _tempPaths();
    final flow = _FakeRestoreFlow();
    // 最新在前（服务契约新→旧）；prerestore 排在最前也不得被选中。
    final backupSvc = _FakeBackupService([
      _backupInfo('inkframe-prerestore-2026-07-16-090000.dump',
          BackupKind.preRestore),
      _backupInfo('inkframe-2026-07-15.dump', BackupKind.daily),
      _backupInfo('inkframe-2026-07-14.dump', BackupKind.daily),
    ]);
    await pumpInkApp(
      tester,
      StartupErrorView(error: LocalIOError(cause: StateError('x'))),
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        folderOpenerProvider.overrideWithValue(_SpyFolderOpener()),
        databaseBackupServiceProvider.overrideWithValue(backupSvc),
        databaseRestoreFlowProvider.overrideWithValue(flow),
        toastServiceProvider.overrideWithValue(_RecordingToast()),
      ],
      surfaceSize: const Size(1200, 900),
    );
    await tester.pump();

    await tester.tap(find.text(l10n.startupErrorRestoreLatest));
    await tester.pumpAndSettle();
    // 确认框：亮出目标（排除 prerestore 后的最新=07-15）与时间。
    expect(find.textContaining('inkframe-2026-07-15.dump'), findsWidgets);
    expect(find.textContaining('2026-07-15'), findsWidgets);

    await tester.tap(find.text(l10n.settingsRestore));
    await tester.pumpAndSettle();

    expect(flow.calls, 1);
    expect(flow.lastFile, 'inkframe-2026-07-15.dump');
    expect(flow.lastRequire, isFalse, reason: '启动面=best-effort 预备份');
  });

  // 嵌入式库的口令与系统凭据里那份对不上（SQLSTATE 28P01）。原来一律显示「本地磁盘
  // I/O 错误，请检查空间与权限」——方向完全错了；而「从最近备份还原」用的是同一份
  // 口令连库，必然以同样的认证失败告终。
  testWidgets('口令对不上 → 说实话的文案，不给注定失败的「从最近备份还原」',
      (tester) async {
    final AppPaths paths = _tempPaths();
    await pumpInkApp(
      tester,
      StartupErrorView(
        error: LocalIOError(
          cause: StateError('28P01'),
          extra: const <String, Object?>{'reason': kDbAuthFailedReason},
        ),
      ),
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        folderOpenerProvider.overrideWithValue(_SpyFolderOpener()),
        // 明明有可还原的备份——按钮仍然不该出现。
        databaseBackupServiceProvider.overrideWithValue(_FakeBackupService([
          _backupInfo('inkframe-2026-07-15.dump', BackupKind.daily),
        ])),
        databaseRestoreFlowProvider.overrideWithValue(_FakeRestoreFlow()),
        toastServiceProvider.overrideWithValue(_RecordingToast()),
      ],
      surfaceSize: const Size(1200, 900),
    );
    await tester.pump();

    expect(find.text(l10n.startupErrorDbAuthFailed), findsOneWidget);
    expect(find.text(l10n.errorLocalIO), findsNothing,
        reason: '磁盘好好的，是口令对不上——别把人往「检查空间与权限」上引');
    expect(find.text(l10n.startupErrorRestoreLatest), findsNothing,
        reason: '还原用同一份口令连库，这颗按钮必然失败');
    // 另外两颗照常：重试（用户可能刚把凭据恢复回去）、打开日志目录。
    expect(find.text(l10n.commonRetry), findsOneWidget);
    expect(find.text(l10n.startupErrorOpenLogDir), findsOneWidget);
  });

  Future<void> pumpWithBackup(WidgetTester tester, Object error) => pumpInkApp(
        tester,
        StartupErrorView(error: error),
        overrides: <Override>[
          appPathsProvider.overrideWithValue(_tempPaths()),
          folderOpenerProvider.overrideWithValue(_SpyFolderOpener()),
          databaseBackupServiceProvider.overrideWithValue(_FakeBackupService([
            _backupInfo('inkframe-2026-07-15.dump', BackupKind.daily),
          ])),
          databaseRestoreFlowProvider.overrideWithValue(_FakeRestoreFlow()),
          toastServiceProvider.overrideWithValue(_RecordingToast()),
        ],
        surfaceSize: const Size(1200, 900),
      );

  // 用户装回了旧版本（比如新版有 bug 想回退）。正解是装回最新版——跟磁盘无关。
  // 还原按钮这里不只是没用：最近一份能还原的若恰好是升级前的旧备份，一键还原会把
  // 升级后的所有改动回滚掉，用户却不知道。
  testWidgets('库比应用新 → 「请安装最新版」，不给可能回滚数据的「还原」', (tester) async {
    await pumpWithBackup(
      tester,
      LocalIOError(
        cause: StateError('downgrade'),
        extra: const <String, Object?>{'reason': kDbNewerThanAppReason},
      ),
    );
    await tester.pump();

    expect(find.text(l10n.startupErrorDbNewerThanApp), findsOneWidget);
    expect(find.text(l10n.errorLocalIO), findsNothing);
    expect(find.text(l10n.startupErrorRestoreLatest), findsNothing,
        reason: '还原可能把升级后的改动悄悄回滚掉');
  });

  // 找不到内置 PG 程序（安装不完整 / 被安全软件隔离）。原来连「磁盘 I/O 错误」都不是
  // ——它不在任何已知分支里，按程序 bug 原样透出，启动页只能说「出了点问题」。
  testWidgets('找不到内置 PG 程序 → 「请重新安装」，不给必然失败的还原', (tester) async {
    await pumpWithBackup(
      tester,
      LocalIOError(
        cause: StateError('no packaged PG'),
        extra: const <String, Object?>{'reason': kDbBinariesMissingReason},
      ),
    );
    await tester.pump();

    expect(find.text(l10n.settingsBackupNoBinaries), findsOneWidget);
    expect(find.text(l10n.errorUnknown), findsNothing);
    expect(find.text(l10n.startupErrorRestoreLatest), findsNothing,
        reason: '还原要用的 pg_restore 就在缺掉的那套程序里');
  });

  // 反向：迁移失败时失败的那一步已回滚，还原是无害的选项——按钮照常给。不是所有
  // 特定失败都该藏按钮。
  testWidgets('前向迁移失败 → 专门文案，「还原」照常给', (tester) async {
    await pumpWithBackup(
      tester,
      LocalIOError(
        cause: StateError('migration'),
        extra: const <String, Object?>{'reason': kDbMigrationFailedReason},
      ),
    );
    await tester.pump();

    expect(find.text(l10n.startupErrorDbMigrationFailed), findsOneWidget);
    expect(find.text(l10n.errorLocalIO), findsNothing);
    expect(find.text(l10n.startupErrorRestoreLatest), findsOneWidget);
  });

  testWidgets('LB-22：只有 prerestore 备份 → 按钮不渲染；flow 失败 → toast + 按钮复位',
      (tester) async {
    final AppPaths paths = _tempPaths();
    final toast = _RecordingToast();
    final flow = _FakeRestoreFlow()..outcome = RestoreOutcome.failed;

    // 场景 1：仅 prerestore → 无按钮。
    await pumpInkApp(
      tester,
      StartupErrorView(error: LocalIOError(cause: StateError('x'))),
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        folderOpenerProvider.overrideWithValue(_SpyFolderOpener()),
        databaseBackupServiceProvider.overrideWithValue(_FakeBackupService([
          _backupInfo('inkframe-prerestore-2026-07-16-090000.dump',
              BackupKind.preRestore),
        ])),
        databaseRestoreFlowProvider.overrideWithValue(flow),
        toastServiceProvider.overrideWithValue(toast),
      ],
      surfaceSize: const Size(1200, 900),
    );
    await tester.pump();
    expect(find.text(l10n.startupErrorRestoreLatest), findsNothing);

    // 场景 2：还原失败 → 失败 toast、按钮复位可再点。
    await tester.pumpWidget(Container());
    await pumpInkApp(
      tester,
      StartupErrorView(error: LocalIOError(cause: StateError('x'))),
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        folderOpenerProvider.overrideWithValue(_SpyFolderOpener()),
        databaseBackupServiceProvider.overrideWithValue(_FakeBackupService([
          _backupInfo('inkframe-2026-07-15.dump', BackupKind.daily),
        ])),
        databaseRestoreFlowProvider.overrideWithValue(flow),
        toastServiceProvider.overrideWithValue(toast),
      ],
      surfaceSize: const Size(1200, 900),
    );
    await tester.pump();

    await tester.tap(find.text(l10n.startupErrorRestoreLatest));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsRestore));
    await tester.pumpAndSettle();

    expect(flow.calls, 1);
    expect(toast.shown.single, l10n.restoreFailed);
    // 按钮复位（onPressed 非 null）。
    final InkButton restoreBtn = tester.widget<InkButton>(
      find.widgetWithText(InkButton, l10n.startupErrorRestoreLatest),
    );
    expect(restoreBtn.onPressed, isNotNull);
  });

  testWidgets('LB-22：latest 按 modified 选，而非文件名排序键（#189 评审 P2-2）',
      (tester) async {
    final AppPaths paths = _tempPaths();
    final flow = _FakeRestoreFlow();
    // 同日：manual 09:00 手动备份、daily 20:00 落盘——文件名排序键把 daily
    // 记 000000 会误选 manual；必须按 modified 选 daily。
    final backupSvc = _FakeBackupService([
      _backupInfo('inkframe-manual-2026-07-15-090000.dump', BackupKind.manual,
          modified: DateTime.utc(2026, 7, 15, 9)),
      _backupInfo('inkframe-2026-07-15.dump', BackupKind.daily,
          modified: DateTime.utc(2026, 7, 15, 20)),
    ]);
    await pumpInkApp(
      tester,
      StartupErrorView(error: LocalIOError(cause: StateError('x'))),
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        folderOpenerProvider.overrideWithValue(_SpyFolderOpener()),
        databaseBackupServiceProvider.overrideWithValue(backupSvc),
        databaseRestoreFlowProvider.overrideWithValue(flow),
        toastServiceProvider.overrideWithValue(_RecordingToast()),
      ],
      surfaceSize: const Size(1200, 900),
    );
    await tester.pump();

    await tester.tap(find.text(l10n.startupErrorRestoreLatest));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsRestore));
    await tester.pumpAndSettle();

    expect(flow.lastFile, 'inkframe-2026-07-15.dump');
  });
}
