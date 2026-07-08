// PromptPresetsController —— 项目级提示词预设列表 + 增删改（按 projectId 分族）。
//
// 对齐 CharactersController：AutoDispose family AsyncNotifier + ME-27 _alive 守卫 +
// 乐观更新/InkError 回滚。全 TEXT，无资产服务。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/prompt_preset_repository.dart';
import '../models/prompt_preset.dart';
import 'serial_mutation_queue.dart';

final promptPresetsControllerProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      PromptPresetsController,
      List<PromptPreset>,
      String
    >(PromptPresetsController.new, name: 'promptPresetsControllerProvider');

class PromptPresetsController
    extends AutoDisposeFamilyAsyncNotifier<List<PromptPreset>, String>
    with SerialMutationQueue {
  bool _alive = false;

  @override
  Future<List<PromptPreset>> build(String projectId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final repo = await ref.watch(promptPresetRepositoryProvider.future);
    final rows = await repo.listByProject(projectId);
    return rows.map(PromptPreset.fromRow).toList(growable: false);
  }

  PromptPresetRepository get _repo {
    final r = ref.read(promptPresetRepositoryProvider).valueOrNull;
    if (r == null) throw StateError('promptPresetRepositoryProvider not ready');
    return r;
  }

  Future<String> create({
    required String name,
    String prompt = '',
    String negative = '',
    String prefix = '',
    String suffix = '',
  }) {
    final repo = _repo;
    final projectId = arg;
    return serialize<String>(() async {
      final id = await repo.create(
        projectId: projectId,
        name: name,
        prompt: prompt,
        negative: negative,
        prefix: prefix,
        suffix: suffix,
      );
      await _reload(repo, projectId);
      return id;
    });
  }

  Future<void> rename(String id, String name) {
    final repo = _repo;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <PromptPreset>[]) : const <PromptPreset>[];
      if (_alive) {
        state = AsyncData(<PromptPreset>[
          for (final p in previous)
            if (p.id == id) p.copyWith(name: name) else p,
        ]);
      }
      try {
        await repo.update(id, <String, Object?>{PromptPresetCol.name: name});
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
          _alive ? (state.valueOrNull ?? const <PromptPreset>[]) : const <PromptPreset>[];
      if (_alive) state = AsyncData(previous.where((p) => p.id != id).toList());
      try {
        await repo.softDelete(id);
      } on InkError {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  Future<void> _reload(PromptPresetRepository repo, String projectId) async {
    final rows = await repo.listByProject(projectId);
    if (_alive) {
      state = AsyncData(rows.map(PromptPreset.fromRow).toList(growable: false));
    }
  }
}
