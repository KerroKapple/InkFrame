// GAP-4：批量 slot 失败可读化——error slot tile 的 Tooltip + danger 文案。
// errorCode 是 InkErrorCode 的 wire 字符串：wire → fromWire（容错）→ 本地化文案。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/batch_result_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/batch_results_grid.dart';

import '../../../_harness/test_app.dart';

const _kContentPolicyText = 'The content policy rejected this request.';
const _kUnknownText = 'An unknown error occurred.';

/// 仅实现 listByNode 的假仓储；其余方法非本用例路径，交由 noSuchMethod 抛错。
class _FakeBatchRepo implements BatchResultRepository {
  _FakeBatchRepo(this._rows);
  final List<Map<String, Object?>> _rows;

  @override
  Future<List<Map<String, Object?>>> listByNode(String nodeId) async => _rows;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Map<String, Object?> _row({
  required String status,
  String? errorCode,
  String? outputUrl,
}) => <String, Object?>{
  'id': 'b1',
  'node_id': 'n1',
  'job_id': 'j1',
  'slot_index': 0,
  'status': status,
  'error_code': errorCode,
  'output_url': outputUrl,
};

List<Override> _repo(List<Map<String, Object?>> rows) => <Override>[
  batchResultRepositoryProvider.overrideWith(
    (ref) async => _FakeBatchRepo(rows),
  ),
];

void main() {
  const resultNode = CanvasNode(
    id: 'n1',
    label: '',
    type: CanvasNodeType.image,
    role: NodeRole.result,
    sourceNodeId: 's1',
  );

  testWidgets('error slot（已知 errorCode wire）→ Tooltip + danger 文案', (
    tester,
  ) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: BatchResultsGrid(resultNode: resultNode)),
      overrides: _repo([_row(status: 'error', errorCode: 'content_policy')]),
    );
    await tester.pumpAndSettle();

    expect(find.text(_kContentPolicyText), findsOneWidget);
    expect(find.byTooltip(_kContentPolicyText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error slot（未知 wire）→ 回退 errorUnknown，不抛异常', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: BatchResultsGrid(resultNode: resultNode)),
      overrides: _repo([
        _row(status: 'error', errorCode: 'totally_bogus_wire'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text(_kUnknownText), findsOneWidget);
    expect(find.byTooltip(_kUnknownText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error slot（errorCode 缺失）→ 回退 errorUnknown', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: BatchResultsGrid(resultNode: resultNode)),
      overrides: _repo([_row(status: 'error')]),
    );
    await tester.pumpAndSettle();

    expect(find.text(_kUnknownText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('success slot → 无 error 文案 / Tooltip', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: BatchResultsGrid(resultNode: resultNode)),
      overrides: _repo([_row(status: 'success', outputUrl: 'images/a.png')]),
    );
    await tester.pumpAndSettle();

    expect(find.text(_kContentPolicyText), findsNothing);
    expect(find.text(_kUnknownText), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
