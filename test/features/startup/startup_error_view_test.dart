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
import 'package:inkframe/core/di/folder_opener.dart';
import 'package:inkframe/core/di/orphan_reaper.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/folder_opener.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/startup/widgets/startup_error_view.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations_en.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:inkframe/theme/components/ink_button.dart';
import 'package:postgres/postgres.dart';

import '../../_harness/test_app.dart';

/// FolderOpener 探针：记录被请求打开的路径。
class _SpyFolderOpener implements FolderOpener {
  final List<String> opened = <String>[];

  @override
  Future<void> open(String path) async => opened.add(path);
}

/// 记录调用顺序的 PgController 假体：不起真进程，start/stop 只记账；
/// stop 可经 [stopGate] 卡住以观测「重启进行中」窗口（禁用重复点击 + 顺序）。
class _RecordingPgController extends PgController {
  _RecordingPgController(AppPaths paths)
      : super(paths: paths, locator: DefaultPgBinaryLocator());

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
}
