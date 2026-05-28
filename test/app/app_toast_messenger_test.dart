// 验证 MaterialApp.scaffoldMessengerKey 接到 toastMessengerKeyProvider 的实例，
// 这样 ToastService 才能在无 BuildContext 时把 SnackBar 弹到当前 Scaffold。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';

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
        apiKeyUnlockedProvider.overrideWith((_) async => true),
        currentCanvasIdProvider.overrideWith((_) => null),
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
