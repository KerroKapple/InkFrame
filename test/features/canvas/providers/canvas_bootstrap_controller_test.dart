// CanvasBootstrapController.createSample 行为单测（ON-2b 种子化后）。
//
// FakeUnitOfWork + InMemory* fake 验证：单事务内建 project + canvas + 示例泳道
// + 预填 prompt 的 image config 节点；切换 currentCanvasIdProvider；返回新画布 id。
//
// P7 起这个示例项目还要把原「内置示例」的两张打包成片种成真产物（config 节点
// 名下两个 result 节点 + 文件落到画布的 images/ 下）——内置示例页就是这么被
// 「并入短剧示例」的。成片是 best-effort：资产加载 / 写盘失败不许把示例项目
// 整体拖垮。本文件把这几条都钉死。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/asset_bundle.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/providers/canvas_bootstrap_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';

import '../../../_harness/fake_asset_bundle.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';

const _seed = (
  laneLabel: 'Ink Style',
  laneStylePrompt: 'ink painting, soft brush',
  nodeLabel: 'First Shot',
  nodePrompt: 'A lone boat on a misty river',
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

void main() {
  late InMemoryProjectRepository projects;
  late InMemoryCanvasRepository canvases;
  late InMemoryStyleLaneRepository lanes;
  late InMemoryNodeRepository nodes;
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
        unitOfWorkProvider.overrideWith(
          (_) async => FakeUnitOfWork(FakeRepositoryScope(
            projects: projects,
            canvas: canvases,
            styleLanes: lanes,
            nodes: nodes,
          )),
        ),
      ];

  setUp(() {
    projects = InMemoryProjectRepository();
    canvases = InMemoryCanvasRepository();
    lanes = InMemoryStyleLaneRepository();
    nodes = InMemoryNodeRepository();
    paths = tempPaths();
    container = ProviderContainer(
      // 默认空 bundle：资产加载失败 ⇒ 不种成片，老用例的「只有一个节点」语义不变。
      overrides: seals(bundle: FakeAssetBundle(const <String, List<int>>{})),
    );
    addTearDown(container.dispose);
  });

  test('createSample 单事务建 project+canvas+泳道+预填节点并切换 currentCanvasId',
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

    // 示例泳道：label / stylePrompt 来自 seed
    final laneRows = await lanes.listByCanvas(canvasId);
    expect(laneRows, hasLength(1));
    expect(laneRows.single['label'], _seed.laneLabel);
    expect(laneRows.single['style_prompt'], _seed.laneStylePrompt);

    // 预填节点：image config、挂进泳道、prompt 预填、落在泳道带内
    final nodeRows = await nodes.listByCanvas(canvasId);
    expect(nodeRows, hasLength(1));
    final node = nodeRows.single;
    expect(node['type'], 'image');
    expect(node['node_role'], 'config');
    expect(node['lane_id'], laneRows.single['id']);
    expect(node['label'], _seed.nodeLabel);
    final typeConfig = node['type_config'] as Map<String, Object?>;
    expect(typeConfig['prompt'], _seed.nodePrompt);
    // 默认泳道厚 400（horizontal 带 = 世界 Y ∈ [0,400)）：节点整体落带内；
    // X 轴同断（direction 切 vertical 时带变 X ∈ [0,400)，节点仍整体落带）。
    final y = node['position_y'] as double;
    final h = node['height'] as double;
    expect(y, greaterThanOrEqualTo(0));
    expect(y + h, lessThanOrEqualTo(400));
    final x = node['position_x'] as double;
    final w = node['width'] as double;
    expect(x, greaterThanOrEqualTo(0));
    expect(x + w, lessThanOrEqualTo(400));
  });

  group('打包成片（原「内置示例」并入短剧示例）', () {
    FakeAssetBundle fullBundle() => FakeAssetBundle(<String, List<int>>{
          for (final String path in kSampleArtifactAssets)
            path: <int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3],
        });

    test('两张成片各落一个 result 节点，文件写进画布 images/ 下', () async {
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
      final Map<String, Object?> config = rows.firstWhere(
        (Map<String, Object?> r) => r['node_role'] == 'config',
      );
      final List<Map<String, Object?>> results = rows
          .where((Map<String, Object?> r) => r['node_role'] == 'result')
          .toList();

      expect(bundle.requested, kSampleArtifactAssets);
      expect(results, hasLength(kSampleArtifactAssets.length));
      for (final Map<String, Object?> r in results) {
        expect(r['source_node_id'], config['id'], reason: 'result 必须挂在 config 下');
        expect(r['type'], 'image');
        expect(r['lane_id'], isNull, reason: '产物不进泳道（与生成路径一致）');
        final Map<String, Object?> cfg = r['type_config'] as Map<String, Object?>;
        final String rel = cfg['image_url']! as String;
        expect(rel, startsWith('images/'));
        final File f = File(
          '${paths.projects.path}/$projectId/canvases/$canvasId/$rel',
        );
        expect(f.existsSync(), isTrue, reason: '节点指向的文件必须真的在盘上：$rel');
        expect(f.lengthSync(), greaterThan(0));
      }
      // 两个产物不共用同一个文件名。
      final Set<String> urls = results
          .map((Map<String, Object?> r) =>
              (r['type_config'] as Map<String, Object?>)['image_url'] as String)
          .toSet();
      expect(urls, hasLength(kSampleArtifactAssets.length));
    });

    test('资产加载失败：示例项目照样建成，只是没有成片节点', () async {
      // setUp 的默认容器就是空 bundle。
      final String canvasId = await container
          .read(canvasBootstrapControllerProvider)
          .createSample(projectName: 'P', canvasName: 'C', seed: _seed);

      final List<Map<String, Object?>> rows =
          await nodes.listByCanvas(canvasId);
      expect(rows, hasLength(1));
      expect(rows.single['node_role'], 'config');
      expect(container.read(currentCanvasIdProvider), canvasId);
    });
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
