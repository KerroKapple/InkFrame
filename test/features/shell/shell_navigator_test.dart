// ShellNavigator：地基合同 + 通知语义。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

void main() {
  const p1 = ProjectRef(id: 'p1', name: 'Alpha');

  ProviderContainer makeContainer([ShellState initial = const ShellState()]) {
    final c = ProviderContainer(overrides: <Override>[
      shellControllerProvider.overrideWith(() => ShellNavigator(initial: initial)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  // 这是整个 PR 的地基合同：写在第一条，任何违反它的改动都当场红。
  test('地基合同：切标签绝不改 canvasId', () {
    final c = makeContainer(const ShellState(tab: ShellTab.canvas, canvasId: 'c1'));
    c.read(shellControllerProvider.notifier).goTab(ShellTab.gallery);
    expect(c.read(shellControllerProvider).canvasId, 'c1');
  });

  test('幂等：连续两次同迁移只通知一次', () {
    final c = makeContainer();
    var notifications = 0;
    final sub = c.listen(shellControllerProvider, (_, _) => notifications++);
    addTearDown(sub.close);

    c.read(shellControllerProvider.notifier).goTab(ShellTab.gallery);
    c.read(shellControllerProvider.notifier).goTab(ShellTab.gallery);

    expect(notifications, 1, reason: '_set 的 if (next == state) return 与 updateShouldNotify 双保险');
  });

  test('updateShouldNotify 用值相等而非 identical', () {
    // riverpod-2.6.1/lib/src/notifier.dart:113-115 默认是 !identical(previous, next)，
    // 而外壳每次导航都构造新实例——不覆写就会在每次切标签时唤醒全体订阅者。
    final nav = ShellNavigator();
    // 非 const 构造：两次调用产生两个不同实例（const 会被 Dart 常量池折叠成同一个
    // 对象，identical 恒真，测不出"值相等但非同一实例"这条真实场景）。
    // ignore: prefer_const_constructors
    final a = ShellState(tab: ShellTab.gallery);
    // ignore: prefer_const_constructors
    final b = ShellState(tab: ShellTab.gallery);
    expect(identical(a, b), isFalse);
    expect(nav.updateShouldNotify(a, b), isFalse);
    expect(nav.updateShouldNotify(a, const ShellState(tab: ShellTab.canvas)), isTrue);
  });

  test('select(canvasId) 在切标签时不通知', () {
    final c = makeContainer(const ShellState(tab: ShellTab.canvas, canvasId: 'c1'));
    var hits = 0;
    final sub = c.listen(
      shellControllerProvider.select((ShellState s) => s.canvasId), (_, _) => hits++);
    addTearDown(sub.close);

    c.read(shellControllerProvider.notifier).goTab(ShellTab.gallery);
    expect(hits, 0, reason: '画布子树不该因为用户瞥了一眼画廊就整棵重建');
  });

  test('openGallery / openOverlay / closeOverlay 委托语义与 ShellState 一致', () {
    final c = makeContainer(const ShellState(tab: ShellTab.canvas, canvasId: 'c1'));
    final nav = c.read(shellControllerProvider.notifier);
    nav.openGallery(p1);
    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
    expect(c.read(shellControllerProvider).canvasId, 'c1');
    nav.openOverlay(ShellOverlay.settings);
    expect(c.read(shellControllerProvider).overlay, ShellOverlay.settings);
    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
    nav.closeOverlay();
    expect(c.read(shellControllerProvider).overlay, isNull);
    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
  });
}
