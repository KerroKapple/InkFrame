// AboutSection widget test — 探测可用 / 不可用两条路径 + UPD-1 检查更新流
// + ON-3 ffmpeg 状态行。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/di/update_check.dart';
import 'package:inkframe/core/di/url_opener.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/services/ffmpeg_locator.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/interfaces/update_check_service.dart';
import 'package:inkframe/core/interfaces/url_opener_service.dart';
import 'package:inkframe/core/models/update_check_result.dart';
import 'package:inkframe/features/settings/widgets/about_section.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../../_harness/test_app.dart';

class _OkSecure implements SecureStorageService {
  final Map<String, String> _data = {};
  @override
  Future<void> store(String k, String v) async => _data[k] = v;
  @override
  Future<String?> retrieve(String k) async => _data[k];
  @override
  Future<void> delete(String k) async => _data.remove(k);
  @override
  Future<bool> exists(String k) async => _data.containsKey(k);
}

class _BrokenSecure implements SecureStorageService {
  @override
  Future<void> store(String k, String v) async => throw StateError('boom');
  @override
  Future<String?> retrieve(String k) async => null;
  @override
  Future<void> delete(String k) async {}
  @override
  Future<bool> exists(String k) async => false;
}

const UpdateCheckResult _kNewVersion = UpdateCheckResult(
  currentVersion: '0.1.0-alpha.10',
  latestVersion: '0.1.0-alpha.11',
  releaseUrl:
      'https://github.com/KerroKapple/InkFrame/releases/tag/v0.1.0-alpha.11',
);

class _FakeUpdate implements UpdateCheckService {
  _FakeUpdate({this.result = _kNewVersion, this.error});
  final UpdateCheckResult result;
  final InkError? error;
  @override
  Future<UpdateCheckResult> check() async {
    final e = error;
    if (e != null) throw e;
    return result;
  }
}

class _RecordingOpener implements UrlOpenerService {
  final List<Uri> opened = <Uri>[];
  @override
  Future<void> openExternal(Uri url) async => opened.add(url);
}

/// 固定结果的 ffmpeg 探测——testWidgets 禁真 spawn（sync-IO 坑），
/// 所有用例必须 override 掉默认 locator。
class _FakeFfmpegLocator implements FfmpegLocator {
  _FakeFfmpegLocator(this.path);
  final String? path;
  @override
  Future<String?> locate() async => path;
  @override
  void invalidate() {}
}

/// 带命中缓存的 fake——真 locator 就是这个行为（命中缓存、miss 不缓存）。
///
/// 上面那个无缓存 fake 看不出「设置页有没有强制重探」：两种实现在它下面都绿。
/// 要钉住「卸掉 ffmpeg 后重进设置页不再报可用」，fake 必须自己会缓存。
class _CachingFakeFfmpegLocator implements FfmpegLocator {
  _CachingFakeFfmpegLocator(this.onDisk);

  /// 当前"磁盘上"有没有；测试中途可改，模拟用户在应用运行期间卸载。
  String? onDisk;
  String? _cached;
  int probes = 0;

  @override
  Future<String?> locate() async {
    final String? hit = _cached;
    if (hit != null) return hit;
    probes++;
    _cached = onDisk; // 命中才留下；onDisk 为 null 时等于不缓存
    return onDisk;
  }

  @override
  void invalidate() => _cached = null;
}

/// 全用例公共 override：secure storage OK + ffmpeg found（另有专测覆盖 miss）。
List<Override> _baseOverrides({String? ffmpegPath = 'ffmpeg'}) => <Override>[
      secureStorageServiceProvider.overrideWithValue(_OkSecure()),
      ffmpegLocatorProvider
          .overrideWithValue(_FakeFfmpegLocator(ffmpegPath)),
    ];

List<Override> _updateOverrides({
  UpdateCheckService? service,
  UrlOpenerService? opener,
  InMemoryPreferencesService? prefs,
}) =>
    <Override>[
      ..._baseOverrides(),
      updateCheckServiceProvider.overrideWithValue(service ?? _FakeUpdate()),
      urlOpenerServiceProvider
          .overrideWithValue(opener ?? _RecordingOpener()),
      if (prefs != null) preferencesServiceProvider.overrideWithValue(prefs),
    ];

void main() {
  testWidgets('探测成功显示 Available', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: _baseOverrides(),
    );
    await tester.pumpAndSettle();
    // 恰 2 行：secure storage + ffmpeg——任一退化 Unavailable 即红
    expect(find.textContaining('Available'), findsNWidgets(2));
  });

  testWidgets('探测抛错显示 Unavailable + 原因', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_BrokenSecure()),
        ffmpegLocatorProvider
            .overrideWithValue(_FakeFfmpegLocator('ffmpeg')),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unavailable'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('ffmpeg 探测命中：显示路径', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: _baseOverrides(ffmpegPath: r'C:\tools\ffmpeg.exe'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(r'C:\tools\ffmpeg.exe'), findsOneWidget);
  });

  // PATH 命中返回的是可执行名、不是路径。套进「可用（{path}）」会显示成
  // 「可用（ffmpeg）」，读起来像 ffmpeg 装在一个叫 ffmpeg 的地方。
  testWidgets('ffmpeg 在 PATH 上命中：说「在 PATH 上找到」，不把可执行名当路径',
      (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: _baseOverrides(ffmpegPath: kFfmpegOnPathExe),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('found on PATH'), findsOneWidget);
    expect(
      find.textContaining('Available (ffmpeg)'),
      findsNothing,
      reason: 'kFfmpegOnPathExe 是交给系统解析的可执行名，不是路径',
    );
  });

  // 设置页的职责是显示**当下**的事实。locator 对命中是 app 级缓存的，只有导出
  // 失败那条路径会 invalidate——所以「装好后重进设置页即重探」只对 miss 成立，
  // 反过来卸掉之后这一行会一直说「可用」，直到用户真去导出才发现。
  test('设置页探测每次强制重探：卸掉 ffmpeg 后不再报可用', () async {
    final locator = _CachingFakeFfmpegLocator(kFfmpegOnPathExe);
    final container = ProviderContainer(overrides: <Override>[
      ffmpegLocatorProvider.overrideWithValue(locator),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(ffmpegProbeProvider.future), kFfmpegOnPathExe);

    // 用户在应用运行期间把 ffmpeg 卸了，然后重新打开设置页
    //（autoDispose 的 provider 重建 == 重进页面）。
    locator.onDisk = null;
    container.invalidate(ffmpegProbeProvider);

    expect(
      await container.read(ffmpegProbeProvider.future),
      isNull,
      reason: '不强制重探的话 locator 的命中缓存会一直报旧值',
    );
    expect(locator.probes, 2, reason: '两次打开设置页 = 两次真探测');
  });

  testWidgets('ffmpeg 未找到（Windows）：winget 指引 + INKFRAME_FFMPEG 兜底',
      (tester) async {
    // 必须在测试体内复位——框架的 foundation 变量 invariant 检查先于 addTearDown；
    // try/finally 保证断言失败也复位，不留次生噪音
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await pumpInkApp(
        tester,
        const Scaffold(body: SingleChildScrollView(child: AboutSection())),
        overrides: _baseOverrides(ffmpegPath: null),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('winget'), findsOneWidget);
      expect(find.textContaining('INKFRAME_FFMPEG'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ffmpeg 未找到（macOS）：brew 指引', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpInkApp(
        tester,
        const Scaffold(body: SingleChildScrollView(child: AboutSection())),
        overrides: _baseOverrides(ffmpegPath: null),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('brew'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ffmpeg 未找到（其他平台）：复用导出对话框文案防双源', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: _baseOverrides(ffmpegPath: null),
    );
    await tester.pumpAndSettle();
    // testWidgets 默认平台非 mac/win → 走 exportVideoFfmpegMissing 复用分支
    expect(find.textContaining('ffmpeg not found'), findsOneWidget);
  });

  testWidgets('点开源许可按钮 → 打开 LicensePage', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: _baseOverrides(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open-source licenses'));
    // 不用 pumpAndSettle：LicensePage 加载许可期间的进度指示器会持续调度帧，
    // pumpAndSettle 会超时；只推进路由过场动画即可断言页面已入栈。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('检查更新：有新版 → 显示版本与查看发布页,点开走 UrlOpener', (tester) async {
    final opener = _RecordingOpener();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: _updateOverrides(opener: opener),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Check for updates'));
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('New version 0.1.0-alpha.11 available'), findsOneWidget);

    await tester.ensureVisible(find.text('View release'));
    await tester.tap(find.text('View release'));
    await tester.pumpAndSettle();

    expect(opener.opened, [Uri.parse(_kNewVersion.releaseUrl!)]);
  });

  testWidgets('检查更新：已是最新 → up-to-date 文案,无发布页按钮', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: _updateOverrides(
        service: _FakeUpdate(
          result: const UpdateCheckResult(currentVersion: '0.1.0-alpha.10'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Check for updates'));
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text("You're on the latest version"), findsOneWidget);
    expect(find.text('View release'), findsNothing);
  });

  testWidgets('检查更新：失败 → 轻提示文案,不炸', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: _updateOverrides(
        service: _FakeUpdate(
          error: const NetworkError(code: InkErrorCode.networkOffline),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Check for updates'));
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't check for updates"), findsOneWidget);
  });

  testWidgets('启动检查开关：默认开,点击后持久化为关', (tester) async {
    final prefs = InMemoryPreferencesService();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AboutSection())),
      overrides: _updateOverrides(prefs: prefs),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    await tester.ensureVisible(switchFinder);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    expect(prefs.current.updateCheckEnabled, isFalse);
  });
}
