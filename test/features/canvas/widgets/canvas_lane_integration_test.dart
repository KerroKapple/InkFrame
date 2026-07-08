// 泳道集成测试：
//   (a) 有泳道时 LaneBackground 渲染进视图树。
//   (b) 节点拖拽后 moveNode 被调用并携带正确 lane_id（通过 fake repo 验证）。
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
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/lane_background.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

// ── fakes ──────────────────────────────────────────────────────────────────

/// NodeRepository fake：记录最后一次 update 参数。
class _FakeNodeRepository implements NodeRepository {
  Map<String, Object?>? lastUpdatePatch;
  String? lastUpdateId;

  // 一个预设节点，位于 (0, 0)，size 200×160。
  final _nodes = <Map<String, Object?>>[
    {
      'id': 'n1',
      'canvas_id': 'cv1',
      'type': 'image',
      'node_role': 'config',
      'label': 'test node',
      'position_x': 0.0,
      'position_y': 0.0,
      'width': 200.0,
      'height': 160.0,
      'z_index': 0,
      'type_config': <String, Object?>{},
    },
  ];

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      canvasId == 'cv1' ? List.of(_nodes) : const [];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    lastUpdateId = id;
    lastUpdatePatch = patch;
    return 1;
  }

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
  }) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>?> findById(String id) async =>
      _nodes.where((r) => r['id'] == id).cast<Map<String, Object?>?>().firstWhere((_) => true, orElse: () => null);

  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) async =>
      const [];

  @override
  Future<int> softDeleteEmptyOrphanResults() async => 0;

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async => 1;
}

/// EdgeRepository fake：无连线。
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
  }) => throw UnimplementedError();

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

/// StyleLaneRepository fake：一条泳道 size=400（横向时 y=0..400）。
class _FakeStyleLaneRepository implements StyleLaneRepository {
  static const _lane = <String, Object?>{
    'id': 'lane-1',
    'canvas_id': 'cv1',
    'label': 'Act 1',
    'style_prompt': 'warm',
    'sort_order': 0,
    'tint_color': null,
    'size': 400.0,
  };

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      canvasId == 'cv1' ? [Map.of(_lane)] : const [];

  @override
  Future<Map<String, Object?>?> findById(String id) async =>
      id == 'lane-1' ? Map.of(_lane) : null;

  @override
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = 400.0,
  }) => throw UnimplementedError();

  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async => 1;
}

/// CanvasRepository fake：横向方向。
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
  }) => throw UnimplementedError();

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

Widget _buildTestApp(ProviderContainer container) =>
    UncontrolledProviderScope(
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
  late _FakeNodeRepository fakeNodeRepo;
  late _FakeEdgeRepository fakeEdgeRepo;
  late _FakeStyleLaneRepository fakeLaneRepo;
  late _FakeCanvasRepository fakeCanvasRepo;
  late ProviderContainer container;

  setUp(() {
    fakeNodeRepo = _FakeNodeRepository();
    fakeEdgeRepo = _FakeEdgeRepository();
    fakeLaneRepo = _FakeStyleLaneRepository();
    fakeCanvasRepo = _FakeCanvasRepository();
    final tmp = Directory.systemTemp.createTempSync('ink_lane_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final paths = DefaultAppPaths.forRoot(tmp);
    container = ProviderContainer(overrides: [
      appPathsProvider.overrideWithValue(paths),
      currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
      nodeRepositoryProvider.overrideWith((ref) async => fakeNodeRepo),
      edgeRepositoryProvider.overrideWith((ref) async => fakeEdgeRepo),
      styleLaneRepositoryProvider.overrideWith((ref) async => fakeLaneRepo),
      canvasRepositoryProvider.overrideWith((ref) async => fakeCanvasRepo),
    ]);
    addTearDown(container.dispose);
  });

  // ── (a) LaneBackground 出现在视图树 ─────────────────────────────────────

  testWidgets('有泳道时 LaneBackground 渲染进 Stack', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    // 等待所有异步 provider 完成。
    await tester.pumpAndSettle();

    expect(find.byType(LaneBackground), findsOneWidget);
  });

  // ── (b) 拖拽落点 → lane_id 随 moveNode 写入 repo ───────────────────────

  testWidgets('节点拖拽后 NodeRepository.update 携带正确 lane_id', (tester) async {
    await tester.pumpWidget(_buildTestApp(container));
    await tester.pumpAndSettle();

    // 等待 lanes controller 加载。
    await container.read(canvasLanesControllerProvider('cv1').future);
    await tester.pump();

    // 直接调用 moveNode，不走 gesture（避免 InteractiveViewer scroll area 干扰）。
    // 节点在 (0,0)，size 200×160。
    // 节点中心拖拽到 delta=(0,100) 后新中心 = (100, 180)。
    // 泳道 lane-1: y=0..400，横向，180 落入 → lane_id = 'lane-1'。
    final lanes = container
        .read(canvasLanesControllerProvider('cv1'))
        .valueOrNull ?? const <StyleLane>[];
    const delta = Offset(0, 100);
    const nodePos = Offset(0, 0);
    const nodeSize = Size(200, 160);
    final center = nodePos + delta + Offset(nodeSize.width / 2, nodeSize.height / 2);
    final resolvedLaneId = laneIdAtPoint(
      point: center,
      lanes: [for (final l in lanes) (id: l.id, size: l.size)],
      direction: LaneDirection.horizontal,
    );
    expect(resolvedLaneId, 'lane-1',
        reason: '拖拽落点应落入 lane-1（y=0..400，中心 y=180）');

    await container
        .read(canvasNodesControllerProvider('cv1').notifier)
        .moveNode('n1', delta, laneId: resolvedLaneId);
    await tester.pump();

    expect(fakeNodeRepo.lastUpdateId, 'n1');
    expect(fakeNodeRepo.lastUpdatePatch?['lane_id'], 'lane-1');
    expect(fakeNodeRepo.lastUpdatePatch?['position_x'], 0.0);
    expect(fakeNodeRepo.lastUpdatePatch?['position_y'], 100.0);
  });

  // ── (c) 泳道外（越界）→ lane_id null ────────────────────────────────────

  test('laneIdAtPoint 越界返回 null（拖出泳道区）', () {
    // 泳道 size=400，拖到 y=500 → 越界。
    final id = laneIdAtPoint(
      point: const Offset(100, 500),
      lanes: const [(id: 'lane-1', size: 400.0)],
      direction: LaneDirection.horizontal,
    );
    expect(id, isNull);
  });
}
