// 提示词条宽度随舞台走（提示词条与节点文字稿）：舞台宽 × 0.6，夹在 480–880；
// 舞台窄于 512（放不下 480 + 两侧 16）时改取舞台宽减两侧 16。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/prompt_bar_width.dart';

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
}
