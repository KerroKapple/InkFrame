// JobNotificationListener：jobsRegistry 的新终态 → 应用级通知卡。
//
// 钉的是：成功 = 一张带提示音、带「查看」的完成卡（标题用活着的画布里的节点名，缩略图
// 用图片产物本身）；失败 = 一张带本地化原因的失败卡；取消不通知；registry 反复发射不重复；
// 挂上之前就已经是终态的 job 不补发；拿不到节点名 / 项目名时退回泛化标题、不给按钮。
//
// ToastService 换成 RecordingToastService（没有 Timer），所以这里可以用
// UncontrolledProviderScope + addTearDown 释放容器。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/notifications/widgets/job_notification_listener.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_toast_service.dart';

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');

const List<CanvasNode> _nodes = <CanvasNode>[
  CanvasNode(
    id: 'n1',
    label: 'Shot 1',
    type: CanvasNodeType.image,
    canvasId: 'c1',
  ),
  CanvasNode(
    id: 'r1',
    label: '',
    type: CanvasNodeType.image,
    role: NodeRole.result,
    canvasId: 'c1',
    sourceNodeId: 'n1',
  ),
];

JobState _queued(String id) => JobState.queued(
      jobId: id,
      providerId: 'p',
      canvasId: 'c1',
      projectId: 'p1',
      sourceNodeId: 'n1',
      resultNodeId: 'r1',
    );

JobState _succeeded(String id, {String artifactPath = 'images/j1.png'}) =>
    JobState.succeeded(
      jobId: id,
      providerId: 'p',
      canvasId: 'c1',
      projectId: 'p1',
      sourceNodeId: 'n1',
      resultNodeId: 'r1',
      artifactPath: artifactPath,
    );

class _Harness {
  _Harness(this.container, this.toasts);

  final ProviderContainer container;
  final RecordingToastService toasts;

  void upsert(JobState job) =>
      container.read(jobsRegistryProvider.notifier).upsert(job);
}

/// [canvasAlive]：任务所在画布的节点控制器是否本来就活着（画布开着）。
/// [before]：挂上监听之前 registry 里就已经有的条目。
Future<_Harness> _pump(
  WidgetTester tester, {
  bool canvasAlive = true,
  ShellState shell = const ShellState(project: _alpha),
  List<JobState> before = const <JobState>[],
  InMemoryNodeRepository? repo,
}) async {
  final RecordingToastService toasts = RecordingToastService();
  final InMemoryNodeRepository nodeRepo = repo ?? InMemoryNodeRepository();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      toastServiceProvider.overrideWithValue(toasts),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
      canvasNodesControllerProvider
          .overrideWith(() => FakeNodesController(_nodes)),
      shellControllerProvider.overrideWith(() => ShellNavigator(initial: shell)),
    ],
  );
  addTearDown(container.dispose);
  for (final JobState job in before) {
    container.read(jobsRegistryProvider.notifier).upsert(job);
  }
  if (canvasAlive) {
    container.listen(
      canvasNodesControllerProvider('c1'),
      (_, _) {},
      fireImmediately: true,
    );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const JobNotificationListener(child: SizedBox.expand()),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, toasts);
}

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(JobNotificationListener)).l10n;

void main() {
  testWidgets('成功：一张完成卡——节点名标题、图片缩略图、提示音、「查看」', (tester) async {
    final _Harness h = await _pump(tester);
    h.upsert(_queued('j1'));
    await tester.pump();
    expect(h.toasts.shown, isEmpty, reason: '还没到终态');

    h.upsert(_succeeded('j1'));
    await tester.pump();

    expect(h.toasts.shown, hasLength(1));
    final RecordedToast t = h.toasts.shown.single;
    expect(t.kind, ToastKind.success);
    expect(t.title, _l10n(tester).jobNotifySucceeded('Shot 1'));
    expect(t.chime, isTrue, reason: '后台事件到达，按设置响一声');
    expect(t.thumbnailPath, isNotNull);
    expect(
      t.thumbnailPath!.replaceAll(r'\', '/'),
      endsWith('images/j1.png'),
      reason: '图片任务的产物本身就是缩略图，经 FileResolverService 解析成绝对路径',
    );
    expect(t.primary?.label, _l10n(tester).toastActionView);
  });

  testWidgets('「查看」：打开产物所在画布（带项目）并选中 result 节点', (tester) async {
    final _Harness h = await _pump(
      tester,
      shell: const ShellState(tab: ShellTab.gallery, project: _alpha),
    );
    h.container.listen(canvasSelectionControllerProvider('c1'), (_, _) {});
    h.upsert(_succeeded('j1'));
    await tester.pump();

    h.toasts.shown.single.primary!.onPressed();
    final ShellState s = h.container.read(shellControllerProvider);
    expect(s.tab, ShellTab.canvas);
    expect(s.canvasId, 'c1');
    expect(s.project, _alpha);
    expect(h.container.read(canvasSelectionControllerProvider('c1')), <String>{'r1'});
  });

  testWidgets('失败：一张失败卡——本地化原因、提示音、按节点去重', (tester) async {
    final _Harness h = await _pump(tester);
    h.upsert(
      const JobState.failed(
        jobId: 'j2',
        providerId: 'p',
        canvasId: 'c1',
        projectId: 'p1',
        sourceNodeId: 'n1',
        resultNodeId: 'r1',
        error: NetworkError(code: InkErrorCode.networkOffline),
      ),
    );
    await tester.pump();

    expect(h.toasts.shown, hasLength(1));
    final RecordedToast t = h.toasts.shown.single;
    expect(t.kind, ToastKind.error);
    expect(t.title, _l10n(tester).jobNotifyFailed('Shot 1'));
    expect(t.body, _l10n(tester).errorNetworkOffline, reason: '用户文案，不是 messageKey');
    expect(t.chime, isTrue);
    expect(t.dedupeKey, isNotNull);
  });

  testWidgets('取消不通知', (tester) async {
    final _Harness h = await _pump(tester);
    h.upsert(_queued('j3'));
    h.upsert(
      const JobState.cancelled(
        jobId: 'j3',
        providerId: 'p',
        canvasId: 'c1',
        projectId: 'p1',
      ),
    );
    await tester.pump();
    expect(h.toasts.shown, isEmpty);
  });

  testWidgets('registry 反复发射不重复通知', (tester) async {
    final _Harness h = await _pump(tester);
    h.upsert(_succeeded('j1'));
    await tester.pump();
    // 终态条目长期留在 registry 里：别的 job 每变一次，整张表都会再发一遍。
    h.upsert(_queued('j9'));
    h.upsert(
      const JobState.running(
        jobId: 'j9',
        providerId: 'p',
        canvasId: 'c1',
        progress: 0.5,
      ),
    );
    h.upsert(_succeeded('j1')); // 同值 upsert
    await tester.pump();
    expect(h.toasts.shown, hasLength(1));
  });

  testWidgets('挂上之前就已经是终态的 job 不补发', (tester) async {
    final _Harness h = await _pump(tester, before: <JobState>[_succeeded('old')]);
    h.upsert(_queued('j9'));
    await tester.pump();
    expect(h.toasts.shown, isEmpty);
  });

  testWidgets('视频：内存里还是占位节点时读一次库，拿首帧缩略图', (tester) async {
    final InMemoryNodeRepository repo = InMemoryNodeRepository();
    final String resultId = await repo.create(
      canvasId: 'c1',
      type: 'video',
      nodeRole: 'result',
      sourceNodeId: 'n1',
      typeConfig: const <String, Object?>{'thumbnail_url': 'thumbs/v1.jpg'},
    );
    final _Harness h = await _pump(tester, repo: repo);
    h.upsert(JobState.succeeded(
      jobId: 'jv',
      providerId: 'p',
      canvasId: 'c1',
      projectId: 'p1',
      sourceNodeId: 'n1',
      resultNodeId: resultId,
      artifactPath: 'videos/v1.mp4',
    ));
    await tester.pump();
    await tester.pump();
    final RecordedToast t = h.toasts.shown.single;
    expect(t.kind, ToastKind.success);
    expect(t.thumbnailPath, isNotNull);
    // StubFileResolver 原样拼接相对路径，所以斜杠保持原样。
    expect(t.thumbnailPath, endsWith('thumbs/v1.jpg'));
  });

  testWidgets('画布没开着：泛化标题；视频产物库里也没有首帧时不硬塞缩略图', (tester) async {
    final _Harness h = await _pump(tester, canvasAlive: false);
    h.upsert(_succeeded('j4', artifactPath: 'videos/j4.mp4'));
    await tester.pump();
    final RecordedToast t = h.toasts.shown.single;
    expect(t.title, _l10n(tester).jobNotifySucceededGeneric);
    expect(t.thumbnailPath, isNull);
  });

  testWidgets('拿不到项目名时不给「查看」（不挂点了没反应的按钮）', (tester) async {
    final _Harness h = await _pump(tester, shell: const ShellState());
    h.upsert(_succeeded('j5'));
    await tester.pump();
    expect(h.toasts.shown.single.primary, isNull);
  });
}
