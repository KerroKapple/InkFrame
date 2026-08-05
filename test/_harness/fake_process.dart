// 共享 ProcessStarter/RunningProcess fake（PR-2 首建；backup/restore/watchdog 测试共用）。
//
// 语义与 _SystemRunningProcess 对齐（PLAYBOOK §5.4 fake 漂移防线，契约测试见
// fake_process_test.dart）：
// - exitCode 的完成**不依赖** stdout 被订阅（真进程如此；评审 P2-6）；
// - 正常路径：流即刻收尾，exitCode 在 exitDelay 后按配置完成；
// - hang=true：流不收尾、exitCode 不完成——直到 kill()；
// - kill()：幂等；killCompletesExit=false 仿真「kill 无效 / 进程已自然退出」
//   （EX-3 fake 同名旋钮，迟到取消与硬截止场景）。
import 'dart:async';
import 'dart:io';

import 'package:inkframe/core/interfaces/process_runner.dart';

class FakeProcessStarter implements ProcessStarter {
  FakeProcessStarter({
    this.exitCode = 0,
    this.writesOutput = true,
    this.hang = false,
    this.stderrText = '',
    this.throwOnStart = false,
    this.killCompletesExit = true,
    this.exitDelay = Duration.zero,
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

  /// 仿真可执行文件不可启动（ProcessException 透传契约）。
  bool throwOnStart;

  /// false = kill 只记账不收尾（kill 无效 / 进程已自然退出的竞态）。
  bool killCompletesExit;

  /// 正常路径 exitCode 的完成延迟（仿真「timeout 已过、进程稍后 exit 0」）。
  Duration exitDelay;

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
    if (throwOnStart) {
      throw ProcessException(executable, arguments, 'spawn failed', 2);
    }
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
      killCompletesExit: killCompletesExit,
      exitDelay: exitDelay,
    );
  }
}

class FakeStartedProcess implements RunningProcess {
  FakeStartedProcess({
    required int exit,
    required String stderr,
    required bool hang,
    this.killCompletesExit = true,
    Duration exitDelay = Duration.zero,
  })  : _exit = exit,
        _stderr = stderr,
        _hang = hang,
        _exitDelay = exitDelay {
    // exitCode 独立于 stdout 订阅完成（真进程语义；评审 P2-6）。
    scheduleMicrotask(_run);
  }

  final int _exit;
  final String _stderr;
  final bool _hang;
  final Duration _exitDelay;
  final bool killCompletesExit;

  bool killed = false;
  final Completer<int> _exitCompleter = Completer<int>();
  final StreamController<String> _ctrl = StreamController<String>();

  Future<void> _run() async {
    await Future<void>.delayed(Duration.zero);
    if (_hang) return; // 挂死：等 kill（或永不）收尾。
    if (_exitDelay > Duration.zero) {
      await Future<void>.delayed(_exitDelay);
    }
    // 不 await close：single-subscription 流的 done future 只在被监听时
    // 投递,await 会让「无人订阅 stdout」的场景卡死 _run。
    if (!_ctrl.isClosed) unawaited(_ctrl.close());
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
    if (!killCompletesExit) return;
    _ctrl.close();
    if (!_exitCompleter.isCompleted) _exitCompleter.complete(-15);
  }
}
