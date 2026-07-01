import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/batch_result.dart';

void main() {
  test('fromRow 全字段 + isSuccess/isError', () {
    final b = BatchResult.fromRow(<String, Object?>{
      'id': 'b1',
      'node_id': 'n1',
      'job_id': 'j1',
      'slot_index': 2,
      'status': 'success',
      'output_url': 'images/a.png',
      'thumbnail_url': 'images/a-t.png',
      'width': 512,
      'height': 768,
      'seed': 42,
      'promoted': true,
      'promoted_node_id': 'p9',
    });
    expect(b.id, 'b1');
    expect(b.nodeId, 'n1');
    expect(b.jobId, 'j1');
    expect(b.slotIndex, 2);
    expect(b.isSuccess, isTrue);
    expect(b.isError, isFalse);
    expect(b.outputUrl, 'images/a.png');
    expect(b.thumbnailUrl, 'images/a-t.png');
    expect(b.width, 512);
    expect(b.height, 768);
    expect(b.seed, 42);
    expect(b.promoted, isTrue);
    expect(b.promotedNodeId, 'p9');
  });

  test('fromRow 缺省 + isError', () {
    final b = BatchResult.fromRow(<String, Object?>{
      'id': 'b1',
      'node_id': 'n1',
      'job_id': 'j1',
      'status': 'error',
    });
    expect(b.slotIndex, 0);
    expect(b.isError, isTrue);
    expect(b.isSuccess, isFalse);
    expect(b.outputUrl, isNull);
    expect(b.promoted, isFalse);
  });

  test('== / hashCode', () {
    const a = BatchResult(
      id: 'b1',
      nodeId: 'n1',
      jobId: 'j1',
      slotIndex: 0,
      status: 'success',
    );
    const same = BatchResult(
      id: 'b1',
      nodeId: 'n1',
      jobId: 'j1',
      slotIndex: 0,
      status: 'success',
    );
    const diff = BatchResult(
      id: 'b1',
      nodeId: 'n1',
      jobId: 'j1',
      slotIndex: 0,
      status: 'error',
    );
    expect(a, same);
    expect(a.hashCode, same.hashCode);
    expect(a == diff, isFalse);
  });
}
