// ProcessRunner 抽象：外部进程执行的最小注入点。
//
// PgProcessRunner（lib/storage/pg_controller.dart）是 PG 专用的窄接口；
// 本接口面向任意命令行工具（当前消费方：ffmpeg 探测与视频导出），
// 单测注入 fake 捕获命令行，生产用 SystemProcessRunner。
//
// 失败语义：可执行文件不存在/不可启动时抛 [ProcessException]（dart:io 原生），
// 由调用方映射为 InkError。
//
// [environment]：附加环境变量（并入父进程环境，不替换）。LB-10 pg_dump 经 PGPASSWORD
// 注入 SCRAM 口令即走此参数；ffmpeg/URL 打开等既有消费方不传。
import 'dart:io';

abstract class ProcessRunner {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  });
}

/// 流式进程句柄：进度解析与取消的最小通道（EX-3 首建，PR-2 备份/还原超时复用）。
///
/// 契约：
/// - [stdoutLines] utf8 按行解码，单订阅流；
/// - [exitCode] 完成时 stderr 已排干（[stderrTail] 此后读取才完整）——
///   实现必须持续消费 stderr，否则管道背压可能把子进程挂死（Windows 尤甚）；
/// - [kill] 幂等，平台默认信号（Windows TerminateProcess / POSIX SIGTERM）。
abstract class RunningProcess {
  Stream<String> get stdoutLines;
  Future<int> get exitCode;

  /// stderr 尾部截断（诊断用，≤4000 字符）。
  String get stderrTail;

  void kill();
}

/// 流式启动接口。与一次性 [ProcessRunner.run] 分离（ISP）：只有需要
/// 进度/取消的消费方才依赖它，既有 run() 的 fake 零改动。
/// 失败语义与 run() 一致：可执行文件不可启动抛 [ProcessException]。
abstract class ProcessStarter {
  Future<RunningProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  });
}
