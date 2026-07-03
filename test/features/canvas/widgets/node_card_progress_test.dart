// 节点卡实时进度：nodeActiveJobProvider 选活跃 job + NodeCard 底部进度条渲染。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/node_active_job.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';

import '../../../_harness/test_app.dart';

class _FakeResolver implements FileResolverService {
  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) =>
      throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      Directory.systemTemp;
  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('${Directory.systemTemp.path}/$relativePath');
  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      source.path;
}

void main() {
  test('nodeActiveJobProvider：选本节点活跃 job；终态/他节点/无 job → null', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final reg = c.read(jobsRegistryProvider.notifier);
    reg.upsert(const JobState.running(
      jobId: 'j1',
      providerId: 'p',
      canvasId: 'cv',
      sourceNodeId: 'n1',
      progress: 0.4,
    ));
    reg.upsert(const JobState.succeeded(
      jobId: 'j2',
      providerId: 'p',
      canvasId: 'cv',
      sourceNodeId: 'n2',
      artifactPath: 'images/x.png',
    ));

    expect(c.read(nodeActiveJobProvider('n1'))?.jobId, 'j1');
    expect(c.read(nodeActiveJobProvider('n2')), isNull); // 终态不算
    expect(c.read(nodeActiveJobProvider('nX')), isNull); // 无 job
  });

  Future<ProviderContainer> pump(WidgetTester tester, CanvasNode node) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: NodeCard(
            node: node,
            selected: false,
            onTap: () {},
            onDragEnd: (_) {},
          ),
        ),
      ),
      overrides: [
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
      ],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(NodeCard)));
  }

  testWidgets('无活跃 job → 无进度条', (tester) async {
    const n = CanvasNode(id: 'n1', label: 'A', type: CanvasNodeType.image);
    await pump(tester, n);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('running job(有进度) → 进度条 value=进度', (tester) async {
    const n = CanvasNode(id: 'n1', label: 'A', type: CanvasNodeType.image);
    final c = await pump(tester, n);
    c.read(jobsRegistryProvider.notifier).upsert(const JobState.running(
          jobId: 'j1',
          providerId: 'p',
          canvasId: 'cv',
          sourceNodeId: 'n1',
          progress: 0.5,
        ));
    await tester.pump();
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);
  });

  testWidgets('queued job → 进度条不确定(value=null)', (tester) async {
    const n = CanvasNode(id: 'n1', label: 'A', type: CanvasNodeType.image);
    final c = await pump(tester, n);
    c.read(jobsRegistryProvider.notifier).upsert(const JobState.queued(
          jobId: 'j1',
          providerId: 'p',
          canvasId: 'cv',
          sourceNodeId: 'n1',
        ));
    await tester.pump();
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNull);
  });
}
