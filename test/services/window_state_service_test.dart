// DefaultWindowStateService 单测（PL-6）——假窗口 / 假显示器，headless，无真实插件。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/window_state.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/models/window_bounds.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/services/window_state_service.dart';

void main() {
  const primary = WindowBounds(x: 0, y: 0, width: 1920, height: 1040);

  DefaultWindowStateService build({
    required AppPreferences initial,
    required _FakeWindowController controller,
    required _FakeDisplayQuery displays,
    required InMemoryPreferencesService prefs,
  }) {
    return DefaultWindowStateService(
      prefs: prefs,
      controller: controller,
      displays: displays,
      logger: _NoopLogger(),
    );
  }

  group('restore', () {
    test('无记忆（首次启动）→ 不碰窗口', () async {
      final controller = _FakeWindowController();
      final prefs = InMemoryPreferencesService();
      final svc = build(
        initial: const AppPreferences(),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[primary]),
        prefs: prefs,
      );

      await svc.restore();

      expect(controller.setBoundsCalls, isEmpty);
      expect(controller.maximizeCount, 0);
    });

    test('首次启动 + 屏幕小于默认窗口 → clamp 进工作区并居中', () async {
      const small = WindowBounds(x: 0, y: 25, width: 1280, height: 775);
      final controller = _FakeWindowController();
      final prefs = InMemoryPreferencesService();
      final svc = build(
        initial: const AppPreferences(),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[small]),
        prefs: prefs,
      );

      await svc.restore();

      expect(controller.setBoundsCalls.length, 1);
      final applied = controller.setBoundsCalls.single;
      // 不超工作区
      expect(applied.width, lessThanOrEqualTo(small.width));
      expect(applied.height, lessThanOrEqualTo(small.height));
      expect(applied.left >= small.left, isTrue);
      expect(applied.top >= small.top, isTrue);
      expect(applied.right <= small.right, isTrue);
      expect(applied.bottom <= small.bottom, isTrue);
      // 工作区内居中
      expect(applied.x, closeTo(small.x + (small.width - applied.width) / 2, 1));
      expect(
          applied.y, closeTo(small.y + (small.height - applied.height) / 2, 1));
    });

    test('首启多显示器：主屏判定取距原点最近工作区，与枚举顺序无关', () async {
      // 副屏在前（大而远），主屏工作区 (0,25) 小于默认窗口。
      const secondary =
          WindowBounds(x: 1920, y: 0, width: 2560, height: 1415);
      const primarySmall = WindowBounds(x: 0, y: 25, width: 1440, height: 875);
      final controller = _FakeWindowController();
      final prefs = InMemoryPreferencesService();
      final svc = build(
        initial: const AppPreferences(),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[secondary, primarySmall]),
        prefs: prefs,
      );

      await svc.restore();

      expect(controller.setBoundsCalls.length, 1);
      final applied = controller.setBoundsCalls.single;
      // 落在主屏（近原点）而非列表首位的副屏。
      expect(applied.right <= primarySmall.right, isTrue);
      expect(applied.top >= primarySmall.top, isTrue);
    });

    test('记忆完整落在可见显示器 → 原样 setBounds', () async {
      const saved = WindowBounds(x: 200, y: 150, width: 1000, height: 700);
      final controller = _FakeWindowController();
      final prefs =
          InMemoryPreferencesService(const AppPreferences(windowBounds: saved));
      final svc = build(
        initial: const AppPreferences(windowBounds: saved),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[primary]),
        prefs: prefs,
      );

      await svc.restore();

      expect(controller.setBoundsCalls, <WindowBounds>[saved]);
      expect(controller.maximizeCount, 0);
    });

    test('记忆在已拔显示器（越界）→ setBounds 退默认（不用 saved）', () async {
      const saved = WindowBounds(x: 3000, y: 100, width: 800, height: 600);
      final controller = _FakeWindowController();
      final prefs =
          InMemoryPreferencesService(const AppPreferences(windowBounds: saved));
      final svc = build(
        initial: const AppPreferences(windowBounds: saved),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[primary]),
        prefs: prefs,
      );

      await svc.restore();

      expect(controller.setBoundsCalls.length, 1);
      final applied = controller.setBoundsCalls.single;
      expect(applied, isNot(saved));
      // 退默认后 clamp 进主屏 → 完整可见。
      expect(applied.left >= primary.left, isTrue);
      expect(applied.right <= primary.right, isTrue);
      expect(applied.bottom <= primary.bottom, isTrue);
    });

    test('maximized 标志 → setBounds（恢复矩形）后 maximize', () async {
      const saved = WindowBounds(x: 100, y: 100, width: 900, height: 600);
      final controller = _FakeWindowController();
      final prefs = InMemoryPreferencesService(
        const AppPreferences(windowBounds: saved, windowMaximized: true),
      );
      final svc = build(
        initial:
            const AppPreferences(windowBounds: saved, windowMaximized: true),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[primary]),
        prefs: prefs,
      );

      await svc.restore();

      expect(controller.setBoundsCalls, <WindowBounds>[saved]);
      expect(controller.maximizeCount, 1);
    });

    test('显示器查询抛异常 → 吞掉，不 setBounds，不上抛', () async {
      const saved = WindowBounds(x: 200, y: 150, width: 1000, height: 700);
      final controller = _FakeWindowController();
      final prefs =
          InMemoryPreferencesService(const AppPreferences(windowBounds: saved));
      final svc = build(
        initial: const AppPreferences(windowBounds: saved),
        controller: controller,
        displays: _FakeDisplayQuery.throwing(),
        prefs: prefs,
      );

      await svc.restore(); // 不得抛

      expect(controller.setBoundsCalls, isEmpty);
    });

    test('setBounds 抛异常 → 吞掉，不上抛', () async {
      const saved = WindowBounds(x: 200, y: 150, width: 1000, height: 700);
      final controller = _FakeWindowController()..throwOnSetBounds = true;
      final prefs =
          InMemoryPreferencesService(const AppPreferences(windowBounds: saved));
      final svc = build(
        initial: const AppPreferences(windowBounds: saved),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[primary]),
        prefs: prefs,
      );

      await svc.restore(); // 不得抛
    });
  });

  group('capture', () {
    test('非最大化：读 getBounds + isMaximized 各一次，边界更新落盘', () async {
      const current = WindowBounds(x: 50, y: 60, width: 1400, height: 900);
      final controller = _FakeWindowController()
        ..bounds = current
        ..maximized = false;
      final prefs = InMemoryPreferencesService();
      final svc = build(
        initial: const AppPreferences(),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[primary]),
        prefs: prefs,
      );

      await svc.capture();

      expect(controller.getBoundsCount, 1);
      expect(controller.isMaximizedCount, 1);
      expect(prefs.current.windowBounds, current);
      expect(prefs.current.windowMaximized, false);
    });

    test('最大化：保留上次非最大化边界，不用全屏 getBounds 覆盖', () async {
      // 上次退出记下的正常窗口矩形。
      const priorNormal = WindowBounds(x: 100, y: 100, width: 900, height: 600);
      // 最大化时 getBounds 返回全屏矩形——绝不能当作正常边界写回。
      const fullScreen = WindowBounds(x: 0, y: 0, width: 1920, height: 1040);
      final controller = _FakeWindowController()
        ..bounds = fullScreen
        ..maximized = true;
      final prefs = InMemoryPreferencesService(
        const AppPreferences(windowBounds: priorNormal),
      );
      final svc = build(
        initial: const AppPreferences(windowBounds: priorNormal),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[primary]),
        prefs: prefs,
      );

      await svc.capture();

      // 正常边界保持不变；仅最大化标志翻真。下次取消最大化才能回到真正的正常尺寸。
      expect(prefs.current.windowBounds, priorNormal);
      expect(prefs.current.windowMaximized, true);
    });

    test('getBounds 抛异常 → 吞掉，偏好不变，不上抛', () async {
      final controller = _FakeWindowController()..throwOnGetBounds = true;
      final prefs = InMemoryPreferencesService();
      final svc = build(
        initial: const AppPreferences(),
        controller: controller,
        displays: _FakeDisplayQuery(<WindowBounds>[primary]),
        prefs: prefs,
      );

      await svc.capture(); // 不得抛

      expect(prefs.current.windowBounds, isNull);
      expect(prefs.current.windowMaximized, false);
    });
  });
}

class _FakeWindowController implements WindowController {
  WindowBounds bounds = const WindowBounds(x: 0, y: 0, width: 800, height: 600);
  bool maximized = false;
  bool throwOnGetBounds = false;
  bool throwOnSetBounds = false;

  final List<WindowBounds> setBoundsCalls = <WindowBounds>[];
  int maximizeCount = 0;
  int getBoundsCount = 0;
  int isMaximizedCount = 0;

  @override
  Future<WindowBounds> getBounds() async {
    getBoundsCount++;
    if (throwOnGetBounds) throw StateError('boom');
    return bounds;
  }

  @override
  Future<void> setBounds(WindowBounds b) async {
    if (throwOnSetBounds) throw StateError('boom');
    setBoundsCalls.add(b);
  }

  @override
  Future<bool> isMaximized() async {
    isMaximizedCount++;
    return maximized;
  }

  @override
  Future<void> maximize() async => maximizeCount++;
}

class _FakeDisplayQuery implements DisplayQuery {
  _FakeDisplayQuery(this._frames) : _throws = false;
  _FakeDisplayQuery.throwing()
      : _frames = const <WindowBounds>[],
        _throws = true;

  final List<WindowBounds> _frames;
  final bool _throws;

  @override
  Future<List<WindowBounds>> visibleFrames() async {
    if (_throws) throw StateError('no displays');
    return _frames;
  }
}

class _NoopLogger implements LoggerService {
  @override
  void debug(String module, String msg, {Map<String, Object?>? extra}) {}
  @override
  void info(String module, String msg, {Map<String, Object?>? extra}) {}
  @override
  void warn(String module, String msg, {Map<String, Object?>? extra}) {}
  @override
  void error(String module, String msg,
      {Map<String, Object?>? extra, Object? cause, StackTrace? stackTrace}) {}
  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {}
}
