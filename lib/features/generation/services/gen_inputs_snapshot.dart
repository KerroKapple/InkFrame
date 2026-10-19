// 生成快照：一次生成用到的输入 → result 节点 type_config.gen_inputs（纯函数）。
//
// 建 result 节点与 job 行的同一个事务里随 create 写入（见 generation_controller）。它是过期标记
// 与下游连线跟随的数据底座：不拿 jobs 行当快照——jobs 30 天 / 按画布上限会被清。
// 不算「输入变了」的东西不进快照：改名、位置、层级、批量张数（batch_size）。
// 契约（GenInputSource / stripUnmappedGenInputs）在 core/models/gen_inputs.dart，这里再导出。
import '../../../core/models/gen_inputs.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../core/models/shot_language.dart';

export '../../../core/models/gen_inputs.dart' show GenInputSource, stripUnmappedGenInputs;

/// 从配置节点 type_config 原样拷进快照的键：运镜 + 镜头语言四键。
const List<String> _copiedConfigKeys = <String>[
  'camera',
  ShotLanguage.keyShotSize,
  ShotLanguage.keyCameraAngle,
  ShotLanguage.keyMotionStrength,
  ShotLanguage.keyFocalLength,
];

/// 结果只含有值的键；[prompt] 是用户提示词（trim 后，不含镜头语言前缀与风格——那些分开记）。
///
/// [seed] 是这次实际用的种子（含「以该种子重跑」的 override）；null = 随机，不写。
/// [seedOverridden] 为 true 时写 `seed_override: true`：这次的种子不是节点设置，比对过期时不比种子。
/// [ignoreLaneStyle] 为 true 时 `lane_style` 一律记空串并写 `ignore_lane_style: true`。
/// `base_style_prefix` / `base_style_suffix` / `lane_style` / `character_ids` / `sources` 总是写（可为空）。
Map<String, Object?> buildGenInputs({
  required Map<String, Object?> configTypeConfig,
  required String prompt,
  required int? seed,
  bool seedOverridden = false,
  required String providerId,
  required Resolution resolution,
  required AspectRatio aspectRatio,
  required int? durationMs,
  required String? negativePrompt,
  required ({String basePrefix, String baseSuffix, String laneStyle}) styles,
  required bool ignoreLaneStyle,
  required List<GenInputSource> sources,
}) {
  return <String, Object?>{
    'prompt': prompt,
    'negative_prompt': ?negativePrompt,
    'seed': ?seed,
    if (seed != null && seedOverridden) 'seed_override': true,
    'provider_id': providerId,
    'resolution': resolution.name,
    'aspect_ratio': aspectRatio.name,
    'duration_ms': ?durationMs,
    for (final String key in _copiedConfigKeys)
      if (configTypeConfig[key] != null) key: configTypeConfig[key],
    'base_style_prefix': styles.basePrefix,
    'base_style_suffix': styles.baseSuffix,
    'lane_style': ignoreLaneStyle ? '' : styles.laneStyle,
    if (ignoreLaneStyle) 'ignore_lane_style': true,
    GenInputsKeys.characterIds: _characterIdsOf(configTypeConfig),
    GenInputsKeys.sources: <Map<String, Object?>>[for (final GenInputSource s in sources) s.toJson()],
  };
}

/// 挂载角色 id，原序；与生成侧读 character_ids 同口径（非空字符串化）。
List<String> _characterIdsOf(Map<String, Object?> typeConfig) {
  final Object? raw = typeConfig[GenInputsKeys.characterIds];
  if (raw is! List) return const <String>[];
  return <String>[
    for (final Object? e in raw)
      if (e != null && e.toString().isNotEmpty) e.toString(),
  ];
}
