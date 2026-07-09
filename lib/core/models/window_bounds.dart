// WindowBounds：窗口矩形（logical px）——x/y 左上角坐标 + 宽/高。
//
// 属应用配置（随 AppPreferences 落 config/preferences.json），刻意不入 PG。
// 手写不可变值类（与 AppPreferences 同例外）：避免为一个坐标 DTO 引 freezed/代码生成。
import 'package:flutter/foundation.dart';

@immutable
class WindowBounds {
  const WindowBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  double get left => x;
  double get top => y;
  double get right => x + width;
  double get bottom => y + height;

  Map<String, Object?> toMap() => <String, Object?>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  /// 容错解析：任一字段缺失/类型不符/宽高非正 → 返回 null（视为无有效记忆），绝不抛。
  static WindowBounds? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final x = raw['x'];
    final y = raw['y'];
    final w = raw['width'];
    final h = raw['height'];
    if (x is! num || y is! num || w is! num || h is! num) return null;
    if (w <= 0 || h <= 0) return null;
    return WindowBounds(
      x: x.toDouble(),
      y: y.toDouble(),
      width: w.toDouble(),
      height: h.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowBounds &&
          other.x == x &&
          other.y == y &&
          other.width == width &&
          other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'WindowBounds($x, $y, $width, $height)';
}
