// 组合 token 为 ThemeData + ThemeExtension，暴露 context.inkColors /
// context.inkTypography 供 widget 消费。
//
// 主题模式三态与 A11y 开关都在 ThemeModeController 层决策（见 core/di/theme.dart）。
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// InkFrame 色板取向：让调用方通过 context 拿，不绑定静态全局。
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.colors,
    required this.typography,
  });

  final InkColors colors;
  final InkTypography typography;

  @override
  AppThemeExtension copyWith({
    InkColors? colors,
    InkTypography? typography,
  }) {
    return AppThemeExtension(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
    );
  }

  @override
  AppThemeExtension lerp(
    ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    // token 切换是离散动作（主题切换），不走连续插值；直接选终态。
    if (other is! AppThemeExtension) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

/// 主题变体枚举——ThemeModeController 解析 Settings + 平台亮度 → 变体。
enum InkThemeVariant { dark, light, highContrast }

/// 从 token 构造 ThemeData，语义色通过 ThemeExtension 暴露。
ThemeData buildAppTheme({
  required InkThemeVariant variant,
  required double textScale,
}) {
  final InkColors colors = switch (variant) {
    InkThemeVariant.dark => InkColors.dark(),
    InkThemeVariant.light => InkColors.light(),
    InkThemeVariant.highContrast => InkColors.highContrast(),
  };
  final InkTypography typography = InkTypography.defaults(scale: textScale);

  final Brightness brightness = variant == InkThemeVariant.light
      ? Brightness.light
      : Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    // surface2 = 应用主体默认底（README）；工作区 / 面板各自显式取 surface1 / surface3。
    scaffoldBackgroundColor: colors.surface2,
    colorScheme: ColorScheme(
      brightness: brightness,
      // 强调色只有一个：primary 与 secondary 同为琥珀，前景走 onAccent
      //（per-variant 锁 WCAG AA ≥4.5，tokens_test）。
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      // danger 只做文字与小图标、不做容器底色，故 onError 没有真实消费者；
      // 取 fg1 只为满足 ColorScheme 必填。
      error: colors.danger,
      onError: colors.fg1,
      surface: colors.surface2,
      onSurface: colors.fg1,
    ),
    extensions: <ThemeExtension<dynamic>>[
      AppThemeExtension(colors: colors, typography: typography),
    ],
  );
}

/// context 扩展：widget 只与语义 token 交互。
extension InkThemeX on BuildContext {
  AppThemeExtension get _inkTheme =>
      Theme.of(this).extension<AppThemeExtension>() ??
      AppThemeExtension(
        colors: InkColors.dark(),
        typography: InkTypography.defaults(),
      );

  InkColors get inkColors => _inkTheme.colors;
  InkTypography get inkTypography => _inkTheme.typography;
}
