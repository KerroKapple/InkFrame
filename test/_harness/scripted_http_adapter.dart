// ScriptedHttpAdapter：按脚本逐个回放响应的 dio HttpClientAdapter。
//
// http_mock_adapter 回不了分块字节流、也不好做「同一路径第 N 次回不同结果」；
// 流式（SSE）与重试场景用这个。每次 fetch 记下 RequestOptions（含原始 data），
// 按顺序消费一条 [ScriptedReply]；脚本用完再请求直接让测试失败。
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 一条回放：要么 HTTP 响应（状态 + 头 + 分块 body），要么抛 DioException。
class ScriptedReply {
  const ScriptedReply({
    this.status = 200,
    this.headers = const <String, String>{},
    this.chunks = const <String>[],
  }) : errorType = null;

  /// 传输层失败（连接错误 / 超时等）。
  const ScriptedReply.fail(DioExceptionType this.errorType)
      : status = 0,
        headers = const <String, String>{},
        chunks = const <String>[];

  /// JSON body 一次性回。
  ScriptedReply.json(int status, Object body, {Map<String, String> headers = const <String, String>{}})
      : this(status: status, headers: headers, chunks: <String>[jsonEncode(body)]);

  final int status;
  final Map<String, String> headers;

  /// body 分块（逐块下发，用来测跨块拼接）。
  final List<String> chunks;
  final DioExceptionType? errorType;
}

class ScriptedHttpAdapter implements HttpClientAdapter {
  ScriptedHttpAdapter(List<ScriptedReply> replies)
      : _queue = List<ScriptedReply>.of(replies);

  final List<ScriptedReply> _queue;

  /// 已发出的请求，按顺序。
  final List<RequestOptions> requests = <RequestOptions>[];

  int get remaining => _queue.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_queue.isEmpty) {
      throw StateError('ScriptedHttpAdapter: 脚本已用完，多发了一次请求 ${options.path}');
    }
    final ScriptedReply r = _queue.removeAt(0);
    final DioExceptionType? type = r.errorType;
    if (type != null) {
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody(
      Stream<Uint8List>.fromIterable(
        r.chunks.map((String c) => Uint8List.fromList(utf8.encode(c))),
      ),
      r.status,
      headers: <String, List<String>>{
        for (final MapEntry<String, String> h in r.headers.entries)
          h.key: <String>[h.value],
        Headers.contentTypeHeader: <String>[
          r.headers[Headers.contentTypeHeader] ?? Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 拼一帧 SSE（event + data 一行 JSON + 空行）。
String sseFrame(String event, Map<String, Object?> data) =>
    'event: $event\ndata: ${jsonEncode(data)}\n\n';
