// CanvasBootstrapController.createSample 行为单测（ON-2b 种子化后）。
//
// FakeUnitOfWork + InMemory* fake 验证：单事务内建 project + canvas + 示例泳道
// + 两镜预填 prompt 的 image config 节点 + 第一镜 → 第二镜一条叙事边；切换
// currentCanvasIdProvider；返回新画布 id。
//
// 两镜 + 叙事边是为了序列标签打开就有东西看：序列视图只认叙事链上的镜（sequence_lens），
// 原来示例只有一个孤立的 config，序列标签是空的。本文件用 buildSequenceLens 直接验这一条。
//
// P7 起这个示例项目还要把原「内置示例」的两张打包成片种成真产物（一镜一张 result 节点
// + 文件落到画布的 images/ 下）——内置示例页就是这么被「并入短剧示例」的。成片是
// best-effort：资产加载 / 写盘失败不许把示例项目整体拖垮。本文件把这几条都钉死。
//
// 泳道风格提示词会拼进发给模型的提示词：写死英文常量（kSampleLaneStylePrompt），不随界面语言变。
//
// 建成后工作库列表（workspaceProjectsProvider）必须失效：画布切换胶囊读它，不刷新就看不到「画布 1」。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/asset_bundle.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_bootstrap_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/sequence/models/sequence_lens.dart';
import 'package:inkframe/features/storyboard/models/sequence_shot.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';

import '../../../_harness/fake_asset_bundle.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';

const SampleSeed _seed = (
  laneLabel: 'Ink Style',
  nodeLabel: 'First Shot',
  nodePrompt: 'A lone boat on a misty river',
  secondNodeLabel: 'Second Shot',
  secondNodePrompt: 'A traveler on a cliff path above the clouds',
);

/// create 必抛 LocalIOError 的节点仓储——驱动种子事务失败路径。
class _FailingNodeRepository extends InMemoryNodeRepository {
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
  }) async {
    throw const LocalIOError(extra: {'op': 'node.create'});
  }
}

/// 某个 config 节点（按 label 找）。
Map<String, Object?> _configNamed(List<Map<String, Object?>> rows, String label) =>
    rows.singleWhere(
      (Map<String, Object?> r) => r['node_role'] == 'config' && r['label'] == label,
    );

void main() {
  late InMemoryProjectRepository projects;
  late InMemoryCanvasRepository canvases;
  late InMemoryStyleLaneRepository lanes;
  late InMemoryNodeRepository nodes;
  late InMemoryEdgeRepository edges;
  late AppPaths paths;
  late ProviderContainer container;

  /// 临时数据根。**必须钉**：示例成片要往 projects/<id>/canvases/<id>/images/
  /// 写文件，不钉就写进用户真实的数据根里去了。
  AppPaths tempPaths() {
    final Directory tmp =
        Directory.systemTemp.createTempSync('ink_sample_boot_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    return DefaultAppPaths.forRoot(tmp);
  }

  List<Override> seals({required FakeAssetBundle bundle}) => <Override>[
        appPathsProvider.overrideWithValue(paths),
        assetBundleProvider.overrideWithValue(bundle),
        // 工作库列表读的两个仓储也钉成同一份内存态：失效之后它重算，读到的就是事务里写下的。
        projectRepositoryProvider.overrideWith((_) async => projects),
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        unitOfWorkProvider.overrideWith(
          (_) async => FakeUnitOfWork(FakeRepositoryScope(
            projects: projects,
            canvas: canvases,
            styleLanes: lanes,
            nodes: nodes,
            edges: edges,
          )),
        ),
      ];

  FakeAssetBundle fullBundle() => FakeAssetBundle(<String, List<int>>{
        for (final String path in kSampleArtifactAssets)
          path: <int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3],
      });

  /// 库里这张画布的节点 + 边，按 UI 的映射读回来，交给序列 lens。
  Future<SequenceLens> lensOf(String canvasId) async => buildSequenceLens(
        nodes: <CanvasNode>[
          for (final Map<String, Object?> r in await nodes.listByCanvas(canvasId))
            CanvasNodeMapping.fromRow(r),
        ],
        edges: <CanvasEdge>[
          for (final Map<String, Object?> r in await edges.listByCanvas(canvasId))
            CanvasEdgeMapping.fromRow(r),
        ],
      );

  setUp(() {
    projects = InMemoryProjectRepository();
    canvases = InMemoryCanvasRepository();
    lanes = InMemoryStyleLaneRepository();
    nodes = InMemoryNodeRepository();
    edges = InMemoryEdgeRepository();
    paths = tempPaths();
    container = ProviderContainer(
      // 默认空 bundle：资产加载失败 ⇒ 不种成片，只剩两镜 config + 叙事边。
      overrides: seals(bundle: FakeAssetBundle(const <String, List<int>>{})),
    );
    addTearDown(container.dispose);
  });

  test('createSample 单事务建 project+canvas+泳道+两镜预填节点并切换 currentCanvasId',
      () async {
    expect(container.read(currentCanvasIdProvider), isNull);

    final controller = container.read(canvasBootstrapControllerProvider);
    final canvasId = await controller.createSample(
      projectName: 'Sample Project',
      canvasName: 'Sample Canvas',
      seed: _seed,
    );

    expect(canvasId, isNotEmpty);
    expect(container.read(currentCanvasIdProvider), canvasId);

    final projectRows = await projects.listAll();
    expect(projectRows, hasLength(1));
    expect(projectRows.single['name'], 'Sample Project');

    final projectId = projectRows.single['id'] as String;
    final canvasRows = await canvases.listByProject(projectId);
    expect(canvasRows, hasLength(1));
    expect(canvasRows.single['id'], canvasId);

    // 示例泳道：label 来自 seed（本地化），风格提示词是英文常量（发给模型的，不随界面语言变）
    final laneRows = await lanes.listByCanvas(canvasId);
    expect(laneRows, hasLength(1));
    expect(laneRows.single['label'], _seed.laneLabel);
    expect(laneRows.single['style_prompt'], kSampleLaneStylePrompt);
    // 带厚按示例常量建：要装下上下两镜与各自右侧的成片
    expect(laneRows.single['size'], kSampleLaneSize);

    // 两镜预填节点：image config、挂进泳道、prompt 预填、上下排开
    final nodeRows = await nodes.listByCanvas(canvasId);
    expect(nodeRows, hasLength(kSampleShotCount));
    final first = _configNamed(nodeRows, _seed.nodeLabel);
    final second = _configNamed(nodeRows, _seed.secondNodeLabel);
    for (final Map<String, Object?> node in <Map<String, Object?>>[first, second]) {
      expect(node['type'], 'image');
      expect(node['node_role'], 'config');
      expect(node['lane_id'], laneRows.single['id']);
    }
    expect((first['type_config'] as Map<String, Object?>)['prompt'], _seed.nodePrompt);
    expect((second['type_config'] as Map<String, Object?>)['prompt'], _seed.secondNodePrompt);
    expect(first['position_x'], kSampleNodePosition.dx);
    expect(first['position_y'], kSampleNodePosition.dy);
    expect(second['position_x'], sampleShotPosition(1).dx);
    expect(second['position_y'], sampleShotPosition(1).dy);
    // 第一镜整体落在默认泳道厚 400 的带内（首启视野）：横向带 = 世界 Y ∈ [0,400)；
    // X 轴同断（direction 切 vertical 时带变 X ∈ [0,400)，节点仍整体落带）。
    final y = first['position_y'] as double;
    final h = first['height'] as double;
    expect(y, greaterThanOrEqualTo(0));
    expect(y + h, lessThanOrEqualTo(400));
    final x = first['position_x'] as double;
    final w = first['width'] as double;
    expect(x, greaterThanOrEqualTo(0));
    expect(x + w, lessThanOrEqualTo(400));

    // 叙事边：第一镜 → 第二镜，恰好一条
    final edgeRows = await edges.listByCanvas(canvasId);
    expect(edgeRows, hasLength(1));
    expect(edgeRows.single['edge_type'], 'narrative');
    expect(edgeRows.single['source_node_id'], first['id']);
    expect(edgeRows.single['target_node_id'], second['id']);
  });

  group('序列标签不空（示例项目一打开就有两镜可看）', () {
    test('有成片：序列是两镜图像，顺序 = 叙事链', () async {
      final ProviderContainer c =
          ProviderContainer(overrides: seals(bundle: fullBundle()));
      addTearDown(c.dispose);

      final String canvasId = await c
          .read(canvasBootstrapControllerProvider)
          .createSample(projectName: 'P', canvasName: 'C', seed: _seed);

      final SequenceLens lens = await lensOf(canvasId);
      expect(lens.shots, hasLength(kSampleShotCount));
      expect(lens.shots.map((SequenceShot s) => s.label).toList(),
          <String>[_seed.nodeLabel, _seed.secondNodeLabel]);
      expect(
        lens.shots.map((SequenceShot s) => s.kind).toSet(),
        <SequenceArtifactKind>{SequenceArtifactKind.image},
        reason: '每镜都借到了自己名下那张成片',
      );
      expect(lens.unchainedCount, 0, reason: '两镜都在链上，没有「未入链」');
    });

    test('资产加载失败（没有成片）：序列仍是两镜占位，不是空的', () async {
      final String canvasId = await container
          .read(canvasBootstrapControllerProvider)
          .createSample(projectName: 'P', canvasName: 'C', seed: _seed);

      final SequenceLens lens = await lensOf(canvasId);
      expect(lens.shots, hasLength(kSampleShotCount));
      expect(lens.placeholderCount, kSampleShotCount);
    });
  });

  group('打包成片（原「内置示例」并入短剧示例）', () {
    test('两张成片一镜一张：result 挂在各自那一镜下，文件写进画布 images/ 下', () async {
      final FakeAssetBundle bundle = fullBundle();
      final ProviderContainer c =
          ProviderContainer(overrides: seals(bundle: bundle));
      addTearDown(c.dispose);

      final String canvasId = await c
          .read(canvasBootstrapControllerProvider)
          .createSample(
            projectName: 'P',
            canvasName: 'C',
            seed: _seed,
          );

      final String projectId =
          (await projects.listAll()).single['id'] as String;
      final List<Map<String, Object?>> rows =
          await nodes.listByCanvas(canvasId);
      final Map<String, Object?> first = _configNamed(rows, _seed.nodeLabel);
      final Map<String, Object?> second = _configNamed(rows, _seed.secondNodeLabel);
      Map<String, Object?> resultFor(String imageUrl) => rows.singleWhere(
            (Map<String, Object?> r) =>
                r['node_role'] == 'result' &&
                (r['type_config'] as Map<String, Object?>)['image_url'] ==
                    imageUrl,
          );

      expect(bundle.requested, kSampleArtifactAssets);
      expect(
        rows.where((Map<String, Object?> r) => r['node_role'] == 'result'),
        hasLength(kSampleArtifactAssets.length),
      );
      expect(resultFor('images/sample-1.jpg')['source_node_id'], first['id'],
          reason: '第一张成片归第一镜');
      expect(resultFor('images/sample-2.jpg')['source_node_id'], second['id'],
          reason: '第二张成片归第二镜');
      for (final Map<String, Object?> r in rows.where(
          (Map<String, Object?> r) => r['node_role'] == 'result')) {
        expect(r['type'], 'image');
        expect(
          r['lane_id'],
          first['lane_id'],
          reason: '产物与 config 同道（与生成路径一致：同道才同一套坐标）',
        );
        final String rel = (r['type_config'] as Map<String, Object?>)['image_url']! as String;
        expect(rel, startsWith('images/'));
        final File f = File(
          '${paths.projects.path}/$projectId/canvases/$canvasId/$rel',
        );
        expect(f.existsSync(), isTrue, reason: '节点指向的文件必须真的在盘上：$rel');
        expect(f.lengthSync(), greaterThan(0));
      }
    });

    test('每镜的成片落在它 config 卡右侧第 0 格：与各自那一镜顶对齐', () async {
      final ProviderContainer c =
          ProviderContainer(overrides: seals(bundle: fullBundle()));
      addTearDown(c.dispose);

      final String canvasId = await c
          .read(canvasBootstrapControllerProvider)
          .createSample(projectName: 'P', canvasName: 'C', seed: _seed);

      final List<Map<String, Object?>> rows =
          await nodes.listByCanvas(canvasId);
      Map<String, Object?> resultFor(String imageUrl) => rows.singleWhere(
            (Map<String, Object?> r) =>
                r['node_role'] == 'result' &&
                (r['type_config'] as Map<String, Object?>)['image_url'] ==
                    imageUrl,
          );
      final Map<String, Object?> first = resultFor('images/sample-1.jpg');
      final Map<String, Object?> second = resultFor('images/sample-2.jpg');

      // 第一镜 config 在 (120, 90)，第二镜在它下面一格 (120, 329)：
      // 列 x = 120 + 卡宽 224 + 列距 64；行距 = 卡高 191 + 48。
      expect(first['position_x'], 408.0);
      expect(first['position_y'], 90.0);
      expect(second['position_x'], 408.0, reason: '同一列');
      expect(second['position_y'], 329.0, reason: '与第二镜 config 顶对齐');
    });

    test('资产加载失败：示例项目照样建成，只是没有成片节点', () async {
      // setUp 的默认容器就是空 bundle。
      final String canvasId = await container
          .read(canvasBootstrapControllerProvider)
          .createSample(projectName: 'P', canvasName: 'C', seed: _seed);

      final List<Map<String, Object?>> rows =
          await nodes.listByCanvas(canvasId);
      expect(rows, hasLength(kSampleShotCount));
      expect(rows.map((Map<String, Object?> r) => r['node_role']).toSet(), <String>{'config'});
      expect(container.read(currentCanvasIdProvider), canvasId);
    });
  });

  test('建成后工作库列表失效：已有订阅者（画布切换胶囊）当场看到新项目和它的画布', () async {
    // 胶囊 watch 着 workspaceProjectsProvider：autoDispose + 有人订阅 ⇒ 不失效就一直是建之前那份空列表。
    final ProviderSubscription<AsyncValue<List<ProjectWithCanvases>>> sub =
        container.listen(workspaceProjectsProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(workspaceProjectsProvider.future), isEmpty);

    final String canvasId = await container
        .read(canvasBootstrapControllerProvider)
        .createSample(projectName: 'Sample Project', canvasName: 'Canvas 1', seed: _seed);

    final List<ProjectWithCanvases> list =
        await container.read(workspaceProjectsProvider.future);
    expect(list, hasLength(1), reason: '列表没失效 ⇒ 还是建之前那份空列表');
    expect(list.single.name, 'Sample Project');
    expect(list.single.canvases.map((CanvasRef c) => c.id), <String>[canvasId]);
    expect(list.single.canvases.single.name, 'Canvas 1');
  });

  test('种子事务任一步失败：rethrow 且 currentCanvasId 不切换、prefs 不写', () async {
    // FakeUnitOfWork 不回滚（真回滚语义由真 PG transaction_integration_test 背书）；
    // 本例锁的是控制器自己的不变量：state/prefs 写在 uow.run 之后，失败即全不动。
    final failing = ProviderContainer(
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        assetBundleProvider
            .overrideWithValue(FakeAssetBundle(const <String, List<int>>{})),
        unitOfWorkProvider.overrideWith(
          (_) async => FakeUnitOfWork(FakeRepositoryScope(
            projects: projects,
            canvas: canvases,
            styleLanes: lanes,
            nodes: _FailingNodeRepository(),
            edges: edges,
          )),
        ),
      ],
    );
    addTearDown(failing.dispose);

    final controller = failing.read(canvasBootstrapControllerProvider);
    await expectLater(
      controller.createSample(
        projectName: 'P',
        canvasName: 'C',
        seed: _seed,
      ),
      throwsA(isA<LocalIOError>()),
    );
    expect(failing.read(currentCanvasIdProvider), isNull);
  });

  test('再次 createSample 累加而不覆盖，currentCanvasId 指向最后一个', () async {
    final controller = container.read(canvasBootstrapControllerProvider);
    final first = await controller.createSample(
      projectName: 'P1',
      canvasName: 'C1',
      seed: _seed,
    );
    final second = await controller.createSample(
      projectName: 'P2',
      canvasName: 'C2',
      seed: _seed,
    );

    expect(first, isNot(second));
    expect(await projects.listAll(), hasLength(2));
    expect(container.read(currentCanvasIdProvider), second);
  });
}
