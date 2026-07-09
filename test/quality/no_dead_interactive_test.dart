// 死交互回归闸（CV-1）：扫 lib/**/*.dart，禁止空实现的交互回调上线。
// 「看似可点但点了没反应」的死按钮 = onTap/onPressed 等指针交互回调挂空闭包。
// 判定口径：交互回调名单（tap/press/pointer 族）+ `(…) {}` / `(…) async {}` 空体。
// 合法形态不会命中：
//   - onTap: null（GestureDetector 直接不捕获，不产生假交互）
//   - onChanged: (_) => setState(() {})（箭头体有真实语义）
//   - setState(() {})（函数调用，非命名回调实参）
//   - onError: (…) {}（非 UI 交互回调，不在名单内）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.contains('l10n/generated/') ||
    p.contains('generated/');

int _lineAt(String src, int charIdx) =>
    '\n'.allMatches(src.substring(0, charIdx)).length + 1;

void main() {
  // 指针交互回调名单：on<交互>[Down|Up|Cancel]? : (params) {} / async {}。
  final deadHandler = RegExp(
    r'\bon(?:Tap|DoubleTap|LongPress|SecondaryTap|TertiaryTap|Pressed'
    r'|PointerDown|PointerUp)(?:Down|Up|Cancel)?'
    r'\s*:\s*\(\s*[_a-zA-Z0-9,\s]*\)\s*(async\s*)?\{\s*\}',
  );

  test('lib 下无空交互回调（onTap/onPressed 等不得挂空闭包）', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ not found');

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || _isGenerated(path)) continue;

      final src = entity.readAsStringSync();
      for (final m in deadHandler.allMatches(src)) {
        final snippet = m.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
        violations.add('$path:${_lineAt(src, m.start)}  $snippet');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'dead interactive handlers found (empty closure):\n'
          '${violations.join('\n')}',
    );
  });
}
