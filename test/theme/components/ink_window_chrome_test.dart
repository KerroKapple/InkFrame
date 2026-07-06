import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/components/ink_window_chrome.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/test_app.dart';

void main() {
  testWidgets('InkWindowChrome height is 56', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: InkWindowChrome(center: Text('Studio › Projects')),
      ),
    );
    final size = tester.getSize(find.byType(InkWindowChrome));
    expect(size.height, 56);
    expect(find.text('Studio › Projects'), findsOneWidget);
  });

  testWidgets('macOS 隐藏自绘窗口按钮并为红绿灯让位', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await pumpInkApp(
      tester,
      const Scaffold(
        body: InkWindowChrome(
          leading: Text('Ink/Frame'),
          center: Text('crumb'),
        ),
      ),
    );
    // 无自绘最小化/最大化/关闭按钮（原生红绿灯负责）
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byIcon(Icons.crop_square), findsNothing);
    // leading 左侧留出红绿灯区域
    final double leadingLeft = tester.getTopLeft(find.text('Ink/Frame')).dx;
    expect(leadingLeft, greaterThanOrEqualTo(InkSpacing.macTrafficLightInset));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('非 macOS 平台保留自绘窗口按钮', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await pumpInkApp(
      tester,
      const Scaffold(
        body: InkWindowChrome(
          leading: Text('Ink/Frame'),
          center: Text('crumb'),
        ),
      ),
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    // 不额外缩进
    final double leadingLeft = tester.getTopLeft(find.text('Ink/Frame')).dx;
    expect(leadingLeft, lessThan(InkSpacing.macTrafficLightInset));
    debugDefaultTargetPlatformOverride = null;
  });
}
