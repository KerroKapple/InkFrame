import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/theme.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  group('ThemeModeController', () {
    test('starts in dark variant', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeControllerProvider).variant,
          InkThemeVariant.dark);
    });

    test('setPreference(light) switches variant', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(themeModeControllerProvider.notifier)
          .setPreference(ThemePreference.light);
      expect(container.read(themeModeControllerProvider).variant,
          InkThemeVariant.light);
    });

    test('setHighContrast(true) overrides preference', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(themeModeControllerProvider.notifier);
      notifier.setPreference(ThemePreference.light);
      notifier.setHighContrast(true);
      expect(container.read(themeModeControllerProvider).variant,
          InkThemeVariant.highContrast);
    });

    test('setTextScale adjusts state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(themeModeControllerProvider.notifier)
          .setTextScale(1.5);
      expect(container.read(themeModeControllerProvider).textScale, 1.5);
    });
  });
}
