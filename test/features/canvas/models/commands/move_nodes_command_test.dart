// MoveNodesCommand：撤销栈里的「移动 N 个节点 / 移入泳道「X」/ 移出泳道「X」」。
//
// 位移按「目标位置 − 此刻位置」算（期间被别处挪过也回得去），泳道直接写目标道；一次 moveNodes 整批落库。
// 装置：ProviderContainer + 本地 _Env；节点控制器 = FakeNodesController 的记录子类，先挂订阅再等加载完。
//
// 变异对照：
// - revert 的位移改成 before − after ⇒「期间被别处挪过 ⇒ 仍回到 before 位置与原道」红；
// - 不跳过已不在的节点 ⇒「节点已删 ⇒ gone」红（moveNodes 被调到）；
// - label 名字空时不落 laneUntitled ⇒「名字空写 Untitled lane」红。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/commands/move_nodes_command.dart';
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

/// 记下 moveNodes 的每一次整批调用（再交给父类就地改内存）。
class _Nodes extends FakeNodesController {
  _Nodes(super.seed);

  final List<Map<String, NodeMove>> moveCalls = <Map<String, NodeMove>>[];

  @override
  Future<void> moveNodes(Map<String, NodeMove> moves) {
    moveCalls.add(Map<String, NodeMove>.of(moves));
    return super.moveNodes(moves);
  }
}

/// 拖进 Dusk 的那一步：before = Rain 道 (40, 40)，after = Dusk 道 (40, 440)。
const MoveNodesCommand _intoDusk = MoveNodesCommand(
  before: <String, ({Offset world, String? laneId})>{
    'a': (world: Offset(40, 40), laneId: 'lane-1'),
  },
  after: <String, ({Offset world, String? laneId})>{
    'a': (world: Offset(40, 440), laneId: 'lane-2'),
  },
  label: (kind: MoveNodesLabelKind.intoLane, laneName: 'Dusk'),
);

CanvasNode _nodeAt(String id, Offset position, String? laneId) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.text,
      canvasId: _c1,
      laneId: laneId,
      position: position,
    );

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

  CanvasNode nodeOf(String id) => container
      .read(canvasNodesControllerProvider(_c1))
      .requireValue
      .singleWhere((CanvasNode n) => n.id == id);

  test('revert 期间被别处挪过 ⇒ 仍回到 before 位置与原道（一次 moveNodes）', () async {
    // 拖进 Dusk 之后，别处又把它挪到了 (500, 300)。
    await setUpWith(<CanvasNode>[_nodeAt('a', const Offset(500, 300), 'lane-2')]);

    expect(await _intoDusk.revert(env()), CanvasCommandOutcome.done);

    expect(nodes.moveCalls, hasLength(1), reason: '整批一次落库');
    final NodeMove move = nodes.moveCalls.single['a']!;
    expect(move.delta, const Offset(-460, -260));
    expect(move.laneId, 'lane-1');
    expect(nodeOf('a').position, const Offset(40, 40));
    expect(nodeOf('a').laneId, 'lane-1');
  });

  test('apply ⇒ 回到 after 位置与目标道', () async {
    await setUpWith(<CanvasNode>[_nodeAt('a', const Offset(40, 40), 'lane-1')]);

    expect(await _intoDusk.apply(env()), CanvasCommandOutcome.done);

    expect(nodeOf('a').position, const Offset(40, 440));
    expect(nodeOf('a').laneId, 'lane-2');
  });

  test('revert 回原道是「不在道里」⇒ laneId 写 null', () async {
    const MoveNodesCommand outOfRain = MoveNodesCommand(
      before: <String, ({Offset world, String? laneId})>{
        'a': (world: Offset(40, 40), laneId: null),
      },
      after: <String, ({Offset world, String? laneId})>{
        'a': (world: Offset(40, 440), laneId: 'lane-1'),
      },
      label: (kind: MoveNodesLabelKind.intoLane, laneName: 'Rain'),
    );
    await setUpWith(<CanvasNode>[_nodeAt('a', const Offset(40, 440), 'lane-1')]);

    expect(await outOfRain.revert(env()), CanvasCommandOutcome.done);

    expect(nodeOf('a').laneId, isNull);
    expect(nodeOf('a').position, const Offset(40, 40));
  });

  test('节点已删 ⇒ gone，不调 moveNodes', () async {
    await setUpWith(<CanvasNode>[_nodeAt('other', Offset.zero, null)]);

    expect(await _intoDusk.revert(env()), CanvasCommandOutcome.gone);
    expect(await _intoDusk.apply(env()), CanvasCommandOutcome.gone);
    expect(nodes.moveCalls, isEmpty);
  });

  test('只挪还在的：两张里删了一张，另一张照挪', () async {
    const MoveNodesCommand two = MoveNodesCommand(
      before: <String, ({Offset world, String? laneId})>{
        'a': (world: Offset(0, 0), laneId: null),
        'b': (world: Offset(100, 0), laneId: null),
      },
      after: <String, ({Offset world, String? laneId})>{
        'a': (world: Offset(0, 50), laneId: null),
        'b': (world: Offset(100, 50), laneId: null),
      },
      label: (kind: MoveNodesLabelKind.move, laneName: null),
    );
    await setUpWith(<CanvasNode>[_nodeAt('b', const Offset(100, 50), null)]);

    expect(await two.revert(env()), CanvasCommandOutcome.done);
    expect(nodes.moveCalls.single.keys, <String>['b']);
    expect(nodeOf('b').position, const Offset(100, 0));
  });

  test('label：移入 / 移出泳道，名字空写 Untitled lane；普通移动按张数', () {
    expect(_intoDusk.label(_en), 'Move into lane “Dusk”');
    expect(_intoDusk.label(_zh), '移入泳道「Dusk」');

    const MoveNodesCommand outOf = MoveNodesCommand(
      before: <String, ({Offset world, String? laneId})>{},
      after: <String, ({Offset world, String? laneId})>{},
      label: (kind: MoveNodesLabelKind.outOfLane, laneName: 'Rain'),
    );
    expect(outOf.label(_en), 'Move out of lane “Rain”');
    expect(outOf.label(_zh), '移出泳道「Rain」');

    const MoveNodesCommand unnamed = MoveNodesCommand(
      before: <String, ({Offset world, String? laneId})>{},
      after: <String, ({Offset world, String? laneId})>{},
      label: (kind: MoveNodesLabelKind.intoLane, laneName: ''),
    );
    expect(unnamed.label(_en), 'Move into lane “Untitled lane”');
    expect(unnamed.label(_zh), '移入泳道「未命名泳道」');

    const MoveNodesCommand nullName = MoveNodesCommand(
      before: <String, ({Offset world, String? laneId})>{},
      after: <String, ({Offset world, String? laneId})>{},
      label: (kind: MoveNodesLabelKind.outOfLane, laneName: null),
    );
    expect(nullName.label(_en), 'Move out of lane “Untitled lane”');

    const MoveNodesCommand moved = MoveNodesCommand(
      before: <String, ({Offset world, String? laneId})>{
        'a': (world: Offset.zero, laneId: null),
        'b': (world: Offset.zero, laneId: null),
      },
      after: <String, ({Offset world, String? laneId})>{
        'a': (world: Offset(1, 1), laneId: null),
        'b': (world: Offset(1, 1), laneId: null),
      },
      label: (kind: MoveNodesLabelKind.move, laneName: null),
    );
    expect(moved.label(_en), 'Move 2 nodes');
    expect(moved.label(_zh), '移动 2 个节点');
    expect(moved.affectedNodeIds, <String>{'a', 'b'});
  });
}
