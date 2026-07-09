import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/window_bounds.dart';

void main() {
  test('toMap/fromMap 往返', () {
    const b = WindowBounds(x: 100, y: 200, width: 1280, height: 720);
    expect(WindowBounds.fromMap(b.toMap()), b);
  });

  test('几何 getter', () {
    const b = WindowBounds(x: 10, y: 20, width: 300, height: 400);
    expect(b.left, 10);
    expect(b.top, 20);
    expect(b.right, 310);
    expect(b.bottom, 420);
  });

  test('fromMap 容错：非 Map / 缺字段 / 类型错 → null', () {
    expect(WindowBounds.fromMap(null), isNull);
    expect(WindowBounds.fromMap('nope'), isNull);
    expect(WindowBounds.fromMap(<String, Object?>{'x': 1, 'y': 2}), isNull);
    expect(
      WindowBounds.fromMap(
          <String, Object?>{'x': 'a', 'y': 2, 'width': 3, 'height': 4}),
      isNull,
    );
  });

  test('fromMap 容错：宽/高非正 → null', () {
    expect(
      WindowBounds.fromMap(
          <String, Object?>{'x': 0, 'y': 0, 'width': 0, 'height': 100}),
      isNull,
    );
    expect(
      WindowBounds.fromMap(
          <String, Object?>{'x': 0, 'y': 0, 'width': 100, 'height': -1}),
      isNull,
    );
  });

  test('fromMap 接受整数并转 double', () {
    final b = WindowBounds.fromMap(
        <String, Object?>{'x': 1, 'y': 2, 'width': 3, 'height': 4});
    expect(b, const WindowBounds(x: 1, y: 2, width: 3, height: 4));
  });

  test('相等与哈希', () {
    const a = WindowBounds(x: 1, y: 2, width: 3, height: 4);
    const b = WindowBounds(x: 1, y: 2, width: 3, height: 4);
    const c = WindowBounds(x: 9, y: 2, width: 3, height: 4);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });
}
