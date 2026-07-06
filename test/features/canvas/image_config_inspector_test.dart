// ImageConfigInspector widget 测试——仅骨架层级：
// 显示标题 / prompt 框 / provider 下拉 / Generate 按钮初始 disabled。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/image_config_inspector.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../../_harness/test_app.dart';

class _FakeSecure implements SecureStorageService {
  final Map<String, String> _data = {};
  @override
  Future<void> store(String k, String v) async => _data[k] = v;
  @override
  Future<String?> retrieve(String k) async => _data[k];
  @override
  Future<void> delete(String k) async => _data.remove(k);
  @override
  Future<bool> exists(String k) async => _data.containsKey(k);
}

const _fakeCaps = caps.ProviderCapabilities(
  providerId: 'test-provider',
  region: caps.ProviderRegion.global,
  modes: [caps.GenerationMode.textToImage],
  supportedRatios: [caps.AspectRatio.r1x1],
  supportedResolutions: [caps.Resolution.p1080],
  supportedDurations: [],
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
  supportsCancellation: false,
  supportsPolling: false,
  costModel: CostModel.perCall(usdPerCall: 0),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 1,
);

const _fullCaps = caps.ProviderCapabilities(
  providerId: 'wanx-image',
  region: caps.ProviderRegion.cn,
  modes: [caps.GenerationMode.textToImage, caps.GenerationMode.imageToImage],
  supportedRatios: [caps.AspectRatio.r1x1, caps.AspectRatio.r16x9],
  supportedResolutions: [caps.Resolution.p1080],
  supportedDurations: [],
  supportedCameras: [],
  maxBatchSize: 4,
  maxRefImages: 1,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: true,
  supportsSeed: true,
  supportsSound: false,
  supportsBatch: true,
  supportsCancellation: true,
  supportsPolling: true,
  costModel: CostModel.perCall(usdPerCall: 0.1),
  maxConcurrentJobs: 2,
  qps: 1,
  burst: 1,
);

const _minimalCaps = caps.ProviderCapabilities(
  providerId: 'openai-image',
  region: caps.ProviderRegion.global,
  modes: [caps.GenerationMode.textToImage],
  supportedRatios: [],
  supportedResolutions: [caps.Resolution.p1080],
  supportedDurations: [],
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
  supportsCancellation: false,
  supportsPolling: false,
  costModel: CostModel.perCall(usdPerCall: 0),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 1,
);

void main() {
  List<Override> overridesWith({SecureStorageService? secure}) => [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeCaps]),
        if (secure != null)
          secureStorageServiceProvider.overrideWithValue(secure),
      ];

  const configNode = CanvasNode(
    id: 'cfg1',
    label: 'Test',
    type: CanvasNodeType.image,
  );

  testWidgets('渲染标题 / prompt 输入 / Provider 下拉', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageConfigInspector(node: configNode)),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Config'), findsOneWidget);
    expect(find.text('Prompt'), findsOneWidget);
    expect(find.text('test-provider'), findsOneWidget);
  });

  testWidgets('默认 provider 链：节点未存时优先上次使用', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageConfigInspector(node: configNode)),
      overrides: [
        providerCapabilitiesListProvider
            .overrideWith((ref) => [_fakeCaps, _fullCaps]),
        preferencesServiceProvider.overrideWithValue(
          InMemoryPreferencesService(
            const AppPreferences(lastImageProviderId: 'wanx-image'),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    // 未存节点配置时不取 first（test-provider），取记住的 wanx-image。
    expect(find.text('wanx-image'), findsOneWidget);
    expect(find.text('test-provider'), findsNothing);
  });

  testWidgets('上次使用的 provider 已不存在 → 回退 first', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageConfigInspector(node: configNode)),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeCaps]),
        preferencesServiceProvider.overrideWithValue(
          InMemoryPreferencesService(
            const AppPreferences(lastImageProviderId: 'custom:ghost'),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('test-provider'), findsOneWidget);
  });

  testWidgets('Generate 初始 disabled（prompt 空）', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageConfigInspector(node: configNode)),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('输入 prompt + 有 Key → Generate 启用（S3b 接 wire）',
      (tester) async {
    final secure = _FakeSecure();
    await secure.store('provider.test-provider.api_key', 'sk-xxx');
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageConfigInspector(node: configNode)),
      overrides: overridesWith(secure: secure),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a cat');
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNotNull,
        reason: 'S3b 已接 wire：prompt 非空 + Key 存在时应启用');
  });

  testWidgets('水化 typeConfig.prompt 到 TextField', (tester) async {
    const nodeWithPrompt = CanvasNode(
      id: 'cfg2',
      label: 'Test',
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{'prompt': 'existing prompt'},
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageConfigInspector(node: nodeWithPrompt)),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    expect(find.text('existing prompt'), findsOneWidget);
  });

  testWidgets('能力齐全 provider → 显示 宽高比 / 负向 / 种子 / 批量 控件',
      (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageConfigInspector(node: configNode)),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fullCaps]),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Aspect ratio'), findsOneWidget);
    expect(find.text('Negative prompt'), findsOneWidget);
    expect(find.text('Seed'), findsOneWidget);
    expect(find.text('Batch size'), findsOneWidget);
  });

  testWidgets('能力为空 provider → 不显示 宽高比 / 负向 / 种子 / 批量', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageConfigInspector(node: configNode)),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_minimalCaps]),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Aspect ratio'), findsNothing);
    expect(find.text('Negative prompt'), findsNothing);
    expect(find.text('Seed'), findsNothing);
    expect(find.text('Batch size'), findsNothing);
  });

  testWidgets('水化 typeConfig 的 seed / negative_prompt', (tester) async {
    const node = CanvasNode(
      id: 'cfg3',
      label: 'T',
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{
        'provider_id': 'wanx-image',
        'seed': 123,
        'negative_prompt': 'blurry',
      },
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageConfigInspector(node: node)),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fullCaps]),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('123'), findsOneWidget);
    expect(find.text('blurry'), findsOneWidget);
  });
}
