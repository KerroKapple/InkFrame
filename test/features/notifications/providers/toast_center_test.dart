// ToastCenter：通知卡状态机的行为契约——按类型计时 / 停留时长偏好 / 悬停与失焦停表 /
// 只有在场的卡倒计时 / dedupeKey 原地替换 / 句柄 / 历史与未读 / 提示音。
//
// 全部计时走 fake_async 虚拟时钟：容器在 fakeAsync 区内建，ToastCenter 的 Timer 跟着
// 虚拟时间走；每例末尾 dispose 容器（顺带验证 onDispose 把 Timer 收干净）。
// 倒计时步长 100ms，断言统一留出一个步长以上的余量，不卡边界。
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/notification_sound.dart';
import 'package:inkframe/core/di/clock.dart';
import 'package:inkframe/core/di/notification_sound.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/interfaces/notification_sound_service.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/notifications/models/notification_prefs.dart';
import 'package:inkframe/features/notifications/models/toast_entry.dart';
import 'package:inkframe/features/notifications/providers/toast_center.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:path/path.dart' as p;

import '../../../_harness/fake_clock.dart';

class _RecordingSound implements NotificationSoundService {
  final List<({NotificationSound sound, String? path})> played =
      <({NotificationSound sound, String? path})>[];

  @override
  Future<void> play(NotificationSound sound, {String? customFilePath}) async {
    played.add((sound: sound, path: customFilePath));
  }
}

ProviderContainer _container({
  AppPreferences prefs = const AppPreferences(),
  NotificationSoundService? sound,
  AppPaths? paths,
  FakeClock? clock,
}) =>
    ProviderContainer(
      overrides: <Override>[
        preferencesServiceProvider
            .overrideWithValue(InMemoryPreferencesService(prefs)),
        if (sound != null)
          notificationSoundServiceProvider.overrideWithValue(sound),
        if (paths != null) appPathsProvider.overrideWithValue(paths),
        if (clock != null) clockProvider.overrideWithValue(clock),
      ],
    );

ToastCenter _center(ProviderContainer c) =>
    c.read(toastCenterProvider.notifier);

ToastCenterState _state(ProviderContainer c) => c.read(toastCenterProvider);

ToastEntry _only(ProviderContainer c) => _state(c).live.single;

/// 在场（不在淡出中）的卡标题，旧 → 新。
List<String> _activeTitles(ProviderContainer c) => <String>[
      for (final ToastEntry e in _state(c).live)
        if (!e.leaving) e.title,
    ];

List<String> _historyTitles(ProviderContainer c) =>
    <String>[for (final ToastEntry e in _state(c).history) e.title];

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  group('停留时长（纯函数）', () {
    test('标准档：提示 / 完成 4 秒、警告 6 秒、撤销 8 秒、失败 / 进行中不自动消失', () {
      expect(toastDwellFor(ToastKind.info, ToastDwell.standard), _ms(4000));
      expect(toastDwellFor(ToastKind.success, ToastDwell.standard), _ms(4000));
      expect(toastDwellFor(ToastKind.warning, ToastDwell.standard), _ms(6000));
      expect(toastDwellFor(ToastKind.undo, ToastDwell.standard), _ms(8000));
      expect(toastDwellFor(ToastKind.error, ToastDwell.standard), isNull);
      expect(toastDwellFor(ToastKind.progress, ToastDwell.standard), isNull);
    });

    test('加长档翻倍；不自动关闭档一律 null', () {
      expect(toastDwellFor(ToastKind.info, ToastDwell.long), _ms(8000));
      expect(toastDwellFor(ToastKind.undo, ToastDwell.long), _ms(16000));
      expect(toastDwellFor(ToastKind.error, ToastDwell.long), isNull);
      for (final ToastKind k in ToastKind.values) {
        expect(toastDwellFor(k, ToastDwell.never), isNull, reason: '$k');
      }
    });
  });

  group('按类型自动消失', () {
    test('提示卡 4 秒后开始退场，退场动画画完才从列表移除', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('hello');
        async.elapse(_ms(3800));
        expect(_only(c).leaving, isFalse, reason: '还没到 4 秒');
        async.elapse(_ms(300)); // 4.1s
        expect(_only(c).leaving, isTrue, reason: '4 秒到了应开始退场');
        async.elapse(_ms(200)); // 4.3s：退场 150ms 已画完
        expect(_state(c).live, isEmpty);
        expect(_historyTitles(c), <String>['hello'], reason: '走了的卡留在历史里');
        c.dispose();
      });
    });

    test('警告 6 秒、撤销 8 秒', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('warn', kind: ToastKind.warning);
        async.elapse(_ms(5800));
        expect(_only(c).leaving, isFalse);
        async.elapse(_ms(500));
        expect(_state(c).live.where((ToastEntry e) => !e.leaving), isEmpty);
        async.elapse(_ms(1000));

        _center(c).show('undo', kind: ToastKind.undo);
        async.elapse(_ms(7800));
        expect(_only(c).leaving, isFalse);
        async.elapse(_ms(500));
        expect(_state(c).live.where((ToastEntry e) => !e.leaving), isEmpty);
        c.dispose();
      });
    });

    test('失败与进行中不自动消失，也不起周期 Timer', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('boom', kind: ToastKind.error);
        _center(c).show('working', kind: ToastKind.progress);
        expect(async.periodicTimerCount, 0, reason: '没有要倒计时的卡就不该有 tick');
        async.elapse(const Duration(minutes: 5));
        expect(_activeTitles(c), <String>['boom', 'working']);
        c.dispose();
      });
    });

    test('多张卡只共用一个周期 Timer；全走完后 Timer 也停了', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('a');
        _center(c).show('b');
        expect(async.periodicTimerCount, 1);
        async.elapse(_ms(5000));
        expect(_state(c).live, isEmpty);
        expect(async.periodicTimerCount, 0);
        c.dispose();
      });
    });

    test('设置「加长」：提示卡停 8 秒', () {
      fakeAsync((async) {
        final ProviderContainer c =
            _container(prefs: const AppPreferences(toastDwell: 'long'));
        _center(c).show('hello');
        expect(_only(c).dwell, _ms(8000));
        async.elapse(_ms(7800));
        expect(_activeTitles(c), <String>['hello']);
        async.elapse(_ms(400));
        expect(_activeTitles(c), isEmpty);
        c.dispose();
      });
    });

    test('设置「不自动关闭」：提示卡一直在，且不起周期 Timer', () {
      fakeAsync((async) {
        final ProviderContainer c =
            _container(prefs: const AppPreferences(toastDwell: 'never'));
        _center(c).show('hello');
        expect(_only(c).dwell, isNull);
        expect(async.periodicTimerCount, 0);
        async.elapse(const Duration(minutes: 5));
        expect(_only(c).leaving, isFalse);
        c.dispose();
      });
    });
  });

  group('停表', () {
    test('鼠标停在卡片栈上：倒计时暂停，移开后接着走', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('hello');
        async.elapse(_ms(2000));
        _center(c).setHovered(true);
        expect(async.periodicTimerCount, 0, reason: '暂停时不该空转 tick');
        async.elapse(const Duration(seconds: 30));
        expect(_activeTitles(c), <String>['hello'], reason: '悬停期间不该走表');
        _center(c).setHovered(false);
        async.elapse(_ms(1800)); // 累计在走 3.8s
        expect(_activeTitles(c), <String>['hello']);
        async.elapse(_ms(400)); // 累计 4.2s
        expect(_activeTitles(c), isEmpty);
        c.dispose();
      });
    });

    test('窗口不在前台：倒计时暂停，回到前台接着走', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('hello');
        async.elapse(_ms(1000));
        _center(c).setWindowActive(false);
        expect(async.periodicTimerCount, 0, reason: '暂停时不该空转 tick');
        async.elapse(const Duration(seconds: 30));
        expect(_activeTitles(c), <String>['hello'], reason: '失焦期间不该走表');
        _center(c).setWindowActive(true);
        async.elapse(_ms(2800)); // 累计 3.8s
        expect(_activeTitles(c), <String>['hello']);
        async.elapse(_ms(400));
        expect(_activeTitles(c), isEmpty);
        c.dispose();
      });
    });

    test('最后一张卡走掉后悬停态自动复位：下一张卡照常倒计时', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        final ToastHandle h = _center(c).show('first');
        _center(c).setHovered(true); // 鼠标停在卡上……
        h.dismiss(); // ……把它关了，卡片栈被抽空（onExit 可能赶不上）
        async.elapse(_ms(300));
        expect(_state(c).live, isEmpty);
        _center(c).show('second');
        async.elapse(_ms(4300));
        expect(_activeTitles(c), isEmpty, reason: '不该还停着表');
        c.dispose();
      });
    });
  });

  group('在场与折叠', () {
    test('最多 3 张在场，更旧的折进「还有 N 条」；画出来的是最新的 3 张', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        for (int i = 0; i < 5; i++) {
          _center(c).show('t$i', kind: ToastKind.error);
        }
        final ToastCenterState s = _state(c);
        expect(s.overflowCount, 2);
        expect(
          <String>[for (final ToastEntry e in s.shown) e.title],
          <String>['t2', 't3', 't4'],
          reason: '旧 → 新，最新的贴着角',
        );
        c.dispose();
      });
    });

    test('折叠着的卡不倒计时：轮到它在场时才开始算', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('old info');
        final List<ToastHandle> errors = <ToastHandle>[
          for (int i = 0; i < 3; i++)
            _center(c).show('e$i', kind: ToastKind.error),
        ];
        async.elapse(const Duration(seconds: 30));
        expect(_activeTitles(c).first, 'old info', reason: '它被折叠着，不该替它把时间花掉');

        errors.last.dismiss(); // 走掉一张 ⇒ 它进场
        async.elapse(_ms(3800));
        expect(_activeTitles(c).first, 'old info');
        async.elapse(_ms(500));
        expect(_activeTitles(c), <String>['e0', 'e1']);
        c.dispose();
      });
    });

    test('关掉一张折叠着的卡：直接移除，不走淡出', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        final ToastHandle hidden = _center(c).show('hidden', kind: ToastKind.error);
        for (int i = 0; i < 3; i++) {
          _center(c).show('e$i', kind: ToastKind.error);
        }
        hidden.dismiss();
        expect(
          _state(c).live.map((ToastEntry e) => e.title).toList(),
          <String>['e0', 'e1', 'e2'],
        );
        c.dispose();
      });
    });
  });

  group('dedupeKey', () {
    test('同一个 key 原地替换在场那一张：卡位 id 不变、不新增', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('save failed 1', kind: ToastKind.error, dedupeKey: 'n1');
        final int id = _only(c).id;
        _center(c).show('save failed 2', kind: ToastKind.error, dedupeKey: 'n1');
        expect(_only(c).id, id);
        expect(_only(c).title, 'save failed 2');
        expect(_historyTitles(c), <String>['save failed 2'], reason: '历史里也是同一行');

        _center(c).show('other', kind: ToastKind.error, dedupeKey: 'n2');
        expect(_activeTitles(c), <String>['save failed 2', 'other']);
        c.dispose();
      });
    });

    test('替换重新计时', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('a', dedupeKey: 'k');
        async.elapse(_ms(3000));
        _center(c).show('b', dedupeKey: 'k');
        async.elapse(_ms(3500)); // 原卡早该走了；替换后才 3.5s
        expect(_activeTitles(c), <String>['b']);
        async.elapse(_ms(800));
        expect(_activeTitles(c), isEmpty);
        c.dispose();
      });
    });

    test('卡位被别的 show 接管后，旧句柄是空操作', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        final ToastHandle first =
            _center(c).show('a', kind: ToastKind.error, dedupeKey: 'k');
        _center(c).show('b', kind: ToastKind.error, dedupeKey: 'k');
        first.update(title: 'stale');
        first.dismiss();
        expect(_only(c).title, 'b');
        expect(_only(c).leaving, isFalse);
        c.dispose();
      });
    });
  });

  group('句柄', () {
    test('update 只改传了的字段，进度 clamp 到 0..1，不动计时', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        final ToastHandle h =
            _center(c).show('Exporting', kind: ToastKind.progress, body: 'shot 1');
        h.update(progress: 0.4);
        expect(_only(c).progress, 0.4);
        h.update(title: 'Exporting…');
        expect(_only(c).title, 'Exporting…');
        expect(_only(c).body, 'shot 1');
        expect(_only(c).progress, 0.4);
        h.update(progress: 1.7);
        expect(_only(c).progress, 1.0);
        expect(_state(c).history.single.title, 'Exporting…', reason: '历史那一行跟着改');
        c.dispose();
      });
    });

    test('complete：原地变成终态卡（同一卡位），并从这一刻重新计时', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        final ToastHandle h =
            _center(c).show('Exporting', kind: ToastKind.progress);
        h.update(progress: 0.9);
        final int id = _only(c).id;
        async.elapse(const Duration(seconds: 20)); // 进行中不自动消失
        h.complete(kind: ToastKind.success, title: 'Exported', body: 'out.mp4');
        final ToastEntry done = _only(c);
        expect(done.id, id);
        expect(done.kind, ToastKind.success);
        expect(done.title, 'Exported');
        expect(done.body, 'out.mp4');
        expect(done.progress, isNull);
        async.elapse(_ms(3800));
        expect(_activeTitles(c), <String>['Exported'], reason: '计时从 complete 那一刻起算');
        async.elapse(_ms(400));
        expect(_activeTitles(c), isEmpty);
        c.dispose();
      });
    });

    test('complete 成失败：不自动消失', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c)
            .show('Exporting', kind: ToastKind.progress)
            .complete(kind: ToastKind.error, title: 'Export failed');
        async.elapse(const Duration(minutes: 1));
        expect(_only(c).kind, ToastKind.error);
        expect(_only(c).leaving, isFalse);
        c.dispose();
      });
    });

    test('dismiss：淡出后移除；之后再调任何方法都是安全的空操作', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        final ToastHandle h = _center(c).show('x', kind: ToastKind.error);
        h.dismiss();
        expect(_only(c).leaving, isTrue);
        async.elapse(_ms(200));
        expect(_state(c).live, isEmpty);
        h.update(title: 'late');
        h.complete(kind: ToastKind.success, title: 'late');
        h.dismiss();
        expect(_state(c).live, isEmpty);
        expect(_historyTitles(c), <String>['x']);
        c.dispose();
      });
    });
  });

  group('历史与未读', () {
    test('历史新 → 旧；只留最近 100 条；掉出去的不再算未读', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        for (int i = 0; i < 105; i++) {
          _center(c).show('t$i', kind: ToastKind.error);
        }
        final ToastCenterState s = _state(c);
        expect(s.history, hasLength(kToastHistoryCap));
        expect(s.history.first.title, 't104');
        expect(s.history.last.title, 't5');
        expect(s.unreadCount, kToastHistoryCap);
        c.dispose();
      });
    });

    test('出现时刻取 clockProvider', () {
      fakeAsync((async) {
        final FakeClock clock = FakeClock(DateTime.utc(2026, 10, 14, 9));
        final ProviderContainer c = _container(clock: clock);
        _center(c).show('hello');
        expect(_state(c).history.single.createdAt, DateTime.utc(2026, 10, 14, 9));
        c.dispose();
      });
    });

    test('打开历史 = 全部已读；开着期间到达的不算未读；关上之后照常计', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('a');
        _center(c).show('b');
        expect(_state(c).unreadCount, 2);
        _center(c).openHistory();
        expect(_state(c).historyOpen, isTrue);
        expect(_state(c).unreadCount, 0);
        _center(c).show('c');
        expect(_state(c).unreadCount, 0, reason: '面板开着时到达的已经看见了');
        _center(c).closeHistory();
        expect(_state(c).historyOpen, isFalse);
        _center(c).show('d');
        expect(_state(c).unreadCount, 1);
        c.dispose();
      });
    });

    test('未读里有失败 ⇒ hasUnreadError；全部已读后复位', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('ok', kind: ToastKind.success);
        expect(_state(c).hasUnreadError, isFalse);
        _center(c).show('boom', kind: ToastKind.error);
        expect(_state(c).hasUnreadError, isTrue);
        _center(c).markAllRead();
        expect(_state(c).unreadCount, 0);
        expect(_state(c).hasUnreadError, isFalse);
        c.dispose();
      });
    });

    test('清空历史不动右下角在场的卡', () {
      fakeAsync((async) {
        final ProviderContainer c = _container();
        _center(c).show('boom', kind: ToastKind.error);
        _center(c).clearHistory();
        expect(_state(c).history, isEmpty);
        expect(_state(c).unreadCount, 0);
        expect(_activeTitles(c), <String>['boom']);
        c.dispose();
      });
    });
  });

  group('提示音', () {
    test('chime：按设置的提示音调用提示音服务', () {
      fakeAsync((async) {
        final _RecordingSound sound = _RecordingSound();
        final ProviderContainer c = _container(
          prefs: const AppPreferences(notificationSound: 'system'),
          sound: sound,
        );
        _center(c).show('done', kind: ToastKind.success, chime: true);
        expect(sound.played, hasLength(1));
        expect(sound.played.single.sound, NotificationSound.system);
        expect(sound.played.single.path, isNull);
        c.dispose();
      });
    });

    test('自定义提示音：传 <数据目录>/config/sounds/<文件名>', () {
      fakeAsync((async) {
        final _RecordingSound sound = _RecordingSound();
        final AppPaths paths = DefaultAppPaths.forRoot(
          Directory(p.join(Directory.systemTemp.path, 'inkframe_toast_center')),
        );
        final ProviderContainer c = _container(
          prefs: const AppPreferences(
            notificationSound: 'custom',
            notificationSoundFile: 'ding.wav',
          ),
          sound: sound,
          paths: paths,
        );
        _center(c).show('done', kind: ToastKind.success, chime: true);
        expect(sound.played.single.sound, NotificationSound.custom);
        expect(
          sound.played.single.path,
          p.join(paths.config.path, kCustomNotificationSoundDir, 'ding.wav'),
        );
        c.dispose();
      });
    });

    test('自定义但还没选文件：照样交给服务（它静默不响），路径为 null', () {
      fakeAsync((async) {
        final _RecordingSound sound = _RecordingSound();
        final ProviderContainer c = _container(
          prefs: const AppPreferences(notificationSound: 'custom'),
          sound: sound,
        );
        _center(c).show('done', chime: true);
        expect(sound.played.single.sound, NotificationSound.custom);
        expect(sound.played.single.path, isNull);
        c.dispose();
      });
    });

    test('chime == false 不响；complete 的 chime 同样生效', () {
      fakeAsync((async) {
        final _RecordingSound sound = _RecordingSound();
        final ProviderContainer c = _container(sound: sound);
        final ToastHandle h = _center(c).show('Exporting', kind: ToastKind.progress);
        _center(c).show('deleted', kind: ToastKind.undo);
        expect(sound.played, isEmpty, reason: '用户自己刚做的操作不响');
        h.complete(kind: ToastKind.success, title: 'Exported', chime: true);
        expect(sound.played, hasLength(1));
        expect(sound.played.single.sound, NotificationSound.inkframe);
        c.dispose();
      });
    });
  });

  test('toastServiceProvider 就是 ToastCenter 本身', () {
    final ProviderContainer c = _container();
    addTearDown(c.dispose);
    expect(
      identical(c.read(toastServiceProvider), c.read(toastCenterProvider.notifier)),
      isTrue,
    );
  });
}
