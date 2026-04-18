// CanvasViewModel 单元测试：节点增删移 + 选中态。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_view_model.dart';

void main() {
  late ProviderContainer container;
  late CanvasViewModel vm;

  setUp(() {
    container = ProviderContainer();
    vm = container.read(canvasViewModelProvider.notifier);
  });

  tearDown(() => container.dispose());

  CanvasState s() => container.read(canvasViewModelProvider);

  group('CanvasViewModel', () {
    test('初始态为空', () {
      expect(s().nodes, isEmpty);
      expect(s().selectedIds, isEmpty);
    });

    test('addNode 新增节点', () {
      vm.addNode(label: 'A', type: CanvasNodeType.image);
      expect(s().nodes, hasLength(1));
      expect(s().nodes.first.label, 'A');
      expect(s().nodes.first.type, CanvasNodeType.image);
    });

    test('addNode 多个节点顺序保留', () {
      vm.addNode(label: 'A', type: CanvasNodeType.image);
      vm.addNode(label: 'B', type: CanvasNodeType.text);
      expect(s().nodes.map((n) => n.label).toList(), ['A', 'B']);
    });

    test('addNode 指定位置', () {
      vm.addNode(
        label: 'X',
        type: CanvasNodeType.image,
        position: const Offset(100, 200),
      );
      expect(s().nodes.first.position, const Offset(100, 200));
    });

    test('removeNode 删除节点 + 清对应选中', () {
      vm.addNode(label: 'A', type: CanvasNodeType.image);
      final id = s().nodes.first.id;
      vm.select(id);
      expect(s().selectedIds, contains(id));
      vm.removeNode(id);
      expect(s().nodes, isEmpty);
      expect(s().selectedIds, isEmpty);
    });

    test('select 单选替换', () {
      vm.addNode(label: 'A', type: CanvasNodeType.image);
      vm.addNode(label: 'B', type: CanvasNodeType.text);
      final idA = s().nodes[0].id;
      final idB = s().nodes[1].id;
      vm.select(idA);
      expect(s().selectedIds, {idA});
      vm.select(idB);
      expect(s().selectedIds, {idB});
    });

    test('select toggle 多选', () {
      vm.addNode(label: 'A', type: CanvasNodeType.image);
      vm.addNode(label: 'B', type: CanvasNodeType.text);
      final idA = s().nodes[0].id;
      final idB = s().nodes[1].id;
      vm.select(idA);
      vm.select(idB, toggle: true);
      expect(s().selectedIds, {idA, idB});
      vm.select(idA, toggle: true);
      expect(s().selectedIds, {idB});
    });

    test('clearSelection 清空', () {
      vm.addNode(label: 'A', type: CanvasNodeType.image);
      vm.select(s().nodes.first.id);
      vm.clearSelection();
      expect(s().selectedIds, isEmpty);
    });

    test('moveNode 移动位置', () {
      vm.addNode(label: 'A', type: CanvasNodeType.image);
      final id = s().nodes.first.id;
      vm.moveNode(id, const Offset(10, 20));
      expect(s().nodes.first.position, const Offset(10, 20));
      vm.moveNode(id, const Offset(-5, 3));
      expect(s().nodes.first.position, const Offset(5, 23));
    });
  });
}
