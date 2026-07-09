// clampBoundsToVisible 纯函数单测（PL-6 多显示器 clamp）——假坐标、headless。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/window_bounds.dart';
import 'package:inkframe/services/window_state_service.dart';

void main() {
  // 主显示器工作区（扣任务栏）：1920x1040 @ 原点。
  const primary = WindowBounds(x: 0, y: 0, width: 1920, height: 1040);
  // 右侧第二显示器：1280x1024 @ x=1920。
  const secondary = WindowBounds(x: 1920, y: 0, width: 1280, height: 1024);

  test('完整落在可见显示器内 → 原样返回', () {
    const saved = WindowBounds(x: 200, y: 150, width: 1000, height: 700);
    expect(clampBoundsToVisible(saved, <WindowBounds>[primary]), saved);
  });

  test('显示器已拔（与任何可见工作区都不相交）→ null（退默认）', () {
    // 保存在原第二显示器坐标，如今只剩主屏。
    const saved = WindowBounds(x: 2200, y: 100, width: 800, height: 600);
    expect(clampBoundsToVisible(saved, <WindowBounds>[primary]), isNull);
  });

  test('部分越界 → clamp 进相交最多的显示器（结果完整可见）', () {
    // 右下越界：右边超出 1920，下边超出 1040，但仍与主屏相交。
    const saved = WindowBounds(x: 1600, y: 900, width: 800, height: 600);
    final r = clampBoundsToVisible(saved, <WindowBounds>[primary])!;
    // 尺寸不变（未超工作区），位置被推回可见区内。
    expect(r.width, 800);
    expect(r.height, 600);
    expect(r.left >= primary.left, isTrue);
    expect(r.top >= primary.top, isTrue);
    expect(r.right <= primary.right, isTrue);
    expect(r.bottom <= primary.bottom, isTrue);
    expect(r, const WindowBounds(x: 1120, y: 440, width: 800, height: 600));
  });

  test('窗口大于工作区 → 尺寸被夹到工作区大小', () {
    const saved = WindowBounds(x: -50, y: -50, width: 3000, height: 2000);
    final r = clampBoundsToVisible(saved, <WindowBounds>[primary])!;
    expect(r.width, primary.width);
    expect(r.height, primary.height);
    expect(r.left, primary.left);
    expect(r.top, primary.top);
  });

  test('多显示器 → 落在相交面积最大的那块', () {
    // 大部分身处第二显示器，小部分探入主屏。
    const saved = WindowBounds(x: 1850, y: 100, width: 600, height: 400);
    final r = clampBoundsToVisible(saved, <WindowBounds>[primary, secondary])!;
    // 相交面积第二屏更大 → 落到第二屏，且完整可见。
    expect(r.left >= secondary.left, isTrue);
    expect(r.right <= secondary.right, isTrue);
    expect(r.top >= secondary.top, isTrue);
    expect(r.bottom <= secondary.bottom, isTrue);
  });

  test('无任何显示器 → null（退默认）', () {
    const saved = WindowBounds(x: 0, y: 0, width: 800, height: 600);
    expect(clampBoundsToVisible(saved, const <WindowBounds>[]), isNull);
  });
}
