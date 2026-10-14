// FileNotificationSoundStore 单测（临时目录）：
// - 导入 = 复制进 config/sounds/notification.<ext>、返回文件名、顶替上一份；
// - 太大 / 类型不对 / 空文件 / 源文件不在 → 各自的 reason，且什么都不写、上一份不动；
// - resolve 只认单纯的文件名，给绝对路径或 null。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/notification_sound_store.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/core/constants/notification_sound.dart';
import 'package:inkframe/services/file_notification_sound_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late AppPaths paths;
  late Directory srcDir;
  late FileNotificationSoundStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_sound_store_');
    paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'root')));
    srcDir = Directory(p.join(tmp.path, 'src'))..createSync();
    store = FileNotificationSoundStore(paths: paths);
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Directory soundsDir() =>
      Directory(p.join(paths.config.path, kCustomNotificationSoundDir));

  /// 提示音目录里现有的文件名（排好序）；目录不存在 = 空。
  List<String> storedNames() {
    final Directory d = soundsDir();
    if (!d.existsSync()) return <String>[];
    return d
        .listSync()
        .whereType<File>()
        .map((File f) => p.basename(f.path))
        .toList()
      ..sort();
  }

  List<int> storedBytes(String name) =>
      File(p.join(soundsDir().path, name)).readAsBytesSync();

  String source(String name, List<int> bytes) {
    final File f = File(p.join(srcDir.path, name))..writeAsBytesSync(bytes);
    return f.path;
  }

  Matcher failsWith(String reason) => throwsA(
        isA<LocalIOError>()
            .having((LocalIOError e) => e.extra['reason'], 'reason', reason),
      );

  group('importFile', () {
    test('复制进 config/sounds/notification.<ext>（扩展名转小写），返回文件名', () async {
      final String src = source('My Chime.WAV', <int>[1, 2, 3, 4]);

      final String name = await store.importFile(src);

      expect(name, 'notification.wav');
      expect(storedNames(), <String>['notification.wav'],
          reason: '只留一份，没有 .partial 残留');
      expect(storedBytes(name), <int>[1, 2, 3, 4]);
      expect(File(src).existsSync(), isTrue, reason: '是复制，不是搬走');
    });

    test('换一个扩展名不同的文件 → 新的就位，上一份删掉', () async {
      await store.importFile(source('a.mp3', <int>[1]));

      final String name = await store.importFile(source('b.ogg', <int>[2, 2]));

      expect(name, 'notification.ogg');
      expect(storedNames(), <String>['notification.ogg']);
      expect(storedBytes(name), <int>[2, 2]);
    });

    test('换一个扩展名相同的文件 → 原地顶替内容', () async {
      await store.importFile(source('a.wav', <int>[1]));

      final String name = await store.importFile(source('b.wav', <int>[7, 7, 7]));

      expect(name, 'notification.wav');
      expect(storedNames(), <String>['notification.wav']);
      expect(storedBytes(name), <int>[7, 7, 7]);
    });

    test('目录里不是我们放的文件不碰', () async {
      soundsDir().createSync(recursive: true);
      File(p.join(soundsDir().path, 'readme.txt')).writeAsStringSync('keep');

      await store.importFile(source('a.m4a', <int>[1]));

      expect(storedNames(), <String>['notification.m4a', 'readme.txt']);
    });

    test('超过 2 MB → too_large，什么都不写，上一份原样保留', () async {
      await store.importFile(source('ok.wav', <int>[9]));
      final String big = source(
        'big.mp3',
        List<int>.filled(kCustomNotificationSoundMaxBytes + 1, 0),
      );

      await expectLater(
        store.importFile(big),
        failsWith(kNotificationSoundTooLargeReason),
      );

      expect(storedNames(), <String>['notification.wav']);
      expect(storedBytes('notification.wav'), <int>[9]);
    });

    test('恰好 2 MB → 收下', () async {
      final String edge = source(
        'edge.m4a',
        List<int>.filled(kCustomNotificationSoundMaxBytes, 1),
      );

      expect(await store.importFile(edge), 'notification.m4a');
      expect(storedNames(), <String>['notification.m4a']);
    });

    test('扩展名不在白名单 → unsupported，什么都不写', () async {
      await expectLater(
        store.importFile(source('song.flac', <int>[1])),
        failsWith(kNotificationSoundUnsupportedReason),
      );
      await expectLater(
        store.importFile(source('noext', <int>[1])),
        failsWith(kNotificationSoundUnsupportedReason),
      );

      expect(storedNames(), isEmpty);
    });

    test('空文件 → empty，什么都不写', () async {
      await expectLater(
        store.importFile(source('silent.wav', <int>[])),
        failsWith(kNotificationSoundEmptyReason),
      );

      expect(storedNames(), isEmpty);
    });

    test('源文件已不在 → io_failed', () async {
      await expectLater(
        store.importFile(p.join(srcDir.path, 'gone.wav')),
        failsWith(kNotificationSoundIoFailedReason),
      );

      expect(storedNames(), isEmpty);
    });
  });

  group('resolve', () {
    test('文件名 → 提示音目录下的绝对路径', () {
      final String? resolved = store.resolve('notification.wav');

      expect(
        resolved,
        p.join(paths.config.path, kCustomNotificationSoundDir, 'notification.wav'),
      );
      expect(p.isAbsolute(resolved!), isTrue);
    });

    test('null / 空串 → null', () {
      expect(store.resolve(null), isNull);
      expect(store.resolve(''), isNull);
    });

    test('带目录或 .. 的名字 → null（偏好文件可手改，不能指到目录外）', () {
      expect(store.resolve('../evil.wav'), isNull);
      expect(store.resolve('sub/notification.wav'), isNull);
      expect(store.resolve('..'), isNull);
      expect(store.resolve('.'), isNull);
    });
  });
}
