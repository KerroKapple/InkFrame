// 检查器「历史」页（PR-6）：选中节点的 take 列表。
//
// 面板本体：配置节点列名下全部 take（新 → 旧，「take N」按时间正序编号）、产物节点列同源兄弟并高亮
// 自己、「在用」（有 data 出边：首帧 / 尾帧 / 参考）、meta = 相对时间 · 种子、空态。
// 外壳级：点一行 = 单选那个产物 + 移到视口中心，页签留在历史页、那一行变成高亮。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/clock.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_tab.dart';
import 'package:inkframe/features/canvas/widgets/canvas_inspector_panel.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/inspector_history_panel.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/theme/primitives/ink_activatable.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_clock.dart';
import '../../../_harness/shell_app.dart';
import '../../../_harness/test_app.dart';

class _Edges extends CanvasEdgesController {
  _Edges(this._edges);
  final List<CanvasEdge> _edges;

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => _edges;
}

/// 「现在」= 5 月 2 日 12:00（UTC），下面三张 take 分别是 1 天前 / 2 小时前 / 1 小时前。
final DateTime _now = DateTime.utc(2026, 5, 2, 12);

const CanvasNode _config = CanvasNode(
  id: 'cfg',
  label: 'Harbor dawn',
  type: CanvasNodeType.image,
  canvasId: 'c1',
  typeConfig: <String, Object?>{'prompt': 'harbor at dawn'},
);

CanvasNode _take(String id, {required DateTime at, int? seed, String source = 'cfg'}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: source,
      createdAt: at,
      typeConfig: <String, Object?>{'image_url': 'images/$id.png', 'seed': ?seed},
    );

final CanvasNode _r1 = _take('r1', at: DateTime.utc(2026, 5, 1, 12), seed: 902);
final CanvasNode _r2 = _take('r2', at: DateTime.utc(2026, 5, 2, 10), seed: 4127);
final CanvasNode _r3 = _take('r3', at: DateTime.utc(2026, 5, 2, 11));

/// 别人名下的产物：不该出现在 cfg 的历史里。
final CanvasNode _other = _take('o1', at: DateTime.utc(2026, 5, 2, 9), source: 'otherCfg');

/// 名下什么都没有的配置节点。
const CanvasNode _blank = CanvasNode(id: 'blank', label: 'Blank', type: CanvasNodeType.image, canvasId: 'c1');

/// r2 当了下游视频的首帧 ⇒ 在用。
const List<CanvasEdge> _edges = <CanvasEdge>[
  CanvasEdge(
    id: 'e1',
    canvasId: 'c1',
    sourceNodeId: 'r2',
    targetNodeId: 'video',
    edgeType: EdgeType.data,
    role: EdgeRole.firstFrame,
  ),
];

List<CanvasNode> get _all => <CanvasNode>[_config, _r1, _r2, _r3, _other, _blank];

Future<void> _pumpPanel(WidgetTester tester, CanvasNode selected) async {
  await pumpInkApp(
    tester,
    Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: CanvasInspectorPanel.width,
          height: 600,
          child: InspectorHistoryPanel(canvasId: 'c1', node: selected),
        ),
      ),
    ),
    overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(_all)),
      canvasEdgesControllerProvider.overrideWith(() => _Edges(_edges)),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      clockProvider.overrideWithValue(FakeClock(_now)),
    ],
    surfaceSize: const Size(400, 700),
  );
  await tester.pump();
  await tester.pump();
}

AppLocalizations _l(WidgetTester tester) => tester.element(find.byType(InspectorHistoryPanel)).l10n;

Finder _row(String id) => find.byKey(InspectorHistoryPanel.takeKey(id));

Finder _inRow(String id, Finder matching) => find.descendant(of: _row(id), matching: matching);

bool _isCurrent(WidgetTester tester, String id) => tester.widget<InkActivatable>(_row(id)).selected ?? false;

/// 缩略图那个盒（行里唯一带前景描边的 Container）的描边色。
Color _thumbBorder(WidgetTester tester, String id) {
  final Container thumb = tester.widget<Container>(
    _inRow(id, find.byWidgetPredicate((Widget w) => w is Container && w.foregroundDecoration != null)),
  );
  return ((thumb.foregroundDecoration! as BoxDecoration).border! as Border).top.color;
}

void main() {
  group('面板本体', () {
    testWidgets('选中配置节点：列名下全部 take，新的在上；编号按时间正序（最早的是 take 1）', (tester) async {
      await _pumpPanel(tester, _config);
      final AppLocalizations l = _l(tester);

      expect(find.text(l.inspectorHistoryHeading('Harbor dawn')), findsOneWidget);
      expect(_row('o1'), findsNothing, reason: '别的节点名下的产物不列');

      final double y3 = tester.getTopLeft(_row('r3')).dy;
      final double y2 = tester.getTopLeft(_row('r2')).dy;
      final double y1 = tester.getTopLeft(_row('r1')).dy;
      expect(y3, lessThan(y2));
      expect(y2, lessThan(y1));

      expect(_inRow('r1', find.text(l.inspectorHistoryTake(1))), findsOneWidget);
      expect(_inRow('r2', find.text(l.inspectorHistoryTake(2))), findsOneWidget);
      expect(_inRow('r3', find.text(l.inspectorHistoryTake(3))), findsOneWidget);

      for (final String id in <String>['r1', 'r2', 'r3']) {
        expect(_isCurrent(tester, id), isFalse, reason: '选中的是配置节点，没有哪一张是「当前」');
      }
    });

    testWidgets('选中产物节点：列它的兄弟（同一来源），自己高亮（surface5 底）；说明行写来源的名字', (tester) async {
      await _pumpPanel(tester, _r2);
      final AppLocalizations l = _l(tester);

      expect(find.text(l.inspectorHistoryHeading('Harbor dawn')), findsOneWidget);
      expect(_row('r1'), findsOneWidget);
      expect(_row('r3'), findsOneWidget);
      expect(_row('o1'), findsNothing);

      expect(_isCurrent(tester, 'r2'), isTrue);
      expect(_isCurrent(tester, 'r1'), isFalse);
      expect(_isCurrent(tester, 'r3'), isFalse);
      final Container current = tester.widget<Container>(_inRow('r2', find.byType(Container)).first);
      expect(current.color, InkColors.dark().surface5);
      final Container other = tester.widget<Container>(_inRow('r1', find.byType(Container)).first);
      expect(other.color, isNull);
    });

    testWidgets('「在用」：有 data 出边的 take 描边换 accent、右侧写「在用」；其余 outline', (tester) async {
      await _pumpPanel(tester, _config);
      final AppLocalizations l = _l(tester);

      expect(_inRow('r2', find.text(l.inspectorHistoryInUse)), findsOneWidget);
      expect(_inRow('r1', find.text(l.inspectorHistoryInUse)), findsNothing);
      expect(_inRow('r3', find.text(l.inspectorHistoryInUse)), findsNothing);
      expect(_thumbBorder(tester, 'r2'), InkColors.dark().accent);
      expect(_thumbBorder(tester, 'r1'), InkColors.dark().outline);
    });

    testWidgets('meta：相对时间 · 种子（type_config 里有 seed 才写）', (tester) async {
      await _pumpPanel(tester, _config);
      final AppLocalizations l = _l(tester);

      expect(
        _inRow('r2', find.text('${l.galleryTimeHoursAgo(2)} · ${l.inspectorHistorySeed(4127)}')),
        findsOneWidget,
      );
      expect(_inRow('r1', find.text('${l.galleryTimeDaysAgo(1)} · ${l.inspectorHistorySeed(902)}')), findsOneWidget);
      expect(_inRow('r3', find.text(l.galleryTimeHoursAgo(1))), findsOneWidget, reason: '没有 seed 就只写时间');
    });

    testWidgets('名下没有产物：一行「还没有生成过」，没有 take 行', (tester) async {
      await _pumpPanel(tester, _blank);
      final AppLocalizations l = _l(tester);
      expect(find.text(l.inspectorHistoryEmpty), findsOneWidget);
      expect(find.byType(InkActivatable), findsNothing);
    });
  });

  group('外壳级', () {
    const ProjectRef alpha = ProjectRef(id: 'p1', name: 'Alpha');

    /// 视频配置 + 名下两张视频产物（视频产物的检查器是空的；历史页本身也不牵扯检查器）。
    const CanvasNode videoConfig = CanvasNode(
      id: 'vcfg',
      label: 'Video shot',
      type: CanvasNodeType.video,
      canvasId: 'c1',
      position: Offset(-900, -600),
      typeConfig: <String, Object?>{'prompt': 'boat drifting'},
    );
    final CanvasNode v1 = CanvasNode(
      id: 'v1',
      label: 'Video take 1',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: 'vcfg',
      position: const Offset(3600, 900),
      createdAt: DateTime.utc(2026, 5, 1),
      typeConfig: const <String, Object?>{'video_url': 'videos/v1.mp4'},
    );
    final CanvasNode v2 = CanvasNode(
      id: 'v2',
      label: 'Video take 2',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: 'vcfg',
      position: const Offset(-2600, 1700),
      createdAt: DateTime.utc(2026, 5, 2),
      typeConfig: const <String, Object?>{'video_url': 'videos/v2.mp4'},
    );

    testWidgets('点一行：单选那个产物并把它移到视口中心；页签留在历史页，那一行变成当前', (tester) async {
      final paths = await setupTempPaths(tester, 'ink_inspector_history_');
      await pumpInkShell(
        tester,
        paths: paths,
        initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: alpha),
        extraOverrides: <Override>[
          canvasNodesControllerProvider.overrideWith(() => FakeNodesController(<CanvasNode>[videoConfig, v1, v2])),
          canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
          canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
          fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
        ],
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }
      final ProviderContainer c = readShellContainer(tester);

      // 先切到历史页再选中：选中配置节点时属性页的视频检查器不在本用例的范围里。
      await tester.tap(find.byKey(CanvasInspectorPanel.tabKey(InspectorTab.history)));
      await tester.pump();
      c.read(canvasSelectionControllerProvider('c1').notifier).select('vcfg');
      await tester.pump();
      await tester.pump();
      expect(_row('v1'), findsOneWidget);
      expect(_row('v2'), findsOneWidget);

      final Offset stage = tester.getCenter(find.byType(CanvasView));
      Offset card(String id) => tester.getCenter(find.byKey(ValueKey<String>('node-card-$id')));
      expect((card('v1') - stage).distance, greaterThan(200), reason: '前置：卡片一开始远离视口中心');

      await tester.tap(_row('v1'));
      await tester.pump();
      await tester.pump();

      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'v1'});
      expect(card('v1').dx, closeTo(stage.dx, 1));
      expect(card('v1').dy, closeTo(stage.dy, 1));
      expect(c.read(inspectorTabProvider), InspectorTab.history, reason: '换选中不重置页签');
      expect(_isCurrent(tester, 'v1'), isTrue);
      expect(_isCurrent(tester, 'v2'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
