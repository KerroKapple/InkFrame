// 标签栏「在序列中查看」（PR-6：原「序列预览」改名，「导入脚本」撤掉）。
//
// - 画布标签右侧只剩两个动作：在序列中查看（次级，带 sequence 图标）+ 导出视频；
// - 选中叙事链上的节点再点：切到序列标签，播放头跳到那一镜——走 selectShot（seekToken +1，
//   「用户 seek」语义）；
// - 没选中 / 选中的不在链上：只切标签，播放头不动；
// - 跳镜头的判据 shotIndexForSelection：产物归到来源那一镜，把产物借给前一镜的配置节点（折叠）
//   落在借走它的那一镜，多选取链序最靠前的。
//
// 外壳级的那几条从画布标签起步：序列标签此前从没物化过，播放头（autoDispose）没有订阅者——
// 正是「临时订阅撑过这一帧」要防的那种情形，裸 read 写进去的跳转会在下一帧被回收。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/sequence/models/sequence_lens.dart';
import 'package:inkframe/features/sequence/providers/sequence_playhead.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/shell_tab_bar.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/shell_app.dart';

const String _canvasId = 'cv-1';

/// 两镜一链 a → b（无产物的 shot 节点靠 shot_notes 成镜），外加一个不在链上的文本节点 t。
const List<CanvasNode> _nodes = <CanvasNode>[
  CanvasNode(
    id: 'a',
    label: 'shot-a',
    type: CanvasNodeType.shot,
    canvasId: _canvasId,
    typeConfig: <String, Object?>{'shot_notes': 'notes a'},
  ),
  CanvasNode(
    id: 'b',
    label: 'shot-b',
    type: CanvasNodeType.shot,
    canvasId: _canvasId,
    position: Offset(400, 0),
    typeConfig: <String, Object?>{'shot_notes': 'notes b'},
  ),
  CanvasNode(
    id: 't',
    label: 'loose',
    type: CanvasNodeType.text,
    canvasId: _canvasId,
    position: Offset(0, 400),
    typeConfig: <String, Object?>{'text': 'not on the chain'},
  ),
];

class _Edges extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => const <CanvasEdge>[
        CanvasEdge(
          id: 'e',
          canvasId: _canvasId,
          sourceNodeId: 'a',
          targetNodeId: 'b',
          edgeType: EdgeType.narrative,
        ),
      ];
}

Future<ProviderContainer> _pumpOnCanvas(WidgetTester tester) async {
  final paths = await setupTempPaths(tester, 'ink_view_in_sequence_');
  await pumpInkShell(
    tester,
    paths: paths,
    initial: const ShellState(
      tab: ShellTab.canvas,
      canvasId: _canvasId,
      project: ProjectRef(id: 'p1', name: 'Alpha'),
    ),
    extraOverrides: <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(_nodes)),
      canvasEdgesControllerProvider.overrideWith(_Edges.new),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ],
  );
  for (int i = 0; i < 4; i++) {
    await tester.pump();
  }
  return readShellContainer(tester);
}

Future<void> _tapViewInSequence(WidgetTester tester) async {
  await tester.tap(find.byKey(ShellTabBar.viewInSequenceKey));
  for (int i = 0; i < 3; i++) {
    await tester.pump();
  }
}

CanvasNode _shot(String id, {Map<String, Object?> config = const <String, Object?>{}}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      typeConfig: config,
    );

CanvasNode _imageConfig(String id) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      canvasId: 'c1',
      typeConfig: const <String, Object?>{'prompt': 'boat at dawn'},
    );

CanvasNode _imageResult(String id, {required String source, required DateTime at}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: source,
      createdAt: at,
      typeConfig: <String, Object?>{'image_url': 'images/$id.png'},
    );

CanvasEdge _narrative(String from, String to) => CanvasEdge(
      id: '$from-$to',
      canvasId: 'c1',
      sourceNodeId: from,
      targetNodeId: to,
      edgeType: EdgeType.narrative,
    );

void main() {
  group('外壳级', () {
    testWidgets('画布标签右侧只剩「在序列中查看」（带 sequence 图标）+「导出视频」，「导入脚本」撤了',
        (tester) async {
      await _pumpOnCanvas(tester);
      expect(find.byKey(const Key('shellAction-importScript')), findsNothing);
      expect(find.byKey(const Key('shellAction-sequencePreview')), findsNothing);
      expect(find.byKey(ShellTabBar.exportVideoKey), findsOneWidget);
      expect(find.byKey(ShellTabBar.viewInSequenceKey), findsOneWidget);
      final Finder icon = find.descendant(
        of: find.byKey(ShellTabBar.viewInSequenceKey),
        matching: find.byWidgetPredicate((Widget w) => w is InkIcon && w.glyph == InkGlyph.sequence),
      );
      expect(icon, findsOneWidget);
      expect(tester.widget<InkIcon>(icon).size, InkIconSize.s14);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('选中链上节点：切到序列标签，播放头跳到那一镜（selectShot，seekToken +1）', (tester) async {
      final ProviderContainer c = await _pumpOnCanvas(tester);
      c.read(canvasSelectionControllerProvider(_canvasId).notifier).select('b');
      await tester.pump();

      await _tapViewInSequence(tester);

      expect(c.read(shellControllerProvider).tab, ShellTab.sequence);
      expect(
        c.read(sequencePlayheadProvider(_canvasId)),
        const SequencePlayhead(index: 1, offsetMs: 0, seekToken: 1),
        reason: '序列标签第一次露面：跳转不能在它订阅播放头之前被回收',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('没选中：只切标签，播放头不动', (tester) async {
      final ProviderContainer c = await _pumpOnCanvas(tester);

      await _tapViewInSequence(tester);

      expect(c.read(shellControllerProvider).tab, ShellTab.sequence);
      expect(c.read(sequencePlayheadProvider(_canvasId)), const SequencePlayhead());
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('选中的不在链上：只切标签，播放头不动', (tester) async {
      final ProviderContainer c = await _pumpOnCanvas(tester);
      c.read(canvasSelectionControllerProvider(_canvasId).notifier).select('t');
      await tester.pump();

      await _tapViewInSequence(tester);

      expect(c.read(shellControllerProvider).tab, ShellTab.sequence);
      expect(c.read(sequencePlayheadProvider(_canvasId)), const SequencePlayhead());
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('shotIndexForSelection', () {
    // s1 ──narrative──> ic1 ──narrative──> s2：ic1 把它的最新产物 r1 借给了 s1（折叠，不单独成镜），
    // 所以序列只有两镜：0 = s1（放 r1），1 = s2（备注占位）。r0 是 ic1 更早的一张。
    final List<CanvasNode> nodes = <CanvasNode>[
      _shot('s1', config: const <String, Object?>{'shot_notes': 'harbor'}),
      _imageConfig('ic1'),
      _imageResult('r0', source: 'ic1', at: DateTime.utc(2026, 5, 1)),
      _imageResult('r1', source: 'ic1', at: DateTime.utc(2026, 5, 2)),
      _shot('s2', config: const <String, Object?>{'shot_notes': 'mountain'}),
      const CanvasNode(id: 'loose', label: 'loose', type: CanvasNodeType.text, canvasId: 'c1'),
    ];
    final SequenceLens lens = buildSequenceLens(
      nodes: nodes,
      edges: <CanvasEdge>[_narrative('s1', 'ic1'), _narrative('ic1', 's2')],
    );

    int indexOf(Set<String> selection) =>
        shotIndexForSelection(lens, selection: selection, nodes: nodes);

    test('前提：序列是两镜，第 0 镜放的是 r1', () {
      expect(lens.shots.map((s) => s.nodeId), <String>['s1', 's2']);
      expect(lens.shots.first.artifactNodeId, 'r1');
    });

    test('自己就是那一镜', () {
      expect(indexOf(<String>{'s1'}), 0);
      expect(indexOf(<String>{'s2'}), 1);
    });

    test('那一镜放的就是它（选中的是成片）', () {
      expect(indexOf(<String>{'r1'}), 0);
    });

    test('把产物借给前一镜的配置节点 → 借走它产物的那一镜；它名下更早的产物同样归过去', () {
      expect(indexOf(<String>{'ic1'}), 0);
      expect(indexOf(<String>{'r0'}), 0);
    });

    test('多选：取链序最靠前的那一镜', () {
      expect(indexOf(<String>{'s2', 'ic1'}), 0);
      expect(indexOf(<String>{'loose', 's2'}), 1);
    });

    test('没选中 / 都不在链上 ⇒ -1', () {
      expect(indexOf(const <String>{}), -1);
      expect(indexOf(<String>{'loose'}), -1);
      expect(indexOf(<String>{'missing'}), -1);
    });
  });
}
