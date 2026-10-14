// 任务胶囊 / 任务弹层的外壳级行为（PR-6）：
// - 胶囊挂在外壳状态栏上，所有标签下都在（job 是全局的）；
// - 弹层左沿对齐胶囊、底边离状态栏上沿 8；
// - 「定位」同一画布 = 单选源节点 + 移到视口中心；别的画布 = 先切过去（同项目带 ProjectRef）。
//   跨画布之后的「再选中」已知会丢（目标画布的选中 provider 是 autoDispose，切过去那一帧没人订阅，
//   画廊 / ⌘K 同病，另行修），这里只断言切过去了。
//
// 注册表一律用 override 播种：外壳里的 JobNotificationListener 只认「这一次变成终态」的 job，
// 播种进来的初始态不弹通知卡（upsert 进来的终态会弹，卡片还带计时器）。
// 全外壳测试禁 pumpAndSettle（见 test/_harness/shell_app.dart），胶囊转圈时更不能。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/shell_status_bar.dart';
import 'package:inkframe/features/shell/widgets/shell_task_capsule.dart';
import 'package:inkframe/features/shell/widgets/shell_task_popover.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/shell_app.dart';

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');

class _SeededRegistry extends JobsRegistry {
  _SeededRegistry(this._seed);
  final List<JobState> _seed;

  @override
  List<JobState> build() => List<JobState>.unmodifiable(_seed);
}

/// 按画布分开的节点表（切到别的画布时，那张画布只该有它自己的节点）。
class _NodesByCanvas extends CanvasNodesController {
  _NodesByCanvas(this._all);
  final List<CanvasNode> _all;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        for (final CanvasNode n in _all)
          if (n.canvasId == canvasId) n,
      ];
}

/// 远离初始视口的文本节点（文本节点的检查器是空的，选中它不牵扯检查器的依赖）。
const CanvasNode _far = CanvasNode(
  id: 'far',
  label: 'Far shot',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(2600, 1700),
  typeConfig: <String, Object?>{'text': 'harbor at dawn'},
);

/// 同项目另一张画布上的节点。
const CanvasNode _elsewhere = CanvasNode(
  id: 'n2',
  label: 'Elsewhere',
  type: CanvasNodeType.text,
  canvasId: 'c2',
  typeConfig: <String, Object?>{'text': 'second canvas'},
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required ShellState initial,
  required List<JobState> jobs,
  List<CanvasNode> nodes = const <CanvasNode>[],
}) async {
  final paths = await setupTempPaths(tester, 'ink_shell_tasks_');
  await pumpInkShell(
    tester,
    paths: paths,
    initial: initial,
    extraOverrides: <Override>[
      jobsRegistryProvider.overrideWith(() => _SeededRegistry(jobs)),
      canvasNodesControllerProvider.overrideWith(() => _NodesByCanvas(nodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ],
  );
  // 节点载入 → 舞台布局 → LayoutBuilder 帧后上报视口尺寸：多给几帧。
  for (int i = 0; i < 5; i++) {
    await tester.pump();
  }
  return readShellContainer(tester);
}

Future<void> _openTasks(WidgetTester tester) async {
  await tester.tap(find.byKey(ShellTaskCapsule.capsuleKey));
  await tester.pump();
  await tester.pump();
}

Offset _cardCenter(WidgetTester tester, String nodeId) =>
    tester.getCenter(find.byKey(ValueKey<String>('node-card-$nodeId')));

void main() {
  testWidgets('胶囊在状态栏里，五个标签下都在', (tester) async {
    await _pump(
      tester,
      initial: const ShellState(),
      jobs: const <JobState>[
        JobState.running(jobId: 'r', providerId: 'p', canvasId: 'c9', progress: 0.2),
      ],
    );
    for (final ShellTab tab in ShellTab.values) {
      await tapShellTab(tester, tab);
      expect(
        find.descendant(
          of: find.byType(ShellStatusBar),
          matching: find.byKey(ShellTaskCapsule.capsuleKey),
        ),
        findsOneWidget,
        reason: '${tab.name} 标签下的状态栏里没有任务胶囊',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('弹层左沿对齐胶囊，底边离状态栏上沿 8', (tester) async {
    await _pump(
      tester,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: _alpha),
      jobs: const <JobState>[
        JobState.succeeded(jobId: 'j1', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
      ],
    );
    await _openTasks(tester);

    final Rect panel = tester.getRect(find.byKey(ShellTaskPopover.panelKey));
    final Rect capsule = tester.getRect(find.byKey(ShellTaskCapsule.capsuleKey));
    final Rect statusBar = tester.getRect(find.byType(ShellStatusBar));
    expect(panel.left, closeTo(capsule.left, 0.5));
    expect(panel.bottom, closeTo(statusBar.top - InkSpacing.sm, 0.5));
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('「定位」同一画布：单选源节点，并把它移到视口中心', (tester) async {
    final ProviderContainer c = await _pump(
      tester,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: _alpha),
      jobs: const <JobState>[
        JobState.succeeded(
          jobId: 'j1',
          providerId: 'p',
          canvasId: 'c1',
          projectId: 'p1',
          sourceNodeId: 'far',
          artifactPath: 'images/x.png',
        ),
      ],
      nodes: const <CanvasNode>[_far],
    );
    final Offset stage = tester.getCenter(find.byType(CanvasView));
    expect((_cardCenter(tester, 'far') - stage).distance, greaterThan(200), reason: '前置：卡片一开始远离视口中心');

    await _openTasks(tester);
    await tester.tap(find.byKey(ShellTaskPopover.locateKey('j1')));
    await tester.pump();
    await tester.pump();

    expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'far'});
    final Offset card = _cardCenter(tester, 'far');
    expect(card.dx, closeTo(stage.dx, 1));
    expect(card.dy, closeTo(stage.dy, 1));
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('「定位」同一画布但人在别的标签：先切回画布标签', (tester) async {
    final ProviderContainer c = await _pump(
      tester,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: _alpha),
      jobs: const <JobState>[
        JobState.succeeded(
          jobId: 'j1',
          providerId: 'p',
          canvasId: 'c1',
          projectId: 'p1',
          sourceNodeId: 'far',
          artifactPath: 'images/x.png',
        ),
      ],
      nodes: const <CanvasNode>[_far],
    );
    await tapShellTab(tester, ShellTab.export);
    expect(c.read(shellControllerProvider).tab, ShellTab.export);

    await _openTasks(tester);
    await tester.tap(find.byKey(ShellTaskPopover.locateKey('j1')));
    await tester.pump();
    await tester.pump();

    expect(c.read(shellControllerProvider).tab, ShellTab.canvas);
    expect(c.read(shellControllerProvider).canvasId, 'c1');
    expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'far'});
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('「定位」别的画布：切到那张画布（项目上下文原样带着），挂上来后单选源节点并移到视口中心', (tester) async {
    final ProviderContainer c = await _pump(
      tester,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: _alpha),
      jobs: const <JobState>[
        JobState.succeeded(
          jobId: 'j2',
          providerId: 'p',
          canvasId: 'c2',
          projectId: 'p1',
          sourceNodeId: 'n2',
          artifactPath: 'images/y.png',
        ),
      ],
      nodes: const <CanvasNode>[_far, _elsewhere],
    );
    await _openTasks(tester);
    await tester.pump();
    expect(find.byKey(ShellTaskPopover.locateKey('j2')), findsOneWidget);

    await tester.tap(find.byKey(ShellTaskPopover.locateKey('j2')));
    for (int i = 0; i < 3; i++) {
      await tester.pump();
    }

    final ShellState s = c.read(shellControllerProvider);
    expect(s.tab, ShellTab.canvas);
    expect(s.canvasId, 'c2');
    expect(s.project, _alpha);

    // 目标画布是切过去才挂上来的：定位走挂起请求，等节点载入、视口上报后落地。
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(c.read(canvasSelectionControllerProvider('c2')), <String>{'n2'},
        reason: '切过去以后源节点要被选中（同一刻直接写会被 autoDispose 回收）');
    final Offset card = tester.getCenter(find.byKey(const ValueKey<String>('node-card-n2')));
    final Offset stage = tester.getCenter(find.byType(CanvasView));
    expect(card.dx, closeTo(stage.dx, 1));
    expect(card.dy, closeTo(stage.dy, 1));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
