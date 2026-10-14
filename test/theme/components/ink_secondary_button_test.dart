// InkSecondaryButton 的图标位：标签栏「在序列中查看」按稿带一个 14px 图标（左右内边距收成 10）。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/components/ink_primitives.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/test_app.dart';

void main() {
  testWidgets('不给 leading：只有文字，左右内边距 12', (tester) async {
    // 生产里它在标签栏的 Row 里（不定宽 ⇒ 收缩到内容）；Center 下会被 alignment 撑满宽度。
    await pumpInkApp(tester, const Center(child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[InkSecondaryButton('Export')])));
    expect(find.byType(InkIcon), findsNothing);
    final Rect button = tester.getRect(find.byType(InkSecondaryButton));
    final Rect text = tester.getRect(find.text('Export'));
    // 1px 边框在内边距外面：内容起点 = 1 + 12。
    expect(text.left - button.left, closeTo(1 + InkSpacing.s12, 0.5));
  });

  testWidgets('给 leading：文字左边一个 14px 图标，间距 6，左右内边距收成 10', (tester) async {
    await pumpInkApp(
      tester,
      const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[InkSecondaryButton('View in sequence', leading: InkGlyph.sequence)],
        ),
      ),
    );
    final InkIcon icon = tester.widget<InkIcon>(find.byType(InkIcon));
    expect(icon.glyph, InkGlyph.sequence);
    expect(icon.size, InkIconSize.s14);
    final Rect button = tester.getRect(find.byType(InkSecondaryButton));
    final Rect iconRect = tester.getRect(find.byType(InkIcon));
    final Rect text = tester.getRect(find.text('View in sequence'));
    expect(iconRect.left - button.left, closeTo(1 + InkSpacing.s10, 0.5));
    expect(text.left - iconRect.right, closeTo(InkSpacing.s6, 0.5));
  });
}
