// 设置页返回键（shell 路由）单测。
//
// 不整页 pump SettingsScreen：StoragePathSection 在本 toolchain 下有
// ticker 挂起坑（见 storage_path_section_test 头注），返回键抽成独立小件测。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/features/settings/settings_screen.dart';

import '../../_harness/test_app.dart';

void main() {
  testWidgets('返回键点击 → currentScreenProvider 回 studio', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SettingsBackButton()),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsBackButton)),
      listen: false,
    );
    container.read(currentScreenProvider.notifier).state = AppScreen.settings;

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(container.read(currentScreenProvider), AppScreen.studio);
  });
}
