// VideoConfigInspector widget 测试——骨架层级：
// 渲染 prompt / duration / camera 控件；Generate 按钮初始 disabled。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/core/models/shot_language.dart' as caps;
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_inputs_section.dart';
import 'package:inkframe/features/canvas/widgets/video_config_inspector.dart';

import '../../../_harness/fake_repositories.dart';
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
  // P3：镜头运动组是导演意图，不再按 provider 能力位隐藏 / 钳制——落库 + 注入提示词，
  // 参数是否下发由 GenerationController 看能力位（generation_controller_video_test）。
  testWidgets('supportedCameras 为空 → 运镜下拉照样在（全量 13 项），另四行也在', (tester) async {
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
    expect(find.text('运镜'), findsOneWidget);
    expect(find.text('景别'), findsOneWidget);
    expect(find.text('机位角度'), findsOneWidget);
    expect(find.text('运镜幅度'), findsOneWidget);
    expect(find.text('焦段'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    // 四个可空字段未设 → 「未设」占位（运镜 / 景别 / 角度 / 焦段下拉 + 滑杆读数）。
    expect(find.text('未设'), findsNWidgets(5));

    await tester.tap(find.byType(DropdownButton<caps.CameraMovement>));
    await tester.pumpAndSettle();
    expect(find.text('跟拍'), findsWidgets, reason: 'P3 新增项在列表里');
    expect(find.text('环绕', skipOffstage: false), findsWidgets, reason: '13 项菜单末项可能在滚动区外');
  });

  testWidgets('持久化的运镜不再被 provider 钳制：orbit 原样显示「环绕」', (tester) async {
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
    expect(find.text('环绕'), findsOneWidget);
    expect(find.text('固定'), findsNothing);
  });

  testWidgets('旧数据里已删除的运镜值（handheld）→ 解析为未设，不炸', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
      typeConfig: <String, Object?>{'provider_id': 'wanx-t2v', 'camera': 'handheld'},
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
    expect(tester.takeException(), isNull);
    expect(find.text('未设'), findsNWidgets(5));
  });

  testWidgets('P3 四字段水化：中景 MS / 平视 Eye Level / 0.35 / 35mm', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
      typeConfig: <String, Object?>{
        'provider_id': 'wanx-t2v',
        'shot_size': 'mediumShot',
        'camera_angle': 'eyeLevel',
        'camera_motion_strength': 0.35,
        'focal_length_mm': 35,
      },
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
    expect(find.text('中景 MS'), findsOneWidget);
    expect(find.text('平视 Eye Level'), findsOneWidget);
    expect(find.text('0.35'), findsOneWidget);
    expect(find.text('35mm'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(0.35, 1e-9));
  });

  testWidgets('P3 改景别 / 拖滑杆 → patchTypeConfig 只落对应键，其他键不动', (tester) async {
    final nodeRepo = InMemoryNodeRepository();
    final String id = await nodeRepo.create(
      canvasId: 'cv1',
      type: 'video',
      nodeRole: 'config',
      label: '',
      typeConfig: const <String, Object?>{'provider_id': 'wanx-t2v', 'camera': 'orbit', 'focal_length_mm': 50},
    );
    final node = CanvasNode(
      id: id,
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
      canvasId: 'cv1',
      typeConfig: const <String, Object?>{'provider_id': 'wanx-t2v', 'camera': 'orbit', 'focal_length_mm': 50},
    );
    await pumpInkApp(
      tester,
      Scaffold(body: VideoConfigInspector(node: node)),
      locale: const Locale('zh'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeVideoCaps]),
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<caps.ShotSize>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('特写 CU').last);
    await tester.pumpAndSettle();

    Map<String, Object?> saved() => nodeRepo.rows[id]!['type_config']! as Map<String, Object?>;
    expect(saved()['shot_size'], 'closeUp');
    expect(saved()['focal_length_mm'], 50, reason: '未改的键原样保留');
    expect(saved()['camera'], 'orbit');
    expect(saved()['camera_angle'], isNull);

    // 滑杆拖到右端 → 1.00（步进 0.05 取整）。
    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0.98);
    await tester.pumpAndSettle();
    expect(saved()['camera_motion_strength'], closeTo(1.0, 1e-9));
    expect(find.text('1.00'), findsOneWidget);
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
    await tester.tap(find.byType(DropdownButton<int>).first); // 第一个是时长，第二个是焦段（P3）
    await tester.pumpAndSettle();

    // [5, 10] 两个 supportedDurations，每个都应渲染为 "{n} 秒"
    expect(find.text('5 秒'), findsWidgets);
    expect(find.text('10 秒'), findsWidgets);
    // 不应出现裸数字
    expect(find.text('5'), findsNothing);
    expect(find.text('10'), findsNothing);
  });

  testWidgets('camera dropdown 显示本地化运镜名（"固定" 而非 "static_"）', (tester) async {
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

    expect(find.text('固定'), findsWidgets);
    expect(find.text('推镜'), findsWidgets);
    // 不应直出枚举名
    expect(find.text('static_'), findsNothing);
    expect(find.text('pushIn'), findsNothing);
  });

  testWidgets('带 canvasId 的视频节点渲染 Inputs 区（首尾帧接入口）', (tester) async {
    final nodeRepo = InMemoryNodeRepository();
    final edgeRepo = InMemoryEdgeRepository();
    final sourceId = await nodeRepo.create(
      canvasId: 'canvas-1',
      type: 'image',
      nodeRole: 'result',
      label: 'FrameSrc',
    );
    final targetId = await nodeRepo.create(
      canvasId: 'canvas-1',
      type: 'video',
      nodeRole: 'config',
      label: '',
    );
    await edgeRepo.create(
      canvasId: 'canvas-1',
      sourceNodeId: sourceId,
      targetNodeId: targetId,
      edgeType: 'data',
    );
    final node = CanvasNode(
      id: targetId,
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
      canvasId: 'canvas-1',
    );
    await pumpInkApp(
      tester,
      Scaffold(body: VideoConfigInspector(node: node)),
      locale: const Locale('en'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeVideoCaps]),
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(NodeInputsSection), findsOneWidget);
    expect(find.text('FrameSrc'), findsOneWidget);
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
