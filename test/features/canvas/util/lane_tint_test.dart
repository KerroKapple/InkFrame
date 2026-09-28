import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/lane_tint.dart';

void main() {
  test('infers warm orange from zh/en keywords', () {
    expect(inferTintHex('烛光餐厅'), '#FF8A50');
    expect(inferTintHex('warm sunset light'), '#FF8A50');
  });
  test('first group in table order wins (no stacking)', () {
    // contains both 暖(warm group) and 夜(cold group); warm defined first.
    expect(inferTintHex('暖色的夜晚'), '#FF8A50');
  });
  test('returns null when no keyword and when empty', () {
    expect(inferTintHex('abstract geometry'), isNull);
    expect(inferTintHex('   '), isNull);
  });
  test('parseHexColor handles #RRGGBB and #AARRGGBB', () {
    expect(parseHexColor('#FF8A50'), const Color(0xFFFF8A50));
    expect(parseHexColor('80FF8A50'), const Color(0x80FF8A50));
    expect(parseHexColor('bad'), isNull);
    expect(parseHexColor(null), isNull);
  });
  test('effectiveLaneTint prefers explicit color over inference', () {
    expect(effectiveLaneTint(tintColor: '#112233', stylePrompt: '森林'), const Color(0xFF112233));
    expect(effectiveLaneTint(tintColor: null, stylePrompt: '森林'), const Color(0xFF3E7C5A));
    expect(effectiveLaneTint(tintColor: null, stylePrompt: 'nothing'), isNull);
  });

  // Lanes 稿改动 6：色板与推断说明都只认词表这一份数据源。
  test('kLaneTintChoices 就是词表五组的 hex，按词表顺序', () {
    expect(kLaneTintChoices, [for (final g in kLaneTintGroups) g.hex]);
    expect(kLaneTintChoices.length, 5);
  });

  test('matchedTintKeywords 只取首个命中组里出现过的词，按词表顺序', () {
    expect(matchedTintKeywords('cyberpunk, neon-lit, rain-slicked streets'), ['rain', 'neon']);
    expect(matchedTintKeywords('霓虹雨夜'), ['雨', '夜', '霓虹']);
    expect(matchedTintKeywords('plain daylight'), isEmpty);
    expect(matchedTintKeywords(''), isEmpty);
  });
}
