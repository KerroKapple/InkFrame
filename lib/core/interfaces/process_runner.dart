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
