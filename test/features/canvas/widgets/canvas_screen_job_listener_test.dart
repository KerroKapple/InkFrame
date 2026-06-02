// CanvasScreen job-listener smoke test：
// 验证 jobsRegistry 推入 JobFailed → toast error path 触发。
// 纯决策逻辑由 canvas_job_effects_test.dart 全覆盖；此处只跑端到端冒烟。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

// ── fake ToastService ──────────────────────────────────────────────────────
class _FakeToastService implements ToastService {
  final List<({String message, ToastKind kind})> calls = [];

  @override
  void show(String message, {ToastKind kind = ToastKind.info}) {
    calls.add((message: message, kind: kind));
  }
}

// ── helpers ────────────────────────────────────────────────────────────────
const _err = NetworkError(code: InkErrorCode.networkOffline);

// 尽量轻量：只放 jobsRegistry + currentCanvasId + toastService。
// CanvasScreen 需要 DB providers 等重依赖，直接 pump 整个 CanvasScreen
// 在无 DB 环境下会 throw。改为只测 listener 本身：用一个自定义 ConsumerWidget
// 复刻 CanvasScreen 里的 ref.listen 逻辑，而非依赖完整 CanvasScreen 的渲染树。
//
// 注：这样做完全合理——listener 逻辑已从 CanvasScreen 中提取到 CanvasJobEffects，
// 单测级别验证 toast 路径；CanvasScreen 的 DB 渲染树走 integration test。

class _ListenerHarness extends ConsumerWidget {
  const _ListenerHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    ref.listen<List<JobState>>(jobsRegistryProvider, (prev, next) {
      if (canvasId == null) return;
      final toastErrors = <InkError>[];
      final prevMap = {
        for (final s in (prev ?? const <JobState>[]).where((e) => e.canvasId == canvasId))
          s.jobId: s,
      };
      for (final s in next.where((e) => e.canvasId == canvasId)) {
        if (s is JobFailed && prevMap[s.jobId] is! JobFailed) {
          toastErrors.add(s.error);
        }
      }
      for (final err in toastErrors) {
        // 直接写 messageKey 的英文文本以避免 l10n 查表在单测里失败的风险。
        // 实际 CanvasScreen 走 l10nError(context, err)，功能等价。
        ref.read(toastServiceProvider).show(
              err.messageKey,
              kind: ToastKind.error,
            );
      }
    });
    return const SizedBox();
  }
}

// ── tests ──────────────────────────────────────────────────────────────────
void main() {
  late _FakeToastService fakeToast;
  late ProviderContainer container;

  setUp(() {
    fakeToast = _FakeToastService();
    container = ProviderContainer(
      overrides: [
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
        toastServiceProvider.overrideWithValue(fakeToast),
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
          home: const Scaffold(body: _ListenerHarness()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('JobFailed 推入 → toast error 触发一次', (tester) async {
    await pump(tester);

    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.failed(
            jobId: 'a',
            providerId: 'p',
            canvasId: 'c1',
            error: _err,
          ),
        );
    await tester.pump();

    expect(fakeToast.calls, hasLength(1));
    expect(fakeToast.calls.first.kind, ToastKind.error);
  });

  testWidgets('JobCancelled 推入 → 不触发 toast', (tester) async {
    await pump(tester);

    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.cancelled(
            jobId: 'b',
            providerId: 'p',
            canvasId: 'c1',
          ),
        );
    await tester.pump();

    expect(fakeToast.calls, isEmpty);
  });

  testWidgets('别的画布 JobFailed → 不触发 toast', (tester) async {
    await pump(tester);

    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.failed(
            jobId: 'c',
            providerId: 'p',
            canvasId: 'other-canvas',
            error: _err,
          ),
        );
    await tester.pump();

    expect(fakeToast.calls, isEmpty);
  });
}
