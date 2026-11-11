// Messages 流式响应（SSE）→ 最终消息的拼装。
//
// 两层：[parseSseEvents] 把字节流切成 (event, data) 帧；[ClaudeStreamAccumulator]
// 按事件类型累积 text 块、usage、stop_reason、stop_details。thinking 块只占位不收内容；
// fallback 块（服务端换模型的分界）也不收——续写的 text 块照常拼接。
import 'dart:convert';

import '../../core/errors/ink_error.dart';
import '../../core/models/claude_message.dart';
import 'anthropic_protocol.dart';
import 'claude_error_mapper.dart';

/// 一帧 SSE。
class SseFrame {
  const SseFrame({required this.event, required this.data});
  final String? event;
  final String data;
}

/// 字节流 → SSE 帧。空行分帧；`data:` 多行按 \n 拼；`:` 开头是注释。
Stream<SseFrame> parseSseEvents(Stream<List<int>> bytes) async* {
  String? event;
  final StringBuffer data = StringBuffer();
  bool hasData = false;
  await for (final String line
      in bytes.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (hasData) yield SseFrame(event: event, data: data.toString());
      event = null;
      data.clear();
      hasData = false;
      continue;
    }
    if (line.startsWith(':')) continue;
    final int colon = line.indexOf(':');
    final String field = colon < 0 ? line : line.substring(0, colon);
    String value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'event') {
      event = value;
    } else if (field == 'data') {
      if (hasData) data.write('\n');
      data.write(value);
      hasData = true;
    }
  }
  if (hasData) yield SseFrame(event: event, data: data.toString());
}

/// 流结束后的原始结局：stop_reason 尚未翻译成成功 / 错误。
class ClaudeStreamResult {
  const ClaudeStreamResult({
    required this.id,
    required this.model,
    required this.textBlocks,
    required this.usage,
    required this.stopReason,
    required this.refusalCategory,
  });

  final String id;
  final String model;
  final List<String> textBlocks;
  final ClaudeUsage usage;
  final String? stopReason;
  final String? refusalCategory;
}

class ClaudeStreamAccumulator {
  String _id = '';
  String _model = '';
  final Map<int, StringBuffer> _texts = <int, StringBuffer>{};
  int _input = 0;
  int _output = 0;
  int _cacheWrite = 0;
  int _cacheRead = 0;
  String? _stopReason;
  String? _category;
  bool _stopped = false;

  /// 喂一帧。服务端 error 事件 → 抛映射后的 InkError（可重试性按 error.type）。
  void add(SseFrame frame) {
    final Object? decoded;
    try {
      decoded = jsonDecode(frame.data);
    } on FormatException catch (e) {
      throw ProviderError(
        code: InkErrorCode.providerInvalidResponse,
        extra: const <String, Object?>{
          'provider_id': AnthropicProtocol.clientId,
          'reason': 'sse_bad_json',
        },
        cause: e,
      );
    }
    if (decoded is! Map) return;
    final Object? type = decoded[AnthropicJson.type] ?? frame.event;
    switch (type) {
      case AnthropicEvents.messageStart:
        final Object? msg = decoded[AnthropicJson.message];
        if (msg is Map) {
          _id = _str(msg[AnthropicJson.id]) ?? _id;
          _model = _str(msg[AnthropicJson.model]) ?? _model;
          _mergeUsage(msg[AnthropicJson.usage]);
        }
      case AnthropicEvents.contentBlockStart:
        final Object? block = decoded[AnthropicJson.contentBlock];
        final int? index = _int(decoded[AnthropicJson.index]);
        if (index != null && block is Map && block[AnthropicJson.type] == AnthropicJson.text) {
          _texts[index] = StringBuffer(_str(block[AnthropicJson.text]) ?? '');
        }
      case AnthropicEvents.contentBlockDelta:
        final Object? delta = decoded[AnthropicJson.delta];
        final int? index = _int(decoded[AnthropicJson.index]);
        if (index != null && delta is Map && delta[AnthropicJson.type] == AnthropicEvents.textDelta) {
          _texts.putIfAbsent(index, StringBuffer.new).write(_str(delta[AnthropicJson.text]) ?? '');
        }
      case AnthropicEvents.messageDelta:
        final Object? delta = decoded[AnthropicJson.delta];
        if (delta is Map) {
          _stopReason = _str(delta[AnthropicJson.stopReason]) ?? _stopReason;
          _readStopDetails(delta[AnthropicJson.stopDetails]);
        }
        _readStopDetails(decoded[AnthropicJson.stopDetails]);
        _mergeUsage(decoded[AnthropicJson.usage]);
      case AnthropicEvents.messageStop:
        _stopped = true;
      case AnthropicEvents.error:
        throw mapClaudeErrorBody(null, decoded);
      default:
        // ping / content_block_stop / 未知事件：忽略。
        break;
    }
  }

  /// 流正常走完。没收到 message_stop ⇒ 流被截断，按可重试的服务端错误处理。
  ClaudeStreamResult finish() {
    if (!_stopped) {
      throw const ProviderError(
        code: InkErrorCode.providerServer,
        extra: <String, Object?>{
          'provider_id': AnthropicProtocol.clientId,
          'reason': 'stream_ended_early',
        },
      );
    }
    return current();
  }

  /// 到目前为止拼出的结果（流中途失败时入日志用；不做完整性检查）。
  ClaudeStreamResult current() {
    final List<int> order = _texts.keys.toList()..sort();
    return ClaudeStreamResult(
      id: _id,
      model: _model,
      textBlocks: <String>[for (final int i in order) _texts[i]!.toString()],
      usage: usage,
      stopReason: _stopReason,
      refusalCategory: _category,
    );
  }

  /// 到目前为止的用量（流中途失败时也能记账）。
  ClaudeUsage get usage => ClaudeUsage(
        inputTokens: _input,
        outputTokens: _output,
        cacheCreationInputTokens: _cacheWrite,
        cacheReadInputTokens: _cacheRead,
      );

  String get model => _model;

  // message_delta 的 usage 是累计值：出现的字段直接覆盖。
  void _mergeUsage(Object? raw) {
    if (raw is! Map) return;
    _input = _int(raw[AnthropicJson.inputTokens]) ?? _input;
    _output = _int(raw[AnthropicJson.outputTokens]) ?? _output;
    _cacheWrite = _int(raw[AnthropicJson.cacheCreationInputTokens]) ?? _cacheWrite;
    _cacheRead = _int(raw[AnthropicJson.cacheReadInputTokens]) ?? _cacheRead;
  }

  void _readStopDetails(Object? raw) {
    if (raw is Map) _category = _str(raw[AnthropicJson.category]) ?? _category;
  }
}

String? _str(Object? v) => v is String ? v : null;
int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
