// InkNameDialog：三处"给它起个名字"的对话框收成一份之后的行为契约
//（CH-2 残留④）。文案全部由调用方给——theme 层不碰 ARB。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/components/ink_name_dialog.dart';

import '../../_harness/test_app.dart';

void main() {
  /// 收框返回值：null = 取消。用列表而不是单值，好区分"还没返回"与"返回了 null"。
  late List<String?> results;

  setUp(() => results = <String?>[]);

  Future<void> open(WidgetTester tester) async {
    await pumpInkApp(
      tester,
      Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                results.add(
                  await showDialog<String>(
                    context: context,
                    builder: (BuildContext _) => const InkNameDialog(
                      title: 'New character',
                      hint: 'Character name',
                      confirmLabel: 'Save',
                      cancelLabel: 'Cancel',
                    ),
                  ),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(InkNameDialog), findsOneWidget);
  }

  /// 确认键按**类型族**取（TextButton / FilledButton 都是 ButtonStyleButton）：
  /// 断言钉的是"禁用态"而不是某个具体按钮件。注意 find.byType 不认子类，
  /// 所以这里走 byWidgetPredicate。
  ButtonStyleButton confirm(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text('Save'),
              matching: find.byWidgetPredicate((Widget w) => w is ButtonStyleButton),
            )
            .first,
      );

  testWidgets('空名字 → 确认键真禁用（onPressed == null，不是空闭包）', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(confirm(tester).onPressed, isNull);
  });

  testWidgets('只打空白 → 仍然禁用', (WidgetTester tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(confirm(tester).onPressed, isNull);
  });

  testWidgets('输入名字 → 确认键可用，返回原始输入（trim 归调用方）', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '  Hero  ');
    await tester.pump();
    expect(confirm(tester).onPressed, isNotNull);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(InkNameDialog), findsNothing);
    expect(results, <String?>['  Hero  ']);
  });

  testWidgets('取消 → 返回 null（取消语义，不是空名字）', (WidgetTester tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Hero');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(InkNameDialog), findsNothing);
    expect(results, <String?>[null]);
  });

  testWidgets('标题 / 提示 / 两个按钮文案全部由调用方给', (WidgetTester tester) async {
    await open(tester);
    expect(find.text('New character'), findsOneWidget);
    expect(find.text('Character name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
