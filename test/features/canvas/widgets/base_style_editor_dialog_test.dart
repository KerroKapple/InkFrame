// base_style_editor_dialog widget 测试：预填 + 预设点击 + Save/Cancel 路径。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/base_style_editor_dialog.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

// T16 并行任务提供此文件；测试阶段 stub 不存在时改为直接导入实际路径。
import 'package:inkframe/features/canvas/util/base_style_presets.dart';

void main() {
  // 标准测试脚手架：l10n + 深色主题。
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        home: child,
      );

  testWidgets('prefix/suffix 预填正确显示', (tester) async {
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showBaseStyleEditorDialog(
                ctx,
                prefix: 'pre text',
                suffix: 'suf text',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('pre text'), findsOneWidget);
    expect(find.text('suf text'), findsOneWidget);
  });

  testWidgets('点击 Cinematic 预设→前缀字段更新为英文 prompt', (tester) async {
    ({String prefix, String suffix})? result;

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showBaseStyleEditorDialog(
                  ctx,
                  prefix: 'old prefix',
                  suffix: 'old suffix',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 点击 Cinematic 预设芯片（l10n 英文标签 "Cinematic"）。
    await tester.tap(find.text('Cinematic'));
    await tester.pumpAndSettle();

    // 找到 cinematic preset 的英文 prompt。
    final cinematicPreset = kBaseStylePresets.firstWhere((p) => p.id == 'cinematic');

    // 点 Save，断言返回值。
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.prefix, cinematicPreset.prompt);
    expect(result!.suffix, 'old suffix');
  });

  testWidgets('Cancel 返回 null', (tester) async {
    ({String prefix, String suffix})? result =
        (prefix: 'x', suffix: 'y');

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showBaseStyleEditorDialog(
                  ctx,
                  prefix: 'a',
                  suffix: 'b',
                );
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

  testWidgets('Save 返回 trim 后的 prefix/suffix', (tester) async {
    ({String prefix, String suffix})? result;

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showBaseStyleEditorDialog(
                  ctx,
                  prefix: 'my prefix',
                  suffix: 'my suffix',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 编辑前缀字段。
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, '  edited prefix  ');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.prefix, 'edited prefix');
  });
}
