// 测试用 BatchResult 仓储 fake。
import 'package:inkframe/core/interfaces/batch_result_repository.dart';

DateTime _dt(Object? v) => switch (v) {
  final DateTime d => d,
  final String s =>
    DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
};

class FakeBatchResultRepo implements BatchResultRepository {
  FakeBatchResultRepo([Map<String, Map<String, Object?>>? rows])
    : rows = rows ?? <String, Map<String, Object?>>{};

  final Map<String, Map<String, Object?>> rows;
  final List<String> promotedIds = <String>[];

  @override
  Future<String> create({
    required String nodeId,
    required String jobId,
    required int slotIndex,
    required String status,
  }) async {
    final id = 'b${rows.length + 1}';
    rows[id] = <String, Object?>{
      'id': id,
      'node_id': nodeId,
      'job_id': jobId,
      'slot_index': slotIndex,
      'status': status,
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => rows[id];

  @override
  Future<Map<String, Object?>?> findBySlot(String nodeId, int slotIndex) async {
    for (final r in rows.values) {
      if (r['node_id'] == nodeId && r['slot_index'] == slotIndex) return r;
    }
    return null;
  }

  @override
  Future<List<Map<String, Object?>>> listByNode(String nodeId) async {
    final l = rows.values.where((r) => r['node_id'] == nodeId).toList();
    l.sort(
      (a, b) => (a['slot_index'] as int).compareTo(b['slot_index'] as int),
    );
    return l;
  }

  /// join 派生列（canvas_id / project_id / created_at）由测试种子行直接提供。
  @override
  Future<List<Map<String, Object?>>> listSuccessByProject(
    String projectId,
  ) async {
    final l = rows.values
        .where(
          (r) => r['project_id'] == projectId && r['status'] == 'success',
        )
        .map(Map<String, Object?>.of)
        .toList();
    l.sort((a, b) => _dt(b['created_at']).compareTo(_dt(a['created_at'])));
    return l;
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    final r = rows[id];
    if (r == null) return 0;
    rows[id] = <String, Object?>{...r, ...patch};
    return 1;
  }

  @override
  Future<int> finalizePendingByJob(
    String jobId, {
    required String toStatus,
    String? errorCode,
  }) async {
    var n = 0;
    for (final id in rows.keys.toList()) {
      final r = rows[id]!;
      if (r['job_id'] == jobId && r['status'] == 'generating') {
        rows[id] = <String, Object?>{
          ...r,
          'status': toStatus,
          'error_code': ?errorCode,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        };
        n++;
      }
    }
    return n;
  }

  @override
  Future<int> finalizeAllPending({
    required String toStatus,
    String? errorCode,
  }) async {
    var n = 0;
    for (final id in rows.keys.toList()) {
      final r = rows[id]!;
      if (r['status'] == 'generating') {
        rows[id] = <String, Object?>{
          ...r,
          'status': toStatus,
          'error_code': ?errorCode,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        };
        n++;
      }
    }
    return n;
  }

  @override
  Future<int> markPromoted({
    required String id,
    required String promotedNodeId,
  }) async {
    promotedIds.add(id);
    final r = rows[id];
    if (r != null) {
      rows[id] = <String, Object?>{
        ...r,
        'promoted': true,
        'promoted_node_id': promotedNodeId,
      };
    }
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async {
    rows.remove(id);
    return 1;
  }

  @override
  Future<List<String>> listAllOutputUrls() async {
    final out = <String>[];
    for (final r in rows.values) {
      final v = r['output_url'];
      if (v is String && v.isNotEmpty) out.add(v);
    }
    return out;
  }
}
