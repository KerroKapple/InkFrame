// ZipDiagnosticsBundleService 单测：内容清单 / 无 api_key 钉死 / 落盘纪律。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/diagnostics_bundle_service.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:path/path.dart' as p;

class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime nowUtc() => _now;
}

void main() {
  late Directory tmp;
  late AppPaths paths;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_diag_');
    paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'root')));
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows：archive 包 addFile 异常路径泄漏源句柄（进程退出才释放），
      // 锁文件用例后临时目录删不掉不影响断言（同 LB-11 已知问题，BOARD 有债）。
    }
  });

  ZipDiagnosticsBundleService build() => ZipDiagnosticsBundleService(
        paths: paths,
        clock: _FixedClock(DateTime.utc(2026, 7, 17, 8, 30, 0)),
        appVersion: '9.9.9',
      );

  void seedAll() {
    paths.logs.createSync(recursive: true);
    File(p.join(paths.logs.path, 'app.log')).writeAsStringSync('log line');
    File(p.join(paths.logs.path, 'pg.log')).writeAsStringSync('pg line');
    paths.crashes.createSync(recursive: true);
    File(p.join(paths.crashes.path, 'inkframe.crash.1.log'))
        .writeAsStringSync('crash');
    paths.config.createSync(recursive: true);
    File(p.join(paths.config.path, 'preferences.json'))
        .writeAsStringSync('{"theme":"dark"}');
    File(p.join(paths.config.path, 'custom_providers.json'))
        .writeAsStringSync('{"providers":[]}');
    // macOS Debug 明文密钥文件——绝不能进包（红测核心）。
    File(p.join(paths.config.path, 'secrets.dev.json'))
        .writeAsStringSync('{"provider.openai.api_key":"sk-LEAKED"}');
  }

  test('内容清单：logs/crashes/config 白名单 + info.json；secrets.dev.json 不进包',
      () async {
    seedAll();
    final target = p.join(tmp.path, 'diag.zip');

    await build().exportBundle(targetPath: target);

    final archive =
        ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, <String>{
      'info.json',
      'logs/app.log',
      'logs/pg.log',
      'crashes/inkframe.crash.1.log',
      'config/preferences.json',
      'config/custom_providers.json',
    });
    expect(File('$target.partial').existsSync(), isFalse);
  });

  test('红测核心：包内任何条目不含 "api_key" 字节序列', () async {
    seedAll();
    final target = p.join(tmp.path, 'diag2.zip');

    await build().exportBundle(targetPath: target);

    final archive =
        ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    for (final f in archive.files) {
      final text = utf8.decode(f.content as List<int>, allowMalformed: true);
      expect(text.contains('api_key'), isFalse,
          reason: '诊断包泄密：${f.name} 含 api_key 字段');
    }
  });

  test('info.json：appVersion/schemaVersion/platform/createdAtUtc', () async {
    final target = p.join(tmp.path, 'diag3.zip');
    await build().exportBundle(targetPath: target);

    final archive =
        ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    final info = jsonDecode(utf8.decode(archive.files
        .firstWhere((f) => f.name == 'info.json')
        .content as List<int>)) as Map<String, dynamic>;
    expect(info['appVersion'], '9.9.9');
    expect(info['schemaVersion'], kAppMigrations.last.version);
    expect(info['platform'], Platform.operatingSystem);
    expect(info['createdAtUtc'], '2026-07-17T08:30:00.000Z');
  });

  test('空目录 → 仅 info.json，合法', () async {
    final target = p.join(tmp.path, 'diag4.zip');
    await build().exportBundle(targetPath: target);
    final archive =
        ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    expect(archive.files.map((f) => f.name).toSet(), <String>{'info.json'});
  });

  test('日志文件不可读 → LocalIOError，零 .partial 残留', () async {
    // 平台分叉触发（同 #188 P3-8 先例）：Windows 强制独占锁；POSIX chmod 000。
    paths.logs.createSync(recursive: true);
    final locked = File(p.join(paths.logs.path, 'locked.log'))
      ..writeAsStringSync('x');
    RandomAccessFile? raf;
    if (Platform.isWindows) {
      raf = locked.openSync(mode: FileMode.append);
      raf.lockSync(FileLock.exclusive);
    } else {
      Process.runSync('chmod', <String>['000', locked.path]);
    }
    addTearDown(() {
      if (raf != null) {
        raf.unlockSync();
        raf.closeSync();
      } else {
        Process.runSync('chmod', <String>['644', locked.path]);
      }
    });

    final target = p.join(tmp.path, 'diag5.zip');
    await expectLater(
      build().exportBundle(targetPath: target),
      throwsA(isA<LocalIOError>()),
    );
    expect(File('$target.partial').existsSync(), isFalse);
    expect(File(target).existsSync(), isFalse);
  });

  test('diagnosticsBundleFileName：时间戳命名', () {
    expect(
      diagnosticsBundleFileName(DateTime.utc(2026, 7, 17, 8, 30, 5)),
      'inkframe-diagnostics-2026-07-17-083005.zip',
    );
  });
}
