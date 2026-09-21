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
    // R19：先开一个浮层，让 openGallery 的"清浮层"这一步真正被观测到——
    // 若起始态本来就是 overlay:null，漏清浮层的实现也能让下面的
    // isNull 断言蒙混过关。
    nav.openOverlay(ShellOverlay.settings);
    nav.openGallery(p1);
    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
    expect(c.read(shellControllerProvider).canvasId, 'c1');
    expect(c.read(shellControllerProvider).overlay, isNull,
        reason: 'openGallery 必须清掉已经打开的浮层，不是"起点本来就是 null"的巧合');
    nav.openOverlay(ShellOverlay.settings);
    expect(c.read(shellControllerProvider).overlay, ShellOverlay.settings);
    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
    nav.closeOverlay();
    expect(c.read(shellControllerProvider).overlay, isNull);
    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
  });

  // R17 fix round 1：ShellNavigator 是从 T6 起所有导航接线的唯一入口，
  // 委托接错是静默失效——setProject/openCanvas/resetSession 此前只被
  // ShellState 自身的同名方法测试间接覆盖，navigator 这一层的委托线本身
  // 缺直接用例。变异已证实：把 openCanvas 错接成 closeOverlay，
  // 22 条旧用例全绿——这三条补上后堵住这个缺口。

  test('openCanvas 委托：canvasId 写入传入值，且落在 canvas 标签', () {
    final c = makeContainer(const ShellState(tab: ShellTab.studio, project: p1));
    final nav = c.read(shellControllerProvider.notifier);
    nav.openCanvas('c9');
    expect(c.read(shellControllerProvider).canvasId, 'c9',
        reason: 'openCanvas 特有的状态变化：canvasId 必须变成传入的那个值');
    expect(c.read(shellControllerProvider).tab, ShellTab.canvas,
        reason: 'openCanvas 特有的状态变化：必须落在 canvas 标签');
    expect(c.read(shellControllerProvider).project, p1);
  });

  test('setProject 委托：只换 project，不动 tab 与 canvasId', () {
    const p2 = ProjectRef(id: 'p2', name: 'Beta');
    final c = makeContainer(
        const ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: p1));
    final nav = c.read(shellControllerProvider.notifier);
    nav.setProject(p2);
    expect(c.read(shellControllerProvider).project, p2,
        reason: 'setProject 特有的状态变化：project 必须换成传入值');
    expect(c.read(shellControllerProvider).tab, ShellTab.canvas,
        reason: 'setProject 不该动 tab——否则会和 openGallery/openCanvas 撞车');
    expect(c.read(shellControllerProvider).canvasId, 'c1',
        reason: 'setProject 不该动 canvasId——否则会当场毁掉画布保活');
  });

  test('resetSession 委托：从非平凡起始态回到 isPristine', () {
    final c = makeContainer(const ShellState(
      tab: ShellTab.gallery,
      overlay: ShellOverlay.settings,
      canvasId: 'c1',
      project: p1,
    ));
    final nav = c.read(shellControllerProvider.notifier);
    nav.resetSession();
    expect(c.read(shellControllerProvider).isPristine, isTrue,
        reason: '还原备份后库换了，四项必须真正归零，不是从一个已经很干净的起点混过去');
  });
}
