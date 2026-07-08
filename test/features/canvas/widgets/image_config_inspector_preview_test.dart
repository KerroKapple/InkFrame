// ImageConfigInspector 预览框 + ignore-lane 开关 widget 测试。
// 仅验证 _PromptPreview 与 SwitchListTile 的行为；不测提交流程。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/image_config_inspector.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_repositories.dart';

// ── fakes ────────────────────────────────────────────────────────────────────

class _FakeStyleLaneRepo implements StyleLaneRepository {
  _FakeStyleLaneRepo(this._lane);
  final Map<String, Object?> _lane;

  @override
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = 400.0,
  }) async =>
      _lane['id']! as String;

  @override
  Future<Map<String, Object?>?> findById(String id) async =>
      id == _lane['id'] ? Map<String, Object?>.of(_lane) : null;

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      canvasId == _lane['canvas_id']
          ? [Map<String, Object?>.of(_lane)]
          : [];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 0;

  @override
  Future<int> hardDelete(String id) async => 1;
}

class _FakeCanvasRepo implements CanvasRepository {
  _FakeCanvasRepo({required this.prefix, required this.suffix});
  final String prefix;
  final String suffix;

  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async =>
      'canvas-1';

  @override
  Future<Map<String, Object?>?> findById(String id) async => {
        'id': id,
        'base_style_prefix': prefix,
        'base_style_suffix': suffix,
      };

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async =>
      [];

  @override
  Future<List<Map<String, Object?>>> listByProjects(
          List<String> projectIds) async =>
      [];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 0;

  @override
  Future<int> hardDelete(String id) async => 1;
}

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

// ── 测试夹具 ─────────────────────────────────────────────────────────────────

const _kCanvasId = 'canvas-1';
const _kLaneId = 'lane-1';
const _kNodeId = 'node-1';

final _kLaneRow = <String, Object?>{
  'id': _kLaneId,
  'canvas_id': _kCanvasId,
  'label': 'Day',
  'style_prompt': 'warm',
  'sort_order': 0,
  'tint_color': null,
  'size': 400.0,
};

const _kConfigNode = CanvasNode(
  id: _kNodeId,
  label: 'Test node',
  type: CanvasNodeType.image,
  role: NodeRole.config,
  canvasId: _kCanvasId,
  laneId: _kLaneId,
);

// ── 辅助 ─────────────────────────────────────────────────────────────────────

ProviderContainer _buildContainer({
  String basePrefix = 'cinematic',
  String baseSuffix = '',
}) {
  final laneRepo = _FakeStyleLaneRepo(_kLaneRow);
  final canvasRepo = _FakeCanvasRepo(prefix: basePrefix, suffix: baseSuffix);

  // 节点 repo：预置 config 节点行，让 canvasNodesControllerProvider 能读到它。
  // _PreloadedNodeRepository 封装 InMemoryNodeRepository，固定返回预置行。
  final configRow = <String, Object?>{
    'id': _kNodeId,
    'canvas_id': _kCanvasId,
    'type': 'image',
    'node_role': 'config',
    'label': 'Test node',
    'source_node_id': null,
    'lane_id': _kLaneId,
    'position_x': 0.0,
    'position_y': 0.0,
    'width': 200.0,
    'height': 160.0,
    'z_index': 0,
    'type_config': <String, Object?>{},
    'created_at': DateTime.now().toUtc(),
    'updated_at': DateTime.now().toUtc(),
    'deleted_at': null,
  };
  final fakeNodeRepo = _PreloadedNodeRepository(configRow, InMemoryNodeRepository());

  final edgeRepo = InMemoryEdgeRepository();

  return ProviderContainer(
    overrides: [
      // 泳道 repo → 提供 lane-1 数据
      styleLaneRepositoryProvider.overrideWith((ref) async => laneRepo),
      // 画布 repo → 提供 base prefix/suffix
      canvasRepositoryProvider.overrideWith((ref) async => canvasRepo),
      // 节点 repo → 预置 config 节点，让真实控制器加载到它
      nodeRepositoryProvider.overrideWith((ref) async => fakeNodeRepo),
      // 边 repo → 空列表
      edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
      // provider 列表 → 空（避免 PG 依赖链）
      providerCapabilitiesListProvider
          .overrideWith((ref) => const <ProviderCapabilities>[]),
      // secure storage → 假实现（避免命中平台 API）
      secureStorageServiceProvider
          .overrideWithValue(_FakeSecure()),
    ],
  );
}

/// 包装 InMemoryNodeRepository，listByCanvas 固定返回预置行，
/// patchTypeConfig / update / findById 走真实内存实现（先 upsert 预置行）。
class _PreloadedNodeRepository implements NodeRepository {
  _PreloadedNodeRepository(this._row, this._inner);
  final Map<String, Object?> _row;
  final InMemoryNodeRepository _inner;

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
      _inner.create(
        canvasId: canvasId,
        type: type,
        nodeRole: nodeRole,
        label: label,
        sourceNodeId: sourceNodeId,
        laneId: laneId,
        positionX: positionX,
        positionY: positionY,
        width: width,
        height: height,
        zIndex: zIndex,
        typeConfig: typeConfig,
      );

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    if (id == _row['id']) return Map<String, Object?>.of(_row);
    return _inner.findById(id);
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async {
    if (canvasId == _row['canvas_id']) {
      return [Map<String, Object?>.of(_row)];
    }
    return _inner.listByCanvas(canvasId);
  }

  @override
  Future<List<Map<String, Object?>>> listOrphanResults(
          String canvasId) async =>
      _inner.listOrphanResults(canvasId);

  @override
  Future<int> softDeleteEmptyOrphanResults() async =>
      _inner.softDeleteEmptyOrphanResults();

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    if (id == _row['id']) {
      _row.addAll(patch);
      return 1;
    }
    return _inner.update(id, patch);
  }

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    if (id == _row['id']) {
      final current = Map<String, Object?>.of(
          _row['type_config'] as Map<String, Object?>);
      current.addAll(patch);
      _row['type_config'] = current;
      return 1;
    }
    return _inner.patchTypeConfig(id, patch);
  }

  @override
  Future<int> softDelete(String id) async {
    if (id == _row['id']) {
      _row['deleted_at'] = DateTime.now().toUtc();
      return 1;
    }
    return _inner.softDelete(id);
  }

  @override
  Future<int> restore(String id) async {
    if (id == _row['id']) {
      _row['deleted_at'] = null;
      return 1;
    }
    return _inner.restore(id);
  }

  @override
  Future<int> hardDelete(String id) async {
    if (id == _row['id']) return 1;
    return _inner.hardDelete(id);
  }
}

// ── 主测试 ───────────────────────────────────────────────────────────────────

void main() {
  late ProviderContainer container;

  setUp(() {
    container = _buildContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ImageConfigInspector(node: _kConfigNode),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('输入 prompt 后预览包含 base 前缀和泳道风格', (tester) async {
    await pump(tester);

    // 在 prompt 输入框输入文字
    final promptField = find.byType(TextField).first;
    await tester.tap(promptField);
    await tester.enterText(promptField, 'cat');
    // 让防抖 Timer 触发，让假 repo 完成保存
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 预览区包含 cinematic（base 前缀）和 warm（泳道风格）
    expect(find.textContaining('cinematic'), findsWidgets);
    expect(find.textContaining('warm'), findsWidgets);
  });

  testWidgets('勾选 ignore-lane 后预览不包含泳道风格', (tester) async {
    await pump(tester);

    // 输入 prompt
    final promptField = find.byType(TextField).first;
    await tester.tap(promptField);
    await tester.enterText(promptField, 'cat');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 开启 ignore-lane 开关
    final switchWidget = find.byType(Switch);
    expect(switchWidget, findsOneWidget);
    await tester.tap(switchWidget);
    await tester.pumpAndSettle();

    // warm 应从预览消失；cinematic（base）仍在
    expect(find.textContaining('warm'), findsNothing,
        reason: 'ignore-lane 开启后泳道风格不应出现在预览中');
    expect(find.textContaining('cinematic'), findsWidgets);
  });

  testWidgets('显示 inspectorPromptPreviewLabel 标签', (tester) async {
    await pump(tester);
    expect(find.text('Final prompt preview'), findsOneWidget);
  });

  testWidgets('显示 inspectorIgnoreLaneStyle 标签', (tester) async {
    await pump(tester);
    expect(find.text('Ignore lane style'), findsOneWidget);
  });
}
