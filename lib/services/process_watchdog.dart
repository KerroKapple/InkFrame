// runWithWatchdog：流式进程通道 + 看门狗定时器（PR-2 / BOARD 债153）。
//
// pg_dump / pg_restore 这类「一次性跑完」的子进程挂死时（网络挂载、锁等待），
// 旧的 ProcessRunner.run 无 kill/timeout 通道会让 busy 态永久锁 UI——
// 本助手用 EX-3 的 ProcessStarter 流式通道加上限时 kill，并带**硬截止**：
// kill 都杀不动（D-state / 管道写端被继承）时，timeout+killGrace 后放弃等待
// 直接返回（评审 P2-2）——busy 的上限是确定的，不是「通常会退出」。
//
// 失败语义：只有可执行文件不可启动抛 [ProcessException]（与 run() 一致，
// 调用方既有 catch 零改动）；流读取异常就地 kill 收敛，异常对象保留在
// [WatchdogResult.streamError] 供调用方入日志（评审 P2-4，不静默蒸发）。
//
// timedOut 与 exitCode 的优先级归调用方：exit 0 = 工作已完成，即使看门狗
// kill 迟到也不应丢弃产物（与 EX-3「已成功不误删」同一不变量，评审 P2-1）。
import 'dart:async';

import '../core/interfaces/process_runner.dart';

class WatchdogResult {
  const WatchdogResult({
    required this.exitCode,
    required this.stderrTail,
    required this.timedOut,
    this.streamError,
  });

  /// 进程退出码；硬截止放弃等待时为 [kExitCodeAbandoned]。
  final int exitCode;

  /// stderr 尾部（≤4000 字符，RunningProcess 契约）。
  final String stderrTail;

  /// true = 看门狗到时 kill 过进程。**exit 0 时调用方应按成功处理**
  ///（kill 迟到 ≠ 工作没做完）。
  final bool timedOut;

  /// stdout 流读取异常（若有）——调用方入日志，勿静默丢弃。
  final Object? streamError;

  static const int kExitCodeAbandoned = -0x7FFF;
}

Future<WatchdogResult> runWithWatchdog(
  ProcessStarter starter,
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  required Duration timeout,
  Duration killGrace = const Duration(seconds: 10),
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
    Object? streamError;
    Future<WatchdogResult> body() async {
      try {
        // stdout 必须排干（管道背压契约）；这类工具正常几乎无 stdout。
        await running.stdoutLines.drain<void>();
      } on Object catch (e) {
        streamError = e;
        running.kill(); // 让 exitCode 收敛；异常对象随结果上交。
      }
      final int code = await running.exitCode;
      return WatchdogResult(
        exitCode: code,
        stderrTail: running.stderrTail,
        timedOut: timedOut,
        streamError: streamError,
      );
    }

    return await body().timeout(timeout + killGrace, onTimeout: () {
      // 硬截止：kill 无效也不再等（评审 P2-2）。泄漏的等待 future 无害——
      // 进程若终于退出，future 完成后即被丢弃。
      running.kill();
      return WatchdogResult(
        exitCode: WatchdogResult.kExitCodeAbandoned,
        stderrTail: running.stderrTail,
        timedOut: true,
        streamError: streamError,
      );
    });
  } finally {
    watchdog.cancel();
  }
}
