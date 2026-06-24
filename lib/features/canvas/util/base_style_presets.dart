// base_style_presets.dart — 画布基底风格预设（模型合约常量，禁止 i18n）。
// ignore_for_file: avoid_classes_with_only_static_members

/// 单条预设：id 用于查找按钮 label，prompt 是英文模型合约常量。
class BaseStylePreset {
  final String id;
  final String prompt;
  const BaseStylePreset(this.id, this.prompt);
}

/// 7 条内置预设。prompt 文本属于模型合约，保持英文、不得 i18n。
const kBaseStylePresets = <BaseStylePreset>[
  BaseStylePreset('cinematic', 'cinematic film still, dramatic lighting, shallow depth of field, 35mm'),
  BaseStylePreset('anime', 'modern anime style, clean lineart, vibrant cel shading'),
  BaseStylePreset('ghibli', 'Studio Ghibli style, hand-painted backgrounds, soft warm palette'),
  BaseStylePreset('cyberpunk', 'cyberpunk, neon-lit, rain-slicked streets, high contrast'),
  BaseStylePreset('inkwash', 'traditional Chinese ink wash painting, sumi-e, minimal flowing brushstrokes'),
  BaseStylePreset('photographic', 'photorealistic, natural lighting, high detail, DSLR'),
  BaseStylePreset('anim3d', '3D animated film style, soft global illumination, subsurface scattering'),
];
