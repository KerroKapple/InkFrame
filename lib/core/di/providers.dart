// Provider DI 装配 — 把所有 Submittable Provider 注册到 ProviderRegistry。
//
// 已注册：
//   - gemini-image      (PRD §10.2.1, 同步文生图)
//   - openai-image      (OpenAI gpt-image-1, 同步文生图)
//   - wanx-image        (阿里万相，异步文生图)
//   - wanx-t2v          (阿里万相，异步文生视频)
//   - wanx-i2v          (阿里万相，异步图生视频)
//   - wanx-r2v          (阿里万相，异步参考生视频)
//   - kling-v3          (快手 Kling v3，DashScope 渠道，异步)
//   - kling-v3-omni     (快手 Kling v3 Omni，DashScope 渠道，异步)
//
// keySource 统一走 SecureStorage，按 providerId 独立存 Key。
// DashScope 系列 6 款虽然都用 DashScope API Key，但当前架构每个 providerId 一把 Key；
// 未来可优化成 "family key" 让用户只填一次 DashScope Key。
//
// RateLimiter 每个 Provider 独立一把，按 capabilities.qps / burst 限速。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/gemini_image_provider.dart';
import '../../providers/kling_v3_omni_provider.dart';
import '../../providers/kling_v3_provider.dart';
import '../../providers/openai_image_provider.dart';
import '../../providers/provider_registry.dart';
import '../../providers/rate_limiter.dart';
import '../../providers/wanx_i2v_provider.dart';
import '../../providers/wanx_image_provider.dart';
import '../../providers/wanx_r2v_provider.dart';
import '../../providers/wanx_t2v_provider.dart';
import '../constants/secure_storage_keys.dart';
import '../models/provider_capabilities.dart';
import 'secure_storage.dart';

/// 真实 ProviderRegistry —— keepAlive 全局一份。
///
/// factory 每次 get() 新建 Submittable 实例；共享 RateLimiter 以遵守
/// capabilities.qps / burst 上限。
final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final secure = ref.watch(secureStorageServiceProvider);

  Future<String> Function() keyFor(String providerId) => () async {
        final key = await secure.retrieve(
          SecureStorageKeys.providerApiKey(providerId),
        );
        if (key == null || key.isEmpty) {
          throw StateError(
            '$providerId API key not configured in SecureStorage.',
          );
        }
        return key;
      };

  // RateLimiter 必须按 providerId 共享：token bucket 持有 _tokens/_waiters
  // 等可变状态，每次 get() 新建实例会让限速形同虚设。提前实例化，由 factory
  // 闭包捕获共享引用。
  final geminiImageRl = ProviderRateLimiter(
    qps: kGeminiImageCapabilities.qps,
    burst: kGeminiImageCapabilities.burst,
  );
  final openAIImageRl = ProviderRateLimiter(
    qps: kOpenAIImageCapabilities.qps,
    burst: kOpenAIImageCapabilities.burst,
  );
  final wanxImageRl = ProviderRateLimiter(
    qps: kWanxImageCapabilities.qps,
    burst: kWanxImageCapabilities.burst,
  );
  final wanxT2VRl = ProviderRateLimiter(
    qps: kWanxT2VCapabilities.qps,
    burst: kWanxT2VCapabilities.burst,
  );
  final wanxI2VRl = ProviderRateLimiter(
    qps: kWanxI2VCapabilities.qps,
    burst: kWanxI2VCapabilities.burst,
  );
  final wanxR2VRl = ProviderRateLimiter(
    qps: kWanxR2VCapabilities.qps,
    burst: kWanxR2VCapabilities.burst,
  );
  final klingV3Rl = ProviderRateLimiter(
    qps: kKlingV3Capabilities.qps,
    burst: kKlingV3Capabilities.burst,
  );
  final klingV3OmniRl = ProviderRateLimiter(
    qps: kKlingV3OmniCapabilities.qps,
    burst: kKlingV3OmniCapabilities.burst,
  );

  return ProviderRegistry(<String, ProviderFactory>{
    kGeminiImageCapabilities.providerId: () => GeminiImageProvider(
          keySource: keyFor(kGeminiImageCapabilities.providerId),
          rateLimiter: geminiImageRl,
        ),
    kOpenAIImageCapabilities.providerId: () => OpenAIImageProvider(
          keySource: keyFor(kOpenAIImageCapabilities.providerId),
          rateLimiter: openAIImageRl,
        ),
    kWanxImageCapabilities.providerId: () => WanxImageProvider(
          keySource: keyFor(kWanxImageCapabilities.providerId),
          rateLimiter: wanxImageRl,
        ),
    kWanxT2VCapabilities.providerId: () => WanxT2VProvider(
          keySource: keyFor(kWanxT2VCapabilities.providerId),
          rateLimiter: wanxT2VRl,
        ),
    kWanxI2VCapabilities.providerId: () => WanxI2VProvider(
          keySource: keyFor(kWanxI2VCapabilities.providerId),
          rateLimiter: wanxI2VRl,
        ),
    kWanxR2VCapabilities.providerId: () => WanxR2VProvider(
          keySource: keyFor(kWanxR2VCapabilities.providerId),
          rateLimiter: wanxR2VRl,
        ),
    kKlingV3Capabilities.providerId: () => KlingV3Provider(
          keySource: keyFor(kKlingV3Capabilities.providerId),
          rateLimiter: klingV3Rl,
        ),
    kKlingV3OmniCapabilities.providerId: () => KlingV3OmniProvider(
          keySource: keyFor(kKlingV3OmniCapabilities.providerId),
          rateLimiter: klingV3OmniRl,
        ),
  });
});

/// UI 层下拉菜单数据源：按注册顺序列出 capabilities。
final providerCapabilitiesListProvider = Provider<List<ProviderCapabilities>>(
  (ref) {
    final registry = ref.watch(providerRegistryProvider);
    return registry.listCapabilities();
  },
  name: 'providerCapabilitiesListProvider',
);
