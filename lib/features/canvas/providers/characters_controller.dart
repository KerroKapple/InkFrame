// CharactersController —— 项目级角色列表 + 增删改（按 projectId 分族）。
//
// 对齐 CanvasNodesController：AutoDispose family AsyncNotifier + ME-27 _alive 守卫 +
// 乐观更新/InkError 回滚。角色参考图落盘经 CharacterAssetService（项目级目录）。
import 'dart:io' show FileSystemException;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/di/character_assets.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/character_asset_service.dart';
import '../../../core/interfaces/character_repository.dart';
import '../models/character.dart';
import 'serial_mutation_queue.dart';

final charactersControllerProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      CharactersController,
      List<Character>,
      String
    >(CharactersController.new, name: 'charactersControllerProvider');

class CharactersController
    extends AutoDisposeFamilyAsyncNotifier<List<Character>, String>
    with SerialMutationQueue {
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

  CharacterAssetService get _assets => ref.read(characterAssetServiceProvider);

  /// 从一张已存在的绝对路径图片新建角色：先建记录拿 id → 导图命名 {id}-0 → 回填参考图。
  /// 导图或回填任一步失败：清记录 + 清可能已落盘的图（best-effort），保留原始错误上抛，
  /// 不留 ghost 记录/孤儿文件。返回新角色 id。
  Future<String> createFromImage({
    required String name,
    required String sourceAbsolutePath,
  }) {
    final projectId = arg;
    final repo = _repo;
    final assets = _assets;
    return serialize<String>(() async {
      final id = await repo.create(projectId: projectId, name: name);
      String? rel;
      // 补偿：清记录 + 清可能已落盘的图（best-effort），补偿失败不掩盖原始错误。
      Future<void> compensate() async {
        try {
          await repo.hardDelete(id);
        } on InkError catch (_) {
          // 仓储层只抛 InkError；补偿失败也不掩盖原始错误。
        }
        final imported = rel;
        if (imported != null) {
          await assets.delete(projectId: projectId, relativePath: imported);
        }
      }

      // 捕获集 = try 体真实抛出集：仓储 InkError / 资产服务 CharacterAssetError /
      // dart:io FileSystemException——不捕宽泛 Exception（铁律）。
      try {
        rel = await assets.importImage(
          projectId: projectId,
          sourceAbsolutePath: sourceAbsolutePath,
          fileBaseName: '$id-0',
        );
        await repo.update(id, <String, Object?>{
          CharacterCol.referenceImagePaths: <String>[rel],
        });
      } on InkError catch (e, st) {
        await compensate();
        Error.throwWithStackTrace(e, st);
      } on CharacterAssetError catch (e, st) {
        await compensate();
        Error.throwWithStackTrace(e, st);
      } on FileSystemException catch (e, st) {
        await compensate();
        Error.throwWithStackTrace(e, st);
      }
      await _reload(repo, projectId);
      return id;
    });
  }

  Future<void> rename(String id, String name) {
    final repo = _repo;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <Character>[]) : const <Character>[];
      if (_alive) {
        state = AsyncData(<Character>[
          for (final c in previous)
            if (c.id == id) c.copyWith(name: name) else c,
        ]);
      }
      try {
        await repo.update(id, <String, Object?>{CharacterCol.name: name});
      } on InkError {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  Future<void> delete(String id) {
    final repo = _repo;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <Character>[]) : const <Character>[];
      if (_alive) state = AsyncData(previous.where((c) => c.id != id).toList());
      try {
        await repo.softDelete(id);
      } on InkError {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
      // 软删可恢复（restore 存在于契约）：不销毁参考图资产，留待 hardDelete/清理路径，
      // 否则 restore 后角色参考图指向已删文件（评审 F2）。
    });
  }

  Future<void> _reload(CharacterRepository repo, String projectId) async {
    final rows = await repo.listByProject(projectId);
    if (_alive) {
      state = AsyncData(rows.map(Character.fromRow).toList(growable: false));
    }
  }
}
