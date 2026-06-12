// InkProgressBar 测试：统一细进度条组件（ME-19 提取，替代手搓 FractionallySizedBox）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/components/ink_progress_bar.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/test_app.dart';

void main() {
  testWidgets('确定态：渲染 LinearProgressIndicator 并 clamp 到 0..1',
      (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: Center(child: InkProgressBar(value: 1.7))),
    );
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 1.0);
  });

  testWidgets('不确定态：value 为 null', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: Center(child: InkProgressBar())),
    );
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, isNull);
    // 不确定态有持续动画，pump 固定帧避免挂起。
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('颜色来自主题 token：底 surface3 / 填充 cta', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: Center(child: InkProgressBar(value: 0.5))),
    );
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    final colors = InkColors.dark();
    expect(indicator.backgroundColor, colors.surface3);
    expect(
      (indicator.valueColor! as AlwaysStoppedAnimation<Color>).value,
      colors.cta,
    );
  });
}
