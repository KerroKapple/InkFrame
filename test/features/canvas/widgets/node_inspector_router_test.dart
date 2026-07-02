// NodeInspectorRouter 按 node.type / role 分流：
//   - image + config → ImageConfigInspector
//   - video + config → VideoConfigInspector
//   - shot  + config → ShotConfigInspector
//   - image + result → ImageResultInspector（有 slot 时渲染 BatchResultsGrid）
//   - video/text + result、text config → 不渲染 Inspector

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/batch_results_grid.dart';
import 'package:inkframe/features/canvas/widgets/image_config_inspector.dart';
import 'package:inkframe/features/canvas/widgets/image_result_inspector.dart';
import 'package:inkframe/features/canvas/widgets/node_inspector_router.dart';
import 'package:inkframe/features/canvas/widgets/shot_config_inspector.dart';
import 'package:inkframe/features/canvas/widgets/video_config_inspector.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/test_app.dart';

void main() {
  testWidgets('image 节点 → ImageConfigInspector', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.image,
      role: NodeRole.config,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: NodeInspectorRouter(node: node)),
    );
    expect(find.byType(ImageConfigInspector), findsOneWidget);
    expect(find.byType(VideoConfigInspector), findsNothing);
  });

  testWidgets('video 节点 → VideoConfigInspector', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: NodeInspectorRouter(node: node)),
    );
    expect(find.byType(VideoConfigInspector), findsOneWidget);
    expect(find.byType(ImageConfigInspector), findsNothing);
  });

  testWidgets('shot 节点 → ShotConfigInspector', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.shot,
      role: NodeRole.config,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: NodeInspectorRouter(node: node)),
    );
    expect(find.byType(ShotConfigInspector), findsOneWidget);
    expect(find.byType(ImageConfigInspector), findsNothing);
  });

  testWidgets('image result 节点 + 有 slot → ImageResultInspector 渲染批量网格', (
    tester,
  ) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      sourceNodeId: 's1',
    );
    final repo = FakeBatchResultRepo();
    await repo.create(nodeId: 'n1', jobId: 'j1', slotIndex: 0, status: 'generating');
    await repo.create(nodeId: 'n1', jobId: 'j1', slotIndex: 1, status: 'error');
    await pumpInkApp(
      tester,
      const Scaffold(body: NodeInspectorRouter(node: node)),
      overrides: [
        batchResultRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(ImageResultInspector), findsOneWidget);
    expect(find.byType(BatchResultsGrid), findsOneWidget);
    expect(find.byType(ImageConfigInspector), findsNothing);
  });

  testWidgets('image result 节点 + 无 slot（单张生成）→ 不占面板空间', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      sourceNodeId: 's1',
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: NodeInspectorRouter(node: node)),
      overrides: [
        batchResultRepositoryProvider.overrideWith(
          (ref) async => FakeBatchResultRepo(),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(ImageResultInspector), findsOneWidget);
    expect(find.byType(BatchResultsGrid), findsNothing);
  });

  testWidgets('video result 节点 → 不渲染 Inspector', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      sourceNodeId: 's1',
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: NodeInspectorRouter(node: node)),
    );
    expect(find.byType(ImageResultInspector), findsNothing);
    expect(find.byType(VideoConfigInspector), findsNothing);
    expect(find.byType(ImageConfigInspector), findsNothing);
  });
}
