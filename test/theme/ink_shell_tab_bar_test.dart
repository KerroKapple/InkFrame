// InkShellTabBar：五个标签 chip 的渲染序、选中态写回、窄屏退化阈值。
//
// 阈值 compactBelow 不是拍脑袋来的：本文件实测 en / zh × textScale 1.0/1.3 下
// 五个 chip 的自然宽度之和 + 左右 gutter，断言它不超过阈值。文案变长或字重变化
// 导致 chip 撑破阈值时，这条会红——阈值与实际渲染宽度不会静默脱钩。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/theme/components/ink_shell_tab_bar.dart';
import 'package:inkframe/theme/tokens.dart';

import '../_harness/test_app.dart';

Finder _tab(ShellTab t) => find.byKey(ValueKey<String>('shellTab-${t.name}'));

Future<double> _naturalChipRunWidth(
  WidgetTester tester, {
  required Locale locale,
  required double textScale,
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: Column(children: <Widget>[InkShellTabBar()])),
    locale: locale,
    textScale: textScale,
    surfaceSize: const Size(1600, 400),
  );
  await tester.pump();
  double total = 0;
  for (final ShellTab t in ShellTab.values) {
    total += tester.getSize(_tab(t)).width;
  }
  return total;
}

void main() {
  testWidgets('五个 chip 按 ShellTab 声明序渲染，且都带稳定 Key', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: Column(children: <Widget>[InkShellTabBar()])),
      surfaceSize: const Size(1440, 400),
    );
    await tester.pump();

    double lastLeft = -1;
    for (final ShellTab t in ShellTab.values) {
      expect(_tab(t), findsOneWidget, reason: '缺 chip: ${t.name}');
      final double left = tester.getTopLeft(_tab(t)).dx;
      expect(left, greaterThan(lastLeft), reason: '${t.name} 的渲染序与声明序不符');
      lastLeft = left;
    }
    expect(tester.getSize(find.byType(InkShellTabBar)).height, 44);
  });

  testWidgets('点 chip → goTab 写回 ShellState，一帧落地', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: Column(children: <Widget>[InkShellTabBar()])),
      surfaceSize: const Size(1440, 400),
    );
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(InkShellTabBar)),
      listen: false,
    );
    await tester.pump();

    expect(container.read(shellControllerProvider).tab, ShellTab.studio);
    // 标签条【不在】DragToMoveArea 里 ⇒ 单击一帧落地。若这里必须补
    // pump(400ms) 才稳，说明有人把标签条挪进了 chrome，回退。
    await tester.tap(_tab(ShellTab.gallery));
    await tester.pump();
    expect(container.read(shellControllerProvider).tab, ShellTab.gallery);
  });

  testWidgets('宽屏出文字标签，窄屏退化成纯图标', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: Column(children: <Widget>[InkShellTabBar()])),
      surfaceSize: const Size(1440, 400),
    );
    await tester.pump();
    expect(find.text('Sequence'), findsOneWidget);

    await pumpInkApp(
      tester,
      const Scaffold(body: Column(children: <Widget>[InkShellTabBar()])),
      surfaceSize: const Size(InkShellTabBar.compactBelow - 1, 400),
    );
    await tester.pump();
    expect(find.text('Sequence'), findsNothing);
    // 退化后仍然找得到每个 chip（Key 落在槽上，不随形态变化）。
    for (final ShellTab t in ShellTab.values) {
      expect(_tab(t), findsOneWidget);
    }
  });

  testWidgets('阈值实测：en / zh × textScale 1.0/1.3 的自然宽度都装得下',
      (tester) async {
    for (final Locale locale in <Locale>[
      const Locale('en'),
      const Locale('zh'),
    ]) {
      for (final double scale in <double>[1.0, 1.3]) {
        final double run = await _naturalChipRunWidth(
          tester,
          locale: locale,
          textScale: scale,
        );
        expect(
          run + InkSpacing.lg * 2,
          lessThanOrEqualTo(InkShellTabBar.compactBelow),
          reason: '$locale @ ${scale}x 的五 chip 自然宽 $run 撑破了退化阈值 '
              '${InkShellTabBar.compactBelow}——要么收文案，要么抬阈值',
        );
      }
    }
  });

  testWidgets('960×600 + textScale 1.3 下无溢出', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: Column(children: <Widget>[InkShellTabBar()])),
      textScale: 1.3,
      surfaceSize: const Size(960, 600),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
