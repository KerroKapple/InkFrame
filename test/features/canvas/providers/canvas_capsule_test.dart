// 画布轻提示胶囊的控制器（providers/canvas_capsule.dart）：一次一条、按类型停留、同 dedupeKey 原地改字并重新计时、
// 悬停停表移出续剩余、两张画布互不串、回收时计时器跟着停。
//
// provider 是 autoDispose：每条用例先 container.listen 订住再操作，否则 read 完即回收、计时器被取消。
// 时间全走 fakeAsync——容器建在 fakeAsync 体内，控制器的计时器才挂在假时钟上。
//
// 变异对照：
//   - 同 dedupeKey 分支不重启计时 ⇒「同 dedupeKey 原地改字并重新计时」红（0.8 + 1.0 s 时已经收了）；
//   - 同 dedupeKey 分支去掉（总是新开一张）⇒「同 dedupeKey：不换卡」红（serial 变了）；宿主那边「不重放淡入」也红；
//   - kCanvasCapsuleZoomDwell 改成 2 s ⇒「zoom 1.2 s 后收」红；
//   - setHovered(true) 不停表 ⇒「悬停停表」红；移出从头计时 ⇒ 同一用例「再 0.5 s 收」那步红；
//   - ref.onDispose 不取消计时器 ⇒「回收时取消计时器」红。
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';

const Duration _ms1 = Duration(milliseconds: 1);

/// 建容器、订住 [canvasId] 的胶囊，返回容器与控制器。须在 fakeAsync 体内调用。
(ProviderContainer, CanvasCapsuleController) _setUp([String canvasId = 'c1']) {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  final ProviderSubscription<CanvasCapsuleMessage?> sub =
      container.listen(canvasCapsuleProvider(canvasId), (_, _) {});
  addTearDown(sub.close);
  return (container, container.read(canvasCapsuleProvider(canvasId).notifier));
}

CanvasCapsuleMessage _action() => CanvasCapsuleMessage(
      text: 'Undone · Move 3 nodes',
      kind: CanvasCapsuleKind.action,
      actionLabel: 'Redo',
      actionHint: 'Ctrl Y',
      onAction: () {},
    );

void main() {
  test('默认没有胶囊', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, _) = _setUp();
      expect(c.read(canvasCapsuleProvider('c1')), isNull);
    });
  });

  test('text 2 s 后收（差 1 ms 还在）', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(const CanvasCapsuleMessage(text: 'Done'));
      async.elapse(kCanvasCapsuleTextDwell - _ms1);
      expect(c.read(canvasCapsuleProvider('c1')), isNotNull);
      async.elapse(_ms1);
      expect(c.read(canvasCapsuleProvider('c1')), isNull);
    });
  });

  test('action 4 s 后收（差 1 ms 还在）', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(_action());
      async.elapse(kCanvasCapsuleActionDwell - _ms1);
      expect(c.read(canvasCapsuleProvider('c1')), isNotNull);
      async.elapse(_ms1);
      expect(c.read(canvasCapsuleProvider('c1')), isNull);
    });
  });

  test('zoom 1.2 s 后收（差 1 ms 还在）', () {
    expect(kCanvasCapsuleZoomDwell, const Duration(milliseconds: 1200));
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(const CanvasCapsuleMessage.zoom(80));
      async.elapse(const Duration(milliseconds: 1199));
      expect(c.read(canvasCapsuleProvider('c1')), isNotNull);
      async.elapse(_ms1);
      expect(c.read(canvasCapsuleProvider('c1')), isNull);
    });
  });

  test('三档停留：text 2 s、action 4 s、zoom 1.2 s', () {
    expect(kCanvasCapsuleTextDwell, const Duration(seconds: 2));
    expect(kCanvasCapsuleActionDwell, const Duration(seconds: 4));
    expect(kCanvasCapsuleZoomDwell, const Duration(milliseconds: 1200));
  });

  test('showZoom：比例取整成百分比，kind = zoom，dedupeKey = zoom', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      ctrl.showZoom(1 / 1.2);
      final CanvasCapsuleMessage? m = c.read(canvasCapsuleProvider('c1'));
      expect(m?.zoomPercent, 83);
      expect(m?.kind, CanvasCapsuleKind.zoom);
      expect(m?.dedupeKey, kCanvasCapsuleZoomKey);
      expect(m?.onAction, isNull);
    });
  });

  test('新消息顶掉旧消息', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      const CanvasCapsuleMessage first = CanvasCapsuleMessage(text: 'First');
      const CanvasCapsuleMessage second = CanvasCapsuleMessage(text: 'Second');
      ctrl.show(first);
      final int firstSerial = ctrl.serial;
      ctrl.show(second);
      expect(c.read(canvasCapsuleProvider('c1')), same(second));
      expect(ctrl.serial, isNot(firstSerial), reason: '不同消息换一张卡（宿主交叉淡入）');
    });
  });

  test('不同 dedupeKey 之间也是换卡', () {
    fakeAsync((FakeAsync async) {
      final (_, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(const CanvasCapsuleMessage(text: 'A', dedupeKey: 'a'));
      final int s = ctrl.serial;
      ctrl.show(const CanvasCapsuleMessage(text: 'B', dedupeKey: 'b'));
      expect(ctrl.serial, isNot(s));
    });
  });

  test('同 dedupeKey：不换卡（serial 不变），只换字', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(const CanvasCapsuleMessage.zoom(80));
      final int s = ctrl.serial;
      ctrl.show(const CanvasCapsuleMessage.zoom(96));
      expect(ctrl.serial, s);
      expect(c.read(canvasCapsuleProvider('c1'))?.zoomPercent, 96);
    });
  });

  test('收掉之后再来同 dedupeKey 的：是新的一张（serial 变）', () {
    fakeAsync((FakeAsync async) {
      final (_, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(const CanvasCapsuleMessage.zoom(80));
      final int s = ctrl.serial;
      async.elapse(kCanvasCapsuleZoomDwell);
      ctrl.show(const CanvasCapsuleMessage.zoom(80));
      expect(ctrl.serial, isNot(s));
    });
  });

  test('同 dedupeKey 原地改字并重新计时：80 → 0.8 s 后 96 → 再 1.0 s 仍在、再 0.2 s 收', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(const CanvasCapsuleMessage.zoom(80));
      async.elapse(const Duration(milliseconds: 800));
      ctrl.show(const CanvasCapsuleMessage.zoom(96));
      expect(c.read(canvasCapsuleProvider('c1'))?.zoomPercent, 96);
      async.elapse(const Duration(milliseconds: 1000));
      expect(c.read(canvasCapsuleProvider('c1'))?.zoomPercent, 96, reason: '计时从第二次算起，还没到 1.2 s');
      async.elapse(const Duration(milliseconds: 200));
      expect(c.read(canvasCapsuleProvider('c1')), isNull);
    });
  });

  test('悬停停表、移出续剩余：1.5 s 悬停 → 10 s 仍在 → 移出 0.4 s 仍在、0.5 s 收', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(const CanvasCapsuleMessage(text: 'Done'));
      async.elapse(const Duration(milliseconds: 1500));
      ctrl.setHovered(true);
      async.elapse(const Duration(seconds: 10));
      expect(c.read(canvasCapsuleProvider('c1')), isNotNull, reason: '悬停时不收');
      ctrl.setHovered(false);
      async.elapse(const Duration(milliseconds: 400));
      expect(c.read(canvasCapsuleProvider('c1')), isNotNull, reason: '还剩 0.1 s');
      async.elapse(const Duration(milliseconds: 100));
      expect(c.read(canvasCapsuleProvider('c1')), isNull, reason: '按剩余 0.5 s 续跑，不是从头算 2 s');
    });
  });

  test('悬停时来了新消息：停着不走，移出后按新消息的停留算', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(const CanvasCapsuleMessage(text: 'A'));
      ctrl.setHovered(true);
      ctrl.show(const CanvasCapsuleMessage.zoom(120));
      async.elapse(const Duration(seconds: 5));
      expect(c.read(canvasCapsuleProvider('c1'))?.zoomPercent, 120);
      ctrl.setHovered(false);
      async.elapse(kCanvasCapsuleZoomDwell - _ms1);
      expect(c.read(canvasCapsuleProvider('c1')), isNotNull);
      async.elapse(_ms1);
      expect(c.read(canvasCapsuleProvider('c1')), isNull);
    });
  });

  test('dismiss 立即收，之后计时器不再动它', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController ctrl) = _setUp();
      ctrl.show(const CanvasCapsuleMessage(text: 'Done'));
      ctrl.dismiss();
      expect(c.read(canvasCapsuleProvider('c1')), isNull);
      expect(async.periodicTimerCount, 0, reason: '收了就不该还有计时器在跑');
      async.elapse(const Duration(seconds: 5));
      expect(c.read(canvasCapsuleProvider('c1')), isNull);
    });
  });

  test('带动作的消息必须是 action 类（debug 断言）', () {
    fakeAsync((FakeAsync async) {
      final (_, CanvasCapsuleController ctrl) = _setUp();
      expect(
        () => ctrl.show(CanvasCapsuleMessage(text: 'x', actionLabel: 'Redo', onAction: () {})),
        throwsAssertionError,
      );
    });
  });

  test('回收时取消计时器：container.dispose() 后推进时间不抛、没有残留计时器', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = ProviderContainer();
      final ProviderSubscription<CanvasCapsuleMessage?> sub =
          container.listen(canvasCapsuleProvider('c1'), (_, _) {});
      container.read(canvasCapsuleProvider('c1').notifier).show(_action());
      expect(async.periodicTimerCount, 1);
      sub.close();
      container.dispose();
      expect(async.periodicTimerCount, 0);
      async.elapse(const Duration(seconds: 10));
    });
  });

  test('两个 canvasId 互不影响', () {
    fakeAsync((FakeAsync async) {
      final (ProviderContainer c, CanvasCapsuleController a) = _setUp('a');
      final ProviderSubscription<CanvasCapsuleMessage?> subB =
          c.listen(canvasCapsuleProvider('b'), (_, _) {});
      addTearDown(subB.close);
      final CanvasCapsuleController b = c.read(canvasCapsuleProvider('b').notifier);

      a.show(const CanvasCapsuleMessage.zoom(120));
      expect(c.read(canvasCapsuleProvider('b')), isNull);

      b.show(const CanvasCapsuleMessage(text: 'B'));
      b.dismiss();
      expect(c.read(canvasCapsuleProvider('a'))?.zoomPercent, 120, reason: 'B 的收起不动 A');

      b.show(const CanvasCapsuleMessage(text: 'B'));
      b.setHovered(true);
      async.elapse(kCanvasCapsuleZoomDwell);
      expect(c.read(canvasCapsuleProvider('a')), isNull, reason: 'B 的悬停不替 A 停表');
      expect(c.read(canvasCapsuleProvider('b')), isNotNull);
    });
  });
}
