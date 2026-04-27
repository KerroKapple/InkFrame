// InkGlass* primitive widget 测试：child 渲染 + BackdropFilter 存在。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/primitives/ink_glass_card.dart';

void main() {
  group('InkGlass primitives', () {
    testWidgets('InkGlassCard renders child inside BackdropFilter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: InkGlassCard(child: Text('card'))),
          ),
        ),
      );
      expect(find.text('card'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('InkGlassPanel renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: InkGlassPanel(child: Text('panel'))),
          ),
        ),
      );
      expect(find.text('panel'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('InkGlassPill renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: InkGlassPill(child: Text('pill'))),
          ),
        ),
      );
      expect(find.text('pill'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('InkGlassCard accepts padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkGlassCard(
                padding: EdgeInsets.all(16),
                child: Text('padded'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('padded'), findsOneWidget);
    });
  });
}
