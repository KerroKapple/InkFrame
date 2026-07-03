// NodeInputsSection widget 测试——入边列表 + role 能力门控：
// 渲染 data 入边行；role 下拉按 supportsFirstFrame/LastFrame 过滤；
// 当前 role 不在允许集时保留（防 DropdownButton 断言）；
// 切 role → updateRole 落库；移除 → removeEdge；空态文案。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_inputs_section.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const _kCanvasId = 'canvas-1';

/// 支持首帧、不支持尾帧（kling-v3 形态）。
const _firstFrameOnlyCaps = caps.ProviderCapabilities(
  providerId: 'kling-v3',
  region: caps.ProviderRegion.cn,
  modes: [caps.GenerationMode.textToVideo, caps.GenerationMode.imageToVideo],
  supportedRatios: [caps.AspectRatio.r16x9],
  supportedResolutions: [caps.Resolution.p720],
  supportedDurations: [5],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: 0,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: true,
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

/// 首尾帧都支持（wanx-i2v 形态）。
const _bothFramesCaps = caps.ProviderCapabilities(
  providerId: 'wanx-i2v',
  region: caps.ProviderRegion.cn,
  modes: [caps.GenerationMode.imageToVideo],
  supportedRatios: [caps.AspectRatio.r16x9],
  supportedResolutions: [caps.Resolution.p720],
  supportedDurations: [5],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: 0,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: true,
  supportsLastFrame: true,
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

/// 图像形态：支持参考图但无首尾帧概念。
const _imageCaps = caps.ProviderCapabilities(
  providerId: 'wanx-image',
  region: caps.ProviderRegion.cn,
  modes: [caps.GenerationMode.textToImage, caps.GenerationMode.imageToImage],
  supportedRatios: [caps.AspectRatio.r1x1],
  supportedResolutions: [caps.Resolution.p1080],
  supportedDurations: [],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: 1,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: true,
  supportsSeed: true,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: true,
  supportsPolling: true,
  costModel: CostModel.perCall(usdPerCall: 0.02),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 1,
);

void main() {
  late InMemoryNodeRepository nodeRepo;
  late InMemoryEdgeRepository edgeRepo;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
    edgeRepo = InMemoryEdgeRepository();
  });

  /// 预置一个 source result 节点 + 指向 target 的 data 边，返回 (targetNode, edgeId)。
  Future<({CanvasNode target, String edgeId})> seed({
    String role = 'reference',
    String sourceLabel = 'SrcNode',
  }) async {
    final sourceId = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'image',
      nodeRole: 'result',
      label: sourceLabel,
    );
    final targetId = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'video',
      nodeRole: 'config',
      label: 'cfg',
    );
    final edgeId = await edgeRepo.create(
      canvasId: _kCanvasId,
      sourceNodeId: sourceId,
      targetNodeId: targetId,
      edgeType: 'data',
      role: role,
    );
    final target = CanvasNode(
      id: targetId,
      label: 'cfg',
      type: CanvasNodeType.video,
      role: NodeRole.config,
      canvasId: _kCanvasId,
    );
    return (target: target, edgeId: edgeId);
  }

  Future<void> pump(
    WidgetTester tester,
    CanvasNode target,
    caps.ProviderCapabilities? selectedCaps,
  ) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: NodeInputsSection(targetNode: target, selectedCaps: selectedCaps),
      ),
      locale: const Locale('en'),
      overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('渲染 data 入边：来源 label + role 下拉 + 移除按钮', (tester) async {
    final s = await seed();
    await pump(tester, s.target, _bothFramesCaps);

    expect(find.text('SrcNode'), findsOneWidget);
    expect(find.byType(DropdownButton<EdgeRole>), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsOneWidget);
  });

  testWidgets('无入边 → 空态文案', (tester) async {
    const target = CanvasNode(
      id: 'lonely',
      label: 'cfg',
      type: CanvasNodeType.video,
      role: NodeRole.config,
      canvasId: _kCanvasId,
    );
    await pump(tester, target, _bothFramesCaps);

    expect(find.text('No input connections'), findsOneWidget);
  });

  testWidgets('supportsFirstFrame 且不支持尾帧 → 下拉有 First frame 无 Last frame', (
    tester,
  ) async {
    final s = await seed();
    await pump(tester, s.target, _firstFrameOnlyCaps);

    await tester.tap(find.byType(DropdownButton<EdgeRole>));
    await tester.pumpAndSettle();

    expect(find.text('First frame'), findsWidgets);
    expect(find.text('Last frame'), findsNothing);
  });

  testWidgets('图像能力（无首尾帧）→ 下拉只有 Reference', (tester) async {
    final s = await seed();
    await pump(tester, s.target, _imageCaps);

    await tester.tap(find.byType(DropdownButton<EdgeRole>));
    await tester.pumpAndSettle();

    expect(find.text('Reference'), findsWidgets);
    expect(find.text('First frame'), findsNothing);
    expect(find.text('Last frame'), findsNothing);
  });

  testWidgets('已存 role 不在允许集 → 保留当前值不崩（钳制语义）', (tester) async {
    final s = await seed(role: 'last_frame');
    await pump(tester, s.target, _firstFrameOnlyCaps);

    expect(tester.takeException(), isNull);
    // 当前值仍展示为 Last frame（按钮上）。
    expect(find.text('Last frame'), findsOneWidget);
  });

  testWidgets('切 role → updateRole 落库为 first_frame', (tester) async {
    final s = await seed();
    await pump(tester, s.target, _bothFramesCaps);

    await tester.tap(find.byType(DropdownButton<EdgeRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First frame').last);
    await tester.pumpAndSettle();

    expect(edgeRepo.rows[s.edgeId]!['role'], 'first_frame');
  });

  testWidgets('点移除 → 边被删除', (tester) async {
    final s = await seed();
    await pump(tester, s.target, _bothFramesCaps);

    await tester.tap(find.byIcon(Icons.link_off));
    await tester.pumpAndSettle();

    expect(await edgeRepo.listByCanvas(_kCanvasId), isEmpty);
  });
}
