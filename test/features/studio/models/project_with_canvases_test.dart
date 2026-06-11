// workspaceProjectsProvider 真实 body 单测 + ProjectWithCanvases/CanvasRef 构造。
//
// 现有 studio 测都 override 掉 workspaceProjectsProvider，provider body
// （从 repo 行装配模型、跳过坏行、CanvasRef name 兜底）从未被触达。
// 这里用 InMemory* fake override 底层 repo provider，跑真 body。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';

import '../../../_harness/fake_repositories.dart';

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
  group('ProjectWithCanvases / CanvasRef 构造', () {
    test('字段如实保留', () {
      const ref = CanvasRef(id: 'cv1', name: 'Scene 1');
      const pwc = ProjectWithCanvases(
        id: 'p1',
        name: 'Alpha',
        canvases: <CanvasRef>[ref],
      );
      expect(pwc.id, 'p1');
      expect(pwc.name, 'Alpha');
      expect(pwc.canvases.single.id, 'cv1');
      expect(pwc.canvases.single.name, 'Scene 1');
    });
  });

  group('workspaceProjectsProvider 真实装配', () {
    test('把 project 行 + 其画布装配成 ProjectWithCanvases', () async {
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
      expect(p.canvases.map((cv) => cv.name), containsAll(['Scene A', 'Scene B']));
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

    test('无项目 → 空列表', () async {
      final c = _containerWith(
        InMemoryProjectRepository(),
        InMemoryCanvasRepository(),
      );
      final result = await c.read(workspaceProjectsProvider.future);
      expect(result, isEmpty);
    });
  });
}
