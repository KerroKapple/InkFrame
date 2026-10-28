// ImageConfigInspector「预估费用」行（TakesCost 稿「花费预告」）：
//   - 自定义接口（价目 perCall 0）写「—」，不再写 $0.00；
//   - 本地改批量即时变（检查器本地态盖在 typeConfig 上，与提示词条同一个 estimateNodeCost）。
// 脚手架照抄 image_config_inspector_characters_test.dart（私有 fake 复制过来）。

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/core/models/provider_protocol_template.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/cost_breakdown_tooltip.dart';
import 'package:inkframe/features/canvas/widgets/image_config_inspector.dart';
import 'package:inkframe/features/canvas/widgets/inspector_rows.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/providers/wanx_image_provider.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_prompt_preset.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const _kCanvasId = 'cv-1';
const _kProjectId = 'proj-1';

final caps.ProviderCapabilities _custom = kOpenAIImageTemplateCapabilities.copyWith(
  providerId: 'custom:acme',
  displayName: 'Acme',
);

class _FakeSecure implements SecureStorageService {
  final Map<String, String> _m = {};
  @override
  Future<void> store(String k, String v) async => _m[k] = v;
  @override
  Future<String?> retrieve(String k) async => _m[k];
  @override
  Future<void> delete(String k) async => _m.remove(k);
  @override
  Future<bool> exists(String k) async => _m.containsKey(k);
}

class _FakeCanvasRepo implements CanvasRepository {
  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(String projectId) async =>
      const <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async => '';
  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async =>
      [];
  @override
  Future<List<Map<String, Object?>>> listByProjects(
    List<String> projectIds,
  ) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 0;
  @override
  Future<int> softDelete(String id) async => 0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

class _FakeLaneRepo implements StyleLaneRepository {
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = 400.0,
  }) async => '';
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 0;
  @override
  Future<int> softDelete(String id) async => 0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

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

void main() {
  late InMemoryNodeRepository nodeRepo;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
  });

  Future<CanvasNode> seedConfigNode(Map<String, Object?> typeConfig) async {
    final id = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'image',
      nodeRole: 'config',
      label: 'cfg',
      typeConfig: typeConfig,
    );
    return CanvasNode(
      id: id,
      label: 'cfg',
      type: CanvasNodeType.image,
      role: NodeRole.config,
      canvasId: _kCanvasId,
      projectId: _kProjectId,
      typeConfig: typeConfig,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    CanvasNode node,
    List<caps.ProviderCapabilities> capabilities, {
    List<Override> extraOverrides = const <Override>[],
  }) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(child: ImageConfigInspector(node: node)),
      ),
      locale: const Locale('en'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith((ref) => capabilities),
        secureStorageServiceProvider.overrideWithValue(_FakeSecure()),
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => InMemoryEdgeRepository()),
        batchResultRepositoryProvider.overrideWith(
          (ref) async => FakeBatchResultRepo(),
        ),
        canvasRepositoryProvider.overrideWith((ref) async => _FakeCanvasRepo()),
        styleLaneRepositoryProvider.overrideWith(
          (ref) async => _FakeLaneRepo(),
        ),
        characterRepositoryProvider.overrideWith((ref) async => FakeCharacterRepo()),
        characterAssetServiceProvider.overrideWithValue(
          FakeCharacterAssetService(),
        ),
        promptPresetRepositoryProvider.overrideWith((ref) async => FakePromptPresetRepo()),
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
        toastServiceProvider.overrideWithValue(RecordingToastService()),
        ...extraOverrides,
      ],
    );
    await tester.pumpAndSettle();
  }

  /// 「Est. cost」那一行里的值。
  Finder costValue(String text) => find.descendant(
        of: find.widgetWithText(InspectorRow, 'Est. cost'),
        matching: find.text(text),
      );

  testWidgets('自定义接口：预估费用写「—」', (tester) async {
    final node = await seedConfigNode(<String, Object?>{'provider_id': 'custom:acme'});
    await pump(tester, node, <caps.ProviderCapabilities>[_custom]);

    await tester.ensureVisible(find.text('Est. cost'));
    expect(costValue('—'), findsOneWidget);
    expect(find.text(r'$0.00'), findsNothing, reason: '价目是 perCall 0 的占位，不是免费');
  });

  testWidgets('批量改 4 → 金额 ×4', (tester) async {
    final node = await seedConfigNode(<String, Object?>{'provider_id': 'wanx-image'});
    await pump(tester, node, <caps.ProviderCapabilities>[kWanxImageCapabilities]);

    await tester.ensureVisible(find.text('Est. cost'));
    // 0.032 × 1。
    expect(costValue(r'$0.03'), findsOneWidget);

    // 图像检查器里 int 下拉只有「数量」一个（种子是输入框）。
    await tester.ensureVisible(find.byType(DropdownButton<int>));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();

    // 0.032 × 4 = 0.128。传进来的 node 没变：金额跟着变只能是走了检查器的本地态。
    expect(costValue(r'$0.13'), findsOneWidget);
    expect(costValue(r'$0.03'), findsNothing);
  });

  testWidgets('已存服务商被删：费用行仍画，金额「—」', (tester) async {
    // 能力表是空的：已存 id 解析得到，但选不中任何服务商（selected == null）。
    // 费用行不能跟着 selected 一起消失（决定 2）。
    final node = await seedConfigNode(<String, Object?>{'provider_id': 'deleted-vendor'});
    await pump(tester, node, <caps.ProviderCapabilities>[]);

    await tester.ensureVisible(find.text('Est. cost'));
    expect(costValue('—'), findsOneWidget);
    expect(find.text(r'$0.00'), findsNothing);
  });

  // 锁定既有行为：悬停检查器「生成」能看到明细卡，证明 costEstimate 经
  // InspectorStatusBinding 传到了按钮。拿掉 image_config_inspector 里传给
  // InspectorStatusBinding 的 `costEstimate: cost`（改成 null）这条会变红。
  testWidgets('悬停「生成」出明细卡：costEstimate 经 Binding 传到按钮', (tester) async {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final node = await seedConfigNode(<String, Object?>{
      'provider_id': 'wanx-image',
      'prompt': 'a cat',
      'batch_size': 4,
    });
    await pump(
      tester,
      node,
      <caps.ProviderCapabilities>[kWanxImageCapabilities],
      extraOverrides: <Override>[
        inspectorHasApiKeyProvider.overrideWith((ref, String providerId) async => true),
      ],
    );

    final Finder button = find.widgetWithText(FilledButton, 'Generate');
    expect(button, findsOneWidget);
    expect(find.byKey(CostBreakdownTooltip.contentKey), findsNothing);

    await tester.ensureVisible(button);
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final Finder card = find.byKey(CostBreakdownTooltip.contentKey);
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text(en.costFormulaBatch(r'$0.032', 4, r'$0.13')),
      ),
      findsOneWidget,
    );

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
