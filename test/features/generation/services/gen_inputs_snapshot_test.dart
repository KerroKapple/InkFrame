// buildGenInputs：一次生成用到的输入 → result 节点 type_config.gen_inputs 的快照（纯函数）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/models/shot_language.dart';
import 'package:inkframe/features/generation/services/gen_inputs_snapshot.dart';

const ({String basePrefix, String baseSuffix, String laneStyle}) _styles =
    (basePrefix: 'cinematic', baseSuffix: '8k', laneStyle: 'warm light');

Map<String, Object?> _build({
  Map<String, Object?> configTypeConfig = const <String, Object?>{'prompt': 'a cat'},
  int? seed,
  bool seedOverridden = false,
  int? durationMs,
  String? negativePrompt,
  ({String basePrefix, String baseSuffix, String laneStyle}) styles = _styles,
  bool ignoreLaneStyle = false,
  List<GenInputSource> sources = const <GenInputSource>[],
}) =>
    buildGenInputs(
      configTypeConfig: configTypeConfig,
      prompt: 'a cat',
      seed: seed,
      seedOverridden: seedOverridden,
      providerId: 'gemini-image',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r16x9,
      durationMs: durationMs,
      negativePrompt: negativePrompt,
      styles: styles,
      ignoreLaneStyle: ignoreLaneStyle,
      sources: sources,
    );

void main() {
  test('只写有值的键；不含 batch_size', () {
    final Map<String, Object?> minimal = _build(
      configTypeConfig: const <String, Object?>{'prompt': 'a cat', 'batch_size': 4},
    );
    expect(minimal, <String, Object?>{
      'prompt': 'a cat',
      'provider_id': 'gemini-image',
      'resolution': 'p1080',
      'aspect_ratio': 'r16x9',
      'base_style_prefix': 'cinematic',
      'base_style_suffix': '8k',
      'lane_style': 'warm light',
      'character_ids': <String>[],
      'sources': <Map<String, Object?>>[],
    }, reason: '批量张数不算输入变化，不进快照；没值的可选键一个都不写');

    final Map<String, Object?> full = _build(
      configTypeConfig: const <String, Object?>{
        'prompt': 'a cat',
        'batch_size': 2,
        'camera': 'pushIn',
        'character_ids': <Object?>['ch1'],
      },
      seed: 7,
      durationMs: 5000,
      negativePrompt: 'blurry',
    );
    expect(full['seed'], 7);
    expect(full['duration_ms'], 5000);
    expect(full['negative_prompt'], 'blurry');
    expect(full['camera'], 'pushIn');
    expect(full['character_ids'], <String>['ch1']);
    expect(full.containsKey('batch_size'), isFalse);
    expect(full.containsKey('seed_override'), isFalse, reason: '种子来自节点设置，不写标记');
    expect(full.containsKey('ignore_lane_style'), isFalse);
  });

  test('seedOverridden → seed 是这次实际用的 + seed_override: true；没种子不写 seed', () {
    final Map<String, Object?> o = _build(seed: 42, seedOverridden: true);
    expect(o['seed'], 42);
    expect(o['seed_override'], isTrue);

    final Map<String, Object?> random = _build();
    expect(random.containsKey('seed'), isFalse, reason: '随机种子 = 不写');
    expect(random.containsKey('seed_override'), isFalse);
  });

  test('镜头语言四键原样拷', () {
    final Map<String, Object?> s = _build(
      configTypeConfig: const <String, Object?>{
        'prompt': 'a cat',
        ShotLanguage.keyShotSize: 'closeUp',
        ShotLanguage.keyCameraAngle: 'low',
        ShotLanguage.keyMotionStrength: 0.35,
        ShotLanguage.keyFocalLength: 85,
      },
    );
    expect(s[ShotLanguage.keyShotSize], 'closeUp');
    expect(s[ShotLanguage.keyCameraAngle], 'low');
    expect(s[ShotLanguage.keyMotionStrength], 0.35);
    expect(s[ShotLanguage.keyFocalLength], 85);
  });

  test('ignore_lane_style → lane_style 空串 + 标记', () {
    final Map<String, Object?> s = _build(ignoreLaneStyle: true);
    expect(s['lane_style'], '');
    expect(s['ignore_lane_style'], isTrue);
    expect(s['base_style_prefix'], 'cinematic', reason: '底稿风格不受泳道开关影响');
  });

  test('sources 保持传入顺序', () {
    final Map<String, Object?> s = _build(
      sources: const <GenInputSource>[
        GenInputSource(nodeId: 'z', role: 'first_frame', imageUrl: 'images/z.png'),
        GenInputSource(nodeId: 'a', role: 'reference', text: 'fog'),
        GenInputSource(nodeId: 'm', role: 'reference'),
      ],
    );
    expect(s['sources'], <Map<String, Object?>>[
      <String, Object?>{'node_id': 'z', 'role': 'first_frame', 'image_url': 'images/z.png'},
      <String, Object?>{'node_id': 'a', 'role': 'reference', 'text': 'fog'},
      <String, Object?>{'node_id': 'm', 'role': 'reference'},
    ]);
  });

  test('stripUnmappedGenInputs 从 generation 侧的再导出也拿得到', () {
    expect(
      stripUnmappedGenInputs(const <String, Object?>{}, mapNode: (_) => null, mapCharacter: (_) => null).dropped,
      0,
    );
  });
}
