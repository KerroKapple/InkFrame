import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/widgets/canvas_render_queue.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

class _SeedableJobsRegistry extends JobsRegistry {
  _SeedableJobsRegistry(this._seed);
  final List<JobState> _seed;

  @override
  List<JobState> build() => List<JobState>.unmodifiable(_seed);
}

Widget _host(List<JobState> jobs, String canvasId) {
  return ProviderScope(
    overrides: [
      currentCanvasIdProvider.overrideWith((ref) => canvasId),
      jobsRegistryProvider.overrideWith(() => _SeedableJobsRegistry(jobs)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: CanvasRenderQueue()),
    ),
  );
}

void main() {
  testWidgets('只显示当前画布的活跃任务，无假数据', (tester) async {
    await tester.pumpWidget(_host([
      const JobState.running(jobId: 'a', providerId: 'p', canvasId: 'c1', progress: 0.45),
      const JobState.running(jobId: 'b', providerId: 'p', canvasId: 'c2', progress: 0.9),
      const JobState.succeeded(jobId: 'd', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
    ], 'c1'));
    await tester.pump();
    expect(find.text('Watch Closeup'), findsNothing);
    expect(find.text('Harbor Docks'), findsNothing);
    expect(find.textContaining('45'), findsOneWidget);
    expect(find.textContaining('90'), findsNothing);
  });

  testWidgets('任务行标题显示 provider displayName 而非 jobId(UUID)', (tester) async {
    await tester.pumpWidget(_host([
      const JobState.running(
        jobId: 'a1b2c3d4-uuid',
        providerId: 'gemini-image',
        canvasId: 'c1',
        progress: 0.3,
      ),
    ], 'c1'));
    await tester.pump();
    // FIX-013 x FIX-010：行标题取 displayName（未声明时回退 providerId）。
    expect(find.text('Gemini Image'), findsOneWidget);
    expect(find.text('a1b2c3d4-uuid'), findsNothing);
  });

  testWidgets('当前画布无活跃任务 → 空态', (tester) async {
    await tester.pumpWidget(_host(const [], 'c1'));
    await tester.pump();
    expect(find.text('No active renders'), findsOneWidget);
  });
}
