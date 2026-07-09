// PgController 单测：注入 fake PgProcessRunner 驱动状态机。
// 真 PG 集成测见 pg_scram_integration_test.dart（@Tags(['pg'])）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:path/path.dart' as p;

import '../_harness/fake_secure_storage.dart';
import '../helpers/recording_logger.dart';

void main() {
  group('PgController', () {
    late Directory tempRoot;
    late AppPaths paths;
    late _FakeRunner runner;
    late PgBinaryLocator locator;
    late FakeSecureStorage storage;

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
      storage = FakeSecureStorage();
    });

    tearDown(() async {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    PgController buildController({
      Future<int> Function()? portPicker,
      LoggerService? logger,
      FakeSecureStorage? secureStorage,
    }) {
      return PgController(
        paths: paths,
        locator: locator,
        runner: runner,
        secureStorage: secureStorage ?? storage,
        portPicker: portPicker,
        logger: logger,
      );
    }

    test('ensureInitialized 首次调用触发 initdb，写 PG_VERSION 后幂等', () async {
      final ctl = buildController();
      await ctl.ensureInitialized();
      expect(runner.initdbCalls, 1);

      // 模拟 initdb 生成 PG_VERSION
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      await ctl.ensureInitialized();
      expect(runner.initdbCalls, 1, reason: '已初始化应幂等');
    });

    test('ensureInitialized 发现非空非 PG 目录拒绝覆盖', () async {
      File(p.join(paths.database.path, 'random.txt')).writeAsStringSync('hi');
      final ctl = buildController();
      await expectLater(ctl.ensureInitialized, throwsA(isA<PgLifecycleError>()));
    });

    test('start 写 pg.port 并返回 runtime', () async {
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      final ctl = buildController(portPicker: () async => 54321);
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

      final ctl = buildController(portPicker: () async => 7000);
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

      final ctl = buildController();
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

      final ctl = buildController();
      await expectLater(ctl.start, throwsA(isA<PgLifecycleError>()));
      expect(runner.pgCtlStartCalls, 0);
    });

    test('stop 幂等：未启动时 no-op', () async {
      final ctl = buildController();
      await ctl.stop();
      expect(runner.pgCtlStopCalls, 0);
    });

    test('stop 调用 pg_ctl 并清空 runtime', () async {
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      File(p.join(paths.database.path, 'postmaster.pid'))
          .writeAsStringSync('999\n');
      final ctl = buildController();
      await ctl.stop();
      expect(runner.pgCtlStopCalls, 1);
      expect(ctl.runtime, isNull);
    });

    test('logger 注入点（FIX-016 / ME-21）：start / 崩溃恢复 / stop 落日志', () async {
      final log = RecordingLogger();
      File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
      // 崩溃残留：pid 已死。
      File(p.join(paths.database.path, 'postmaster.pid'))
          .writeAsStringSync('12345\n');
      runner.aliveForPid = <int>{};

      final ctl = buildController(portPicker: () async => 7100, logger: log);
      runner.onPgCtlStart = () {
        File(p.join(paths.database.path, 'postmaster.pid'))
            .writeAsStringSync('777\n');
      };

      await ctl.start();
      await ctl.stop();

      final modules = log.byModule('storage.pg');
      expect(modules, isNotEmpty);
      // 崩溃恢复必须留 WARN 痕迹。
      expect(
        log.byLevel(InkLogLevel.warn).where((r) => r.module == 'storage.pg'),
        isNotEmpty,
      );
      // 启动成功 INFO 带端口。
      expect(
        log
            .byLevel(InkLogLevel.info)
            .where((r) => r.extra?['port'] == 7100),
        isNotEmpty,
      );
    });

    test('isAlive 根据 pid 文件 + 进程存活判定', () async {
      final ctl = buildController();
      expect(ctl.isAlive(), isFalse);

      File(p.join(paths.database.path, 'postmaster.pid'))
          .writeAsStringSync('4321\n');
      runner.aliveForPid = <int>{4321};
      expect(ctl.isAlive(), isTrue);

      runner.aliveForPid = <int>{};
      expect(ctl.isAlive(), isFalse);
    });

    // ── LB-07：trust → SCRAM-SHA-256 ────────────────────────────────────────

    group('SCRAM（LB-07）', () {
      test('ensureInitialized：随机密码入 SecureStorage，pwfile 在 initdb 时存在且一致，事后删除',
          () async {
        final ctl = buildController();
        await ctl.ensureInitialized();

        final stored = storage.snapshot[SecureStorageKeys.databasePassword];
        expect(stored, isNotNull, reason: '密码必须持久化到 SecureStorage');
        expect(stored!.length, greaterThanOrEqualTo(43),
            reason: '32 字节随机密码 base64url 编码后至少 43 字符');

        expect(runner.pwFileExistedAtCall, isTrue,
            reason: 'initdb 执行时 pwfile 必须存在');
        expect(runner.pwFileContentAtCall!.trim(), stored,
            reason: 'pwfile 内容必须与入库密码一致');
        expect(runner.lastPwFile!.existsSync(), isFalse,
            reason: 'initdb 结束后 pwfile 必须删除');
      });

      test('密码先入 SecureStorage 再 initdb：store 失败 → LocalIOError 上抛且 initdb 不执行',
          () async {
        final ctl = buildController(secureStorage: _StoreThrowingStorage());
        await expectLater(ctl.ensureInitialized, throwsA(isA<LocalIOError>()));
        expect(runner.initdbCalls, 0,
            reason: '密码未持久化成功前禁止 initdb——否则产出密码丢失的 SCRAM 集群');
      });

      test('initdb 失败：pwfile 仍被删除（finally），重试生成新密码覆盖旧条目', () async {
        runner.failInitdb = true;
        final ctl = buildController();
        await expectLater(
            ctl.ensureInitialized, throwsA(isA<PgLifecycleError>()));
        expect(runner.lastPwFile!.existsSync(), isFalse,
            reason: '失败路径 pwfile 也必须删除');
        final first = storage.snapshot[SecureStorageKeys.databasePassword];
        expect(first, isNotNull);

        runner.failInitdb = false;
        await ctl.ensureInitialized();
        final second = storage.snapshot[SecureStorageKeys.databasePassword];
        expect(second, isNot(first), reason: '重试必须生成新密码并覆盖');
      });

      test('已初始化集群：幂等，不重新生成/覆盖密码', () async {
        File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
        storage = FakeSecureStorage(
            {SecureStorageKeys.databasePassword: 'existing-pw'});
        final ctl = buildController();
        await ctl.ensureInitialized();
        expect(runner.initdbCalls, 0);
        expect(
            storage.snapshot[SecureStorageKeys.databasePassword], 'existing-pw');
      });

      test('start：runtime.password 取自 SecureStorage', () async {
        File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
        storage =
            FakeSecureStorage({SecureStorageKeys.databasePassword: 'sekret'});
        final ctl = buildController(portPicker: () async => 5501);
        runner.onPgCtlStart = () {
          File(p.join(paths.database.path, 'postmaster.pid'))
              .writeAsStringSync('9999\n');
        };
        final rt = await ctl.start();
        expect(rt.password, 'sekret');
      });

      test('start：无密码条目（存量 trust 集群）→ password 为 null 照常启动', () async {
        File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
        final ctl = buildController(portPicker: () async => 5502);
        runner.onPgCtlStart = () {
          File(p.join(paths.database.path, 'postmaster.pid'))
              .writeAsStringSync('9999\n');
        };
        final rt = await ctl.start();
        expect(rt.password, isNull);
        expect(runner.pgCtlStartCalls, 1, reason: '存量 trust 集群必须照常启动');
      });

      test('start：复用存活实例路径同样携带密码', () async {
        File(p.join(paths.database.path, 'PG_VERSION')).writeAsStringSync('17');
        File(p.join(paths.database.path, 'postmaster.pid')).writeAsStringSync(
          '12345\n${paths.database.path}\n1718000000\n54399\n\'\'\n127.0.0.1\n  1 2\nready\n',
        );
        runner.aliveForPid = <int>{12345};
        storage =
            FakeSecureStorage({SecureStorageKeys.databasePassword: 'sekret'});
        final ctl = buildController();
        final rt = await ctl.start();
        expect(rt.port, 54399);
        expect(rt.password, 'sekret');
        expect(runner.pgCtlStartCalls, 0);
      });
    });
  });

  group('generatePgPassword', () {
    test('43 字符、URL-safe 字符集、无 base64 填充', () {
      final pw = generatePgPassword();
      expect(pw.length, 43, reason: '32 字节 → base64url 去填充 = 43 字符');
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(pw), isTrue,
          reason: 'pwfile 单行明文，禁止空白/填充字符');
    });

    test('抽样 100 次无重复', () {
      final seen = <String>{for (var i = 0; i < 100; i++) generatePgPassword()};
      expect(seen.length, 100);
    });
  });

  group('SystemPgProcessRunner.initdbArgs', () {
    test('SCRAM 参数齐备，trust 彻底移除', () {
      final dataDir = Directory(p.join('some', 'data'));
      final pwFile = File(p.join('some', 'pwfile'));
      final args =
          SystemPgProcessRunner.initdbArgs(dataDir: dataDir, pwFile: pwFile);

      expect(args, contains('--auth=scram-sha-256'));
      expect(args, contains('--pwfile=${pwFile.path}'));
      expect(args, isNot(contains('-A')));
      expect(args.where((a) => a.contains('trust')), isEmpty);
      expect(args, containsAllInOrder(<String>['-D', dataDir.path]));
      expect(args, containsAllInOrder(<String>['-U', kPgSuperuser]));
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

/// store 必炸的 SecureStorage——验证「先持久化密码再 initdb」的失败路径。
class _StoreThrowingStorage extends FakeSecureStorage {
  @override
  Future<void> store(String key, String value) async {
    throw LocalIOError(extra: <String, Object?>{'op': 'store', 'key': key});
  }
}

class _FakeRunner implements PgProcessRunner {
  int initdbCalls = 0;
  int pgCtlStartCalls = 0;
  int pgCtlStopCalls = 0;
  Set<int> aliveForPid = <int>{};
  void Function()? onPgCtlStart;

  /// LB-07 捕获：pwfile 生命周期断言用。
  File? lastPwFile;
  bool pwFileExistedAtCall = false;
  String? pwFileContentAtCall;
  bool failInitdb = false;

  @override
  Future<ProcessResult> initdb({
    required File initdbBin,
    required Directory dataDir,
    required File pwFile,
  }) async {
    initdbCalls += 1;
    lastPwFile = pwFile;
    pwFileExistedAtCall = pwFile.existsSync();
    pwFileContentAtCall =
        pwFileExistedAtCall ? pwFile.readAsStringSync() : null;
    if (failInitdb) {
      return ProcessResult(0, 1, '', 'initdb exploded');
    }
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
