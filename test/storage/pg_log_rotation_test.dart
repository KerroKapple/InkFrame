// pg.log 启动期轮转（BOARD 185）——纯函数部分。
// 装配（start() 在 pg_ctl start 之前调它）另见 pg_controller_test。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/pg_log_rotation.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory logs;
  late File pgLog;
  final DateTime t0 = DateTime.utc(2026, 10, 13, 9, 30, 15);

  setUp(() {
    logs = Directory.systemTemp.createTempSync('pg_log_rot_');
    pgLog = File(p.join(logs.path, 'pg.log'));
  });
  tearDown(() {
    if (logs.existsSync()) logs.deleteSync(recursive: true);
  });

  List<String> names() =>
      (logs.listSync().whereType<File>().map((f) => p.basename(f.path)).toList()
        ..sort());

  test('不存在 ⇒ notNeeded，什么都不建', () {
    expect(rotatePgLogIfLarge(pgLog, nowUtc: t0), PgLogRotation.notNeeded);
    expect(names(), isEmpty);
  });

  test('没到上限 ⇒ notNeeded，原样不动', () {
    pgLog.writeAsStringSync('x' * 99);
    expect(rotatePgLogIfLarge(pgLog, nowUtc: t0, maxBytes: 100),
        PgLogRotation.notNeeded);
    expect(names(), <String>['pg.log']);
  });

  test('到上限 ⇒ 改名为 pg.<UTC 时间戳>.log，内容原样', () {
    pgLog.writeAsStringSync('y' * 100);
    expect(rotatePgLogIfLarge(pgLog, nowUtc: t0, maxBytes: 100),
        PgLogRotation.rotated);
    expect(names(), <String>['pg.20261013T093015.log'],
        reason: 'pg.log 被滚走后由 pg_ctl -l 重新创建，不由这里建空文件');
    expect(File(p.join(logs.path, 'pg.20261013T093015.log')).readAsStringSync(),
        'y' * 100);
  });

  test('同一秒内撞名 ⇒ 加 -1 后缀，不覆盖已有历史', () {
    File(p.join(logs.path, 'pg.20261013T093015.log')).writeAsStringSync('old');
    pgLog.writeAsStringSync('z' * 100);

    rotatePgLogIfLarge(pgLog, nowUtc: t0, maxBytes: 100);

    expect(File(p.join(logs.path, 'pg.20261013T093015.log')).readAsStringSync(),
        'old', reason: '已有的那份历史不能被新的一份盖掉');
    expect(File(p.join(logs.path, 'pg.20261013T093015-1.log')).existsSync(),
        isTrue);
  });

  test('只留最新 keep 份历史；按文件名（=时间序）剪，不碰别的日志', () {
    for (final String ts in <String>[
      '20261001T000000',
      '20261002T000000',
      '20261003T000000',
    ]) {
      File(p.join(logs.path, 'pg.$ts.log')).writeAsStringSync('h');
    }
    // 反向护栏：app 自己的日志与诊断用的其它文件，剪枝一个都不许碰。
    File(p.join(logs.path, 'inkframe.log')).writeAsStringSync('app');
    File(p.join(logs.path, 'inkframe.20261001T000000.log'))
        .writeAsStringSync('app-old');
    pgLog.writeAsStringSync('w' * 100);

    rotatePgLogIfLarge(pgLog, nowUtc: t0, maxBytes: 100, keep: 3);

    expect(names(), <String>[
      'inkframe.20261001T000000.log',
      'inkframe.log',
      // 最老的 20261001 被剪掉；新滚出来的那份算在 keep 里。
      'pg.20261002T000000.log',
      'pg.20261003T000000.log',
      'pg.20261013T093015.log',
    ]);
  });
}
