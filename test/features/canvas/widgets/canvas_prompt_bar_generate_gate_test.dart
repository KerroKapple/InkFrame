// 提示词条「生成」与检查器的生成按钮同一道闸（util/generate_gate.dart）。
//
// 演示里撞到的：没配 API Key 时检查器的「生成」是灰的，提示词条的「生成」却点得动，点下去才报
// 「生成失败」——提示词条只看了「提示词非空 + 不在途」。本文件钉四件：
//   - 没配 Key：按钮点不动、挂检查器同一句原因（图像 / 视频各一句），⌘↵ 也什么都不发；
//   - 判 Key 的供应商与检查器同一条链（节点已存 > 上次使用 > 第一个），不是生成路径的兜底默认；
//   - 节点没存过供应商时，终稿把判 Key 的那个一并写进去——判的和用的是同一个；
//   - 节点存过供应商时终稿不动它。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../../../_harness/a11y.dart';
import '../../../_harness/test_app.dart';

const String _openAi = 'openai-image';

const CanvasNode _image = CanvasNode(
  id: 'n1',
  label: 'Shot',
  type: CanvasNodeType.image,
  canvasId: 'cv1',
  typeConfig: <String, Object?>{'prompt': 'a cat'},
);

const CanvasNode _video = CanvasNode(
  id: 'n1',
  label: 'Clip',
  type: CanvasNodeType.video,
  canvasId: 'cv1',
  typeConfig: <String, Object?>{'prompt': 'a cat walks'},
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

/// 只记终稿的提交控制器：本文件看的是「发不发、发了什么」，不是 submit 自己怎么写库。
class _RecordingSubmit extends InspectorSubmitController {
  static final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<void> submit(Map<String, Object?> finalConfig) async =>
      calls.add(finalConfig);

  @override
  void savePromptDebounced(String prompt) {}
}

/// [keyed] = 配了 Key 的供应商集合；[lastImage] = 上次用过的图像供应商。
Future<void> _pump(
  WidgetTester tester,
  CanvasNode node, {
  Set<String> keyed = const <String>{},
  String? lastImage,
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasPromptBar(canvasId: 'cv1')),
    surfaceSize: const Size(900, 500),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
      canvasNodesControllerProvider.overrideWith(() => _Nodes(node)),
      canvasSelectionControllerProvider.overrideWith(_Selected.new),
      inspectorSubmitControllerProvider.overrideWith(_RecordingSubmit.new),
      inspectorHasApiKeyProvider.overrideWith(
        (ref, String providerId) async => keyed.contains(providerId),
      ),
      preferencesServiceProvider.overrideWithValue(
        InMemoryPreferencesService(AppPreferences(lastImageProviderId: lastImage)),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

String? _tooltip(WidgetTester tester) {
  final Finder tip = find.descendant(
    of: find.byKey(CanvasPromptBar.generateKey),
    matching: find.byType(Tooltip),
  );
  if (tip.evaluate().isEmpty) return null;
  return tester.widget<Tooltip>(tip).message;
}

Future<void> _ctrlEnterInField(WidgetTester tester) async {
  await tester.tap(find.descendant(
    of: find.byType(CanvasPromptBar),
    matching: find.byType(TextField),
  ));
  await tester.pumpAndSettle();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  setUp(_RecordingSubmit.calls.clear);

  testWidgets('没配 Key：「生成」点不动，挂检查器同一句原因', (tester) async {
    await _pump(tester, _image);

    expect(
      activatableFocus(tester, CanvasPromptBar.generateKey).canRequestFocus,
      isFalse,
      reason: '检查器的生成按钮此刻是灰的，提示词条的也得是',
    );
    expect(_tooltip(tester), en.inspectorGenerateDisabledNoKey);

    await tester.tap(find.byKey(CanvasPromptBar.generateKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_RecordingSubmit.calls, isEmpty, reason: '点下去不该发出去再报「生成失败」');
  });

  testWidgets('没配 Key：提示词框里按 Ctrl+↵ 也什么都不发', (tester) async {
    await _pump(tester, _image);

    await _ctrlEnterInField(tester);

    expect(_RecordingSubmit.calls, isEmpty);
  });

  testWidgets('视频节点没配 Key：原因用视频检查器那一句', (tester) async {
    await _pump(tester, _video);

    expect(_tooltip(tester), en.inspectorVideoGenerateDisabledNoKey);
  });

  testWidgets('判 Key 走检查器同一条链：上次用过的供应商配了 Key ⇒ 可点，终稿写进这个供应商', (tester) async {
    // 只有 openai 配了 Key、上次用的也是它；生成路径的兜底默认（gemini）没配。
    // 提示词条要是按兜底默认判，这里就是灰的。
    await _pump(tester, _image, keyed: <String>{_openAi}, lastImage: _openAi);

    expect(_tooltip(tester), isNull, reason: '可点时不挂原因');
    await tester.tap(find.byKey(CanvasPromptBar.generateKey));
    await tester.pumpAndSettle();

    expect(_RecordingSubmit.calls, <Map<String, Object?>>[
      <String, Object?>{'prompt': 'a cat', 'provider_id': _openAi},
    ], reason: '节点没存过供应商：判 Key 的那个必须一并写进终稿，否则生成会落回兜底默认');
  });

  const CanvasNode saved = CanvasNode(
    id: 'n1',
    label: 'Shot',
    type: CanvasNodeType.image,
    canvasId: 'cv1',
    typeConfig: <String, Object?>{'prompt': 'a cat', 'provider_id': _openAi},
  );

  testWidgets('节点存过供应商：判的是它的 Key，不是上次用过的', (tester) async {
    // 上次用的是 gemini 且它配了 Key——但节点已存 openai，优先级更高：openai 没 Key ⇒ 点不动。
    await _pump(tester, saved, keyed: <String>{'gemini-image'}, lastImage: 'gemini-image');

    expect(_tooltip(tester), en.inspectorGenerateDisabledNoKey);
    await _ctrlEnterInField(tester);
    expect(_RecordingSubmit.calls, isEmpty);
  });

  testWidgets('节点存过供应商且配了 Key：Ctrl+↵ 发出去，终稿不改写供应商', (tester) async {
    await _pump(tester, saved, keyed: <String>{_openAi});

    await _ctrlEnterInField(tester);

    expect(_RecordingSubmit.calls, <Map<String, Object?>>[
      <String, Object?>{'prompt': 'a cat'},
    ], reason: '库里那一份才是检查器最后选的，提示词条不拿内存里可能过期的值盖它');
  });
}
