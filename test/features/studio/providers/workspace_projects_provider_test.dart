// workspaceProjectsProvider 真实 body 单测：装配语义 + 查询次数（反 N+1）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';

import '../../../_harness/fake_repositories.dart';

class _CountingCanvasRepository extends InMemoryCanvasRepository {
  int listByProjectCalls = 0;
  int listByProjectsCalls = 0;

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) {
    listByProjectCalls += 1;
    return super.listByProject(projectId);
  }

  @override
  Future<List<Map<String, Object?>>> listByProjects(List<String> projectIds) {
    listByProjectsCalls += 1;
    return super.listByProjects(projectIds);
  }
}

ProviderContainer _containerWith(
  ProjectRepository projects,
  CanvasRepository canvases,
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
  group('workspaceProjectsProvider 真实装配', () {
    test('把 project 行 + 其画布装配成 ProjectWithCanvases（含真实 createdAt）',
        () async {
      final projects = InMemoryProjectRepository();
      final canvases = InMemoryCanvasRepository();
      final pid = await projects.create(name: 'Alpha');
      await canvases.create(projectId: pid, name: 'Scene A');
      await canvases.create(projectId: pid, name: 'Scene B');

      final c = _containerWith(projects, canvases);
      final result = await c.read(workspaceProjectsProvider.future);

      expect(result, hasLength(1));
      final p = result.single;
      expect(p.id, pid);
      expect(p.name, 'Alpha');
      expect(
        p.createdAt,
        (await projects.findById(pid))!['created_at'],
      );
      expect(
        p.canvases.map((cv) => cv.name),
        containsAll(['Scene A', 'Scene B']),
      );
    });

    test('画布 name 为空字符串时 CanvasRef.name 兜底为空串（不抛错）', () async {
      final projects = InMemoryProjectRepository();
      final canvases = InMemoryCanvasRepository();
      final pid = await projects.create(name: 'Beta');
      await canvases.create(projectId: pid, name: '');

      final c = _containerWith(projects, canvases);
      final result = await c.read(workspaceProjectsProvider.future);
      expect(result.single.canvases.single.name, '');
    });

    test('多项目：各自只挂自己的画布', () async {
      final projects = InMemoryProjectRepository();
      final canvases = InMemoryCanvasRepository();
      final p1 = await projects.create(name: 'P1');
      final p2 = await projects.create(name: 'P2');
      await canvases.create(projectId: p1, name: 'only-p1');

      final c = _containerWith(projects, canvases);
      final result = await c.read(workspaceProjectsProvider.future);
      final byId = {for (final p in result) p.id: p};
      expect(byId[p1]!.canvases.single.name, 'only-p1');
      expect(byId[p2]!.canvases, isEmpty);
    });

    test('无项目 → 空列表，且不发画布查询', () async {
      final canvases = _CountingCanvasRepository();
      final c = _containerWith(InMemoryProjectRepository(), canvases);
      final result = await c.read(workspaceProjectsProvider.future);
      expect(result, isEmpty);
      expect(canvases.listByProjectsCalls, 0);
      expect(canvases.listByProjectCalls, 0);
    });
  });

  group('workspaceProjectsProvider 查询次数（反 N+1）', () {
    test('N 个项目只发 1 次批量画布查询，绝不逐项目查', () async {
      final projects = InMemoryProjectRepository();
      final canvases = _CountingCanvasRepository();
      for (var i = 0; i < 5; i++) {
        final pid = await projects.create(name: 'P$i');
        await canvases.create(projectId: pid, name: 'C$i');
      }

      final c = _containerWith(projects, canvases);
      final result = await c.read(workspaceProjectsProvider.future);

      expect(result, hasLength(5));
      expect(canvases.listByProjectsCalls, 1);
      expect(canvases.listByProjectCalls, 0);
    });
  });
}
