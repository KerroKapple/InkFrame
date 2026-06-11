// CanvasBootstrapController.createSample 行为单测。
//
// 该 dev 入口此前零覆盖。用 InMemory* fake override repo provider，验证：
// 真建了 project + 挂在其下的 canvas、切换了 currentCanvasIdProvider、返回新画布 id。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/canvas_bootstrap_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';

import '../../../_harness/fake_repositories.dart';

void main() {
  test('createSample 建 project + canvas 并切换 currentCanvasId', () async {
    final projects = InMemoryProjectRepository();
    final canvases = InMemoryCanvasRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        projectRepositoryProvider.overrideWith((_) async => projects),
        canvasRepositoryProvider.overrideWith((_) async => canvases),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(currentCanvasIdProvider), isNull);

    final controller = container.read(canvasBootstrapControllerProvider);
    final canvasId = await controller.createSample(
      projectName: 'Sample Project',
      canvasName: 'Sample Canvas',
    );

    // 返回值即新画布 id，且已切为当前画布
    expect(canvasId, isNotEmpty);
    expect(container.read(currentCanvasIdProvider), canvasId);

    // project 真落库，名字正确
    final projectRows = await projects.listAll();
    expect(projectRows, hasLength(1));
    expect(projectRows.single['name'], 'Sample Project');

    // canvas 真落库，挂在该 project 下，名字正确
    final projectId = projectRows.single['id'] as String;
    final canvasRows = await canvases.listByProject(projectId);
    expect(canvasRows, hasLength(1));
    expect(canvasRows.single['id'], canvasId);
    expect(canvasRows.single['name'], 'Sample Canvas');
  });

  test('再次 createSample 累加而不覆盖，currentCanvasId 指向最后一个', () async {
    final projects = InMemoryProjectRepository();
    final canvases = InMemoryCanvasRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        projectRepositoryProvider.overrideWith((_) async => projects),
        canvasRepositoryProvider.overrideWith((_) async => canvases),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(canvasBootstrapControllerProvider);
    final first = await controller.createSample(
      projectName: 'P1',
      canvasName: 'C1',
    );
    final second = await controller.createSample(
      projectName: 'P2',
      canvasName: 'C2',
    );

    expect(first, isNot(second));
    expect((await projects.listAll()), hasLength(2));
    expect(container.read(currentCanvasIdProvider), second);
  });
}
