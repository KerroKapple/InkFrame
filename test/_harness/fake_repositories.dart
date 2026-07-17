// InMemoryXxxRepository：4 个 repository 的内存实现，吃掉 PG 依赖。
//
// 用于 controller / service 层单测——不再需要起真 PG。
// 行级数据用 `Map<String, Object?>`，与真实现保持同样的"raw row"语义。
//
// 不做事务、不做 cascade、不做 SQL 约束校验——这些是 PG 集成测的活
// （见 test/storage/repositories/postgres_repositories_integration_test.dart）。

import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';

int _idSeq = 0;
String _newId(String prefix) {
  _idSeq += 1;
  return '$prefix-$_idSeq';
}

DateTime _utcNow() => DateTime.now().toUtc();

// ─── Project ─────────────────────────────────────────────────────────

class InMemoryProjectRepository implements ProjectRepository {
  final Map<String, Map<String, Object?>> _rows = <String, Map<String, Object?>>{};

  /// 直接访问 raw store——断言用。
  Map<String, Map<String, Object?>> get rows =>
      Map<String, Map<String, Object?>>.unmodifiable(_rows);

  @override
  Future<String> create({required String name, String? coverNodeId}) async {
    final String id = _newId('proj');
    _rows[id] = <String, Object?>{
      'id': id,
      'name': name,
      'cover_node_id': coverNodeId,
      'created_at': _utcNow(),
      'updated_at': _utcNow(),
      'deleted_at': null,
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return null;
    return Map<String, Object?>.of(row);
  }

  @override
  Future<List<Map<String, Object?>>> listAll() async {
    final List<Map<String, Object?>> alive = _rows.values
        .where((r) => r['deleted_at'] == null)
        .map(Map<String, Object?>.of)
        .toList();
    alive.sort((a, b) =>
        (b['created_at'] as DateTime).compareTo(a['created_at'] as DateTime));
    return alive;
  }

  @override
  Future<List<Map<String, Object?>>> listTrashed() async {
    return _rows.values
        .where((r) => r['deleted_at'] != null)
        .map(Map<String, Object?>.of)
        .toList();
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null) return 0;
    row.addAll(patch);
    row['updated_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> softDelete(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return 0;
    row['deleted_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> restore(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] == null) return 0;
    row['deleted_at'] = null;
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async {
    return _rows.remove(id) == null ? 0 : 1;
  }
}

// ─── Canvas ──────────────────────────────────────────────────────────

class InMemoryCanvasRepository implements CanvasRepository {
  final Map<String, Map<String, Object?>> _rows = <String, Map<String, Object?>>{};

  Map<String, Map<String, Object?>> get rows =>
      Map<String, Map<String, Object?>>.unmodifiable(_rows);

  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async {
    final String id = _newId('canvas');
    _rows[id] = <String, Object?>{
      'id': id,
      'project_id': projectId,
      'name': name,
      'base_style_prefix': baseStylePrefix,
      'base_style_suffix': baseStyleSuffix,
      'created_at': _utcNow(),
      'updated_at': _utcNow(),
      'deleted_at': null,
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return null;
    return Map<String, Object?>.of(row);
  }

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async {
    final List<Map<String, Object?>> alive = _rows.values
        .where(
            (r) => r['project_id'] == projectId && r['deleted_at'] == null)
        .map(Map<String, Object?>.of)
        .toList();
    alive.sort((a, b) =>
        (a['created_at'] as DateTime).compareTo(b['created_at'] as DateTime));
    return alive;
  }

  @override
  Future<List<Map<String, Object?>>> listByProjects(
      List<String> projectIds) async {
    final Set<String> wanted = projectIds.toSet();
    final List<Map<String, Object?>> alive = _rows.values
        .where((r) =>
            wanted.contains(r['project_id']) && r['deleted_at'] == null)
        .map(Map<String, Object?>.of)
        .toList();
    alive.sort((a, b) {
      final int byProject =
          (a['project_id']! as String).compareTo(b['project_id']! as String);
      if (byProject != 0) return byProject;
      return (a['created_at'] as DateTime)
          .compareTo(b['created_at'] as DateTime);
    });
    return alive;
  }

  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(
      String projectId) async {
    final List<Map<String, Object?>> trashed = _rows.values
        .where(
            (r) => r['project_id'] == projectId && r['deleted_at'] != null)
        .map(Map<String, Object?>.of)
        .toList();
    trashed.sort((a, b) =>
        (b['deleted_at'] as DateTime).compareTo(a['deleted_at'] as DateTime));
    return trashed;
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null) return 0;
    row.addAll(patch);
    row['updated_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> softDelete(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return 0;
    row['deleted_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> restore(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] == null) return 0;
    row['deleted_at'] = null;
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async {
    return _rows.remove(id) == null ? 0 : 1;
  }
}

// ─── Node ────────────────────────────────────────────────────────────

class InMemoryNodeRepository implements NodeRepository {
  final Map<String, Map<String, Object?>> _rows = <String, Map<String, Object?>>{};

  Map<String, Map<String, Object?>> get rows =>
      Map<String, Map<String, Object?>>.unmodifiable(_rows);

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
  }) async {
    final String id = _newId('node');
    _rows[id] = <String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'type': type,
      'node_role': nodeRole,
      'label': label,
      'source_node_id': sourceNodeId,
      'lane_id': laneId,
      'position_x': positionX,
      'position_y': positionY,
      'width': width,
      'height': height,
      'z_index': zIndex,
      'type_config': Map<String, Object?>.of(typeConfig),
      'created_at': _utcNow(),
      'updated_at': _utcNow(),
      'deleted_at': null,
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return null;
    return Map<String, Object?>.of(row);
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async {
    return _rows.values
        .where((r) => r['canvas_id'] == canvasId && r['deleted_at'] == null)
        .map(Map<String, Object?>.of)
        .toList();
  }

  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) async {
    return _rows.values
        .where((r) =>
            r['canvas_id'] == canvasId &&
            r['deleted_at'] == null &&
            r['source_node_id'] == null &&
            r['node_role'] == 'result')
        .map(Map<String, Object?>.of)
        .toList();
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null) return 0;
    row.addAll(patch);
    row['updated_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null) return 0;
    final Map<String, Object?> current =
        Map<String, Object?>.of(row['type_config'] as Map<String, Object?>);
    current.addAll(patch);
    row['type_config'] = current;
    row['updated_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> softDelete(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return 0;
    row['deleted_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> restore(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] == null) return 0;
    row['deleted_at'] = null;
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async {
    return _rows.remove(id) == null ? 0 : 1;
  }

  @override
  Future<int> softDeleteEmptyOrphanResults() async {
    // LB-14 真实过滤逻辑：node_role='result' 且未删、3 个 url 键皆空的壳软删。
    // 本内存仓储不持有 batch_results / jobs，故成功 slot / 在途 job 两道守卫
    // 在此库上恒成立（无相关数据）——url 空判据部分与真库同语义。
    int count = 0;
    for (final Map<String, Object?> row in _rows.values) {
      if (row['deleted_at'] != null) continue;
      if (row['node_role'] != 'result') continue;
      final Map<String, Object?> cfg =
          (row['type_config'] as Map<String, Object?>?) ??
              const <String, Object?>{};
      if (_blank(cfg['image_url']) &&
          _blank(cfg['video_url']) &&
          _blank(cfg['thumbnail_url'])) {
        row['deleted_at'] = _utcNow();
        row['updated_at'] = _utcNow();
        count += 1;
      }
    }
    return count;
  }

  // COALESCE(->>'x','') = '' 语义：JSON 文本值为 null 或空串即视为空。
  bool _blank(Object? v) => v == null || v == '';

  @override
  Future<List<String>> listAllMediaUrls() async {
    // LB-13：含软删节点（不过滤 deleted_at）——软删产物仍算被引用（安全#2）。
    final out = <String>[];
    for (final Map<String, Object?> row in _rows.values) {
      final Map<String, Object?> cfg =
          (row['type_config'] as Map<String, Object?>?) ??
              const <String, Object?>{};
      for (final key in const ['image_url', 'video_url', 'thumbnail_url']) {
        final v = cfg[key];
        if (v is String && v.isNotEmpty) out.add(v);
      }
    }
    return out;
  }
}

// ─── StyleLane ───────────────────────────────────────────────────────

class InMemoryStyleLaneRepository implements StyleLaneRepository {
  final Map<String, Map<String, Object?>> _rows =
      <String, Map<String, Object?>>{};

  Map<String, Map<String, Object?>> get rows =>
      Map<String, Map<String, Object?>>.unmodifiable(_rows);

  @override
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = 400.0,
  }) async {
    final String id = _newId('lane');
    _rows[id] = <String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'label': label,
      'style_prompt': stylePrompt,
      'sort_order': sortOrder,
      'tint_color': tintColor,
      'size': size,
      'created_at': _utcNow(),
      'updated_at': _utcNow(),
      'deleted_at': null,
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return null;
    return Map<String, Object?>.of(row);
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async {
    return _rows.values
        .where((r) => r['canvas_id'] == canvasId && r['deleted_at'] == null)
        .map(Map<String, Object?>.of)
        .toList();
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null) return 0;
    row.addAll(patch);
    row['updated_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> softDelete(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return 0;
    row['deleted_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> restore(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] == null) return 0;
    row['deleted_at'] = null;
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async => _rows.remove(id) == null ? 0 : 1;
}

// ─── Edge ────────────────────────────────────────────────────────────

class InMemoryEdgeRepository implements EdgeRepository {
  final Map<String, Map<String, Object?>> _rows = <String, Map<String, Object?>>{};

  Map<String, Map<String, Object?>> get rows =>
      Map<String, Map<String, Object?>>.unmodifiable(_rows);

  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) async {
    final String id = _newId('edge');
    _rows[id] = <String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
      'edge_type': edgeType,
      'role': role,
      'sort_order': sortOrder,
      'created_at': _utcNow(),
      'updated_at': _utcNow(),
      'deleted_at': null,
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return null;
    return Map<String, Object?>.of(row);
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async {
    return _rows.values
        .where((r) => r['canvas_id'] == canvasId && r['deleted_at'] == null)
        .map(Map<String, Object?>.of)
        .toList();
  }

  @override
  Future<List<Map<String, Object?>>> listOutgoing(String sourceNodeId) async {
    return _rows.values
        .where((r) =>
            r['source_node_id'] == sourceNodeId && r['deleted_at'] == null)
        .map(Map<String, Object?>.of)
        .toList();
  }

  @override
  Future<List<Map<String, Object?>>> listIncoming(String targetNodeId) async {
    return _rows.values
        .where((r) =>
            r['target_node_id'] == targetNodeId && r['deleted_at'] == null)
        .map(Map<String, Object?>.of)
        .toList();
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null) return 0;
    row.addAll(patch);
    row['updated_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> softDelete(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] != null) return 0;
    row['deleted_at'] = _utcNow();
    return 1;
  }

  @override
  Future<int> restore(String id) async {
    final Map<String, Object?>? row = _rows[id];
    if (row == null || row['deleted_at'] == null) return 0;
    row['deleted_at'] = null;
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async {
    return _rows.remove(id) == null ? 0 : 1;
  }
}
