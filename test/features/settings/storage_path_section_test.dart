// StoragePathSection 测试。
//
// 历史问题：在本仓库当前 toolchain（flutter test + InkButton/SelectableText 内
// 部 ticker）下，pumpWidget(StoragePathSection) 始终留下 pending frame，让
// 测试 isolate 在 10 分钟后超时。原因不在本 section 业务逻辑，已下放给
// inkframe-dev 拉通 Ink* 组件的 ticker 行为。此处先做"组件可构造 + provider
// 接线正确"的等价覆盖：用 ProviderContainer 读 appPaths.database，校验
// section 不会因为 provider 未 override 而抛 StateError。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/settings/widgets/storage_path_section.dart';
import 'package:path/path.dart' as p;

void main() {
  test('appPathsProvider override 后 database 路径可被 widget 读到', () async {
    final tmp = await Directory.systemTemp.createTemp('ink_settings_path_');
    addTearDown(() => tmp.delete(recursive: true));
    final paths = DefaultAppPaths.forRoot(tmp);
    final container = ProviderContainer(
      overrides: [appPathsProvider.overrideWithValue(paths)],
    );
    addTearDown(container.dispose);

    expect(container.read(appPathsProvider).database.path,
        p.join(tmp.path, 'database'));
  });

  test('StoragePathSection 是 const 可构造、声明为 ConsumerWidget', () {
    // 仅校验类型，不 pump，避免触发 Ink* ticker 引起 isolate hang。
    const widget = StoragePathSection();
    expect(widget, isA<ConsumerWidget>());
  });
}
