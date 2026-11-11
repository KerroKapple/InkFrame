// DioAnthropicClient 单测：假 HttpClientAdapter 回放 SSE / 错误响应。
//
// 覆盖：请求体固定字段（model / thinking / effort / fallbacks / beta 头 / 版本头 /
// output_config.format / image base64 块）与禁用字段、SSE 拼接、refusal、max_tokens、
// 429 / 529 / 5xx / 连接错误的退避重试与放弃、401 / 400、Key 校验三态、观察口（入日志）。
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/anthropic_client.dart';
import 'package:inkframe/core/models/claude_message.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/services/anthropic/anthropic_protocol.dart';
import 'package:inkframe/services/anthropic/dio_anthropic_client.dart';

import '../../_harness/scripted_http_adapter.dart';

/// 记下交出的请求体与回应（导演日志的替身）。
class _RecordingObserver implements ClaudeExchangeObserver {
  final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];
  final List<int> attempts = <int>[];
  final List<ClaudeExchangeResponse> responses = <ClaudeExchangeResponse>[];

  @override
  Future<void> onRequest(Map<String, Object?> body, {required int attempt}) async {
    bodies.add(body);
    attempts.add(attempt);
  }

  @override
  Future<void> onResponse(ClaudeExchangeResponse response) async => responses.add(response);
}


/// 一次正常的流：message_start → thinking 块 → 两个 text 块（跨 delta）→ message_delta → stop。
List<String> _okStream({
  String stopReason = AnthropicStopReasons.endTurn,
  Map<String, Object?>? stopDetails,
  int outputTokens = 42,
}) =>
    <String>[
      sseFrame('message_start', <String, Object?>{
        'type': 'message_start',
        'message': <String, Object?>{
          'id': 'msg_1',
          'type': 'message',
          'model': 'claude-opus-5-5',
          'content': <Object?>[],
          'usage': <String, Object?>{
            'input_tokens': 100,
            'output_tokens': 1,
            'cache_creation_input_tokens': 10,
            'cache_read_input_tokens': 20,
          },
        },
      }),
      sseFrame('ping', <String, Object?>{'type': 'ping'}),
      sseFrame('content_block_start', <String, Object?>{
        'type': 'content_block_start',
        'index': 0,
        'content_block': <String, Object?>{'type': 'thinking', 'thinking': ''},
      }),
      sseFrame('content_block_delta', <String, Object?>{
        'type': 'content_block_delta',
        'index': 0,
        'delta': <String, Object?>{'type': 'thinking_delta', 'thinking': 'secret'},
      }),
      sseFrame('content_block_stop', <String, Object?>{'type': 'content_block_stop', 'index': 0}),
      sseFrame('content_block_start', <String, Object?>{
        'type': 'content_block_start',
        'index': 1,
        'content_block': <String, Object?>{'type': 'text', 'text': ''},
      }),
      sseFrame('content_block_delta', <String, Object?>{
        'type': 'content_block_delta',
        'index': 1,
        'delta': <String, Object?>{'type': 'text_delta', 'text': '{"shots":'},
      }),
      sseFrame('content_block_delta', <String, Object?>{
        'type': 'content_block_delta',
        'index': 1,
        'delta': <String, Object?>{'type': 'text_delta', 'text': '[1,2]}'},
      }),
      sseFrame('content_block_stop', <String, Object?>{'type': 'content_block_stop', 'index': 1}),
      sseFrame('message_delta', <String, Object?>{
        'type': 'message_delta',
        'delta': <String, Object?>{
          'stop_reason': stopReason,
          'stop_details': ?stopDetails,
        },
        'usage': <String, Object?>{'output_tokens': outputTokens},
      }),
      sseFrame('message_stop', <String, Object?>{'type': 'message_stop'}),
    ];

/// 整段流按固定长度切块，故意把行与 UTF-8 字节都切断。
List<String> _rechunk(List<String> frames, int size) {
  final String all = frames.join();
  return <String>[
    for (int i = 0; i < all.length; i += size)
      all.substring(i, i + size > all.length ? all.length : i + size),
  ];
}

ScriptedReply _ok({List<String>? chunks}) => ScriptedReply(
      headers: const <String, String>{Headers.contentTypeHeader: 'text/event-stream'},
      chunks: chunks ?? _okStream(),
    );

ScriptedReply _err(int status, String type, {Map<String, String> headers = const <String, String>{}}) =>
    ScriptedReply.json(
      status,
      <String, Object?>{
        'type': 'error',
        'error': <String, Object?>{'type': type, 'message': 'boom'},
      },
      headers: headers,
    );

class _Rig {
  _Rig(List<ScriptedReply> replies, {String key = 'sk-ant-test'})
      : adapter = ScriptedHttpAdapter(replies) {
    final Dio dio = Dio(BaseOptions(baseUrl: AnthropicProtocol.baseUrl))
      ..httpClientAdapter = adapter;
    client = DioAnthropicClient(
      dio: dio,
      keySource: () async => key,
      sleep: (Duration d) async => sleeps.add(d),
    );
  }

  final ScriptedHttpAdapter adapter;
  final _RecordingObserver observer = _RecordingObserver();
  final List<Duration> sleeps = <Duration>[];
  late final DioAnthropicClient client;

  Future<ClaudeMessage> send(ClaudeRequest r) => client.createMessage(r, observer: observer);

  Map<String, Object?> body(int i) =>
      (adapter.requests[i].data as Map).cast<String, Object?>();
}

ClaudeRequest _req({
  ClaudeEffort effort = ClaudeEffort.medium,
  ClaudeJsonSchema? schema,
  List<ClaudeMessageParam>? messages,
  String? system,
}) =>
    ClaudeRequest(
      messages: messages ?? <ClaudeMessageParam>[ClaudeMessageParam.userText('hi')],
      effort: effort,
      outputSchema: schema,
      system: system,
    );

void main() {
  group('请求', () {
    test('固定字段：model / stream / thinking adaptive / effort / fallbacks + 头', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_ok()]);
      await rig.send(_req(system: 'You are a director.'));

      final RequestOptions o = rig.adapter.requests.single;
      expect(o.method, 'POST');
      expect(o.path, '/v1/messages');
      expect(o.headers['x-api-key'], 'sk-ant-test');
      expect(o.headers['anthropic-version'], '2026-10-21');
      expect(o.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');

      final Map<String, Object?> b = rig.body(0);
      expect(b['model'], 'claude-opus-5-5');
      expect(b['stream'], isTrue);
      expect(b['max_tokens'], kClaudeDefaultMaxTokens);
      expect(b['thinking'], <String, Object?>{'type': 'adaptive'});
      expect(b['output_config'], <String, Object?>{'effort': 'medium'});
      expect(b['fallbacks'], 'default');
      expect(b['system'], 'You are a director.');
      expect(b['messages'], <Object?>[
        <String, Object?>{
          'role': 'user',
          'content': <Object?>[
            <String, Object?>{'type': 'text', 'text': 'hi'},
          ],
        },
      ]);
      for (final String banned in <String>['temperature', 'top_p', 'top_k', 'tool_choice']) {
        expect(b.containsKey(banned), isFalse, reason: '$banned 在该模型上会 400');
      }
    });

    test('effort 由调用方传；outputSchema → output_config.format json_schema', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_ok()]);
      final ClaudeJsonSchema schema = ClaudeJsonSchema(<String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'pass': <String, Object?>{'type': 'boolean'},
        },
        'required': <String>['pass'],
        'additionalProperties': false,
      });
      await rig.send(_req(effort: ClaudeEffort.high, schema: schema));

      expect(rig.body(0)['output_config'], <String, Object?>{
        'effort': 'high',
        'format': <String, Object?>{'type': 'json_schema', 'schema': schema.schema},
      });
    });

    test('图片走 base64 image 块，与文本块同一条 user 消息', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_ok()]);
      await rig.send(_req(messages: <ClaudeMessageParam>[
        ClaudeMessageParam(role: ClaudeRole.user, content: const <ClaudeContentBlock>[
          ClaudeImageBlock(mediaType: 'image/png', base64Data: 'iVBORw0KGgo='),
          ClaudeTextBlock('Review this keyframe.'),
        ]),
      ]));

      final List<Object?> content =
          ((rig.body(0)['messages'] as List).single as Map)['content'] as List;
      expect(content.first, <String, Object?>{
        'type': 'image',
        'source': <String, Object?>{
          'type': 'base64',
          'media_type': 'image/png',
          'data': 'iVBORw0KGgo=',
        },
      });
      expect(content.last, <String, Object?>{'type': 'text', 'text': 'Review this keyframe.'});
    });

    test('末轮是 assistant（= 预填）⇒ 本地拦下 invalidParameter，不发请求', () async {
      final _Rig rig = _Rig(const <ScriptedReply>[]);
      await expectLater(
        rig.send(_req(messages: <ClaudeMessageParam>[
          ClaudeMessageParam.userText('hi'),
          ClaudeMessageParam(
            role: ClaudeRole.assistant,
            content: const <ClaudeContentBlock>[ClaudeTextBlock('{')],
          ),
        ])),
        throwsA(isA<ProviderError>().having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
      expect(rig.adapter.requests, isEmpty);
    });
  });

  group('SSE 拼接', () {
    test('text 块按序拼接、thinking 内容不收；usage 合并 message_start + message_delta', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_ok()]);
      final ClaudeMessage m = await rig.send(_req());

      expect(m.id, 'msg_1');
      expect(m.model, 'claude-opus-5-5');
      expect(m.text, '{"shots":[1,2]}');
      expect(m.textBlocks, hasLength(1));
      expect(m.text.contains('secret'), isFalse);
      expect(m.stopReason, ClaudeStopReason.endTurn);
      expect(
        m.usage,
        const ClaudeUsage(
          inputTokens: 100,
          outputTokens: 42,
          cacheCreationInputTokens: 10,
          cacheReadInputTokens: 20,
        ),
      );
    });

    test('分块切断行与多字节字符照样拼对', () async {
      final List<String> frames = _okStream()
        ..insert(
          8,
          sseFrame('content_block_delta', <String, Object?>{
            'type': 'content_block_delta',
            'index': 1,
            'delta': <String, Object?>{'type': 'text_delta', 'text': '杜甫'},
          }),
        );
      final _Rig rig = _Rig(<ScriptedReply>[_ok(chunks: _rechunk(frames, 7))]);
      final ClaudeMessage m = await rig.send(_req());
      expect(m.text, '{"shots":[1,2]}杜甫');
    });

    test('流没走到 message_stop 就断 ⇒ 当可重试的服务端错误，重来一次成功', () async {
      final List<String> cut = _okStream()..removeLast();
      final _Rig rig = _Rig(<ScriptedReply>[_ok(chunks: cut), _ok()]);
      final ClaudeMessage m = await rig.send(_req());
      expect(m.text, '{"shots":[1,2]}');
      expect(rig.adapter.requests, hasLength(2));
    });

    test('流内 error 事件（overloaded）⇒ 重试', () async {
      final ScriptedReply overloaded = ScriptedReply(chunks: <String>[
        sseFrame('error', <String, Object?>{
          'type': 'error',
          'error': <String, Object?>{'type': 'overloaded_error', 'message': 'Overloaded'},
        }),
      ]);
      final _Rig rig = _Rig(<ScriptedReply>[overloaded, _ok()]);
      await rig.send(_req());
      expect(rig.adapter.requests, hasLength(2));
      expect(rig.sleeps, <Duration>[const Duration(seconds: 1)]);
    });
  });

  group('stop_reason', () {
    test('refusal ⇒ RefusalError(category)，不重试，用量照记', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        _ok(
          chunks: _okStream(
            stopReason: AnthropicStopReasons.refusal,
            stopDetails: <String, Object?>{'type': 'refusal', 'category': 'cyber'},
          ),
        ),
      ]);
      await expectLater(
        rig.send(_req()),
        throwsA(isA<RefusalError>()
            .having((e) => e.category, 'category', 'cyber')
            .having((e) => e.code, 'code', InkErrorCode.modelRefusal)),
      );
      expect(rig.adapter.requests, hasLength(1));
      expect(rig.observer.responses, hasLength(1));
    });

    test('refusal 而 stop_details 为 null ⇒ 仍是 RefusalError，category null', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        _ok(chunks: _okStream(stopReason: AnthropicStopReasons.refusal)),
      ]);
      await expectLater(
        rig.send(_req()),
        throwsA(isA<RefusalError>().having((e) => e.category, 'category', isNull)),
      );
    });

    test('max_tokens ⇒ ProviderError(outputTruncated)，不重试', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        _ok(chunks: _okStream(stopReason: AnthropicStopReasons.maxTokens)),
      ]);
      await expectLater(
        rig.send(_req()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.outputTruncated)
            .having((e) => e.retryable, 'retryable', isFalse)),
      );
      expect(rig.adapter.requests, hasLength(1));
      expect(rig.observer.responses, hasLength(1));
    });
  });

  group('重试', () {
    test('529 带 retry-after ⇒ 按它等，再试成功', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        _err(529, 'overloaded_error', headers: const <String, String>{'retry-after': '3'}),
        _ok(),
      ]);
      await rig.send(_req());
      expect(rig.sleeps, <Duration>[const Duration(seconds: 3)]);
      expect(rig.adapter.requests, hasLength(2));
    });

    test('429 → 500 无 retry-after ⇒ 指数退避 1s、2s，第三次成功', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        _err(429, 'rate_limit_error'),
        _err(500, 'api_error'),
        _ok(),
      ]);
      await rig.send(_req());
      expect(rig.sleeps, <Duration>[const Duration(seconds: 1), const Duration(seconds: 2)]);
    });

    test('retry-after 过长 ⇒ 封顶 60s', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        _err(429, 'rate_limit_error', headers: const <String, String>{'retry-after': '3600'}),
        _ok(),
      ]);
      await rig.send(_req());
      expect(rig.sleeps, <Duration>[const Duration(seconds: 60)]);
    });

    test('连接错误 ⇒ 重试', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        const ScriptedReply.fail(DioExceptionType.connectionError),
        _ok(),
      ]);
      await rig.send(_req());
      expect(rig.adapter.requests, hasLength(2));
    });

    test('连续 3 次 529 ⇒ 重试 2 次后放弃，抛 providerBusy', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        _err(529, 'overloaded_error'),
        _err(529, 'overloaded_error'),
        _err(529, 'overloaded_error'),
      ]);
      await expectLater(
        rig.send(_req()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerBusy)
            .having((e) => e.extra['status'], 'status', 529)),
      );
      expect(rig.adapter.requests, hasLength(3));
      expect(rig.sleeps, hasLength(2));
      expect(rig.adapter.remaining, 0);
    });

    test('401 ⇒ invalidKey，不重试', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_err(401, 'authentication_error')]);
      await expectLater(
        rig.send(_req()),
        throwsA(isA<ProviderError>().having((e) => e.code, 'code', InkErrorCode.invalidKey)),
      );
      expect(rig.adapter.requests, hasLength(1));
      expect(rig.sleeps, isEmpty);
    });

    test('400 ⇒ invalidParameter，带错误摘要，不重试', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_err(400, 'invalid_request_error')]);
      await expectLater(
        rig.send(_req()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)
            .having((e) => e.extra['body_code'], 'body_code', 'invalid_request_error')
            .having((e) => e.extra['body_message'], 'body_message', 'boom')),
      );
      expect(rig.adapter.requests, hasLength(1));
    });
  });

  group('Key 校验（GET /v1/models）', () {
    test('200 ⇒ valid；只带版本头不带 beta 头', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        ScriptedReply.json(200, <String, Object?>{'data': <Object?>[]}),
      ]);
      expect(await rig.client.validateApiKey('sk-ant-x'), const KeyValidationResult.valid());
      final RequestOptions o = rig.adapter.requests.single;
      expect(o.method, 'GET');
      expect(o.path, '/v1/models');
      expect(o.headers['x-api-key'], 'sk-ant-x');
      expect(o.headers['anthropic-version'], '2026-10-21');
      expect(o.headers.containsKey('anthropic-beta'), isFalse);
    });

    test('401 ⇒ invalid(invalidKey)', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_err(401, 'authentication_error')]);
      expect(
        await rig.client.validateApiKey('bad'),
        const KeyValidationResult.invalid(reason: KeyInvalidReason.invalidKey),
      );
    });

    test('402 ⇒ invalid(insufficientBalance)', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_err(402, 'billing_error')]);
      expect(
        await rig.client.validateApiKey('broke'),
        const KeyValidationResult.invalid(reason: KeyInvalidReason.insufficientBalance),
      );
    });

    test('连接错误 / 5xx ⇒ networkError（无法判定）', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        const ScriptedReply.fail(DioExceptionType.connectionError),
        _err(529, 'overloaded_error'),
      ]);
      expect(await rig.client.validateApiKey('k'), isA<KeyNetworkError>());
      expect(await rig.client.validateApiKey('k'), isA<KeyNetworkError>());
    });
  });

  group('观察口（入日志）', () {
    test('发出前交出原样请求体：与线上发送的逐字段相同，且不含 Key', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_ok()]);
      await rig.send(_req(system: 'sys'));

      expect(rig.observer.bodies, hasLength(1));
      expect(rig.observer.bodies.single, rig.body(0));
      expect(jsonEncode(rig.observer.bodies.single), jsonEncode(rig.body(0)));
      expect(jsonEncode(rig.observer.bodies.single), isNot(contains('sk-ant-test')));
    });

    test('重试的每一次都先交出，attempt 递增；没拿到用量的失败不报回应', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_err(529, 'overloaded_error'), _ok()]);
      await rig.send(_req());
      expect(rig.observer.attempts, <int>[0, 1]);
      expect(rig.observer.bodies[0], rig.body(1));
      expect(rig.observer.responses, hasLength(1));
    });

    test('成功回应：id / 模型 / 文本块 / 用量 / stop_reason', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_ok()]);
      await rig.send(_req());

      final ClaudeExchangeResponse r = rig.observer.responses.single;
      expect(r.id, 'msg_1');
      expect(r.model, 'claude-opus-5-5');
      expect(r.textBlocks, <String>['{"shots":[1,2]}']);
      expect(r.usage, const ClaudeUsage(
        inputTokens: 100,
        outputTokens: 42,
        cacheCreationInputTokens: 10,
        cacheReadInputTokens: 20,
      ));
      expect(r.stopReason, 'end_turn');
      expect(r.partial, isFalse);
    });

    test('拒答也交出回应（计费），带 category', () async {
      final _Rig rig = _Rig(<ScriptedReply>[
        _ok(
          chunks: _okStream(
            stopReason: AnthropicStopReasons.refusal,
            stopDetails: <String, Object?>{'type': 'refusal', 'category': 'cyber'},
          ),
        ),
      ]);
      await expectLater(rig.send(_req()), throwsA(isA<RefusalError>()));
      expect(rig.observer.responses.single.stopReason, 'refusal');
      expect(rig.observer.responses.single.refusalCategory, 'cyber');
    });

    test('观察口抛错 ⇒ 这次请求不发出', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_ok()]);
      await expectLater(
        rig.client.createMessage(_req(), observer: _FailingObserver()),
        throwsA(isA<LocalIOError>()),
      );
      expect(rig.adapter.requests, isEmpty);
    });

    test('不给观察口也照常工作', () async {
      final _Rig rig = _Rig(<ScriptedReply>[_ok()]);
      final ClaudeMessage m = await rig.client.createMessage(_req());
      expect(m.text, '{"shots":[1,2]}');
    });
  });
}

class _FailingObserver implements ClaudeExchangeObserver {
  @override
  Future<void> onRequest(Map<String, Object?> body, {required int attempt}) async =>
      throw const LocalIOError();

  @override
  Future<void> onResponse(ClaudeExchangeResponse response) async {}
}
