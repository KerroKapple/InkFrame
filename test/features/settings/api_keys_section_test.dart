// ApiKeysSection widget 测试 —— FakeSecureStorage 覆盖 save / clear 往返。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/settings/widgets/api_keys_section.dart';
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

const _fake = caps.ProviderCapabilities(
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

Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

ProviderScope scope(Widget child, SecureStorageService secure) {
  return ProviderScope(
    overrides: [
      providerCapabilitiesListProvider.overrideWith((ref) => [_fake]),
      secureStorageServiceProvider.overrideWithValue(secure),
    ],
    child: child,
  );
}

void main() {
  testWidgets('初始态未配置，Clear 按钮 disabled', (tester) async {
    final secure = _FakeSecure();
    await tester.pumpWidget(scope(host(const ApiKeysSection()), secure));
    await tester.pumpAndSettle();

    expect(find.text('test-provider'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    // Clear 按钮 disabled
    final clearBtn =
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Clear'));
    expect(clearBtn.onPressed, isNull);
  });

  testWidgets('Save 写入 SecureStorage 并切换到已配置', (tester) async {
    final secure = _FakeSecure();
    await tester.pumpWidget(scope(host(const ApiKeysSection()), secure));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final storedKey = SecureStorageKeys.providerApiKey('test-provider');
    expect(await secure.retrieve(storedKey), 'sk-abc');
    expect(find.text('Set'), findsOneWidget);
  });

  testWidgets('Clear 删除 SecureStorage 并切回未配置', (tester) async {
    final secure = _FakeSecure();
    final storedKey = SecureStorageKeys.providerApiKey('test-provider');
    await secure.store(storedKey, 'sk-existing');

    await tester.pumpWidget(scope(host(const ApiKeysSection()), secure));
    await tester.pumpAndSettle();
    expect(find.text('Set'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(await secure.retrieve(storedKey), isNull);
    expect(find.text('Not set'), findsOneWidget);
  });
}
