// SB-4：shot → video 直达。
//
// 与「用备注生成图片」同一条链路，多带一件事：把本镜的镜头级参数（SB-3 的
// 预期时长 / 预期运镜）一并写进新建的 video config 节点，省得用户重填。
// 带过去的是**意图**——video 面板会按所选 provider 的能力钳制，这里只负责传。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/shot_config_inspector.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const _canvasId = 'cv1';

void main() {
  late InMemoryNodeRepository nodeRepo;
  late InMemoryEdgeRepository edgeRepo;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
    edgeRepo = InMemoryEdgeRepository();
  });

  Future<CanvasNode> seedShot(Map<String, Object?> typeConfig) async {
    final id = await nodeRepo.create(
      canvasId: _canvasId,
      type: 'shot',
      nodeRole: 'config',
      label: '',
      typeConfig: typeConfig,
    );
    return CanvasNode(
      id: id,
      label: '',
      type: CanvasNodeType.shot,
      canvasId: _canvasId,
      typeConfig: typeConfig,
    );
  }

  Future<void> pump(WidgetTester tester, CanvasNode node) async {
    await pumpInkApp(
      tester,
      Scaffold(body: ShotConfigInspector(node: node)),
      overrides: <Override>[
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
      ],
    );
    await tester.pumpAndSettle();
    // 预热 controllers：按钮回调经 ref.read 取 notifier，repo 需先就绪。
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShotConfigInspector)),
    );
    await container.read(canvasNodesControllerProvider(_canvasId).future);
    await container.read(canvasEdgesControllerProvider(_canvasId).future);
    await tester.pump();
  }

  Map<String, Object?> createdVideoConfig() {
    final row = nodeRepo.rows.values.firstWhere((r) => r['type'] == 'video');
    return row['type_config']! as Map<String, Object?>;
  }

  testWidgets('按钮存在;备注为空时与生成图片按钮一起禁用', (tester) async {
    final node = await seedShot(const <String, Object?>{});
    await pump(tester, node);

    final btn = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Generate video from notes'),
    );
    expect(btn.onPressed, isNull, reason: '无备注不能生成');
  });

  testWidgets('有备注 → 建 video config 节点(prompt=备注) + narrative 边',
      (tester) async {
    final node = await seedShot(
      const <String, Object?>{'shot_notes': 'rope bridge at dusk'},
    );
    await pump(tester, node);

    await tester.tap(find.text('Generate video from notes'));
    await tester.pumpAndSettle();

    final video = nodeRepo.rows.values.where((r) => r['type'] == 'video');
    expect(video, hasLength(1));
    expect(createdVideoConfig()['prompt'], 'rope bridge at dusk');
    expect(video.single['node_role'], 'config');

    final edges = edgeRepo.rows.values.toList();
    expect(edges, hasLength(1));
    expect(edges.single['edge_type'], EdgeType.narrative.name);
    expect(edges.single['source_node_id'], node.id);
    expect(edges.single['target_node_id'], video.single['id']);
  });

  testWidgets('镜头级参数一并带过去：duration_ms(秒×1000) + camera 枚举名',
      (tester) async {
    final node = await seedShot(const <String, Object?>{
      'shot_notes': 'push in on the gate',
      'duration_ms': 10000,
      'camera': 'pushIn',
    });
    await pump(tester, node);

    await tester.tap(find.text('Generate video from notes'));
    await tester.pumpAndSettle();

    final cfg = createdVideoConfig();
    expect(cfg['duration_ms'], 10000);
    expect(cfg['camera'], 'pushIn');
  });

  testWidgets('镜头级参数未设置时不写空键——留给 video 面板按 provider 取默认',
      (tester) async {
    final node = await seedShot(
      const <String, Object?>{'shot_notes': 'plain shot'},
    );
    await pump(tester, node);

    await tester.tap(find.text('Generate video from notes'));
    await tester.pumpAndSettle();

    final cfg = createdVideoConfig();
    expect(cfg.containsKey('duration_ms'), isFalse);
    expect(cfg.containsKey('camera'), isFalse);
    expect(cfg['prompt'], 'plain shot');
  });

  testWidgets('生成图片按钮不受影响——建的仍是 image 节点且不带镜头参数',
      (tester) async {
    final node = await seedShot(const <String, Object?>{
      'shot_notes': 'wide establishing',
      'duration_ms': 5000,
      'camera': 'orbit',
    });
    await pump(tester, node);

    await tester.tap(find.text('Generate image from notes'));
    await tester.pumpAndSettle();

    final image = nodeRepo.rows.values.where((r) => r['type'] == 'image');
    expect(image, hasLength(1));
    final cfg = image.single['type_config']! as Map<String, Object?>;
    expect(cfg['prompt'], 'wide establishing');
    // 图片没有时长/运镜的概念——不该顺手塞进去。
    expect(cfg.containsKey('duration_ms'), isFalse);
    expect(cfg.containsKey('camera'), isFalse);
  });
}
