// StudioProjectsController 单测：create 编排原子性 + 列表刷新 + 错误冒泡。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/studio/controllers/studio_projects_controller.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';

import '../../../_harness/fake_repositories.dart';

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

    test('画布建失败：补偿删除刚建的项目（不留半成品），InkError 冒泡', () async {
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

      expect(projects.rows, isEmpty);
      expect(canvases.rows, isEmpty);
    });
  });
}
