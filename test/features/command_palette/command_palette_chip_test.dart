// PL-1：⌘K chip 不再是纯展示——点击唤起命令面板。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_chip.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';

import '../../_harness/test_app.dart';

void main() {
  testWidgets('chip 显示快捷键文案，点击打开命令面板', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: Center(child: CommandPaletteChip())),
    );
    await tester.pumpAndSettle();

    // 测试平台非 macOS → Ctrl K。
    expect(find.text('Ctrl K'), findsOneWidget);
    expect(find.byType(CommandPaletteDialog), findsNothing);

    await tester.tap(find.text('Ctrl K'));
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteDialog), findsOneWidget);
  });
}
