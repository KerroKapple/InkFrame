// ON-1 首帧闸门（挂 LB-09 DB-ready 之后）：
// - DB-ready 成功 + onboardingCompleted=false → 弹向导且该次跳过会话恢复
// - DB-ready 成功 + =true → 不弹向导，会话恢复照常
// - PG 失败 → StartupErrorView 全屏接管，不弹向导也不恢复
// restoreLastSessionProvider 用探针 override 观测触发与否。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/orphan_reaper.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/startup/widgets/startup_error_view.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/restore_last_session.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:postgres/postgres.dart';

import '../_harness/fake_secure_storage.dart';

/// DB-ready 成功密封：Pool 懒建连接——无人消费即无 IO，不触真 PG。
Override _dbReadyOk() => pgMigratedPoolProvider.overrideWith(
      (ref) async => Pool.withEndpoints(
        [Endpoint(host: '127.0.0.1', database: 'unused', username: 'unused')],
        settings: const PoolSettings(
          sslMode: SslMode.disable,
          maxConnectionCount: 1,
        ),
      ),
    );

/// DB-ready 失败密封：DI 边界契约是翻好的 InkError。
Override _dbReadyFail() => pgMigratedPoolProvider.overrideWith(
      (ref) => Future<Pool<void>>.error(
        const LocalIOError(extra: {'op': 'pg_boot'}),
      ),
    );

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppPreferences prefs,
  required void Function() onRestore,
  required Override dbReady,
  List<Override> extra = const <Override>[],
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      preferencesServiceProvider
          .overrideWithValue(InMemoryPreferencesService(prefs)),
      secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
      anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
      // 密封 LB-13 孤儿回收启动读：boot 测试不触发真 PG/dart:io。
      orphanReapStartupProvider.overrideWith((_) async {}),
      dbReady,
      // 密封：boot 渲染唯一碰 DB 的链路，断在此处——避免真起内嵌 PG。
      workspaceProjectsProvider
          .overrideWith((_) async => const <ProjectWithCanvases>[]),
      restoreLastSessionProvider.overrideWith((_) async => onRestore()),
      ...extra,
    ],
    child: const InkFrameApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('首启：DB-ready + onboardingCompleted=false → 弹向导，该次跳过会话恢复',
      (tester) async {
    var restoreTriggered = false;
    await _pumpApp(
      tester,
      prefs: const AppPreferences(),
      onRestore: () => restoreTriggered = true,
      dbReady: _dbReadyOk(),
    );

    expect(find.text('Welcome to InkFrame'), findsOneWidget);
    expect(restoreTriggered, isFalse,
        reason: '向导优先——首启该次不得触发上次会话恢复');
  });

  testWidgets('二启：DB-ready + onboardingCompleted=true → 不弹向导，会话恢复照常触发',
      (tester) async {
    var restoreTriggered = false;
    await _pumpApp(
      tester,
      prefs: const AppPreferences(onboardingCompleted: true),
      onRestore: () => restoreTriggered = true,
      dbReady: _dbReadyOk(),
    );

    expect(find.text('Welcome to InkFrame'), findsNothing);
    expect(restoreTriggered, isTrue);
  });

  testWidgets('PG 失败：即使首启也不弹向导、不恢复——StartupErrorView 全屏接管',
      (tester) async {
    var restoreTriggered = false;
    // StartupErrorView 渲染读 appPaths.logs.path（纯字符串，无 IO）。
    final Directory tmp = Directory.systemTemp.createTempSync('ink_gate_err_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await _pumpApp(
      tester,
      prefs: const AppPreferences(),
      onRestore: () => restoreTriggered = true,
      dbReady: _dbReadyFail(),
      extra: <Override>[
        appPathsProvider.overrideWithValue(DefaultAppPaths.forRoot(tmp)),
      ],
    );

    expect(find.byType(StartupErrorView), findsOneWidget);
    expect(find.text('Welcome to InkFrame'), findsNothing,
        reason: 'PG 失败时不得弹首启向导（向导会悬浮在错误页之上）');
    expect(restoreTriggered, isFalse);
  });
}
