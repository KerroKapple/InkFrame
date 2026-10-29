// SetCurrentTakeCommand：「设为当前」那一步的 revert / apply。
//
// 装配：ProviderContainer + 真 CanvasNodesController / CanvasEdgesController（InMemoryNodeRepository /
// InMemoryEdgeRepository + FakeUnitOfWork）；命令环境在测试里自建（Provider<CanvasCommandEnv>），直接拿
// revert / apply 的结果断言 done / gone。节点 / 边控制器挂订阅保活（autoDispose）。
//
// 变异对照：
// - revert 写成删除固定（写 null）而不是写回旧值 ⇒「revert 写回旧 pinned」红。
// - revert 在配置节点不在时返回 done ⇒「revert：配置节点已删 → gone」红。
// - apply 不查新固定 take 在不在 ⇒「apply：新固定 take 已删 → gone」红。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/take_keys.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/commands/set_current_take_command.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../../_harness/fake_repositories.dart';
import '../../../../_harness/fake_unit_of_work.dart';

const String _cid = 'c1';

final AppLocalizations _zh = lookupAppLocalizations(const Locale('zh'));

class _Env implements CanvasCommandEnv {
  _Env(this.canvasId, this.ref);

  @override
  final String canvasId;

  @override
  final Ref ref;
}

final Provider<CanvasCommandEnv> _envProvider =
    Provider<CanvasCommandEnv>((Ref ref) => _Env(_cid, ref));

void main() {
  late InMemoryNodeRepository nodes;
  late InMemoryEdgeRepository edges;
  late ProviderContainer container;
  late String cfg;
  late String t1;
  late String t2;
  late String t3;

  final nodesProvider = canvasNodesControllerProvider(_cid);
  final edgesProvider = canvasEdgesControllerProvider(_cid);

  Future<String> take(String sourceId, int day) async {
    final String id = await nodes.create(
      canvasId: _cid,
      type: 'image',
      nodeRole: 'result',
      sourceNodeId: sourceId,
      typeConfig: <String, Object?>{'image_url': 'images/$day.png'},
    );
    await nodes.update(id, <String, Object?>{'created_at': DateTime.utc(2026, 5, day)});
    return id;
  }

  setUp(() async {
    nodes = InMemoryNodeRepository();
    edges = InMemoryEdgeRepository();
    cfg = await nodes.create(
      canvasId: _cid,
      type: 'image',
      nodeRole: 'config',
      typeConfig: const <String, Object?>{'prompt': 'harbor'},
    );
    t1 = await take(cfg, 1);
    t2 = await take(cfg, 2);
    t3 = await take(cfg, 3);
    container = ProviderContainer(overrides: <Override>[
      nodeRepositoryProvider.overrideWith((_) async => nodes),
      edgeRepositoryProvider.overrideWith((_) async => edges),
      unitOfWorkProvider.overrideWith(
        (_) async => FakeUnitOfWork(FakeRepositoryScope(nodes: nodes, edges: edges)),
      ),
    ]);
    addTearDown(container.dispose);
    container.listen(nodesProvider, (_, _) {});
    container.listen(edgesProvider, (_, _) {});
    await container.read(nodesProvider.future);
    await container.read(edgesProvider.future);
  });

  CanvasCommandEnv env() => container.read(_envProvider);

  /// 配置节点此刻在内存里的 pinned_result_id 原值（键在不在都看得见）。
  Map<String, Object?> memoryConfig() =>
      container.read(nodesProvider).requireValue.firstWhere((CanvasNode n) => n.id == cfg).typeConfig;

  Map<String, Object?> storedConfig() => nodes.rows[cfg]!['type_config']! as Map<String, Object?>;

  /// 先把配置节点的固定写成 [pin]（模拟「设为当前」已经做成）。
  Future<void> pinTo(String pin) => container
      .read(nodesProvider.notifier)
      .patchTypeConfigMany(<String, Map<String, Object?>>{
        cfg: <String, Object?>{TakeKeys.pinnedResultId: pin},
      });

  SetCurrentTakeCommand command({String? previous, required String pinned, int? number = 3}) =>
      SetCurrentTakeCommand(
        configNodeId: cfg,
        previousPinnedResultId: previous,
        pinnedResultId: pinned,
        takeNumber: number,
      );

  test('label：有号「设为当前 · take 3」，无号「设为当前」', () {
    expect(command(pinned: 'x', number: 3).label(_zh), '设为当前 · take 3');
    expect(command(pinned: 'x', number: null).label(_zh), '设为当前');
    expect(command(previous: 'a', pinned: 'b').affectedNodeIds, <String>{cfg, 'b'});
  });

  test('revert 写回旧 pinned；旧值缺省写 null', () async {
    // 原来固定 t1，设成 t3；撤销 ⇒ 写回 t1（不是清掉固定）。
    await pinTo(t3);
    expect(await command(previous: t1, pinned: t3).revert(env()), CanvasCommandOutcome.done);
    expect(memoryConfig()[TakeKeys.pinnedResultId], t1);
    expect(storedConfig()[TakeKeys.pinnedResultId], t1);

    // 原来没固定：撤销写 JSON null（键在、值为 null），判据回落最新。
    await pinTo(t2);
    expect(await command(pinned: t2).revert(env()), CanvasCommandOutcome.done);
    expect(memoryConfig().containsKey(TakeKeys.pinnedResultId), isTrue);
    expect(memoryConfig()[TakeKeys.pinnedResultId], isNull);
    expect(storedConfig()[TakeKeys.pinnedResultId], isNull);
  });

  test('apply 再设回；旧固定的那张已删时 revert 仍 done', () async {
    await pinTo(t1);
    await container.read(nodesProvider.notifier).removeNodes(<String>{t1});
    expect(await command(previous: t1, pinned: t3).revert(env()), CanvasCommandOutcome.done,
        reason: '旧固定的 t1 已删：照样写回，判据自然回落最新');
    expect(memoryConfig()[TakeKeys.pinnedResultId], t1);

    expect(await command(previous: t1, pinned: t3).apply(env()), CanvasCommandOutcome.done);
    expect(memoryConfig()[TakeKeys.pinnedResultId], t3);
    expect(storedConfig()[TakeKeys.pinnedResultId], t3);
  });

  test('revert：配置节点已删 → gone', () async {
    await pinTo(t3);
    await container.read(nodesProvider.notifier).removeNodes(<String>{cfg});
    expect(await command(previous: t1, pinned: t3).revert(env()), CanvasCommandOutcome.gone);
    expect(storedConfig()[TakeKeys.pinnedResultId], t3, reason: 'gone 不写库');
  });

  test('apply：新固定 take 已删 → gone', () async {
    await container.read(nodesProvider.notifier).removeNodes(<String>{t3});
    expect(await command(pinned: t3).apply(env()), CanvasCommandOutcome.gone);
    expect(storedConfig().containsKey(TakeKeys.pinnedResultId), isFalse, reason: 'gone 不写库');

    // 配置节点不在同样 gone。
    await container.read(nodesProvider.notifier).removeNodes(<String>{cfg});
    expect(await command(pinned: t2).apply(env()), CanvasCommandOutcome.gone);
  });

  test('撤销 / 重做不碰边：revert / apply 前后边控制器的边表不变', () async {
    // t2 当了下游的首帧（data 边）。
    final String video = await nodes.create(canvasId: _cid, type: 'video', nodeRole: 'config');
    await edges.create(canvasId: _cid, sourceNodeId: t2, targetNodeId: video, edgeType: 'data');
    container.invalidate(edgesProvider);
    container.invalidate(nodesProvider);
    await container.read(nodesProvider.future);
    final List<CanvasEdge> before = await container.read(edgesProvider.future);
    expect(before, hasLength(1));
    final Map<String, Map<String, Object?>> rowsBefore = <String, Map<String, Object?>>{
      for (final MapEntry<String, Map<String, Object?>> e in edges.rows.entries)
        e.key: Map<String, Object?>.of(e.value),
    };

    await pinTo(t3);
    expect(await command(previous: t2, pinned: t3).revert(env()), CanvasCommandOutcome.done);
    expect(await command(previous: t2, pinned: t3).apply(env()), CanvasCommandOutcome.done);

    expect(container.read(edgesProvider).requireValue, before);
    expect(edges.rows, rowsBefore);
  });
}
