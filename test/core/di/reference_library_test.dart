// 参考库 DI 单测：偏好 seed、没选文件夹 ⇒ null、set() 落盘并让条目 provider 重读、
// 默认 reader 是 ai-pose-gallery-zh 适配器。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/reference_library.dart';
import 'package:inkframe/core/interfaces/reference_library_reader.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/services/reference_library/ai_pose_gallery_zh_reader.dart';

import '../../helpers/recording_logger.dart';

/// 记下每次 load 的路径；结果固定为 NotFound（这里只关心调没调、拿什么调）。
class _FakeReader implements ReferenceLibraryReader {
  final List<String> calls = <String>[];

  @override
  Future<ReferenceLibraryLoad> load(String rootPath) async {
    calls.add(rootPath);
    return const ReferenceLibraryNotFound();
  }
}

void main() {
  late _FakeReader reader;
  late InMemoryPreferencesService prefs;

  ProviderContainer build([AppPreferences initial = const AppPreferences()]) {
    reader = _FakeReader();
    prefs = InMemoryPreferencesService(initial);
    final ProviderContainer container = ProviderContainer(overrides: <Override>[
      preferencesServiceProvider.overrideWithValue(prefs),
      referenceLibraryReaderProvider.overrideWithValue(reader),
    ]);
    addTearDown(container.dispose);
    // 模拟面板一直开着：条目 provider 有人听。
    container.listen<AsyncValue<ReferenceLibraryLoad?>>(
      referenceLibraryProvider,
      (_, _) {},
    );
    return container;
  }

  test('没选文件夹 ⇒ root 为 null，条目 provider 为 null，reader 不被调用', () async {
    final ProviderContainer c = build();

    expect(c.read(referenceLibraryRootProvider), isNull);
    expect(await c.read(referenceLibraryProvider.future), isNull);
    expect(reader.calls, isEmpty);
  });

  test('启动从偏好 seed：reader 拿偏好里的路径读', () async {
    final ProviderContainer c =
        build(const AppPreferences(referenceLibraryRoot: 'D:/seed'));

    expect(c.read(referenceLibraryRootProvider), 'D:/seed');
    expect(
      await c.read(referenceLibraryProvider.future),
      isA<ReferenceLibraryNotFound>(),
    );
    expect(reader.calls, <String>['D:/seed']);
  });

  test('set(path)：state 更新、偏好落盘、reader 收到新路径', () async {
    final ProviderContainer c = build();
    expect(await c.read(referenceLibraryProvider.future), isNull);

    await c.read(referenceLibraryRootProvider.notifier).set('D:/lib');

    expect(c.read(referenceLibraryRootProvider), 'D:/lib');
    expect(prefs.current.referenceLibraryRoot, 'D:/lib');
    expect(
      await c.read(referenceLibraryProvider.future),
      isA<ReferenceLibraryNotFound>(),
    );
    expect(reader.calls, <String>['D:/lib']);
  });

  test('换文件夹 ⇒ 重读一次；同一文件夹不重复读', () async {
    final ProviderContainer c =
        build(const AppPreferences(referenceLibraryRoot: 'D:/a'));
    await c.read(referenceLibraryProvider.future);
    await c.read(referenceLibraryProvider.future);
    expect(reader.calls, <String>['D:/a']);

    await c.read(referenceLibraryRootProvider.notifier).set('D:/b');
    await c.read(referenceLibraryProvider.future);

    expect(reader.calls, <String>['D:/a', 'D:/b']);
    expect(prefs.current.referenceLibraryRoot, 'D:/b');
  });

  test('默认 reader 是 ai-pose-gallery-zh 适配器', () {
    final ProviderContainer c = ProviderContainer(overrides: <Override>[
      loggerProvider.overrideWithValue(RecordingLogger()),
    ]);
    addTearDown(c.dispose);

    expect(c.read(referenceLibraryReaderProvider), isA<AiPoseGalleryZhReader>());
  });
}
