// 提示词条第一行（名字 · 摘要 | 基底风格）在最窄的 480 宽条子上的版式（W2 验收 #17）。
//
// 钉的几件：
//   - 名字短、摘要长：摘要吃掉名字用不完的宽度，服务商名完整显示——原来名字与摘要两个 flex 1 平分，
//     摘要最多拿一半，「Wanx Image-t…」；
//   - 基底风格前缀很长：chip 封顶 160、在 chip 里省略，这一行不溢出；
//   - 节点还没存 provider_id：摘要里写解析到的那一家（与金额 / 判 Key 同一条链），不是空着。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_base_style.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';
import 'package:inkframe/providers/wanx_image_provider.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../../../_harness/test_app.dart';

/// 一个名字够长的服务商：480 宽的条子上平分时放不下，独占剩余宽度时放得下。
const String _longProviderName = 'Wanx Image Turbo Provider Edition Plus';

final ProviderCapabilities _longNamed = kWanxImageCapabilities.copyWith(
  providerId: 'long-named',
  displayName: _longProviderName,
);

CanvasNode _node(Map<String, Object?> tc) => CanvasNode(
      id: 'n1',
      label: 'Shot',
      type: CanvasNodeType.image,
      canvasId: 'cv1',
      typeConfig: tc,
    );

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

/// 打字不落库：本文件只看版式。
class _NoSave extends InspectorSubmitController {
  @override
  void savePromptDebounced(String prompt) {}
}

/// 舞台 697 ⇒ 条宽 480（下限）。与 canvas_prompt_bar_layout_test 同一种挂法。
Future<void> _pump(
  WidgetTester tester,
  CanvasNode node, {
  required List<ProviderCapabilities> capabilities,
  String prefix = '',
}) async {
  const double stage = 697;
  await pumpInkApp(
    tester,
    const Scaffold(
      body: Center(
        child: SizedBox(width: stage, child: CanvasPromptBar(canvasId: 'cv1')),
      ),
    ),
    surfaceSize: const Size(stage + 100, 600),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
      canvasNodesControllerProvider.overrideWith(() => _Nodes(node)),
      canvasSelectionControllerProvider.overrideWith(_Selected.new),
      inspectorSubmitControllerProvider.overrideWith(_NoSave.new),
      inspectorHasApiKeyProvider.overrideWith((ref, String providerId) async => true),
      preferencesServiceProvider.overrideWithValue(InMemoryPreferencesService()),
      providerCapabilitiesListProvider.overrideWithValue(capabilities),
      canvasBaseStyleProvider.overrideWith(
        (ref, String canvasId) async => (prefix: prefix, suffix: ''),
      ),
    ],
  );
  await tester.pumpAndSettle();
  expect(tester.getSize(find.byKey(CanvasPromptBar.surfaceKey)).width, closeTo(480, 0.01),
      reason: '前提：最窄的 480 宽条子');
}

/// [text] 那一行 Text 是否被省略（单行超宽 ⇒ didExceedMaxLines）。
bool _truncated(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

void main() {
  testWidgets('名字短、摘要长：摘要吃掉剩余宽度，服务商名完整显示', (tester) async {
    await _pump(
      tester,
      _node(<String, Object?>{'prompt': 'a cat', 'provider_id': 'long-named'}),
      capabilities: <ProviderCapabilities>[_longNamed],
    );

    expect(find.text(_longProviderName), findsOneWidget);
    expect(_truncated(tester, _longProviderName), isFalse,
        reason: '名字只有「Shot」，用不完的宽度该让给摘要，而不是两边平分');
    expect(_truncated(tester, 'Shot'), isFalse);
  });

  testWidgets('名字很长：封顶 40%，摘要仍有位置', (tester) async {
    final String longLabel = List<String>.filled(20, 'Shot').join(' ');
    await _pump(
      tester,
      _node(<String, Object?>{'prompt': 'a cat', 'provider_id': 'long-named'}).copyWith(label: longLabel),
      capabilities: <ProviderCapabilities>[_longNamed],
    );

    expect(tester.takeException(), isNull);
    final double barWidth = tester.getSize(find.byKey(CanvasPromptBar.surfaceKey)).width;
    expect(tester.getSize(find.text(longLabel)).width, lessThanOrEqualTo(barWidth * 0.4),
        reason: '名字封顶在这一段的 40% 以内');
    expect(_truncated(tester, longLabel), isTrue);
  });

  testWidgets('基底风格前缀很长：chip 封顶 160，这一行不溢出', (tester) async {
    final String longPrefix = List<String>.filled(30, 'cinematic').join(' ');
    await _pump(
      tester,
      _node(<String, Object?>{'prompt': 'a cat', 'provider_id': 'long-named'}),
      capabilities: <ProviderCapabilities>[_longNamed],
      prefix: longPrefix,
    );

    expect(tester.takeException(), isNull, reason: '前缀再长也不能撑爆第一行');
    expect(tester.getSize(find.byKey(CanvasPromptBar.baseStyleKey)).width, lessThanOrEqualTo(160));
    final Rect bar = tester.getRect(find.byKey(CanvasPromptBar.surfaceKey));
    expect(tester.getRect(find.byKey(CanvasPromptBar.baseStyleKey)).right, lessThanOrEqualTo(bar.right));
    // 名字与摘要仍然画得出来（没被挤成 0 宽）。
    expect(tester.getSize(find.text('Shot')).width, greaterThan(0));
    expect(tester.getSize(find.text(_longProviderName)).width, greaterThan(0));
  });

  testWidgets('节点没存 provider_id：摘要写解析到的服务商（与金额同一条链）', (tester) async {
    await _pump(
      tester,
      _node(<String, Object?>{'prompt': 'a cat'}),
      capabilities: <ProviderCapabilities>[_longNamed],
    );

    // 没有上次使用 ⇒ 候选第一个，就是金额按它算的那一家。
    expect(find.text(_longProviderName), findsOneWidget);
  });
}
