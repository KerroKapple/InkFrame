// StudioProjectsController 单测：create 编排走 UnitOfWork + 列表刷新 + 错误冒泡。
// 真正的事务回滚（项目不残留）由 transaction_integration_test.dart（真 PG）断言。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/studio/controllers/studio_projects_controller.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';

class _FailingCanvasCreateRepository extends InMemoryCanvasRepository {
  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async {
    throw const LocalIOError();
  }
}

ProviderContainer _containerWith(
  InMemoryProjectRepository projects,
  InMemoryCanvasRepository canvases,
) {
  final c = ProviderContainer(
    overrides: <Override>[
      projectRepositoryProvider.overrideWith((_) async => projects),
      canvasRepositoryProvider.overrideWith((_) async => canvases),
      unitOfWorkProvider.overrideWith(
        (_) async => FakeUnitOfWork(
          FakeRepositoryScope(projects: projects, canvas: canvases),
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('StudioProjectsController.createProject', () {
    test('成功：项目 + 首画布都建出来，列表刷新可见', () async {
      final projects = InMemoryProjectRepository();
      final canvases = InMemoryCanvasRepository();
      final c = _containerWith(projects, canvases);

      await c.read(studioProjectsControllerProvider).createProject(
            name: 'Alpha',
            firstCanvasName: 'Untitled Canvas',
          );

      expect(projects.rows, hasLength(1));
      expect(canvases.rows, hasLength(1));
      expect(canvases.rows.values.single['name'], 'Untitled Canvas');

      final list = await c.read(workspaceProjectsProvider.future);
      expect(list.single.name, 'Alpha');
      expect(list.single.canvases.single.name, 'Untitled Canvas');
    });

    test('画布建失败：InkError 原样冒泡（事务回滚由 pg 集成测覆盖）', () async {
      final projects = InMemoryProjectRepository();
      final canvases = _FailingCanvasCreateRepository();
      final c = _containerWith(projects, canvases);

      await expectLater(
        c.read(studioProjectsControllerProvider).createProject(
              name: 'Alpha',
              firstCanvasName: 'Untitled Canvas',
            ),
        throwsA(isA<LocalIOError>()),
      );
    });
  });
}
