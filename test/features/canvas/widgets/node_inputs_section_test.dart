// NodeInputsSection widget 测试——入边列表 + role 能力门控：
// 渲染 data 入边行；role 下拉按 supportsFirstFrame/LastFrame 过滤；
// 当前 role 不在允许集时保留（防 DropdownButton 断言）；
// 切 role → updateRole 落库；移除 → removeEdge；空态文案。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_inputs_section.dart';
import 'package:inkframe/theme/components/ink_error_banner.dart';
import 'package:inkframe/theme/primitives/ink_dashed_slot.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const _kCanvasId = 'canvas-1';
const _kProjectId = 'proj-1';

class _FakeResolver implements FileResolverService {
  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) => File('/fake/$projectId/$canvasId/$relativePath');

  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) => File('/fake/$projectId/$relativePath');

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      Directory.systemTemp;

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) => source.path;
}

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
    Map<String, Object?> sourceTypeConfig = const <String, Object?>{},
  }) async {
    final sourceId = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'image',
      nodeRole: 'result',
      label: sourceLabel,
      typeConfig: sourceTypeConfig,
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
      projectId: _kProjectId,
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
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
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

  group('B3 参考图 UI 补完', () {
    testWidgets('maxRefImages>0 → 标签带 n/max 计数', (tester) async {
      final s = await seed();
      await pump(tester, s.target, _imageCaps); // maxRefImages: 1

      expect(find.text('Inputs (1/1)'), findsOneWidget);
    });

    testWidgets('first/last_frame 边不计入 n/max（只数 reference）', (tester) async {
      final s = await seed(role: 'first_frame');
      await pump(tester, s.target, _bothFramesCaps);
      // _bothFramesCaps maxRefImages=0 → 无计数；换 imageCaps 验证计 0
      await pump(tester, s.target, _imageCaps);

      expect(find.text('Inputs (0/1)'), findsOneWidget);
    });

    testWidgets('reference 边超出 maxRefImages → 显示忽略警告', (tester) async {
      final s = await seed();
      // 第二条 reference 边
      final src2 = await nodeRepo.create(
        canvasId: _kCanvasId,
        type: 'image',
        nodeRole: 'result',
        label: 'Src2',
      );
      await edgeRepo.create(
        canvasId: _kCanvasId,
        sourceNodeId: src2,
        targetNodeId: s.target.id,
        edgeType: 'data',
        role: 'reference',
      );
      await pump(tester, s.target, _imageCaps); // maxRefImages: 1

      expect(find.text('Inputs (2/1)'), findsOneWidget);
      expect(find.textContaining('Exceeds provider limit'), findsOneWidget);
    });

    testWidgets('未超限 → 无忽略警告', (tester) async {
      final s = await seed();
      await pump(tester, s.target, _imageCaps);

      expect(find.textContaining('Exceeds provider limit'), findsNothing);
    });

    testWidgets('空态用 InkDashedSlot 呈现', (tester) async {
      const target = CanvasNode(
        id: 'lonely',
        label: 'cfg',
        type: CanvasNodeType.video,
        role: NodeRole.config,
        canvasId: _kCanvasId,
        projectId: _kProjectId,
      );
      await pump(tester, target, _bothFramesCaps);

      expect(find.byType(InkDashedSlot), findsOneWidget);
      expect(find.text('No input connections'), findsOneWidget);
    });

    testWidgets('来源节点有 image_url → 行内缩略图（缺文件走占位不崩）', (tester) async {
      final s = await seed(
        sourceTypeConfig: <String, Object?>{'image_url': 'images/a.png'},
      );
      await pump(tester, s.target, _bothFramesCaps);

      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('来源节点无 image_url → 不渲染缩略图', (tester) async {
      final s = await seed();
      await pump(tester, s.target, _bothFramesCaps);

      expect(find.byType(Image), findsNothing);
    });
  });

  group('LB-06 加载失败错误态', () {
    testWidgets('入边加载失败 → 错误横幅（不再误报"无入边"）', (tester) async {
      const target = CanvasNode(
        id: 'cfg',
        label: 'cfg',
        type: CanvasNodeType.video,
        role: NodeRole.config,
        canvasId: _kCanvasId,
        projectId: _kProjectId,
      );
      await pumpInkApp(
        tester,
        const Scaffold(
          body: NodeInputsSection(
            targetNode: target,
            selectedCaps: _bothFramesCaps,
          ),
        ),
        locale: const Locale('en'),
        overrides: [
          nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
          // 边仓储 future 抛错 → edgesController 落 AsyncError。
          edgeRepositoryProvider.overrideWith(
            (ref) async => throw const LocalIOError(),
          ),
          fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(InkErrorBanner), findsOneWidget);
      expect(
        find.text('Local disk I/O error. Check space and permissions.'),
        findsOneWidget,
      );
      expect(find.text('No input connections'), findsNothing);
    });
  });
}
