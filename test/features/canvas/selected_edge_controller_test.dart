// SelectedEdgeController 单测 —— idle / select / clear / 幂等。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';

void main() {
  late ProviderContainer container;
  late SelectedEdgeController ctrl;

  setUp(() {
    container = ProviderContainer();
    ctrl = container.read(selectedEdgeControllerProvider.notifier);
  });
  tearDown(() => container.dispose());

  String? s() => container.read(selectedEdgeControllerProvider);

  test('初始 null', () {
    expect(s(), isNull);
  });

  test('select 设置 id', () {
    ctrl.select('e1');
    expect(s(), 'e1');
  });

  test('select 同 id 幂等（不 rebuild）', () {
    ctrl.select('e1');
    final before = s();
    ctrl.select('e1');
    expect(identical(s(), before), isTrue);
  });

  test('clear 回 null', () {
    ctrl.select('e1');
    ctrl.clear();
    expect(s(), isNull);
  });

  test('clear idle 幂等', () {
    final before = s();
    ctrl.clear();
    expect(identical(s(), before), isTrue);
  });
}
