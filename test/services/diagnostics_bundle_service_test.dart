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
    // 用户手编 JSON：误塞的 key 字段被解析器静默忽略——诊断包必须打码
    // 而非原文入包（#191 评审 P2-2）。
    File(p.join(paths.config.path, 'custom_providers.json')).writeAsStringSync(
        '{"providers":[{"id":"x","api_key":"sk-CUSTOM-LEAK"}]}');
    // macOS Debug 明文密钥文件——绝不能进包（红测核心）；含非 api_key 形态条目。
    File(p.join(paths.config.path, 'secrets.dev.json')).writeAsStringSync(
        '{"provider.openai.api_key":"sk-LEAKED",'
        '"database.pg.password":"pg-pw-LEAKED"}');
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

  test('红测核心：包内任何条目不含敏感词与金丝雀值', () async {
    seedAll();
    final target = p.join(tmp.path, 'diag2.zip');

    await build().exportBundle(targetPath: target);

    final archive =
        ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    // 敏感词表（大小写不敏感）+ 金丝雀值（值比键名更强的断言——评审 P3-1）。
    const words = <String>['api_key', 'apikey', 'password', 'token', 'secret'];
    const canaries = <String>['sk-LEAKED', 'sk-CUSTOM-LEAK', 'pg-pw-LEAKED'];
    for (final f in archive.files) {
      final text = utf8
          .decode(f.content as List<int>, allowMalformed: true)
          .toLowerCase();
      for (final w in words) {
        expect(text.contains(w), isFalse,
            reason: '诊断包泄密：${f.name} 含敏感词 $w');
      }
      for (final c in canaries) {
        expect(text.contains(c.toLowerCase()), isFalse,
            reason: '诊断包泄密：${f.name} 含金丝雀值 $c');
      }
    }
  });

  test('自吞守卫：保存位置选进 logs/ → 正在写的包与旧目标不进包（#191 P2-1）',
      () async {
    seedAll();
    // 旧的同名产物与本次目标都落在被扫描的 logs/ 目录内。
    final target = p.join(paths.logs.path, 'diag.zip');
    File(target).writeAsBytesSync(<int>[9, 9]);

    await build().exportBundle(targetPath: target);

    final archive =
        ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    final names = archive.files.map((f) => f.name).toSet();
    expect(names.where((n) => n.contains('diag.zip')), isEmpty,
        reason: '自吞：正在写的 zip / 旧目标被扫进包');
    expect(names, contains('logs/app.log'));
  });

  test('config 白名单软链跳过（POSIX；Windows 建链需特权跳过本测）', () async {
    if (Platform.isWindows) return;
    seedAll();
    // preferences.json 换成指向 secrets.dev.json 的软链——白名单名义绕排除。
    final pref = File(p.join(paths.config.path, 'preferences.json'))
      ..deleteSync();
    Link(pref.path).createSync(p.join(paths.config.path, 'secrets.dev.json'));

    final target = p.join(tmp.path, 'diag-link.zip');
    await build().exportBundle(targetPath: target);

    final archive =
        ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    expect(
      archive.files.map((f) => f.name),
      isNot(contains('config/preferences.json')),
    );
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
