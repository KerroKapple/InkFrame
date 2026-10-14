// 真应用（InkFrameApp）把通知卡层接在 MaterialApp.builder 上：ToastLayer 包着 Navigator，
// 于是卡片在所有路由之上。取代原来的「scaffoldMessengerKey == toastMessengerKeyProvider」
// 那条——ToastService 已经不走 ScaffoldMessenger 了。
//
// 外壳级测试的纪律照旧（test/_harness/shell_app.dart）：只固定次数 pump，不 pumpAndSettle。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/notifications/widgets/toast_layer.dart';
import 'package:inkframe/theme/components/ink_toast_card.dart';

import '../_harness/shell_app.dart';

void main() {
  testWidgets('MaterialApp.builder 挂 ToastLayer：它包着根 Navigator，卡片画出来且点得到',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_app_toast_layer_');
    await pumpInkShell(tester, paths: paths);

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.builder, isNotNull);
    expect(find.byType(ToastLayer), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(Navigator).first,
        matching: find.byType(ToastLayer),
      ),
      findsOneWidget,
      reason: 'ToastLayer 必须在 Navigator 之上，卡片才能盖过浮层与对话框',
    );

    readShellContainer(tester).read(toastServiceProvider).show('hello');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(InkToastCard), findsOneWidget);
    expect(find.text('hello').hitTestable(), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
