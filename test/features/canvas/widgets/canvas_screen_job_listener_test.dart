// CanvasJobListener 真实 widget 测试：pump 生产代码本体（非手抄副本）。
// 验证 jobsRegistry 变化 → toast / 节点重拉两条副作用都走真实接线。
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
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

// ── fakes ──────────────────────────────────────────────────────────────────
class _FakeToastService implements ToastService {
  final List<({String message, ToastKind kind})> calls = [];

  @override
  void show(String message, {ToastKind kind = ToastKind.info}) {
    calls.add((message: message, kind: kind));
  }
}

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
  late _FakeToastService fakeToast;
  late _CountingNodeRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeToast = _FakeToastService();
    fakeRepo = _CountingNodeRepository();
    container = ProviderContainer(
      overrides: [
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
        toastServiceProvider.overrideWithValue(fakeToast),
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

  testWidgets('JobFailed 推入 → toast error 一次 + 节点重拉', (tester) async {
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

    expect(fakeToast.calls, hasLength(1));
    expect(fakeToast.calls.first.kind, ToastKind.error);
    // toast 文案是 l10n 后的用户文案，绝不应是 messageKey 本身。
    expect(fakeToast.calls.first.message, isNot('errorNetworkOffline'));
    expect(fakeRepo.listByCanvasCalls, greaterThan(baseline),
        reason: 'invalidate 应触发节点重拉');
  });

  testWidgets('JobCancelled 推入 → 不 toast 但节点重拉', (tester) async {
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

    expect(fakeToast.calls, isEmpty);
    expect(fakeRepo.listByCanvasCalls, greaterThan(baseline));
  });

  testWidgets('别的画布 JobFailed → 无 toast 无重拉', (tester) async {
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

    expect(fakeToast.calls, isEmpty);
    expect(fakeRepo.listByCanvasCalls, baseline);
  });
}
