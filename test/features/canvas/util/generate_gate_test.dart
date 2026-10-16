// generate_gate：检查器与提示词条共用的「生成」判据（纯函数）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/generate_gate.dart';

void main() {
  group('generateBlockReason', () {
    test('提示词空优先于没 Key（就近原则：先让人填提示词）', () {
      expect(
        generateBlockReason(promptEmpty: true, hasApiKey: false),
        GenerateBlockReason.emptyPrompt,
      );
      expect(
        generateBlockReason(promptEmpty: true, hasApiKey: true),
        GenerateBlockReason.emptyPrompt,
      );
    });

    test('有提示词没 Key ⇒ missingApiKey；都有 ⇒ null（可点）', () {
      expect(
        generateBlockReason(promptEmpty: false, hasApiKey: false),
        GenerateBlockReason.missingApiKey,
      );
      expect(generateBlockReason(promptEmpty: false, hasApiKey: true), isNull);
    });
  });

  group('configProviderCandidates', () {
    test('图像节点：全部供应商（与图像检查器的下拉一致）', () {
      expect(
        configProviderCandidates(CanvasNodeType.image, kAllProviderCapabilities),
        kAllProviderCapabilities,
      );
    });

    test('视频节点：只留能文生 / 图生视频的', () {
      final List<ProviderCapabilities> video =
          configProviderCandidates(CanvasNodeType.video, kAllProviderCapabilities);
      expect(video, isNotEmpty);
      for (final ProviderCapabilities c in video) {
        expect(
          c.modes.contains(GenerationMode.textToVideo) ||
              c.modes.contains(GenerationMode.imageToVideo),
          isTrue,
          reason: '${c.providerId} 不能出视频',
        );
      }
      expect(video.map((ProviderCapabilities c) => c.providerId), isNot(contains('gemini-image')));
    });
  });

  group('resolveConfigProviderId', () {
    const List<ProviderCapabilities> caps = kAllProviderCapabilities;
    final String first = caps.first.providerId;
    final String other = caps[1].providerId;

    test('节点已存的优先，且不校验是否在候选里（检查器一直原样显示已存值）', () {
      expect(
        resolveConfigProviderId(
          savedProviderId: 'gone-custom',
          lastUsedProviderId: other,
          candidates: caps,
        ),
        'gone-custom',
      );
    });

    test('没存过：上次使用（仍在候选里）其次', () {
      expect(
        resolveConfigProviderId(savedProviderId: null, lastUsedProviderId: other, candidates: caps),
        other,
      );
    });

    test('上次使用已不在候选里（自定义供应商删了）⇒ 候选第一个', () {
      expect(
        resolveConfigProviderId(
          savedProviderId: null,
          lastUsedProviderId: 'deleted-custom',
          candidates: caps,
        ),
        first,
      );
    });

    test('什么都没有 ⇒ 候选第一个；候选也空 ⇒ null', () {
      expect(
        resolveConfigProviderId(savedProviderId: null, lastUsedProviderId: null, candidates: caps),
        first,
      );
      expect(
        resolveConfigProviderId(
          savedProviderId: null,
          lastUsedProviderId: null,
          candidates: const <ProviderCapabilities>[],
        ),
        isNull,
      );
    });
  });
}
