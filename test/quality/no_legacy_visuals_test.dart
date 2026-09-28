// V0 收口守卫：旧「Amber Noir」暖色 ramp 与衬线字体家族在 lib/ 下零残留。
//
// 任务书 §2「tokens_test 必补 5」：命中即红。扫描 lib/**/*.dart（含 token 真相
// 源——它正是最容易被"顺手保留一个别名"的地方），另扫 pubspec.yaml 的字体声明。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 旧暖色 ramp 六档 + 三个暖灰前景。大小写不敏感，匹配 `0x??RRGGBB` 与 `#RRGGBB`。
final RegExp _warmHex = RegExp(
  r'(0x[0-9A-Fa-f]{2}|#)(0B0908|100C0A|15110E|1C1814|2A2520|36302A|'
  r'E8DFD0|B5A89A|8A7E70)\b',
  caseSensitive: false,
);

/// 任何 serif 家族名：Cormorant / Garamond / Noto Serif / 裸 serif 家族声明。
final RegExp _serifFamily = RegExp(
  r"Cormorant|Garamond|Noto Serif|fontFamily:\s*'serif'",
  caseSensitive: false,
);

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.contains('${Platform.pathSeparator}generated'));

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

  test('lib/ 与 pubspec.yaml 无衬线字体家族', () {
    final hits = <String>[];
    final files = <File>[..._dartFiles(Directory('lib')), File('pubspec.yaml')];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_serifFamily.hasMatch(lines[i])) {
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
