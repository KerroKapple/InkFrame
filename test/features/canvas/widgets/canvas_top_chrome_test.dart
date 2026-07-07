// CanvasTopChrome：Studio 回归按钮 + breadcrumb 渲染 + 点击清空 currentCanvasIdProvider。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/widgets/canvas_top_chrome.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/test_app.dart';

// 导出按钮 watch 节点集合；fake 隔离 DB DI。
class _EmptyNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async =>
      const <CanvasNode>[];
}

void main() {
  testWidgets('top chrome 渲染 Studio 回归按钮 + breadcrumb', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: CanvasTopChrome(canvasName: 'Test Canvas'),
      ),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
        canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
      ],
    );
    await tester.pumpAndSettle();

    // canvasBackToStudio = "Studio" 字面值在 en + 多 locale 都是 "Studio"。
    expect(find.text('Studio'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Test Canvas'), findsOneWidget);
  });

  testWidgets('点击 Studio 按钮清空 currentCanvasIdProvider', (tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentCanvasIdProvider.notifier).state = 'c1';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(
            variant: InkThemeVariant.dark,
            textScale: 1,
          ),
          home: const Scaffold(
            body: CanvasTopChrome(canvasName: 'Test'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(currentCanvasIdProvider), 'c1');
    // DragToMoveArea has onDoubleTap, which delays single-tap recognition by
    // the kDoubleTapTimeout (300ms). Pump past it so the tap resolves.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(currentCanvasIdProvider), isNull);
  });
}
