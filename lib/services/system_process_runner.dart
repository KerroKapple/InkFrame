// SystemProcessRunner：ProcessRunner 的 dart:io 落地。
import 'dart:io';

import '../core/interfaces/process_runner.dart';

class SystemProcessRunner implements ProcessRunner {
  const SystemProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) =>
      Process.run(executable, arguments, environment: environment);
}
