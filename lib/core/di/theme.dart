// ThemeModeController：观察设置 + 平台亮度 + 高对比度，解算 ThemeData。
//
// T1 阶段只提供状态存储 + 显式 setter；监听 PlatformDispatcher 的
// platformBrightnessChanged 由 app 层 widget（InkFrameApp）挂接，避免 Notifier
// 在 build() 阶段写全局状态（在 widget 测试里容易引起订阅循环）。
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

class ThemeState {
  const ThemeState({
    required this.variant,
    this.textScale = 1.0,
  });

  final InkThemeVariant variant;
  final double textScale;

  ThemeState copyWith({InkThemeVariant? variant, double? textScale}) {
    return ThemeState(
      variant: variant ?? this.variant,
      textScale: textScale ?? this.textScale,
    );
  }
}

enum ThemePreference { dark, light, system }

class ThemeModeController extends Notifier<ThemeState> {
  ThemePreference _preference = ThemePreference.dark;
  bool _highContrast = false;

  @override
  ThemeState build() {
    return ThemeState(variant: _resolveVariant());
  }

  InkThemeVariant _resolveVariant() {
    if (_highContrast) {
      return InkThemeVariant.highContrast;
    }
    switch (_preference) {
      case ThemePreference.dark:
        return InkThemeVariant.dark;
      case ThemePreference.light:
        return InkThemeVariant.light;
      case ThemePreference.system:
        final b = PlatformDispatcher.instance.platformBrightness;
        return b == Brightness.light
            ? InkThemeVariant.light
            : InkThemeVariant.dark;
    }
  }

  void setPreference(ThemePreference preference) {
    _preference = preference;
    state = state.copyWith(variant: _resolveVariant());
  }

  void setHighContrast(bool enabled) {
    _highContrast = enabled;
    state = state.copyWith(variant: _resolveVariant());
  }

  void setTextScale(double scale) {
    state = state.copyWith(textScale: scale);
  }

  /// 外部驱动：系统亮度变化时调用，使 system 偏好重算变体。
  void onPlatformBrightnessChanged() {
    if (_preference == ThemePreference.system && !_highContrast) {
      state = state.copyWith(variant: _resolveVariant());
    }
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeState>(
  ThemeModeController.new,
  name: 'themeModeControllerProvider',
);
