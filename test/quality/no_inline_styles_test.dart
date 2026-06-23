// 零硬编码视觉值回归：把原 check-inline-styles.sh 固化为 Dart 静态测试。
// 扫 lib/**/*.dart（排除生成文件与 token 真相源），断言不残留硬编码颜色/字号/间距/圆角/阴影。
// 设计令牌系统（lib/theme/tokens.dart 等）是唯一真相源，故对其豁免。
//
// 覆盖 6 类规则（对应原脚本 Rule1-5/7）：
//   R1 hex Color(0x...)  R2 Colors.* 物料色  R3 fontSize:N
//   R4 EdgeInsets 裸数字  R5 BorderRadius 裸数字  R7 内联 BoxShadow(color:)
// Rule6（裸 Container+BoxDecoration）属设计偏好而非硬编码值，留待 custom_lint，不在此纳入。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 生成文件 / 测试文件 一律跳过。
bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.endsWith('_test.dart') ||
    p.contains('l10n/generated/') ||
    p.contains('generated/');

/// token / 主题真相源豁免——它们定义视觉常量，理应直接写值。
bool _isThemeSourceOfTruth(String p) =>
    p.endsWith('lib/theme/tokens.dart') ||
    p.endsWith('lib/theme/app_theme.dart') ||
    p.endsWith('theme/typography.dart');

/// primitives / components：组件按设计直接消费 token（hex/Colors/BoxShadow 合法），
/// 故对 R1/R2/R7 豁免；但对 R3(fontSize)/R4(EdgeInsets) 不豁免——硬编码间距/字号仍是违例。
bool _isStyledComponentDir(String p) =>
    p.contains('lib/theme/primitives/') || p.contains('lib/theme/components/');

/// 剔除 InkSpacing.* / InkRadius.* 等 token 引用后，再判定是否残留裸数字字面量。
String _stripSpacingTokens(String s) =>
    s.replaceAll(RegExp(r'Ink(Spacing|Radius)\.[A-Za-z][A-Za-z0-9]*'), '');

/// 平衡括号：从 [openParenIdx]（指向 '('）起取到配对 ')'，返回括号内实参子串。
/// 支持跨行实参（libFixes 把若干 padding 改成多行 EdgeInsets.symmetric(\n ... )）。
String _balancedArgs(String src, int openParenIdx) {
  var depth = 0;
  var i = openParenIdx;
  for (; i < src.length; i++) {
    final c = src[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) break;
    }
  }
  return src.substring(openParenIdx + 1, i);
}

/// 剥离 token 后剩余文本里是否含【非零】裸数字。
/// 单独的 0（如 EdgeInsets.fromLTRB(InkSpacing.md, 0, ...) 的零边）属零间距惯用法，
/// 与 EdgeInsets.zero 同义，不算硬编码设计值；仅非零字面量（2/3/4/10...）才算违例。
bool _hasNonZeroBareNumber(String stripped) {
  for (final m in RegExp(r'[0-9]+').allMatches(stripped)) {
    if (int.parse(m.group(0)!) != 0) return true;
  }
  return false;
}

int _lineAt(String src, int charIdx) =>
    '\n'.allMatches(src.substring(0, charIdx)).length + 1;

void main() {
  final r1Hex = RegExp(r'Color\s*\(\s*0x[0-9A-Fa-f]{6,8}');
  final r2Material = RegExp(
    r'Colors\.(white|black|grey|red|blue|green|orange|purple|pink|yellow|'
    r'brown|cyan|teal|amber|lime|indigo)\b',
  );
  final r3FontSize = RegExp(r'fontSize\s*:\s*[0-9]');
  final r7BoxShadow = RegExp(r'BoxShadow\s*\(\s*color:');
  final r4Edge = RegExp(r'EdgeInsets\.(all|symmetric|only|fromLTRB)\s*\(');
  final r5Radius =
      RegExp(r'(BorderRadius\.(circular|only|all)|Radius\.circular)\s*\(');

  test('lib 下无硬编码视觉值（颜色/字号/间距/圆角/阴影）', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ not found');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (_isGenerated(path)) continue;
      if (_isThemeSourceOfTruth(path)) continue;

      final src = entity.readAsStringSync();
      final lines = src.split('\n');
      final componentDir = _isStyledComponentDir(path);

      // 逐行规则：R1/R2/R3/R7（跳过 // 与 * 注释行）。
      for (var i = 0; i < lines.length; i++) {
        final raw = lines[i];
        final trimmed = raw.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        final at = '$path:${i + 1}';
        if (!componentDir) {
          if (r1Hex.hasMatch(raw)) {
            violations.add('$at  [R1] hex Color: ${raw.trim()}');
          }
          if (r2Material.hasMatch(raw)) {
            violations.add('$at  [R2] material Colors.*: ${raw.trim()}');
          }
          if (r7BoxShadow.hasMatch(raw)) {
            violations.add('$at  [R7] inline BoxShadow(color:): ${raw.trim()}');
          }
        }
        if (r3FontSize.hasMatch(raw)) {
          violations.add('$at  [R3] hardcoded fontSize: ${raw.trim()}');
        }
      }

      // 全文 + 平衡括号规则：R4 EdgeInsets / R5 BorderRadius（支持跨行实参）。
      for (final spec in <List<Object>>[
        [r4Edge, 'R4 EdgeInsets'],
        [r5Radius, 'R5 BorderRadius'],
      ]) {
        final re = spec[0] as RegExp;
        final label = spec[1] as String;
        for (final m in re.allMatches(src)) {
          final args = _balancedArgs(src, m.end - 1);
          final stripped = _stripSpacingTokens(args);
          if (_hasNonZeroBareNumber(stripped)) {
            final ln = _lineAt(src, m.start);
            final flat = args.replaceAll(RegExp(r'\s+'), ' ').trim();
            violations.add('$path:$ln  [$label] bare number in args: [$flat]');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'hardcoded visual values found:\n${violations.join('\n')}',
    );
  });
}
