// 居中定舞台几何单测——全向无限画布的坐标换算与常量约束。
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';

void main() {
  test('世界原点位于舞台正中央', () {
    expect(kStageOrigin, const Offset(kStageHalf, kStageHalf));
    expect(kStageSize, const Size(kStageHalf * 2, kStageHalf * 2));
  });

  test('worldToStage / stageToWorld 互逆，负坐标合法', () {
    for (final w in const [
      Offset.zero,
      Offset(100, 200),
      Offset(-3000, -4500),
      Offset(-kWorldReach, kWorldReach),
    ]) {
      expect(stageToWorld(worldToStage(w)), w);
    }
  });

  test('可漫游范围映射后不越出舞台（含节点自身尺寸余量）', () {
    // 极限世界坐标 ±kWorldReach 映射进舞台后距边缘 ≥2000，够放一张卡片。
    final min = worldToStage(const Offset(-kWorldReach, -kWorldReach));
    final max = worldToStage(const Offset(kWorldReach, kWorldReach));
    expect(min.dx, greaterThanOrEqualTo(2000));
    expect(min.dy, greaterThanOrEqualTo(2000));
    expect(max.dx, lessThanOrEqualTo(kStageSize.width - 2000));
    expect(max.dy, lessThanOrEqualTo(kStageSize.height - 2000));
  });
}
