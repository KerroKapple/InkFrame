import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkframe/core/di/current_screen.dart';

void main() {
  test('currentScreenProvider 默认值是 studio', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(currentScreenProvider), AppScreen.studio);
  });

  test('currentScreenProvider 可切换到 settings 再回 studio', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(currentScreenProvider.notifier).state = AppScreen.settings;
    expect(container.read(currentScreenProvider), AppScreen.settings);
    container.read(currentScreenProvider.notifier).state = AppScreen.studio;
    expect(container.read(currentScreenProvider), AppScreen.studio);
  });
}
