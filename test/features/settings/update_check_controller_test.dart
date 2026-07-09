// UpdateCheckController / UpdateCheckPrefController 单测（UPD-1）。
//
// 覆盖：手动检查（loading→data / error）、启动静默检查（偏好开关、6h 节流、
// 失败静默 INFO 不改 UI 态）、时间戳持久化、偏好开关持久化。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/clock.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/update_check.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/update_check_service.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/models/update_check_result.dart';
import 'package:inkframe/features/settings/providers/update_check_controller.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../../_harness/fake_clock.dart';
import '../../helpers/recording_logger.dart';

const UpdateCheckResult _kAvailable = UpdateCheckResult(
  currentVersion: '0.1.0-alpha.10',
  latestVersion: '0.1.0-alpha.11',
  releaseUrl: 'https://github.com/KerroKapple/InkFrame/releases/tag/v0.1.0-alpha.11',
);

class _FakeUpdateCheckService implements UpdateCheckService {
  _FakeUpdateCheckService({this.error});

  final UpdateCheckResult result = _kAvailable;
  final InkError? error;
  int calls = 0;

  @override
  Future<UpdateCheckResult> check() async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return result;
  }
}

({
  ProviderContainer container,
  _FakeUpdateCheckService service,
  InMemoryPreferencesService prefs,
  FakeClock clock,
  RecordingLogger logger,
}) _harness({
  AppPreferences initial = const AppPreferences(),
  InkError? error,
}) {
  final service = _FakeUpdateCheckService(error: error);
  final prefs = InMemoryPreferencesService(initial);
  final clock = FakeClock(DateTime.utc(2026, 7, 9, 12));
  final logger = RecordingLogger();
  final container = ProviderContainer(
    overrides: <Override>[
      updateCheckServiceProvider.overrideWithValue(service),
      preferencesServiceProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(clock),
      loggerProvider.overrideWithValue(logger),
    ],
  );
  addTearDown(container.dispose);
  return (
    container: container,
    service: service,
    prefs: prefs,
    clock: clock,
    logger: logger,
  );
}

void main() {
  group('UpdateCheckController.checkNow', () {
    test('成功：结果进入 state,写入检查时间戳', () async {
      final h = _harness();
      final notifier = h.container.read(updateCheckControllerProvider.notifier);

      expect(h.container.read(updateCheckControllerProvider).value, isNull);

      final future = notifier.checkNow();
      expect(h.container.read(updateCheckControllerProvider).isLoading, isTrue);
      await future;

      expect(
        h.container.read(updateCheckControllerProvider).value,
        _kAvailable,
      );
      expect(
        h.prefs.current.lastUpdateCheckAtIso,
        DateTime.utc(2026, 7, 9, 12).toIso8601String(),
      );
      expect(h.service.calls, 1);
    });

    test('失败：state 进入 AsyncError(InkError),时间戳不写', () async {
      final h = _harness(
        error: const NetworkError(code: InkErrorCode.networkOffline),
      );
      final notifier = h.container.read(updateCheckControllerProvider.notifier);

      await notifier.checkNow();

      final state = h.container.read(updateCheckControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkError>());
      expect(h.prefs.current.lastUpdateCheckAtIso, isNull);
    });
  });

  group('UpdateCheckController.maybeCheckOnStartup', () {
    test('偏好关 → 不调用服务', () async {
      final h = _harness(
        initial: const AppPreferences(updateCheckEnabled: false),
      );

      await h.container
          .read(updateCheckControllerProvider.notifier)
          .maybeCheckOnStartup();

      expect(h.service.calls, 0);
    });

    test('6h 内已检查 → 节流不调用', () async {
      final h = _harness(
        initial: AppPreferences(
          lastUpdateCheckAtIso:
              DateTime.utc(2026, 7, 9, 7).toIso8601String(), // 5h 前
        ),
      );

      await h.container
          .read(updateCheckControllerProvider.notifier)
          .maybeCheckOnStartup();

      expect(h.service.calls, 0);
    });

    test('超 6h → 检查并刷新时间戳', () async {
      final h = _harness(
        initial: AppPreferences(
          lastUpdateCheckAtIso:
              DateTime.utc(2026, 7, 9, 5).toIso8601String(), // 7h 前
        ),
      );

      await h.container
          .read(updateCheckControllerProvider.notifier)
          .maybeCheckOnStartup();

      expect(h.service.calls, 1);
      expect(
        h.container.read(updateCheckControllerProvider).value,
        _kAvailable,
      );
      expect(
        h.prefs.current.lastUpdateCheckAtIso,
        DateTime.utc(2026, 7, 9, 12).toIso8601String(),
      );
    });

    test('从未检查过 → 检查', () async {
      final h = _harness();

      await h.container
          .read(updateCheckControllerProvider.notifier)
          .maybeCheckOnStartup();

      expect(h.service.calls, 1);
    });

    test('失败 → 静默：state 不动,仅 INFO 日志', () async {
      final h = _harness(
        error: const NetworkError(code: InkErrorCode.networkTimeout),
      );

      await h.container
          .read(updateCheckControllerProvider.notifier)
          .maybeCheckOnStartup();

      final state = h.container.read(updateCheckControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value, isNull);
      final infos = h.logger.byLevel(InkLogLevel.info);
      expect(infos, hasLength(1));
      expect(infos.single.module, 'update.check');
    });
  });

  group('UpdateCheckPrefController', () {
    test('build 从偏好 seed', () {
      final h = _harness(
        initial: const AppPreferences(updateCheckEnabled: false),
      );
      expect(h.container.read(updateCheckPrefControllerProvider), isFalse);
    });

    test('setEnabled 更新状态并持久化', () async {
      final h = _harness();
      h.container
          .read(updateCheckPrefControllerProvider.notifier)
          .setEnabled(false);

      expect(h.container.read(updateCheckPrefControllerProvider), isFalse);
      // update 为异步落盘,推一拍微任务。
      await Future<void>.delayed(Duration.zero);
      expect(h.prefs.current.updateCheckEnabled, isFalse);
    });
  });
}
