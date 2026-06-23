import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
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

/// update 调用时抛出 InkError，用于回滚测试。
class _ThrowingOnUpdateRepo extends _FakeLaneRepo {
  @override
  Future<int> update(String id, Map<String, Object?> patch) =>
      Future.error(const LocalIOError(extra: {'op': 'update'}));
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

  test('reorderLanes [c,a,b] → 状态顺序 c,a,b 且 sort_order=0,1,2，repo 收到更新', () async {
    final repo = _FakeLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final a = await notifier.createLane(label: 'a');
    final b = await notifier.createLane(label: 'b');
    final lane = await notifier.createLane(label: 'c');
    // 重排为 c,a,b
    await notifier.reorderLanes([lane.id, a.id, b.id]);
    final lanes = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(lanes.map((l) => l.label), ['c', 'a', 'b']);
    expect(lanes.map((l) => l.sortOrder), [0, 1, 2]);
    // repo 中 sort_order 已更新
    expect(repo.store[lane.id]!['sort_order'], 0);
    expect(repo.store[a.id]!['sort_order'], 1);
    expect(repo.store[b.id]!['sort_order'], 2);
  });

  test('reorderLanes → repo.update 抛出 InkError 时回滚状态', () async {
    final repo = _ThrowingOnUpdateRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final a = await notifier.createLane(label: 'a');
    final b = await notifier.createLane(label: 'b');
    final lane = await notifier.createLane(label: 'c');
    final before = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    await expectLater(
      notifier.reorderLanes([lane.id, a.id, b.id]),
      throwsA(isA<InkError>()),
    );
    // 状态回滚到重排前
    final after = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(after.map((l) => l.id), before.map((l) => l.id));
    expect(after.map((l) => l.sortOrder), before.map((l) => l.sortOrder));
  });

  test('reorderLanes 收到不完整 id 列表（少于现有数量）→ 状态不变、不重排', () async {
    final repo = _FakeLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final a = await notifier.createLane(label: 'a');
    await notifier.createLane(label: 'b');
    await notifier.createLane(label: 'c');
    final before = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    // 只给 1 个 id（< 现有 3 条）→ 控制器早退保持原状（length 不匹配 guard）。
    await notifier.reorderLanes([a.id]);
    final after = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(after.map((l) => l.id), before.map((l) => l.id));
    expect(after.map((l) => l.sortOrder), before.map((l) => l.sortOrder));
  });

  test('updateLane → repo.update 抛 InkError 时回滚 size', () async {
    final repo = _ThrowingOnUpdateRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final lane = await notifier.createLane(label: 'a');
    final origSize = c
        .read(canvasLanesControllerProvider('cv'))
        .valueOrNull!
        .firstWhere((l) => l.id == lane.id)
        .size;
    await expectLater(
      notifier.updateLane(lane.id, size: origSize + 500),
      throwsA(isA<InkError>()),
    );
    // 乐观写 size 已回滚。
    final after = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(after.firstWhere((l) => l.id == lane.id).size, origSize);
  });
}
