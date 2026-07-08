import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/providers/characters_controller.dart';

import '../../../_harness/fake_character.dart';

void main() {
  late FakeCharacterRepo repo;
  late FakeCharacterAssetService assets;
  late ProviderContainer container;

  setUp(() {
    repo = FakeCharacterRepo();
    assets = FakeCharacterAssetService();
    container = ProviderContainer(
      overrides: <Override>[
        characterRepositoryProvider.overrideWith((ref) async => repo),
        characterAssetServiceProvider.overrideWithValue(assets),
      ],
    );
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
    final list = container
        .read(charactersControllerProvider('p1'))
        .valueOrNull!;
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
    final list = container
        .read(charactersControllerProvider('p1'))
        .valueOrNull!;
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
    final list = container
        .read(charactersControllerProvider('p1'))
        .valueOrNull!;
    expect(list.single.name, 'New');
  });

  test('delete：软删（可 restore）→ 不销毁参考图资产 + 列表移除', () async {
    repo.rows['c1'] = <String, Object?>{
      'id': 'c1',
      'project_id': 'p1',
      'name': 'X',
      'reference_image_paths': <String>['characters/x.png'],
    };
    final notifier = await boot('p1');
    await notifier.delete('c1');
    expect(repo.softDeleted, contains('c1'));
    // 软删可恢复：不销毁资产，否则 restore 后指向已删文件（评审 F2）。
    expect(assets.deleted, isEmpty);
    final list = container
        .read(charactersControllerProvider('p1'))
        .valueOrNull!;
    expect(list, isEmpty);
  });

  test('createFromImage：repo.update 失败 → 清 ghost 记录 + 孤儿图，上抛', () async {
    repo.failUpdate = true;
    final notifier = await boot('p1');
    await expectLater(
      notifier.createFromImage(name: 'Hero', sourceAbsolutePath: '/src/a.png'),
      throwsA(isA<InkError>()),
    );
    // 记录已回滚（hardDelete），不残留 ghost；导入的图也被清理。
    expect(repo.rows.values.any((r) => r['name'] == 'Hero'), isFalse);
    expect(assets.deleted, hasLength(1));
  });

  test('createFromImage：补偿 hardDelete 也失败 → 仍上抛原始错误且不掩盖', () async {
    repo.failUpdate = true;
    repo.failHardDelete = true;
    final notifier = await boot('p1');
    await expectLater(
      notifier.createFromImage(name: 'Hero', sourceAbsolutePath: '/src/a.png'),
      throwsA(isA<InkError>()),
    );
    // 补偿失败被静默（不掩盖原始错误），已导入的图仍被清理。
    expect(assets.deleted, hasLength(1));
  });

  test('并发 rename：失败一方回滚不得清掉已成功的并发更新（LB-04 串行化）', () async {
    repo.rows['c1'] = <String, Object?>{
      'id': 'c1',
      'project_id': 'p1',
      'name': 'Old1',
      'reference_image_paths': <String>[],
    };
    repo.rows['c2'] = <String, Object?>{
      'id': 'c2',
      'project_id': 'p1',
      'name': 'Old2',
      'reference_image_paths': <String>[],
    };
    repo.failUpdateIds.add('c1'); // c1 落库失败，c2 成功
    final notifier = await boot('p1');

    // 两次 rename 交错发起：未串行化时 c1 的回滚会把 c2 的成功更新一并抹掉。
    final fa = notifier.rename('c1', 'New1');
    final fb = notifier.rename('c2', 'New2');
    await expectLater(fa, throwsA(isA<InkError>()));
    await fb;

    final list =
        container.read(charactersControllerProvider('p1')).valueOrNull!;
    final c1 = list.firstWhere((c) => c.id == 'c1');
    final c2 = list.firstWhere((c) => c.id == 'c2');
    expect(c1.name, 'Old1', reason: 'c1 落库失败 → 正确回滚');
    expect(c2.name, 'New2', reason: 'c2 已成功，不得被 c1 的回滚清掉');
  });

  test('rename：repo 抛 InkError → 乐观更新回滚', () async {
    repo.rows['c1'] = <String, Object?>{
      'id': 'c1',
      'project_id': 'p1',
      'name': 'Old',
    };
    repo.failUpdate = true;
    final notifier = await boot('p1');
    await expectLater(notifier.rename('c1', 'New'), throwsA(isA<InkError>()));
    final list = container
        .read(charactersControllerProvider('p1'))
        .valueOrNull!;
    expect(list.single.name, 'Old'); // 回滚
  });
}
