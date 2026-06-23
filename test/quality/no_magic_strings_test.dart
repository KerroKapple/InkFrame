// 魔法字符串回归：把原 check-magic-strings.sh 收窄为可落地的真违例子集固化为 Dart 测试。
//
// 原脚本的双引号正则对本仓（强制 prefer_single_quotes）结构性全盲，魔法数字规则全是 FP，
// 故本测试只保留唯一一类真违例：【UI 子树内裸字面量前缀直接拼接 i18n 调用】，
// 例如 '+ ${l.canvasInspectorAddAttribute}' —— 前缀 '+ ' 是脱离 ARB 的硬编码 UI 文本，
// 会在多语言下漏译。纯插值（'${l.foo}'）或纯占位英文串（mock 屏，接线时随 mock 删除）不在此闸门范围。
//
// 魔法数字规则整条不实现（单位换算/截断上限/布局余量无语义，纯噪音）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _skip(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.endsWith('_test.dart') ||
    p.contains('l10n/') ||
    p.contains('generated/') ||
    p.contains('constants') ||
    p.contains('features/debug/');

void main() {
  // 匹配“可见前缀 + 紧接 l10n 插值”：单引号串内含非空前缀文本，随后是 ${l. / ${context.l10n. / ${loc.
  // 严格只抓前缀拼接，纯插值或后缀场景不命中，避免误伤合法格式化。
  final prefixConcat =
      RegExp(r"""'[^']*[^\s']\s*\$\{(l|context\.l10n|loc)\.""");

  test('lib 下无 i18n 前缀拼接硬编码（裸字面量前缀 + l10n 插值）', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ not found');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (_skip(path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final raw = lines[i];
        final trimmed = raw.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        if (prefixConcat.hasMatch(raw)) {
          violations.add('$path:${i + 1}  prefix-concat i18n: ${raw.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'hardcoded text prefixing i18n call '
          '(move the prefix into the ARB string):\n${violations.join('\n')}',
    );
  });
}
