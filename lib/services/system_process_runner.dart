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
    _stderrDone =
        _process.stderr.transform(utf8.decoder).forEach((chunk) {
      _stderrBuf.write(chunk);
      if (_stderrBuf.length > _kStderrCap) {
        final s = _stderrBuf.toString();
        _stderrBuf
          ..clear()
          ..write(s.substring(s.length - _kStderrCap));
      }
    });
  }

  static const int _kStderrCap = 4000;

  final Process _process;
  final StringBuffer _stderrBuf = StringBuffer();
  late final Future<void> _stderrDone;

  @override
  Stream<String> get stdoutLines =>
      _process.stdout.transform(utf8.decoder).transform(const LineSplitter());

  @override
  Future<int> get exitCode async {
    final code = await _process.exitCode;
    try {
      await _stderrDone;
    } on Object {
      // stderr 解码失败不掩盖退出码。
    }
    return code;
  }

  @override
  String get stderrTail => _stderrBuf.toString();

  @override
  void kill() => _process.kill();
}