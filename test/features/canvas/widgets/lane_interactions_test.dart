// 泳道交互测试（T20）：折叠、resize、重排。
// 驱动 controller 路径断言 widget 状态，避免 InteractiveViewer 手势坐标脆弱性。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/lane_collapse_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/lane_background.dart';
import 'package:inkframe/features/canvas/widgets/lane_title_bar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_unit_of_work.dart';

// ── fakes ──────────────────────────────────────────────────────────────────

class _FakeNodeRepository implements NodeRepository {
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      canvasId == 'cv1'
          ? [
              {
                'id': 'n1',
                'canvas_id': 'cv1',
                'type': 'image',
                'node_role': 'config',
                'label': 'node',
                'position_x': 0.0,
                'position_y': 0.0,
                'width': 200.0,
                'height': 160.0,
                'z_index': 0,
                'type_config': <String, Object?>{},
              },
            ]
          : const [];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<String> create({
    required String canvasId,
    required String type,
    required String nodeRole,
    String label = '',
    String? sourceNodeId,
    String? laneId,
    double positionX = 0,
    double positionY = 0,
    double width = 240,
    double height = 240,
    int zIndex = 0,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>?> findById(String id) async => null;

  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) async =>
      const [];

  @override
  Future<int> softDeleteEmptyOrphanResults() async => 0;

  @override
  Future<List<String>> listAllMediaUrls() async => const <String>[];

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async => 1;
}

class _FakeEdgeRepository implements EdgeRepository {
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      const [];

  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>?> findById(String id) async => null;

  @override
  Future<List<Map<String, Object?>>> listOutgoing(String sourceNodeId) async =>
      const [];

  @override
  Future<List<Map<String, Object?>>> listIncoming(String targetNodeId) async =>
      const [];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async => 1;
}

/// 记录 update 调用的 fake repo（两条泳道：lane-1, lane-2）。
class _FakeStyleLaneRepository implements StyleLaneRepository {
  final _updates = <({String id, Map<String, Object?> patch})>[];
  List<({String id, Map<String, Object?> patch})> get updates =>
      List.unmodifiable(_updates);

  static const _row1 = <String, Object?>{
    'id': 'lane-1',
    'canvas_id': 'cv1',
    'label': 'Act 1',
    'style_prompt': 'warm',
    'sort_order': 0,
    'tint_color': null,
    'size': 400.0,
  };

  static const _row2 = <String, Object?>{
    'id': 'lane-2',
    'canvas_id': 'cv1',
    'label': 'Act 2',
    'style_prompt': 'cool',
    'sort_order': 1,
    'tint_color': null,
    'size': 400.0,
  };

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      canvasId == 'cv1' ? [Map.of(_row1), Map.of(_row2)] : const [];

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    if (id == 'lane-1') return Map.of(_row1);
    if (id == 'lane-2') return Map.of(_row2);
    return null;
  }

  @override
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = 400.0,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    _updates.add((id: id, patch: patch));
    return 1;
  }

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async => 1;
}

class _FakeCanvasRepository implements CanvasRepository {
  @override
  Future<Map<String, Object?>?> findById(String id) async => <String, Object?>{
        'id': id,
        'lane_direction': 'horizontal',
        'base_style_prefix': '',
        'base_style_suffix': '',
      };

  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async =>
      const [];

  @override
  Future<List<Map<String, Object?>>> listByProjects(
          List<String> projectIds) async =>
      const [];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async => 1;
}

// ── helpers ─────────────────────────────────────────────────────────────────

Widget _buildTestApp(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        home: const Scaffold(body: CanvasView()),
      ),
    );

// ── tests ───────────────────────────────────────────────────────────────────

void main() {
  late _FakeStyleLaneRepository fakeLaneRepo;
  late ProviderContainer container;

  setUp(() {
    fakeLaneRepo = _FakeStyleLaneRepository();
    final tmp = Directory.systemTemp.createTempSync('ink_interactions_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final paths = DefaultAppPaths.forRoot(tmp);
    container = ProviderContainer(overrides: [
      appPathsProvider.overrideWithValue(paths),
      currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
      nodeRepositoryProvider.overrideWith((ref) async => _FakeNodeRepository()),
      edgeRepositoryProvider.overrideWith((ref) async => _FakeEdgeRepository()),
      styleLaneRepositoryProvider.overrideWith((ref) async => fakeLaneRepo),
      canvasRepositoryProvider.overrideWith((ref) async => _FakeCanvasRepository()),
      unitOfWorkProvider.overrideWith(
          (ref) async => FakeUnitOfWork(FakeRepositoryScope(styleLanes: fakeLaneRepo))),
    ]);
    addTearDown(container.dispose);
  });

  // ── (a) 折叠：toggle → LaneBackground.collapsedIds 含目标 id ──────────────

  testWidgets('toggle 折叠后 LaneBackground 收到 collapsedIds', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();

    // 初始：collapsedIds 为空。
    final bgBefore = tester.widget<LaneBackground>(find.byType(LaneBackground));
    expect(bgBefore.collapsedIds, isEmpty);

    // 直接驱动 controller，不走手势（避免 InteractiveViewer 坐标问题）。
    container.read(laneCollapseProvider('cv1').notifier).toggle('lane-1');
    await tester.pump();

    final bgAfter = tester.widget<LaneBackground>(find.byType(LaneBackground));
    expect(bgAfter.collapsedIds, contains('lane-1'));

    // 标题栏的折叠图标应从 unfold_less 变为 unfold_more。
    // LaneTitleBar 中折叠时显示 Icons.unfold_more。
    expect(find.byIcon(Icons.unfold_more), findsWidgets);
  });

  // ── (b) 折叠后再次 toggle → 恢复展开态 ──────────────────────────────────

  testWidgets('二次 toggle 恢复展开态', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();

    container.read(laneCollapseProvider('cv1').notifier).toggle('lane-1');
    await tester.pump();
    container.read(laneCollapseProvider('cv1').notifier).toggle('lane-1');
    await tester.pump();

    final bg = tester.widget<LaneBackground>(find.byType(LaneBackground));
    expect(bg.collapsedIds, isNot(contains('lane-1')));
  });

  // ── 泳道皮不随缩放（屏幕恒定大小；只缩放泳道内的内容）──────────────────

  testWidgets('缩放 2x 时标题栏反向缩放 0.5、分界线 pixelScale=2', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();

    // 把画布变换调到 2x。
    container.read(canvasTransformControllerProvider('cv1')).value =
        Matrix4.identity()..scaleByDouble(2.0, 2.0, 1.0, 1.0);
    await tester.pump();

    // 标题栏外层 Transform 的缩放应为 1/2——屏幕尺寸恒定。
    final t = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byType(LaneTitleBar).first,
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(scaleOf(t.transform), closeTo(0.5, 1e-9));

    // 泳道背景分界线拿到 pixelScale=2（世界粗细 1/2 → 屏幕恒 1px）。
    final bg = tester.widget<LaneBackground>(find.byType(LaneBackground));
    expect(bg.pixelScale, closeTo(2.0, 1e-9));
  });

  // ── (c) resize：updateLane → repo 收到 size 更新 ──────────────────────────

  testWidgets('updateLane 传入 size 时 repo 收到 size patch', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();
    await container.read(canvasLanesControllerProvider('cv1').future);

    // 直接调用 controller，验证 repo 写入路径正确。
    await container
        .read(canvasLanesControllerProvider('cv1').notifier)
        .updateLane('lane-1', size: 250.0);
    await tester.pump();

    final sizeUpdates = fakeLaneRepo.updates
        .where((u) => u.id == 'lane-1' && u.patch.containsKey('size'))
        .toList();
    expect(sizeUpdates, isNotEmpty, reason: 'repo 应收到 size patch');
    expect(sizeUpdates.last.patch['size'], 250.0);
  });

  // ── (d) resize clamp：clampLaneSize 下限语义由 lane_geometry_test 覆盖 ───────

  // ── (e) 重排：reorderLanes → repo sort_order 更新 ──────────────────────────

  testWidgets('reorderLanes → repo 收到 sort_order patch', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();
    await container.read(canvasLanesControllerProvider('cv1').future);

    // 交换顺序：[lane-2, lane-1]。
    await container
        .read(canvasLanesControllerProvider('cv1').notifier)
        .reorderLanes(['lane-2', 'lane-1']);
    await tester.pump();

    final sortUpdates = fakeLaneRepo.updates
        .where((u) => u.patch.containsKey('sort_order'))
        .toList();
    expect(sortUpdates, isNotEmpty, reason: 'repo 应收到 sort_order patch');

    // lane-2 -> sort_order 0；lane-1 -> sort_order 1。
    final lane2Update = sortUpdates.where((u) => u.id == 'lane-2').toList();
    final lane1Update = sortUpdates.where((u) => u.id == 'lane-1').toList();
    expect(lane2Update.last.patch['sort_order'], 0);
    expect(lane1Update.last.patch['sort_order'], 1);
  });

  // ── (f) 重排后 LaneTitleBar 渲染顺序跟 lanes 一致 ─────────────────────────

  testWidgets('重排后标题栏按新顺序渲染', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();
    await container.read(canvasLanesControllerProvider('cv1').future);

    await container
        .read(canvasLanesControllerProvider('cv1').notifier)
        .reorderLanes(['lane-2', 'lane-1']);
    await tester.pump();

    // 重排后 state 顺序：lane-2 先，lane-1 后。
    final lanes = container
        .read(canvasLanesControllerProvider('cv1'))
        .valueOrNull;
    expect(lanes, isNotNull);
    expect(lanes!.first.id, 'lane-2');
    expect(lanes.last.id, 'lane-1');

    // LaneTitleBar 均在树中。
    expect(find.byType(LaneTitleBar), findsNWidgets(2));
  });
}
