// StudioProjectsController.renameProject / deleteProject / renameCanvas /
// deleteCanvas 单测。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/features/studio/controllers/studio_projects_controller.dart';

class _FakeProjectRepo implements ProjectRepository {
  final List<Map<String, Object?>> updates = <Map<String, Object?>>[];
  final List<String> softDeleted = <String>[];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    updates.add(<String, Object?>{'id': id, ...patch});
    return 1;
  }

  @override
  Future<int> softDelete(String id) async {
    softDeleted.add(id);
    return 1;
  }

  // 未使用
  @override
  Future<String> create({required String name, String? coverNodeId}) async =>
      'p';
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listAll() async => const [];
  @override
  Future<List<Map<String, Object?>>> listTrashed() async => const [];
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

class _FakeCanvasRepo implements CanvasRepository {
  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(String projectId) async =>
      const <Map<String, Object?>>[];

  final List<Map<String, Object?>> updates = <Map<String, Object?>>[];
  final List<String> softDeleted = <String>[];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    updates.add(<String, Object?>{'id': id, ...patch});
    return 1;
  }

  @override
  Future<int> softDelete(String id) async {
    softDeleted.add(id);
    return 1;
  }

  // 未使用
  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async =>
      'cv';
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async =>
      const [];
  @override
  Future<List<Map<String, Object?>>> listByProjects(
    List<String> projectIds,
  ) async =>
      const [];
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

void main() {
  ({
    ProviderContainer c,
    _FakeProjectRepo repo,
    _FakeCanvasRepo canvases,
  }) build() {
    final repo = _FakeProjectRepo();
    final canvases = _FakeCanvasRepo();
    final c = ProviderContainer(overrides: [
      projectRepositoryProvider.overrideWith((ref) async => repo),
      canvasRepositoryProvider.overrideWith((ref) async => canvases),
    ]);
    addTearDown(c.dispose);
    return (c: c, repo: repo, canvases: canvases);
  }

  test('renameProject → repo.update(name)', () async {
    final (:c, :repo, canvases: _) = build();
    await c
        .read(studioProjectsControllerProvider)
        .renameProject(id: 'p1', name: '新名');
    expect(repo.updates, hasLength(1));
    expect(repo.updates.first['id'], 'p1');
    expect(repo.updates.first['name'], '新名');
  });

  test('deleteProject → repo.softDelete', () async {
    final (:c, :repo, canvases: _) = build();
    await c.read(studioProjectsControllerProvider).deleteProject('p2');
    expect(repo.softDeleted, <String>['p2']);
  });

  test('renameCanvas → canvasRepo.update(name)', () async {
    final (:c, repo: _, :canvases) = build();
    await c
        .read(studioProjectsControllerProvider)
        .renameCanvas(id: 'cv1', name: '新画布名');
    expect(canvases.updates, hasLength(1));
    expect(canvases.updates.first['id'], 'cv1');
    expect(canvases.updates.first['name'], '新画布名');
  });

  test('deleteCanvas → canvasRepo.softDelete', () async {
    final (:c, repo: _, :canvases) = build();
    await c.read(studioProjectsControllerProvider).deleteCanvas('cv2');
    expect(canvases.softDeleted, <String>['cv2']);
  });
}
