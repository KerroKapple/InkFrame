// FIX-005 生命周期回归：
// - HI-08：registry.get(id) 实例按 providerId 缓存（Dio 不再每次新建泄漏）
// - keyFor：Key 未配置抛 ProviderError(invalidKey)，不再裸 StateError
// - LO-01：RateLimiter 随 ProviderContainer 销毁统一 dispose

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/gemini_image_provider.dart';

class _NoopSecure implements SecureStorageService {
  @override
  Future<void> store(String k, String v) async {}
  @override
  Future<String?> retrieve(String k) async => null;
  @override
  Future<void> delete(String k) async {}
  @override
  Future<bool> exists(String k) async => false;
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_NoopSecure()),
      ],
    );
  });

  test('同一 providerId 重复 get() 返回缓存实例（identical）', () {
    final registry = container.read(providerRegistryProvider);
    addTearDown(container.dispose);

    for (final id in registry.ids) {
      expect(
        identical(registry.get(id), registry.get(id)),
        isTrue,
        reason: '$id: 实例必须缓存——否则每次 get() 新建 Dio 永不释放',
      );
    }
  });

  test('Key 未配置时 submit 抛 ProviderError(invalidKey)', () async {
    final registry = container.read(providerRegistryProvider);
    addTearDown(container.dispose);

    const task = GenerationTask(
      providerId: 'gemini-image',
      jobId: 'job-keyless',
      mode: GenerationMode.textToImage,
      prompt: 'an ink wash painting',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );
    // keySource 在发 HTTP 前读取，本测试不触网。
    await expectLater(
      registry.get('gemini-image').submit(task),
      throwsA(
        isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidKey)
            .having((e) => e.extra['provider_id'], 'provider_id',
                'gemini-image'),
      ),
    );
  });

  test('container dispose 级联 dispose RateLimiter（挂起的 acquire 报错退出）', () async {
    final registry = container.read(providerRegistryProvider);
    final gemini =
        registry.get('gemini-image') as GeminiImageProvider;
    final limiter = gemini.rateLimiterForTesting;

    // 耗尽 burst 让下一个 acquire 挂起
    for (var i = 0; i < kGeminiImageCapabilities.burst; i++) {
      await limiter.acquire();
    }
    final pending = limiter.acquire();

    container.dispose();
    await expectLater(pending, throwsA(isA<StateError>()));
  });
}
