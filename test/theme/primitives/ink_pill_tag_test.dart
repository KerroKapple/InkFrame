// InkPillTag 测试：label 渲染 + icon 可选；纯展示不可 tap。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/primitives/ink_pill_tag.dart';

void main() {
  group('InkPillTag', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: InkPillTag(label: 'EP01'))),
        ),
      );
      expect(find.text('EP01'), findsOneWidget);
    });

    testWidgets('renders leading icon when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkPillTag(label: 'Series', icon: Icons.folder),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.folder), findsOneWidget);
    });
  });
}
