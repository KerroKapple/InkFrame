// NotificationsSection widget 测：
// - 四个提示音选项都在，点哪个哪个变选中并落盘；停留时长三选一同理；
// - 「关闭」时试听禁用，其余选择可试听；自定义还没选文件时也禁用；
// - 自定义那一行显示存好的文件名 / 「还没选文件」；
// - 选文件导入：成功切到自定义；太大单独说一句，其余失败统一一句，都走通知卡（error）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/notification_sound.dart';
import 'package:inkframe/core/di/notification_sound_store.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/notification_sound_service.dart';
import 'package:inkframe/core/interfaces/notification_sound_store.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/constants/notification_sound.dart';
import 'package:inkframe/features/notifications/models/notification_prefs.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/settings/widgets/notifications_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/theme/components/ink_button.dart';

import '../../_harness/fake_toast_service.dart';
import '../../_harness/test_app.dart';

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

  @override
  Future<String> importFile(String sourcePath) async {
    imported.add(sourcePath);
    final LocalIOError? e = importError;
    if (e != null) throw e;
    return 'notification.mp3';
  }

  @override
  String? resolve(String? fileName) =>
      fileName == null ? null : '/data/config/sounds/$fileName';
}

/// 一次 pump 用到的全部替身。
class _Rig {
  _Rig({
    AppPreferences initial = const AppPreferences(),
    this.pickedPath,
    LocalIOError? importError,
  })  : prefs = InMemoryPreferencesService(initial),
        store = _FakeStore(importError: importError);

  final InMemoryPreferencesService prefs;
  final _FakeStore store;
  final _RecordingSound sound = _RecordingSound();
  final RecordingToastService toast = RecordingToastService();

  /// 选文件框「选中」的路径；null = 用户取消。
  final String? pickedPath;
  final List<(String, List<String>)> pickerCalls = <(String, List<String>)>[];

  List<Override> get overrides => <Override>[
        preferencesServiceProvider.overrideWithValue(prefs),
        notificationSoundServiceProvider.overrideWithValue(sound),
        notificationSoundStoreProvider.overrideWithValue(store),
        notificationSoundFilePickerProvider.overrideWithValue(
          (String typeLabel, List<String> extensions) async {
            pickerCalls.add((typeLabel, extensions));
            return pickedPath;
          },
        ),
        toastServiceProvider.overrideWithValue(toast),
      ];
}

final AppLocalizations _l = lookupAppLocalizations(const Locale('en'));

Future<void> _pump(WidgetTester tester, _Rig rig) async {
  await pumpInkApp(
    tester,
    const Scaffold(
      body: SingleChildScrollView(child: NotificationsSection()),
    ),
    overrides: rig.overrides,
    surfaceSize: const Size(1000, 800),
  );
  await tester.pump();
}

/// [key] 所在处的 InkButton（key 挂在选项包装上或直接挂在按钮上都找得到）。
InkButton _button(WidgetTester tester, Key key) => tester.widget<InkButton>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(InkButton),
        matchRoot: true,
      ),
    );

bool _selected(WidgetTester tester, Key key) =>
    _button(tester, key).variant == InkButtonVariant.primary;

void main() {
  group('提示音选项', () {
    testWidgets('四个选项都在，默认选中 InkFrame 默认', (tester) async {
      await _pump(tester, _Rig());

      expect(find.text(_l.settingsNotificationsSection), findsOneWidget);
      expect(find.text(_l.settingsNotificationSoundInkframe), findsOneWidget);
      expect(find.text(_l.settingsNotificationSoundSystem), findsOneWidget);
      expect(find.text(_l.settingsNotificationSoundCustom), findsOneWidget);
      expect(find.text(_l.settingsNotificationSoundOff), findsOneWidget);
      for (final NotificationSound s in NotificationSound.values) {
        expect(
          _selected(tester, NotificationsSection.soundKey(s)),
          s == NotificationSound.inkframe,
          reason: '${s.name} 的选中态不对',
        );
      }
    });

    testWidgets('点哪个哪个变选中，并即时落盘', (tester) async {
      final _Rig rig = _Rig();
      await _pump(tester, rig);

      for (final NotificationSound s in <NotificationSound>[
        NotificationSound.system,
        NotificationSound.custom,
        NotificationSound.off,
        NotificationSound.inkframe,
      ]) {
        await tester.tap(find.byKey(NotificationsSection.soundKey(s)));
        await tester.pumpAndSettle();

        expect(rig.prefs.current.notificationSound, s.name);
        expect(_selected(tester, NotificationsSection.soundKey(s)), isTrue,
            reason: '点了 ${s.name} 却没变选中');
      }
    });

    testWidgets('说明文字跟着选择换；「关闭」不带说明', (tester) async {
      await _pump(tester, _Rig());
      expect(find.text(_l.settingsNotificationSoundInkframeHint), findsOneWidget);

      await tester.tap(
          find.byKey(NotificationsSection.soundKey(NotificationSound.system)));
      await tester.pumpAndSettle();
      expect(find.text(_l.settingsNotificationSoundSystemHint), findsOneWidget);
      expect(find.text(_l.settingsNotificationSoundInkframeHint), findsNothing);

      await tester.tap(
          find.byKey(NotificationsSection.soundKey(NotificationSound.off)));
      await tester.pumpAndSettle();
      expect(find.text(_l.settingsNotificationSoundInkframeHint), findsNothing);
      expect(find.text(_l.settingsNotificationSoundSystemHint), findsNothing);
      expect(find.text(_l.settingsNotificationSoundCustomHint), findsNothing);
    });
  });

  group('试听', () {
    testWidgets('「关闭」时禁用', (tester) async {
      await _pump(
        tester,
        _Rig(initial: const AppPreferences(notificationSound: 'off')),
      );

      expect(_button(tester, NotificationsSection.previewKey).onPressed, isNull);
    });

    testWidgets('切到别的选择就能试听，播的是当前选择', (tester) async {
      final _Rig rig =
          _Rig(initial: const AppPreferences(notificationSound: 'off'));
      await _pump(tester, rig);

      await tester.tap(
          find.byKey(NotificationsSection.soundKey(NotificationSound.system)));
      await tester.pumpAndSettle();
      expect(
        _button(tester, NotificationsSection.previewKey).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(NotificationsSection.previewKey));
      await tester.pumpAndSettle();
      expect(rig.sound.plays, <(NotificationSound, String?)>[
        (NotificationSound.system, null),
      ]);
    });

    testWidgets('自定义还没选文件 → 禁用（按了也不会响）', (tester) async {
      await _pump(
        tester,
        _Rig(initial: const AppPreferences(notificationSound: 'custom')),
      );

      expect(_button(tester, NotificationsSection.previewKey).onPressed, isNull);
    });

    testWidgets('自定义有文件 → 试听带上解析后的绝对路径', (tester) async {
      final _Rig rig = _Rig(
        initial: const AppPreferences(
          notificationSound: 'custom',
          notificationSoundFile: 'notification.mp3',
        ),
      );
      await _pump(tester, rig);

      await tester.tap(find.byKey(NotificationsSection.previewKey));
      await tester.pumpAndSettle();

      expect(rig.sound.plays, <(NotificationSound, String?)>[
        (NotificationSound.custom, '/data/config/sounds/notification.mp3'),
      ]);
    });
  });

  group('自定义文件', () {
    testWidgets('不是自定义时不显示文件行', (tester) async {
      await _pump(tester, _Rig());

      expect(find.byKey(NotificationsSection.chooseFileKey), findsNothing);
    });

    testWidgets('已有文件 → 显示文件名 +「更换…」', (tester) async {
      await _pump(
        tester,
        _Rig(
          initial: const AppPreferences(
            notificationSound: 'custom',
            notificationSoundFile: 'notification.mp3',
          ),
        ),
      );

      expect(find.text('notification.mp3'), findsOneWidget);
      expect(
        _button(tester, NotificationsSection.chooseFileKey).label,
        _l.settingsNotificationSoundReplaceFile,
      );
      expect(find.text(_l.settingsNotificationSoundNoFile), findsNothing);
    });

    testWidgets('还没选 → 「还没选文件」+「选择文件…」', (tester) async {
      await _pump(
        tester,
        _Rig(initial: const AppPreferences(notificationSound: 'custom')),
      );

      expect(find.text(_l.settingsNotificationSoundNoFile), findsOneWidget);
      expect(
        _button(tester, NotificationsSection.chooseFileKey).label,
        _l.settingsNotificationSoundChooseFile,
      );
    });

    testWidgets('选文件成功 → 导入、切到自定义、显示新文件名，不弹通知', (tester) async {
      final _Rig rig = _Rig(
        initial: const AppPreferences(notificationSound: 'custom'),
        pickedPath: '/music/chime.mp3',
      );
      await _pump(tester, rig);

      await tester.tap(find.byKey(NotificationsSection.chooseFileKey));
      await tester.pumpAndSettle();

      expect(rig.pickerCalls, hasLength(1));
      expect(rig.pickerCalls.single.$1, _l.settingsNotificationSoundFileType);
      expect(rig.pickerCalls.single.$2, kCustomNotificationSoundExtensions);
      expect(rig.store.imported, <String>['/music/chime.mp3']);
      expect(rig.prefs.current.notificationSound, 'custom');
      expect(rig.prefs.current.notificationSoundFile, 'notification.mp3');
      expect(find.text('notification.mp3'), findsOneWidget);
      expect(rig.toast.shown, isEmpty);
    });

    testWidgets('取消选文件 → 什么都不做', (tester) async {
      final _Rig rig =
          _Rig(initial: const AppPreferences(notificationSound: 'custom'));
      await _pump(tester, rig);

      await tester.tap(find.byKey(NotificationsSection.chooseFileKey));
      await tester.pumpAndSettle();

      expect(rig.pickerCalls, hasLength(1));
      expect(rig.store.imported, isEmpty);
      expect(rig.toast.shown, isEmpty);
    });

    testWidgets('文件太大 → 通知卡（error）说「超过 2 MB」，偏好不动', (tester) async {
      final _Rig rig = _Rig(
        initial: const AppPreferences(notificationSound: 'custom'),
        pickedPath: '/music/huge.wav',
        importError: const LocalIOError(
          extra: <String, Object?>{
            'reason': kNotificationSoundTooLargeReason,
          },
        ),
      );
      await _pump(tester, rig);

      await tester.tap(find.byKey(NotificationsSection.chooseFileKey));
      await tester.pumpAndSettle();

      expect(rig.toast.titles, <String>[_l.settingsNotificationSoundTooLarge]);
      expect(rig.toast.kinds, <ToastKind>[ToastKind.error]);
      expect(rig.prefs.current.notificationSoundFile, isNull);
      expect(find.text(_l.settingsNotificationSoundNoFile), findsOneWidget);
    });

    testWidgets('其余导入失败 → 通知卡（error）说「这个文件用不了」', (tester) async {
      final _Rig rig = _Rig(
        initial: const AppPreferences(notificationSound: 'custom'),
        pickedPath: '/music/song.flac',
        importError: const LocalIOError(
          extra: <String, Object?>{
            'reason': kNotificationSoundUnsupportedReason,
          },
        ),
      );
      await _pump(tester, rig);

      await tester.tap(find.byKey(NotificationsSection.chooseFileKey));
      await tester.pumpAndSettle();

      expect(rig.toast.titles, <String>[_l.settingsNotificationSoundImportFailed]);
      expect(rig.toast.kinds, <ToastKind>[ToastKind.error]);
      expect(rig.prefs.current.notificationSoundFile, isNull);
    });
  });

  group('停留时长', () {
    testWidgets('三个选项，默认标准；点了即时落盘', (tester) async {
      final _Rig rig = _Rig();
      await _pump(tester, rig);

      expect(find.text(_l.settingsNotificationDwellStandard), findsOneWidget);
      expect(find.text(_l.settingsNotificationDwellLong), findsOneWidget);
      expect(find.text(_l.settingsNotificationDwellNever), findsOneWidget);
      expect(
        _selected(tester, NotificationsSection.dwellKey(ToastDwell.standard)),
        isTrue,
      );

      for (final ToastDwell d in <ToastDwell>[
        ToastDwell.never,
        ToastDwell.long,
        ToastDwell.standard,
      ]) {
        await tester.tap(find.byKey(NotificationsSection.dwellKey(d)));
        await tester.pumpAndSettle();

        expect(rig.prefs.current.toastDwell, d.name);
        expect(_selected(tester, NotificationsSection.dwellKey(d)), isTrue,
            reason: '点了 ${d.name} 却没变选中');
      }
    });
  });
}
