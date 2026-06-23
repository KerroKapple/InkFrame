// PRD §7.3 风格泳道底色推断：中英双语词表，按定义顺序取首个命中、不叠加。
import 'dart:ui';

const List<({String hex, List<String> keywords})> _kTintGroups = [
  (hex: '#FF8A50', keywords: ['暖', '黄昏', '餐厅', '烛光', 'warm', 'dusk', 'sunset', 'restaurant', 'candle']),
  (hex: '#4A78C8', keywords: ['雨', '夜', '冷', '霓虹', 'rain', 'night', 'cold', 'neon']),
  (hex: '#9AD8D8', keywords: ['荧光', '白', '医院', '办公', 'fluorescent', 'white', 'hospital', 'office']),
  (hex: '#3E7C5A', keywords: ['森林', '自然', '草地', 'forest', 'nature', 'grass', 'meadow']),
  (hex: '#6A4C93', keywords: ['恐怖', '暗', '废墟', 'horror', 'dark', 'ruin']),
];

String? inferTintHex(String stylePrompt) {
  final lower = stylePrompt.trim().toLowerCase();
  if (lower.isEmpty) return null;
  for (final g in _kTintGroups) {
    for (final kw in g.keywords) {
      if (lower.contains(kw.toLowerCase())) return g.hex;
    }
  }
  return null;
}

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

Color? effectiveLaneTint({required String? tintColor, required String stylePrompt}) =>
    parseHexColor(tintColor) ?? parseHexColor(inferTintHex(stylePrompt));
