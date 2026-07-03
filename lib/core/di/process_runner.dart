// ProcessRunner provider —— app-scoped，外部进程执行的统一注入点。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/system_process_runner.dart';
import '../interfaces/process_runner.dart';

final processRunnerProvider = Provider<ProcessRunner>(
  (ref) => const SystemProcessRunner(),
  name: 'processRunnerProvider',
);
