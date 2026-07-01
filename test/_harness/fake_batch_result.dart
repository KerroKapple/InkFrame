// 测试用 BatchResult 仓储 fake。
import 'package:inkframe/core/interfaces/batch_result_repository.dart';

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

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    final r = rows[id];
    if (r == null) return 0;
    rows[id] = <String, Object?>{...r, ...patch};
    return 1;
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
}
