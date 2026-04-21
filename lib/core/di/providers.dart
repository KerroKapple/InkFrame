// Provider DI 装配 — 把所有 Submittable Provider 注册到 ProviderRegistry。
//
// S2a 范围内仅接 Gemini (PRD §10.2.1)；后续切片再把 Wanx / Kling 加进来。
//
// keySource 统一走 SecureStorage；未配置 Key 时 retrieve 返回 null →
// 抛 StateError，由 UI/Controller 层捕获提示用户去 Settings 填。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/gemini_image_provider.dart';
import '../../providers/provider_registry.dart';
import '../../providers/rate_limiter.dart';
import '../constants/secure_storage_keys.dart';
import '../models/provider_capabilities.dart';
import 'secure_storage.dart';

/// 真实 ProviderRegistry —— keepAlive 全局一份。
///
/// factory 每次 get() 新建 Submittable 实例；共享 RateLimiter 以遵守
/// capabilities.qps / burst 上限。
final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final secure = ref.watch(secureStorageServiceProvider);
  final geminiRateLimiter = ProviderRateLimiter(
    qps: kGeminiImageCapabilities.qps,
    burst: kGeminiImageCapabilities.burst,
  );

  return ProviderRegistry(<String, ProviderFactory>{
    kGeminiImageCapabilities.providerId: () => GeminiImageProvider(
          keySource: () async {
            final key = await secure.retrieve(
              SecureStorageKeys.providerApiKey(
                kGeminiImageCapabilities.providerId,
              ),
            );
            if (key == null || key.isEmpty) {
              throw StateError(
                'Gemini API key not configured in SecureStorage.',
              );
            }
            return key;
          },
          rateLimiter: geminiRateLimiter,
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
