// 提示词条宽度随舞台走（提示词条与节点文字稿）：舞台宽 × 0.6，夹在 480–880；
// 舞台窄于 512（放不下 480 + 两侧 16）时改取舞台宽减两侧 16。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/prompt_bar_width.dart';
import 'package:inkframe/theme/tokens.dart';

void main() {
  test('窄舞台 697：0.6 倍只有 418 → 落在下限 480', () {
    expect(promptBarWidth(697), 480);
  });

  test('中等舞台 1014：取 60% = 608.4', () {
    expect(promptBarWidth(1014), closeTo(608.4, 1e-9));
  });

  test('宽舞台 1977：0.6 倍 1186 → 封顶 880', () {
    expect(promptBarWidth(1977), 880);
  });

  test('舞台 500 放不下 480 + 两侧 16 → 舞台宽减两侧 16 = 468', () {
    expect(promptBarWidth(500), 468);
  });

  test('512 是两段规则的接缝：511 → 479，512 → 480，首尾相接', () {
    expect(promptBarWidth(511), 479);
    expect(promptBarWidth(512), 480);
  });

  test('窄到不足两侧边距 → 0，不出负宽', () {
    expect(promptBarWidth(20), 0);
  });

  test('父级不限宽（infinity）→ 封顶 880', () {
    expect(promptBarWidth(double.infinity), 880);
  });

  group('promptBarPlacement', () {
    test('居中压不到左下那一簇：照常居中', () {
      final ({double left, double width}) p = promptBarPlacement(1014);
      expect(p.width, closeTo(608.4, 0.01));
      expect(p.left, closeTo((1014 - 608.4) / 2, 0.01));
    });

    test('居中会压到：在预留区右边那段里居中', () {
      final ({double left, double width}) p = promptBarPlacement(697);
      expect(p.width, 480);
      expect(p.left, closeTo(InkToolbarSize.stageBottomLeftReserve + (697 - 176 - 16 - 480) / 2, 0.01));
      expect(p.left + p.width, lessThanOrEqualTo(697 - 16));
    });

    test('右边那段放不下：收窄到那段的宽度；窄到没有就是 0，不出负宽', () {
      expect(promptBarPlacement(500).width, 500 - 176 - 16);
      expect(promptBarPlacement(150).width, 0);
    });

    test('不限宽（infinity）：照旧取上限、不算左沿', () {
      final ({double left, double width}) p = promptBarPlacement(double.infinity);
      expect(p.width, 880);
      expect(p.left, 0);
    });
  });

}
