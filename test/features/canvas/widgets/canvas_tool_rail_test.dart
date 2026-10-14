// CanvasToolRail 的图标接线：七个格子各画图标集 v1 的哪一个（16px），以及图标颜色随
// 格子状态走——激活 = onAccent（琥珀底上的深色）、可用 = fg3、禁用 = fg6。
//
// 工具条构建时只读连线模式与选中态两个纯内存 Notifier，不需要任何仓储 override；
// 状态直接从 ProviderContainer 驱动。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_tool_rail.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/test_app.dart';

const String _canvasId = 'c1';

/// 格子 id → 该格应画的图标。
const Map<String, InkGlyph> _glyphOf = <String, InkGlyph>{
  'select': InkGlyph.select,
  'pan': InkGlyph.pan,
  'link': InkGlyph.link,
  'text': InkGlyph.text,
  'image': InkGlyph.imageConfig,
  'video': InkGlyph.videoConfig,
  'lane': InkGlyph.lane,
};

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await pumpInkApp(
    tester,
    const Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: CanvasToolRail(canvasId: _canvasId),
      ),
    ),
    surfaceSize: const Size(400, 600),
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(CanvasToolRail)),
    listen: false,
  );
}

InkIcon _iconOf(WidgetTester tester, String tool) => tester.widget<InkIcon>(
      find.descendant(
        of: find.byKey(CanvasToolRail.keyOf(tool)),
        matching: find.byType(InkIcon),
      ),
    );

void main() {
  testWidgets('七个格子各画图标集 v1 的对应图标，16px', (tester) async {
    await _pump(tester);

    for (final MapEntry<String, InkGlyph> e in _glyphOf.entries) {
      expect(find.byKey(CanvasToolRail.keyOf(e.key)), findsOneWidget, reason: e.key);
      final InkIcon icon = _iconOf(tester, e.key);
      expect(icon.glyph, e.value, reason: '${e.key} 格的图标');
      expect(icon.size, InkIconSize.sm, reason: '${e.key} 格的图标尺寸');
    }
  });

  testWidgets('默认态：选择 = 激活（onAccent）；平移 / 连线 = 禁用（fg6）；其余可用（fg3）',
      (tester) async {
    await _pump(tester);
    final InkColors c = InkColors.dark();

    expect(_iconOf(tester, 'select').color, c.onAccent,
        reason: '不在连线模式时「选择」是激活态，图标压在琥珀底上');
    expect(_iconOf(tester, 'pan').color, c.fg6, reason: '平移没有独立工具态，恒禁用');
    expect(_iconOf(tester, 'link').color, c.fg6, reason: '没选中节点时连线不可用');
    for (final String id in <String>['text', 'image', 'video', 'lane']) {
      expect(_iconOf(tester, id).color, c.fg3, reason: id);
    }
  });

  testWidgets('选中恰好一个节点 → 连线可用（fg3）；选中两个又回到禁用（fg6）', (tester) async {
    final ProviderContainer container = await _pump(tester);
    final CanvasSelectionController selection =
        container.read(canvasSelectionControllerProvider(_canvasId).notifier);
    final InkColors c = InkColors.dark();

    selection.select('n1');
    await tester.pump();
    expect(_iconOf(tester, 'link').color, c.fg3);

    selection.select('n2', toggle: true);
    await tester.pump();
    expect(_iconOf(tester, 'link').color, c.fg6);
  });

  testWidgets('连线模式：连线格激活（onAccent），选择格退为可用（fg3，点它 = 退出连线）',
      (tester) async {
    final ProviderContainer container = await _pump(tester);
    final InkColors c = InkColors.dark();

    container.read(linkModeControllerProvider(_canvasId).notifier).start('n1');
    await tester.pump();

    expect(_iconOf(tester, 'link').color, c.onAccent);
    expect(_iconOf(tester, 'select').color, c.fg3);
  });
}
