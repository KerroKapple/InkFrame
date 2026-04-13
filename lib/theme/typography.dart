// 排版 token：widget 只读 context.inkTypography 获得 TextStyle。
//
// 字号通过 A11y §20.1 的"界面字号"档位在上层 ThemeExtension 乘以缩放系数
// 后注入，不直接依赖 MediaQuery.textScaler——保证 golden test 可控。
import 'package:flutter/widgets.dart';

@immutable
class InkTypography {
  const InkTypography({
    required this.display,
    required this.title,
    required this.body,
    required this.label,
    required this.caption,
    required this.code,
  });

  factory InkTypography.defaults({double scale = 1.0}) => InkTypography(
        display: TextStyle(
          fontSize: 28 * scale,
          fontWeight: FontWeight.w600,
          height: 1.2,
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
          fontSize: 12 * scale,
          fontWeight: FontWeight.w400,
          height: 1.35,
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
  final TextStyle title;
  final TextStyle body;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle code;

  InkTypography scaled(double scale) => InkTypography(
        display: display.copyWith(fontSize: (display.fontSize ?? 28) * scale),
        title: title.copyWith(fontSize: (title.fontSize ?? 18) * scale),
        body: body.copyWith(fontSize: (body.fontSize ?? 14) * scale),
        label: label.copyWith(fontSize: (label.fontSize ?? 13) * scale),
        caption: caption.copyWith(fontSize: (caption.fontSize ?? 12) * scale),
        code: code.copyWith(fontSize: (code.fontSize ?? 13) * scale),
      );
}
