// CanvasSelectionController 单测 —— 纯 UI 状态，不接 DB。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';

void main() {
  late ProviderContainer container;
  late CanvasSelectionController ctrl;

  setUp(() {
    container = ProviderContainer();
    ctrl = container.read(canvasSelectionControllerProvider.notifier);
  });
  tearDown(() => container.dispose());

  Set<String> s() => container.read(canvasSelectionControllerProvider);

  group('CanvasSelectionController', () {
    test('初始为空', () {
      expect(s(), isEmpty);
    });

    test('select 单选替换', () {
      ctrl.select('a');
      expect(s(), {'a'});
      ctrl.select('b');
      expect(s(), {'b'});
    });

    test('select toggle 多选', () {
      ctrl.select('a');
      ctrl.select('b', toggle: true);
      expect(s(), {'a', 'b'});
      ctrl.select('a', toggle: true);
      expect(s(), {'b'});
    });

    test('clear', () {
      ctrl.select('a');
      ctrl.clear();
      expect(s(), isEmpty);
    });

    test('removed 清掉已选 id', () {
      ctrl.select('a');
      ctrl.select('b', toggle: true);
      ctrl.removed('a');
      expect(s(), {'b'});
    });

    test('removed 未选中 id 不改变 state 引用', () {
      ctrl.select('a');
      final before = s();
      ctrl.removed('zzz');
      expect(identical(s(), before), isTrue);
    });

    test('selectAll 整体替换为给定集合', () {
      ctrl.select('x');
      ctrl.selectAll(<String>['a', 'b', 'c']);
      expect(s(), {'a', 'b', 'c'});
    });

    test('selectAll 集合等价时不改变 state 引用', () {
      ctrl.selectAll(<String>['a', 'b']);
      final before = s();
      ctrl.selectAll(<String>['b', 'a']); // 顺序不同但等价
      expect(identical(s(), before), isTrue);
    });
  });
}
