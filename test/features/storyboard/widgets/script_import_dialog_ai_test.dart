// 剧本导入对话框的「AI 拆分」：无 Key 置灰、拆分中可停、完成预览、失败重试、改字后标过期、
// 改设定入日志、创建走同一个建链控制器（human_confirmed + applied_to_canvas）。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/di/anthropic.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/models/director.dart';
import 'package:inkframe/features/director/widgets/ai_storyboard_panel.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/storyboard/widgets/script_import_dialog.dart';

import '../../../_harness/fake_anthropic_client.dart';
import '../../../_harness/fake_director_repository.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_secure_storage.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/fake_unit_of_work.dart';
import '../../../_harness/test_app.dart';

String _board() => jsonEncode(<String, Object?>{
      'content_language': 'zh-CN',
      'setting': <String, Object?>{'era': '唐', 'region': '', 'culture': '', 'art_style': '水墨'},
      'shots': <Object?>[
        for (int i = 0; i < 2; i++)
          <String, Object?>{
            'label': '镜$i',
            'notes': '画面$i',
            'shot_size': 'closeUp',
            'camera_angle': null,
            'camera': 'pushIn',
            'duration_seconds': 4,
            'characters': <Object?>[],
          },
      ],
    });

class _Rig {
  final InMemoryNodeRepository nodes = InMemoryNodeRepository();
  final InMemoryEdgeRepository edges = InMemoryEdgeRepository();
  final InMemoryCanvasRepository canvases = InMemoryCanvasRepository();
  final InMemoryDirectorRepository director = InMemoryDirectorRepository();
  final RecordingToastService toast = RecordingToastService();
  late FakeAnthropicClient client;

  List<DirectorEvent> get events => director.sessions.isEmpty
      ? const <DirectorEvent>[]
      : director.eventsOf(director.sessions.keys.single);

  Future<void> pump(
    WidgetTester tester, {
    bool withKey = true,
    List<FakeClaudeReply> replies = const <FakeClaudeReply>[],
  }) async {
    client = FakeAnthropicClient(replies);
    final String canvasId = await canvases.create(projectId: 'p1', name: 'c');
    await pumpInkApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showScriptImportDialog(context, canvasId: canvasId),
            child: const Text('open'),
          ),
        ),
      ),
      surfaceSize: const Size(1200, 1600),
      overrides: <Override>[
        unitOfWorkProvider.overrideWith(
          (Ref ref) async => FakeUnitOfWork(FakeRepositoryScope(nodes: nodes, edges: edges)),
        ),
        canvasRepositoryProvider.overrideWith((Ref ref) async => canvases),
        directorRepositoryProvider.overrideWith((Ref ref) async => director),
        anthropicClientProvider.overrideWithValue(client),
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorage(<String, String>{
          if (withKey) SecureStorageKeys.anthropicApiKey: 'sk-ant-x',
        })),
        toastServiceProvider.overrideWithValue(toast),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

Future<void> _paste(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pumpAndSettle();
}

Future<void> _toAi(WidgetTester tester) async {
  await tester.tap(find.text('AI split'));
  await tester.pumpAndSettle();
}

ButtonStyleButton _create(WidgetTester tester, String label) =>
    tester.widget(find.widgetWithText(FilledButton, label));

void main() {
  testWidgets('没填 Claude Key：AI 段置灰（点了不切），悬停提示去设置页', (WidgetTester tester) async {
    final _Rig rig = _Rig();
    await rig.pump(tester, withKey: false);
    await _paste(tester, '山径破晓');
    await _toAi(tester);

    expect(find.byKey(AiStoryboardPanelKeys.start), findsNothing);
    expect(find.text('1. 山径破晓'), findsOneWidget, reason: '仍是规则预览');
    expect(find.byTooltip('Add a Claude API key in Settings › API keys to use AI split.'), findsOneWidget);
  });

  testWidgets('拆分完成：预览显示语言与设定、每镜「标题 · 景别 · 运镜 · 时长」、用量；可创建', (WidgetTester tester) async {
    final _Rig rig = _Rig();
    await rig.pump(tester, replies: <FakeClaudeReply>[FakeClaudeReply.text(_board())]);
    await _paste(tester, '山径破晓');
    await _toAi(tester);
    expect(_create(tester, 'Create shots').onPressed, isNull, reason: '还没拆，不能创建');

    await tester.tap(find.byKey(AiStoryboardPanelKeys.start));
    await tester.pumpAndSettle();

    expect(find.text('Detected language and setting'), findsOneWidget);
    expect(tester.widget<TextField>(find.descendant(
      of: find.byKey(AiStoryboardPanelKeys.language),
      matching: find.byType(TextField),
    )).controller!.text, 'zh-CN');
    expect(find.text('1. 镜0 · Close-up CU · Dolly in · 4s'), findsOneWidget);
    expect(find.text('2 shots'), findsOneWidget);
    expect(find.byKey(AiStoryboardPanelKeys.usage), findsOneWidget);
    expect(find.text('1,200 tokens · about <\$0.01'), findsOneWidget);
    expect(_create(tester, 'Create 2 shots').onPressed, isNotNull);
  });

  testWidgets('拆分中：进度 + 停止；停止后记 model_failed、回到开始，迟到的结果丢弃', (WidgetTester tester) async {
    final _Rig rig = _Rig();
    final Completer<void> gate = Completer<void>();
    await rig.pump(tester, replies: <FakeClaudeReply>[FakeClaudeReply.text(_board(), gate: gate)]);
    await _paste(tester, '山径破晓');
    await _toAi(tester);
    await tester.tap(find.byKey(AiStoryboardPanelKeys.start));
    for (int i = 0; i < 10; i++) {
      await tester.pump();
    }

    expect(find.text('Splitting the script…'), findsOneWidget);
    await tester.tap(find.byKey(AiStoryboardPanelKeys.stop));
    await tester.pump();
    await tester.pump();
    expect(rig.events.last.kind, DirectorEventKind.modelFailed);
    expect(rig.events.last.payload['code'], 'cancelled_by_user');
    expect(find.byKey(AiStoryboardPanelKeys.start), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(AiStoryboardPanelKeys.start), findsOneWidget);
    expect(_create(tester, 'Create shots').onPressed, isNull);
  });

  testWidgets('失败：显示原因与重试；重试成功出提案', (WidgetTester tester) async {
    final _Rig rig = _Rig();
    await rig.pump(tester, replies: <FakeClaudeReply>[
      const FakeClaudeReply.error(NetworkError(code: InkErrorCode.networkOffline)),
      FakeClaudeReply.text(_board()),
    ]);
    await _paste(tester, '山径破晓');
    await _toAi(tester);
    await tester.tap(find.byKey(AiStoryboardPanelKeys.start));
    await tester.pumpAndSettle();

    expect(find.textContaining('Split failed: '), findsOneWidget);
    await tester.tap(find.byKey(AiStoryboardPanelKeys.retry));
    await tester.pumpAndSettle();
    expect(find.text('2 shots'), findsOneWidget);
  });

  testWidgets('拆完又改了剧本：标「需重新拆分」，创建置灰；重新拆分后恢复', (WidgetTester tester) async {
    final _Rig rig = _Rig();
    await rig.pump(tester, replies: <FakeClaudeReply>[
      FakeClaudeReply.text(_board()),
      FakeClaudeReply.text(_board()),
    ]);
    await _paste(tester, '山径破晓');
    await _toAi(tester);
    await tester.tap(find.byKey(AiStoryboardPanelKeys.start));
    await tester.pumpAndSettle();

    await _paste(tester, '山径破晓，加一句');
    expect(find.byKey(AiStoryboardPanelKeys.stale), findsOneWidget);
    expect(_create(tester, 'Create 2 shots').onPressed, isNull);

    await tester.enterText(find.descendant(
      of: find.byKey(AiStoryboardPanelKeys.feedback),
      matching: find.byType(TextField),
    ), '多一个远景');
    await tester.tap(find.byKey(AiStoryboardPanelKeys.resplit));
    await tester.pumpAndSettle();
    expect(find.byKey(AiStoryboardPanelKeys.stale), findsNothing);
    expect(_create(tester, 'Create 2 shots').onPressed, isNotNull);
    expect(rig.events.map((DirectorEvent e) => e.kind), contains(DirectorEventKind.humanRejected));
    expect(jsonEncode(rig.client.sentBodies.last), contains('多一个远景'));
  });

  testWidgets('改设定：失焦即记 human_edited 并写回会话', (WidgetTester tester) async {
    final _Rig rig = _Rig();
    await rig.pump(tester, replies: <FakeClaudeReply>[FakeClaudeReply.text(_board())]);
    await _paste(tester, '山径破晓');
    await _toAi(tester);
    await tester.tap(find.byKey(AiStoryboardPanelKeys.start));
    await tester.pumpAndSettle();

    final Finder era = find.descendant(
      of: find.byKey(AiStoryboardPanelKeys.era),
      matching: find.byType(TextField),
    );
    await tester.tap(era);
    await tester.enterText(era, '盛唐');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(rig.events.last.kind, DirectorEventKind.humanEdited);
    expect((rig.events.last.payload['setting']! as Map)['era'], '盛唐');
    expect(rig.director.sessions.values.single.setting.era, '盛唐');
  });

  testWidgets('创建镜头：走同一个建链控制器，带镜头语言；关框 + 成功提示；日志记确认与落画布', (WidgetTester tester) async {
    final _Rig rig = _Rig();
    await rig.pump(tester, replies: <FakeClaudeReply>[FakeClaudeReply.text(_board())]);
    await _paste(tester, '山径破晓');
    await _toAi(tester);
    await tester.tap(find.byKey(AiStoryboardPanelKeys.start));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create 2 shots'));
    await tester.pumpAndSettle();

    expect(rig.nodes.rows, hasLength(2));
    expect(rig.edges.rows, hasLength(1));
    final Map<String, Object?> cfg = rig.nodes.rows.values.first['type_config']! as Map<String, Object?>;
    expect(cfg['shot_size'], 'closeUp');
    expect(cfg['camera'], 'pushIn');
    expect(cfg['duration_ms'], 4000);
    expect(find.text('Import script'), findsNothing);
    expect(rig.toast.titles, <String>['2 shots added to the canvas']);
    expect(rig.toast.kinds, <ToastKind>[ToastKind.success]);
    expect(rig.events.map((DirectorEvent e) => e.kind).skip(4), <DirectorEventKind>[
      DirectorEventKind.humanConfirmed,
      DirectorEventKind.appliedToCanvas,
    ]);
    expect(rig.events.last.payload['node_ids'], unorderedEquals(rig.nodes.rows.keys));
  });
}
