// InkFrame 工程骨架烟测：InkFrameApp 可装配并渲染首屏 l10n。
//
// 关键点：DefaultAppPaths.ensureInitialized 走真实 dart:io，必须用
// tester.runAsync 执行，否则 testWidgets 的 fake async zone 会永远挂起。
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/orphan_reaper.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:postgres/postgres.dart';

void main() {
  testWidgets('InkFrameApp boots into workspace when unlocked',
      (tester) async {
    final Directory tmp = Directory.systemTemp.createTempSync('ink_app_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final AppPaths paths = DefaultAppPaths.forRoot(tmp);
    await tester.runAsync(() => paths.ensureInitialized());

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          // 密封 LB-13 孤儿回收启动读：boot 测试不触发真 PG/dart:io，否则 fire-and-forget
          // 的 PG initdb 泄漏会让 test+coverage 的覆盖率收集永挂（VM service 等 isolate 空闲）。
          orphanReapStartupProvider.overrideWith((_) async {}),
          // 密封 LB-09 DB-ready gate：pgMigratedPoolProvider 停在 loading，
          // _StartupGate 照常进 _UnlockedShell，不触发真 PG。
          // （ON-1 首帧决策也挂 DB-ready 之后——loading 态天然不弹向导。）
          pgMigratedPoolProvider
              .overrideWith((ref) => Completer<Pool<void>>().future),
          // 本测试关注 boot 渲染，非首启路径：显式跳过 ON-1 向导（意图密封）。
          preferencesServiceProvider.overrideWithValue(
            InMemoryPreferencesService(
              const AppPreferences(onboardingCompleted: true),
            ),
          ),
          // 密封：boot 渲染唯一碰 DB 的链路，断在此处——避免真起内嵌 PG。
          workspaceProjectsProvider
              .overrideWith((_) async => const <ProjectWithCanvases>[]),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    // 解锁态首屏为 StudioHomeScreen，顶部 chrome 中显示 LIBRARY section
    expect(find.text('LIBRARY'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
