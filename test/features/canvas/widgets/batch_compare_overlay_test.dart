// BatchCompareOverlay：足尺并排对比浮层。
//   - errorCode 原串只在这里露出
//   - ⎘「以该种子重跑」的启用/禁用与透传
//   - 「叠加对比」是禁用标签（不做清单），不是可点按钮
//   - ←→ 切换选中格、↵ 转正当前格、Esc 关闭
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/batch_compare_overlay.dart';
import 'package:inkframe/features/generation/generation_controller.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_unit_of_work.dart';
import '../../../_harness/test_app.dart';

const _kEmDash = '—';
const _kUnknownText = 'An unknown error occurred.';

class _FakeNodeRepo implements NodeRepository {
  final List<(String, Map<String, Object?>)> patches =
      <(String, Map<String, Object?>)>[];

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    patches.add((id, Map<String, Object?>.of(patch)));
    return 1;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async =>
      <String, Object?>{'id': id, 'canvas_id': null};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeGen implements GenerationController {
  final List<String> submitted = <String>[];
  final List<int?> seeds = <int?>[];

  @override
  Future<String> submitFromConfigNode(
    String configNodeId, {
    int? seedOverride,
  }) async {
    submitted.add(configNodeId);
    seeds.add(seedOverride);
    return 'job-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeQueue implements JobQueueService {
  final List<String> cancelled = <String>[];

  @override
  Future<void> cancel(String jobId) async => cancelled.add(jobId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Map<String, Object?> row({
  required String id,
  required int slotIndex,
  required String status,
  String? errorCode,
  String? outputUrl,
  int? seed,
  int? width,
  int? height,
  bool promoted = false,
  String jobId = 'j1',
}) => <String, Object?>{
  'id': id,
  'node_id': 'n1',
  'job_id': jobId,
  'slot_index': slotIndex,
  'status': status,
  'error_code': errorCode,
  'output_url': outputUrl,
  'seed': seed,
  'width': width,
  'height': height,
  'promoted': promoted,
};

late FakeBatchResultRepo repo;
late _FakeNodeRepo _nodes;
late _FakeGen _gen;
late _FakeQueue _queue;

List<Override> overridesFor(List<Map<String, Object?>> rows) {
  repo = FakeBatchResultRepo(<String, Map<String, Object?>>{
    for (final r in rows) r['id']! as String: r,
  });
  _nodes = _FakeNodeRepo();
  _gen = _FakeGen();
  _queue = _FakeQueue();
  return <Override>[
    batchResultRepositoryProvider.overrideWith((ref) async => repo),
    nodeRepositoryProvider.overrideWith((ref) async => _nodes),
    generationControllerProvider.overrideWith((ref) async => _gen),
    jobQueueServiceProvider.overrideWith((ref) async => _queue),
    unitOfWorkProvider.overrideWith(
      (ref) async =>
          FakeUnitOfWork(FakeRepositoryScope(nodes: _nodes, batchResults: repo)),
    ),
  ];
}

void main() {
  const resultNode = CanvasNode(
    id: 'n1',
    label: 'Shot 05',
    type: CanvasNodeType.image,
    role: NodeRole.result,
    sourceNodeId: 's1',
  );

  /// 稿上的四格：promoted / success / error / generating。
  List<Map<String, Object?>> fourSlots() => <Map<String, Object?>>[
    row(
      id: 'b1',
      slotIndex: 0,
      status: 'success',
      outputUrl: 'images/a.png',
      seed: 41207,
      width: 1024,
      height: 576,
      promoted: true,
    ),
    row(
      id: 'b2',
      slotIndex: 1,
      status: 'success',
      outputUrl: 'images/b.png',
      seed: 88316,
    ),
    row(
      id: 'b3',
      slotIndex: 2,
      status: 'error',
      errorCode: 'content_policy',
      seed: 15043,
    ),
    row(id: 'b4', slotIndex: 3, status: 'generating'),
  ];

  Future<void> pumpOverlay(
    WidgetTester tester,
    List<Map<String, Object?>> rows,
  ) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: Center(child: BatchCompareOverlay(resultNode: resultNode)),
      ),
      overrides: overridesFor(rows),
      surfaceSize: const Size(1400, 900),
    );
    await tester.pumpAndSettle();
  }

  group('并排渲染', () {
    testWidgets('每格一张：序号 / 种子 / 主按钮按态分化', (tester) async {
      await pumpOverlay(tester, fourSlots());

      expect(find.text('Batch results · Shot 05'), findsOneWidget);
      // 头部元信息 = 产物真实像素尺寸
      expect(find.text('1024×576'), findsOneWidget);

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('41207'), findsOneWidget);
      expect(find.text(_kEmDash), findsOneWidget);

      // promoted 那格：徽标 + 「当前产物」状态块（徽标与主按钮同文案，共两处）
      expect(find.text('Current artifact'), findsNWidgets(2));
      expect(find.text('Set as artifact'), findsOneWidget);
      expect(find.text('Rerun this slot'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('失败格同时给本地化文案与 errorCode 原串', (tester) async {
      await pumpOverlay(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'error',
          errorCode: 'content_policy',
        ),
      ]);

      expect(
        find.text(
          "The provider's content policy rejected this prompt. "
          'Adjust the prompt and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('content_policy'), findsOneWidget);
    });

    testWidgets('未知 wire：文案回退 unknown，原串仍照实显示', (tester) async {
      await pumpOverlay(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'error',
          errorCode: 'totally_bogus_wire',
        ),
      ]);

      expect(find.text(_kUnknownText), findsOneWidget);
      expect(find.text('totally_bogus_wire'), findsOneWidget);
    });
  });

  group('顶栏两格模式', () {
    testWidgets('并排 = 选中态；叠加对比 = 禁用标签 + 说明 tooltip，且不可点', (tester) async {
      await pumpOverlay(tester, fourSlots());

      expect(find.text('Side by side'), findsOneWidget);
      expect(find.text('Overlay'), findsOneWidget);
      expect(
        find.byTooltip('Overlay comparison is not implemented'),
        findsOneWidget,
      );
      // 禁用标签不是按钮：不挂手势
      expect(
        find.ancestor(
          of: find.text('Overlay'),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });

  group('⎘ 以该种子重跑', () {
    testWidgets('有 seed → 可点，带 seedOverride 透传', (tester) async {
      await pumpOverlay(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/a.png',
          seed: 88316,
        ),
      ]);

      expect(find.byTooltip('Rerun with this seed'), findsOneWidget);
      await tester.tap(find.text('⎘'));
      await tester.pumpAndSettle();

      expect(_gen.submitted, <String>['s1']);
      expect(_gen.seeds, <int?>[88316]);
    });

    testWidgets('无 seed → 置灰：tooltip 说明原因，点了不发请求', (tester) async {
      await pumpOverlay(tester, [
        row(id: 'b1', slotIndex: 0, status: 'generating'),
      ]);

      expect(
        find.byTooltip('No seed recorded for this slot'),
        findsOneWidget,
      );
      expect(find.byTooltip('Rerun with this seed'), findsNothing);
      await tester.tap(find.text('⎘'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(_gen.submitted, isEmpty);
    });
  });

  group('主按钮动作', () {
    testWidgets('「设为产物」→ 落库并就地翻面', (tester) async {
      await pumpOverlay(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/old.png',
          promoted: true,
        ),
        row(
          id: 'b2',
          slotIndex: 1,
          status: 'success',
          outputUrl: 'images/new.png',
        ),
      ]);

      await tester.tap(find.text('Set as artifact'));
      await tester.pumpAndSettle();

      expect(_nodes.patches.single.$2, <String, Object?>{
        'image_url': 'images/new.png',
      });
      expect(repo.rows['b2']!['promoted'], isTrue);
      expect(repo.rows['b1']!['promoted'], isFalse);
      // 原来的 promoted 格变回可设为产物
      expect(find.text('Set as artifact'), findsOneWidget);
    });

    testWidgets('生成中格的「取消」是整批：tooltip 说明 + 取消该 job', (tester) async {
      await pumpOverlay(tester, [
        row(id: 'b1', slotIndex: 0, status: 'generating', jobId: 'job-9'),
      ]);

      expect(find.byTooltip('Cancel the whole batch'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(_queue.cancelled, <String>['job-9']);
    });

    testWidgets('失败格「重跑此 slot」不带 seed 覆盖', (tester) async {
      await pumpOverlay(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'error',
          errorCode: 'download_failed',
          seed: 999,
        ),
      ]);

      await tester.tap(find.text('Rerun this slot'));
      await tester.pumpAndSettle();

      expect(_gen.seeds, <int?>[null]);
    });
  });

  group('键盘', () {
    testWidgets('↵ 转正当前选中格；←→ 换格', (tester) async {
      await pumpOverlay(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/a.png',
        ),
        row(
          id: 'b2',
          slotIndex: 1,
          status: 'success',
          outputUrl: 'images/b.png',
        ),
        row(
          id: 'b3',
          slotIndex: 2,
          status: 'success',
          outputUrl: 'images/c.png',
        ),
      ]);

      // 初始选中 #1，右移两格到 #3
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_nodes.patches.single.$2, <String, Object?>{
        'image_url': 'images/c.png',
      });
      expect(repo.rows['b3']!['promoted'], isTrue);
    });

    testWidgets('← 从首格回绕到末格', (tester) async {
      await pumpOverlay(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/a.png',
        ),
        row(
          id: 'b2',
          slotIndex: 1,
          status: 'success',
          outputUrl: 'images/b.png',
        ),
      ]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(repo.rows['b2']!['promoted'], isTrue);
    });

    testWidgets('↵ 落在不可转正的格上什么都不做', (tester) async {
      await pumpOverlay(tester, [
        row(id: 'b1', slotIndex: 0, status: 'error', errorCode: 'unknown'),
      ]);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_nodes.patches, isEmpty);
      expect(repo.promotedIds, isEmpty);
    });
  });

  group('对话框', () {
    testWidgets('Esc 关闭浮层', (tester) async {
      await pumpInkApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (BuildContext ctx) => TextButton(
              onPressed: () =>
                  showBatchCompareOverlay(ctx, resultNode: resultNode),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: overridesFor(fourSlots()),
        surfaceSize: const Size(1400, 900),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BatchCompareOverlay), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(BatchCompareOverlay), findsNothing);
    });

    testWidgets('「完成」关闭浮层', (tester) async {
      await pumpInkApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (BuildContext ctx) => TextButton(
              onPressed: () =>
                  showBatchCompareOverlay(ctx, resultNode: resultNode),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: overridesFor(fourSlots()),
        surfaceSize: const Size(1400, 900),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(BatchCompareOverlay), findsNothing);
    });
  });
}
