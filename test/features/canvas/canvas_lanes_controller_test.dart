import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';

class _FakeLaneRepo implements StyleLaneRepository {
  final Map<String, Map<String, Object?>> store = {};
  int _seq = 0;
  @override
  Future<String> create({required String canvasId, String label = '', String stylePrompt = '', int sortOrder = 0, String? tintColor, double size = 400.0}) async {
    final id = 'lane-${_seq++}';
    store[id] = {'id': id, 'canvas_id': canvasId, 'label': label, 'style_prompt': stylePrompt, 'sort_order': sortOrder, 'tint_color': tintColor, 'size': size};
    return id;
  }
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      store.values.where((r) => r['canvas_id'] == canvasId).toList();
  @override
  Future<int> update(String id, Map<String, Object?> patch) async { store[id]?.addAll(patch); return 1; }
  @override
  Future<int> softDelete(String id) async => store.remove(id) == null ? 0 : 1;
  @override
  Future<Map<String, Object?>?> findById(String id) async => store[id];
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => store.remove(id) == null ? 0 : 1;
}

void main() {
  test('createLane appends and updates state', () async {
    final repo = _FakeLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final lane = await c.read(canvasLanesControllerProvider('cv').notifier).createLane(label: 'A');
    expect(lane.label, 'A');
    final lanes = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(lanes.map((l) => l.id), contains(lane.id));
  });

  test('deleteLane removes from state', () async {
    final repo = _FakeLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final lane = await notifier.createLane(label: 'A');
    await notifier.deleteLane(lane.id);
    expect(c.read(canvasLanesControllerProvider('cv')).valueOrNull, isEmpty);
  });
}
