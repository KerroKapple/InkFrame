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
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/lane_collapse_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/lane_background.dart';
import 'package:inkframe/features/canvas/widgets/lane_title_bar.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_toast_service.dart';
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
              // 在 lane-2（起始边 400）内的节点——泳道钉死锚定测试用。
              {
                'id': 'n2',
                'canvas_id': 'cv1',
                'type': 'image',
                'node_role': 'config',
                'label': 'laned',
                'lane_id': 'lane-2',
                'position_x': 0.0,
                'position_y': 500.0,
                'width': 200.0,
                'height': 160.0,
                'z_index': 0,
                'type_config': <String, Object?>{},
              },
              // 负世界坐标节点——全向无限画布命中测试用。
              {
                'id': 'n3',
                'canvas_id': 'cv1',
                'type': 'image',
                'node_role': 'config',
                'label': 'negative',
                'position_x': -500.0,
                'position_y': -300.0,
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
  // P2-3 test flips this to vertical; setUp resets it.
  static String direction = 'horizontal';

  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(String projectId) async =>
      const <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>?> findById(String id) async => <String, Object?>{
        'id': id,
        'lane_direction': direction,
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
    _FakeCanvasRepository.direction = 'horizontal';
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

  // ── 泳道钉在视口层：缩放/平移只动泳道内的内容，泳道本身不动 ─────────────

  // 舞台顶部那一条（InkToolbarSize.stageTopInset）归浮动工具条：默认相机下泳道标题栏都得在它
  // 下面，否则窄窗口里居中的工具条会盖住标题栏右端的折叠 / 编辑键。横向道的标题栏随泳道栈走
  //（靠初始相机让位），竖向道的标题栏钉在视口顶（靠钉住的 top 让位）——两条路各测一次。
  Future<void> expectTitleBarsBelowToolbarBand(WidgetTester tester) async {
    final Finder bars = find.byType(LaneTitleBar);
    expect(bars, findsWidgets);
    for (int i = 0; i < bars.evaluate().length; i++) {
      expect(
        tester.getTopLeft(bars.at(i)).dy,
        greaterThanOrEqualTo(InkToolbarSize.stageTopInset),
        reason: '第 ${i + 1} 条泳道的标题栏压进了工具条那一条',
      );
    }
  }

  testWidgets('默认相机下横向泳道的标题栏在工具条那一条之下', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();
    await expectTitleBarsBelowToolbarBand(tester);
  });

  testWidgets('竖向泳道的标题栏钉在视口顶，同样让出工具条那一条', (tester) async {
    _FakeCanvasRepository.direction = 'vertical';
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();
    await expectTitleBarsBelowToolbarBand(tester);
  });

  testWidgets('泳道背景/标题栏在 InteractiveViewer 之外（视口层，不随缩放）',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();

    // 泳道三件套不在世界变换内——缩放/平移不影响它们。
    expect(
      find.ancestor(
        of: find.byType(LaneBackground),
        matching: find.byType(InteractiveViewer),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(LaneTitleBar).first,
        matching: find.byType(InteractiveViewer),
      ),
      findsNothing,
    );

    // 围绕世界原点缩放到 2x（worldT 不变——初始相机把世界原点放在 (0, stageTopInset)，
    // 这里保持住它）：标题栏屏幕位置不变、厚度不缩放。
    final beforeTop = tester.getTopLeft(find.byType(LaneTitleBar).first);
    container.read(canvasTransformControllerProvider('cv1')).value =
        Matrix4.identity()
          ..translateByDouble(
            -2 * kStageHalf,
            -2 * kStageHalf + InkToolbarSize.stageTopInset,
            0.0,
            1.0,
          )
          ..scaleByDouble(2.0, 2.0, 1.0, 1.0);
    await tester.pump();
    final afterTop = tester.getTopLeft(find.byType(LaneTitleBar).first);
    expect(afterTop, beforeTop);

    // 平移画布（终版语义）：泳道栈随世界一起动。
    container.read(canvasTransformControllerProvider('cv1')).value =
        initialCanvasTransform()..translateByDouble(0.0, -300.0, 0.0, 1.0);
    await tester.pump();
    final panned = tester.getTopLeft(find.byType(LaneTitleBar).first);
    expect(panned.dy, beforeTop.dy - 300);
  });

  // ── 全向无限画布：负世界坐标节点可见、可点选 ────────────────────────────

  testWidgets('负坐标节点：平移相机后可见且可点选', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();

    // 相机向左上平移 600/400：世界 (-500,-300) 应落到屏幕 (100, 100 + stageTopInset)
    //（初始相机已把世界原点往下让出浮动工具条那一条）。
    container.read(canvasTransformControllerProvider('cv1')).value =
        initialCanvasTransform()..translateByDouble(600.0, 400.0, 0.0, 1.0);
    await tester.pump();

    final card = find.byKey(const ValueKey('node-card-n3'));
    expect(
      tester.getTopLeft(card),
      const Offset(100, 100 + InkToolbarSize.stageTopInset),
    );

    // 负坐标区不再是点击死区：tap 命中并进入选中集。
    await tester.tap(card);
    await tester.pump();
    expect(
      container.read(canvasSelectionControllerProvider('cv1')),
      contains('n3'),
    );
  });

  testWidgets('泳道内卡片缩放锚定本道起始边，不穿出泳道带', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();

    // n2 在 lane-2（起始边 400）内，世界 y=500；初始相机下屏幕 y=500 + stageTopInset。
    final card = find.byKey(const ValueKey('node-card-n2'));
    expect(tester.getTopLeft(card).dy, 500 + InkToolbarSize.stageTopInset);

    // 围绕世界原点 2x：锚定本道 → y = 400 + 2*(500-400) = 600（未锚定会飞到 1000）。
    container.read(canvasTransformControllerProvider('cv1')).value =
        Matrix4.identity()
          ..translateByDouble(-2 * kStageHalf, -2 * kStageHalf, 0.0, 1.0)
          ..scaleByDouble(2.0, 2.0, 1.0, 1.0);
    await tester.pump();
    expect(tester.getTopLeft(card).dy, closeTo(600, 0.5));

    // 围绕世界原点 0.5x：y = 400 + 0.5*(500-400) = 450，仍在道带 [400, 800) 内。
    container.read(canvasTransformControllerProvider('cv1')).value =
        Matrix4.identity()
          ..translateByDouble(-0.5 * kStageHalf, -0.5 * kStageHalf, 0.0, 1.0)
          ..scaleByDouble(0.5, 0.5, 1.0, 1.0);
    await tester.pump();
    expect(tester.getTopLeft(card).dy, closeTo(450, 0.5));

    // 纵向平移（终版语义）：泳道栈带着道内卡片一起动。
    container.read(canvasTransformControllerProvider('cv1')).value =
        initialCanvasTransform()..translateByDouble(0.0, -300.0, 0.0, 1.0);
    await tester.pump();
    expect(
      tester.getTopLeft(card).dy,
      closeTo(200 + InkToolbarSize.stageTopInset, 0.5),
    );
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

  // ── (c2) resize：真实拖拽分界线手势 → repo 收到 size 更新（回归守卫：
  //        泳道钉到视口层后感应条不得被 InteractiveViewer 手势吃掉）──────────

  testWidgets('拖拽泳道分界线 → 泳道宽度更新', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();
    await container.read(canvasLanesControllerProvider('cv1').future);

    // lane-1 尺寸 400 → 分界线在屏幕 y=400 + stageTopInset（初始相机让出工具条那一条），
    // 感应条 ±5 需整段可抓（含与 lane-2 标题栏重叠的下半段——感应条须压在标题栏之上）。
    // 从边界线正中往下 3 处起拖，往下拖 50。
    final gesture = await tester
        .startGesture(const Offset(300, 403 + InkToolbarSize.stageTopInset));
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final sizeUpdates = fakeLaneRepo.updates
        .where((u) => u.id == 'lane-1' && u.patch.containsKey('size'))
        .toList();
    expect(sizeUpdates, isNotEmpty, reason: '分界线拖拽应触发 size 落库');
    expect((sizeUpdates.last.patch['size']! as num).toDouble(),
        closeTo(450, 5));
  });

  // ── (c3) 平移画布后分界线仍可拖（回归守卫：Transform.translate 只移画面
  //        不移命中区，平移后泳道边界曾"看得见摸不着"）──────────────────────

  testWidgets('平移画布后拖拽分界线仍可调宽度', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();
    await container.read(canvasLanesControllerProvider('cv1').future);

    // 相机上移 300：泳道栈随平移整体走，lane-1/lane-2 分界线从 400 移到 100（都另加
    // stageTopInset）。
    container.read(canvasTransformControllerProvider('cv1')).value =
        initialCanvasTransform()..translateByDouble(0.0, -300.0, 0.0, 1.0);
    await tester.pump();

    final gesture = await tester
        .startGesture(const Offset(300, 103 + InkToolbarSize.stageTopInset));
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final sizeUpdates = fakeLaneRepo.updates
        .where((u) => u.id == 'lane-1' && u.patch.containsKey('size'))
        .toList();
    expect(sizeUpdates, isNotEmpty,
        reason: '平移后分界线命中区必须跟随泳道栈');
    expect((sizeUpdates.last.patch['size']! as num).toDouble(),
        closeTo(450, 5));
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

  // ── Lanes 稿改动 4：折叠真的省空间 ────────────────────────────────────────

  testWidgets('折叠 lane-1 → 收成 36 轨：lane-2 标题栏上移 400 − 36，lane-1 里的节点不再建卡', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();
    // 三个节点：n1 无道、n2 在 lane-2、n3 无道 ⇒ 三张卡。
    expect(find.byType(NodeCard, skipOffstage: false), findsNWidgets(3));
    final Offset lane2Before = tester.getTopLeft(find.byType(LaneTitleBar).at(1));

    container.read(laneCollapseProvider('cv1').notifier).toggle('lane-1');
    await tester.pump();

    final Offset lane2After = tester.getTopLeft(find.byType(LaneTitleBar).at(1));
    expect(lane2After.dy, lane2Before.dy - (400 - kCollapsedLaneSize), reason: '后面的道整体上移');
    expect(find.text('Collapsed'), findsOneWidget);

    // 折叠 lane-2：它里面的 n2 不再建卡，只剩两张。
    container.read(laneCollapseProvider('cv1').notifier).toggle('lane-2');
    await tester.pump();
    expect(find.byType(NodeCard, skipOffstage: false), findsNWidgets(2), reason: '折叠道里的内容隐藏');
    expect(find.text('laned', skipOffstage: false), findsNothing);
  });

  // ── BOARD P2-3：竖向窄末道的标题栏按钮必须可命中 ─────────────────────────

  testWidgets('竖向末道 80px 时标题栏按最小宽溢出到道外，编辑键仍可点开编辑框', (tester) async {
    _FakeCanvasRepository.direction = 'vertical';
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();
    await container.read(canvasLanesControllerProvider('cv1').future);
    // 末道收到下限 80：栏宽 80 − 24 = 56 < LaneTitleBar.minWidth ⇒ 按 128 溢出到道外。
    await container.read(canvasLanesControllerProvider('cv1').notifier).updateLane('lane-2', size: 80);
    // 初始相机把世界原点放在视口正中（x=400），竖向泳道栈从那里开始往右堆——末道会落到 800 宽的
    // 视口之外。往左平移 300，让末道（400..480 → 500..580）和它溢出的标题栏都在视口里。
    container.read(canvasTransformControllerProvider('cv1')).value =
        initialCanvasTransform()..translateByDouble(-300.0, 0.0, 0.0, 1.0);
    await tester.pump();

    final Finder lastBar = find.byType(LaneTitleBar).at(1);
    expect(tester.getSize(lastBar).width, LaneTitleBar.minWidth);
    final Offset stackOrigin = tester.getTopLeft(find.byType(LaneTitleBar).first) - const Offset(12, 14);
    expect(tester.getBottomRight(lastBar).dx, greaterThan(stackOrigin.dx + 400 + 80),
        reason: '前置：栏确实溢出到泳道栈之外');

    final Finder editKey = find.descendant(of: lastBar, matching: find.byIcon(Icons.edit));
    await tester.tap(editKey);
    // 标题栏挂着 onDoubleTap：单击要等 kDoubleTapTimeout（300ms）才落地，pumpAndSettle 不推计时器。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Edit lane'), findsOneWidget, reason: '溢出到栈外的按钮也得能点——皮层盒子留了余量');
  });

  // ── 解散泳道（节点留下）：不确认、卡片原地不动、库里 lane_id 清空 ─────────────
  //
  // setUp 的共享容器用的是静态假仓储（update 不写、softDelete 不删），撑不起这条：自建 InMemory 三件套容器。
  // 缩放取 0.8（不是 1）：缩放 1 时道内锚定与全局变换恰好重合，「不换算位置」的变异抓不到。
  // 变异对照：stage_lane_layer 仍走旧确认框 ⇒「无确认框」红；dissolvedPositions 返回原坐标 ⇒ getRect 前后不等红；
  // dissolveLane 不写 lane_id: null ⇒「repo 里 lane_id 为 null」红。

  testWidgets('点标题栏解散键：无确认框，卡片 getRect 前后相等，repo 里 lane_id 为 null，tooltip 为 Dissolve lane (keep nodes)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final nodes = InMemoryNodeRepository();
    final edges = InMemoryEdgeRepository();
    final lanes = InMemoryStyleLaneRepository();
    await lanes.create(canvasId: 'cv1', label: 'Ink', sortOrder: 0, size: 400);
    final cyber = await lanes.create(canvasId: 'cv1', label: 'Cyber', sortOrder: 1, size: 400);
    final laned = await nodes.create(
      canvasId: 'cv1',
      type: 'image',
      nodeRole: 'config',
      label: 'laned',
      laneId: cyber,
      positionX: 0,
      positionY: 500,
    );
    final tmp = Directory.systemTemp.createTempSync('ink_dissolve_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final toasts = RecordingToastService();
    final own = ProviderContainer(overrides: [
      appPathsProvider.overrideWithValue(DefaultAppPaths.forRoot(tmp)),
      currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
      nodeRepositoryProvider.overrideWith((ref) async => nodes),
      edgeRepositoryProvider.overrideWith((ref) async => edges),
      styleLaneRepositoryProvider.overrideWith((ref) async => lanes),
      canvasRepositoryProvider.overrideWith((ref) async => _FakeCanvasRepository()),
      unitOfWorkProvider.overrideWith(
        (ref) async => FakeUnitOfWork(FakeRepositoryScope(nodes: nodes, edges: edges, styleLanes: lanes)),
      ),
      toastServiceProvider.overrideWithValue(toasts),
    ]);
    addTearDown(own.dispose);

    await tester.pumpWidget(_buildTestApp(own));
    await tester.pumpAndSettle();
    // 围绕世界原点缩放到 0.8：Cyber 起始边 400，卡片屏幕 y = 400 + 0.8 × (500 − 400) = 480。
    own.read(canvasTransformControllerProvider('cv1')).value = Matrix4.identity()
      ..translateByDouble(-0.8 * kStageHalf, -0.8 * kStageHalf, 0.0, 1.0)
      ..scaleByDouble(0.8, 0.8, 1.0, 1.0);
    await tester.pump();

    final card = find.byKey(ValueKey('node-card-$laned'));
    final Rect before = tester.getRect(card);
    expect(before.top, closeTo(480, 0.5), reason: '前置：卡片按 Cyber 的起始边锚定');

    final Finder dissolveKey = find.descendant(
      of: find.byType(LaneTitleBar).at(1),
      matching: find.byTooltip('Dissolve lane (keep nodes)'),
    );
    expect(dissolveKey, findsOneWidget);
    await tester.tap(dissolveKey);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing, reason: '解散不确认');
    expect(find.byType(LaneTitleBar), findsOneWidget, reason: 'Cyber 道没了');
    expect(nodes.rows[laned]!['lane_id'], isNull, reason: '库里清掉 lane_id');
    expect(own.read(canvasNodesControllerProvider('cv1')).valueOrNull!.single.laneId, isNull,
        reason: '内存同样是道外节点');
    final Rect after = tester.getRect(card);
    expect(after.left, closeTo(before.left, 0.5));
    expect(after.top, closeTo(before.top, 0.5), reason: '屏幕上原地不动');
    expect(after.width, closeTo(before.width, 0.5));
    expect(after.height, closeTo(before.height, 0.5));
    expect(toasts.titles, <String>['Lane “Cyber” dissolved']);
  });
}
