// CH-2：video inspector 角色区——maxRefImages>0 挂载（不要求 imageToImage,CH-1 口径）,
// =0 整段不出现;chip 点选写 type_config.character_ids。
// 节点必须带 projectId/canvasId——角色区首行守卫 projectId==null 即 shrink
//（image 侧测试文件头注释踩过的坑）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/characters_section.dart';
import 'package:inkframe/features/canvas/widgets/video_config_inspector.dart';

import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const _kCanvasId = 'cv-1';
const _kProjectId = 'proj-1';

// 关键:modes 无 imageToImage——若共享 section 误用 image 门,挂载测试必红。
const _refCapableVideoCaps = caps.ProviderCapabilities(
  providerId: 'kling-v3-omni',
  region: caps.ProviderRegion.cn,
  modes: [caps.GenerationMode.textToVideo, caps.GenerationMode.imageToVideo],
  supportedRatios: [caps.AspectRatio.r16x9],
  supportedResolutions: [caps.Resolution.p1080],
  supportedDurations: [5, 10],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: 4,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: false,
  supportsSeed: false,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: true,
  supportsPolling: true,
  costModel: CostModel.perCall(usdPerCall: 0.1),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 1,
);

const _noRefVideoCaps = caps.ProviderCapabilities(
  providerId: 'wanx-t2v',
  region: caps.ProviderRegion.cn,
  modes: [caps.GenerationMode.textToVideo],
  supportedRatios: [caps.AspectRatio.r16x9],
  supportedResolutions: [caps.Resolution.p1080],
  supportedDurations: [5, 10],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: 0,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: false,
  supportsSeed: false,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: true,
  supportsPolling: true,
  costModel: CostModel.perCall(usdPerCall: 0.1),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 1,
);

void main() {
  late InMemoryNodeRepository nodeRepo;
  late InMemoryEdgeRepository edgeRepo;
  late FakeCharacterRepo charRepo;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
    edgeRepo = InMemoryEdgeRepository();
    charRepo = FakeCharacterRepo();
  });

  Future<CanvasNode> seedConfigNode() async {
    final id = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'video',
      nodeRole: 'config',
      label: 'cfg',
    );
    return CanvasNode(
      id: id,
      label: 'cfg',
      type: CanvasNodeType.video,
      role: NodeRole.config,
      canvasId: _kCanvasId,
      projectId: _kProjectId,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    CanvasNode node, {
    required caps.ProviderCapabilities capabilities,
  }) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(child: VideoConfigInspector(node: node)),
      ),
      locale: const Locale('en'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith(
          (ref) => [capabilities],
        ),
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        characterRepositoryProvider.overrideWith((ref) async => charRepo),
        characterAssetServiceProvider.overrideWithValue(
          FakeCharacterAssetService(),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('maxRefImages>0 → 角色区出现（无 imageToImage mode 也出现,CH-1 口径）',
      (tester) async {
    final node = await seedConfigNode();
    await pump(tester, node, capabilities: _refCapableVideoCaps);

    expect(find.byType(CharactersSection), findsOneWidget);
  });

  testWidgets('maxRefImages=0 → 角色区整段不挂载', (tester) async {
    final node = await seedConfigNode();
    await pump(tester, node, capabilities: _noRefVideoCaps);

    expect(find.byType(CharactersSection), findsNothing);
  });

  testWidgets('点选角色 chip → type_config 写入 character_ids', (tester) async {
    charRepo.rows['char-1'] = <String, Object?>{
      'id': 'char-1',
      'project_id': _kProjectId,
      'name': 'Hero',
      'reference_image_paths': <String>[],
    };
    final node = await seedConfigNode();
    await pump(tester, node, capabilities: _refCapableVideoCaps);

    await tester.tap(find.text('Hero'));
    await tester.pumpAndSettle();

    final tc = nodeRepo.rows[node.id]!['type_config']! as Map<String, Object?>;
    expect(tc['character_ids'], ['char-1'],
        reason: 'chip 点选须经 saveConfig 落到节点 type_config');
  });
}
