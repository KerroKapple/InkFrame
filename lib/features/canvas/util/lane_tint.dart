// PRD §7.3 风格泳道底色推断：中英双语词表，按定义顺序取首个命中、不叠加。
//
// 词表是【唯一数据源】：编辑框的色板（Lanes 稿改动 6）与「自动」推断说明都从这里读，
// UI 层不再复刻五个色值。
import 'dart:ui';

/// 五组词表：hex + 中英关键词。顺序即优先级，也是色板顺序。
const List<({String hex, List<String> keywords})> kLaneTintGroups = [
  (hex: '#FF8A50', keywords: ['暖', '黄昏', '餐厅', '烛光', 'warm', 'dusk', 'sunset', 'restaurant', 'candle']),
  (hex: '#4A78C8', keywords: ['雨', '夜', '冷', '霓虹', 'rain', 'night', 'cold', 'neon']),
  (hex: '#9AD8D8', keywords: ['荧光', '白', '医院', '办公', 'fluorescent', 'white', 'hospital', 'office']),
  (hex: '#3E7C5A', keywords: ['森林', '自然', '草地', 'forest', 'nature', 'grass', 'meadow']),
  (hex: '#6A4C93', keywords: ['恐怖', '暗', '废墟', 'horror', 'dark', 'ruin']),
];

/// 色板：词表五色，按词表顺序。
final List<String> kLaneTintChoices = List<String>.unmodifiable(
  <String>[for (final g in kLaneTintGroups) g.hex],
);

String? inferTintHex(String stylePrompt) => _inferGroup(stylePrompt)?.hex;

/// 「自动」推断命中的关键词（按词表顺序、只取首个命中组内的词）；没命中返回空。
/// 编辑框用它写「当前命中「neon / rain」→ #4A78C8」这一行。
List<String> matchedTintKeywords(String stylePrompt) {
  final g = _inferGroup(stylePrompt);
  if (g == null) return const <String>[];
  final lower = stylePrompt.trim().toLowerCase();
  return <String>[for (final kw in g.keywords) if (lower.contains(kw.toLowerCase())) kw];
}

({String hex, List<String> keywords})? _inferGroup(String stylePrompt) {
  final lower = stylePrompt.trim().toLowerCase();
  if (lower.isEmpty) return null;
  for (final g in kLaneTintGroups) {
    for (final kw in g.keywords) {
      if (lower.contains(kw.toLowerCase())) return g;
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
