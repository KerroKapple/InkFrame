// LaneCollapseController 单测——toggle 增删、build 初始空集。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/lane_collapse_controller.dart';

void main() {
  late ProviderContainer container;
  late LaneCollapseController ctrl;

  setUp(() {
    container = ProviderContainer();
    ctrl = container.read(laneCollapseProvider('cv').notifier);
  });
  tearDown(() => container.dispose());

  Set<String> s() => container.read(laneCollapseProvider('cv'));

  test('build 返回空集', () {
    expect(s(), isEmpty);
  });

  test('toggle 添加 id', () {
    ctrl.toggle('a');
    expect(s(), {'a'});
    expect(ctrl.isCollapsed('a'), isTrue);
  });

  test('toggle 再次调用移除 id', () {
    ctrl.toggle('a');
    ctrl.toggle('a');
    expect(s(), isEmpty);
    expect(ctrl.isCollapsed('a'), isFalse);
  });

  test('toggle 多个 id 独立管理', () {
    ctrl.toggle('a');
    ctrl.toggle('b');
    expect(s(), {'a', 'b'});
    ctrl.toggle('a');
    expect(s(), {'b'});
  });

  test('不同 family 参数互不干扰', () {
    final ctrl2 = container.read(laneCollapseProvider('cv2').notifier);
    ctrl.toggle('a');
    expect(container.read(laneCollapseProvider('cv2')), isEmpty);
    ctrl2.toggle('b');
    expect(s(), {'a'});
  });
}
