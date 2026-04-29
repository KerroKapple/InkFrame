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
    required this.surfaceCanvas,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.surface4,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.fg4,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.brand,
    required this.cta,
    required this.ctaHover,
    required this.danger,
    required this.warning,
    required this.success,
    required this.info,
    required this.border,
    required this.borderSubtle,
    required this.borderHover,
    required this.focusRing,
    required this.overlay,
    required this.scrim,
  });

  /// 深色主题（P0 默认）。
  factory InkColors.dark() => const InkColors._(
        surfaceCanvas: Color(0xFF101218),
        surface1: Color(0xFF1B1D24),
        surface2: Color(0xFF262830),
        surface3: Color(0xFF323440),
        surface4: Color(0xFF3E404C),
        fg1: Color(0xFFFFFFFF),
        fg2: Color(0xFFCFCECE),
        fg3: Color(0xFF6B6B6B),
        fg4: Color(0xFF4D4D4D),
        accent: Color(0xFF0080FF),
        accentHover: Color(0xFF0070E0),
        accentPressed: Color(0xFF0060C0),
        brand: Color(0xFFA88BFF),
        cta: Color(0xFFD42B57),
        ctaHover: Color(0xFFBA2149),
        danger: Color(0xFFE53E3E),
        warning: Color(0xFFF59E0B),
        success: Color(0xFF2EBD6B),
        info: Color(0xFF00A3D9),
        border: Color(0xFF34363F),
        borderSubtle: Color(0xFF262830),
        borderHover: Color(0xFF484A54),
        focusRing: Color(0xFF0080FF),
        overlay: Color(0xCC101218),
        scrim: Color(0x99000000),
      );

  /// 浅色主题（P0 最小可用，打磨列入 P1）。
  factory InkColors.light() => const InkColors._(
        surfaceCanvas: Color(0xFFFAFAFA),
        surface1: Color(0xFFFFFFFF),
        surface2: Color(0xFFF7F7F7),
        surface3: Color(0xFFF2F2F2),
        surface4: Color(0xFFEBEBEB),
        fg1: Color(0xFF1A1A1A),
        fg2: Color(0xFF737373),
        fg3: Color(0xFF9E9E9E),
        fg4: Color(0xFFBFBFBF),
        accent: Color(0xFF0080FF),
        accentHover: Color(0xFF0070E0),
        accentPressed: Color(0xFF0060C0),
        brand: Color(0xFF4A2FD1),
        cta: Color(0xFFD42B57),
        ctaHover: Color(0xFFBA2149),
        danger: Color(0xFFE53E3E),
        warning: Color(0xFFF59E0B),
        success: Color(0xFF2E8C57),
        info: Color(0xFF00A3D9),
        border: Color(0xFFE0E0E0),
        borderSubtle: Color(0xFFEBEBEB),
        borderHover: Color(0xFFCCCCCC),
        focusRing: Color(0xFF0080FF),
        overlay: Color(0xCCFAFAFA),
        scrim: Color(0x66000000),
      );

  /// 高对比度变体（A11y §20.1，启用"高对比度"时激活）。
  factory InkColors.highContrast() => const InkColors._(
        surfaceCanvas: Color(0xFF000000),
        surface1: Color(0xFF000000),
        surface2: Color(0xFF0A0A0A),
        surface3: Color(0xFF151515),
        surface4: Color(0xFF202020),
        fg1: Color(0xFFFFFFFF),
        fg2: Color(0xFFF0F0F0),
        fg3: Color(0xFFDADADA),
        fg4: Color(0xFFBEBEBE),
        accent: Color(0xFFFFD400),
        accentHover: Color(0xFFFFE550),
        accentPressed: Color(0xFFF5C000),
        brand: Color(0xFFFFD400),
        cta: Color(0xFFFFD400),
        ctaHover: Color(0xFFFFE550),
        danger: Color(0xFFFF6A6A),
        warning: Color(0xFFFFD400),
        success: Color(0xFF66FFB0),
        info: Color(0xFF66E0FF),
        border: Color(0xFFFFFFFF),
        borderSubtle: Color(0xFFA0A0A0),
        borderHover: Color(0xFFFFFFFF),
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
  final Color surfaceCanvas; // 画布最底层（surface-0）
  final Color surface4; // 活跃控件（surface-4）
  final Color fg4; // 极弱辅助文本（text-quaternary）
  final Color accentHover;
  final Color accentPressed;
  final Color cta; // 品牌红 CTA
  final Color ctaHover;
  final Color info; // 语义信息蓝
  final Color borderSubtle;
  final Color borderHover;
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
  static const double bento = 10; // bento 卡片圆角
  static const double bentoBtn = 6; // bento 按钮圆角
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
