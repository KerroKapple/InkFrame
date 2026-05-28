// InspectorStatusPanel 四态 widget 测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/inspector_status_panel.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('idle: 渲染 Generate 按钮；canSubmit=false 时 disabled', (tester) async {
    var pressed = 0;
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorJobIdle(),
        generateLabel: '生成',
        canSubmit: false,
        disabledReason: '请先填写提示词',
        onSubmit: () => pressed++,
      ),
      locale: const Locale('zh'),
    );
    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
    expect(find.text('生成'), findsOneWidget);
    expect(pressed, 0);
  });

  testWidgets('idle: canSubmit=true 时点击触发 onSubmit', (tester) async {
    var pressed = 0;
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorJobIdle(),
        generateLabel: '生成',
        canSubmit: true,
        onSubmit: () => pressed++,
      ),
      locale: const Locale('zh'),
    );
    await tester.tap(find.byType(FilledButton));
    expect(pressed, 1);
  });

  testWidgets('submitting: 展示 spinner + "提交中..."', (tester) async {
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorJobSubmitting(),
        generateLabel: '生成',
        canSubmit: true,
        onSubmit: () {},
      ),
      locale: const Locale('zh'),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('提交中...'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('running 无 progress: indeterminate 进度条 + "生成中..."',
      (tester) async {
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorJobRunning(),
        generateLabel: '生成',
        canSubmit: true,
        onSubmit: () {},
      ),
      locale: const Locale('zh'),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNull);
    expect(find.text('生成中...'), findsOneWidget);
  });

  testWidgets('running 带 progress: 进度条带值 + 百分号 label', (tester) async {
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorJobRunning(progress: 0.42),
        generateLabel: '生成',
        canSubmit: true,
        onSubmit: () {},
      ),
      locale: const Locale('zh'),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.42, 1e-6));
    expect(find.text('生成中... 42%'), findsOneWidget);
  });

  testWidgets('error: 展示标题 + code + Retry 按钮可点', (tester) async {
    var retries = 0;
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorJobError(code: 'invalidKey'),
        generateLabel: '生成',
        canSubmit: true,
        onSubmit: () => retries++,
      ),
      locale: const Locale('zh'),
    );
    expect(find.text('生成失败'), findsOneWidget);
    expect(find.text('invalidKey'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });
}
