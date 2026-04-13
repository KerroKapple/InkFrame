// ThemeModeController：观察设置 + 平台亮度 + 高对比度，解算 ThemeData。
//
// T1 阶段 Settings 还没实现，先暴露一个最小 API：
//   - 默认 dark
//   - highContrast 手动切换
//   - 平台亮度通过 PlatformDispatcher 热更新
// T5（设置模块）落地后可通过 Settings repository 扩展输入源，本 controller 的
// 公开接口保持不变。
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
    // 订阅平台亮度变化。
    final dispatcher = PlatformDispatcher.instance;
    void onBrightnessChanged() {
      if (_preference == ThemePreference.system && !_highContrast) {
        state = state.copyWith(variant: _resolveVariant());
      }
    }

    dispatcher.onPlatformBrightnessChanged = onBrightnessChanged;
    ref.onDispose(() {
      if (dispatcher.onPlatformBrightnessChanged == onBrightnessChanged) {
        dispatcher.onPlatformBrightnessChanged = null;
      }
    });

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
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeState>(
  ThemeModeController.new,
  name: 'themeModeControllerProvider',
);
