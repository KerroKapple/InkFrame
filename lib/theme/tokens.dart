// 设计 token：三主题变体 + 间距/圆角/阴影/排版原值。
//
// 这是整个应用唯一允许出现原始色值 / 数值的文件。所有 widget 与组件必须
// 通过 InkSpacing / InkRadius / InkShadow / InkTypography / context.inkColors 消费。
//
// 三态变体：dark / light / highContrast。highContrast 是 A11y §20.1 基线的
// 开关目标，前景色与背景色的对比度 ≥ 7:1（WCAG AAA 参考值），实际 CI 不做
// 自动对比度检查——值由人工维护。
import 'package:flutter/widgets.dart';

/// 启动阶段（main 进入 runApp 前）唯一可暴露的原始色板常量入口。
///
/// 仅暴露在 BuildContext 可用之前必须使用的颜色（如 window_manager 背景），
/// 其他场景请走 `context.inkColors`。每个常量必须等于对应主题工厂的值，
/// 由 tokens_test 守护一致性。
class InkPalette {
  InkPalette._();

  /// 启动时 window_manager 背景色；必须等于 `InkColors.dark().surfaceCanvas`。
  static const Color surfaceCanvasDark = Color(0xFF0B0908);
}

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
    required this.inputFill,
  });

  /// 深色主题（P0 默认）—— Amber Noir：电影暗室 + 琥珀金高光 + 哑光暖黑。
  factory InkColors.dark() => const InkColors._(
        surfaceCanvas: InkPalette.surfaceCanvasDark,
        surface1: Color(0xFF100C0A),
        surface2: Color(0xFF15110E),
        surface3: Color(0xFF1C1814),
        surface4: Color(0xFF2A2520),
        fg1: Color(0xFFE8DFD0),
        fg2: Color(0xFFB5A89A),
        fg3: Color(0xFF8A7E70),
        fg4: Color(0xFF5A5048),
        accent: Color(0xFFC9A85B),
        accentHover: Color(0xFFD8B66B),
        accentPressed: Color(0xFFB89A4F),
        brand: Color(0xFFC9A85B),
        cta: Color(0xFFE3A648),
        ctaHover: Color(0xFFF0B556),
        danger: Color(0xFFC8523A),
        warning: Color(0xFFD88B3A),
        success: Color(0xFF5C8A4E),
        info: Color(0xFF4B7A92),
        border: Color(0xFF2A2522),
        borderSubtle: Color(0xFF1C1814),
        borderHover: Color(0xFF3C342A),
        focusRing: Color(0xFFC9A85B),
        overlay: Color(0xCC0B0908),
        scrim: Color(0xB3000000),
        inputFill: Color(0x0AFFFFFF),
      );

  /// 浅色主题—— Paper Ivory：暖白纸 + 琥珀金（与暗色形成对偶）。
  factory InkColors.light() => const InkColors._(
        surfaceCanvas: Color(0xFFF5EFE3),
        surface1: Color(0xFFFAF5EB),
        surface2: Color(0xFFFFFAF0),
        surface3: Color(0xFFEFE7D5),
        surface4: Color(0xFFE5DBC4),
        fg1: Color(0xFF2A2520),
        fg2: Color(0xFF5A5048),
        fg3: Color(0xFF8A7E70),
        fg4: Color(0xFFB5A89A),
        accent: Color(0xFFA88340),
        accentHover: Color(0xFFB89150),
        accentPressed: Color(0xFF8C6A30),
        brand: Color(0xFFA88340),
        cta: Color(0xFFC68B2E),
        ctaHover: Color(0xFFD89A3E),
        danger: Color(0xFFB04030),
        warning: Color(0xFFC07028),
        success: Color(0xFF4C7240),
        info: Color(0xFF3C6478),
        border: Color(0xFFD5CAB0),
        borderSubtle: Color(0xFFE5DBC4),
        borderHover: Color(0xFFB89A6A),
        focusRing: Color(0xFFA88340),
        overlay: Color(0xCCF5EFE3),
        scrim: Color(0x66000000),
        inputFill: Color(0x0F2A2520),
      );

  /// 高对比度变体（A11y §20.1）—— 纯黑底 + 高饱琥珀。
  factory InkColors.highContrast() => const InkColors._(
        surfaceCanvas: Color(0xFF000000),
        surface1: Color(0xFF000000),
        surface2: Color(0xFF0A0807),
        surface3: Color(0xFF15110E),
        surface4: Color(0xFF201A14),
        fg1: Color(0xFFFFFFFF),
        fg2: Color(0xFFF0E8D8),
        fg3: Color(0xFFDDD0B5),
        fg4: Color(0xFFB5A890),
        accent: Color(0xFFFFCB52),
        accentHover: Color(0xFFFFD874),
        accentPressed: Color(0xFFF0BA3C),
        brand: Color(0xFFFFCB52),
        cta: Color(0xFFFFCB52),
        ctaHover: Color(0xFFFFD874),
        danger: Color(0xFFFF6A4A),
        warning: Color(0xFFFFB04A),
        success: Color(0xFF7AD06A),
        info: Color(0xFF6BB5D0),
        border: Color(0xFFFFFFFF),
        borderSubtle: Color(0xFFA0998A),
        borderHover: Color(0xFFFFFFFF),
        focusRing: Color(0xFFFFCB52),
        overlay: Color(0xEE000000),
        scrim: Color(0xCC000000),
        inputFill: Color(0x14FFFFFF),
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
  final Color inputFill; // 输入框半透明底（暗色提亮 / 浅色压暗）
}

/// 间距（8 的倍数主刻度 + 半阶档位）。
///
/// 半阶档位（s10/s12/s14/s18/s28）覆盖 mockup 的光学微调值，
/// 禁止在 widget 内对 token 做加减算术拼间距。
class InkSpacing {
  InkSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  // 半阶档位
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s18 = 18;
  static const double s28 = 28;
}

/// 圆角。
class InkRadius {
  InkRadius._();
  static const double xs = 2; // 细进度条 / 微裁切
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
