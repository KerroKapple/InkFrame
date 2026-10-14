// StoragePathSection 测试。
//
// 历史记录：这里写过「在本仓库当前 toolchain（flutter test + InkButton/SelectableText
// 内部 ticker）下，pumpWidget(StoragePathSection) 始终留下 pending frame，让测试
// isolate 在 10 分钟后超时」。前两条用例是当时的等价覆盖："组件可构造 + provider
// 接线正确"——用 ProviderContainer 读 appPaths.database，校验 section 不会因为
// provider 未 override 而抛 StateError。外壳 harness（test/_harness/shell_app.dart）
// 至今照这条纪律只做固定次数 pump()。
//
// 「复制路径」那条必须真 pump 才点得到按钮：照同一纪律只做固定次数 pump()、不
// pumpAndSettle；路径用 DefaultAppPaths.forRoot 只拼字符串、不碰磁盘。提示走通知卡，
// 覆盖 toastServiceProvider 为 RecordingToastService 断言 titles / kinds。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/settings/widgets/storage_path_section.dart';
import 'package:path/path.dart' as p;

import '../../_harness/fake_toast_service.dart';
import '../../_harness/test_app.dart';

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

  testWidgets('复制路径 → 写剪贴板 + 弹「已复制」完成卡', (tester) async {
    final List<String> copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final AppPaths paths =
        DefaultAppPaths.forRoot(Directory('ink_storage_section_root'));
    final RecordingToastService toast = RecordingToastService();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: StoragePathSection())),
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        toastServiceProvider.overrideWithValue(toast),
      ],
    );
    await tester.pump();

    await tester.tap(find.text('Copy path'));
    await tester.pump();
    await tester.pump();

    expect(copied, <String>[paths.database.path]);
    expect(toast.titles, <String>['Path copied to clipboard']);
    expect(toast.kinds, <ToastKind>[ToastKind.success]);
    expect(toast.shown.single.chime, isFalse,
        reason: '用户自己刚点的复制，不是后台事件到达');
  });
}
