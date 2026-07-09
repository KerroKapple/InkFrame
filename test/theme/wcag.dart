// 测试共享工具：WCAG 相对亮度对比率。
import 'package:flutter/widgets.dart';

/// WCAG 对比率 (L1+0.05)/(L2+0.05)，L1 取较亮色；AA 正文阈值 4.5:1。
double wcagContrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
