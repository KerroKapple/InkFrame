// InkIcon：图标集 v1 的唯一绘制入口。
//
// 守四件事：尺寸（默认 md，size 照办，按网格等比缩放）、每一笔用对笔型（描边 / 填充）
// 与颜色、不给颜色时跟随 IconTheme、读屏语义（给了名字才说，不给就对读屏透明）。
// 画了什么用 flutter_test 的 paints 匹配器直接回放 CustomPaint 的绘制指令，不靠像素。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/test_app.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    pumpInkApp(tester, Scaffold(body: Center(child: child)));

/// InkIcon 底下那块 CustomPaint：paints 匹配器在它的 RenderObject 上回放绘制。
Finder _canvasOf(Finder icon) =>
    find.descendant(of: icon, matching: find.byType(CustomPaint));

void main() {
  testWidgets('默认尺寸 = InkIconSize.md；size 参数照办', (tester) async {
    const Key md = Key('md');
    const Key sm = Key('sm');
    const Key big = Key('big');
    await _pump(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkIcon(InkGlyph.close, key: md),
          InkIcon(InkGlyph.close, key: sm, size: InkIconSize.sm),
          InkIcon(InkGlyph.close, key: big, size: 40),
        ],
      ),
    );

    expect(tester.getSize(find.byKey(md)), const Size.square(InkIconSize.md));
    expect(tester.getSize(find.byKey(sm)), const Size.square(InkIconSize.sm));
    expect(tester.getSize(find.byKey(big)), const Size.square(40));
  });

  testWidgets('按尺寸等比缩放：40px = 20 网格的 2 倍，画布 scale(2)', (tester) async {
    await _pump(tester, const InkIcon(InkGlyph.close, size: 40));

    expect(
      _canvasOf(find.byType(InkIcon)),
      paints
        ..something(
          (Symbol method, List<dynamic> args) =>
              method == #scale && args.first == 2.0,
        ),
    );
  });

  testWidgets('描边笔：close 只有一笔描边——网格线宽 1.5、给定颜色', (tester) async {
    final Color probe = InkColors.dark().accent;
    await _pump(tester, InkIcon(InkGlyph.close, color: probe));

    final Finder canvas = _canvasOf(find.byType(InkIcon));
    expect(canvas, paintsExactlyCountTimes(#drawPath, 1));
    expect(
      canvas,
      paints
        ..path(
          style: PaintingStyle.stroke,
          strokeWidth: InkIconSize.gridStroke,
          color: probe,
        ),
    );
  });

  testWidgets('填充笔：more 是三个实心圆点，按数据顺序画、都用给定颜色', (tester) async {
    final Color probe = InkColors.dark().accent;
    await _pump(tester, InkIcon(InkGlyph.more, color: probe));

    final Finder canvas = _canvasOf(find.byType(InkIcon));
    expect(canvas, paintsExactlyCountTimes(#drawPath, 3));
    // 路径本身在网格坐标里（缩放做在画布上），所以圆心按 20 网格写。
    expect(
      canvas,
      paints
        ..path(
          style: PaintingStyle.fill,
          color: probe,
          includes: const <Offset>[Offset(4.75, 10)],
        )
        ..path(
          style: PaintingStyle.fill,
          color: probe,
          includes: const <Offset>[Offset(10, 10)],
        )
        ..path(
          style: PaintingStyle.fill,
          color: probe,
          includes: const <Offset>[Offset(15.25, 10)],
        ),
    );
  });

  testWidgets('同一图标里描边与填充混用：warning 先描竖线、再填圆点', (tester) async {
    final Color probe = InkColors.dark().accent;
    await _pump(tester, InkIcon(InkGlyph.warning, color: probe));

    final Finder canvas = _canvasOf(find.byType(InkIcon));
    expect(canvas, paintsExactlyCountTimes(#drawPath, 2));
    expect(
      canvas,
      paints
        ..path(style: PaintingStyle.stroke, color: probe)
        ..path(
          style: PaintingStyle.fill,
          color: probe,
          includes: const <Offset>[Offset(10, 14.75)],
        ),
    );
  });

  testWidgets('不给 color：跟随最近的 IconTheme', (tester) async {
    final Color themed = InkColors.dark().success;
    await _pump(
      tester,
      IconTheme(
        data: IconThemeData(color: themed),
        child: const InkIcon(InkGlyph.close),
      ),
    );

    expect(_canvasOf(find.byType(InkIcon)), paints..path(color: themed));
  });

  testWidgets('显式 color 优先于 IconTheme', (tester) async {
    final Color themed = InkColors.dark().success;
    final Color explicit = InkColors.dark().danger;
    await _pump(
      tester,
      IconTheme(
        data: IconThemeData(color: themed),
        child: InkIcon(InkGlyph.close, color: explicit),
      ),
    );

    expect(_canvasOf(find.byType(InkIcon)), paints..path(color: explicit));
  });

  testWidgets('给了 semanticLabel：读屏读到这个名字，并标成图片', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      const InkIcon(InkGlyph.close, semanticLabel: 'Close panel'),
    );

    final Finder labelled = find.bySemanticsLabel('Close panel');
    expect(labelled, findsOneWidget);
    expect(
      tester.getSemantics(labelled),
      isSemantics(label: 'Close panel', isImage: true),
    );
    handle.dispose();
  });

  testWidgets('不给 semanticLabel：图标对读屏透明，不往所在节点里掺字', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    // 外层给一个有名字的容器节点：图标若自带任何语义，会并进这个节点。
    await _pump(
      tester,
      Semantics(
        container: true,
        label: 'Toolbar slot',
        child: const InkIcon(InkGlyph.close),
      ),
    );

    expect(
      tester.getSemantics(find.byType(InkIcon)),
      isSemantics(label: 'Toolbar slot', isImage: false),
      reason: '没给名字的图标不该往外层节点里加字，也不该把它标成图片',
    );
    handle.dispose();
  });
}
