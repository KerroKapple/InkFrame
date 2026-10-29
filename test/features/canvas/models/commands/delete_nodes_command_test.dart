// DeleteNodesCommand：撤销栈里的「删除 N 个节点」（连带它们的线）。
//
// 装置：ProviderContainer + 本地 _Env（取一个 Provider 的 Ref 当命令环境）；节点控制器覆盖成
// FakeNodesController 的记录子类，先挂订阅（autoDispose）再等它加载完。
//
// 变异对照：
// - revert 里「restoreAll 返回 0 ⇒ gone」删掉 ⇒「restoreAll 返回 0 ⇒ gone」红；
// - revert 里导入节点的 invalidate 删掉 ⇒「撤销删除导入节点 ⇒ 节点控制器重建一次」红；
// - apply 不换新令牌 ⇒「apply 换新令牌，再 revert 用新令牌」红；
// - apply 不先筛「此刻还在内存里」⇒「apply 节点都不在 ⇒ gone」红（removeNodes 被调到）。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/import_keys.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/commands/delete_nodes_command.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../../_harness/fake_canvas.dart';

const String _c1 = 'c1';

final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations _zh = lookupAppLocalizations(const Locale('zh'));

class _Env implements CanvasCommandEnv {
  _Env(this.canvasId, this.ref);

  @override
  final String canvasId;

  @override
  final Ref ref;
}

final Provider<CanvasCommandEnv> _envProvider =
    Provider<CanvasCommandEnv>((ref) => _Env(_c1, ref));

/// 导入的图片节点（type_config.origin = import）。
const CanvasNode _imported = CanvasNode(
  id: 'imp',
  label: 'photo.png',
  type: CanvasNodeType.image,
  role: NodeRole.result,
  canvasId: _c1,
  typeConfig: <String, Object?>{ImportKeys.origin: ImportKeys.originImport},
);

/// 记下 build / removeNodes / restoreAll 的调用；restoreAll 的结果可以改写。
class _Nodes extends FakeNodesController {
  _Nodes(super.seed);

  int builds = 0;
  final List<Set<String>> removeNodesCalls = <Set<String>>[];
  final List<List<NodeDeletion>> restoreAllCalls = <List<NodeDeletion>>[];

  /// 非 null ⇒ restoreAll 不动内存、直接返回它（测「受影响行全 0」）。
  int? restoreResult;

  /// 非 null ⇒ restoreAll 抛它。
  InkError? restoreError;

  @override
  Future<List<CanvasNode>> build(String canvasId) {
    builds++;
    return super.build(canvasId);
  }

  /// 每次整批删除给的令牌都带一个与调用次数挂钩的边 id，好分辨「新令牌 / 旧令牌」。
  @override
  Future<List<NodeDeletion>> removeNodes(Set<String> ids) async {
    removeNodesCalls.add(Set<String>.of(ids));
    final int generation = removeNodesCalls.length;
    final List<NodeDeletion> tokens = await super.removeNodes(ids);
    return <NodeDeletion>[
      for (final NodeDeletion d in tokens)
        (node: d.node, edgeIds: <String>['gen-$generation']),
    ];
  }

  @override
  Future<int> restoreAll(List<NodeDeletion> deletions) {
    restoreAllCalls.add(List<NodeDeletion>.of(deletions));
    final InkError? error = restoreError;
    if (error != null) return Future<int>.error(error);
    final int? forced = restoreResult;
    if (forced != null) return Future<int>.value(forced);
    return super.restoreAll(deletions);
  }
}

void main() {
  late _Nodes nodes;
  late ProviderContainer container;

  Future<void> setUpWith(List<CanvasNode> seed) async {
    nodes = _Nodes(seed);
    container = ProviderContainer(overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(() => nodes),
    ]);
    addTearDown(container.dispose);
    container.listen(canvasNodesControllerProvider(_c1), (_, _) {});
    await container.read(canvasNodesControllerProvider(_c1).future);
  }

  CanvasCommandEnv env() => container.read(_envProvider);

  CanvasNodesController ctrl() =>
      container.read(canvasNodesControllerProvider(_c1).notifier);

  Set<String> idsInMemory() => <String>{
        for (final CanvasNode n
            in container.read(canvasNodesControllerProvider(_c1)).requireValue)
          n.id,
      };

  /// 先真删一次（拿到令牌），再用令牌建命令——同 canvas_node_delete.dart 的「做成之后才 record」。
  Future<DeleteNodesCommand> deleted(Set<String> ids) async {
    final List<NodeDeletion> tokens = await ctrl().removeNodes(ids);
    return DeleteNodesCommand(tokens);
  }

  test('revert 走一次 restoreAll，把节点放回内存', () async {
    await setUpWith(twoNodes);
    final DeleteNodesCommand cmd = await deleted(<String>{'a', 'b'});
    expect(idsInMemory(), isEmpty, reason: '前置：两张都删了');

    final CanvasCommandOutcome outcome = await cmd.revert(env());

    expect(outcome, CanvasCommandOutcome.done);
    expect(nodes.restoreAllCalls, hasLength(1), reason: '一次事务整批复原');
    expect(
      <String>{for (final NodeDeletion d in nodes.restoreAllCalls.single) d.node.id},
      <String>{'a', 'b'},
    );
    expect(idsInMemory(), <String>{'a', 'b'});
  });

  test('apply 换新令牌，再 revert 用新令牌', () async {
    await setUpWith(twoNodes);
    final DeleteNodesCommand cmd = await deleted(<String>{'a'});
    expect(await cmd.revert(env()), CanvasCommandOutcome.done);
    expect(nodes.restoreAllCalls.last.single.edgeIds, <String>['gen-1']);

    expect(await cmd.apply(env()), CanvasCommandOutcome.done);
    expect(nodes.removeNodesCalls.last, <String>{'a'});
    expect(idsInMemory(), <String>{'b'});

    expect(await cmd.revert(env()), CanvasCommandOutcome.done);
    expect(nodes.restoreAllCalls.last.single.edgeIds, <String>['gen-2'],
        reason: '重做之后的撤销要用重做那次删出来的令牌');
  });

  test('apply 节点都不在 ⇒ gone，不碰 removeNodes', () async {
    await setUpWith(twoNodes);
    final DeleteNodesCommand cmd = await deleted(<String>{'a'});
    // 没撤销就重做（等价于「重做时它已经不在了」）：内存里没有 'a'。
    expect(idsInMemory(), <String>{'b'});
    final int before = nodes.removeNodesCalls.length;

    expect(await cmd.apply(env()), CanvasCommandOutcome.gone);
    expect(nodes.removeNodesCalls, hasLength(before));
  });

  test('restoreAll 返回 0 ⇒ gone', () async {
    await setUpWith(twoNodes);
    final DeleteNodesCommand cmd = await deleted(<String>{'a'});
    nodes.restoreResult = 0;

    expect(await cmd.revert(env()), CanvasCommandOutcome.gone);
  });

  test('restoreAll 抛 InkError ⇒ failed', () async {
    await setUpWith(twoNodes);
    final DeleteNodesCommand cmd = await deleted(<String>{'a'});
    nodes.restoreError = const LocalIOError();

    expect(await cmd.revert(env()), CanvasCommandOutcome.failed);
  });

  test('label：1 / 3 个节点（en / zh）', () async {
    await setUpWith(<CanvasNode>[
      ...twoNodes,
      textNode('c', 'Node C', 600),
    ]);
    final DeleteNodesCommand one = await deleted(<String>{'a'});
    final DeleteNodesCommand three = DeleteNodesCommand(<NodeDeletion>[
      (node: twoNodes[0], edgeIds: const <String>[]),
      (node: twoNodes[1], edgeIds: const <String>[]),
      (node: textNode('c', 'Node C', 600), edgeIds: const <String>[]),
    ]);

    expect(one.label(_en), 'Delete 1 node');
    expect(three.label(_en), 'Delete 3 nodes');
    expect(one.label(_zh), '删除 1 个节点');
    expect(three.label(_zh), '删除 3 个节点');
    expect(three.affectedNodeIds, <String>{'a', 'b', 'c'});
  });

  test('撤销删除导入节点 ⇒ 节点控制器重建一次', () async {
    await setUpWith(<CanvasNode>[...twoNodes, _imported]);
    final DeleteNodesCommand cmd = await deleted(<String>{'imp'});
    expect(nodes.builds, 1, reason: '前置：只加载过一次');

    expect(await cmd.revert(env()), CanvasCommandOutcome.done);
    await container.read(canvasNodesControllerProvider(_c1).future);

    expect(nodes.builds, 2, reason: '令牌快照里没有导入回写的 url，要重载才看得到图');
  });

  test('撤销删除非导入节点 ⇒ 节点控制器不重建', () async {
    await setUpWith(<CanvasNode>[...twoNodes, _imported]);
    final DeleteNodesCommand cmd = await deleted(<String>{'a'});

    expect(await cmd.revert(env()), CanvasCommandOutcome.done);
    await container.read(canvasNodesControllerProvider(_c1).future);

    expect(nodes.builds, 1);
  });
}
