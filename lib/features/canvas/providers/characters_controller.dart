// CharactersController —— 项目级角色列表 + 增删改（按 projectId 分族）。
//
// 对齐 CanvasNodesController：AutoDispose family AsyncNotifier + ME-27 _alive 守卫 +
// 乐观更新/InkError 回滚。角色参考图落盘经 CharacterAssetService（项目级目录）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/di/character_assets.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/character_asset_service.dart';
import '../../../core/interfaces/character_repository.dart';
import '../models/character.dart';

final charactersControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CharactersController, List<Character>, String>(
  CharactersController.new,
  name: 'charactersControllerProvider',
);

class CharactersController
    extends AutoDisposeFamilyAsyncNotifier<List<Character>, String> {
  bool _alive = false;

  @override
  Future<List<Character>> build(String projectId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final repo = await ref.watch(characterRepositoryProvider.future);
    final rows = await repo.listByProject(projectId);
    return rows.map(Character.fromRow).toList(growable: false);
  }

  // build 已 await 过 characterRepositoryProvider.future，故此处同步取已就绪实例。
  CharacterRepository get _repo {
    final r = ref.read(characterRepositoryProvider).valueOrNull;
    if (r == null) throw StateError('characterRepositoryProvider not ready');
    return r;
  }

  CharacterAssetService get _assets =>
      ref.read(characterAssetServiceProvider);

  /// 从一张已存在的绝对路径图片新建角色：先建记录拿 id → 导图命名 {id}-0 → 回填参考图。
  /// 导图失败回滚记录并上抛。返回新角色 id。
  Future<String> createFromImage({
    required String name,
    required String sourceAbsolutePath,
  }) async {
    final projectId = arg;
    final repo = _repo;
    final id = await repo.create(projectId: projectId, name: name);
    final String rel;
    try {
      rel = await _assets.importImage(
        projectId: projectId,
        sourceAbsolutePath: sourceAbsolutePath,
        fileBaseName: '$id-0',
      );
    } catch (_) {
      await repo.hardDelete(id);
      rethrow;
    }
    await repo.update(id, <String, Object?>{
      CharacterCol.referenceImagePaths: <String>[rel],
    });
    await _reload();
    return id;
  }

  Future<void> rename(String id, String name) async {
    final repo = _repo;
    final previous = state.valueOrNull ?? const <Character>[];
    state = AsyncData(<Character>[
      for (final c in previous)
        if (c.id == id) c.copyWith(name: name) else c,
    ]);
    try {
      await repo.update(id, <String, Object?>{CharacterCol.name: name});
    } on InkError {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final repo = _repo;
    final assets = _assets;
    final projectId = arg;
    final previous = state.valueOrNull ?? const <Character>[];
    final removed = previous.where((c) => c.id == id).toList();
    state = AsyncData(previous.where((c) => c.id != id).toList());
    try {
      await repo.softDelete(id);
    } on InkError {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
    // 资产清理尽力而为——不影响 UI 状态。
    for (final c in removed) {
      for (final rel in c.referenceImagePaths) {
        await assets.delete(projectId: projectId, relativePath: rel);
      }
    }
  }

  Future<void> _reload() async {
    final rows = await _repo.listByProject(arg);
    if (_alive) {
      state = AsyncData(rows.map(Character.fromRow).toList(growable: false));
    }
  }
}
