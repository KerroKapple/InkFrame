// InspectorStatusPanel 四态 widget 测试。
//
// error 态：断言展示本地化文案（generation* / error* ARB 键映射），
// 不再直出 toString / 裸错误码。

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/cost_breakdown_tooltip.dart';
import 'package:inkframe/features/canvas/widgets/inspector_status_panel.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/generation/services/node_cost.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/providers/wanx_image_provider.dart';

import '../../../_harness/test_app.dart';

void _noop() {}

/// 万相图像 batch 4：0.032 × 4 = 0.128。
final NodeCostEstimate _wanxBatch4 = NodeCostEstimate(
  providerId: kWanxImageCapabilities.providerId,
  usd: 0.128,
  costModel: kWanxImageCapabilities.costModel,
  batch: 4,
);

/// 鼠标停到「生成」按钮上并等 tooltip 淡入完；测试末尾移开、等收完，不留计时器。
Future<void> _hoverButton(WidgetTester tester, Future<void> Function() body) async {
  final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(find.byType(FilledButton)));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await body();
  await mouse.moveTo(Offset.zero);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// build() 直接吐预置列表的 JobsRegistry——用于 Binding 进度回读测试。
class _SeededRegistry extends JobsRegistry {
  _SeededRegistry(this._seed);
  final List<JobState> _seed;
  @override
  List<JobState> build() => _seed;
}

void main() {
  testWidgets('idle: 渲染 Generate 按钮；canSubmit=false 时 disabled', (tester) async {
    var pressed = 0;
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorSubmitIdle(),
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
        view: const InspectorSubmitIdle(),
        generateLabel: '生成',
        canSubmit: true,
        onSubmit: () => pressed++,
      ),
      locale: const Locale('zh'),
    );
    await tester.tap(find.byType(FilledButton));
    expect(pressed, 1);
  });

  testWidgets('idle 可点 + costEstimate → 悬停出明细', (tester) async {
    final AppLocalizations zh = lookupAppLocalizations(const Locale('zh'));
    await pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: InspectorStatusPanel(
            view: const InspectorSubmitIdle(),
            generateLabel: '生成',
            canSubmit: true,
            onSubmit: _noop,
            costEstimate: _wanxBatch4,
          ),
        ),
      ),
      locale: const Locale('zh'),
    );
    expect(find.byKey(CostBreakdownTooltip.contentKey), findsNothing, reason: '没悬停时不出');

    await _hoverButton(tester, () async {
      final Finder card = find.byKey(CostBreakdownTooltip.contentKey);
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(zh.costApprox(r'$0.13'))), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(zh.costFormulaBatch(r'$0.032', 4, r'$0.13'))),
        findsOneWidget,
      );
      expect(find.descendant(of: card, matching: find.text(zh.costBreakdownDisclaimer)), findsOneWidget);
    });
  });

  testWidgets('idle 不可点 → 只出置灰原因', (tester) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: InspectorStatusPanel(
            view: const InspectorSubmitIdle(),
            generateLabel: '生成',
            canSubmit: false,
            disabledReason: '请先填写提示词',
            onSubmit: _noop,
            costEstimate: _wanxBatch4,
          ),
        ),
      ),
      locale: const Locale('zh'),
    );
    expect(find.byType(CostBreakdownTooltip), findsNothing, reason: '置灰时按钮外面不包明细');

    await _hoverButton(tester, () async {
      expect(find.text('请先填写提示词'), findsOneWidget);
      expect(find.byKey(CostBreakdownTooltip.contentKey), findsNothing);
    });
  });

  testWidgets('submitting: 展示 spinner + "提交中…"', (tester) async {
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorSubmitSubmitting(),
        generateLabel: '生成',
        canSubmit: true,
        onSubmit: () {},
      ),
      locale: const Locale('zh'),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('提交中…'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('running 无 progress: indeterminate 进度条 + "生成中…"',
      (tester) async {
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorSubmitRunning(),
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
    expect(find.text('生成中…'), findsOneWidget);
  });

  testWidgets('running 带 progress: 进度条带值 + 百分号 label', (tester) async {
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorSubmitRunning(progress: 0.42),
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
    expect(find.text('生成中… 42%'), findsOneWidget);
  });

  testWidgets('error: missingApiKey → 本地化文案 + Retry 按钮可点', (tester) async {
    var retries = 0;
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorSubmitFailure(InspectorMissingApiKey()),
        generateLabel: '生成',
        canSubmit: true,
        onSubmit: () => retries++,
      ),
      locale: const Locale('zh'),
    );
    expect(find.text('生成失败'), findsOneWidget);
    expect(find.text('API Key 未配置'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });

  testWidgets('error: InkError → l10nError 文案，不直出 toString', (tester) async {
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorSubmitFailure(
          InspectorInkFailure(ProviderError(code: InkErrorCode.invalidKey)),
        ),
        generateLabel: 'Generate',
        canSubmit: true,
        onSubmit: () {},
      ),
    );
    expect(
      find.text('API key was rejected by the provider. Update it in Settings → API Keys.'),
      findsOneWidget,
    );
    expect(find.textContaining('InkError'), findsNothing);
    expect(find.textContaining('invalid_key'), findsNothing);
  });

  testWidgets('error: invalidConfig → 文案携带 reason placeholder', (tester) async {
    await pumpInkApp(
      tester,
      InspectorStatusPanel(
        view: const InspectorSubmitFailure(
          InspectorInvalidConfig('prompt is empty'),
        ),
        generateLabel: '生成',
        canSubmit: true,
        onSubmit: () {},
      ),
      locale: const Locale('zh'),
    );
    expect(find.text('配置无效：prompt is empty'), findsOneWidget);
  });

  testWidgets('Binding: 节点有活跃 running job → 展示该 job 的真实进度', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: InspectorStatusBinding(
          nodeId: 'n1',
          providerId: null,
          promptEmpty: false,
          generateLabel: 'Generate',
          disabledEmptyPromptText: 'empty',
          disabledNoKeyText: 'nokey',
          onSubmit: _noop,
        ),
      ),
      locale: const Locale('zh'),
      overrides: [
        jobsRegistryProvider.overrideWith(
          () => _SeededRegistry(const [
            JobState.running(
              jobId: 'j',
              providerId: 'p',
              canvasId: 'c',
              sourceNodeId: 'n1',
              progress: 0.5,
            ),
          ]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 1e-6));
    expect(find.text('生成中… 50%'), findsOneWidget);
    // 活跃 job 覆盖 idle → 不该再显示 Generate 按钮
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('Binding: 节点有终态 job（succeeded）→ 回落 idle，显示 Generate',
      (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: InspectorStatusBinding(
          nodeId: 'n1',
          providerId: null,
          promptEmpty: true,
          generateLabel: 'Generate',
          disabledEmptyPromptText: 'empty',
          disabledNoKeyText: 'nokey',
          onSubmit: _noop,
        ),
      ),
      overrides: [
        jobsRegistryProvider.overrideWith(
          () => _SeededRegistry(const [
            JobState.succeeded(
              jobId: 'j',
              providerId: 'p',
              canvasId: 'c',
              sourceNodeId: 'n1',
              artifactPath: 'a.png',
            ),
          ]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
