// 验证 MaterialApp.scaffoldMessengerKey 接到 toastMessengerKeyProvider 的实例，
// 这样 ToastService 才能在无 BuildContext 时把 SnackBar 弹到当前 Scaffold。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/orphan_reaper.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:postgres/postgres.dart';

void main() {
  testWidgets(
      'MaterialApp.scaffoldMessengerKey == toastMessengerKeyProvider value',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final Directory tmp = Directory.systemTemp.createTempSync('ink_toast_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final AppPaths paths = DefaultAppPaths.forRoot(tmp);
    await tester.runAsync(() => paths.ensureInitialized());

    final container = ProviderContainer(
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
        currentCanvasIdProvider.overrideWith((_) => null),
        // 密封 LB-13 孤儿回收启动读：boot 测试不触发真 PG/dart:io（否则 coverage 收集永挂）。
        orphanReapStartupProvider.overrideWith((_) async {}),
        // 密封 LB-09 DB-ready gate：pgMigratedPoolProvider 停在 loading，
        // _StartupGate 照常进 _UnlockedShell，不触发真 PG。
        pgMigratedPoolProvider
            .overrideWith((ref) => Completer<Pool<void>>().future),
        // 密封：boot 渲染唯一碰 DB 的链路，断在此处——避免真起内嵌 PG。
        workspaceProjectsProvider
            .overrideWith((_) async => const <ProjectWithCanvases>[]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    final materialApp =
        tester.widget<MaterialApp>(find.byType(MaterialApp));
    final expectedKey = container.read(toastMessengerKeyProvider);
    expect(identical(materialApp.scaffoldMessengerKey, expectedKey), isTrue);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
