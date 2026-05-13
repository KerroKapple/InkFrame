// 排版 token：widget 只读 context.inkTypography 获得 TextStyle。
//
// 字号通过 A11y §20.1 的"界面字号"档位在上层 ThemeExtension 乘以缩放系数
// 后注入，不直接依赖 MediaQuery.textScaler——保证 golden test 可控。
//
// Amber Noir 字体方案：
//   - display / headline：CormorantGaramond（衬线，氛围标题）
//   - caption：JetBrainsMono（等宽，标签 / 元数据）
//   - 其余：系统默认无衬线（body / title / label / micro / nano）
//   - code：等宽 fallback（保留旧字段供代码块复用）
import 'package:flutter/widgets.dart';

@immutable
class InkTypography {
  const InkTypography({
    required this.display,
    required this.headline,
    required this.title,
    required this.body,
    required this.label,
    required this.caption,
    required this.micro,
    required this.nano,
    required this.code,
  });

  factory InkTypography.defaults({double scale = 1.0}) => InkTypography(
        display: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontSize: 48 * scale,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.5,
          height: 1.15,
        ),
        headline: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontSize: 22 * scale,
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
          fontSize: 11 * scale,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.5,
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
  final TextStyle title;
  final TextStyle body;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle micro;
  final TextStyle nano;
  final TextStyle code;

  InkTypography scaled(double scale) => InkTypography(
        display: display.copyWith(fontSize: (display.fontSize ?? 48) * scale),
        headline: headline.copyWith(fontSize: (headline.fontSize ?? 22) * scale),
        title: title.copyWith(fontSize: (title.fontSize ?? 18) * scale),
        body: body.copyWith(fontSize: (body.fontSize ?? 14) * scale),
        label: label.copyWith(fontSize: (label.fontSize ?? 13) * scale),
        caption: caption.copyWith(fontSize: (caption.fontSize ?? 11) * scale),
        micro: micro.copyWith(fontSize: (micro.fontSize ?? 10) * scale),
        nano: nano.copyWith(fontSize: (nano.fontSize ?? 9) * scale),
        code: code.copyWith(fontSize: (code.fontSize ?? 13) * scale),
      );
}
