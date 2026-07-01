import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/shot_config_inspector.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('渲染标题 + 备注标签，水化 shot_notes', (tester) async {
    const node = CanvasNode(
      id: 's1',
      label: '',
      type: CanvasNodeType.shot,
      role: NodeRole.config,
      typeConfig: <String, Object?>{'shot_notes': 'wide establishing shot'},
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: ShotConfigInspector(node: node)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shot'), findsOneWidget);
    expect(find.text('Shot notes'), findsOneWidget);
    expect(find.text('wide establishing shot'), findsOneWidget);
  });
}
