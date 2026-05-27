// InkFrame 工程骨架烟测：InkFrameApp 可装配并渲染首屏 l10n。
//
// 关键点：DefaultAppPaths.ensureInitialized 走真实 dart:io，必须用
// tester.runAsync 执行，否则 testWidgets 的 fake async zone 会永远挂起。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/paths/app_paths.dart';

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
          apiKeyUnlockedProvider.overrideWith((_) async => true),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    // 解锁态首屏为 StudioHomeScreen，顶部 chrome 中显示 LIBRARY section
    expect(find.text('LIBRARY'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('InkFrameApp shows LockScreen when not unlocked',
      (tester) async {
    final Directory tmp = Directory.systemTemp.createTempSync('ink_lock_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final AppPaths paths = DefaultAppPaths.forRoot(tmp);
    await tester.runAsync(() => paths.ensureInitialized());

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          apiKeyUnlockedProvider.overrideWith((_) async => false),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Unlock'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
