// NotificationSoundPlayer 单测：按选择路由到两条缝、自定义文件缺失静默、1200 ms 节流、绝不抛。
//
// 两条缝（AudioClipPlayer / SystemAlertSound）都换成只记录调用的假实现——不碰 media_kit、
// 不碰系统音频；时钟用 FakeClock 手动推进。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/notification_sound_service.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/features/notifications/models/notification_prefs.dart';
import 'package:inkframe/services/notification_sound/audio_clip_player.dart';
import 'package:inkframe/services/notification_sound/notification_sound_player.dart';
import 'package:inkframe/services/notification_sound/system_alert_sound.dart';
import 'package:path/path.dart' as p;

import '../../_harness/fake_clock.dart';
import '../../helpers/recording_logger.dart';

class _FakeClips implements AudioClipPlayer {
  final List<String> assets = <String>[];
  final List<(String, Duration?)> files = <(String, Duration?)>[];
  int disposeCalls = 0;

  /// 不为 null 时两种播放都抛它。
  Object? throwOnPlay;

  @override
  Future<void> playAsset(String assetKey) async {
    final Object? e = throwOnPlay;
    if (e != null) throw e;
    assets.add(assetKey);
  }

  @override
  Future<void> playFile(String path, {Duration? maxDuration}) async {
    final Object? e = throwOnPlay;
    if (e != null) throw e;
    files.add((path, maxDuration));
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _FakeSystemSound implements SystemAlertSound {
  int plays = 0;
  Object? throwOnPlay;

  @override
  Future<void> play() async {
    final Object? e = throwOnPlay;
    if (e != null) throw e;
    plays++;
  }
}

({
  NotificationSoundPlayer player,
  _FakeClips clips,
  _FakeSystemSound system,
  FakeClock clock,
  RecordingLogger logger,
}) _harness() {
  final _FakeClips clips = _FakeClips();
  final _FakeSystemSound system = _FakeSystemSound();
  final FakeClock clock = FakeClock(DateTime.utc(2026, 10, 14, 12));
  final RecordingLogger logger = RecordingLogger();
  return (
    player: NotificationSoundPlayer(
      clips: clips,
      systemSound: system,
      clock: clock,
      logger: logger,
    ),
    clips: clips,
    system: system,
    clock: clock,
    logger: logger,
  );
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_sound_player_');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// 磁盘上真有的一份自定义提示音。
  String existingCustomFile() {
    final File f = File(p.join(tmp.path, 'notification.wav'))
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);
    return f.path;
  }

  String missingCustomFile() => p.join(tmp.path, 'gone.mp3');

  group('按选择路由', () {
    test('InkFrame 默认 → 播打包的提示音资产，别的缝不碰', () async {
      final h = _harness();

      await h.player.play(NotificationSound.inkframe);

      expect(h.clips.assets, <String>[kNotificationChimeAsset]);
      expect(kNotificationChimeAsset, 'assets/sounds/notification.wav');
      expect(h.clips.files, isEmpty);
      expect(h.system.plays, 0);
    });

    test('系统提示音 → SystemAlertSound，别的缝不碰', () async {
      final h = _harness();

      await h.player.play(NotificationSound.system);

      expect(h.system.plays, 1);
      expect(h.clips.assets, isEmpty);
      expect(h.clips.files, isEmpty);
    });

    test('自定义 + 文件在 → 播这个文件，最多 4 秒', () async {
      final h = _harness();
      final String path = existingCustomFile();

      await h.player.play(NotificationSound.custom, customFilePath: path);

      expect(h.clips.files, <(String, Duration?)>[
        (path, kCustomNotificationSoundMaxPlay),
      ]);
      expect(kCustomNotificationSoundMaxPlay, const Duration(seconds: 4));
      expect(h.clips.assets, isEmpty);
      expect(h.system.plays, 0);
    });

    test('关闭 → 什么都不做', () async {
      final h = _harness();

      await h.player.play(NotificationSound.off);
      await h.player.play(
        NotificationSound.off,
        customFilePath: existingCustomFile(),
      );

      expect(h.clips.assets, isEmpty);
      expect(h.clips.files, isEmpty);
      expect(h.system.plays, 0);
    });
  });

  group('自定义文件缺失', () {
    test('路径为 null → 不响', () async {
      final h = _harness();

      await h.player.play(NotificationSound.custom);

      expect(h.clips.files, isEmpty);
      expect(h.clips.assets, isEmpty, reason: '不退回默认提示音');
    });

    test('文件已不在 → 不响', () async {
      final h = _harness();

      await h.player.play(
        NotificationSound.custom,
        customFilePath: missingCustomFile(),
      );

      expect(h.clips.files, isEmpty);
      expect(h.clips.assets, isEmpty, reason: '不退回默认提示音');
    });

    test('本来就不响的请求（关闭 / 文件缺失）不占节流窗口', () async {
      final h = _harness();

      await h.player.play(
        NotificationSound.custom,
        customFilePath: missingCustomFile(),
      );
      await h.player.play(NotificationSound.off);
      h.clock.advance(const Duration(milliseconds: 1));
      await h.player.play(NotificationSound.inkframe);

      expect(h.clips.assets, hasLength(1));
    });
  });

  group('节流 1200 ms', () {
    test('窗口内的第二声丢掉；距上一声满 1200 ms 再放行', () async {
      final h = _harness();

      await h.player.play(NotificationSound.inkframe);
      h.clock.advance(const Duration(milliseconds: 1199));
      await h.player.play(NotificationSound.inkframe);
      expect(h.clips.assets, hasLength(1), reason: '1199 ms 还在窗口内');

      h.clock.advance(const Duration(milliseconds: 1));
      await h.player.play(NotificationSound.inkframe);
      expect(h.clips.assets, hasLength(2), reason: '满 1200 ms 放行');
    });

    test('被丢掉的请求不顺延窗口', () async {
      final h = _harness();

      await h.player.play(NotificationSound.inkframe);
      h.clock.advance(const Duration(milliseconds: 800));
      await h.player.play(NotificationSound.inkframe);
      h.clock.advance(const Duration(milliseconds: 400));
      await h.player.play(NotificationSound.inkframe);

      expect(
        h.clips.assets,
        hasLength(2),
        reason: '窗口从上一次真正出声算起，被丢掉的那次不算',
      );
    });

    test('三种出声共用一个窗口', () async {
      final h = _harness();
      final String path = existingCustomFile();

      await h.player.play(NotificationSound.inkframe);
      h.clock.advance(const Duration(milliseconds: 300));
      await h.player.play(NotificationSound.system);
      h.clock.advance(const Duration(milliseconds: 300));
      await h.player.play(NotificationSound.custom, customFilePath: path);

      expect(h.clips.assets, hasLength(1));
      expect(h.system.plays, 0);
      expect(h.clips.files, isEmpty);
    });

    test('时钟回拨不把提示音哑掉', () async {
      final h = _harness();

      await h.player.play(NotificationSound.inkframe);
      h.clock.setNow(DateTime.utc(2026, 10, 14, 11));
      await h.player.play(NotificationSound.inkframe);

      expect(h.clips.assets, hasLength(2));
    });
  });

  group('绝不抛', () {
    test('资产播放抛错 → play 照常返回，记一条 warn', () async {
      final h = _harness();
      h.clips.throwOnPlay = StateError('mpv gone');

      await expectLater(h.player.play(NotificationSound.inkframe), completes);

      final List<LogRecord> warns = h.logger.byLevel(InkLogLevel.warn);
      expect(warns, hasLength(1));
      expect(warns.single.extra?['sound'], 'inkframe');
    });

    test('文件播放抛 Exception → 同样不抛', () async {
      final h = _harness();
      h.clips.throwOnPlay = Exception('decoder failed');

      await expectLater(
        h.player.play(
          NotificationSound.custom,
          customFilePath: existingCustomFile(),
        ),
        completes,
      );
      expect(h.logger.byLevel(InkLogLevel.warn), hasLength(1));
    });

    test('系统提示音抛错 → 同样不抛', () async {
      final h = _harness();
      h.system.throwOnPlay = ArgumentError('winmm.dll');

      await expectLater(h.player.play(NotificationSound.system), completes);
      expect(h.logger.byLevel(InkLogLevel.warn), hasLength(1));
    });
  });

  test('dispose → 释放底层播放器', () async {
    final h = _harness();

    await h.player.dispose();

    expect(h.clips.disposeCalls, 1);
  });
}
