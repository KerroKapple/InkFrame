// 设计 token：三主题变体 + 间距/圆角/阴影/排版原值。
//
// 这是整个应用唯一允许出现原始色值 / 数值的文件。所有 widget 与组件必须
// 通过 InkSpacing / InkRadius / InkShadow / InkTypography / context.inkColors 消费。
//
// 三态变体：dark / light / highContrast。highContrast 是 A11y §20.1 基线的
// 开关目标，前景色与背景色的对比度 ≥ 7:1（WCAG AAA 参考值），实际 CI 不做
// 自动对比度检查——值由人工维护。
import 'package:flutter/widgets.dart';

/// 语义化色板：widget 永远读这个接口，token 工厂决定具体值。
@immutable
class InkColors {
  const InkColors._({
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.accent,
    required this.brand,
    required this.danger,
    required this.warning,
    required this.success,
    required this.border,
    required this.focusRing,
    required this.overlay,
    required this.scrim,
  });

  /// 深色主题（P0 默认）。
  factory InkColors.dark() => const InkColors._(
        surface1: Color(0xFF0F0F13),
        surface2: Color(0xFF1C1C24),
        surface3: Color(0xFF2A2A3A),
        fg1: Color(0xFFF5F5F7),
        fg2: Color(0xFFB5B5C0),
        fg3: Color(0xFF7A7A85),
        accent: Color(0xFF7B61FF),
        brand: Color(0xFFA88BFF),
        danger: Color(0xFFF5534A),
        warning: Color(0xFFF5B72E),
        success: Color(0xFF4CC38A),
        border: Color(0xFF32323F),
        focusRing: Color(0xFF8E72FF),
        overlay: Color(0xCC0F0F13),
        scrim: Color(0x99000000),
      );

  /// 浅色主题（P0 最小可用，打磨列入 P1）。
  factory InkColors.light() => const InkColors._(
        surface1: Color(0xFFFAFAFC),
        surface2: Color(0xFFF0F0F5),
        surface3: Color(0xFFE4E4EC),
        fg1: Color(0xFF151520),
        fg2: Color(0xFF46465A),
        fg3: Color(0xFF7A7A8A),
        accent: Color(0xFF6E55E6),
        brand: Color(0xFF4A2FD1),
        danger: Color(0xFFD0342C),
        warning: Color(0xFFB47200),
        success: Color(0xFF2E8C57),
        border: Color(0xFFD5D5DD),
        focusRing: Color(0xFF6E55E6),
        overlay: Color(0xCCFAFAFC),
        scrim: Color(0x66000000),
      );

  /// 高对比度变体（A11y §20.1，启用"高对比度"时激活）。
  factory InkColors.highContrast() => const InkColors._(
        surface1: Color(0xFF000000),
        surface2: Color(0xFF0A0A0A),
        surface3: Color(0xFF151515),
        fg1: Color(0xFFFFFFFF),
        fg2: Color(0xFFF0F0F0),
        fg3: Color(0xFFDADADA),
        accent: Color(0xFFFFD400),
        brand: Color(0xFFFFD400),
        danger: Color(0xFFFF6A6A),
        warning: Color(0xFFFFD400),
        success: Color(0xFF66FFB0),
        border: Color(0xFFFFFFFF),
        focusRing: Color(0xFFFFD400),
        overlay: Color(0xEE000000),
        scrim: Color(0xCC000000),
      );

  final Color surface1; // 画布底
  final Color surface2; // 卡片
  final Color surface3; // 抬升/悬浮
  final Color fg1; // 主要文本
  final Color fg2; // 次要文本
  final Color fg3; // 辅助/占位文本
  final Color accent; // 品牌强调
  final Color brand; // 品牌主色
  final Color danger; // 错误 / 危险
  final Color warning; // 警告
  final Color success; // 成功
  final Color border; // 边框
  final Color focusRing; // A11y 键盘焦点环
  final Color overlay; // 遮罩背景
  final Color scrim; // 全屏遮罩
}

/// 间距（8 的倍数制）。
class InkSpacing {
  InkSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// 圆角。
class InkRadius {
  InkRadius._();
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 999;
}

/// 阴影（随亮/暗主题固化——暗色场景下阴影几乎不可见，依赖 surface 提升传达层级）。
class InkShadow {
  InkShadow._();

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elevated = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];
}

/// 动画时长（MediaQuery.disableAnimations 时由上层替换为 Duration.zero）。
class InkMotion {
  InkMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
}
