// SystemProcessRunner：ProcessRunner / ProcessStarter 的 dart:io 落地。
import 'dart:convert';
import 'dart:io';

import '../core/interfaces/process_runner.dart';

class SystemProcessRunner implements ProcessRunner, ProcessStarter {
  const SystemProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) =>
      Process.run(executable, arguments, environment: environment);

  @override
  Future<RunningProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      environment: environment,
    );
    return _SystemRunningProcess(process);
  }
}

class _SystemRunningProcess implements RunningProcess {
  _SystemRunningProcess(this._process) {
    // stderr 必须持续排干（接口契约）：不消费会因管道背压挂死子进程。
    // catchError 护栏：该 future 在被 exitCode await 之前若以错误完成,
    // 会以"无监听者错误"逃到 zone（评审 P2-3,已复现）——就地吞掉。
    _stderrDone = _process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
      _stderrBuf.write(chunk);
      if (_stderrBuf.length > _kStderrCap) {
        final s = _stderrBuf.toString();
        _stderrBuf
          ..clear()
          ..write(s.substring(s.length - _kStderrCap));
      }
    }).catchError((Object _) {
      // 管道读取异常：stderrTail 保留已收到的前缀,不掩盖退出码。
    });
  }

  static const int _kStderrCap = 4000;

  final Process _process;
  final StringBuffer _stderrBuf = StringBuffer();
  late final Future<void> _stderrDone;

  @override
  Stream<String> get stdoutLines => _process.stdout
      // allowMalformed：子进程输出混入非 UTF-8 字节（如容器 metadata 回显）
      // 不应炸掉整条进度流（评审 P1-2 触发面 a）。
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());

  @override
  Future<int> get exitCode async {
    final code = await _process.exitCode;
    await _stderrDone; // 构造期已挂 catchError,恒正常完成。
    return code;
  }

  @override
  String get stderrTail => _stderrBuf.toString();

  @override
  void kill() => _process.kill();
}
