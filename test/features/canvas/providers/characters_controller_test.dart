import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/characters_controller.dart';

import '../../../_harness/fake_character.dart';

void main() {
  late FakeCharacterRepo repo;
  late FakeCharacterAssetService assets;
  late ProviderContainer container;

  setUp(() {
    repo = FakeCharacterRepo();
    assets = FakeCharacterAssetService();
    container = ProviderContainer(overrides: <Override>[
      characterRepositoryProvider.overrideWith((ref) async => repo),
      characterAssetServiceProvider.overrideWithValue(assets),
    ]);
    addTearDown(container.dispose);
  });

  // 订阅保活：autoDispose family 在读取后不被回收，_alive 守卫保持 true。
  Future<CharactersController> boot(String projectId) async {
    final sub = container.listen(
      charactersControllerProvider(projectId),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await container.read(charactersControllerProvider(projectId).future);
    return container.read(charactersControllerProvider(projectId).notifier);
  }

  test('build 列出项目角色', () async {
    repo.rows['c1'] = <String, Object?>{
      'id': 'c1',
      'project_id': 'p1',
      'name': 'Hero',
      'reference_image_paths': <String>['characters/h.png'],
    };
    await boot('p1');
    final list = container.read(charactersControllerProvider('p1')).valueOrNull!;
    expect(list, hasLength(1));
    expect(list.single.name, 'Hero');
    expect(list.single.referenceImagePaths, ['characters/h.png']);
  });

  test('createFromImage：建记录 → 导图 → 回填参考图 → 刷新列表', () async {
    final notifier = await boot('p1');
    final id = await notifier.createFromImage(
      name: 'Hero',
      sourceAbsolutePath: '/src/a.png',
    );
    expect(assets.imported, hasLength(1));
    final row = repo.rows[id]!;
    expect(row['name'], 'Hero');
    expect(row['reference_image_paths'], isNotEmpty);
    final list = container.read(charactersControllerProvider('p1')).valueOrNull!;
    expect(list.any((c) => c.id == id), isTrue);
  });

  test('rename：乐观更新 + 落库', () async {
    repo.rows['c1'] = <String, Object?>{
      'id': 'c1',
      'project_id': 'p1',
      'name': 'Old',
      'reference_image_paths': <String>[],
    };
    final notifier = await boot('p1');
    await notifier.rename('c1', 'New');
    expect(repo.rows['c1']!['name'], 'New');
    final list = container.read(charactersControllerProvider('p1')).valueOrNull!;
    expect(list.single.name, 'New');
  });

  test('delete：软删 + 资产清理 + 列表移除', () async {
    repo.rows['c1'] = <String, Object?>{
      'id': 'c1',
      'project_id': 'p1',
      'name': 'X',
      'reference_image_paths': <String>['characters/x.png'],
    };
    final notifier = await boot('p1');
    await notifier.delete('c1');
    expect(repo.softDeleted, contains('c1'));
    expect(assets.deleted, contains('characters/x.png'));
    final list = container.read(charactersControllerProvider('p1')).valueOrNull!;
    expect(list, isEmpty);
  });
}
