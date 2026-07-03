// FakeBatchResultRepo 收敛行为契约：finalizePendingByJob / finalizeAllPending
// 只翻 'generating' slot；终态 slot（success/error/cancelled）不动。
import 'package:flutter_test/flutter_test.dart';

import 'fake_batch_result.dart';

void main() {
  late FakeBatchResultRepo repo;

  setUp(() async {
    repo = FakeBatchResultRepo();
    await repo.create(nodeId: 'n1', jobId: 'j1', slotIndex: 0, status: 'success');
    await repo.create(nodeId: 'n1', jobId: 'j1', slotIndex: 1, status: 'generating');
    await repo.create(nodeId: 'n1', jobId: 'j1', slotIndex: 2, status: 'generating');
    await repo.create(nodeId: 'n2', jobId: 'j2', slotIndex: 0, status: 'generating');
  });

  Map<String, Object?> slot(String jobId, int index) => repo.rows.values
      .firstWhere((r) => r['job_id'] == jobId && r['slot_index'] == index);

  test('finalizePendingByJob：只收敛该 job 的 generating slot，返回行数', () async {
    final n = await repo.finalizePendingByJob(
      'j1',
      toStatus: 'cancelled',
      errorCode: 'cancelled_by_user',
    );

    expect(n, 2);
    expect(slot('j1', 0)['status'], 'success', reason: '终态 slot 不动');
    expect(slot('j1', 1)['status'], 'cancelled');
    expect(slot('j1', 1)['error_code'], 'cancelled_by_user');
    expect(slot('j1', 1)['completed_at'], isNotNull);
    expect(slot('j1', 2)['status'], 'cancelled');
    expect(slot('j2', 0)['status'], 'generating', reason: '别的 job 不动');
  });

  test('finalizePendingByJob：errorCode 缺省时不写 error_code', () async {
    await repo.finalizePendingByJob('j1', toStatus: 'error');
    expect(slot('j1', 1)['status'], 'error');
    expect(slot('j1', 1)['error_code'], isNull);
  });

  test('finalizePendingByJob：无 generating slot → 0 行', () async {
    await repo.finalizePendingByJob('j1', toStatus: 'error');
    final n = await repo.finalizePendingByJob('j1', toStatus: 'cancelled');
    expect(n, 0);
  });

  test('finalizeAllPending：全表 generating 收敛（跨 job），终态不动', () async {
    final n = await repo.finalizeAllPending(
      toStatus: 'cancelled',
      errorCode: 'cancelled_on_exit',
    );

    expect(n, 3);
    expect(slot('j1', 0)['status'], 'success');
    expect(slot('j1', 1)['status'], 'cancelled');
    expect(slot('j2', 0)['status'], 'cancelled');
    expect(slot('j2', 0)['error_code'], 'cancelled_on_exit');
  });

  test('listSuccessByProject：按 project_id 过滤 success，created_at 倒序', () async {
    // join 派生列（canvas_id/project_id/created_at）由种子行直接提供
    repo.rows.addAll(<String, Map<String, Object?>>{
      'a': <String, Object?>{
        'id': 'a',
        'node_id': 'n1',
        'job_id': 'j1',
        'slot_index': 0,
        'status': 'success',
        'output_url': 'images/a.png',
        'project_id': 'p1',
        'canvas_id': 'c1',
        'created_at': DateTime.utc(2026, 1, 1),
      },
      'b': <String, Object?>{
        'id': 'b',
        'node_id': 'n1',
        'job_id': 'j1',
        'slot_index': 1,
        'status': 'success',
        'output_url': 'images/b.png',
        'project_id': 'p1',
        'canvas_id': 'c1',
        'created_at': DateTime.utc(2026, 1, 2),
      },
      'err': <String, Object?>{
        'id': 'err',
        'node_id': 'n1',
        'job_id': 'j1',
        'slot_index': 2,
        'status': 'error',
        'project_id': 'p1',
        'canvas_id': 'c1',
        'created_at': DateTime.utc(2026, 1, 3),
      },
      'other': <String, Object?>{
        'id': 'other',
        'node_id': 'n9',
        'job_id': 'j9',
        'slot_index': 0,
        'status': 'success',
        'output_url': 'images/x.png',
        'project_id': 'p2',
        'canvas_id': 'c9',
        'created_at': DateTime.utc(2026, 1, 4),
      },
    });

    final l = await repo.listSuccessByProject('p1');

    expect(l.map((r) => r['id']).toList(), <String>['b', 'a']);
    // setUp 里无 project_id 的 success 行不混入
    expect(await repo.listSuccessByProject('p9'), isEmpty);
  });
}
