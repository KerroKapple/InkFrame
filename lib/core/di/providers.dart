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
//   - stability-image-core (Stability AI Stable Image Core，同步文生图，multipart)
//
// keySource 统一走 SecureStorage；DashScope 家族经 SecureStorageKeys.scopeOf
// 折叠到同一把 Key。
//
// 生命周期不变量（CachingProviderRegistry 保证）：
// - 每个 providerId 的实例 / Dio / RateLimiter 全 app 生命周期只建一次
// - RateLimiter 随 ProviderContainer 销毁统一 dispose（ref.onDispose）

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/gemini_image_provider.dart';
import '../../providers/kling_v3_omni_provider.dart';
import '../../providers/kling_v3_provider.dart';
import '../../providers/openai_image_provider.dart';
import '../../providers/provider_registry.dart';
import '../../providers/rate_limiter.dart';
import '../../providers/stability_image_core_provider.dart';
import '../../providers/wanx_i2v_provider.dart';
import '../../providers/wanx_image_provider.dart';
import '../../providers/wanx_r2v_provider.dart';
import '../../providers/wanx_t2v_provider.dart';
import '../constants/secure_storage_keys.dart';
import '../errors/ink_error.dart';
import '../models/provider_capabilities.dart';
import 'secure_storage.dart';

/// 真实 ProviderRegistry —— keepAlive 全局一份。
final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final secure = ref.watch(secureStorageServiceProvider);

  Future<String> Function() keyFor(String providerId) => () async {
        final key = await secure.retrieve(
          SecureStorageKeys.providerApiKey(providerId),
        );
        if (key == null || key.isEmpty) {
          // 未配置 Key 走统一 InkError 链路（errorInvalidKey 文案），
          // 不再抛裸 StateError 落进 UnknownError 兜底。
          throw ProviderError(
            code: InkErrorCode.invalidKey,
            extra: {'provider_id': providerId, 'reason': 'key_not_configured'},
          );
        }
        return key;
      };

  // factory 只会被 CachingProviderRegistry 调用一次（实例缓存），
  // 故 limiter 在 factory 内创建即满足"每 providerId 单例"不变量；
  // dispose 挂到 container 生命周期，杜绝 Timer / waiter 泄漏。
  ProviderRateLimiter limiterFor(ProviderCapabilities caps) {
    final limiter = ProviderRateLimiter(qps: caps.qps, burst: caps.burst);
    ref.onDispose(limiter.dispose);
    return limiter;
  }

  return CachingProviderRegistry(<String, ProviderFactory>{
    kGeminiImageCapabilities.providerId: () => GeminiImageProvider(
          keySource: keyFor(kGeminiImageCapabilities.providerId),
          rateLimiter: limiterFor(kGeminiImageCapabilities),
        ),
    kOpenAIImageCapabilities.providerId: () => OpenAIImageProvider(
          keySource: keyFor(kOpenAIImageCapabilities.providerId),
          rateLimiter: limiterFor(kOpenAIImageCapabilities),
        ),
    kWanxImageCapabilities.providerId: () => WanxImageProvider(
          keySource: keyFor(kWanxImageCapabilities.providerId),
          rateLimiter: limiterFor(kWanxImageCapabilities),
        ),
    kWanxT2VCapabilities.providerId: () => WanxT2VProvider(
          keySource: keyFor(kWanxT2VCapabilities.providerId),
          rateLimiter: limiterFor(kWanxT2VCapabilities),
        ),
    kWanxI2VCapabilities.providerId: () => WanxI2VProvider(
          keySource: keyFor(kWanxI2VCapabilities.providerId),
          rateLimiter: limiterFor(kWanxI2VCapabilities),
        ),
    kWanxR2VCapabilities.providerId: () => WanxR2VProvider(
          keySource: keyFor(kWanxR2VCapabilities.providerId),
          rateLimiter: limiterFor(kWanxR2VCapabilities),
        ),
    kKlingV3Capabilities.providerId: () => KlingV3Provider(
          keySource: keyFor(kKlingV3Capabilities.providerId),
          rateLimiter: limiterFor(kKlingV3Capabilities),
        ),
    kKlingV3OmniCapabilities.providerId: () => KlingV3OmniProvider(
          keySource: keyFor(kKlingV3OmniCapabilities.providerId),
          rateLimiter: limiterFor(kKlingV3OmniCapabilities),
        ),
    kStabilityImageCoreCapabilities.providerId: () =>
        StabilityImageCoreProvider(
          keySource: keyFor(kStabilityImageCoreCapabilities.providerId),
          rateLimiter: limiterFor(kStabilityImageCoreCapabilities),
        ),
  });
});

/// 全部已注册 Provider 的能力声明（编译期 const）。注册顺序即展示顺序。
/// 与 providerRegistryProvider 的工厂表共用同一组 capabilities const，
/// 一致性由 provider_capabilities_source_test 守卫（对齐 registry.ids，防漂移）。
const List<ProviderCapabilities>
    kAllProviderCapabilities = <ProviderCapabilities>[
  kGeminiImageCapabilities,
  kOpenAIImageCapabilities,
  kWanxImageCapabilities,
  kWanxT2VCapabilities,
  kWanxI2VCapabilities,
  kWanxR2VCapabilities,
  kKlingV3Capabilities,
  kKlingV3OmniCapabilities,
  kStabilityImageCoreCapabilities,
];

/// UI 层下拉菜单数据源：直接读编译期 const 能力——**不实例化任何 Provider**
/// （不连带 9 个 Dio / RateLimiter）。这是 P1-x1 的修复点。
final providerCapabilitiesListProvider = Provider<List<ProviderCapabilities>>(
  (ref) => kAllProviderCapabilities,
  name: 'providerCapabilitiesListProvider',
);

/// providerId → 用户可读显示名。未声明 displayName 的回退 providerId。
final providerDisplayNamesProvider = Provider<Map<String, String>>(
  (ref) {
    final caps = ref.watch(providerCapabilitiesListProvider);
    return <String, String>{
      for (final c in caps) c.providerId: c.displayName ?? c.providerId,
    };
  },
  name: 'providerDisplayNamesProvider',
);
