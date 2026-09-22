// 画布网格底（Workspace v2 稿：24px 网格，1px canvasGrid 线；屏幕空间，不随缩放）。
import 'package:flutter/rendering.dart';

class CanvasGridPainter extends CustomPainter {
  const CanvasGridPainter(this.color, {this.step = 24});

  final Color color;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(CanvasGridPainter old) => old.color != color || old.step != step;
}
