// V0 收口守卫：旧「Amber Noir」暖色 ramp 与衬线字体家族在 lib/ 下零残留。
//
// 任务书 §2「tokens_test 必补 5」：命中即红。扫描 lib/**/*.dart（含 token 真相
// 源——它正是最容易被"顺手保留一个别名"的地方），另扫 pubspec.yaml 的字体声明。
//
// P7 补第三条闸：**暖色 hex 只许住在 tokens.dart**。前两条闸只认旧 ramp 的九个
// 具体值，换一组新的暖色照样过；no_inline_styles 的 R1 又对 theme/ 下的
// app_theme / typography / primitives / components 豁免（它们按设计直接消费
// 令牌值）。于是「在某个组件里手写一个琥珀色」这条路一直是开着的。这一条按
// 色相判定，不认具体数值：琥珀 / 危险 / 警告 / 成功这些品牌色是设计语言本身，
// 它们留在 tokens.dart（本条唯一的豁免文件）里；别的文件一律不许出现暖色。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 旧暖色 ramp 六档 + 三个暖灰前景。大小写不敏感，匹配 `0x??RRGGBB` 与 `#RRGGBB`。
final RegExp _warmHex = RegExp(
  r'(0x[0-9A-Fa-f]{2}|#)(0B0908|100C0A|15110E|1C1814|2A2520|36302A|'
  r'E8DFD0|B5A89A|8A7E70)\b',
  caseSensitive: false,
);

/// 衬线家族名 + Skia 通用族名。通用族名的理由见 lib/theme/typography.dart 头注：
/// 它会在 widget test 里被解析成真实系统字体，让度量随机器漂。
final RegExp _bannedFamily = RegExp(
  r"Cormorant|Garamond|Noto Serif|Times New Roman|Georgia|Playfair|"
  r"Merriweather|Source Serif|PT Serif|Libre Baskerville|"
  r"""['"]serif['"]|['"]sans-serif['"]""",
  caseSensitive: false,
);

/// 任意 ARGB / RGB hex 字面量：`Color(0xFF123456)` / `Color(0x123456)` / `#123456`。
final RegExp _anyHex = RegExp(
  r'Color\s*\(\s*0x([0-9A-Fa-f]{6,8})|#([0-9A-Fa-f]{6})\b',
);

/// 本条闸唯一的豁免文件：设计令牌真相源。
bool _isTokenSource(String path) => path.endsWith('lib/theme/tokens.dart');

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.contains('${Platform.pathSeparator}generated'));

/// 注释行（`//` 或续行的 `*`）不参与判定——注释里提到一个颜色或字体名不改像素，
/// 而 typography.dart 的头注恰恰要写出「**不写** 'sans-serif'」这句话。
bool _isComment(String line) {
  final String t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

/// hex 串 → 0xAARRGGBB（6 位补满不透明）。
int _parseHex(String hex) {
  final int v = int.parse(hex, radix: 16);
  return hex.length <= 6 ? 0xFF000000 | v : v;
}

/// 「暖色」= HSL 色相落在 20°–70°（黄 / 橙 / 琥珀那一段，旧 ramp 的方向）
/// 且饱和度 ≥ 0.05。中性灰的饱和度≈0，于是 #2E2E2E / #1A1A1A 这类机壳灰不误伤；
/// 纯黑纯白与阴影用的 0x33000000 同理。
bool _isWarm(int argb) {
  final double r = ((argb >> 16) & 0xFF) / 255;
  final double g = ((argb >> 8) & 0xFF) / 255;
  final double b = (argb & 0xFF) / 255;
  final double max = [r, g, b].reduce((a, c) => a > c ? a : c);
  final double min = [r, g, b].reduce((a, c) => a < c ? a : c);
  final double delta = max - min;
  if (delta == 0) return false; // 纯灰
  final double sum = max + min;
  final double saturation = sum <= 1 ? delta / sum : delta / (2 - sum);
  if (saturation < 0.05) return false;
  double hue;
  if (max == r) {
    hue = 60 * (((g - b) / delta) % 6);
  } else if (max == g) {
    hue = 60 * ((b - r) / delta + 2);
  } else {
    hue = 60 * ((r - g) / delta + 4);
  }
  if (hue < 0) hue += 360;
  return hue >= 20 && hue <= 70;
}

void main() {
  test('lib/ 下无旧暖色 hex 残留', () {
    final hits = <String>[];
    for (final f in _dartFiles(Directory('lib'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_warmHex.hasMatch(lines[i])) {
          hits.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: '旧暖色 ramp 已整体废弃，不保留别名：\n${hits.join('\n')}');
  });

  test('暖色 hex 只许住在 lib/theme/tokens.dart', () {
    final hits = <String>[];
    for (final f in _dartFiles(Directory('lib'))) {
      final String path = f.path.replaceAll(r'\', '/');
      if (_isTokenSource(path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_isComment(lines[i])) continue;
        for (final Match m in _anyHex.allMatches(lines[i])) {
          final String? hex = m.group(1) ?? m.group(2);
          if (hex == null) continue;
          if (_isWarm(_parseHex(hex))) {
            hits.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason: '暖色属设计语言，归 tokens.dart 管；组件里要用就先加一个令牌：\n'
          '${hits.join('\n')}',
    );
  });

  test('lib/ 与 pubspec.yaml 无衬线 / 通用字体家族名', () {
    final hits = <String>[];
    final files = <File>[..._dartFiles(Directory('lib')), File('pubspec.yaml')];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_isComment(lines[i])) continue;
        if (_bannedFamily.hasMatch(lines[i])) {
          hits.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: '界面全无衬线（README §字体）：\n${hits.join('\n')}');
  });

  test('assets/fonts 只剩 JetBrains Mono', () {
    final names = Directory('assets/fonts')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
    expect(names.where((n) => n.contains('Cormorant')), isEmpty);
  });
}
