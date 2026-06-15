// CanvasNodeCard 最小测试：渲染类型标签 + 标题 + ID/分辨率行。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_node_card.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('CanvasNodeCard shows type label + title + id + resolution',
      (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: CanvasNodeCard(
          type: CanvasNodeType.character,
          title: 'Elara',
          id: 'chr_0042',
          resolution: '1024x576',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Elara'), findsOneWidget);
    expect(find.text('Character'), findsOneWidget);
    expect(find.text('chr_0042'), findsOneWidget);
    expect(find.text('1024x576'), findsOneWidget);
  });

  testWidgets('标题字号跟随 a11y textScale（HI-24 回归）', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: CanvasNodeCard(
          type: CanvasNodeType.character,
          title: 'Elara',
          id: 'chr_0042',
          resolution: '1024x576',
        ),
      ),
      textScale: 1.5,
    );
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('Elara'));
    // headlineSm 18 × 1.5 —— 不再被 copyWith(fontSize) 钉死
    expect(title.style?.fontSize, 18 * 1.5);
    // 类型标签走 monoNano token，等宽字体不再硬编码在 widget 内
    final label = tester.widget<Text>(find.text('Character'));
    expect(label.style?.fontFamily, 'JetBrainsMono');
    expect(label.style?.fontSize, 9 * 1.5);
  });
}
