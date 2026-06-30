// StudioProjectsController.renameProject / deleteProject 单测。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
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

void main() {
  ({ProviderContainer c, _FakeProjectRepo repo}) build() {
    final repo = _FakeProjectRepo();
    final c = ProviderContainer(overrides: [
      projectRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    return (c: c, repo: repo);
  }

  test('renameProject → repo.update(name)', () async {
    final (:c, :repo) = build();
    await c
        .read(studioProjectsControllerProvider)
        .renameProject(id: 'p1', name: '新名');
    expect(repo.updates, hasLength(1));
    expect(repo.updates.first['id'], 'p1');
    expect(repo.updates.first['name'], '新名');
  });

  test('deleteProject → repo.softDelete', () async {
    final (:c, :repo) = build();
    await c.read(studioProjectsControllerProvider).deleteProject('p2');
    expect(repo.softDeleted, <String>['p2']);
  });
}
