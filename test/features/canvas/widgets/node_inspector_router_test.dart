// NodeInspectorRouter 按 node.type / role 分流：
//   - image + config → ImageConfigInspector
//   - video + config → VideoConfigInspector
//   - result / 其他 → 不渲染 Inspector

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/image_config_inspector.dart';
import 'package:inkframe/features/canvas/widgets/node_inspector_router.dart';
import 'package:inkframe/features/canvas/widgets/video_config_inspector.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('image 节点 → ImageConfigInspector', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.image,
      role: NodeRole.config,
    );
    await tester.pumpWidget(_host(const NodeInspectorRouter(node: node)));
    expect(find.byType(ImageConfigInspector), findsOneWidget);
    expect(find.byType(VideoConfigInspector), findsNothing);
  });

  testWidgets('video 节点 → VideoConfigInspector', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.config,
    );
    await tester.pumpWidget(_host(const NodeInspectorRouter(node: node)));
    expect(find.byType(VideoConfigInspector), findsOneWidget);
    expect(find.byType(ImageConfigInspector), findsNothing);
  });

  testWidgets('result 节点不渲染 Inspector', (tester) async {
    const node = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      sourceNodeId: 's1',
    );
    await tester.pumpWidget(_host(const NodeInspectorRouter(node: node)));
    expect(find.byType(ImageConfigInspector), findsNothing);
    expect(find.byType(VideoConfigInspector), findsNothing);
  });
}
