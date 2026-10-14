// 左栏大纲（PR-4）：点行 = 单选 + 移到视口中心；行尾五种状态；产物子行；筛选；画布切换胶囊。
//
// 定位与胶囊走外壳级 pump（视口尺寸、相机、外壳状态都要真的）；状态 / 子行 / 筛选只要面板本体，
// 直接 pump OutlinePanel。进行中的图标在转圈——那几条只用固定次数的 pump，不 pumpAndSettle。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/util/outline_model.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/canvas_switcher.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/outline_panel.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';

import '../../../../_harness/fake_canvas.dart';
import '../../../../_harness/shell_app.dart';
import '../../../../_harness/test_app.dart';

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');

/// 远离初始视口的文本配置节点（文本节点的检查器是空的，选中它不牵扯检查器的依赖）。
const CanvasNode _far = CanvasNode(
  id: 'far',
  label: 'Far shot',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(2600, 1700),
  typeConfig: <String, Object?>{'text': 'harbor at dawn'},
);

/// 视频配置 + 它名下的一个视频产物（视频 result 的检查器同样是空的）。
const CanvasNode _videoConfig = CanvasNode(
  id: 'vcfg',
  label: 'Video shot',
  type: CanvasNodeType.video,
  canvasId: 'c1',
  position: Offset(-900, -600),
  typeConfig: <String, Object?>{'prompt': 'boat drifting'},
);

final CanvasNode _videoResult = CanvasNode(
  id: 'vres',
  label: 'Video shot result',
  type: CanvasNodeType.video,
  role: NodeRole.result,
  canvasId: 'c1',
  sourceNodeId: 'vcfg',
  position: const Offset(3600, 900),
  createdAt: DateTime.utc(2026, 5, 1),
  typeConfig: const <String, Object?>{'video_url': 'videos/v.mp4'},
);

List<Override> _canvasOverrides(List<CanvasNode> nodes) => <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(nodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ];

Future<ProviderContainer> _pumpShell(
  WidgetTester tester,
  List<CanvasNode> nodes, {
  List<Override> extra = const <Override>[],
}) async {
  final paths = await setupTempPaths(tester, 'ink_left_outline_');
  await pumpInkShell(
    tester,
    paths: paths,
    initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: _alpha),
    extraOverrides: <Override>[..._canvasOverrides(nodes), ...extra],
  );
  // 节点载入 → 舞台布局 → LayoutBuilder 帧后上报视口尺寸：多给几帧。
  for (int i = 0; i < 5; i++) {
    await tester.pump();
  }
  return readShellContainer(tester);
}

Offset _cardCenter(WidgetTester tester, String nodeId) =>
    tester.getCenter(find.byKey(ValueKey<String>('node-card-$nodeId')));

Offset _stageCenter(WidgetTester tester) => tester.getCenter(find.byType(CanvasView));

/// 直接 pump 面板本体（241 宽，与左栏面板同宽）。
Future<ProviderContainer> _pumpPanel(WidgetTester tester, List<CanvasNode> nodes) async {
  await pumpInkApp(
    tester,
    const Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 241, height: 700, child: OutlinePanel(canvasId: 'c1')),
      ),
    ),
    overrides: _canvasOverrides(nodes),
    surfaceSize: const Size(400, 800),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(OutlinePanel)));
}

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(OutlinePanel)));

Finder _inRow(String nodeId, Finder matching) =>
    find.descendant(of: find.byKey(OutlinePanel.shotKey(nodeId)), matching: matching);

Finder _glyph(InkGlyph glyph) =>
    find.byWidgetPredicate((Widget w) => w is InkIcon && w.glyph == glyph);

CanvasNode _image(String id, {String prompt = ''}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      canvasId: 'c1',
      typeConfig: <String, Object?>{'prompt': prompt},
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

void main() {
  group('点行 = 单选 + 移到视口中心（外壳级）', () {
    testWidgets('点镜头行：只选中它一个，卡片中心落在舞台视口中心', (tester) async {
      final ProviderContainer c = await _pumpShell(tester, <CanvasNode>[_far, _videoConfig, _videoResult]);
      c.read(canvasSelectionControllerProvider('c1').notifier).select('vres');
      final double before = (_cardCenter(tester, 'far') - _stageCenter(tester)).distance;
      expect(before, greaterThan(200), reason: '前置：卡片一开始远离视口中心');

      await tester.tap(find.byKey(OutlinePanel.shotKey('far')));
      await tester.pump();
      await tester.pump();

      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'far'}, reason: '单选：原来选中的被替换');
      final Offset card = _cardCenter(tester, 'far');
      final Offset stage = _stageCenter(tester);
      expect(card.dx, closeTo(stage.dx, 1));
      expect(card.dy, closeTo(stage.dy, 1));
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('点产物子行：选中那个产物节点并把它移到视口中心', (tester) async {
      final ProviderContainer c = await _pumpShell(tester, <CanvasNode>[_far, _videoConfig, _videoResult]);

      await tester.tap(find.byKey(OutlinePanel.artifactKey('vcfg')));
      await tester.pump();
      await tester.pump();

      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'vres'});
      final Offset card = _cardCenter(tester, 'vres');
      final Offset stage = _stageCenter(tester);
      expect(card.dx, closeTo(stage.dx, 1));
      expect(card.dy, closeTo(stage.dy, 1));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  testWidgets('画布切换胶囊：列出本项目的画布，点另一张 = 在同一项目里换画布', (tester) async {
    final ProviderContainer c = await _pumpShell(
      tester,
      <CanvasNode>[_far],
      extra: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              createdAt: DateTime.utc(2026),
              canvases: const <CanvasRef>[
                CanvasRef(id: 'c1', name: 'Canvas One'),
                CanvasRef(id: 'c2', name: 'Canvas Two'),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.tap(find.byKey(CanvasSwitcher.pillKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(CanvasSwitcher.itemKey('c1')), findsOneWidget);
    expect(find.byKey(CanvasSwitcher.itemKey('c2')), findsOneWidget);

    await tester.tap(find.byKey(CanvasSwitcher.itemKey('c2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final ShellState s = c.read(shellControllerProvider);
    expect(s.canvasId, 'c2');
    expect(s.project, _alpha, reason: '同项目内换画布，项目上下文原样留着');
  }, timeout: const Timeout(Duration(seconds: 30)));

  group('面板本体', () {
    testWidgets('行尾五种状态：运行中（带百分比）/ 排队中 / 有产物 / 就绪 / 草稿', (tester) async {
      final ProviderContainer c = await _pumpPanel(tester, <CanvasNode>[
        _image('run', prompt: 'a'),
        _image('queue', prompt: 'b'),
        _image('done', prompt: 'c'),
        _imageResult('doneR', source: 'done', at: DateTime.utc(2026, 1, 1)),
        _image('ready', prompt: 'd'),
        _image('draft'),
      ]);
      final JobsRegistry jobs = c.read(jobsRegistryProvider.notifier);
      jobs.upsert(const JobState.running(
        jobId: 'j1',
        providerId: 'p',
        canvasId: 'c1',
        sourceNodeId: 'run',
        progress: 0.62,
      ));
      jobs.upsert(const JobState.queued(
        jobId: 'j2',
        providerId: 'p',
        canvasId: 'c1',
        sourceNodeId: 'queue',
      ));
      await tester.pump();
      await tester.pump();
      final AppLocalizations l = _l(tester);

      expect(_inRow('run', find.text('62%')), findsOneWidget);
      expect(_inRow('run', _glyph(InkGlyph.progress)), findsOneWidget);
      expect(_inRow('queue', find.text(l.canvasRenderQueueStatusQueued)), findsOneWidget);
      expect(_inRow('done', _glyph(InkGlyph.success)), findsOneWidget);
      expect(_inRow('ready', find.text(l.leftRailStatusReady)), findsOneWidget);
      expect(_inRow('draft', find.text(l.leftRailStatusDraft)), findsOneWidget);

      // 交叉排除：每行只有自己那一种。
      expect(_inRow('done', find.text(l.leftRailStatusReady)), findsNothing, reason: '有产物压过就绪');
      expect(_inRow('ready', _glyph(InkGlyph.success)), findsNothing);
      expect(_inRow('draft', find.text(l.leftRailStatusReady)), findsNothing);

      // 有活动 job 的两镜各多一行「生成中…」；其余没有。
      expect(find.byKey(OutlinePanel.generatingKey('run')), findsOneWidget);
      expect(find.byKey(OutlinePanel.generatingKey('queue')), findsOneWidget);
      expect(find.byKey(OutlinePanel.generatingKey('ready')), findsNothing);
    });

    testWidgets('产物子行：只画最新一个；名下多于一个时写「共 N 个」；没有产物不画', (tester) async {
      await _pumpPanel(tester, <CanvasNode>[
        _image('one', prompt: 'x'),
        _imageResult('oneR', source: 'one', at: DateTime.utc(2026, 1, 1)),
        _image('many', prompt: 'y'),
        _imageResult('m1', source: 'many', at: DateTime.utc(2026, 1, 1)),
        _imageResult('m2', source: 'many', at: DateTime.utc(2026, 1, 3)),
        _imageResult('m3', source: 'many', at: DateTime.utc(2026, 1, 2)),
        _image('none', prompt: 'z'),
      ]);
      final AppLocalizations l = _l(tester);

      expect(
        find.descendant(of: find.byKey(OutlinePanel.artifactKey('one')), matching: find.text(l.leftRailArtifactImage)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(OutlinePanel.artifactKey('many')),
          matching: find.text(l.leftRailArtifactCount(l.leftRailArtifactImage, 3)),
        ),
        findsOneWidget,
      );
      expect(find.byKey(OutlinePanel.artifactKey('none')), findsNothing);
    });

    testWidgets('筛选：按名称或提示词、不区分大小写；不命中的整组消失', (tester) async {
      await _pumpPanel(tester, <CanvasNode>[
        _image('Harbor', prompt: 'misty river'),
        _image('Boat', prompt: 'A lone FISHERMAN'),
        _image('Peaks', prompt: 'far mountains'),
      ]);
      Future<void> filter(String q) async {
        await tester.enterText(
          find.descendant(of: find.byKey(OutlinePanel.filterKey), matching: find.byType(TextField)),
          q,
        );
        await tester.pump();
      }

      await filter('HARB');
      expect(find.byKey(OutlinePanel.shotKey('Harbor')), findsOneWidget);
      expect(find.byKey(OutlinePanel.shotKey('Boat')), findsNothing);

      await filter('fisherman');
      expect(find.byKey(OutlinePanel.shotKey('Boat')), findsOneWidget, reason: '提示词命中');
      expect(find.byKey(OutlinePanel.shotKey('Harbor')), findsNothing);

      await filter('zzz');
      expect(find.byKey(OutlinePanel.groupKey(OutlineGroupKind.unchained)), findsNothing,
          reason: '一个都不匹配，组头也不画');
      expect(find.text(_l(tester).leftRailOutlineEmpty), findsNothing, reason: '只是没命中，不是空画布');
    });

    testWidgets('画布上没有配置节点 → 居中一行空态说明', (tester) async {
      await _pumpPanel(tester, const <CanvasNode>[]);
      expect(find.text(_l(tester).leftRailOutlineEmpty), findsOneWidget);
    });
  });
}
