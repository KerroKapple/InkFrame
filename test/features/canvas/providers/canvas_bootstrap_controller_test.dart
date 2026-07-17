// CanvasBootstrapController.createSample 行为单测（ON-2b 种子化后）。
//
// FakeUnitOfWork + InMemory* fake 验证：单事务内建 project + canvas + 示例泳道
// + 预填 prompt 的 image config 节点；切换 currentCanvasIdProvider；返回新画布 id。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/canvas_bootstrap_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';

const _seed = (
  laneLabel: 'Ink Style',
  laneStylePrompt: 'ink painting, soft brush',
  nodeLabel: 'First Shot',
  nodePrompt: 'A lone boat on a misty river',
);

void main() {
  late InMemoryProjectRepository projects;
  late InMemoryCanvasRepository canvases;
  late InMemoryStyleLaneRepository lanes;
  late InMemoryNodeRepository nodes;
  late ProviderContainer container;

  setUp(() {
    projects = InMemoryProjectRepository();
    canvases = InMemoryCanvasRepository();
    lanes = InMemoryStyleLaneRepository();
    nodes = InMemoryNodeRepository();
    container = ProviderContainer(
      overrides: <Override>[
        unitOfWorkProvider.overrideWith(
          (_) async => FakeUnitOfWork(FakeRepositoryScope(
            projects: projects,
            canvas: canvases,
            styleLanes: lanes,
            nodes: nodes,
          )),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('createSample 单事务建 project+canvas+泳道+预填节点并切换 currentCanvasId',
      () async {
    expect(container.read(currentCanvasIdProvider), isNull);

    final controller = container.read(canvasBootstrapControllerProvider);
    final canvasId = await controller.createSample(
      projectName: 'Sample Project',
      canvasName: 'Sample Canvas',
      seed: _seed,
    );

    expect(canvasId, isNotEmpty);
    expect(container.read(currentCanvasIdProvider), canvasId);

    final projectRows = await projects.listAll();
    expect(projectRows, hasLength(1));
    expect(projectRows.single['name'], 'Sample Project');

    final projectId = projectRows.single['id'] as String;
    final canvasRows = await canvases.listByProject(projectId);
    expect(canvasRows, hasLength(1));
    expect(canvasRows.single['id'], canvasId);

    // 示例泳道：label / stylePrompt 来自 seed
    final laneRows = await lanes.listByCanvas(canvasId);
    expect(laneRows, hasLength(1));
    expect(laneRows.single['label'], _seed.laneLabel);
    expect(laneRows.single['style_prompt'], _seed.laneStylePrompt);

    // 预填节点：image config、挂进泳道、prompt 预填、落在泳道带内
    final nodeRows = await nodes.listByCanvas(canvasId);
    expect(nodeRows, hasLength(1));
    final node = nodeRows.single;
    expect(node['type'], 'image');
    expect(node['node_role'], 'config');
    expect(node['lane_id'], laneRows.single['id']);
    expect(node['label'], _seed.nodeLabel);
    final typeConfig = node['type_config'] as Map<String, Object?>;
    expect(typeConfig['prompt'], _seed.nodePrompt);
    // 默认泳道厚 400（horizontal 带 = 世界 Y ∈ [0,400)）：节点整体落带内
    final y = node['position_y'] as double;
    final h = node['height'] as double;
    expect(y, greaterThanOrEqualTo(0));
    expect(y + h, lessThanOrEqualTo(400));
  });

  test('再次 createSample 累加而不覆盖，currentCanvasId 指向最后一个', () async {
    final controller = container.read(canvasBootstrapControllerProvider);
    final first = await controller.createSample(
      projectName: 'P1',
      canvasName: 'C1',
      seed: _seed,
    );
    final second = await controller.createSample(
      projectName: 'P2',
      canvasName: 'C2',
      seed: _seed,
    );

    expect(first, isNot(second));
    expect(await projects.listAll(), hasLength(2));
    expect(container.read(currentCanvasIdProvider), second);
  });
}
