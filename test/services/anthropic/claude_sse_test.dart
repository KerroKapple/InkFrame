// SSE 帧切分：注释行、多行 data、无 event 名、末帧缺空行。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/services/anthropic/claude_sse.dart';

Stream<List<int>> _bytes(String s) => Stream<List<int>>.value(utf8.encode(s));

void main() {
  test('注释跳过、多行 data 以换行拼接、event 可缺省', () async {
    final List<SseFrame> frames = await parseSseEvents(
      _bytes(': keep-alive\nevent: a\ndata: {"x":\ndata: 1}\n\ndata: {"type":"ping"}\n\n'),
    ).toList();
    expect(frames, hasLength(2));
    expect(frames[0].event, 'a');
    expect(frames[0].data, '{"x":\n1}');
    expect(frames[1].event, isNull);
  });

  test('流尾没有空行也交出最后一帧', () async {
    final List<SseFrame> frames =
        await parseSseEvents(_bytes('event: message_stop\ndata: {}')).toList();
    expect(frames.single.event, 'message_stop');
  });

  test('data 不是 JSON ⇒ providerInvalidResponse', () {
    expect(
      () => ClaudeStreamAccumulator().add(const SseFrame(event: 'x', data: 'not json')),
      throwsA(isA<ProviderError>()
          .having((e) => e.code, 'code', InkErrorCode.providerInvalidResponse)),
    );
  });
}
