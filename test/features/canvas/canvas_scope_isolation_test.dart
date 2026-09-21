// 画布态按 canvasId 隔离（V1 的硬前提）：c1 的选中/选中边/连线态/视口尺寸
// 一律不得被 c2 读到。今天这四个 provider 是全局单例，本文件在改 family 前编译不过。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('选中集按 canvasId 隔离', () {
    container.read(canvasSelectionControllerProvider('c1').notifier).select('n1');
    expect(container.read(canvasSelectionControllerProvider('c1')), <String>{'n1'});
    expect(container.read(canvasSelectionControllerProvider('c2')), isEmpty,
        reason: 'c1 的 nodeId 串进 c2 会让 deleteNodesWithUndo 误删');
  });

  test('选中边按 canvasId 隔离', () {
    container.read(selectedEdgeControllerProvider('c1').notifier).select('e1');
    expect(container.read(selectedEdgeControllerProvider('c1')), 'e1');
    expect(container.read(selectedEdgeControllerProvider('c2')), isNull);
  });

  test('连线态按 canvasId 隔离', () {
    container.read(linkModeControllerProvider('c1').notifier).start('n1');
    expect(container.read(linkModeControllerProvider('c1')), isNotNull);
    expect(container.read(linkModeControllerProvider('c2')), isNull,
        reason: '残留 sourceNodeId 会让新画布首次点击就连出跨画布的边');
  });

  test('视口尺寸按 canvasId 隔离', () {
    container.read(canvasViewportSizeProvider('c1').notifier).setSize(const Size(800, 600));
    expect(container.read(canvasViewportSizeProvider('c1')), const Size(800, 600));
    expect(container.read(canvasViewportSizeProvider('c2')), Size.zero);
  });
}
