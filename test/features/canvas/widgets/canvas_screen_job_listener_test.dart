// CanvasJobListener 真实 widget 测试：pump 生产代码本体（非手抄副本）。
// 验证 jobsRegistry 变化 → 节点重拉走真实接线，且【这里不弹通知】——
// 生成完成 / 失败的通知卡归应用级的 JobNotificationListener
// （test/features/notifications/widgets/job_notification_listener_test.dart）；
// 这里再弹一次，失败就会出两张卡。ToastService 仍换成记录用的假实现，就是为了
// 钉住「一张都没弹」。
// 纯决策矩阵由 canvas_job_effects_test.dart 覆盖。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_job_listener.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_toast_service.dart';

// ── fakes ──────────────────────────────────────────────────────────────────
/// 只计数 listByCanvas 的 NodeRepository——invalidate → rebuild → 计数 +1。
class _CountingNodeRepository implements NodeRepository {
  int listByCanvasCalls = 0;

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async {
    listByCanvasCalls++;
    return const <Map<String, Object?>>[];
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

void main() {
  late RecordingToastService toasts;
  late _CountingNodeRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    toasts = RecordingToastService();
    fakeRepo = _CountingNodeRepository();
    container = ProviderContainer(
      overrides: [
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

  testWidgets('别的画布 JobFailed → 无通知无重拉', (tester) async {
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
}
