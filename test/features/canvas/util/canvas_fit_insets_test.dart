// 适应视口的留白（canvas_tool_actions.canvasFitInsets）：提示词条不显示时就是基本留白；显示时底部让出条子
// （条高 + promptBarClearance），与缩放条那一截取大的。外壳里真按 Shift+1 的效果见
// test/features/shell/shell_canvas_fit_test.dart。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/canvas_tool_actions.dart';
import 'package:inkframe/theme/tokens.dart';

void main() {
  test('条子不显示（高 0）：就是基本留白', () {
    expect(canvasFitInsets(promptBarHeight: 0), kCanvasFitInsets);
  });

  test('条子显示：底部 = 条高 + promptBarClearance，其余三边不动', () {
    final insets = canvasFitInsets(promptBarHeight: 100);
    expect(insets.bottom, 100 + InkToolbarSize.promptBarClearance);
    expect(insets.top, kCanvasFitInsets.top);
    expect(insets.left, kCanvasFitInsets.left);
    expect(insets.right, kCanvasFitInsets.right);
  });

  test('条子矮到让出的比缩放条那一截还少：仍按缩放条那一截', () {
    expect(canvasFitInsets(promptBarHeight: 4).bottom, InkToolbarSize.stageBottomInset);
  });
}
