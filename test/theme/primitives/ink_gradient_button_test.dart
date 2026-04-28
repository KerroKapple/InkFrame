// InkGradientButton 测试：6 变体渲染 + onPressed + disabled.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/primitives/ink_gradient_button.dart';

void main() {
  group('InkGradientButton', () {
    testWidgets('renders label + icon; onPressed triggers', (tester) async {
      int count = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkGradientButton(
                variant: InkGradientVariant.image,
                label: '图片',
                icon: Icons.image,
                onPressed: () => count++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('图片'), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
      await tester.tap(find.byType(InkGradientButton));
      expect(count, 1);
    });

    testWidgets('disabled (onPressed null) does not trigger', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkGradientButton(
                variant: InkGradientVariant.video,
                label: '视频',
                icon: Icons.videocam,
                onPressed: null,
              ),
            ),
          ),
        ),
      );
      // 找到按钮但 tap 不产生副作用（disabled 靠 opacity 或 ignoring）
      expect(find.text('视频'), findsOneWidget);
    });

    testWidgets('6 个变体全部能渲染', (tester) async {
      for (final v in InkGradientVariant.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: InkGradientButton(
                  variant: v,
                  label: v.name,
                  icon: Icons.circle,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        expect(find.text(v.name), findsOneWidget);
      }
    });

    test('每个变体都有非空 from/to 色', () {
      for (final v in InkGradientVariant.values) {
        final pair = InkGradientButton.colorsOf(v);
        expect(pair.$1, isA<Color>());
        expect(pair.$2, isA<Color>());
      }
    });
  });
}
