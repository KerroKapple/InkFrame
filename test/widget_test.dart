// InkFrame 工程骨架烟测：InkFrameApp 可装配并渲染首屏 l10n。
//
// 关键点：DefaultAppPaths.ensureInitialized 走真实 dart:io，必须用
// tester.runAsync 执行，否则 testWidgets 的 fake async zone 会永远挂起。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/paths/app_paths.dart';

void main() {
  testWidgets('InkFrameApp boots', (tester) async {
    final Directory tmp = Directory.systemTemp.createTempSync('ink_app_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final AppPaths paths = DefaultAppPaths.forRoot(tmp);
    await tester.runAsync(() => paths.ensureInitialized());

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appPathsProvider.overrideWithValue(paths)],
        child: const InkFrameApp(),
      ),
    );
    // 首屏为 StatelessWidget + 同步 l10n，一帧即可稳定。
    await tester.pump();
    expect(find.text('InkFrame'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
