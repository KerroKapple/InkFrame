// runWithWatchdog 单测（评审 P2-5）：正常透传 / 超时 kill / exit0 优先语义供
// 调用方判定 / kill 无效硬截止 / 流异常留证 / ProcessException 透传。
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/process_runner.dart';
import 'package:inkframe/services/process_watchdog.dart';

import '../_harness/fake_process.dart';

void main() {
  test('正常路径：exitCode/stderrTail 透传，timedOut=false', () async {
    final starter = FakeProcessStarter(
      exitCode: 3,
      writesOutput: false,
      stderrText: 'warning: something',
    );

    final r = await runWithWatchdog(
      starter, 'tool', const <String>['-x'],
      timeout: const Duration(seconds: 5),
    );

    expect(r.exitCode, 3);
    expect(r.stderrTail, 'warning: something');
    expect(r.timedOut, isFalse);
    expect(r.streamError, isNull);
    expect(starter.last!.killed, isFalse);
  });

  test('挂死 → 超时 kill → timedOut=true，exitCode=-15', () async {
    final starter = FakeProcessStarter(hang: true, writesOutput: false);

    final r = await runWithWatchdog(
      starter, 'tool', const <String>[],
      timeout: const Duration(milliseconds: 40),
    );

    expect(r.timedOut, isTrue);
    expect(r.exitCode, -15);
    expect(starter.last!.killed, isTrue);
  });

  test('kill 迟到、进程 exit 0：timedOut=true 但 exitCode=0（调用方按成功处理）',
      () async {
    final starter = FakeProcessStarter(
      writesOutput: false,
      killCompletesExit: false, // kill 打在已收尾的进程上=no-op
      exitDelay: const Duration(milliseconds: 80),
    );

    final r = await runWithWatchdog(
      starter, 'tool', const <String>[],
      timeout: const Duration(milliseconds: 30),
      killGrace: const Duration(seconds: 2),
    );

    expect(r.timedOut, isTrue, reason: '看门狗确实开过火');
    expect(r.exitCode, 0, reason: '工作已完成——exit 0 必须原样透传');
  });

  test('kill 无效（D-state 仿真）→ timeout+killGrace 硬截止返回，不永挂', () async {
    final starter = FakeProcessStarter(
      hang: true,
      writesOutput: false,
      killCompletesExit: false, // kill 杀不动
    );

    final sw = Stopwatch()..start();
    final r = await runWithWatchdog(
      starter, 'tool', const <String>[],
      timeout: const Duration(milliseconds: 40),
      killGrace: const Duration(milliseconds: 60),
    );
    sw.stop();

    expect(r.timedOut, isTrue);
    expect(r.exitCode, WatchdogResult.kExitCodeAbandoned);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)),
        reason: '硬截止：busy 上限确定');
  });

  test('ProcessException 透传（与 run() 同语义）', () async {
    final starter = FakeProcessStarter(throwOnStart: true);

    await expectLater(
      runWithWatchdog(
        starter, 'gone-tool', const <String>[],
        timeout: const Duration(seconds: 1),
      ),
      throwsA(isA<ProcessException>()),
    );
  });

  test('stdout 流异常 → kill 收敛 + streamError 留证', () async {
    final starter = _ErrorStreamStarter();

    final r = await runWithWatchdog(
      starter, 'tool', const <String>[],
      timeout: const Duration(seconds: 5),
    );

    expect(r.streamError, isA<FormatException>());
    expect(starter.last!.killed, isTrue);
    expect(r.exitCode, -15);
  });
}

/// stdout 流注入 error 的专用 starter（仿真管道读取异常）。
class _ErrorStreamStarter implements ProcessStarter {
  FakeStartedProcess? last;

  @override
  Future<RunningProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async =>
      last = _ErrorStreamProcess();
}

class _ErrorStreamProcess extends FakeStartedProcess {
  _ErrorStreamProcess()
      : super(exit: 0, stderr: '', hang: true) {
    scheduleMicrotask(() {
      _errCtrl
        ..addError(const FormatException('bad pipe bytes'))
        ..close();
    });
  }

  final StreamController<String> _errCtrl = StreamController<String>();

  @override
  Stream<String> get stdoutLines => _errCtrl.stream;
}
