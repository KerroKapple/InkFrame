// LaneEditDialog widget 测试：填名称+风格→Save→断言返回值。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/util/lane_tint.dart';
import 'package:inkframe/features/canvas/widgets/lane_edit_dialog.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  // 构造标准测试脚手架：带 l10n + 主题的 MaterialApp。
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        home: child,
      );

  testWidgets('填名称+风格→Save→返回正确 LaneEditResult（tintColor==null）',
      (tester) async {
    LaneEditResult? result;

    // 被测按钮：点击后打开弹窗并记录返回值。
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showLaneEditDialog(ctx);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    // 打开弹窗。
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 找到两个 TextField（InkInput 内部用 TextField）。
    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeastNWidgets(2));

    // 第一个：名称；第二个：风格描述。
    await tester.enterText(textFields.first, 'Day Scene');
    await tester.enterText(textFields.at(1), 'warm sunset lighting');
    await tester.pumpAndSettle();

    // 点 Save（使用 l10n 英文值 "Save"）。
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // 断言返回值。
    expect(result, isNotNull);
    expect(result!.label, 'Day Scene');
    expect(result!.stylePrompt, 'warm sunset lighting');
    // 默认未选色块 → tintColor 为 null（自动）。
    expect(result!.tintColor, isNull);
  });

  testWidgets('取消→返回 null', (tester) async {
    LaneEditResult? result = const LaneEditResult(
      label: 'x',
      stylePrompt: 'y',
      tintColor: null,
    );

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showLaneEditDialog(ctx);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('existing 泳道预填字段', (tester) async {
    const existing = StyleLane(
      id: 'l1',
      canvasId: 'c1',
      label: '夜景',
      stylePrompt: '霓虹雨夜',
      tintColor: '#4A78C8',
    );

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showLaneEditDialog(ctx, existing: existing),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 名称和风格已预填。
    expect(find.text('夜景'), findsOneWidget);
    expect(find.text('霓虹雨夜'), findsOneWidget);
  });

  // ---- Lanes 稿接线补测（P1，改动 6）----

  Future<void> open(WidgetTester tester, StyleLane? existing) async {
    await tester.pumpWidget(wrap(Scaffold(
      body: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => showLaneEditDialog(ctx, existing: existing),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder swatches() => find.byWidgetPredicate(
        (Widget w) => w is Container && w.constraints?.maxWidth == 26 && w.constraints?.maxHeight == 26,
      );

  testWidgets('「自动」推断说明：命中时写出命中的词与色值', (tester) async {
    await open(tester, const StyleLane(id: 'l', canvasId: 'c', label: 'Night', stylePrompt: 'cyberpunk, neon-lit, rain-slicked streets'));
    expect(find.text('Auto picks from the prompt — matched “rain / neon” → #4A78C8.'), findsOneWidget);
  });

  testWidgets('「自动」推断说明：没命中写「不绘底色」；色板 = 词表五色；手动选色后说明消失', (tester) async {
    await open(tester, const StyleLane(id: 'l', canvasId: 'c', label: 'Plain', stylePrompt: 'plain daylight'));
    expect(find.text('Auto picks from the prompt — no keyword matched, no tint is drawn.'), findsOneWidget);
    expect(swatches(), findsNWidgets(kLaneTintChoices.length), reason: '改动 6：色板只认词表');
    await tester.tap(swatches().first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Auto picks from the prompt'), findsNothing);
  });

  testWidgets('底部条：厚度说明 + 取消 / 保存；不再是 AlertDialog', (tester) async {
    await open(tester, null);
    expect(find.text('Thickness is not set here — drag the divider.'), findsOneWidget);
    expect(find.text('New lane'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing, reason: '稿是自定义对话框壳');
  });
}
