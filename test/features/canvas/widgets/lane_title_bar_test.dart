import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/widgets/lane_title_bar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('shows label and fires onEdit', (tester) async {
    var edited = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: LaneTitleBar(
          lane: const StyleLane(id: 'a', canvasId: 'c', label: 'Day'),
          onEdit: () => edited = true,
          onDelete: () {},
        ),
      ),
    ));
    expect(find.text('Day'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit).first);
    expect(edited, isTrue);
  });

  testWidgets('shows laneUntitled when label is empty', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: LaneTitleBar(
          lane: const StyleLane(id: 'b', canvasId: 'c', label: ''),
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    ));
    // en locale fallback: "Untitled lane"
    expect(find.text('Untitled lane'), findsOneWidget);
  });

  testWidgets('delete button fires onDelete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: LaneTitleBar(
          lane: const StyleLane(id: 'c', canvasId: 'c', label: 'Night'),
          onEdit: () {},
          onDelete: () => deleted = true,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    expect(deleted, isTrue);
  });

  // ---- Lanes 稿接线补测（P1）----

  Widget wrap(Widget child, {double width = LaneTitleBar.horizontalWidth}) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, height: LaneTitleBar.height, child: child),
          ),
        ),
      );

  testWidgets('两行：名称 + 提示词摘要，节点数等宽显示', (tester) async {
    await tester.pumpWidget(wrap(LaneTitleBar(
      lane: const StyleLane(id: 'a', canvasId: 'c', label: 'Dusk', stylePrompt: 'warm dusk, golden hour'),
      nodeCount: 6,
      onEdit: () {},
      onDelete: () {},
    )));
    expect(find.text('Dusk'), findsOneWidget);
    expect(find.text('warm dusk, golden hour'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '两行 line-height 1.15 必须收进 26 高，不许溢出');
  });

  testWidgets('折叠态：只留名称 + 计数 + 「已折叠」+ 展开键，编辑 / 删除键不出现', (tester) async {
    await tester.pumpWidget(wrap(LaneTitleBar(
      lane: const StyleLane(id: 'a', canvasId: 'c', label: 'Ruins', stylePrompt: 'dark ruin'),
      nodeCount: 3,
      collapsed: true,
      onToggleCollapse: () {},
      onEdit: () {},
      onDelete: () {},
    )));
    expect(find.text('Ruins'), findsOneWidget);
    expect(find.text('Collapsed'), findsOneWidget);
    expect(find.text('dark ruin'), findsNothing, reason: '折叠态不显示提示词行');
    expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('CJK 超长名称与提示词：单行省略，不溢出（横向 268 与竖向下限 128 两种宽）', (tester) async {
    const String longLabel = '黄昏山径松林逆光背影渐清破晓山脊第一缕光回望收尾空镜黄昏山径松林逆光背影渐清';
    const String longPrompt = '暖色黄昏金色时刻长影松林逆光雾气氤氲柔和笔触传统水墨画风暖色黄昏金色时刻长影';
    for (final double w in <double>[LaneTitleBar.horizontalWidth, LaneTitleBar.minWidth]) {
      await tester.pumpWidget(wrap(
        LaneTitleBar(
          lane: const StyleLane(id: 'a', canvasId: 'c', label: longLabel, stylePrompt: longPrompt),
          nodeCount: 12,
          onToggleCollapse: () {},
          onEdit: () {},
          onDelete: () {},
        ),
        width: w,
      ));
      expect(tester.takeException(), isNull, reason: '宽 $w 下不许溢出');
      final Size bar = tester.getSize(find.byType(LaneTitleBar));
      expect(bar.width, w);
      expect(bar.height, LaneTitleBar.height);
      // 三个键都在栏内、可命中。
      expect(tester.getBottomRight(find.byIcon(Icons.delete_outline)).dx, lessThanOrEqualTo(w));
    }
  });
}
