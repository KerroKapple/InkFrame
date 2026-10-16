// CanvasJobListener 真实 widget 测试：pump 生产代码本体（非手抄副本）。
// 验证 jobsRegistry 变化 → 节点重拉走真实接线，且【这里不弹通知】——
// 生成完成 / 失败的通知卡归应用级的 JobNotificationListener
// （test/features/notifications/widgets/job_notification_listener_test.dart）；
// 这里再弹一次，失败就会出两张卡。ToastService 仍换成记录用的假实现，就是为了
// 钉住「一张都没弹」。
// 纯决策矩阵由 canvas_job_effects_test.dart 覆盖。
//
// 刷新按 job 所在画布走，不只当前画布：状态栏任务弹层开着时会 watch 别的画布的节点控制器（找源节点），
// 那张画布上的 job 成功，它的控制器也得重新读库——否则「定位」过去看到的是旧节点表。最后一条用例
// 把弹层本体和监听器一起 pump，钉的就是这件事。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/db/columns.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_job_listener.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/widgets/shell_task_popover.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_toast_service.dart';

// ── fakes ──────────────────────────────────────────────────────────────────
/// 计数 listByCanvas 的 NodeRepository——invalidate → rebuild → 计数 +1。
/// 按画布存一份「库」（没种过的画布读出来是空表），并按画布记读了几次。
class _CountingNodeRepository implements NodeRepository {
  int listByCanvasCalls = 0;

  /// 画布 id → 库里的节点行（listByCanvas 原样返回）。
  final Map<String, List<Map<String, Object?>>> rowsByCanvas =
      <String, List<Map<String, Object?>>>{};

  /// 画布 id → 被读了几次。
  final Map<String, int> readsByCanvas = <String, int>{};

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async {
    listByCanvasCalls++;
    readsByCanvas[canvasId] = (readsByCanvas[canvasId] ?? 0) + 1;
    return rowsByCanvas[canvasId] ?? const <Map<String, Object?>>[];
  }

  @override
  Future<String> create({
    required String canvasId,
    required String type,
    required String nodeRole,
    String label = '',
    String? sourceNodeId,
    String? laneId,
    double positionX = 0,
    double positionY = 0,
    double width = 240,
    double height = 240,
    int zIndex = 0,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>?> findById(String id) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) =>
      throw UnimplementedError();

  @override
  Future<int> softDeleteEmptyOrphanResults() async => 0;

  @override
  Future<List<String>> listAllMediaUrls() async => const <String>[];

  @override
  Future<int> update(String id, Map<String, Object?> patch) =>
      throw UnimplementedError();

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) =>
      throw UnimplementedError();

  @override
  Future<int> softDelete(String id) => throw UnimplementedError();

  @override
  Future<int> restore(String id) => throw UnimplementedError();

  @override
  Future<int> hardDelete(String id) => throw UnimplementedError();
}

const _err = NetworkError(code: InkErrorCode.networkOffline);

/// 一行节点（列名走 NodeCol，与真仓储读出来的行同形）。
Map<String, Object?> _nodeRow(
  String id, {
  required String canvasId,
  required NodeRole role,
  String label = '',
  String? source,
  String? imageUrl,
}) =>
    <String, Object?>{
      NodeCol.id: id,
      NodeCol.canvasId: canvasId,
      NodeCol.type: CanvasNodeType.image.name,
      NodeCol.nodeRole: role.name,
      NodeCol.label: label,
      NodeCol.sourceNodeId: source,
      NodeCol.typeConfig: <String, Object?>{'image_url': ?imageUrl},
    };

void main() {
  late RecordingToastService toasts;
  late _CountingNodeRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    toasts = RecordingToastService();
    fakeRepo = _CountingNodeRepository();
    container = ProviderContainer(
      overrides: [
        // 当前画布 = c1：下面「别的画布」都是相对它说的。
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
        toastServiceProvider.overrideWithValue(toasts),
        nodeRepositoryProvider.overrideWith((ref) async => fakeRepo),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          home: const Scaffold(body: CanvasJobListener(child: SizedBox())),
        ),
      ),
    );
    // 让 nodes controller 处于活跃订阅，invalidate 才会触发重建。
    container.listen(
      canvasNodesControllerProvider('c1'),
      (_, _) {},
      fireImmediately: true,
    );
    await tester.pumpAndSettle();
  }

  /// 监听器 + 任务弹层本体（状态栏胶囊点开后挂的就是它）：弹层为每个 job 去 job 所在画布的节点控制器里
  /// 找源节点，别的画布的控制器就是这样被保活的。
  Future<void> pumpWithTaskPopover(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          home: const Scaffold(
            body: CanvasJobListener(
              child: Align(alignment: Alignment.bottomLeft, child: ShellTaskPopover()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('JobFailed 推入 → 节点重拉，但这里不弹通知（归应用级监听）', (tester) async {
    await pump(tester);
    final baseline = fakeRepo.listByCanvasCalls;
    expect(baseline, greaterThan(0), reason: '前置：controller 已完成首拉');

    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.failed(
            jobId: 'a',
            providerId: 'p',
            canvasId: 'c1',
            error: _err,
          ),
        );
    await tester.pumpAndSettle();

    expect(
      toasts.shown,
      isEmpty,
      reason: '失败卡由 JobNotificationListener 弹；这里再弹就是两张',
    );
    expect(fakeRepo.listByCanvasCalls, greaterThan(baseline),
        reason: 'invalidate 应触发节点重拉');
  });

  testWidgets('JobCancelled 推入 → 不通知但节点重拉', (tester) async {
    await pump(tester);
    final baseline = fakeRepo.listByCanvasCalls;

    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.cancelled(
            jobId: 'b',
            providerId: 'p',
            canvasId: 'c1',
          ),
        );
    await tester.pumpAndSettle();

    expect(toasts.shown, isEmpty);
    expect(fakeRepo.listByCanvasCalls, greaterThan(baseline));
  });

  testWidgets('别的画布 JobFailed、那张画布的控制器没人 watch → 无通知；invalidate 落空，谁都不重拉', (tester) async {
    await pump(tester);
    final baseline = fakeRepo.listByCanvasCalls;

    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.failed(
            jobId: 'c',
            providerId: 'p',
            canvasId: 'other-canvas',
            error: _err,
          ),
        );
    await tester.pumpAndSettle();

    expect(toasts.shown, isEmpty);
    expect(fakeRepo.listByCanvasCalls, baseline);
  });

  testWidgets('任务弹层 watch 着别的画布：那张画布上的 job 成功 → 它的控制器重新读库，读到带产物的新状态',
      (tester) async {
    // 当前画布是 c1；c2 上有一个还在跑的 job：库里是配置节点 + 还没有产物的 result 占位。
    fakeRepo.rowsByCanvas['c2'] = <Map<String, Object?>>[
      _nodeRow('cfg-b', canvasId: 'c2', role: NodeRole.config, label: 'Harbor dawn'),
      _nodeRow('r-b', canvasId: 'c2', role: NodeRole.result, source: 'cfg-b'),
    ];
    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.running(
            jobId: 'jb',
            providerId: 'p',
            canvasId: 'c2',
            sourceNodeId: 'cfg-b',
            resultNodeId: 'r-b',
            progress: 0.5,
          ),
        );
    await pumpWithTaskPopover(tester);

    // 前置：弹层正 watch c2 的控制器——任务名就是从那里找到的源节点名。
    expect(find.text('Harbor dawn'), findsOneWidget);
    expect(container.exists(canvasNodesControllerProvider('c2')), isTrue);
    final int readsBefore = fakeRepo.readsByCanvas['c2'] ?? 0;
    expect(readsBefore, greaterThan(0), reason: '前置：c2 已经读过一次库');

    // 产物落库（result 有了 image_url），然后 job 转成功。
    fakeRepo.rowsByCanvas['c2'] = <Map<String, Object?>>[
      _nodeRow('cfg-b', canvasId: 'c2', role: NodeRole.config, label: 'Harbor dawn'),
      _nodeRow('r-b', canvasId: 'c2', role: NodeRole.result, source: 'cfg-b', imageUrl: 'images/b.png'),
    ];
    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.succeeded(
            jobId: 'jb',
            providerId: 'p',
            canvasId: 'c2',
            sourceNodeId: 'cfg-b',
            resultNodeId: 'r-b',
            artifactPath: 'images/b.png',
          ),
        );
    await tester.pumpAndSettle();

    expect(fakeRepo.readsByCanvas['c2'], greaterThan(readsBefore),
        reason: 'job 所在画布（不是当前画布）的控制器要失效、重新读库');
    final CanvasNode result = container
        .read(canvasNodesControllerProvider('c2'))
        .requireValue
        .firstWhere((CanvasNode n) => n.id == 'r-b');
    expect(result.imageUrl, 'images/b.png', reason: '「定位」过去要看到产物，不是旧的占位');
  });
}
