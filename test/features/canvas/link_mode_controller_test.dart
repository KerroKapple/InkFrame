// LinkModeController 单测——状态机 start / cancel。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';

void main() {
  late ProviderContainer container;
  late LinkModeController ctrl;

  setUp(() {
    container = ProviderContainer();
    ctrl = container.read(linkModeControllerProvider.notifier);
  });
  tearDown(() => container.dispose());

  String? s() => container.read(linkModeControllerProvider);

  test('初始 null', () {
    expect(s(), isNull);
    expect(ctrl.active, isFalse);
  });

  test('start 进入连线模式', () {
    ctrl.start('n1');
    expect(s(), 'n1');
    expect(ctrl.active, isTrue);
    expect(ctrl.sourceNodeId, 'n1');
  });

  test('start 覆盖前一次起点', () {
    ctrl.start('n1');
    ctrl.start('n2');
    expect(s(), 'n2');
  });

  test('cancel 回到 idle', () {
    ctrl.start('n1');
    ctrl.cancel();
    expect(s(), isNull);
    expect(ctrl.active, isFalse);
  });

  test('cancel 在 idle 状态幂等（不触发 rebuild）', () {
    final before = s();
    ctrl.cancel();
    expect(identical(s(), before), isTrue);
  });
}
