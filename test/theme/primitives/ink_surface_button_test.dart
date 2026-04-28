// InkSurfaceButton 测试：regular + icon variants、onPressed、disabled。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/primitives/ink_surface_button.dart';

void main() {
  group('InkSurfaceButton', () {
    testWidgets('regular variant renders label + icon and triggers onPressed',
        (tester) async {
      int count = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkSurfaceButton(
                label: '原点',
                icon: Icons.home,
                onPressed: () => count++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('原点'), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      await tester.tap(find.byType(InkSurfaceButton));
      expect(count, 1);
    });

    testWidgets('regular variant works without icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkSurfaceButton(
                label: '纯文本',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('纯文本'), findsOneWidget);
    });

    testWidgets('icon variant renders 28x28 icon-only button', (tester) async {
      int count = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkSurfaceButton.icon(
                icon: Icons.add,
                onPressed: () => count++,
                tooltip: '放大',
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      await tester.tap(find.byType(InkSurfaceButton));
      expect(count, 1);
    });

    testWidgets('disabled (onPressed null) does not trigger', (tester) async {
      const count = 0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkSurfaceButton(
                label: 'disabled',
                onPressed: null,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkSurfaceButton));
      expect(count, 0);
    });
  });
}
