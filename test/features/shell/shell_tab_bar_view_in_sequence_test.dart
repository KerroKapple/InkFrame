// 标签栏「在序列中查看」（PR-6：原「序列预览」改名，「导入脚本」撤掉）。
//
// - 画布标签右侧只剩两个动作：在序列中查看（次级，带 sequence 图标）+ 导出视频；
// - 选中叙事链上的节点再点：切到序列标签，播放头跳到那一镜——走 selectShot（seekToken +1，
//   「用户 seek」语义）；
// - 没选中 / 选中的不在链上：只切标签，播放头不动。
// 「切标签 + 跳播放头」本体 PR-8b 搬到了 sequence/util/view_in_sequence.dart（画布节点右键菜单「在序列中
// 定位」共用），跳镜头的判据 shotIndexForSelection 在同目录的 shot_index.dart，判据的用例在
// test/features/sequence/util/shot_index_test.dart；这里留外壳级的那几条。
//
// 外壳级的那几条从画布标签起步：序列标签此前从没物化过，播放头（autoDispose）没有订阅者——
// 正是「临时订阅撑过这一帧」要防的那种情形，裸 read 写进去的跳转会在下一帧被回收。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/export/providers/delivery_plan_provider.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
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
      // 序列标签右侧交付面板的底栏要显示输出目录（resolveInProject）；桩解析器不实现它——
      // 回落成默认相对路径即可，本文件不测交付。
      deliveryOutputDirPathProvider.overrideWith((ref, String projectId) => null),
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
}
