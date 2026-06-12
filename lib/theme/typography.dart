// 排版 token：widget 只读 context.inkTypography 获得 TextStyle。
//
// 字号通过 A11y §20.1 的"界面字号"档位在上层 ThemeExtension 乘以缩放系数
// 后注入，不直接依赖 MediaQuery.textScaler——保证 golden test 可控。
// 禁止 widget 内 copyWith(fontSize:) 钉死字号——会绕过 a11y 缩放。
//
// Amber Noir 字体方案：
//   - display / headline / headlineSm / headlineXs：CormorantGaramond（衬线，氛围标题）
//   - caption / overline / monoMicro / monoNano：JetBrainsMono（等宽，标签 / 元数据）
//   - 其余：系统默认无衬线（body / title / label / micro / nano）
//   - code：等宽 fallback（保留旧字段供代码块复用）
import 'package:flutter/widgets.dart';

const List<String> _serifFallback = <String>[
  'PingFang SC',
  'Microsoft YaHei',
  'Noto Serif CJK SC',
  'Noto Sans CJK SC',
];

const List<String> _monoFallback = <String>[
  'Menlo',
  'Consolas',
  'PingFang SC',
  'Microsoft YaHei',
];

@immutable
class InkTypography {
  const InkTypography({
    required this.display,
    required this.headline,
    required this.headlineSm,
    required this.headlineXs,
    required this.title,
    required this.body,
    required this.label,
    required this.caption,
    required this.overline,
    required this.micro,
    required this.nano,
    required this.monoMicro,
    required this.monoNano,
    required this.code,
  });

  factory InkTypography.defaults({double scale = 1.0}) => InkTypography(
        display: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontFamilyFallback: _serifFallback,
          fontSize: 48 * scale,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.5,
          height: 1.15,
        ),
        headline: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontFamilyFallback: _serifFallback,
          fontSize: 22 * scale,
          fontWeight: FontWeight.w400,
          height: 1.25,
        ),
        headlineSm: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontFamilyFallback: _serifFallback,
          fontSize: 18 * scale,
          fontWeight: FontWeight.w400,
          height: 1.25,
        ),
        headlineXs: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontFamilyFallback: _serifFallback,
          fontSize: 16 * scale,
          fontWeight: FontWeight.w400,
          height: 1.25,
        ),
        title: TextStyle(
          fontSize: 18 * scale,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        body: TextStyle(
          fontSize: 14 * scale,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        label: TextStyle(
          fontSize: 13 * scale,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        caption: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: _monoFallback,
          fontSize: 11 * scale,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.5,
          height: 1.35,
        ),
        overline: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: _monoFallback,
          fontSize: 11 * scale,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.8,
          height: 1.35,
        ),
        micro: TextStyle(
          fontSize: 10 * scale,
          fontWeight: FontWeight.w400,
          height: 1.3,
        ),
        nano: TextStyle(
          fontSize: 9 * scale,
          fontWeight: FontWeight.w400,
          height: 1.25,
        ),
        monoMicro: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: _monoFallback,
          fontSize: 10 * scale,
          fontWeight: FontWeight.w400,
          height: 1.3,
        ),
        monoNano: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: _monoFallback,
          fontSize: 9 * scale,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.8,
          height: 1.25,
        ),
        code: TextStyle(
          fontSize: 13 * scale,
          fontWeight: FontWeight.w400,
          height: 1.45,
          fontFamily: 'monospace',
          fontFamilyFallback: const <String>['Menlo', 'Consolas', 'Monaco'],
        ),
      );

  final TextStyle display;
  final TextStyle headline;
  final TextStyle headlineSm; // 衬线 18（节点卡标题 / 顶栏 logo）
  final TextStyle headlineXs; // 衬线 16（画布顶栏 logo）
  final TextStyle title;
  final TextStyle body;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle overline; // 等宽 kicker（分节标题，宽字距）
  final TextStyle micro;
  final TextStyle nano;
  final TextStyle monoMicro; // 等宽 10（ID / 分辨率元数据）
  final TextStyle monoNano; // 等宽 9（类型标签，宽字距）
  final TextStyle code;

  InkTypography scaled(double scale) => InkTypography(
        display: _scale(display, 48, scale),
        headline: _scale(headline, 22, scale),
        headlineSm: _scale(headlineSm, 18, scale),
        headlineXs: _scale(headlineXs, 16, scale),
        title: _scale(title, 18, scale),
        body: _scale(body, 14, scale),
        label: _scale(label, 13, scale),
        caption: _scale(caption, 11, scale),
        overline: _scale(overline, 11, scale),
        micro: _scale(micro, 10, scale),
        nano: _scale(nano, 9, scale),
        monoMicro: _scale(monoMicro, 10, scale),
        monoNano: _scale(monoNano, 9, scale),
        code: _scale(code, 13, scale),
      );

  static TextStyle _scale(TextStyle s, double base, double scale) =>
      s.copyWith(fontSize: (s.fontSize ?? base) * scale);
}
