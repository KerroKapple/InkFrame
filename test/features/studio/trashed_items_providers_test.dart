// trashed providers 单测：映射 / 坏行跳过 / 排序透传（LB-15）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/features/studio/providers/trashed_items_providers.dart';

class _RowsProjectRepo implements ProjectRepository {
  _RowsProjectRepo(this.trashed);
  final List<Map<String, Object?>> trashed;

  @override
  Future<List<Map<String, Object?>>> listTrashed() async => trashed;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

class _RowsCanvasRepo implements CanvasRepository {
  _RowsCanvasRepo(this.trashed);
  final List<Map<String, Object?>> trashed;
  String? lastProjectId;

  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(
      String projectId) async {
    lastProjectId = projectId;
    return trashed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

void main() {
  final t1 = DateTime.utc(2026, 7, 16, 10);
  final t2 = DateTime.utc(2026, 7, 15, 9);

  test('trashedProjectsProvider：行映射 + 坏行跳过 + 顺序透传', () async {
    final repo = _RowsProjectRepo([
      {'id': 'p1', 'name': 'A', 'deleted_at': t1},
      {'id': 'p2', 'name': 'B', 'deleted_at': t2},
      {'id': null, 'name': 'bad', 'deleted_at': t1}, // 坏行：无 id。
      {'id': 'p3', 'name': 'C', 'deleted_at': '2026-07-15'}, // 坏行：非 DateTime。
    ]);
    final c = ProviderContainer(overrides: [
      projectRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);

    final items = await c.read(trashedProjectsProvider.future);
    expect(items.map((i) => i.id).toList(), <String>['p1', 'p2']);
    expect(items.first.name, 'A');
    expect(items.first.deletedAt, t1);
  });

  test('trashedCanvasesProvider：family 透传 projectId', () async {
    final repo = _RowsCanvasRepo([
      {'id': 'c9', 'name': 'Old canvas', 'deleted_at': t2},
    ]);
    final c = ProviderContainer(overrides: [
      canvasRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);

    final items = await c.read(trashedCanvasesProvider('proj-1').future);
    expect(repo.lastProjectId, 'proj-1');
    expect(items.single.id, 'c9');
    expect(items.single.deletedAt, t2);
  });
}
