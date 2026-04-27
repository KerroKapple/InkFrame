// InkAccentChip 测试：label 渲染 + icon 可选 + onPressed 触发。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/primitives/ink_accent_chip.dart';

void main() {
  group('InkAccentChip', () {
    testWidgets('renders label only', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: InkAccentChip(label: 'Active'))),
        ),
      );
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders leading icon when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkAccentChip(label: 'Pinned', icon: Icons.push_pin),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('onPressed triggers on tap', (tester) async {
      int count = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkAccentChip(
                label: 'Tap me',
                onPressed: () => count++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkAccentChip));
      expect(count, 1);
    });
  });
}
