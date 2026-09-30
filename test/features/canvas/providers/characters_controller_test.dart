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

  // ---- P4：角色编辑框要的四个薄方法 --------------------------------------

  Future<CharactersController> bootWithRefs(List<String> refs) {
    repo.rows['c1'] = <String, Object?>{
      'id': 'c1',
      'project_id': 'p1',
      'name': 'Hero',
      'description': 'old',
      'reference_image_paths': refs,
    };
    return boot('p1');
  }

  List<String> refsOf() => container
      .read(charactersControllerProvider('p1'))
      .valueOrNull!
      .single
      .referenceImagePaths;

  test('setDescription：落库 + 乐观更新', () async {
    final notifier = await bootWithRefs(<String>['characters/c1-0.png']);
    await notifier.setDescription('c1', '中年男性，粗布行囊');
    expect(repo.rows['c1']!['description'], '中年男性，粗布行囊');
    expect(
      container.read(charactersControllerProvider('p1')).valueOrNull!.single.description,
      '中年男性，粗布行囊',
    );
  });

  test('setDescription：repo 抛 InkError → 回滚', () async {
    final notifier = await bootWithRefs(<String>[]);
    repo.failUpdate = true;
    await expectLater(notifier.setDescription('c1', 'new'), throwsA(isA<InkError>()));
    expect(
      container.read(charactersControllerProvider('p1')).valueOrNull!.single.description,
      'old',
    );
  });

  test('addReferenceImage：命名取「已用过的最大序号 +1」，不是 length', () async {
    // 删掉中间一张后的典型残局：只剩 -0 与 -2；用 length(=2) 会撞上已存在的 c1-2，
    // 而 File.copy 是静默覆盖。
    final notifier =
        await bootWithRefs(<String>['characters/c1-0.png', 'characters/c1-2.png']);
    await notifier.addReferenceImage('c1', sourceAbsolutePath: '/src/new.png');
    expect(assets.imported.single, 'characters/c1-3.png');
    expect(refsOf(), <String>[
      'characters/c1-0.png',
      'characters/c1-2.png',
      'characters/c1-3.png',
    ]);
    expect(repo.rows['c1']!['reference_image_paths'], hasLength(3));
  });

  test('addReferenceImage：空列表从 0 起', () async {
    final notifier = await bootWithRefs(<String>[]);
    await notifier.addReferenceImage('c1', sourceAbsolutePath: '/src/a.png');
    expect(assets.imported.single, 'characters/c1-0.png');
  });

  test('addReferenceImage：落库失败 → 回滚 + 删掉刚落盘的图，不留孤儿', () async {
    final notifier = await bootWithRefs(<String>['characters/c1-0.png']);
    repo.failUpdate = true;
    await expectLater(
      notifier.addReferenceImage('c1', sourceAbsolutePath: '/src/new.png'),
      throwsA(isA<InkError>()),
    );
    expect(refsOf(), <String>['characters/c1-0.png'], reason: '回滚');
    expect(assets.deleted, contains('characters/c1-1.png'), reason: '孤儿文件要清掉');
  });

  test('removeReferenceImage：先落库再删文件', () async {
    final notifier = await bootWithRefs(<String>[
      'characters/c1-0.png',
      'characters/c1-1.png',
      'characters/c1-2.png',
    ]);
    await notifier.removeReferenceImage('c1', 1);
    expect(refsOf(), <String>['characters/c1-0.png', 'characters/c1-2.png']);
    expect(assets.deleted, <String>['characters/c1-1.png']);
  });

  test('removeReferenceImage：落库失败 → 回滚且不动磁盘', () async {
    final notifier =
        await bootWithRefs(<String>['characters/c1-0.png', 'characters/c1-1.png']);
    repo.failUpdate = true;
    await expectLater(notifier.removeReferenceImage('c1', 0), throwsA(isA<InkError>()));
    expect(refsOf(), hasLength(2), reason: '回滚');
    expect(assets.deleted, isEmpty, reason: '库没写成就不能删文件');
  });

  test('removeReferenceImage：越界下标是 no-op', () async {
    final notifier = await bootWithRefs(<String>['characters/c1-0.png']);
    await notifier.removeReferenceImage('c1', 5);
    expect(refsOf(), hasLength(1));
    expect(assets.deleted, isEmpty);
  });

  test('reorderReferenceImages：顺序即注入次序，落库', () async {
    final notifier = await bootWithRefs(<String>[
      'characters/c1-0.png',
      'characters/c1-1.png',
      'characters/c1-2.png',
    ]);
    await notifier.reorderReferenceImages('c1', 2, 0);
    const List<String> expected = <String>[
      'characters/c1-2.png',
      'characters/c1-0.png',
      'characters/c1-1.png',
    ];
    expect(refsOf(), expected);
    expect(repo.rows['c1']!['reference_image_paths'], expected);
  });

  test('reorderReferenceImages：同位 / 越界是 no-op', () async {
    final notifier =
        await bootWithRefs(<String>['characters/c1-0.png', 'characters/c1-1.png']);
    await notifier.reorderReferenceImages('c1', 1, 1);
    await notifier.reorderReferenceImages('c1', 0, 9);
    expect(refsOf(), <String>['characters/c1-0.png', 'characters/c1-1.png']);
  });

  test('nextReferenceIndex：只认自己 id 的编号，认不出就从 0 起', () {
    expect(CharactersController.nextReferenceIndex('c1', <String>[]), 0);
    expect(CharactersController.nextReferenceIndex('c1', <String>['characters/c1-0.png']), 1);
    expect(
      CharactersController.nextReferenceIndex('c1', <String>[
        'characters/c1-0.png',
        'characters/c1-7.jpg',
        'characters/c1-2.png',
      ]),
      8,
    );
    expect(
      CharactersController.nextReferenceIndex('c1', <String>['characters/other-9.png']),
      0,
      reason: '别人的编号不算数',
    );
    expect(
      CharactersController.nextReferenceIndex('c1', <String>['characters/c1.png']),
      0,
      reason: '没有 -n 后缀的旧数据不算数',
    );
  });
}
