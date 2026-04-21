// ConfigNodeInspector widget 测试——仅骨架层级：
// 显示标题 / prompt 框 / provider 下拉 / Generate 按钮初始 disabled。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/config_node_inspector.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

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

void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  ProviderScope scope(Widget child, {SecureStorageService? secure}) {
    return ProviderScope(
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => [_fakeCaps]),
        if (secure != null)
          secureStorageServiceProvider.overrideWithValue(secure),
      ],
      child: child,
    );
  }

  const configNode = CanvasNode(
    id: 'cfg1',
    label: 'Test',
    type: CanvasNodeType.image,
  );

  testWidgets('渲染标题 / prompt 输入 / Provider 下拉', (tester) async {
    await tester.pumpWidget(scope(host(const ConfigNodeInspector(node: configNode))));
    await tester.pumpAndSettle();

    expect(find.text('Config'), findsOneWidget);
    expect(find.text('Prompt'), findsOneWidget);
    expect(find.text('test-provider'), findsOneWidget);
  });

  testWidgets('Generate 初始 disabled（prompt 空）', (tester) async {
    await tester.pumpWidget(scope(host(const ConfigNodeInspector(node: configNode))));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('输入 prompt + 有 Key → Generate 启用（S3b 接 wire）',
      (tester) async {
    final secure = _FakeSecure();
    await secure.store('provider.test-provider.api_key', 'sk-xxx');
    await tester.pumpWidget(
      scope(host(const ConfigNodeInspector(node: configNode)), secure: secure),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a cat');
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNotNull,
        reason: 'S3b 已接 wire：prompt 非空 + Key 存在时应启用');
  });
}
