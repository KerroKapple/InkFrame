// InkDashedSlot 测试：child 渲染 + onPressed 触发 + 默认无 child 也能渲染空槽。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/primitives/ink_dashed_slot.dart';

void main() {
  group('InkDashedSlot', () {
    testWidgets('renders child inside dashed frame', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkDashedSlot(child: Text('add image')),
            ),
          ),
        ),
      );
      expect(find.text('add image'), findsOneWidget);
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('onPressed triggers on tap', (tester) async {
      int count = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkDashedSlot(
                onPressed: () => count++,
                child: const Text('tap'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkDashedSlot));
      expect(count, 1);
    });

    testWidgets('no onPressed still renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: InkDashedSlot(child: Text('static'))),
          ),
        ),
      );
      expect(find.text('static'), findsOneWidget);
    });
  });
}
