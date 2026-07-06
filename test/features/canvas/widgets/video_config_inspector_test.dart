// VideoConfigInspector widget 测试——骨架层级：
// 渲染 prompt / duration / camera 控件；Generate 按钮初始 disabled。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/video_config_inspector.dart';

import '../../../_harness/test_app.dart';

const _fakeVideoCaps = caps.ProviderCapabilities(
  providerId: 'wanx-t2v',
  region: caps.ProviderRegion.cn,
  modes: [caps.GenerationMode.textToVideo, caps.GenerationMode.imageToVideo],
  supportedRatios: [caps.AspectRatio.r16x9, caps.AspectRatio.r1x1],
  supportedResolutions: [caps.Resolution.p720, caps.Resolution.p1080],
  supportedDurations: [5, 10],
  supportedCameras: [caps.CameraMovement.static_, caps.CameraMovement.pushIn],
  maxBatchSize: 1,
  maxRefImages: 1,
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

const _noCameraCaps = caps.ProviderCapabilities(
  providerId: 'wanx-t2v',
  region: caps.ProviderRegion.cn,
  modes: [caps.GenerationMode.textToVideo],
  supportedRatios: [caps.AspectRatio.r16x9],
  supportedResolutions: [caps.Resolution.p720, caps.Resolution.p1080],
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
  testWidgets('supportedCameras 为空 → 运镜整段隐藏（不渲染死下拉）', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: VideoConfigInspector(node: node)),
      locale: const Locale('zh'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_noCameraCaps]),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('运镜'), findsNothing);
    expect(find.byType(DropdownButton<caps.CameraMovement>), findsNothing);
    // duration 仍在
    expect(find.text('时长（秒）'), findsOneWidget);
  });

  testWidgets('持久化的不受支持运镜被钳制，不触发 DropdownButton 断言', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
      typeConfig: <String, Object?>{'provider_id': 'wanx-t2v', 'camera': 'orbit'},
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: VideoConfigInspector(node: node)),
      locale: const Locale('zh'),
      overrides: [
        // 支持 [static_, pushIn]，不含 orbit
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeVideoCaps]),
      ],
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 钳制为 supportedCameras.first → 本地化"固定机位"
    expect(find.text('固定机位'), findsOneWidget);
  });

  testWidgets('prompt / duration / camera 控件渲染', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: VideoConfigInspector(node: node)),
      locale: const Locale('zh'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeVideoCaps]),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('视频提示词'), findsOneWidget);
    expect(find.text('时长（秒）'), findsOneWidget);
    expect(find.text('运镜'), findsOneWidget);
  });

  testWidgets('duration dropdown 显示带单位（"5 秒" 而非 "5"）', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: VideoConfigInspector(node: node)),
      locale: const Locale('zh'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeVideoCaps]),
      ],
    );
    await tester.pumpAndSettle();

    // 打开 dropdown，断言 menu items 显示带单位
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();

    // [5, 10] 两个 supportedDurations，每个都应渲染为 "{n} 秒"
    expect(find.text('5 秒'), findsWidgets);
    expect(find.text('10 秒'), findsWidgets);
    // 不应出现裸数字
    expect(find.text('5'), findsNothing);
    expect(find.text('10'), findsNothing);
  });

  testWidgets('camera dropdown 显示本地化运镜名（"固定机位" 而非 "static_"）', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: VideoConfigInspector(node: node)),
      locale: const Locale('zh'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeVideoCaps]),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<caps.CameraMovement>));
    await tester.pumpAndSettle();

    expect(find.text('固定机位'), findsWidgets);
    expect(find.text('推进'), findsWidgets);
    // 不应直出枚举名
    expect(find.text('static_'), findsNothing);
    expect(find.text('pushIn'), findsNothing);
  });

  testWidgets('Generate 按钮初始 disabled（prompt 空）', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: VideoConfigInspector(node: node)),
      locale: const Locale('zh'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeVideoCaps]),
      ],
    );
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
  });
}
