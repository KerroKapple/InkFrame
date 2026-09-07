import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/shot_config_inspector.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

void main() {
  testWidgets('渲染标题 + 备注标签，水化 shot_notes', (tester) async {
    const node = CanvasNode(
      id: 's1',
      label: '',
      type: CanvasNodeType.shot,
      role: NodeRole.config,
      typeConfig: <String, Object?>{'shot_notes': 'wide establishing shot'},
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: ShotConfigInspector(node: node)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shot'), findsOneWidget);
    expect(find.text('Shot notes'), findsOneWidget);
    expect(find.text('wide establishing shot'), findsOneWidget);
  });

  group('用本镜备注生成图像', () {
    const canvasId = 'cv1';
    late InMemoryNodeRepository nodeRepo;
    late InMemoryEdgeRepository edgeRepo;

    setUp(() {
      nodeRepo = InMemoryNodeRepository();
      edgeRepo = InMemoryEdgeRepository();
    });

    Future<void> pump(WidgetTester tester, CanvasNode node) async {
      await pumpInkApp(
        tester,
        Scaffold(body: ShotConfigInspector(node: node)),
        overrides: [
          nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
          edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        ],
      );
      await tester.pumpAndSettle();
      // 预热 controllers：按钮回调经 ref.read 取 notifier，repo 需先就绪。
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShotConfigInspector)),
      );
      await container.read(canvasNodesControllerProvider(canvasId).future);
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      await tester.pump();
    }

    testWidgets('有备注 → 点按钮创建 image config 节点(prompt=shot_notes) + narrative 边',
        (tester) async {
      const node = CanvasNode(
        id: 'shot-1',
        label: '',
        type: CanvasNodeType.shot,
        role: NodeRole.config,
        canvasId: canvasId,
        typeConfig: <String, Object?>{'shot_notes': 'hero walks into frame'},
      );
      await pump(tester, node);

      expect(find.text('Generate image from notes'), findsOneWidget);
      await tester.tap(find.text('Generate image from notes'));
      await tester.pumpAndSettle();

      final created = nodeRepo.rows.values
          .where((r) => r['type'] == 'image')
          .toList();
      expect(created, hasLength(1));
      expect(created.single['node_role'], 'config');
      expect(
        (created.single['type_config']! as Map<String, Object?>)['prompt'],
        'hero walks into frame',
      );

      final edges = edgeRepo.rows.values.toList();
      expect(edges, hasLength(1));
      expect(edges.single['edge_type'], 'narrative');
      expect(edges.single['source_node_id'], 'shot-1');
      expect(edges.single['target_node_id'], created.single['id']);
    });

    testWidgets('空备注 → 按钮禁用，点击不产生节点', (tester) async {
      const node = CanvasNode(
        id: 'shot-2',
        label: '',
        type: CanvasNodeType.shot,
        role: NodeRole.config,
        canvasId: canvasId,
        typeConfig: <String, Object?>{},
      );
      await pump(tester, node);

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);

      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(nodeRepo.rows, isEmpty);
      expect(edgeRepo.rows, isEmpty);
    });

    testWidgets('输入备注后按钮从禁用变可用', (tester) async {
      const node = CanvasNode(
        id: 'shot-3',
        label: '',
        type: CanvasNodeType.shot,
        role: NodeRole.config,
        canvasId: canvasId,
        typeConfig: <String, Object?>{},
      );
      await pump(tester, node);

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), 'dolly in on face');
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      // 排掉 shot_notes 落盘防抖 timer。
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
    });

    testWidgets(
        '输入备注后立即切换选中(dispose)——挂起的防抖写入仍应落盘(回归 2026-08-31 审计 P0)',
        (tester) async {
      final id = await nodeRepo.create(
        canvasId: canvasId,
        type: 'shot',
        nodeRole: 'config',
      );
      final node = CanvasNode(
        id: id,
        label: '',
        type: CanvasNodeType.shot,
        role: NodeRole.config,
        canvasId: canvasId,
        typeConfig: const <String, Object?>{},
      );
      await pump(tester, node);

      await tester.enterText(find.byType(TextField), 'dolly in on face');
      await tester.pump();

      // 切换选中：把 ShotConfigInspector 从树里换掉，在 500ms 防抖窗口内触发
      // 其 State.dispose()——不能只 cancel 计时器，必须先把最后一次输入落盘。
      await pumpInkApp(
        tester,
        const Scaffold(body: SizedBox.shrink()),
        overrides: [
          nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
          edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        ],
      );

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(
        (nodeRepo.rows[id]!['type_config'] as Map<String, Object?>)[
            'shot_notes'],
        'dolly in on face',
      );
    });

    testWidgets('连线失败 → 节点已创建 + 专用连线失败 snackbar', (tester) async {
      edgeRepo = _FailingEdgeRepository();
      const node = CanvasNode(
        id: 'shot-4',
        label: '',
        type: CanvasNodeType.shot,
        role: NodeRole.config,
        canvasId: canvasId,
        typeConfig: <String, Object?>{'shot_notes': 'crane shot over city'},
      );
      await pump(tester, node);

      await tester.tap(find.text('Generate image from notes'));
      await tester.pumpAndSettle();

      expect(
        nodeRepo.rows.values.where((r) => r['type'] == 'image'),
        hasLength(1),
      );
      expect(edgeRepo.rows, isEmpty);
      expect(
        find.text('Image node added, but linking failed'),
        findsOneWidget,
      );
      expect(find.text('Failed to add node'), findsNothing);
      // 排掉 snackbar 自动关闭 timer。
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    });

    testWidgets('连击生成按钮只创建一套节点+边（in-flight 防重）', (tester) async {
      // 闸门卡住首次 create,让第二次点击落在 in-flight 窗口内。
      final gated = _GatedNodeRepository();
      nodeRepo = gated;
      const node = CanvasNode(
        id: 'shot-5',
        label: '',
        type: CanvasNodeType.shot,
        role: NodeRole.config,
        canvasId: canvasId,
        typeConfig: <String, Object?>{'shot_notes': 'match cut to interior'},
      );
      await pump(tester, node);

      await tester.tap(find.text('Generate image from notes'));
      await tester.tap(
        find.text('Generate image from notes'),
        warnIfMissed: false,
      );
      gated.gate.complete();
      await tester.pumpAndSettle();

      expect(
        nodeRepo.rows.values.where((r) => r['type'] == 'image'),
        hasLength(1),
      );
      expect(edgeRepo.rows, hasLength(1));
    });
  });
}

class _FailingEdgeRepository extends InMemoryEdgeRepository {
  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) async => throw const LocalIOError();
}

class _GatedNodeRepository extends InMemoryNodeRepository {
  final Completer<void> gate = Completer<void>();

  @override
  Future<String> create({
    required String canvasId,
    required String type,
    required String nodeRole,
    String label = '',
    String? sourceNodeId,
    String? laneId,
    double positionX = 0,
    double positionY = 0,
    double width = 240,
    double height = 240,
    int zIndex = 0,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    await gate.future;
    return super.create(
      canvasId: canvasId,
      type: type,
      nodeRole: nodeRole,
      label: label,
      sourceNodeId: sourceNodeId,
      laneId: laneId,
      positionX: positionX,
      positionY: positionY,
      width: width,
      height: height,
      zIndex: zIndex,
      typeConfig: typeConfig,
    );
  }
}
