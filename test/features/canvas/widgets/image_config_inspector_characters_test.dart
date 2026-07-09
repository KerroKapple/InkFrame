// ImageConfigInspector 角色区/预设区 widget 测试（B3）：
// 角色 chip 缩略图 / InkDashedSlot 空态 / 落库失败 SnackBar。
// 节点必须带 projectId——两个 section 首行守卫 projectId==null 即 shrink，
// 这正是此前 widget 测试结构性够不到这两个区的原因。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/image_config_inspector.dart';
import 'package:inkframe/theme/components/ink_error_banner.dart';
import 'package:inkframe/theme/primitives/ink_dashed_slot.dart';

import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_prompt_preset.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const _kCanvasId = 'cv-1';
const _kProjectId = 'proj-1';

const _refCapableCaps = caps.ProviderCapabilities(
  providerId: 'fake-image',
  region: caps.ProviderRegion.global,
  modes: [caps.GenerationMode.textToImage, caps.GenerationMode.imageToImage],
  supportedRatios: [caps.AspectRatio.r1x1],
  supportedResolutions: [caps.Resolution.p1080],
  supportedDurations: [],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: 2,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: false,
  supportsSeed: false,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: true,
  supportsPolling: true,
  costModel: CostModel.perCall(usdPerCall: 0.01),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 1,
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
  late InMemoryEdgeRepository edgeRepo;
  late FakeCharacterRepo charRepo;
  late FakePromptPresetRepo presetRepo;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
    edgeRepo = InMemoryEdgeRepository();
    charRepo = FakeCharacterRepo();
    presetRepo = FakePromptPresetRepo();
  });

  Future<CanvasNode> seedConfigNode() async {
    final id = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'image',
      nodeRole: 'config',
      label: 'cfg',
    );
    return CanvasNode(
      id: id,
      label: 'cfg',
      type: CanvasNodeType.image,
      role: NodeRole.config,
      canvasId: _kCanvasId,
      projectId: _kProjectId,
    );
  }

  Future<void> pump(WidgetTester tester, CanvasNode node) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(child: ImageConfigInspector(node: node)),
      ),
      locale: const Locale('en'),
      overrides: [
        providerCapabilitiesListProvider.overrideWith(
          (ref) => [_refCapableCaps],
        ),
        secureStorageServiceProvider.overrideWithValue(_FakeSecure()),
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        canvasRepositoryProvider.overrideWith((ref) async => _FakeCanvasRepo()),
        styleLaneRepositoryProvider.overrideWith(
          (ref) async => _FakeLaneRepo(),
        ),
        characterRepositoryProvider.overrideWith((ref) async => charRepo),
        characterAssetServiceProvider.overrideWithValue(
          FakeCharacterAssetService(),
        ),
        promptPresetRepositoryProvider.overrideWith((ref) async => presetRepo),
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('角色 chip 渲染缩略图（缺文件走占位不崩）', (tester) async {
    charRepo.rows['char-1'] = <String, Object?>{
      'id': 'char-1',
      'project_id': _kProjectId,
      'name': 'Hero',
      'reference_image_paths': <String>['characters/hero-0.png'],
    };
    final node = await seedConfigNode();
    await pump(tester, node);

    expect(find.text('Hero'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无角色 → InkDashedSlot 空态（导入 CTA）', (tester) async {
    final node = await seedConfigNode();
    await pump(tester, node);

    expect(
      find.widgetWithText(InkDashedSlot, 'No characters yet'),
      findsOneWidget,
    );
  });

  testWidgets('存为预设落库失败 → SnackBar 提示（不静默吞错）', (tester) async {
    presetRepo.failCreate = true;
    final node = await seedConfigNode();
    await pump(tester, node);

    // 输入 prompt（空 prompt 直接 return 不落库）
    await tester.enterText(find.byType(TextField).first, 'a cat');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save current as preset'));
    await tester.tap(find.text('Save current as preset'));
    await tester.pumpAndSettle();

    // 名称对话框
    await tester.enterText(find.byType(TextField).last, 'My preset');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to save preset'), findsOneWidget);
  });

  testWidgets('存为角色落库失败 → SnackBar 提示（不静默吞错）', (tester) async {
    charRepo.failCreate = true;
    final node = await seedConfigNode();
    // reference 边 + 带 image_url 的源节点 → 「存为角色」按钮启用
    final srcId = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'image',
      nodeRole: 'result',
      label: 'Src',
      typeConfig: <String, Object?>{'image_url': 'images/ref.png'},
    );
    await edgeRepo.create(
      canvasId: _kCanvasId,
      sourceNodeId: srcId,
      targetNodeId: node.id,
      edgeType: 'data',
    );
    await pump(tester, node);

    await tester.ensureVisible(find.text('Save reference as character'));
    await tester.tap(find.text('Save reference as character'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Hero');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to import character'), findsOneWidget);
  });

  group('LB-06 分区加载失败错误态', () {
    const localIoText = 'Local disk I/O error. Check space and permissions.';

    /// 除指定抛错仓储外其余全用工作 fake；隔离单个分区的错误态。
    Future<void> pumpWith(
      WidgetTester tester,
      CanvasNode node, {
      required bool failCharacters,
      required bool failPresets,
    }) async {
      await pumpInkApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: ImageConfigInspector(node: node)),
        ),
        locale: const Locale('en'),
        overrides: [
          providerCapabilitiesListProvider.overrideWith(
            (ref) => [_refCapableCaps],
          ),
          secureStorageServiceProvider.overrideWithValue(_FakeSecure()),
          nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
          edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
          canvasRepositoryProvider.overrideWith((ref) async => _FakeCanvasRepo()),
          styleLaneRepositoryProvider.overrideWith(
            (ref) async => _FakeLaneRepo(),
          ),
          characterRepositoryProvider.overrideWith(
            (ref) async =>
                failCharacters ? throw const LocalIOError() : charRepo,
          ),
          characterAssetServiceProvider.overrideWithValue(
            FakeCharacterAssetService(),
          ),
          promptPresetRepositoryProvider.overrideWith(
            (ref) async => failPresets ? throw const LocalIOError() : presetRepo,
          ),
          fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('角色列表加载失败 → 错误横幅（不再误报"无角色"）', (tester) async {
      final node = await seedConfigNode();
      await pumpWith(
        tester,
        node,
        failCharacters: true,
        failPresets: false,
      );

      expect(find.byType(InkErrorBanner), findsOneWidget);
      expect(find.text(localIoText), findsOneWidget);
      expect(find.text('No characters yet'), findsNothing);
    });

    testWidgets('预设列表加载失败 → 错误横幅（不再误报"无预设"）', (tester) async {
      final node = await seedConfigNode();
      await pumpWith(
        tester,
        node,
        failCharacters: false,
        failPresets: true,
      );

      expect(find.byType(InkErrorBanner), findsOneWidget);
      expect(find.text(localIoText), findsOneWidget);
    });
  });
}
