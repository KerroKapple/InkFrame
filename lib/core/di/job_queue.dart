import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/job_queue_service.dart';
import '../../providers/provider_registry.dart';
import '../../services/job_queue_service.dart';

/// app-scoped 单例：JobQueueService 横跨所有项目和画布（PRD §10.7）。
///
/// b1 阶段使用内存调度器；b2 子步换接持久化 + 启动恢复版本时只改本 provider。
final jobQueueServiceProvider = Provider<JobQueueService>((ref) {
  final registry = ref.watch(providerRegistryProvider);
  final service = InMemoryJobQueueService(registry: registry);
  ref.onDispose(service.dispose);
  return service;
});

/// 临时占位：真正的 ProviderRegistry 注册在后续 Provider 接入 PR 中完成。
///
/// b1 阶段单测里通过 \`overrideWithValue\` 注入测试 registry。
final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  throw UnimplementedError(
    'providerRegistryProvider must be overridden — register Providers in di/providers.dart',
  );
});
