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
import 'package:inkframe/features/canvas/util/canvas_extent.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_shortcuts.dart';

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
  Size? surfaceSize,
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasShortcuts(child: CanvasView())),
    overrides: _overrides(nodes),
    surfaceSize: surfaceSize,
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

/// 通过 InteractiveViewer widget 读当前变换——与 transform provider 是否 family 无关。
Matrix4 _ivTransform(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;

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
    await _pump(tester, nodes: twoNodes);
    expect(_ivTransform(tester), initialCanvasTransform());

    await _sendCtrl(tester, LogicalKeyboardKey.equal);
    expect(scaleOf(_ivTransform(tester)), greaterThan(1.0));

    final zoomedIn = scaleOf(_ivTransform(tester));
    await _sendCtrl(tester, LogicalKeyboardKey.minus);
    expect(scaleOf(_ivTransform(tester)), lessThan(zoomedIn));
  });

  testWidgets('⌘0（Ctrl+0）缩放复位到初始相机', (tester) async {
    await _pump(tester, nodes: twoNodes);

    await _sendCtrl(tester, LogicalKeyboardKey.equal);
    expect(_ivTransform(tester), isNot(initialCanvasTransform()));

    await _sendCtrl(tester, LogicalKeyboardKey.digit0);
    expect(_ivTransform(tester), initialCanvasTransform());
  });

  // ===== D2：缩放围绕视口中心（viewport size 存活，不自毁复位 Size.zero）=====
  testWidgets('⌘+ 围绕视口中心而非 (0,0)：viewport size 存活', (tester) async {
    final container = await _pump(
      tester,
      nodes: twoNodes,
      surfaceSize: const Size(800, 600),
    );
    // viewport size 已上报且未被 autoDispose 复位。
    final size = container.read(canvasViewportSizeProvider);
    expect(size, isNot(Size.zero));
    expect(size.width, greaterThan(0));

    await _sendCtrl(tester, LogicalKeyboardKey.equal); // ⌘+
    final m = _ivTransform(tester);
    final scale = scaleOf(m);
    // 围绕视口中心：初始相机 t=-kStageHalf、s=1 → 中心场景点 = cx + kStageHalf，
    // 新平移 tx = cx(1-scale) - kStageHalf*scale；若支点落 (0,0) 则 tx==-kStageHalf*scale。
    final cx = size.width / 2;
    final expectedTx = cx * (1 - scale) - kStageHalf * scale;
    expect(m.storage[12], closeTo(expectedTx, 1e-3));
    expect(
      (m.storage[12] + kStageHalf * scale).abs(),
      greaterThan(1.0), // 不是 (0,0) 支点
    );
  });

  // ===== D3：切换画布不继承旧画布的 pan/zoom（transform 按 canvasId 隔离）=====
  testWidgets('切换画布 → InteractiveViewer 变换复位为初始相机', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    // 预热并保活 c2 的节点：否则切换瞬间出现 loading 空档，InteractiveViewer 短暂卸载，
    // autoDispose 顺带把（非 family 的）共享 transform 复位，反而掩盖了串味 bug。
    // 保活后切换无空档、舞台持续挂载，才能真实暴露"新画布继承旧变换"。
    final sub = container.listen(
      canvasNodesControllerProvider('c2'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await tester.pumpAndSettle();

    // 缩放当前画布 c1。
    await _sendCtrl(tester, LogicalKeyboardKey.equal);
    expect(_ivTransform(tester), isNot(initialCanvasTransform()));

    // 切到 c2（同一 CanvasScreen 常驻，仅换 canvasId；c2 已 AsyncData，无 loading 空档）。
    container.read(currentCanvasIdProvider.notifier).state = 'c2';
    await tester.pumpAndSettle();

    expect(
      _ivTransform(tester),
      initialCanvasTransform(),
      reason: '新画布不得继承旧画布的 pan/zoom',
    );
  });

  // ===== D1：生产嵌套下画布仍拿到焦点（PL-1 ⌘K 层在外层）=====
  testWidgets('生产嵌套：CommandPaletteShortcuts 外层时画布仍持焦（Delete 生效 + ⌘K 仍开面板）', (
    tester,
  ) async {
    // 复现 app.dart 的嵌套：命令面板层(autofocus) 包 画布快捷键层。
    await pumpInkApp(
      tester,
      const Scaffold(
        body: CommandPaletteShortcuts(
          child: CanvasShortcuts(child: CanvasView()),
        ),
      ),
      overrides: _overrides(twoNodes),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );
    container.read(canvasSelectionControllerProvider.notifier).select('a');
    await tester.pump();

    // 不点击任何东西：Delete 应删除节点（证明画布抢回了焦点，未被 PL-1 autofocus 独占）。
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('Node A'), findsNothing);

    // ⌘K 仍冒泡到祖先命令面板层 → 打开面板（证明没弄坏 ⌘K）。
    await _sendCtrl(tester, LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteDialog), findsOneWidget);
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
