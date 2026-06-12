// pickRandomNodePosition：注入 Random 后确定可测 + 落点范围正确。
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/node_position.dart';

void main() {
  test('同 seed 结果确定', () {
    final a = pickRandomNodePosition(Random(42));
    final b = pickRandomNodePosition(Random(42));
    expect(a, b);
  });

  test('落点始终在 [200, 600) 区间', () {
    final rand = Random(7);
    for (var i = 0; i < 100; i++) {
      final p = pickRandomNodePosition(rand);
      expect(p.dx, inInclusiveRange(200, 600));
      expect(p.dy, inInclusiveRange(200, 600));
    }
  });
}
