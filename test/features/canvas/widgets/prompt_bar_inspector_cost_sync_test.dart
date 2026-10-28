// 检查器与提示词条同屏：检查器改批量 / 时长之后，两处金额立即一致（W2 验收 #5）。
//
// 钉的几件：
//   - 写入卡在半路（仓储的 patchTypeConfig 等一道闸）——库里还是旧值、画布节点内存也是旧值——提示词条的
//     金额已经跟着检查器变了：它读的是 inspectorPendingConfigProvider（检查器本地已改的补丁）；
//   - 放闸、落盘之后两处仍一致：saveConfig 不刷新画布节点内存（这里的节点控制器是固定种子），补丁不能
//     在落盘成功时清掉。
//
// 变异点：
//   - canvas_prompt_bar.dart 估价的 pending 去掉 ...pendingConfig（不 watch 补丁）⇒ 两条用例在「未落盘」处红；
//   - InspectorSubmitController.saveConfig 不调 _publishPendingConfig ⇒ 同上红；
//   - 写成功后把补丁清空 ⇒ 两条用例在「落盘后」处红。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';
import 'package:inkframe/features/canvas/widgets/image_config_inspector.dart';
import 'package:inkframe/features/canvas/widgets/inspector_rows.dart';
import 'package:inkframe/features/canvas/widgets/video_config_inspector.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/providers/wanx_i2v_provider.dart';
import 'package:inkframe/providers/wanx_image_provider.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_prompt_preset.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_secure_storage.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const String _cid = 'cv1';

/// type_config 写入可以卡在半路：[gate] 非空时 patchTypeConfig 等它完成才真正落库。
class _GatedNodeRepo extends InMemoryNodeRepository {
  Completer<void>? gate;

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    final Completer<void>? g = gate;
    if (g != null) await g.future;
    return super.patchTypeConfig(id, patch);
  }
}

class _Selected extends CanvasSelectionController {
  _Selected(this.id);
  final String id;

  @override
  Set<String> build(String canvasId) => <String>{id};
}

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  late _GatedNodeRepo nodeRepo;

  setUp(() {
    nodeRepo = _GatedNodeRepo();
  });

  Future<CanvasNode> seed(CanvasNodeType type, Map<String, Object?> typeConfig) async {
    final String id = await nodeRepo.create(
      canvasId: _cid,
      type: type.name,
      nodeRole: 'config',
      label: 'cfg',
      typeConfig: typeConfig,
    );
    return CanvasNode(
      id: id,
      label: 'cfg',
      type: type,
      role: NodeRole.config,
      canvasId: _cid,
      projectId: 'proj-1',
      typeConfig: typeConfig,
    );
  }

  /// 检查器（左）与提示词条（右下）同屏。画布节点控制器是固定种子：saveConfig 落库后内存不变——
  /// 与真实画布一致（saveConfig 不刷新节点控制器）。
  Future<void> pump(
    WidgetTester tester,
    CanvasNode node,
    Widget inspector,
    List<ProviderCapabilities> capabilities,
  ) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 420, child: SingleChildScrollView(child: inspector)),
            const Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: CanvasPromptBar(canvasId: _cid),
              ),
            ),
          ],
        ),
      ),
      surfaceSize: const Size(1500, 1000),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => _cid),
        canvasNodesControllerProvider.overrideWith(() => FakeNodesController(<CanvasNode>[node])),
        canvasEdgesControllerProvider.overrideWith(FakeEdgesController.new),
        canvasLanesControllerProvider.overrideWith(EmptyLanesController.new),
        canvasSelectionControllerProvider.overrideWith(() => _Selected(node.id)),
        providerCapabilitiesListProvider.overrideWith((ref) => capabilities),
        preferencesServiceProvider.overrideWithValue(InMemoryPreferencesService()),
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => InMemoryEdgeRepository()),
        batchResultRepositoryProvider.overrideWith((ref) async => FakeBatchResultRepo()),
        canvasRepositoryProvider.overrideWith((ref) async => InMemoryCanvasRepository()),
        styleLaneRepositoryProvider.overrideWith((ref) async => InMemoryStyleLaneRepository()),
        characterRepositoryProvider.overrideWith((ref) async => FakeCharacterRepo()),
        characterAssetServiceProvider.overrideWithValue(FakeCharacterAssetService()),
        promptPresetRepositoryProvider.overrideWith((ref) async => FakePromptPresetRepo()),
        fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
        toastServiceProvider.overrideWithValue(RecordingToastService()),
      ],
    );
    await tester.pumpAndSettle();
  }

  /// 检查器「Est. cost」行里是不是写着 [text]。
  Finder inspectorCost(String text) => find.descendant(
        of: find.widgetWithText(InspectorRow, en.inspectorEstimatedCostLabel),
        matching: find.text(text),
      );

  String? barAmount(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(CanvasPromptBar.costKey)).data;

  /// 两处金额都是 [amount]（检查器写裸金额，提示词条写「≈ 金额」）。
  void expectBoth(WidgetTester tester, String amount, {required String reason}) {
    expect(inspectorCost(amount), findsOneWidget, reason: '检查器 · $reason');
    expect(barAmount(tester), en.costApprox(amount), reason: '提示词条 · $reason');
  }

  Map<String, Object?> storedConfig(String id) =>
      nodeRepo.rows[id]!['type_config']! as Map<String, Object?>;

  testWidgets('图像：检查器批量 1 → 4，未落盘时提示词条金额已一致，落盘后仍一致', (tester) async {
    final CanvasNode node = await seed(
      CanvasNodeType.image,
      <String, Object?>{'prompt': 'a cat', 'provider_id': 'wanx-image'},
    );
    await pump(
      tester,
      node,
      ImageConfigInspector(node: node),
      const <ProviderCapabilities>[kWanxImageCapabilities],
    );
    await tester.ensureVisible(find.text(en.inspectorEstimatedCostLabel));
    // 0.032 × 1。
    expectBoth(tester, r'$0.03', reason: '初始');

    // 写入卡在半路：库里、画布节点内存里都还是批量 1。
    nodeRepo.gate = Completer<void>();
    final Finder batch = find.descendant(
      of: find.byType(ImageConfigInspector),
      matching: find.byType(DropdownButton<int>),
    );
    await tester.ensureVisible(batch);
    await tester.tap(batch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();

    expect(storedConfig(node.id)['batch_size'], isNull, reason: '还没落盘');
    // 0.032 × 4 = 0.128。
    expectBoth(tester, r'$0.13', reason: '未落盘');

    nodeRepo.gate!.complete();
    nodeRepo.gate = null;
    await tester.pumpAndSettle();

    expect(storedConfig(node.id)['batch_size'], 4, reason: '已落盘');
    expectBoth(tester, r'$0.13', reason: '落盘后（画布节点内存仍是旧的）');
  });

  testWidgets('视频：检查器时长 5 秒 → 10 秒，未落盘时提示词条金额已一致，落盘后仍一致', (tester) async {
    final CanvasNode node = await seed(
      CanvasNodeType.video,
      <String, Object?>{'prompt': 'a cat', 'provider_id': 'wanx-i2v', 'duration_ms': 5000},
    );
    await pump(
      tester,
      node,
      VideoConfigInspector(node: node),
      const <ProviderCapabilities>[kWanxI2VCapabilities],
    );
    await tester.ensureVisible(find.text(en.inspectorEstimatedCostLabel));
    // 5 秒 × 0.30 × 1.0（没存分辨率 ⇒ 1080p）。
    expectBoth(tester, r'$1.50', reason: '初始');

    nodeRepo.gate = Completer<void>();
    // 第一个 int 下拉是时长，第二个是焦段（P3）。
    final Finder duration = find
        .descendant(
          of: find.byType(VideoConfigInspector),
          matching: find.byType(DropdownButton<int>),
        )
        .first;
    await tester.ensureVisible(duration);
    await tester.tap(duration);
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.inspectorVideoDurationOption(10)).last);
    await tester.pumpAndSettle();

    expect(storedConfig(node.id)['duration_ms'], 5000, reason: '还没落盘');
    expectBoth(tester, r'$3.00', reason: '未落盘');

    nodeRepo.gate!.complete();
    nodeRepo.gate = null;
    await tester.pumpAndSettle();

    expect(storedConfig(node.id)['duration_ms'], 10000, reason: '已落盘');
    expectBoth(tester, r'$3.00', reason: '落盘后（画布节点内存仍是旧的）');
  });
}
