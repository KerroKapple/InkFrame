// 提示词条的花费预告（TakesCost 稿「花费预告」）：「生成」左侧常驻金额 + 悬停「生成」出明细卡。
//
// 钉的几件：
//   - 已知价目写「约 $0.13」，自定义接口（perCall 0）写「—」，不再出现 $0.00；
//   - 「生成」可点时悬停出明细卡（含计价式与「以服务商账单为准」），明细包在按钮外面；
//   - 按钮置灰（没 Key）时悬停只出原有原因，不叠明细；
//   - 金额随输入框当前内容即时变，不等防抖落库（这里的提交控制器根本不落库）。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/models/provider_protocol_template.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';
import 'package:inkframe/features/canvas/widgets/cost_breakdown_tooltip.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/providers/wanx_image_provider.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../../../_harness/test_app.dart';

final ProviderCapabilities _custom = kOpenAIImageTemplateCapabilities.copyWith(
  providerId: 'custom:acme',
  displayName: 'Acme',
);

/// 手搭的按字计价：单价放大到打几十个字就能在两位小数上看出差别（真实 Gemini 每千字 0.000075，测不出东西）。
final ProviderCapabilities _perChar = kWanxImageCapabilities.copyWith(
  providerId: 'per-char',
  displayName: 'PerChar',
  costModel: const CostModel.perCharInput(usdPerKChar: 10.0, usdPerImageOutput: 0.01),
);

final List<ProviderCapabilities> _caps = <ProviderCapabilities>[kWanxImageCapabilities, _custom, _perChar];

CanvasNode _node(Map<String, Object?> tc) => CanvasNode(
      id: 'n1',
      label: 'Shot',
      type: CanvasNodeType.image,
      canvasId: 'cv1',
      typeConfig: tc,
    );

final CanvasNode _wanxBatch4 =
    _node(<String, Object?>{'prompt': 'a cat', 'provider_id': 'wanx-image', 'batch_size': 4});

class _Nodes extends CanvasNodesController {
  _Nodes(this.node);
  final CanvasNode node;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[node];
}

class _Selected extends CanvasSelectionController {
  @override
  Set<String> build(String canvasId) => <String>{'n1'};
}

/// 只记终稿、打字不落库：金额要是还跟着变，只能是走了 pending。
class _RecordingSubmit extends InspectorSubmitController {
  static final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<void> submit(Map<String, Object?> finalConfig) async =>
      calls.add(finalConfig);

  @override
  void savePromptDebounced(String prompt) {}
}

/// [keyed] = 配了 Key 的供应商集合。
Future<void> _pump(
  WidgetTester tester,
  CanvasNode node, {
  Set<String> keyed = const <String>{'wanx-image', 'custom:acme', 'per-char'},
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasPromptBar(canvasId: 'cv1')),
    locale: const Locale('zh'),
    surfaceSize: const Size(900, 500),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
      canvasNodesControllerProvider.overrideWith(() => _Nodes(node)),
      canvasSelectionControllerProvider.overrideWith(_Selected.new),
      inspectorSubmitControllerProvider.overrideWith(_RecordingSubmit.new),
      inspectorHasApiKeyProvider.overrideWith(
        (ref, String providerId) async => keyed.contains(providerId),
      ),
      preferencesServiceProvider.overrideWithValue(InMemoryPreferencesService()),
      providerCapabilitiesListProvider.overrideWithValue(_caps),
    ],
  );
  await tester.pumpAndSettle();
}

String? _amount(WidgetTester tester) {
  final Finder f = find.byKey(CanvasPromptBar.costKey);
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f).data;
}

/// 鼠标停到「生成」上，等 tooltip 淡入完。返回的手势在测试末尾移开。
Future<TestGesture> _hoverGenerate(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(find.byKey(CanvasPromptBar.generateKey)));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return mouse;
}

/// 移开鼠标并等 tooltip 收完，不留计时器。
Future<void> _leave(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(Offset.zero);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  final AppLocalizations zh = lookupAppLocalizations(const Locale('zh'));

  setUp(_RecordingSubmit.calls.clear);

  testWidgets(r'已知价目：生成按钮左侧写「约 $0.13」', (tester) async {
    await _pump(tester, _wanxBatch4);

    expect(_amount(tester), zh.costApprox(r'$0.13'));
    // 金额在「生成」左边。
    expect(
      tester.getRect(find.byKey(CanvasPromptBar.costKey)).right,
      lessThanOrEqualTo(tester.getRect(find.byKey(CanvasPromptBar.generateKey)).left),
    );
  });

  testWidgets(r'自定义接口：写「—」，不出现 $0.00', (tester) async {
    await _pump(tester, _node(<String, Object?>{'prompt': 'a cat', 'provider_id': 'custom:acme'}));

    expect(_amount(tester), '—');
    expect(find.textContaining(r'$0.00'), findsNothing);
    // 「—」自己挂「价格未知」。
    expect(
      find.ancestor(of: find.byKey(CanvasPromptBar.costKey), matching: find.byType(Tooltip)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Tooltip>(
            find.ancestor(of: find.byKey(CanvasPromptBar.costKey), matching: find.byType(Tooltip)),
          )
          .message,
      zh.costUnknown,
    );
  });

  testWidgets('悬停生成按钮出明细：含「以服务商账单为准」与计价式', (tester) async {
    await _pump(tester, _wanxBatch4);
    expect(find.byKey(CostBreakdownTooltip.contentKey), findsNothing, reason: '没悬停时不出');

    final TestGesture mouse = await _hoverGenerate(tester);

    final Finder card = find.byKey(CostBreakdownTooltip.contentKey);
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(zh.costBreakdownDisclaimer)), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(zh.costFormulaBatch(r'$0.032', 4, r'$0.13'))),
      findsOneWidget,
    );
    expect(find.descendant(of: card, matching: find.text(zh.costApprox(r'$0.13'))), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Wanx Image')), findsOneWidget,
        reason: '服务商名取 providerDisplayNamesProvider');

    await _leave(tester, mouse);
  });

  testWidgets('自定义接口：明细写「自定义接口没有价目」', (tester) async {
    await _pump(tester, _node(<String, Object?>{'prompt': 'a cat', 'provider_id': 'custom:acme'}));

    final TestGesture mouse = await _hoverGenerate(tester);

    final Finder card = find.byKey(CostBreakdownTooltip.contentKey);
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(zh.costUnknownCustom)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(zh.costUnknown)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining(r'$0.00')), findsNothing);

    await _leave(tester, mouse);
  });

  testWidgets('按钮置灰（没 Key）时悬停只出原因，不出明细', (tester) async {
    await _pump(tester, _wanxBatch4, keyed: const <String>{});

    expect(find.byType(CostBreakdownTooltip), findsNothing, reason: '置灰时按钮外面不包明细');
    final TestGesture mouse = await _hoverGenerate(tester);

    expect(find.text(zh.inspectorGenerateDisabledNoKey), findsOneWidget, reason: '原有的置灰原因照出');
    expect(find.byKey(CostBreakdownTooltip.contentKey), findsNothing);
    expect(_amount(tester), zh.costApprox(r'$0.13'), reason: '常驻金额不受按钮置灰影响');

    await _leave(tester, mouse);
  });

  testWidgets('改提示词即时刷新金额（PerCharInput）', (tester) async {
    // 'a cat' 5 字：10 × 0.005 + 0.01 = 0.06。
    await _pump(tester, _node(<String, Object?>{'prompt': 'a cat', 'provider_id': 'per-char'}));
    expect(_amount(tester), zh.costApprox(r'$0.06'));

    // 100 字：10 × 0.1 + 0.01 = 1.01。提交控制器不落库，节点 typeConfig 没变——只能靠 pending。
    await tester.enterText(
      find.descendant(of: find.byType(CanvasPromptBar), matching: find.byType(TextField)),
      List<String>.filled(100, 'x').join(),
    );
    await tester.pump();

    expect(_amount(tester), zh.costApprox(r'$1.01'));
  });
}
