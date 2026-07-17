// PgController：嵌入式 PostgreSQL 生命周期控制器。
//
// PRD §22.1 职责：
//   - ensureInitialized: 首次启动调用 initdb 初始化 PGDATA
//   - start: 选随机端口 → pg_ctl start → 写 <root>/config/pg.port
//   - stop: pg_ctl stop -m fast，等待 ≤ 5s
//   - 崩溃恢复: 检查 postmaster.pid → 存活则复用，否则清理后重启
//   - isAlive: 轻量探测（端口 + postmaster 进程）
//   - PG 强制绑定 127.0.0.1，不允许 0.0.0.0
//
// 设计选择：
//   - 进程调用抽成 PgProcessRunner 接口，便于 unit 测注入 fake，
//     真 PG 集成测由 test/storage/pg_integration_test.dart（@Tags(['pg'])) 覆盖
//   - 端口分配使用 ServerSocket.bind(port: 0) 让系统挑可用端口，
//     立刻关闭后把该端口传给 pg_ctl；PG 起得快（1-3s）时碰撞概率极低
//   - 不缓存 Connection，PgController 只负责进程与端口，连接由 database provider 按需创建
//
// LB-07（SCRAM）：
//   - 新集群 initdb 走 --auth=scram-sha-256 + --pwfile（trust 已移除）；
//     随机 32 字节密码先入 SecureStorage 再 initdb（反序会产出密码丢失的死集群），
//     pwfile 用后即删（finally 兜底失败路径）
//   - 存量 trust 集群 Zero-BC：无迁移。SecureStorage 无条目 → password=null，
//     trust 集群带 / 不带密码连接均成功，行为不变
//   - SecureStorage 故障（非缺条目）→ LocalIOError 原样上抛（平台实现已翻译），
//     经 pool provider 变成 AsyncError 冒泡到启动门（LB-09）
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../core/constants/secure_storage_keys.dart';
import '../core/interfaces/secure_storage_service.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import 'pg_binary_locator.dart';

/// 嵌入式 PG 超级用户名——initdb 与连接串共用，禁止散落字面量。
const String kPgSuperuser = 'inkframe';

/// 嵌入式 PG 默认库名。
const String kPgDatabaseName = 'postgres';

/// SCRAM 随机密码字节数（base64url 去填充后 43 字符）。
const int kPgPasswordBytes = 32;

/// 生成 initdb 引导密码：加密安全随机源，URL-safe 字符集（pwfile 单行明文安全）。
String generatePgPassword({Random? random}) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(kPgPasswordBytes, (_) => rng.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// 端到端配置结果：给上层 provider 构造 Endpoint。
class PgRuntime {
  const PgRuntime({
    required this.host,
    required this.port,
    required this.dataDir,
    this.password,
  });
  final String host;
  final int port;
  final Directory dataDir;

  /// 超级用户密码。null = SecureStorage 无条目（存量 trust 集群，LB-07 Zero-BC）。
  final String? password;
}

/// 抽象进程执行：单测注入 fake；生产使用 [SystemPgProcessRunner]。
abstract class PgProcessRunner {
  Future<ProcessResult> initdb({
    required File initdbBin,
    required Directory dataDir,
    required File pwFile,
  });

  /// 启动 postgres，返回 true 代表 pg_ctl 退出码 0。
  Future<ProcessResult> pgCtlStart({
    required File pgCtlBin,
    required Directory dataDir,
    required int port,
    required File logFile,
  });

  Future<ProcessResult> pgCtlStop({
    required File pgCtlBin,
    required Directory dataDir,
  });

  /// 判定给定 PID 是否仍在运行。
  bool isProcessAlive(int pid);
}

class SystemPgProcessRunner implements PgProcessRunner {
  const SystemPgProcessRunner();

  /// initdb 参数构造（LB-07）：SCRAM-SHA-256 + pwfile，trust 已移除。
  /// 抽成 static 纯函数供单测直接断言参数面。
  static List<String> initdbArgs({
    required Directory dataDir,
    required File pwFile,
  }) {
    return <String>[
      '-D', dataDir.path,
      '-U', kPgSuperuser,
      '--auth=scram-sha-256',
      '--pwfile=${pwFile.path}',
      '-E', 'UTF8',
      '--locale=C',
    ];
  }

  @override
  Future<ProcessResult> initdb({
    required File initdbBin,
    required Directory dataDir,
    required File pwFile,
  }) {
    return Process.run(
      initdbBin.path,
      initdbArgs(dataDir: dataDir, pwFile: pwFile),
    );
  }

  @override
  Future<ProcessResult> pgCtlStart({
    required File pgCtlBin,
    required Directory dataDir,
    required int port,
    required File logFile,
  }) {
    // -o 传 postgres 参数：监听 127.0.0.1，避免 unix socket 目录依赖
    final opts = '-c listen_addresses=127.0.0.1 '
        '-c unix_socket_directories= '
        '-c port=$port';
    return Process.run(pgCtlBin.path, <String>[
      '-D', dataDir.path,
      '-l', logFile.path,
      '-o', opts,
      '-w', // 等起起来
      '-t', '30', // 30s 超时
      'start',
    ]);
  }

  @override
  Future<ProcessResult> pgCtlStop({
    required File pgCtlBin,
    required Directory dataDir,
  }) {
    return Process.run(pgCtlBin.path, <String>[
      '-D', dataDir.path,
      '-m', 'fast',
      '-w',
      '-t', '10',
      'stop',
    ]);
  }

  @override
  bool isProcessAlive(int pid) {
    if (pid <= 0) return false;
    try {
      // 0 信号不真正发送，只探测存在性；Windows 下 Process.killPid 无法仅探测，改走 tasklist。
      if (Platform.isWindows) {
        final result = Process.runSync('tasklist', <String>[
          '/FI',
          'PID eq $pid',
          '/NH',
        ]);
        final out = (result.stdout as String).trim();
        return out.isNotEmpty && out.contains('$pid');
      }
      return Process.killPid(pid, ProcessSignal.sigcont);
    } on ProcessException {
      return false;
    }
  }
}

/// PgController 生命周期错误。
class PgLifecycleError extends StateError {
  PgLifecycleError(super.message);
}

/// 控制器主体——app-scoped。
class PgController {
  PgController({
    required AppPaths paths,
    required PgBinaryLocator locator,
    required SecureStorageService secureStorage,
    PgProcessRunner runner = const SystemPgProcessRunner(),
    Future<int> Function()? portPicker,
    LoggerService? logger,
  })  : _paths = paths,
        _locator = locator,
        _secureStorage = secureStorage,
        _runner = runner,
        _portPicker = portPicker ?? _defaultPortPicker,
        _logger = logger;

  final AppPaths _paths;
  final PgBinaryLocator _locator;
  final SecureStorageService _secureStorage;
  final PgProcessRunner _runner;
  final Future<int> Function() _portPicker;
  final LoggerService? _logger;

  static const String _logModule = 'storage.pg';

  PgRuntime? _runtime;
  PgRuntime? get runtime => _runtime;

  /// `<root>/database/`
  Directory get dataDir => _paths.database;

  /// `<root>/config/pg.port`
  File get portFile => File(p.join(_paths.config.path, 'pg.port'));

  /// `<root>/logs/pg.log`
  File get logFile => File(p.join(_paths.logs.path, 'pg.log'));

  File get _postmasterPid => File(p.join(dataDir.path, 'postmaster.pid'));

  bool get _isInitialized =>
      File(p.join(dataDir.path, 'PG_VERSION')).existsSync();

  /// 首次启动：确保 PGDATA 已 initdb（SCRAM-SHA-256），幂等。
  ///
  /// 密码生命周期（LB-07）：
  ///   生成 32 字节随机密码 → 先入 SecureStorage（initdb 失败重试会覆盖；
  ///   反序则可能产出密码未持久化的 SCRAM 集群 = 死库）→ 写临时 pwfile →
  ///   initdb --pwfile → finally 删 pwfile（含失败路径）。
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    // 目录已存在但非空（非 PG 数据目录）→ 拒绝。
    if (dataDir.existsSync()) {
      final entries = dataDir.listSync();
      if (entries.isNotEmpty) {
        throw PgLifecycleError(
          'PGDATA directory ${dataDir.path} is non-empty but lacks PG_VERSION; '
          'refusing to overwrite. Clean it manually before retrying.',
        );
      }
    } else {
      dataDir.createSync(recursive: true);
    }

    final binLocation = _locator.locate();

    // 密码先持久化：SecureStorage 故障（LocalIOError）在 initdb 前上抛，零残留。
    final password = generatePgPassword();
    await _secureStorage.store(SecureStorageKeys.databasePassword, password);

    final pwFile = File(p.join(_paths.config.path, 'pg.pwfile.tmp'));
    if (!pwFile.parent.existsSync()) {
      pwFile.parent.createSync(recursive: true);
    }
    pwFile.writeAsStringSync(password, flush: true);
    _restrictToOwner(pwFile);

    _logger?.info(_logModule, 'initdb start (auth=scram-sha-256)');
    try {
      final result = await _runner.initdb(
        initdbBin: binLocation.initdb,
        dataDir: dataDir,
        pwFile: pwFile,
      );
      if (result.exitCode != 0) {
        _logger?.error(_logModule, 'initdb failed',
            extra: {'exit_code': result.exitCode});
        throw PgLifecycleError(
          'initdb failed (exit ${result.exitCode}): ${result.stderr}',
        );
      }
    } finally {
      // 明文密码文件绝不落盘超过 initdb 存活期。
      if (pwFile.existsSync()) {
        pwFile.deleteSync();
      }
    }
    _logger?.info(_logModule, 'initdb done');
  }

  /// pwfile 收紧为 600（POSIX）。Windows 用户目录 ACL 默认仅本人可读，跳过。
  void _restrictToOwner(File file) {
    if (Platform.isWindows) return;
    try {
      Process.runSync('chmod', <String>['600', file.path]);
    } on ProcessException {
      _logger?.warn(_logModule, 'chmod 600 on pwfile failed; continuing');
    }
  }

  /// 取存储密码：无条目 = 存量 trust 集群（Zero-BC，无迁移）→ null；
  /// storage 故障 → LocalIOError 原样上抛（平台实现已在边界翻译为 InkError）。
  Future<String?> _readStoredPassword() async {
    final password =
        await _secureStorage.retrieve(SecureStorageKeys.databasePassword);
    if (password == null) {
      _logger?.info(_logModule,
          'no stored database password; assuming legacy trust cluster');
    }
    return password;
  }

  /// start 单飞 memo（LB-22 评审 P1-1）：还原流程与池重建可能并发调 start——
  /// 双 pg_ctl start 会竞速 postmaster 锁。在飞的调用共享同一 future；
  /// 完成即清（含失败），失败后可重试。
  Future<PgRuntime>? _startInflight;

  /// 启动：存活复用 / 崩溃恢复 + pg_ctl start；写端口文件；返回 runtime（携密码）。
  /// 并发调用单飞——同一时刻只放行一个真实启动流程。
  Future<PgRuntime> start() {
    return _startInflight ??=
        _doStart().whenComplete(() => _startInflight = null);
  }

  Future<PgRuntime> _doStart() async {
    await ensureInitialized();
    final password = await _readStoredPassword();

    // 上次会话遗留的存活实例（如非正常退出）→ 直接复用其端口，禁止二次启动。
    final reused = _reuseAliveInstanceOrCleanStale(password);
    if (reused != null) {
      portFile.writeAsStringSync('${reused.port}\n');
      _runtime = reused;
      return reused;
    }

    final binLocation = _locator.locate();
    final port = await _portPicker();

    // 确保 logs 目录存在
    if (!_paths.logs.existsSync()) {
      _paths.logs.createSync(recursive: true);
    }
    if (!_paths.config.existsSync()) {
      _paths.config.createSync(recursive: true);
    }

    final result = await _runner.pgCtlStart(
      pgCtlBin: binLocation.pgCtl,
      dataDir: dataDir,
      port: port,
      logFile: logFile,
    );
    if (result.exitCode != 0) {
      _logger?.error(_logModule, 'pg_ctl start failed',
          extra: {'exit_code': result.exitCode, 'port': port});
      throw PgLifecycleError(
        'pg_ctl start failed (exit ${result.exitCode}): ${result.stderr}',
      );
    }

    portFile.writeAsStringSync('$port\n');
    _runtime = PgRuntime(
      host: '127.0.0.1',
      port: port,
      dataDir: dataDir,
      password: password,
    );
    _logger?.info(_logModule, 'postgres started', extra: {'port': port});
    return _runtime!;
  }

  /// postmaster.pid 处理：
  ///   - 进程仍活 → 解析 pid 文件第 4 行端口并复用（PGDATA 为本应用独占，
  ///     存活实例只可能是上次会话的孤儿 PG）；
  ///   - 进程已死 → 删 stale pid 文件，返回 null 走正常 pg_ctl start。
  PgRuntime? _reuseAliveInstanceOrCleanStale(String? password) {
    if (!_postmasterPid.existsSync()) return null;
    final lines = _postmasterPid.readAsLinesSync();
    if (lines.isEmpty) {
      _postmasterPid.deleteSync();
      return null;
    }
    final pid = int.tryParse(lines.first.trim()) ?? -1;
    if (!_runner.isProcessAlive(pid)) {
      _logger?.warn(_logModule, 'stale postmaster.pid removed (crash recovery)',
          extra: {'pid': pid});
      _postmasterPid.deleteSync();
      return null;
    }
    // postmaster.pid 格式：pid / datadir / start-time / port / socket-dir / ...
    final port = lines.length >= 4 ? int.tryParse(lines[3].trim()) : null;
    if (port == null || port <= 0) {
      _logger?.error(_logModule, 'live postmaster without parsable port',
          extra: {'pid': pid});
      throw PgLifecycleError(
        'A postgres instance (pid=$pid) is alive against ${dataDir.path} '
        'but its postmaster.pid lacks a parsable port; cannot reuse it.',
      );
    }
    _logger?.info(_logModule, 'live postmaster detected; reusing instance',
        extra: {'pid': pid, 'port': port});
    return PgRuntime(
      host: '127.0.0.1',
      port: port,
      dataDir: dataDir,
      password: password,
    );
  }

  /// 停止 PG，幂等：未启动时 no-op。
  Future<void> stop() async {
    if (!_postmasterPid.existsSync()) {
      _runtime = null;
      return;
    }
    final binLocation = _locator.locate();
    final result = await _runner.pgCtlStop(
      pgCtlBin: binLocation.pgCtl,
      dataDir: dataDir,
    );
    if (result.exitCode != 0) {
      _logger?.error(_logModule, 'pg_ctl stop failed',
          extra: {'exit_code': result.exitCode});
      throw PgLifecycleError(
        'pg_ctl stop failed (exit ${result.exitCode}): ${result.stderr}',
      );
    }
    _runtime = null;
    _logger?.info(_logModule, 'postgres stopped');
  }

  /// 轻量探测：postmaster.pid 存在 + pid 进程活着。
  bool isAlive() {
    if (!_postmasterPid.existsSync()) return false;
    final lines = _postmasterPid.readAsLinesSync();
    if (lines.isEmpty) return false;
    final pid = int.tryParse(lines.first.trim()) ?? -1;
    return _runner.isProcessAlive(pid);
  }
}

/// 端口分配：绑定 0 → OS 派端口 → close 释放。
Future<int> _defaultPortPicker() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
