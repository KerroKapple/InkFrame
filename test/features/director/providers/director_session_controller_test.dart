// 导演管线（假 AnthropicClient / 真 DioAnthropicClient + 回放适配器）：
// 确认 / 驳回再分叉 / 失败 / 拒答 / 取消 / 人工改设定 / 从日志重建；
// 断言日志里的 model_request 能原样重建实际发出的请求。
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/anthropic.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/anthropic_client.dart';
import 'package:inkframe/core/models/director.dart';
import 'package:inkframe/features/director/providers/director_session_controller.dart';
import 'package:inkframe/features/director/providers/director_session_state.dart';
import 'package:inkframe/services/anthropic/anthropic_protocol.dart';
import 'package:inkframe/services/anthropic/claude_request_encoder.dart';
import 'package:inkframe/services/anthropic/dio_anthropic_client.dart';

import '../../../_harness/fake_anthropic_client.dart';
import '../../../_harness/fake_director_repository.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';
import '../../../_harness/scripted_http_adapter.dart';

String _board({String lang = 'zh-CN', int shots = 2}) => jsonEncode(<String, Object?>{
      'content_language': lang,
      'setting': <String, Object?>{'era': '唐', 'region': '蜀中', 'culture': '', 'art_style': '水墨'},
      'shots': <Object?>[
        for (int i = 0; i < shots; i++)
          <String, Object?>{
            'label': '镜$i',
            'notes': '画面$i',
            'shot_size': 'mediumShot',
            'camera_angle': 'low',
            'camera': 'tracking',
            'duration_seconds': 4,
            'characters': <Object?>['杜甫'],
          },
      ],
    });

class _Rig {
  _Rig(AnthropicClient client) {
    container = ProviderContainer(overrides: <Override>[
      directorRepositoryProvider.overrideWith((Ref ref) async => repo),
      anthropicClientProvider.overrideWithValue(client),
      canvasRepositoryProvider.overrideWith((Ref ref) async => canvases),
      unitOfWorkProvider.overrideWith(
        (Ref ref) async => FakeUnitOfWork(FakeRepositoryScope(nodes: nodes, edges: edges)),
      ),
    ]);
  }

  final InMemoryDirectorRepository repo = InMemoryDirectorRepository();
  final InMemoryCanvasRepository canvases = InMemoryCanvasRepository();
  final InMemoryNodeRepository nodes = InMemoryNodeRepository();
  final InMemoryEdgeRepository edges = InMemoryEdgeRepository();
  late final ProviderContainer container;
  late String sessionId;
  late String canvasId;

  Future<DirectorSessionController> open() async {
    canvasId = await canvases.create(projectId: 'p1', name: 'c');
    sessionId = await container.read(directorSessionStarterProvider).start(canvasId);
    return attach();
  }

  Future<DirectorSessionController> attach() async {
    container.listen(directorSessionControllerProvider(sessionId), (_, _) {});
    await container.read(directorSessionControllerProvider(sessionId).future);
    return container.read(directorSessionControllerProvider(sessionId).notifier);
  }

  DirectorSessionState get state =>
      container.read(directorSessionControllerProvider(sessionId)).requireValue;

  List<DirectorEvent> get events => repo.eventsOf(sessionId);
  List<DirectorEventKind> get kinds => events.map((DirectorEvent e) => e.kind).toList();
}

void main() {
  test('会话建在画布所属项目下；画布不存在 ⇒ LocalIOError', () async {
    final _Rig rig = _Rig(FakeAnthropicClient(const <FakeClaudeReply>[]));
    addTearDown(rig.container.dispose);
    await rig.open();
    expect(rig.repo.sessions[rig.sessionId]!.projectId, 'p1');
    expect(rig.repo.sessions[rig.sessionId]!.canvasId, rig.canvasId);
    await expectLater(
      rig.container.read(directorSessionStarterProvider).start('ghost'),
      throwsA(isA<LocalIOError>()),
    );
  });

  test('拆分 → 提案 → 确认：事件成链、语言设定写回、落画布走同一条建链路径', () async {
    final FakeAnthropicClient client = FakeAnthropicClient(<FakeClaudeReply>[FakeClaudeReply.text(_board())]);
    final _Rig rig = _Rig(client);
    addTearDown(rig.container.dispose);
    final DirectorSessionController c = await rig.open();

    await c.split('山径破晓\n\n渡索桥');
    expect(rig.kinds, <DirectorEventKind>[
      DirectorEventKind.scriptSubmitted,
      DirectorEventKind.modelRequest,
      DirectorEventKind.modelResponse,
      DirectorEventKind.storyboardProposed,
    ]);
    expect(rig.events.map((DirectorEvent e) => e.parentSeq), <int?>[null, 1, 2, 3]);
    expect(rig.state.phase, DirectorPhase.proposed);
    expect(rig.state.proposal!.shots, hasLength(2));
    expect(rig.state.proposedScript, '山径破晓\n\n渡索桥');
    expect(rig.repo.sessions[rig.sessionId]!.contentLanguage, 'zh-CN');
    expect(rig.repo.sessions[rig.sessionId]!.setting.era, '唐');
    expect(rig.state.ledger.totalUsage.inputTokens, 1000);

    final List<String> ids = await c.confirm();
    expect(ids, hasLength(2));
    expect(rig.kinds.sublist(4), <DirectorEventKind>[
      DirectorEventKind.humanConfirmed,
      DirectorEventKind.appliedToCanvas,
    ]);
    expect(rig.events.last.payload['node_ids'], ids);
    expect(rig.state.phase, DirectorPhase.applied);
    expect(rig.state.appliedNodeIds, ids);
    final Map<String, Object?> cfg =
        (await rig.nodes.findById(ids.first))!['type_config']! as Map<String, Object?>;
    expect(cfg, <String, Object?>{
      'shot_notes': '画面0\n杜甫',
      'shot_size': 'mediumShot',
      'camera_angle': 'low',
      'camera': 'tracking',
      'duration_ms': 4000,
    });
  });

  test('日志里的 model_request 原样重建了实际发出的请求，不含 Key', () async {
    final FakeAnthropicClient client = FakeAnthropicClient(<FakeClaudeReply>[FakeClaudeReply.text(_board())]);
    final _Rig rig = _Rig(client);
    addTearDown(rig.container.dispose);
    await (await rig.open()).split('山径破晓');

    final DirectorEvent req = rig.events[1];
    final Object? body = req.payload['body'];
    expect(body, client.sentBodies.single);
    expect(body, encodeClaudeRequest(client.requests.single));
    expect(jsonEncode(body), isNot(contains('x-api-key')));
    expect(req.payload['attempt'], 0);
    expect(req.payload['step'], 'storyboard');
  });

  test('真客户端：日志里的 body 与线上发出的逐字段相同（含重试的每一次）', () async {
    final ScriptedHttpAdapter adapter = ScriptedHttpAdapter(<ScriptedReply>[
      ScriptedReply.json(529, <String, Object?>{
        'type': 'error',
        'error': <String, Object?>{'type': 'overloaded_error', 'message': 'busy'},
      }),
      ScriptedReply(
        headers: const <String, String>{Headers.contentTypeHeader: 'text/event-stream'},
        chunks: <String>[
          sseFrame('message_start', <String, Object?>{
            'type': 'message_start',
            'message': <String, Object?>{
              'id': 'msg_1',
              'model': 'claude-opus-5-5',
              'usage': <String, Object?>{'input_tokens': 10, 'output_tokens': 1},
            },
          }),
          sseFrame('content_block_start', <String, Object?>{
            'type': 'content_block_start',
            'index': 0,
            'content_block': <String, Object?>{'type': 'text', 'text': ''},
          }),
          sseFrame('content_block_delta', <String, Object?>{
            'type': 'content_block_delta',
            'index': 0,
            'delta': <String, Object?>{'type': 'text_delta', 'text': _board(shots: 1)},
          }),
          sseFrame('message_delta', <String, Object?>{
            'type': 'message_delta',
            'delta': <String, Object?>{'stop_reason': 'end_turn'},
            'usage': <String, Object?>{'output_tokens': 7},
          }),
          sseFrame('message_stop', <String, Object?>{'type': 'message_stop'}),
        ],
      ),
    ]);
    final Dio dio = Dio(BaseOptions(baseUrl: AnthropicProtocol.baseUrl))..httpClientAdapter = adapter;
    final _Rig rig = _Rig(DioAnthropicClient(
      dio: dio,
      keySource: () async => 'sk-ant-secret',
      sleep: (_) async {},
    ));
    addTearDown(rig.container.dispose);
    await (await rig.open()).split('山径破晓');

    final List<DirectorEvent> requests =
        rig.events.where((DirectorEvent e) => e.kind == DirectorEventKind.modelRequest).toList();
    expect(requests, hasLength(2));
    for (int i = 0; i < 2; i++) {
      expect(requests[i].payload['attempt'], i);
      expect(requests[i].payload['body'], adapter.requests[i].data);
      expect(jsonEncode(requests[i].payload), isNot(contains('sk-ant-secret')));
    }
    expect(rig.state.phase, DirectorPhase.proposed);
    expect(rig.state.ledger.totalUsage.outputTokens, 7);
  });

  test('驳回再拆：记 human_rejected，从空根分叉，意见进下一次请求；两轮都计费', () async {
    final FakeAnthropicClient client = FakeAnthropicClient(<FakeClaudeReply>[
      FakeClaudeReply.text(_board(shots: 3)),
      FakeClaudeReply.text(_board(shots: 1)),
    ]);
    final _Rig rig = _Rig(client);
    addTearDown(rig.container.dispose);
    final DirectorSessionController c = await rig.open();
    await c.split('山径破晓');
    await c.split('山径破晓', feedback: '  合成一镜 ');

    final DirectorEvent rejected = rig.events[4];
    expect(rejected.kind, DirectorEventKind.humanRejected);
    expect(rejected.parentSeq, 4);
    expect(rejected.payload['reason'], '合成一镜');
    expect(rejected.payload['proposal_seq'], 4);
    final DirectorEvent fork = rig.events[5];
    expect(fork.kind, DirectorEventKind.scriptSubmitted);
    expect(fork.parentSeq, isNull, reason: '还没确认过 ⇒ 从空根分叉');
    expect(fork.payload['feedback'], <Object?>['合成一镜']);
    expect(jsonEncode(client.sentBodies[1]), contains('合成一镜'));
    expect(jsonEncode(client.sentBodies[0]), isNot(contains('合成一镜')));
    expect(rig.state.proposal!.shots, hasLength(1));
    expect(rig.state.ledger.records, hasLength(2));
  });

  test('确认过之后再拆：从最近的 human_confirmed 分叉，确认过的不受影响', () async {
    final _Rig rig = _Rig(FakeAnthropicClient(<FakeClaudeReply>[
      FakeClaudeReply.text(_board()),
      FakeClaudeReply.text(_board(shots: 1)),
    ]));
    addTearDown(rig.container.dispose);
    final DirectorSessionController c = await rig.open();
    await c.split('a');
    await c.confirm();
    final int confirmedSeq =
        rig.events.firstWhere((DirectorEvent e) => e.kind == DirectorEventKind.humanConfirmed).seq;
    await c.split('b');

    final DirectorEvent fork = rig.events.lastWhere((DirectorEvent e) => e.kind == DirectorEventKind.scriptSubmitted);
    expect(fork.parentSeq, confirmedSeq);
    final List<int> path = rig.state.log.pathTo(rig.state.head).map((DirectorEvent e) => e.seq).toList();
    expect(path, contains(confirmedSeq));
    expect(rig.kinds.where((DirectorEventKind k) => k == DirectorEventKind.appliedToCanvas), hasLength(1));
  });

  test('没拿到回应的失败 ⇒ model_failed(code)，状态 failed，不计费', () async {
    final _Rig rig = _Rig(FakeAnthropicClient(<FakeClaudeReply>[
      const FakeClaudeReply.error(NetworkError(code: InkErrorCode.networkOffline)),
    ]));
    addTearDown(rig.container.dispose);
    await (await rig.open()).split('a');
    expect(rig.kinds, <DirectorEventKind>[
      DirectorEventKind.scriptSubmitted,
      DirectorEventKind.modelRequest,
      DirectorEventKind.modelFailed,
    ]);
    expect(rig.events.last.payload['code'], 'network_offline');
    expect(rig.state.phase, DirectorPhase.failed);
    expect(rig.state.errorCode, InkErrorCode.networkOffline);
    expect(rig.state.ledger.records, isEmpty);
  });

  test('拒答冒泡：回应照记（计费），model_failed 带 category', () async {
    final _Rig rig = _Rig(FakeAnthropicClient(<FakeClaudeReply>[
      const FakeClaudeReply.refusal(refusalCategory: 'cyber'),
    ]));
    addTearDown(rig.container.dispose);
    await (await rig.open()).split('a');
    expect(rig.kinds.sublist(1), <DirectorEventKind>[
      DirectorEventKind.modelRequest,
      DirectorEventKind.modelResponse,
      DirectorEventKind.modelFailed,
    ]);
    expect(rig.events[2].payload['stop_reason'], 'refusal');
    expect(rig.events.last.payload['code'], 'model_refusal');
    expect(rig.events.last.payload['refusal_category'], 'cyber');
    expect(rig.state.errorCode, InkErrorCode.modelRefusal);
    expect(rig.state.ledger.records, hasLength(1));
  });

  test('回应读不出 ⇒ providerInvalidResponse，回应仍在日志里', () async {
    final _Rig rig = _Rig(FakeAnthropicClient(<FakeClaudeReply>[const FakeClaudeReply.text('oops')]));
    addTearDown(rig.container.dispose);
    await (await rig.open()).split('a');
    expect(rig.kinds.last, DirectorEventKind.modelFailed);
    expect(rig.kinds, contains(DirectorEventKind.modelResponse));
    expect(rig.state.errorCode, InkErrorCode.providerInvalidResponse);
  });

  test('取消：当下记 model_failed(cancelled_by_user) 回到 idle；迟到的回应照记、不出提案', () async {
    final Completer<void> gate = Completer<void>();
    final _Rig rig = _Rig(FakeAnthropicClient(<FakeClaudeReply>[FakeClaudeReply.text(_board(), gate: gate)]));
    addTearDown(rig.container.dispose);
    final DirectorSessionController c = await rig.open();

    final Future<void> run = c.split('a');
    await pumpEventQueue();
    expect(rig.state.phase, DirectorPhase.running);
    await c.cancel();
    expect(rig.state.phase, DirectorPhase.idle);
    expect(rig.events.last.kind, DirectorEventKind.modelFailed);
    expect(rig.events.last.payload['code'], 'cancelled_by_user');
    expect(rig.events.last.parentSeq, 2, reason: '接在已发出的 model_request 之后');

    gate.complete();
    await run;
    expect(rig.kinds.last, DirectorEventKind.modelResponse);
    expect(rig.kinds, isNot(contains(DirectorEventKind.storyboardProposed)));
    expect(rig.state.phase, DirectorPhase.idle);
    expect(rig.state.ledger.records, hasLength(1));
  });

  test('人工改语言 / 设定：human_edited 写回会话；没改不记', () async {
    final _Rig rig = _Rig(FakeAnthropicClient(<FakeClaudeReply>[FakeClaudeReply.text(_board())]));
    addTearDown(rig.container.dispose);
    final DirectorSessionController c = await rig.open();
    await c.split('a');
    final DirectorSetting same = rig.state.proposal!.setting;
    await c.edit(contentLanguage: 'zh-CN', setting: same);
    expect(rig.kinds.last, DirectorEventKind.storyboardProposed);

    await c.edit(contentLanguage: 'zh-TW', setting: same.copyWith(era: '盛唐'));
    expect(rig.kinds.last, DirectorEventKind.humanEdited);
    expect(rig.events.last.payload['content_language'], 'zh-TW');
    expect(rig.repo.sessions[rig.sessionId]!.setting.era, '盛唐');
    expect(rig.state.proposal!.contentLanguage, 'zh-TW');
    expect(rig.state.proposal!.setting.era, '盛唐');
    expect(rig.state.phase, DirectorPhase.proposed);
  });

  test('从日志重建：另开一个控制器读同一会话，状态与提案一致', () async {
    final _Rig rig = _Rig(FakeAnthropicClient(<FakeClaudeReply>[FakeClaudeReply.text(_board())]));
    addTearDown(rig.container.dispose);
    final DirectorSessionController c = await rig.open();
    await c.split('a');
    await c.edit(contentLanguage: 'zh-TW', setting: rig.state.proposal!.setting);
    final Map<String, Object?> before = rig.state.proposal!.toJson();

    rig.container.invalidate(directorSessionControllerProvider(rig.sessionId));
    await rig.attach();
    expect(rig.state.phase, DirectorPhase.proposed);
    expect(rig.state.proposal!.toJson(), before);
    expect(rig.state.proposedScript, 'a');
  });

  test('写日志失败 ⇒ 不发请求，状态 failed(local_io_error)', () async {
    final FakeAnthropicClient client = FakeAnthropicClient(<FakeClaudeReply>[FakeClaudeReply.text(_board())]);
    final _Rig rig = _Rig(client);
    addTearDown(rig.container.dispose);
    final DirectorSessionController c = await rig.open();
    rig.repo.failAppendAt = 1; // 第二件（model_request）写不进去
    await c.split('a');
    expect(client.sentBodies, isEmpty);
    expect(rig.state.phase, DirectorPhase.failed);
    expect(rig.state.errorCode, InkErrorCode.localIOError);
  });
}
