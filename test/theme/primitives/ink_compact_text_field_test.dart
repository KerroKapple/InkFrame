// InkCompactTextField 测试：输入 + onChanged + placeholder + 多行。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/primitives/ink_compact_text_field.dart';

void main() {
  group('InkCompactTextField', () {
    testWidgets('renders placeholder when empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkCompactTextField(placeholder: '输入提示词'),
            ),
          ),
        ),
      );
      expect(find.text('输入提示词'), findsOneWidget);
    });

    testWidgets('onChanged receives typed text', (tester) async {
      String latest = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkCompactTextField(
                onChanged: (v) => latest = v,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'hello');
      expect(latest, 'hello');
    });

    testWidgets('multi-line (maxLines: null) accepts newlines', (tester) async {
      String latest = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkCompactTextField(
                maxLines: null,
                minLines: 3,
                onChanged: (v) => latest = v,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'line1\nline2');
      expect(latest.contains('\n'), isTrue);
    });

    testWidgets('initial value renders', (tester) async {
      final ctrl = TextEditingController(text: 'preset');
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkCompactTextField(controller: ctrl),
            ),
          ),
        ),
      );
      expect(find.text('preset'), findsOneWidget);
    });
  });
}
