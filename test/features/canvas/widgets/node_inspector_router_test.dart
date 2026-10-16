// NodeInspectorRouter 按 node.type / role 分流：
//   - image + config → ImageConfigInspector
//   - video + config → VideoConfigInspector
//   - shot  + config → ShotConfigInspector
//   - text  + config → TextNodeInspector
//   - image + result → ImageResultInspector（有 slot 时渲染 BatchResultsGrid，否则单张预览）
//   - video + result → VideoResultInspector

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/batch_results_grid.dart';
import 'package:inkframe/features/canvas/widgets/image_config_inspector.dart';
import 'package:inkframe/features/canvas/widgets/image_result_inspector.dart';
import 'package:inkframe/features/canvas/widgets/node_inspector_router.dart';
import 'package:inkframe/features/canvas/widgets/result_inspector_parts.dart';
import 'package:inkframe/features/canvas/widgets/shot_config_inspector.dart';
import 'package:inkframe/features/canvas/widgets/text_node_inspector.dart';
import 'package:inkframe/features/canvas/widgets/video_config_inspector.dart';
import 'package:inkframe/features/canvas/widgets/video_result_inspector.dart';

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

  testWidgets('image result 节点 + 无 slot（单张生成）→ 不画网格，画单张预览', (tester) async {
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
    // 演示 F2：单张生成时面板不再整块留空。
    expect(find.byKey(ResultInspectorKeys.preview), findsOneWidget);
  });

  testWidgets('video result 节点 → VideoResultInspector（预览 + 参数 + 动作）', (tester) async {
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
    await tester.pumpAndSettle();
    expect(find.byType(VideoResultInspector), findsOneWidget);
    expect(find.byKey(ResultInspectorKeys.preview), findsOneWidget);
    expect(find.byType(ImageResultInspector), findsNothing);
    expect(find.byType(VideoConfigInspector), findsNothing);
    expect(find.byType(ImageConfigInspector), findsNothing);
  });

  testWidgets('text 节点 → TextNodeInspector（正文输入框）', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.text,
      role: NodeRole.config,
      typeConfig: <String, Object?>{'text': 'opening narration'},
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: NodeInspectorRouter(node: node)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextNodeInspector), findsOneWidget);
    expect(find.byKey(TextNodeInspector.contentFieldKey), findsOneWidget);
    expect(find.text('opening narration'), findsOneWidget);
    expect(find.byType(ImageConfigInspector), findsNothing);
  });
}
