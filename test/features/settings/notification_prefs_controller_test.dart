// NotificationPrefsController 单测：自偏好播种（非法值退默认）、setter 即时落盘、
// 试听带上解析后的绝对路径、导入成功切到「自定义」、导入失败什么都不动。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/notification_sound.dart';
import 'package:inkframe/core/di/notification_sound_store.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/notification_sound_service.dart';
import 'package:inkframe/core/interfaces/notification_sound_store.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/features/notifications/models/notification_prefs.dart';
import 'package:inkframe/features/settings/providers/notification_prefs_controller.dart';
import 'package:inkframe/services/file_preferences_service.dart';

class _RecordingSound implements NotificationSoundService {
  final List<(NotificationSound, String?)> plays =
      <(NotificationSound, String?)>[];

  @override
  Future<void> play(NotificationSound sound, {String? customFilePath}) async {
    plays.add((sound, customFilePath));
  }
}

class _FakeStore implements NotificationSoundStore {
  _FakeStore({this.importError});

  final LocalIOError? importError;
  final List<String> imported = <String>[];
  final List<String?> resolved = <String?>[];

  @override
  Future<String> importFile(String sourcePath) async {
    imported.add(sourcePath);
    final LocalIOError? e = importError;
    if (e != null) throw e;
    return 'notification.mp3';
  }

  @override
  String? resolve(String? fileName) {
    resolved.add(fileName);
    return fileName == null ? null : '/data/config/sounds/$fileName';
  }
}

({
  ProviderContainer container,
  InMemoryPreferencesService prefs,
  _RecordingSound sound,
  _FakeStore store,
}) _harness({
  AppPreferences initial = const AppPreferences(),
  LocalIOError? importError,
}) {
  final InMemoryPreferencesService prefs = InMemoryPreferencesService(initial);
  final _RecordingSound sound = _RecordingSound();
  final _FakeStore store = _FakeStore(importError: importError);
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      preferencesServiceProvider.overrideWithValue(prefs),
      notificationSoundServiceProvider.overrideWithValue(sound),
      notificationSoundStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, prefs: prefs, sound: sound, store: store);
}

void main() {
  group('播种', () {
    test('默认：InkFrame 默认 / 没有文件 / 标准停留', () {
      final h = _harness();

      expect(
        h.container.read(notificationPrefsControllerProvider),
        (
          sound: NotificationSound.inkframe,
          soundFile: null,
          dwell: ToastDwell.standard,
        ),
      );
    });

    test('从已存的偏好播种', () {
      final h = _harness(
        initial: const AppPreferences(
          notificationSound: 'system',
          notificationSoundFile: 'notification.ogg',
          toastDwell: 'long',
        ),
      );

      expect(
        h.container.read(notificationPrefsControllerProvider),
        (
          sound: NotificationSound.system,
          soundFile: 'notification.ogg',
          dwell: ToastDwell.long,
        ),
      );
    });

    test('非法值退默认', () {
      final h = _harness(
        initial: const AppPreferences(
          notificationSound: 'loud',
          toastDwell: 'forever',
        ),
      );

      final NotificationPrefs s =
          h.container.read(notificationPrefsControllerProvider);
      expect(s.sound, NotificationSound.inkframe);
      expect(s.dwell, ToastDwell.standard);
    });
  });

  group('setter 即时落盘', () {
    test('setSound：状态与偏好都变，自定义文件名留着（切回来还在）', () {
      final h = _harness(
        initial: const AppPreferences(
          notificationSound: 'custom',
          notificationSoundFile: 'notification.wav',
        ),
      );

      h.container
          .read(notificationPrefsControllerProvider.notifier)
          .setSound(NotificationSound.off);

      final NotificationPrefs s =
          h.container.read(notificationPrefsControllerProvider);
      expect(s.sound, NotificationSound.off);
      expect(s.soundFile, 'notification.wav');
      expect(h.prefs.current.notificationSound, 'off');
      expect(h.prefs.current.notificationSoundFile, 'notification.wav');
    });

    test('setDwell：状态与偏好都变', () {
      final h = _harness();

      h.container
          .read(notificationPrefsControllerProvider.notifier)
          .setDwell(ToastDwell.never);

      expect(
        h.container.read(notificationPrefsControllerProvider).dwell,
        ToastDwell.never,
      );
      expect(h.prefs.current.toastDwell, 'never');
    });
  });

  group('preview', () {
    test('自定义 → 把文件名解析成绝对路径交给提示音服务', () async {
      final h = _harness(
        initial: const AppPreferences(
          notificationSound: 'custom',
          notificationSoundFile: 'notification.wav',
        ),
      );

      await h.container
          .read(notificationPrefsControllerProvider.notifier)
          .preview();

      expect(h.sound.plays, <(NotificationSound, String?)>[
        (NotificationSound.custom, '/data/config/sounds/notification.wav'),
      ]);
    });

    test('其余选择 → 不带路径、不碰存取层', () async {
      final h = _harness(
        initial: const AppPreferences(
          notificationSound: 'system',
          notificationSoundFile: 'notification.wav',
        ),
      );

      await h.container
          .read(notificationPrefsControllerProvider.notifier)
          .preview();

      expect(h.sound.plays, <(NotificationSound, String?)>[
        (NotificationSound.system, null),
      ]);
      expect(h.store.resolved, isEmpty);
    });

    test('跟着当前选择走（刚改的选择立刻生效）', () async {
      final h = _harness();
      final NotificationPrefsController c =
          h.container.read(notificationPrefsControllerProvider.notifier);

      c.setSound(NotificationSound.off);
      await c.preview();

      expect(h.sound.plays, <(NotificationSound, String?)>[
        (NotificationSound.off, null),
      ]);
    });
  });

  group('importCustomSound', () {
    test('成功 → 切到自定义，记下存好的文件名并落盘', () async {
      final h = _harness(
        initial: const AppPreferences(notificationSound: 'off'),
      );

      await h.container
          .read(notificationPrefsControllerProvider.notifier)
          .importCustomSound('/music/chime.mp3');

      expect(h.store.imported, <String>['/music/chime.mp3']);
      expect(
        h.container.read(notificationPrefsControllerProvider),
        (
          sound: NotificationSound.custom,
          soundFile: 'notification.mp3',
          dwell: ToastDwell.standard,
        ),
      );
      expect(h.prefs.current.notificationSound, 'custom');
      expect(h.prefs.current.notificationSoundFile, 'notification.mp3');
    });

    test('失败 → 原样抛出，状态与偏好都不动', () async {
      final h = _harness(
        initial: const AppPreferences(notificationSound: 'system'),
        importError: const LocalIOError(
          extra: <String, Object?>{
            'reason': kNotificationSoundTooLargeReason,
          },
        ),
      );

      await expectLater(
        h.container
            .read(notificationPrefsControllerProvider.notifier)
            .importCustomSound('/music/huge.wav'),
        throwsA(isA<LocalIOError>()),
      );

      final NotificationPrefs s =
          h.container.read(notificationPrefsControllerProvider);
      expect(s.sound, NotificationSound.system);
      expect(s.soundFile, isNull);
      expect(h.prefs.current.notificationSound, 'system');
      expect(h.prefs.current.notificationSoundFile, isNull);
    });
  });
}
