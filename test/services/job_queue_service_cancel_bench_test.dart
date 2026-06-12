// 性能诊断：测 cancel(jobId) 在不同 pending depth 下的耗时。
//
// 不做 expect 断言（避免环境抖动挂 CI），只 print 表格。
// 真正的性能护栏在 job_queue_service_test.dart 的 perf group 里，
// 那里只断 N=10000 < 50ms 这一条粗线。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/provider_registry.dart';
import 'package:inkframe/services/job_queue_service.dart';

class _NoopProvider implements Submittable {
  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        providerId: 'bench-noop',
        region: ProviderRegion.global,
        modes: [GenerationMode.textToImage],
        supportedRatios: [AspectRatio.r1x1],
        supportedResolutions: [Resolution.p1080],
        supportedDurations: [],
        supportedCameras: [],
        maxBatchSize: 1,
        maxRefImages: 0,
        refImagesIncludeKeyframes: false,
        supportsFirstFrame: false,
        supportsLastFrame: false,
        supportsNegativePrompt: false,
        supportsSeed: false,
        supportsSound: false,
        supportsBatch: false,
        supportsCancellation: false,
        supportsPolling: true,
        costModel: CostModel.perCall(usdPerCall: 0),
        maxConcurrentJobs: 0, // 0 = 永远不调度，让任务全部堆在 pending
        qps: 1,
        burst: 1,
      );

  @override
  Future<JobId> submit(GenerationTask task) async => task.jobId;
}

GenerationTask _task(int i) => GenerationTask(
      jobId: 'bench-$i',
      projectId: 'p',
      canvasId: 'c',
      resultNodeId: 'r-$i',
      providerId: 'bench-noop',
      prompt: 'noop',
      mode: GenerationMode.textToImage,
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

Future<int> _benchCancel(int n, String pattern) async {
  final svc = InMemoryJobQueueService(
    registry: CachingProviderRegistry({'bench-noop': () => _NoopProvider()}),
  );
  final ids = <String>[];
  for (var i = 0; i < n; i++) {
    await svc.submit(_task(i));
    ids.add('bench-$i');
  }
  final order = switch (pattern) {
    'head' => ids,
    'tail' => ids.reversed.toList(),
    'random' => (ids.toList()..shuffle()),
    _ => ids,
  };
  final sw = Stopwatch()..start();
  for (final id in order) {
    await svc.cancel(id);
  }
  sw.stop();
  svc.dispose();
  return sw.elapsedMicroseconds;
}

void main() {
  test('JobQueueService cancel — diagnostic bench (no assertions)', () async {
    final sizes = [10, 100, 1000, 10000];
    final patterns = ['head', 'tail', 'random'];
    // ignore: avoid_print
    print('| N | pattern | total μs | per-cancel μs |');
    // ignore: avoid_print
    print('|---|---------|---------|---------------|');
    for (final n in sizes) {
      for (final p in patterns) {
        final total = await _benchCancel(n, p);
        // ignore: avoid_print
        print('| $n | $p | $total | ${total / n} |');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
