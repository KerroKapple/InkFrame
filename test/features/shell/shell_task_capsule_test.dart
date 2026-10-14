// 状态栏任务胶囊 + 任务弹层（PR-6：取代画布底栏的渲染队列，原 canvas_render_queue_test 的行为都搬到这里）。
//
// 胶囊三态：有活动 job（「生成中 N · 排队 M」，0 的那段省掉，提交中算排队）/ 只剩终态（「任务 N」，
// 有失败加「· 失败 K」danger）/ 注册表空（不画，连同左侧间距）。
// 弹层：点胶囊开、再点或 Esc 关；行序活动在前终态在后；任务名 = 源节点名（回退 provider 显示名，
// 不暴露 jobId，范围是全部 job、源节点按 job 所在画布找）；meta = provider · 状态；失败行 tooltip 是
// 本地化错误；运行中的行有进度条；「取消」委托 JobQueueService.cancel；「定位」只在终态 + 源节点在 +
// 拿得到项目时出；「清除已完成」清终态留活动；「并发 N」。
//
// 进行中的胶囊图标在转圈：只用固定次数的 pump，不 pumpAndSettle。
// 「定位」点下去之后的单选 + 居中 / 切画布要真画布，在 shell_task_capsule_shell_test.dart。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/shell_task_capsule.dart';
import 'package:inkframe/features/shell/widgets/shell_task_popover.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/services/job_queue_service.dart' show kDefaultGlobalConcurrency;
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/primitives/ink_activatable.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/test_app.dart';

class _SeededRegistry extends JobsRegistry {
  _SeededRegistry(this._seed);
  final List<JobState> _seed;

  @override
  List<JobState> build() => List<JobState>.unmodifiable(_seed);
}

/// 按画布分开的节点表：弹层要去 job 所在的那张画布里找源节点。
class _NodesByCanvas extends CanvasNodesController {
  _NodesByCanvas(this._all);
  final List<CanvasNode> _all;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        for (final CanvasNode n in _all)
          if (n.canvasId == canvasId) n,
      ];
}

/// 只捕获 cancel(jobId) 调用的假 JobQueueService。
class _CapturingQueue implements JobQueueService {
  String? cancelledJobId;

  @override
  Future<void> init() async {}

  @override
  Future<JobHandle> submit(GenerationTask task) async => throw UnimplementedError();

  @override
  Future<void> cancel(String jobId) async => cancelledJobId = jobId;

  @override
  void dispose() {}
}

const NetworkError _timeout = NetworkError(code: InkErrorCode.networkTimeout);

/// 胶囊左侧间距：注册表空时连它一起不占位（下面那条用例要量）。
const double _gap = 16;

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<JobState> jobs, {
  List<CanvasNode> nodes = const <CanvasNode>[],
  List<Override> extra = const <Override>[],
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(
      body: Column(
        children: <Widget>[
          Spacer(),
          // 胶囊在最底下一条里（与状态栏同高），弹层往上开。
          SizedBox(
            height: 23,
            child: Row(children: <Widget>[ShellTaskCapsule(leadingGap: _gap)]),
          ),
        ],
      ),
    ),
    overrides: <Override>[
      jobsRegistryProvider.overrideWith(() => _SeededRegistry(jobs)),
      canvasNodesControllerProvider.overrideWith(() => _NodesByCanvas(nodes)),
      ...extra,
    ],
    surfaceSize: const Size(900, 800),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(ShellTaskCapsule)));
}

AppLocalizations _l(WidgetTester tester) => tester.element(find.byType(ShellTaskCapsule)).l10n;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(ShellTaskCapsule.capsuleKey));
  await tester.pump();
  await tester.pump();
}

BoxDecoration _capsuleDecoration(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(ShellTaskCapsule.bodyKey)).decoration! as BoxDecoration;

Finder _progressGlyph() => find.descendant(
      of: find.byKey(ShellTaskCapsule.capsuleKey),
      matching: find.byWidgetPredicate((Widget w) => w is InkIcon && w.glyph == InkGlyph.progress),
    );

Finder _inRow(String jobId, Finder matching) =>
    find.descendant(of: find.byKey(ShellTaskPopover.rowKey(jobId)), matching: matching);

void main() {
  test('摘要：生成中只数 running；排队含提交中；终态里单数失败', () {
    final TaskCapsuleSummary s = taskCapsuleSummaryOf(const <JobState>[
      JobState.running(jobId: 'r', providerId: 'p', canvasId: 'c1', progress: 0.3),
      JobState.queued(jobId: 'q', providerId: 'p', canvasId: 'c1'),
      JobState.submitting(jobId: 's', providerId: 'p', canvasId: 'c2'),
      JobState.succeeded(jobId: 'ok', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
      JobState.failed(jobId: 'f', providerId: 'p', canvasId: 'c2', error: _timeout),
      JobState.cancelled(jobId: 'x', providerId: 'p', canvasId: 'c1'),
    ]);
    expect(s, (running: 1, queued: 2, terminal: 3, failed: 1));
  });

  test('行序：活动的在前、终态在后，各自保持插入序', () {
    final List<JobState> ordered = orderTasks(const <JobState>[
      JobState.succeeded(jobId: 'd1', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
      JobState.running(jobId: 'a1', providerId: 'p', canvasId: 'c1'),
      JobState.cancelled(jobId: 'd2', providerId: 'p', canvasId: 'c1'),
      JobState.queued(jobId: 'a2', providerId: 'p', canvasId: 'c2'),
    ]);
    expect(ordered.map((JobState j) => j.jobId), <String>['a1', 'a2', 'd1', 'd2']);
  });

  group('胶囊三态', () {
    testWidgets('注册表空：不画胶囊，连左侧间距也不占', (tester) async {
      await _pump(tester, const <JobState>[]);
      expect(find.byKey(ShellTaskCapsule.capsuleKey), findsNothing);
      expect(tester.getSize(find.byType(ShellTaskCapsule)).width, 0);
    });

    testWidgets('有活动 job：wash 底 + washBorder 边 + 转圈图标，「生成中 N · 排队 M」（提交中算排队）',
        (tester) async {
      await _pump(tester, const <JobState>[
        JobState.running(jobId: 'r', providerId: 'p', canvasId: 'c1', progress: 0.3),
        JobState.queued(jobId: 'q', providerId: 'p', canvasId: 'c1'),
        JobState.submitting(jobId: 's', providerId: 'p', canvasId: 'c2'),
        JobState.succeeded(jobId: 'ok', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
      ]);
      final AppLocalizations l = _l(tester);
      expect(find.text('${l.taskCapsuleRunning(1)} · ${l.taskCapsuleQueued(2)}'), findsOneWidget);
      expect(_progressGlyph(), findsOneWidget);
      final BoxDecoration d = _capsuleDecoration(tester);
      expect(d.color, InkColors.dark().accentWash);
      expect((d.border! as Border).top.color, InkColors.dark().accentWashBorder);
      expect(tester.getSize(find.byKey(ShellTaskCapsule.capsuleKey)).height, ShellTaskCapsule.height);
      expect(
        tester.getTopLeft(find.byKey(ShellTaskCapsule.capsuleKey)).dx,
        closeTo(_gap, 0.5),
        reason: '画出来时才占左侧间距',
      );
    });

    testWidgets('为 0 的那段省掉：只有生成中 / 只有排队', (tester) async {
      final ProviderContainer c = await _pump(tester, const <JobState>[
        JobState.running(jobId: 'r', providerId: 'p', canvasId: 'c1'),
      ]);
      final AppLocalizations l = _l(tester);
      expect(find.text(l.taskCapsuleRunning(1)), findsOneWidget);

      c.read(jobsRegistryProvider.notifier)
        ..remove('r')
        ..upsert(const JobState.queued(jobId: 'q', providerId: 'p', canvasId: 'c1'));
      await tester.pump();
      expect(find.text(l.taskCapsuleQueued(1)), findsOneWidget);
    });

    testWidgets('只剩终态：outline 边、没有转圈，「任务 N」；有失败加「· 失败 K」且整段 danger',
        (tester) async {
      await _pump(tester, const <JobState>[
        JobState.succeeded(jobId: 'ok', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
        JobState.failed(jobId: 'f', providerId: 'p', canvasId: 'c1', error: _timeout),
        JobState.cancelled(jobId: 'x', providerId: 'p', canvasId: 'c1'),
      ]);
      final AppLocalizations l = _l(tester);
      expect(
        find.text('${l.taskCapsuleTotal(3)} · ${l.taskCapsuleFailed(1)}', findRichText: true),
        findsOneWidget,
      );
      expect(_progressGlyph(), findsNothing);
      final BoxDecoration d = _capsuleDecoration(tester);
      expect(d.color, isNull);
      expect((d.border! as Border).top.color, InkColors.dark().outline);

      final RichText rich = tester.widget<RichText>(
        find.descendant(of: find.byKey(ShellTaskCapsule.bodyKey), matching: find.byType(RichText)),
      );
      String? danger;
      rich.text.visitChildren((InlineSpan span) {
        if (span is TextSpan && span.style?.color == InkColors.dark().danger) danger = span.toPlainText();
        return true;
      });
      expect(danger, ' · ${l.taskCapsuleFailed(1)}');
    });

    testWidgets('只剩终态且没有失败：只写「任务 N」', (tester) async {
      await _pump(tester, const <JobState>[
        JobState.succeeded(jobId: 'ok', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
        JobState.cancelled(jobId: 'x', providerId: 'p', canvasId: 'c1'),
      ]);
      final AppLocalizations l = _l(tester);
      expect(find.text(l.taskCapsuleTotal(2), findRichText: true), findsOneWidget);
      expect(find.textContaining(l.taskCapsuleFailed(0), findRichText: true), findsNothing);
    });
  });

  group('弹层', () {
    testWidgets('点胶囊开、再点关；开着时按 Esc 也关', (tester) async {
      await _pump(tester, const <JobState>[
        JobState.running(jobId: 'r', providerId: 'p', canvasId: 'c1'),
      ]);
      expect(find.byKey(ShellTaskPopover.panelKey), findsNothing);

      await _open(tester);
      expect(find.byKey(ShellTaskPopover.panelKey), findsOneWidget);
      await _open(tester);
      expect(find.byKey(ShellTaskPopover.panelKey), findsNothing, reason: '再点一次胶囊是关');

      await _open(tester);
      expect(find.byKey(ShellTaskPopover.panelKey), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(ShellTaskPopover.panelKey), findsNothing, reason: 'Esc 关');
    });

    testWidgets('弹层在胶囊正上方、左沿对齐，宽 340', (tester) async {
      await _pump(tester, const <JobState>[
        JobState.running(jobId: 'r', providerId: 'p', canvasId: 'c1'),
      ]);
      await _open(tester);
      final Rect panel = tester.getRect(find.byKey(ShellTaskPopover.panelKey));
      final Rect capsule = tester.getRect(find.byKey(ShellTaskCapsule.capsuleKey));
      expect(panel.width, ShellTaskPopover.width);
      expect(panel.left, closeTo(capsule.left, 0.5));
      expect(panel.bottom, closeTo(capsule.top - ShellTaskCapsule.popoverLift, 0.5));
    });

    testWidgets('头部「任务」+「并发 N」（JobQueueService 的全局并发上限）', (tester) async {
      await _pump(tester, const <JobState>[
        JobState.running(jobId: 'r', providerId: 'p', canvasId: 'c1'),
      ]);
      await _open(tester);
      final AppLocalizations l = _l(tester);
      expect(find.text(l.taskPopoverTitle), findsOneWidget);
      expect(find.text(l.renderQueueConcurrency(kDefaultGlobalConcurrency)), findsOneWidget);
    });

    testWidgets('行：活动在前终态在后；任务名 = 源节点名（别的画布也找得到），没有源节点回退 provider 显示名；'
        'meta = provider · 状态；运行中的行有进度条', (tester) async {
      await _pump(
        tester,
        const <JobState>[
          JobState.succeeded(
            jobId: 'done1',
            providerId: 'gemini-image',
            canvasId: 'c1',
            sourceNodeId: 'n1',
            artifactPath: 'x',
          ),
          JobState.running(
            jobId: 'run1',
            providerId: 'gemini-image',
            canvasId: 'c2',
            sourceNodeId: 'n2',
            progress: 0.5,
          ),
          JobState.cancelled(jobId: 'gone1', providerId: 'gemini-image', canvasId: 'c1'),
          JobState.queued(jobId: 'q1', providerId: 'gemini-image', canvasId: 'c1'),
        ],
        nodes: const <CanvasNode>[
          CanvasNode(id: 'n1', label: 'Harbor Docks', type: CanvasNodeType.image, canvasId: 'c1'),
          CanvasNode(id: 'n2', label: 'Mountain Pass', type: CanvasNodeType.video, canvasId: 'c2'),
        ],
      );
      await _open(tester);
      await tester.pump();
      final AppLocalizations l = _l(tester);

      final List<double> tops = <String>['run1', 'q1', 'done1', 'gone1']
          .map((String id) => tester.getTopLeft(find.byKey(ShellTaskPopover.rowKey(id))).dy)
          .toList();
      for (int i = 0; i + 1 < tops.length; i++) {
        expect(tops[i], lessThan(tops[i + 1]), reason: '行序应为 run1 / q1 / done1 / gone1');
      }

      expect(_inRow('run1', find.text('Mountain Pass')), findsOneWidget, reason: '别的画布上的 job 也列，名字从那张画布里找');
      expect(_inRow('done1', find.text('Harbor Docks')), findsOneWidget);
      expect(_inRow('q1', find.text('Gemini Image')), findsOneWidget, reason: '没有源节点：回退 provider 显示名');
      expect(find.text('q1'), findsNothing, reason: '不暴露 jobId');

      expect(_inRow('run1', find.text('Gemini Image · ${l.renderQueueStatusRunning}')), findsOneWidget);
      expect(_inRow('q1', find.text('Gemini Image · ${l.canvasRenderQueueStatusQueued}')), findsOneWidget);
      expect(_inRow('done1', find.text('Gemini Image · ${l.renderQueueStatusDone}')), findsOneWidget);
      expect(_inRow('gone1', find.text('Gemini Image · ${l.renderQueueStatusCancelled}')), findsOneWidget);

      expect(find.byKey(ShellTaskPopover.progressKey('run1')), findsOneWidget);
      expect(find.byKey(ShellTaskPopover.progressKey('q1')), findsNothing, reason: '只有运行中的行有进度条');
      expect(
        tester
            .widget<FractionallySizedBox>(find.descendant(
              of: find.byKey(ShellTaskPopover.progressKey('run1')),
              matching: find.byType(FractionallySizedBox),
            ))
            .widthFactor,
        0.5,
      );
    });

    testWidgets('失败行：状态「失败」+ tooltip 是本地化错误；不给「取消」', (tester) async {
      await _pump(tester, const <JobState>[
        JobState.failed(jobId: 'f', providerId: 'gemini-image', canvasId: 'c1', error: _timeout),
      ]);
      await _open(tester);
      final AppLocalizations l = _l(tester);
      expect(_inRow('f', find.text('Gemini Image · ${l.renderQueueStatusFailed}')), findsOneWidget);
      expect(find.byTooltip(l10nErrorFor(l, _timeout)), findsOneWidget);
      expect(find.byKey(ShellTaskPopover.cancelKey('f')), findsNothing);
    });

    testWidgets('「取消」只给非终态行，点了委托 JobQueueService.cancel(jobId)', (tester) async {
      final _CapturingQueue queue = _CapturingQueue();
      await _pump(
        tester,
        const <JobState>[
          JobState.running(jobId: 'job-x', providerId: 'p', canvasId: 'c1', progress: 0.5),
          JobState.queued(jobId: 'job-q', providerId: 'p', canvasId: 'c1'),
          JobState.succeeded(jobId: 'job-s', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
        ],
        extra: <Override>[jobQueueServiceProvider.overrideWith((ref) async => queue)],
      );
      await _open(tester);
      expect(find.byKey(ShellTaskPopover.cancelKey('job-x')), findsOneWidget);
      expect(find.byKey(ShellTaskPopover.cancelKey('job-q')), findsOneWidget);
      expect(find.byKey(ShellTaskPopover.cancelKey('job-s')), findsNothing);
      expect(find.byTooltip(_l(tester).canvasRenderQueueCancel), findsNWidgets(2));

      await tester.tap(find.byKey(ShellTaskPopover.cancelKey('job-x')));
      await tester.pump();
      expect(queue.cancelledJobId, 'job-x');
    });

    testWidgets('「定位」只给终态 + 源节点还在 + 同画布或拿得到项目的行', (tester) async {
      const ProjectRef alpha = ProjectRef(id: 'p1', name: 'Alpha');
      await _pump(
        tester,
        const <JobState>[
          // 同一画布：直接能定位。
          JobState.succeeded(
            jobId: 'same',
            providerId: 'p',
            canvasId: 'c1',
            projectId: 'p1',
            sourceNodeId: 'n1',
            artifactPath: 'x',
          ),
          // 同项目的另一张画布：项目就是外壳当前项目，能定位。
          JobState.failed(
            jobId: 'other',
            providerId: 'p',
            canvasId: 'c2',
            projectId: 'p1',
            sourceNodeId: 'n2',
            error: _timeout,
          ),
          // 别的项目、工作库列表里也找不到名字：不给（点了没处去）。
          JobState.succeeded(
            jobId: 'unknown',
            providerId: 'p',
            canvasId: 'c3',
            projectId: 'p9',
            sourceNodeId: 'n3',
            artifactPath: 'x',
          ),
          // 没有源节点：不给。
          JobState.succeeded(jobId: 'nosrc', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
          // 源节点已经不在画布上：不给。
          JobState.cancelled(jobId: 'deleted', providerId: 'p', canvasId: 'c1', sourceNodeId: 'gone'),
          // 非终态：给的是「取消」不是「定位」。
          JobState.running(jobId: 'busy', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n1'),
        ],
        nodes: const <CanvasNode>[
          CanvasNode(id: 'n1', label: 'One', type: CanvasNodeType.text, canvasId: 'c1'),
          CanvasNode(id: 'n2', label: 'Two', type: CanvasNodeType.text, canvasId: 'c2'),
          CanvasNode(id: 'n3', label: 'Three', type: CanvasNodeType.text, canvasId: 'c3'),
        ],
        extra: <Override>[
          shellControllerProvider.overrideWith(
            () => ShellNavigator(
              initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: alpha),
            ),
          ),
        ],
      );
      await _open(tester);
      await tester.pump();

      expect(find.byKey(ShellTaskPopover.locateKey('same')), findsOneWidget);
      expect(find.byKey(ShellTaskPopover.locateKey('other')), findsOneWidget);
      expect(find.byKey(ShellTaskPopover.locateKey('unknown')), findsNothing);
      expect(find.byKey(ShellTaskPopover.locateKey('nosrc')), findsNothing);
      expect(find.byKey(ShellTaskPopover.locateKey('deleted')), findsNothing);
      expect(find.byKey(ShellTaskPopover.locateKey('busy')), findsNothing);
      expect(find.byKey(ShellTaskPopover.cancelKey('busy')), findsOneWidget);
    });

    testWidgets('「清除已完成」清掉终态、留下活动行；之后没有终态就不可点', (tester) async {
      final ProviderContainer c = await _pump(tester, const <JobState>[
        JobState.running(jobId: 'r', providerId: 'p', canvasId: 'c1', progress: 0.2),
        JobState.succeeded(jobId: 's', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
        JobState.failed(jobId: 'f', providerId: 'p', canvasId: 'c1', error: _timeout),
      ]);
      await _open(tester);
      expect(tester.widget<InkActivatable>(find.byKey(ShellTaskPopover.clearDoneKey)).onTap, isNotNull);

      await tester.tap(find.byKey(ShellTaskPopover.clearDoneKey));
      await tester.pump();

      expect(c.read(jobsRegistryProvider).map((JobState j) => j.jobId), <String>['r']);
      expect(find.byKey(ShellTaskPopover.rowKey('s')), findsNothing);
      expect(find.byKey(ShellTaskPopover.rowKey('f')), findsNothing);
      expect(find.byKey(ShellTaskPopover.rowKey('r')), findsOneWidget);
      expect(
        tester.widget<InkActivatable>(find.byKey(ShellTaskPopover.clearDoneKey)).onTap,
        isNull,
        reason: '没有终态可清：不可点（不挂空闭包）',
      );
    });

    testWidgets('清到注册表空：胶囊连同弹层一起消失', (tester) async {
      await _pump(tester, const <JobState>[
        JobState.succeeded(jobId: 's', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
      ]);
      await _open(tester);
      await tester.tap(find.byKey(ShellTaskPopover.clearDoneKey));
      await tester.pump();
      expect(find.byKey(ShellTaskCapsule.capsuleKey), findsNothing);
      expect(find.byKey(ShellTaskPopover.panelKey), findsNothing);
    });
  });
}
