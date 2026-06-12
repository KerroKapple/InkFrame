// PgController：嵌入式 PostgreSQL 生命周期控制器。
//
// PRD §22.1 职责：
//   - ensureInitialized: 首次启动调用 initdb 初始化 PGDATA
//   - start: 选随机端口 → pg_ctl start → 写 ~/InkFrame/config/pg.port
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
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import 'pg_binary_locator.dart';

/// 端到端配置结果：给上层 provider 构造 Endpoint。
class PgRuntime {
  const PgRuntime({
    required this.host,
    required this.port,
    required this.dataDir,
  });
  final String host;
  final int port;
  final Directory dataDir;
}

/// 抽象进程执行：单测注入 fake；生产使用 [SystemPgProcessRunner]。
abstract class PgProcessRunner {
  Future<ProcessResult> initdb({
    required File initdbBin,
    required Directory dataDir,
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

  @override
  Future<ProcessResult> initdb({
    required File initdbBin,
    required Directory dataDir,
  }) {
    // -U inkframe: 超级用户名；--auth=trust: 本地 127.0.0.1 + socket 均信任；-E UTF8
    return Process.run(initdbBin.path, <String>[
      '-D', dataDir.path,
      '-U', 'inkframe',
      '-A', 'trust',
      '-E', 'UTF8',
      '--locale=C',
    ]);
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
    PgProcessRunner runner = const SystemPgProcessRunner(),
    Future<int> Function()? portPicker,
    LoggerService? logger,
  })  : _paths = paths,
        _locator = locator,
        _runner = runner,
        _portPicker = portPicker ?? _defaultPortPicker,
        _logger = logger;

  final AppPaths _paths;
  final PgBinaryLocator _locator;
  final PgProcessRunner _runner;
  final Future<int> Function() _portPicker;
  final LoggerService? _logger;

  static const String _logModule = 'storage.pg';

  PgRuntime? _runtime;
  PgRuntime? get runtime => _runtime;

  /// `~/InkFrame/database/`
  Directory get dataDir => _paths.database;

  /// `~/InkFrame/config/pg.port`
  File get portFile => File(p.join(_paths.config.path, 'pg.port'));

  /// `~/InkFrame/logs/pg.log`
  File get logFile => File(p.join(_paths.logs.path, 'pg.log'));

  File get _postmasterPid => File(p.join(dataDir.path, 'postmaster.pid'));

  bool get _isInitialized =>
      File(p.join(dataDir.path, 'PG_VERSION')).existsSync();

  /// 首次启动：确保 PGDATA 已 initdb，幂等。
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
    _logger?.info(_logModule, 'initdb start');
    final result = await _runner.initdb(
      initdbBin: binLocation.initdb,
      dataDir: dataDir,
    );
    if (result.exitCode != 0) {
      _logger?.error(_logModule, 'initdb failed',
          extra: {'exit_code': result.exitCode});
      throw PgLifecycleError(
        'initdb failed (exit ${result.exitCode}): ${result.stderr}',
      );
    }
    _logger?.info(_logModule, 'initdb done');
  }

  /// 启动：崩溃恢复 + pg_ctl start；写端口文件；返回 runtime。
  Future<PgRuntime> start() async {
    await ensureInitialized();
    await _recoverStaleLock();

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
    _runtime = PgRuntime(host: '127.0.0.1', port: port, dataDir: dataDir);
    _logger?.info(_logModule, 'postgres started', extra: {'port': port});
    return _runtime!;
  }

  /// 崩溃恢复：postmaster.pid 存在但进程已死 → 删 pid 文件。
  Future<void> _recoverStaleLock() async {
    if (!_postmasterPid.existsSync()) return;
    final lines = _postmasterPid.readAsLinesSync();
    if (lines.isEmpty) {
      _postmasterPid.deleteSync();
      return;
    }
    final pid = int.tryParse(lines.first.trim()) ?? -1;
    if (_runner.isProcessAlive(pid)) {
      // 进程仍在：可能是其他实例，拒绝抢占。
      _logger?.error(_logModule, 'live postmaster detected; refusing start',
          extra: {'pid': pid});
      throw PgLifecycleError(
        'Another postgres instance (pid=$pid) is already running against '
        '${dataDir.path}. Refusing to start to avoid data corruption.',
      );
    }
    _logger?.warn(_logModule, 'stale postmaster.pid removed (crash recovery)',
        extra: {'pid': pid});
    _postmasterPid.deleteSync();
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
