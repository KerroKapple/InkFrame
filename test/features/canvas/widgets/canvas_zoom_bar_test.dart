// CanvasZoomBar（左下缩放条）：缩小 / 放大画图标集 v1 的 zoomOut / zoomIn（16px），
// 不再是「−」「+」两个字符；图标格有名字（读屏 + tooltip）；点了改缩放，「适应」复位。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/widgets/canvas_header_bar.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/test_app.dart';

const String _canvasId = 'c1';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: Center(child: CanvasZoomBar(canvasId: _canvasId))),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasZoomBar)));
}

Finder _glyph(InkGlyph glyph) => find.descendant(
      of: find.byType(CanvasZoomBar),
      matching: find.byWidgetPredicate(
        (Widget w) => w is InkIcon && w.glyph == glyph,
      ),
    );

void main() {
  testWidgets('缩小 / 放大是 zoomOut / zoomIn 图标（16px），不再是字符；图标格有 tooltip',
      (tester) async {
    await _pump(tester);

    expect(_glyph(InkGlyph.zoomOut), findsOneWidget);
    expect(_glyph(InkGlyph.zoomIn), findsOneWidget);
    expect(tester.widget<InkIcon>(_glyph(InkGlyph.zoomOut)).size, InkIconSize.sm);
    expect(tester.widget<InkIcon>(_glyph(InkGlyph.zoomIn)).size, InkIconSize.sm);
    expect(find.text('−'), findsNothing);
    expect(find.text('+'), findsNothing);
    expect(find.text('Fit'), findsOneWidget, reason: '「适应」与百分比读数保留');
    expect(find.text('100%'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
  });

  testWidgets('点放大 → 变大；点缩小 → 变小；点适应 → 回初始相机', (tester) async {
    final ProviderContainer container = await _pump(tester);
    Matrix4 current() =>
        container.read(canvasTransformControllerProvider(_canvasId)).value;

    await tester.tap(_glyph(InkGlyph.zoomIn));
    await tester.pump();
    final double zoomedIn = scaleOf(current());
    expect(zoomedIn, greaterThan(1.0));

    await tester.tap(_glyph(InkGlyph.zoomOut));
    await tester.pump();
    expect(scaleOf(current()), lessThan(zoomedIn));

    await tester.tap(find.text('Fit'));
    await tester.pump();
    expect(current(), initialCanvasTransform());
  });
}
