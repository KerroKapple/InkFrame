// BatchResultsGrid：
//   - GAP-4 既有回归：失败 slot 的本地化文案 + 整块 Tooltip（errorCode wire 容错）
//   - P4 接线：真实比例图区 / seed 露出 / 四态动作词 / 动作真的落库
//   - 缩略图渲染（BatchSlotImage）：resultNode 必须带 projectId/canvasId 才会走到
//     resolve + Image.file 那段；缺任一项 BatchSlotImage 直接 early-return，
//     整块缩略图代码零覆盖（把 `url.isEmpty` 写反成 `isNotEmpty` 也照样全绿）。
import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:inkframe/features/canvas/widgets/batch_results_grid.dart';
import 'package:inkframe/features/canvas/widgets/image_result_inspector.dart';
import 'package:inkframe/features/generation/generation_controller.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_unit_of_work.dart';
import '../../../_harness/test_app.dart';

const _kContentPolicyText =
    "The provider's content policy rejected this prompt. Adjust the prompt and try again.";
const _kUnknownText = 'An unknown error occurred.';
const _kEmDash = '—';

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
  String id = 'b1',
  int slotIndex = 0,
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
  // 孤儿 result：溯源 config 节点已不在，重跑整条路走不通。
  const orphanNode = CanvasNode(
    id: 'n1',
    label: 'Shot 05',
    type: CanvasNodeType.image,
    role: NodeRole.result,
    projectId: 'p1',
    canvasId: 'c1',
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
    pngDir = Directory.systemTemp.createTempSync('batch_grid_');
    pngFile = File('${pngDir.path}/a.png')..writeAsBytesSync(_kPngBytes);
  });
  tearDownAll(() {
    if (pngDir.existsSync()) pngDir.deleteSync(recursive: true);
  });

  Future<void> pumpGrid(
    WidgetTester tester,
    List<Map<String, Object?>> rows, {
    CanvasNode node = resultNode,
    Size size = const Size(400, 900),
    String? failResolveOn,
  }) async {
    await pumpInkApp(
      tester,
      Scaffold(body: BatchResultsGrid(resultNode: node)),
      overrides: overridesFor(rows, failResolveOn: failResolveOn),
      surfaceSize: size,
    );
    await tester.pumpAndSettle();
  }

  group('失败 slot 可读化（GAP-4 回归）', () {
    testWidgets('已知 errorCode wire → Tooltip + danger 文案', (tester) async {
      await pumpGrid(tester, [
        row(status: 'error', errorCode: 'content_policy'),
      ]);
      expect(find.text(_kContentPolicyText), findsOneWidget);
      expect(find.byTooltip(_kContentPolicyText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('未知 wire → 回退 errorUnknown，不抛异常', (tester) async {
      await pumpGrid(tester, [
        row(status: 'error', errorCode: 'totally_bogus_wire'),
      ]);
      expect(find.text(_kUnknownText), findsOneWidget);
      expect(find.byTooltip(_kUnknownText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('errorCode 缺失 → 回退 errorUnknown', (tester) async {
      await pumpGrid(tester, [row(status: 'error')]);
      expect(find.text(_kUnknownText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('success slot → 格内无失败文案 / 无失败 Tooltip', (tester) async {
      await pumpGrid(tester, [
        row(status: 'success', outputUrl: 'images/a.png'),
      ]);
      expect(find.text(_kContentPolicyText), findsNothing);
      expect(find.text(_kUnknownText), findsNothing);
      expect(find.byTooltip(_kContentPolicyText), findsNothing);
      expect(find.byTooltip(_kUnknownText), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('errorCode 原串不在检查器格内露出（只在对比浮层）', (tester) async {
      await pumpGrid(tester, [
        row(status: 'error', errorCode: 'content_policy'),
      ]);
      expect(find.text('content_policy'), findsNothing);
    });
  });

  group('图区比例', () {
    testWidgets('有真实宽高 → 用真实比例', (tester) async {
      await pumpGrid(tester, [
        row(
          status: 'success',
          outputUrl: 'images/a.png',
          width: 768,
          height: 1024,
        ),
      ]);
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        0.75,
      );
    });

    testWidgets('缺宽高 → 回落 16:9（不再是正方形）', (tester) async {
      await pumpGrid(tester, [
        row(status: 'success', outputUrl: 'images/a.png'),
      ]);
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        16 / 9,
      );
    });
  });

  // 这一组钉的是 BatchSlotImage 整块：既有用例的 resultNode 没有 projectId，
  // 所以 resolve + Image.file 一行都没跑过——把 `url.isEmpty` 写反成
  // `url.isNotEmpty`（出图的格全部退回透明）以前是全绿的。
  group('缩略图渲染（BatchSlotImage）', () {
    testWidgets('success / promoted 两格真的解出 Image.file，且带节点路径去 resolve', (
      tester,
    ) async {
      await pumpGrid(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/a.png',
          promoted: true,
        ),
        row(
          id: 'b2',
          slotIndex: 1,
          status: 'success',
          outputUrl: 'images/b.png',
        ),
        row(id: 'b3', slotIndex: 2, status: 'error', errorCode: 'unknown'),
        row(id: 'b4', slotIndex: 3, status: 'generating'),
      ]);

      // 出图的两格各一张；失败 / 生成中不进 resolve。
      expect(find.byType(Image), findsNWidgets(2));
      expect(
        _resolver.calls.map((c) => c.$3).toSet(),
        <String>{'images/a.png', 'images/b.png'},
      );
      // 传进 resolve 的项目/画布 id 来自节点本身，不是写死的常量。
      expect(_resolver.calls.map((c) => c.$1).toSet(), <String>{'p1'});
      expect(_resolver.calls.map((c) => c.$2).toSet(), <String>{'c1'});
      expect(tester.takeException(), isNull);
    });

    testWidgets('cacheWidth = 网格解码宽 180 × devicePixelRatio（LB-23）', (
      tester,
    ) async {
      // dpr 钉成 2：期望值算得出来，且「忘了乘 dpr」会立刻翻车。
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpGrid(tester, [
        row(status: 'success', outputUrl: 'images/a.png'),
      ]);

      final Image img = tester.widget<Image>(find.byType(Image));
      expect(
        img.image,
        isA<ResizeImage>().having((r) => r.width, 'cacheWidth', 360),
        reason: 'LB-23：按 2 列格宽上限 180 逻辑 px × dpr 缩略解码',
      );
    });

    testWidgets('resolve 抛 PathSecurityError → broken_image 占位，不崩', (
      tester,
    ) async {
      await pumpGrid(
        tester,
        [row(status: 'success', outputUrl: '../../../etc/passwd')],
        failResolveOn: '../../../etc/passwd',
      );

      // 越权路径是 build 里同步抛的：接住画坏图占位，整个网格照常。
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Promote'), findsOneWidget, reason: '坏图不影响动作词');
      expect(tester.takeException(), isNull);
    });

    testWidgets('节点缺 projectId/canvasId → 不画图、不调 resolve、不报错', (tester) async {
      await pumpGrid(
        tester,
        [row(status: 'success', outputUrl: 'images/a.png')],
        node: noPathNode,
      );

      expect(find.byType(Image), findsNothing);
      expect(_resolver.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('序号徽标', () {
    testWidgets('每格左上角是短序号 #N（全写的 slot #N 是浮层的写法）', (tester) async {
      await pumpGrid(tester, [
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
        row(id: 'b3', slotIndex: 2, status: 'error', errorCode: 'unknown'),
        row(id: 'b4', slotIndex: 3, status: 'generating'),
      ]);

      // slotIndex 0-based，露出的是 1-based——差一就在这里翻车。
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('#0'), findsNothing);
      expect(find.text('#5'), findsNothing);
      // 检查器内联格宽不到 140，序号必须短；'slot #1' 只属于浮层。
      expect(find.text('slot #1'), findsNothing);
    });
  });

  group('seed 露出', () {
    testWidgets('有 seed → 标出数值；无 seed → em dash', (tester) async {
      await pumpGrid(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/a.png',
          seed: 41207,
        ),
        row(id: 'b2', slotIndex: 1, status: 'generating'),
      ]);
      expect(find.text('41207'), findsOneWidget);
      expect(find.text(_kEmDash), findsOneWidget);
    });
  });

  group('标题行', () {
    testWidgets('slot 数 + 「对比」入口；点开浮层', (tester) async {
      await pumpGrid(
        tester,
        [
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
        ],
        size: const Size(1400, 900),
      );
      expect(find.text('Batch results'), findsOneWidget);
      expect(find.text('2 slot'), findsOneWidget);
      expect(find.byTooltip('Open full-size comparison'), findsOneWidget);

      await tester.tap(find.text('Compare'));
      await tester.pumpAndSettle();
      expect(find.byType(BatchCompareOverlay), findsOneWidget);
    });
  });

  group('四态动作词', () {
    testWidgets('success=转正 / promoted=当前+已选徽标 / error=重跑 / generating=取消', (
      tester,
    ) async {
      await pumpGrid(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/a.png',
          promoted: true,
        ),
        row(
          id: 'b2',
          slotIndex: 1,
          status: 'success',
          outputUrl: 'images/b.png',
        ),
        row(id: 'b3', slotIndex: 2, status: 'error', errorCode: 'unknown'),
        row(id: 'b4', slotIndex: 3, status: 'generating'),
      ]);

      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Chosen'), findsOneWidget);
      expect(find.text('Promote'), findsOneWidget);
      expect(find.text('Rerun'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Generating'), findsOneWidget);
      // 取消是整批，不是单格——tooltip 必须说清楚。
      expect(find.byTooltip('Cancel the whole batch'), findsOneWidget);
    });

    testWidgets('「当前」不是按钮：不挂手势', (tester) async {
      await pumpGrid(tester, [
        row(
          status: 'success',
          outputUrl: 'images/a.png',
          promoted: true,
        ),
      ]);
      expect(
        find.ancestor(
          of: find.text('Current'),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });

  group('动作落地', () {
    testWidgets('点「转正」→ 节点产物换图 + 本行 promoted + 旧行清零', (tester) async {
      await pumpGrid(tester, [
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

      // 转正前「当前」在左格（slot #1），转正后应挪到右格（slot #2）。
      final double beforeX = tester.getCenter(find.text('Current')).dx;

      await tester.tap(find.text('Promote'));
      await tester.pumpAndSettle();

      expect(_nodes.patches.single.$1, 'n1');
      expect(_nodes.patches.single.$2, <String, Object?>{
        'image_url': 'images/new.png',
      });
      expect(repo.rows['b2']!['promoted'], isTrue);
      expect(repo.rows['b1']!['promoted'], isFalse);
      // 网格就地翻面：徽标与「当前」跟着换格，旧格回到可转正。
      expect(find.text('Chosen'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Promote'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Current')).dx,
        greaterThan(beforeX),
      );
    });

    testWidgets('点「重跑」→ 从溯源 config 节点再发一次，不带 seed 覆盖', (tester) async {
      await pumpGrid(tester, [
        row(status: 'error', errorCode: 'download_failed', seed: 777),
      ]);

      await tester.tap(find.text('Rerun'));
      await tester.pumpAndSettle();

      expect(_gen.submitted, <String>['s1']);
      expect(_gen.seeds, <int?>[null]);
    });

    testWidgets('点「取消」→ 取消整个 job', (tester) async {
      await pumpGrid(tester, [
        row(status: 'generating', jobId: 'job-77'),
      ]);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(_queue.cancelled, <String>['job-77']);
    });

    testWidgets('「重跑失败 slot」只在有失败格时出现，点一次只发一批', (tester) async {
      await pumpGrid(tester, [
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/a.png',
        ),
        row(id: 'b2', slotIndex: 1, status: 'error', errorCode: 'unknown'),
        row(id: 'b3', slotIndex: 2, status: 'cancelled'),
      ]);

      expect(find.text('Rerun failed slots'), findsOneWidget);
      await tester.tap(find.text('Rerun failed slots'));
      await tester.pumpAndSettle();

      // 两个失败格，但只发一次：一次重跑就是一整批新图，循环发只会扣 k 倍额度。
      expect(_gen.submitted, <String>['s1']);
    });

    testWidgets('全成功时不画「重跑失败 slot」', (tester) async {
      await pumpGrid(tester, [
        row(status: 'success', outputUrl: 'images/a.png'),
      ]);
      expect(find.text('Rerun failed slots'), findsNothing);
    });
  });

  group('孤儿 result（无溯源 config 节点）', () {
    testWidgets('重跑整条路走不通 → 不画重跑动作词、不画批量重跑按钮', (tester) async {
      await pumpGrid(
        tester,
        [row(status: 'error', errorCode: 'unknown')],
        node: orphanNode,
      );
      expect(find.text('Rerun'), findsNothing);
      expect(find.text('Rerun failed slots'), findsNothing);
      // 失败文案仍在——只是没得重跑
      expect(find.text(_kUnknownText), findsOneWidget);
    });
  });

  testWidgets('真实检查器宽度（320 面板）下四格 + 按钮 + 脚注不溢出', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageResultInspector(node: resultNode)),
      overrides: overridesFor([
        row(
          id: 'b1',
          slotIndex: 0,
          status: 'success',
          outputUrl: 'images/a.png',
          seed: 41207,
          promoted: true,
        ),
        row(
          id: 'b2',
          slotIndex: 1,
          status: 'success',
          outputUrl: 'images/b.png',
          seed: 88316,
          width: 768,
          height: 1024,
        ),
        row(
          id: 'b3',
          slotIndex: 2,
          status: 'error',
          errorCode: 'content_policy',
        ),
        row(id: 'b4', slotIndex: 3, status: 'generating'),
      ]),
      surfaceSize: const Size(420, 900),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BatchResultsGrid), findsOneWidget);
    expect(find.text('4 slot'), findsOneWidget);
    // RenderFlex overflow 会以异常形式抛出——这条就是宽度回归。
    expect(tester.takeException(), isNull);
  });

  testWidgets('转正说明脚注常驻', (tester) async {
    await pumpGrid(tester, [
      row(status: 'success', outputUrl: 'images/a.png'),
    ]);
    expect(
      find.textContaining("Promoting writes that slot to the node's artifact"),
      findsOneWidget,
    );
  });
}
