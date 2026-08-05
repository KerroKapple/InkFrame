// ProcessRunner provider —— app-scoped，外部进程执行的统一注入点。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/system_process_runner.dart';
import '../interfaces/process_runner.dart';

final processRunnerProvider = Provider<ProcessRunner>(
  (ref) => const SystemProcessRunner(),
  name: 'processRunnerProvider',
);

/// 流式启动通道（EX-3）。与 [processRunnerProvider] 同为无状态 const 实例，
/// 分开注入以维持 ISP：消费方按需依赖 run 或 start。
final processStarterProvider = Provider<ProcessStarter>(
  (ref) => const SystemProcessRunner(),
  name: 'processStarterProvider',
);
