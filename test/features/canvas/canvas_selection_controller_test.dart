// CanvasSelectionController 单测 —— 纯 UI 状态，不接 DB。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';

void main() {
  late ProviderContainer container;
  late CanvasSelectionController ctrl;

  const canvasId = 'c1';

  setUp(() {
    container = ProviderContainer();
    ctrl = container.read(canvasSelectionControllerProvider(canvasId).notifier);
  });
  tearDown(() => container.dispose());

  Set<String> s() => container.read(canvasSelectionControllerProvider(canvasId));

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

    // 批量方法（框选 / 浮动条 / 对齐等共用的集合运算）：结果与当前集合相等时一律不赋值。
    test('replace 整体替换', () {
      ctrl.select('a');
      ctrl.replace(<String>['b', 'c']);
      expect(s(), {'b', 'c'});
    });

    test('replace 集合相等时不改变 state 引用', () {
      ctrl.replace(<String>['a', 'b']);
      final before = s();
      ctrl.replace(<String>['b', 'a']);
      expect(identical(s(), before), isTrue);
    });

    test('replace 空集 = 清空', () {
      ctrl.select('a');
      ctrl.replace(const <String>[]);
      expect(s(), isEmpty);
    });

    test('addAll 并入，已在的不重复', () {
      ctrl.select('a');
      ctrl.addAll(<String>['a', 'b']);
      expect(s(), {'a', 'b'});
    });

    test('addAll 没有新增时不改变引用', () {
      ctrl.replace(<String>['a', 'b']);
      final before = s();
      ctrl.addAll(<String>['b', 'a']);
      expect(identical(s(), before), isTrue);
      ctrl.addAll(const <String>[]);
      expect(identical(s(), before), isTrue);
    });

    test('toggleAll 逐个取反', () {
      ctrl.replace(<String>['a', 'b']);
      ctrl.toggleAll(<String>['b', 'c']);
      expect(s(), {'a', 'c'});
    });

    test('toggleAll 空输入不改变引用', () {
      ctrl.replace(<String>['a']);
      final before = s();
      ctrl.toggleAll(const <String>[]);
      expect(identical(s(), before), isTrue);
    });

    test('removeAll 只去掉在的', () {
      ctrl.replace(<String>['a', 'b']);
      ctrl.removeAll(<String>['b', 'x']);
      expect(s(), {'a'});
    });

    test('removeAll 一个都不在时不改变引用', () {
      ctrl.replace(<String>['a', 'b']);
      final before = s();
      ctrl.removeAll(<String>['x', 'y']);
      expect(identical(s(), before), isTrue);
      ctrl.removeAll(const <String>[]);
      expect(identical(s(), before), isTrue);
    });
  });
}
