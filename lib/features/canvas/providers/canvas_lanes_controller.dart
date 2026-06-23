// CanvasLanesController — DB-backed 画布泳道集合（按 canvasId 分族）。
// 乐观更新 + 失败回滚，与 CanvasNodesController 同策略（ME-27 _alive 守卫）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/style_lane_repository.dart';
import '../models/style_lane.dart';
import '../util/lane_geometry.dart';

final canvasLanesControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CanvasLanesController, List<StyleLane>, String>(
  CanvasLanesController.new,
  name: 'canvasLanesControllerProvider',
);

class CanvasLanesController
    extends AutoDisposeFamilyAsyncNotifier<List<StyleLane>, String> {
  bool _alive = false;

  @override
  Future<List<StyleLane>> build(String canvasId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final repo = await ref.watch(styleLaneRepositoryProvider.future);
    final rows = await repo.listByCanvas(canvasId);
    final lanes = rows.map(StyleLane.fromRow).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return lanes;
  }

  StyleLaneRepository get _repo {
    final repo = ref.read(styleLaneRepositoryProvider).valueOrNull;
    if (repo == null) throw StateError('styleLaneRepositoryProvider not ready');
    return repo;
  }

  Future<StyleLane> createLane({
    String label = '',
    String stylePrompt = '',
    String? tintColor,
  }) async {
    final repo = _repo;
    final canvasId = arg;
    final previous = state.valueOrNull ?? const <StyleLane>[];
    final nextOrder =
        previous.isEmpty ? 0 : previous.map((l) => l.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final id = await repo.create(
      canvasId: canvasId,
      label: label,
      stylePrompt: stylePrompt,
      sortOrder: nextOrder,
      tintColor: tintColor,
    );
    final lane = StyleLane(
      id: id,
      canvasId: canvasId,
      label: label,
      stylePrompt: stylePrompt,
      sortOrder: nextOrder,
      tintColor: tintColor,
    );
    if (_alive) state = AsyncData([...previous, lane]);
    return lane;
  }

  Future<void> updateLane(
    String id, {
    String? label,
    String? stylePrompt,
    String? tintColor,
    bool clearTint = false,
    double? size,
  }) async {
    final repo = _repo;
    final previous = state.valueOrNull ?? const <StyleLane>[];
    final patch = <String, Object?>{
      'label': ?label,
      'style_prompt': ?stylePrompt,
      if (clearTint) 'tint_color': null else 'tint_color': ?tintColor,
      'size': ?size,
    };
    if (patch.isEmpty) return;
    state = AsyncData([
      for (final l in previous)
        if (l.id == id)
          l.copyWith(
            label: label,
            stylePrompt: stylePrompt,
            tintColor: tintColor,
            clearTint: clearTint,
            size: size,
          )
        else
          l,
    ]);
    try {
      await repo.update(id, patch);
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }

  /// 按给定 id 顺序重排泳道，sort_order=下标。乐观更新 + 失败回滚。
  Future<void> reorderLanes(List<String> orderedIds) async {
    final repo = _repo;
    final previous = state.valueOrNull ?? const <StyleLane>[];
    final byId = {for (final l in previous) l.id: l};
    final reordered = <StyleLane>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final lane = byId[orderedIds[i]];
      if (lane != null) reordered.add(lane.copyWith(sortOrder: i));
    }
    if (reordered.length != previous.length) return; // 不完整顺序，跳过
    state = AsyncData(reordered);
    try {
      for (var i = 0; i < reordered.length; i++) {
        if (previous.firstWhere((l) => l.id == reordered[i].id).sortOrder != i) {
          await repo.update(reordered[i].id, <String, Object?>{'sort_order': i});
        }
      }
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> deleteLane(String id) async {
    final repo = _repo;
    final previous = state.valueOrNull ?? const <StyleLane>[];
    state = AsyncData(previous.where((l) => l.id != id).toList());
    try {
      await repo.softDelete(id);
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }
}

/// 画布泳道方向（读 canvases.lane_direction）。
final canvasLaneDirectionProvider =
    FutureProvider.autoDispose.family<LaneDirection, String>((ref, canvasId) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  final row = await repo.findById(canvasId);
  return laneDirectionFromString((row?['lane_direction'] as String?) ?? 'horizontal');
});

/// 切换并持久化泳道方向，然后失效方向 provider 触发重读。
/// 取 WidgetRef（read/invalidate 即够用）——调用方均为 widget。
Future<void> setLaneDirection(WidgetRef ref, String canvasId, LaneDirection dir) async {
  final repo = await ref.read(canvasRepositoryProvider.future);
  await repo.update(canvasId, {'lane_direction': laneDirectionToString(dir)});
  ref.invalidate(canvasLaneDirectionProvider(canvasId));
}
