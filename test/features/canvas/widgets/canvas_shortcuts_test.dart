// CanvasShortcuts widget 测试（PL-2）：五组键位（Delete / Esc / ⌘A / ⌘± / ⌘0）
// 驱动真实画布 + 焦点链陷阱（Inspector 文本框聚焦时不误伤画布）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';

import '../../../_harness/test_app.dart';

/// 内存 Fake：build 返回 seed，removeNode/restore 就地增删。
class _FakeNodesController extends CanvasNodesController {
  _FakeNodesController(this._seed);
  final List<CanvasNode> _seed;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;

  @override
  Future<NodeDeletion?> removeNode(String id) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    CanvasNode? removed;
    for (final n in previous) {
      if (n.id == id) removed = n;
    }
    state = AsyncData(
      previous.where((n) => n.id != id).toList(growable: false),
    );
    if (removed == null) return null;
    return (node: removed, edgeIds: const <String>[]);
  }

  @override
  Future<void> restore(NodeDeletion deletion) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    state = AsyncData([...previous, deletion.node]);
  }
}

class _FakeEdgesController extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => const <CanvasEdge>[];
}

class _EmptyLanesController extends CanvasLanesController {
  @override
  Future<List<StyleLane>> build(String canvasId) async => const <StyleLane>[];
}

/// NodeCard 通过 fileResolverServiceProvider 解析缩略图；用桩隔离磁盘/appPaths。
class _StubResolver implements FileResolverService {
  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) => throw UnimplementedError();

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) => File(
    '${Directory.systemTemp.path}'
    '${Platform.pathSeparator}__inkframe_missing__'
    '${Platform.pathSeparator}$relativePath',
  );

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) => throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      Directory(
        '${Directory.systemTemp.path}'
        '${Platform.pathSeparator}__inkframe_missing__',
      );
}

CanvasNode _textNode(String id, String label, double x) => CanvasNode(
  id: id,
  label: label,
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(x, 40),
  size: const Size(180, 120),
);

List<Override> _overrides(List<CanvasNode> nodes) => <Override>[
  currentCanvasIdProvider.overrideWith((ref) => 'c1'),
  canvasNodesControllerProvider.overrideWith(() => _FakeNodesController(nodes)),
  canvasEdgesControllerProvider.overrideWith(() => _FakeEdgesController()),
  canvasLanesControllerProvider.overrideWith(() => _EmptyLanesController()),
  fileResolverServiceProvider.overrideWithValue(_StubResolver()),
];

/// 画布单独包在 CanvasShortcuts 下（对齐 canvas_screen 的包裹方式）。
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<CanvasNode> nodes,
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasShortcuts(child: CanvasView())),
    overrides: _overrides(nodes),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

/// 发送带 Ctrl 修饰的按键（跨平台注册了 meta+control 双变体）。
Future<void> _sendCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  final twoNodes = <CanvasNode>[
    _textNode('a', 'Node A', 40),
    _textNode('b', 'Node B', 320),
  ];

  testWidgets('Delete 键删除选中节点（复用 PL-4a 删除路径）', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider.notifier).select('a');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.text('Node A'), findsNothing);
    expect(find.byType(NodeCard), findsOneWidget); // 仅剩 B
    expect(find.text('Node deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget); // 撤销入口保留
  });

  testWidgets('Backspace 键同样删除选中节点', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider.notifier).select('b');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(find.text('Node B'), findsNothing);
  });

  testWidgets('多选 Delete → 批量删除 + 一条批量撤销', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider.notifier).selectAll(
      <String>['a', 'b'],
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.byType(NodeCard), findsNothing);
    expect(find.text('2 nodes deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('Esc 清空节点 + 边选择', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider.notifier).select('a');
    container.read(selectedEdgeControllerProvider.notifier).select('e1');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(canvasSelectionControllerProvider), isEmpty);
    expect(container.read(selectedEdgeControllerProvider), isNull);
  });

  testWidgets('Esc 优先退出连线模式，不清空选择', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(linkModeControllerProvider.notifier).start('a');
    container.read(canvasSelectionControllerProvider.notifier).select('a');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(linkModeControllerProvider), isNull); // 退出连线
    expect(container.read(canvasSelectionControllerProvider), {'a'}); // 选择保留
  });

  testWidgets('Ctrl+A 全选当前画布所有节点', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);

    await _sendCtrl(tester, LogicalKeyboardKey.keyA);

    expect(container.read(canvasSelectionControllerProvider), {'a', 'b'});
  });

  testWidgets('⌘±（Ctrl+= / Ctrl+-）改变缩放变换', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    final controller = container.read(canvasTransformControllerProvider);
    expect(controller.value, Matrix4.identity());

    await _sendCtrl(tester, LogicalKeyboardKey.equal);
    expect(scaleOf(controller.value), greaterThan(1.0));

    final zoomedIn = scaleOf(controller.value);
    await _sendCtrl(tester, LogicalKeyboardKey.minus);
    expect(scaleOf(controller.value), lessThan(zoomedIn));
  });

  testWidgets('⌘0（Ctrl+0）缩放复位到单位矩阵', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    final controller = container.read(canvasTransformControllerProvider);

    await _sendCtrl(tester, LogicalKeyboardKey.equal);
    expect(controller.value, isNot(Matrix4.identity()));

    await _sendCtrl(tester, LogicalKeyboardKey.digit0);
    expect(controller.value, Matrix4.identity());
  });

  // ===== 焦点链陷阱（MANDATORY）=====
  testWidgets('焦点在 Inspector 文本框时：Backspace/⌘A 交给文本编辑，不误伤画布', (tester) async {
    final fieldController = TextEditingController(text: 'hello');
    addTearDown(fieldController.dispose);

    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasShortcuts(
          child: Column(
            children: <Widget>[
              const Expanded(child: CanvasView()),
              // Inspector 文本框替身：同处于 CanvasShortcuts 子树内的 EditableText。
              TextField(controller: fieldController),
            ],
          ),
        ),
      ),
      overrides: _overrides(twoNodes),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );

    // 选中一个节点（若快捷键误命中会被删/被全选覆盖）。
    container.read(canvasSelectionControllerProvider.notifier).select('a');
    await tester.pump();

    // 焦点移入文本框。
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(isEditingText(), isTrue); // 主焦点确在 EditableText 内

    // Backspace：应编辑文本，而非删除节点。
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.text('Node A'), findsOneWidget); // 节点未被删
    expect(container.read(canvasSelectionControllerProvider), {'a'}); // 选择未变

    // ⌘A：应选中框内文本，而非全选画布节点。
    await _sendCtrl(tester, LogicalKeyboardKey.keyA);
    expect(
      container.read(canvasSelectionControllerProvider),
      {'a'},
      reason: '文本框聚焦时 ⌘A 不得触发画布全选',
    );
  });
}
