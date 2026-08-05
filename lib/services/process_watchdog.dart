// runWithWatchdog：流式进程通道 + 看门狗定时器（PR-2 / BOARD 债153）。
//
// pg_dump / pg_restore 这类「一次性跑完」的子进程挂死时（网络挂载、锁等待），
// 旧的 ProcessRunner.run 无 kill/timeout 通道会让 busy 态永久锁 UI——
// 本助手用 EX-3 的 ProcessStarter 流式通道加上限时 kill。
//
// 失败语义：只有可执行文件不可启动抛 [ProcessException]（与 run() 一致，
// 调用方既有 catch 零改动）；流读取异常就地 kill 收敛，不向外抛。
import 'dart:async';

import '../core/interfaces/process_runner.dart';

class WatchdogResult {
  const WatchdogResult({
    required this.exitCode,
    required this.stderrTail,
    required this.timedOut,
  });

  final int exitCode;

  /// stderr 尾部（≤4000 字符，RunningProcess 契约）。
  final String stderrTail;

  /// true = 看门狗到时 kill 过进程；此时 [exitCode] 是 kill 产物，
  /// 调用方应按超时而非普通失败归因。
  final bool timedOut;
}

Future<WatchdogResult> runWithWatchdog(
  ProcessStarter starter,
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  required Duration timeout,
}) async {
  final RunningProcess running = await starter.start(
    executable,
    arguments,
    environment: environment,
  );
  var timedOut = false;
  final Timer watchdog = Timer(timeout, () {
    timedOut = true;
    running.kill();
  });
  try {
    try {
      // stdout 必须排干（管道背压契约）；这类工具正常几乎无 stdout。
      await running.stdoutLines.drain<void>();
    } on Object {
      // 流读取异常：kill 让 exitCode 收敛，按退出码归因。
      running.kill();
    }
    final int code = await running.exitCode;
    return WatchdogResult(
      exitCode: code,
      stderrTail: running.stderrTail,
      timedOut: timedOut,
    );
  } finally {
    watchdog.cancel();
  }
}
