// LB-06：批量结果读侧的 AsyncValue error 态。
// 此前 valueOrNull ?? [] 把加载失败静默降级为空 → 面板/网格假装"无结果"。
// 现在错误必须落成 InkErrorBanner（走 l10nError 文案）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/batch_results_grid.dart';
import 'package:inkframe/features/canvas/widgets/image_result_inspector.dart';
import 'package:inkframe/theme/components/ink_error_banner.dart';

import '../../../_harness/test_app.dart';

const _kLocalIoText = 'Local disk I/O error. Check space and permissions.';

/// 让 batchResultsControllerProvider.build 落错误态：底层仓储 future 抛 InkError。
List<Override> _failingBatchRepo() => <Override>[
  batchResultRepositoryProvider.overrideWith(
    (ref) async => throw const LocalIOError(),
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

  testWidgets('BatchResultsGrid：slot 加载失败 → 错误横幅（非空白）', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: BatchResultsGrid(resultNode: resultNode)),
      overrides: _failingBatchRepo(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InkErrorBanner), findsOneWidget);
    expect(find.text(_kLocalIoText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ImageResultInspector：加载失败 → 面板浮出并渲染错误横幅', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: ImageResultInspector(node: resultNode)),
      overrides: _failingBatchRepo(),
    );
    await tester.pumpAndSettle();

    // 此前 error 会让整块面板 shrink（空白）；现在面板浮出并交由网格渲染错误。
    expect(find.byType(BatchResultsGrid), findsOneWidget);
    expect(find.byType(InkErrorBanner), findsOneWidget);
    expect(find.text(_kLocalIoText), findsOneWidget);
  });
}
