// 共享 ProcessStarter/RunningProcess fake（PR-2 首建；backup/restore 测试共用）。
//
// 语义与 _SystemRunningProcess 对齐（PLAYBOOK §5.4 fake 漂移防线）：
// - 正常路径：stdout 流即刻收尾，exitCode 按配置完成；
// - hang=true：流不收尾、exitCode 不完成——直到 kill()（看门狗超时场景）；
// - kill()：幂等，关流并以 -15 完成 exitCode（进程已收尾则 no-op）。
import 'dart:async';
import 'dart:io';

import 'package:inkframe/core/interfaces/process_runner.dart';

class FakeProcessStarter implements ProcessStarter {
  FakeProcessStarter({
    this.exitCode = 0,
    this.writesOutput = true,
    this.hang = false,
    this.stderrText = '',
    this.order,
    this.orderTag = 'process',
  });

  int exitCode;

  /// 真实 pg_dump 即便非零退出也常已把截断的 -Fc 头写进 -f 目标——writesOutput
  /// 时无论退出码都产出文件，好让「失败清半成品」断言测的是真删除而非空。
  bool writesOutput;

  /// true = 仿真挂死子进程：流不收尾、exitCode 不完成，直到 kill()。
  bool hang;

  String stderrText;

  /// 非 null 时每次 start 往里记一条 [orderTag]（restore 测试的 SQL/进程时序断言）。
  final List<String>? order;
  final String orderTag;

  int calls = 0;
  String? lastExecutable;
  List<String>? lastArgs;
  Map<String, String>? lastEnv;
  FakeStartedProcess? last;

  @override
  Future<RunningProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    calls++;
    lastExecutable = executable;
    lastArgs = List<String>.of(arguments);
    lastEnv = environment;
    order?.add(orderTag);
    if (writesOutput) {
      final fi = arguments.indexOf('-f');
      if (fi >= 0 && fi + 1 < arguments.length) {
        File(arguments[fi + 1]).writeAsStringSync('PGDMP-fake');
      }
    }
    return last = FakeStartedProcess(
      exit: exitCode,
      stderr: stderrText,
      hang: hang,
    );
  }
}

class FakeStartedProcess implements RunningProcess {
  FakeStartedProcess({
    required int exit,
    required String stderr,
    required bool hang,
  })  : _exit = exit,
        _stderr = stderr,
        _hang = hang;

  final int _exit;
  final String _stderr;
  final bool _hang;

  bool killed = false;
  final Completer<int> _exitCompleter = Completer<int>();
  late final StreamController<String> _ctrl =
      StreamController<String>(onListen: _pump);

  Future<void> _pump() async {
    await Future<void>.delayed(Duration.zero);
    if (_hang || _ctrl.isClosed) return; // 挂死：等 kill 收尾。
    await _ctrl.close();
    if (!_exitCompleter.isCompleted) _exitCompleter.complete(_exit);
  }

  @override
  Stream<String> get stdoutLines => _ctrl.stream;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  String get stderrTail => _stderr;

  @override
  void kill() {
    if (killed) return;
    killed = true;
    _ctrl.close();
    if (!_exitCompleter.isCompleted) _exitCompleter.complete(-15);
  }
}
