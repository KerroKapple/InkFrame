// 图标集 v1 总表 golden：全部图标 × 16 / 20 / 24 三档，fg3 画在暗色主题上。
//
// 这张图守的是「路径数据 → 像素」整条链：路径数据本身（ink_glyph，与设计稿逐字相同）、
// 解析（svg_path_data）、按尺寸缩放与描边（InkIcon）。改了任何一笔都要重铸基线。
//
// 基线存在才跑（_goldensPresent），否则 skip；基线只在 canonical ubuntu
// （update-goldens.yml workflow_dispatch）生成提交——详见 node_card_golden_test。
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/golden_scaffold.dart';

final bool _goldensPresent =
    File('test/theme/icons/goldens/ink_icon_sheet.png').existsSync();
final bool _skipGolden = !_goldensPresent && !autoUpdateGoldenFiles;

const Size _surface = Size(960, 600);

/// 三档尺寸：列表行 16、导航 / 工具条 20（网格原尺寸）、再大一档看缩放后的描边。
const List<double> _sizes = <double>[InkIconSize.sm, InkIconSize.md, 24];

const Key _sheetKey = ValueKey<String>('inkIconSheet');

/// 每格 = 三档图标一行 + 图标名；一行 8 格，44 个图标排 6 行。
const double _cellWidth = 112;
const double _cellHeight = 60;
const int _perRow = 8;

Widget _sheet() => Builder(
      builder: (BuildContext context) {
        final c = context.inkColors;
        final t = context.inkTypography;
        return RepaintBoundary(
          key: _sheetKey,
          child: ColoredBox(
            color: c.surface2,
            child: Padding(
              padding: const EdgeInsets.all(InkSpacing.md),
              child: SizedBox(
                width: _cellWidth * _perRow,
                child: Wrap(
                  children: <Widget>[
                    for (final InkGlyph glyph in InkGlyph.values)
                      SizedBox(
                        width: _cellWidth,
                        height: _cellHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: InkSpacing.xs,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              spacing: InkSpacing.sm,
                              children: <Widget>[
                                for (final double size in _sizes)
                                  InkIcon(glyph, size: size, color: c.fg3),
                              ],
                            ),
                            Text(
                              glyph.name,
                              style: t.mono.copyWith(color: c.fg6),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

void main() {
  testWidgets(
    '图标集 v1 总表：全部图标 × 16 / 20 / 24，fg3 画在暗色主题上',
    (tester) async {
      await pumpGoldenScene(tester, _sheet(), size: _surface);
      expect(
        find.byType(InkIcon),
        findsNWidgets(InkGlyph.values.length * _sizes.length),
        reason: '总表必须一个不落：漏画的图标不会出现在基线里',
      );
      await expectLater(
        find.byKey(_sheetKey),
        matchesGoldenFile('goldens/ink_icon_sheet.png'),
      );
    },
    skip: _skipGolden,
  );
}
