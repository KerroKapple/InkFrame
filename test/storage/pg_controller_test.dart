// PgController 单测：注入 fake PgProcessRunner 驱动状态机。
// 真 PG 集成测见 pg_integration_test.dart（@Tags(['pg'])）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PgController', () {
    late Directory tempRoot;
    late AppPaths paths;
    late _FakeRunner runner;
    late PgBinaryLocator locator;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('pg_ctrl_');
      final binDir = Directory(p.join(tempRoot.path, 'pgbin'))
        ..createSync(recursive: true);
      final postgresBin = File(p.join(binDir.path, _exe('postgres')));
      postgresBin.createSync();
      File(p.join(binDir.path, _exe('initdb'))).createSync();
      File(p.join(binDir.path, _exe('pg_ctl'))).createSync();

      paths = DefaultAppPaths.forRoot(tempRoot);
      await paths.ensureInitialized();

      locator = _StubLocator(
        PgBinaryLocation(
          binDir: binDir,
          libDir: Directory(p.join(binDir.path, '..', 'lib')),
        ),
      );
      runner = _FakeRunner();
    });

    tearDown(() async {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('ensureInitialized 首次调用触发 initdb，写 PG_VERSION 后幂等', () async {
      final ctl = PgController(paths: paths, locator: locator, runner: runner);
      await ctl.ensureInitialized();
      expect(runner.initdbCalls, 1);

      // 模拟 initdb 生成 PG_VERSION
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      await ctl.ensureInitialized();
      expect(runner.initdbCalls, 1, reason: '已初始化应幂等');
    });

    test('ensureInitialized 发现非空非 PG 目录拒绝覆盖', () async {
      File(p.join(paths.database.path, 'random.txt')).writeAsStringSync('hi');
      final ctl = PgController(paths: paths, locator: locator, runner: runner);
      await expectLater(ctl.ensureInitialized, throwsA(isA<PgLifecycleError>()));
    });

    test('start 写 pg.port 并返回 runtime', () async {
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      final ctl = PgController(
        paths: paths,
        locator: locator,
        runner: runner,
        portPicker: () async => 54321,
      );
      // 模拟 pg_ctl start 成功：runner 写 postmaster.pid
      runner.onPgCtlStart = () {
        File(p.join(paths.database.path, 'postmaster.pid'))
            .writeAsStringSync('9999\n');
      };

      final rt = await ctl.start();
      expect(rt.port, 54321);
      expect(rt.host, '127.0.0.1');
      expect(ctl.portFile.readAsStringSync().trim(), '54321');
    });

    test('崩溃恢复：postmaster.pid 存在但进程已死 → 删 pid 文件后成功启动', () async {
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      File(p.join(paths.database.path, 'postmaster.pid'))
          .writeAsStringSync('12345\n');
      runner.aliveForPid = <int>{};

      final ctl = PgController(
        paths: paths,
        locator: locator,
        runner: runner,
        portPicker: () async => 7000,
      );
      runner.onPgCtlStart = () {
        File(p.join(paths.database.path, 'postmaster.pid'))
            .writeAsStringSync('777\n');
      };

      await ctl.start();
      expect(runner.pgCtlStartCalls, 1);
    });

    test('二次启动：postmaster 进程仍活 → 复用其端口，不再 pg_ctl start', () async {
      // 模拟上次会话未清理的存活 PG（CR-02 场景）。
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      File(p.join(paths.database.path, 'postmaster.pid')).writeAsStringSync(
        '12345\n${paths.database.path}\n1718000000\n54399\n\'\'\n127.0.0.1\n  1 2\nready\n',
      );
      runner.aliveForPid = <int>{12345};

      final ctl = PgController(paths: paths, locator: locator, runner: runner);
      final rt = await ctl.start();
      expect(rt.port, 54399);
      expect(rt.host, '127.0.0.1');
      expect(runner.pgCtlStartCalls, 0, reason: '存活实例必须复用，不得重复启动');
      expect(ctl.portFile.readAsStringSync().trim(), '54399');
      expect(ctl.runtime, isNotNull);
    });

    test('存活实例但 postmaster.pid 无法解析端口 → PgLifecycleError', () async {
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      File(p.join(paths.database.path, 'postmaster.pid'))
          .writeAsStringSync('12345\n');
      runner.aliveForPid = <int>{12345};

      final ctl = PgController(paths: paths, locator: locator, runner: runner);
      await expectLater(ctl.start, throwsA(isA<PgLifecycleError>()));
      expect(runner.pgCtlStartCalls, 0);
    });

    test('stop 幂等：未启动时 no-op', () async {
      final ctl = PgController(paths: paths, locator: locator, runner: runner);
      await ctl.stop();
      expect(runner.pgCtlStopCalls, 0);
    });

    test('stop 调用 pg_ctl 并清空 runtime', () async {
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      File(p.join(paths.database.path, 'postmaster.pid'))
          .writeAsStringSync('999\n');
      final ctl = PgController(paths: paths, locator: locator, runner: runner);
      await ctl.stop();
      expect(runner.pgCtlStopCalls, 1);
      expect(ctl.runtime, isNull);
    });

    test('isAlive 根据 pid 文件 + 进程存活判定', () async {
      final ctl = PgController(paths: paths, locator: locator, runner: runner);
      expect(ctl.isAlive(), isFalse);

      File(p.join(paths.database.path, 'postmaster.pid'))
          .writeAsStringSync('4321\n');
      runner.aliveForPid = <int>{4321};
      expect(ctl.isAlive(), isTrue);

      runner.aliveForPid = <int>{};
      expect(ctl.isAlive(), isFalse);
    });
  });
}

String _exe(String name) => Platform.isWindows ? '$name.exe' : name;

class _StubLocator implements PgBinaryLocator {
  _StubLocator(this.loc);
  final PgBinaryLocation loc;
  @override
  PgBinaryLocation locate() => loc;
}

class _FakeRunner implements PgProcessRunner {
  int initdbCalls = 0;
  int pgCtlStartCalls = 0;
  int pgCtlStopCalls = 0;
  Set<int> aliveForPid = <int>{};
  void Function()? onPgCtlStart;

  @override
  Future<ProcessResult> initdb({
    required File initdbBin,
    required Directory dataDir,
  }) async {
    initdbCalls += 1;
    // 模拟 initdb 写 PG_VERSION
    File(p.join(dataDir.path, 'PG_VERSION')).writeAsStringSync('17');
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<ProcessResult> pgCtlStart({
    required File pgCtlBin,
    required Directory dataDir,
    required int port,
    required File logFile,
  }) async {
    pgCtlStartCalls += 1;
    onPgCtlStart?.call();
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<ProcessResult> pgCtlStop({
    required File pgCtlBin,
    required Directory dataDir,
  }) async {
    pgCtlStopCalls += 1;
    return ProcessResult(0, 0, '', '');
  }

  @override
  bool isProcessAlive(int pid) => aliveForPid.contains(pid);
}
