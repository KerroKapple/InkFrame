// BatchCompareOverlay：足尺并排对比浮层。
//   - errorCode 原串只在这里露出
//   - ⎘「以该种子重跑」的启用/禁用与透传
//   - 「叠加对比」是禁用标签（不做清单），不是可点按钮
//   - ←→ 切换选中格（选中环落在哪一格）、↵ 转正当前格、Esc 关闭
//   - 生成中格的「Generating N%」取自 batchJobProgressProvider
//   - 缩略图（BatchSlotImage）：resultNode 必须带 projectId/canvasId 才会走到
//     resolve + Image.file 那段；缺任一项整块缩略图代码零覆盖
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/batch_compare_overlay.dart';
import 'package:inkframe/features/generation/generation_controller.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';

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

/// 固定列表的 jobsRegistry 桩——生成中格的进度条读它。
class _StubRegistry extends JobsRegistry {
  _StubRegistry(this.jobs);

  final List<JobState> jobs;

  @override
  List<JobState> build() => jobs;
}

/// 1×1 PNG——让 Image.file 指向真实存在的文件，避免测试收尾后才冒出的异步读失败。
const List<int> _kPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// 可控 FileResolverService：记录每次 resolve 的入参（用来钉「传进去的确实是
/// 节点的 projectId/canvasId + slot 的 outputUrl」），并把任意相对路径映射到同
/// 一张真实 PNG；[failOn] 命中的相对路径改抛 PathSecurityError。
class _RecordingResolver implements FileResolverService {
  _RecordingResolver(this.file, {this.failOn});

  final File file;
  final String? failOn;
  final List<(String, String, String)> calls = <(String, String, String)>[];

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) {
    calls.add((projectId, canvasId, relativePath));
    if (relativePath == failOn) {
      throw PathSecurityError('escapes canvas root: $relativePath');
    }
    return file;
  }

  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) => throw UnimplementedError();

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) => throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      throw UnimplementedError();
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
late _RecordingResolver _resolver;
late File pngFile;

List<Override> overridesFor(
  List<Map<String, Object?>> rows, {
  String? failResolveOn,
  List<JobState>? jobs,
}) {
  repo = FakeBatchResultRepo(<String, Map<String, Object?>>{
    for (final r in rows) r['id']! as String: r,
  });
  _nodes = _FakeNodeRepo();
  _gen = _FakeGen();
  _queue = _FakeQueue();
  _resolver = _RecordingResolver(pngFile, failOn: failResolveOn);
  return <Override>[
    fileResolverServiceProvider.overrideWithValue(_resolver),
    if (jobs != null)
      jobsRegistryProvider.overrideWith(() => _StubRegistry(jobs)),
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
  // projectId/canvasId 是缩略图那条路的开关：没有它们 BatchSlotImage 一律
  // early-return，resolve + Image.file 整段代码在测试里从没被执行过。
  const resultNode = CanvasNode(
    id: 'n1',
    label: 'Shot 05',
    type: CanvasNodeType.image,
    role: NodeRole.result,
    projectId: 'p1',
    canvasId: 'c1',
    sourceNodeId: 's1',
  );
  // 落盘路径拼不出来的节点（单测/历史数据允许为空）——图区应静默留白。
  const noPathNode = CanvasNode(
    id: 'n1',
    label: 'Shot 05',
    type: CanvasNodeType.image,
    role: NodeRole.result,
    sourceNodeId: 's1',
  );

  late Directory pngDir;
  setUpAll(() {
    pngDir = Directory.systemTemp.createTempSync('batch_overlay_');
    pngFile = File('${pngDir.path}/a.png')..writeAsBytesSync(_kPngBytes);
  });
  tearDownAll(() {
    if (pngDir.existsSync()) pngDir.deleteSync(recursive: true);
  });

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
    List<Map<String, Object?>> rows, {
    CanvasNode node = resultNode,
    String? failResolveOn,
    List<JobState>? jobs,
  }) async {
    await pumpInkApp(
      tester,
      Scaffold(body: Center(child: BatchCompareOverlay(resultNode: node))),
      overrides: overridesFor(rows, failResolveOn: failResolveOn, jobs: jobs),
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

      // 稿上浮层写全「slot #1」，检查器内联格才是短的「#1」。
      expect(find.text('slot #1'), findsOneWidget);
      expect(find.text('slot #4'), findsOneWidget);
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

  // 这一组钉的是 BatchSlotImage 整块：既有用例的 resultNode 没有 projectId，
  // 所以 resolve + Image.file 一行都没跑过——把 `url.isEmpty` 写反成
  // `url.isNotEmpty`（出图的格全部退回透明）以前是全绿的。
  group('缩略图渲染（BatchSlotImage）', () {
    testWidgets('success / promoted 两格真的解出 Image.file，且带节点路径去 resolve', (
      tester,
    ) async {
      await pumpOverlay(tester, fourSlots());

      // 四格里只有 b1/b2 出图；error / generating 不进 resolve。
      expect(find.byType(Image), findsNWidgets(2));
      expect(
        _resolver.calls.map((c) => c.$3).toSet(),
        <String>{'images/a.png', 'images/b.png'},
      );
      expect(_resolver.calls.map((c) => c.$1).toSet(), <String>{'p1'});
      expect(_resolver.calls.map((c) => c.$2).toSet(), <String>{'c1'});
      expect(tester.takeException(), isNull);
    });

    testWidgets('cacheWidth = 浮层解码宽 540 × devicePixelRatio（LB-23）', (
      tester,
    ) async {
      // dpr 钉成 2：期望值算得出来，且「忘了乘 dpr」会立刻翻车。
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpOverlay(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/a.png',
        ),
      ]);

      final Image img = tester.widget<Image>(find.byType(Image));
      expect(
        img.image,
        isA<ResizeImage>().having((r) => r.width, 'cacheWidth', 1080),
        reason: '浮层是足尺对比，解码宽 540 逻辑 px × dpr——比网格那份大',
      );
    });

    testWidgets('resolve 抛 PathSecurityError → broken_image 占位，不崩', (
      tester,
    ) async {
      await pumpOverlay(
        tester,
        [
          row(
            id: 'b1',
            slotIndex: 0,
            status: 'success',
            outputUrl: '../../../etc/passwd',
          ),
        ],
        failResolveOn: '../../../etc/passwd',
      );

      // 越权路径是 build 里同步抛的：接住画坏图占位，浮层其余部分照常。
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Set as artifact'), findsOneWidget, reason: '坏图不影响主按钮');
      expect(tester.takeException(), isNull);
    });

    testWidgets('节点缺 projectId/canvasId → 不画图、不调 resolve、不报错', (tester) async {
      await pumpOverlay(
        tester,
        [
          row(
            id: 'b1',
            slotIndex: 0,
            status: 'success',
            outputUrl: 'images/a.png',
          ),
        ],
        node: noPathNode,
      );

      expect(find.byType(Image), findsNothing);
      expect(_resolver.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('生成中进度', () {
    testWidgets('注册表里有本 job → 「Generating 40%」', (tester) async {
      await pumpOverlay(
        tester,
        [row(id: 'b1', slotIndex: 0, status: 'generating', jobId: 'j-gen')],
        jobs: const <JobState>[
          // 另一条 job 先放着：取错 job 会读成 90%。
          JobState.running(
            jobId: 'j-other',
            providerId: 'p',
            canvasId: 'cv',
            progress: 0.9,
          ),
          JobState.running(
            jobId: 'j-gen',
            providerId: 'p',
            canvasId: 'cv',
            progress: 0.4,
          ),
        ],
      );

      expect(find.text('Generating 40%'), findsOneWidget);
      expect(find.text('Generating 90%'), findsNothing);
      // 有进度时不再画裸的「Generating」——百分比就是那行字。
      expect(find.text('Generating'), findsNothing);
    });

    testWidgets('注册表里没有本 job（重启后读库的历史 slot）→ 只写「Generating」', (
      tester,
    ) async {
      await pumpOverlay(
        tester,
        [row(id: 'b1', slotIndex: 0, status: 'generating', jobId: 'j-gen')],
        jobs: const <JobState>[
          JobState.running(
            jobId: 'j-other',
            providerId: 'p',
            canvasId: 'cv',
            progress: 0.9,
          ),
        ],
      );

      expect(find.text('Generating'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('选中环', () {
    testWidgets('初始落在首格；→ 之后挪到第 2 格，首格不再有环', (tester) async {
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

      Rect ring() => tester.getRect(find.byKey(kBatchSlotSelectedRingKey));
      Offset badge(int n) => tester.getCenter(find.text('slot #$n'));

      // 环只有一个——每格都画就等于没有选中态。
      expect(find.byKey(kBatchSlotSelectedRingKey), findsOneWidget);
      expect(ring().contains(badge(1)), isTrue, reason: '初始选中首格');
      expect(ring().contains(badge(2)), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(find.byKey(kBatchSlotSelectedRingKey), findsOneWidget);
      expect(ring().contains(badge(2)), isTrue, reason: '→ 之后选中第 2 格');
      expect(ring().contains(badge(1)), isFalse, reason: '首格的环必须撤掉');
      expect(ring().contains(badge(3)), isFalse);
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

      // 可点时 tooltip 讲的是代价：一次重跑 = 整批重来、落新节点。
      expect(find.byTooltip('One rerun re-runs the whole batch and the new images land on a new node; a single slot cannot be re-run on its own.'), findsOneWidget);
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
      expect(find.byTooltip('One rerun re-runs the whole batch and the new images land on a new node; a single slot cannot be re-run on its own.'), findsNothing);
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
