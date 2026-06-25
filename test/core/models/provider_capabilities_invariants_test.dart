// ProviderCapabilities 不变量闸门（评审 P2#10）：所有 const 能力声明必须满足
// 限流/配额/批量为正、模式与比例非空、providerId 全局唯一。
// ProviderCapabilities 是 freezed const，无法在工厂里加 assert（需 codegen），
// 故以静态测试固化不变量——新增 Provider 时自动受检。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/gemini_image_provider.dart';
import 'package:inkframe/providers/kling_v3_omni_provider.dart';
import 'package:inkframe/providers/kling_v3_provider.dart';
import 'package:inkframe/providers/openai_image_provider.dart';
import 'package:inkframe/providers/stability_image_core_provider.dart';
import 'package:inkframe/providers/wanx_i2v_provider.dart';
import 'package:inkframe/providers/wanx_image_provider.dart';
import 'package:inkframe/providers/wanx_r2v_provider.dart';
import 'package:inkframe/providers/wanx_t2v_provider.dart';

void main() {
  const all = <String, ProviderCapabilities>{
    'gemini-image': kGeminiImageCapabilities,
    'openai-image': kOpenAIImageCapabilities,
    'stability-image-core': kStabilityImageCoreCapabilities,
    'wanx-image': kWanxImageCapabilities,
    'wanx-t2v': kWanxT2VCapabilities,
    'wanx-i2v': kWanxI2VCapabilities,
    'wanx-r2v': kWanxR2VCapabilities,
    'kling-v3': kKlingV3Capabilities,
    'kling-v3-omni': kKlingV3OmniCapabilities,
  };

  for (final entry in all.entries) {
    test('ProviderCapabilities 不变量：${entry.key}', () {
      final c = entry.value;
      expect(c.providerId, isNotEmpty);
      expect(c.qps, greaterThan(0), reason: 'qps 须为正（令牌桶速率）');
      expect(c.burst, greaterThan(0), reason: 'burst 须为正');
      expect(c.maxConcurrentJobs, greaterThanOrEqualTo(1));
      expect(c.maxBatchSize, greaterThanOrEqualTo(1));
      expect(c.maxRefImages, greaterThanOrEqualTo(0));
      expect(c.modes, isNotEmpty, reason: '至少声明一种生成模式');
      expect(c.supportedRatios, isNotEmpty, reason: '至少支持一种比例');
    });
  }

  test('providerId 全局唯一', () {
    final ids = all.values.map((c) => c.providerId).toList();
    expect(ids.toSet().length, ids.length, reason: 'providerId 重复');
  });
}
