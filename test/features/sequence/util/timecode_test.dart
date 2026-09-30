// 时间码（Timeline 稿，24fps 帧位）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/sequence/util/timecode.dart';

void main() {
  test('formatTimecode：HH:MM:SS:FF，帧位按 24fps 向下取整', () {
    expect(formatTimecode(0), '00:00:00:00');
    expect(formatTimecode(1000), '00:00:01:00');
    expect(formatTimecode(1500), '00:00:01:12');
    expect(formatTimecode(999), '00:00:00:23');
    expect(formatTimecode(3661041), '01:01:01:00', reason: '41ms 不足一帧');
    expect(formatTimecode(-7), '00:00:00:00', reason: '负数夹 0');
  });

  test('formatTimecodeShort：不足一分钟 SS:FF，否则 MM:SS:FF', () {
    expect(formatTimecodeShort(3000), '03:00');
    expect(formatTimecodeShort(4250), '04:06');
    expect(formatTimecodeShort(62000), '01:02:00');
  });
}
