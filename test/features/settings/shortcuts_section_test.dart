// 设置「快捷键」页：清单上屏（动作名走 ARB，键位符号按平台）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/settings/widgets/shortcuts_section.dart';

import '../../_harness/test_app.dart';

void main() {
  testWidgets('macOS：动作名 + ⌘ 键位都上屏，表头两列在场', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ShortcutsSection(isMacOverride: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Shortcut'), findsOneWidget);
    expect(find.text('Command palette'), findsOneWidget);
    expect(find.text('⌘K'), findsOneWidget);
    expect(find.text('Select all nodes'), findsOneWidget);
    expect(find.text('⌘A'), findsOneWidget);
    // 一个动作绑多键 → 同一行里逐个列出。
    expect(find.text('Delete  ·  Backspace'), findsOneWidget);
    expect(
      find.text(
        'Key bindings are fixed in this version — this page lists what is '
        'actually bound.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Windows：同一份清单出 Ctrl 变体，不出 ⌘', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ShortcutsSection(isMacOverride: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ctrl+K'), findsOneWidget);
    expect(find.text('⌘K'), findsNothing);
  });
}
