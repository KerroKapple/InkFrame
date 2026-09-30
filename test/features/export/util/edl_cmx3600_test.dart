// EDL CMX3600 写出器（P6 交付 B 的核心）——纯函数，序列片段表 → EDL 文本。
//
// 钉的是「达芬奇能读进去」的那几条硬规矩，不是「长得像 EDL」：
//   - 记录时间码必须**首尾相接**（上一条的 out == 下一条的 in），断开就错位；
//   - 帧位必须整数累加，不能每条各自从毫秒四舍五入（会漂）；
//   - 占位镜不出事件、但**照样占记录时间**（导成空隙），否则后面全提前。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/export/util/edl_cmx3600.dart';

/// 24fps 下 1 帧 = 41.666…ms；用帧数反推毫秒，免得测试里自己算错。
int ms(int frames) => (frames * 1000 / 24).round();

void main() {
  group('formatEdlTimecode', () {
    test('帧 → HH:MM:SS:FF', () {
      expect(formatEdlTimecode(0), '00:00:00:00');
      expect(formatEdlTimecode(23), '00:00:00:23');
      expect(formatEdlTimecode(24), '00:00:01:00');
      expect(formatEdlTimecode(24 * 60), '00:01:00:00');
      expect(formatEdlTimecode(24 * 3600), '01:00:00:00');
      // 时位溢出 24 小时不回绕——EDL 里出现 25 小时是合法的，回绕反而丢信息。
      expect(formatEdlTimecode(24 * 3600 * 25), '25:00:00:00');
    });

    test('负帧钳到 0，不写出负时间码', () {
      expect(formatEdlTimecode(-5), '00:00:00:00');
    });
  });

  group('buildCmx3600', () {
    test('头两行固定：TITLE + FCM NON-DROP FRAME', () {
      final List<String> lines = buildCmx3600(
        title: '山径破晓_v03',
        clips: const <DeliveryClip>[],
      ).split('\n');
      expect(lines[0], 'TITLE: 山径破晓_v03');
      expect(lines[1], 'FCM: NON-DROP FRAME');
    });

    test('单条事件：栏位与源/记录时间码', () {
      final String edl = buildCmx3600(
        title: 'T',
        clips: <DeliveryClip>[
          DeliveryClip(fileName: '001_镜头 01.mp4', durationMs: ms(48)),
        ],
        handleFrames: 12,
      );
      // 源片带 ±12 帧手柄 ⇒ 入点落在手柄之后，出点 = 入点 + 时长。
      // 记录起点默认 01:00:00:00。
      expect(
        edl,
        contains(
          '001  AX       V     C        '
          '00:00:00:12 00:00:02:12 01:00:00:00 01:00:02:00',
        ),
      );
      expect(edl, contains('* FROM CLIP NAME: 001_镜头 01.mp4'));
    });

    test('多条事件：记录时间码首尾相接，事件号三位递增', () {
      final String edl = buildCmx3600(
        title: 'T',
        clips: <DeliveryClip>[
          DeliveryClip(fileName: 'a.mp4', durationMs: ms(24)),
          DeliveryClip(fileName: 'b.mp4', durationMs: ms(12)),
          DeliveryClip(fileName: 'c.mp4', durationMs: ms(36)),
        ],
        handleFrames: 0,
      );
      expect(edl, contains('001  AX       V     C        00:00:00:00 00:00:01:00 01:00:00:00 01:00:01:00'));
      expect(edl, contains('002  AX       V     C        00:00:00:00 00:00:00:12 01:00:01:00 01:00:01:12'));
      expect(edl, contains('003  AX       V     C        00:00:00:00 00:00:01:12 01:00:01:12 01:00:03:00'));
    });

    test('毫秒不整除一帧时，记录端仍首尾相接（逐条取整会漂）', () {
      // 每条 100ms = 2.4 帧。逐条四舍五入成 2 帧、再各自从毫秒算记录位置，
      // 三条下来就会和累加值差出帧；正确做法是下一条的入点直接取上一条的出点。
      final String edl = buildCmx3600(
        title: 'T',
        clips: List<DeliveryClip>.generate(
          3,
          (int i) => DeliveryClip(fileName: '$i.mp4', durationMs: 100),
        ),
        handleFrames: 0,
      );
      final List<String> events = <String>[
        for (final String l in edl.split('\n'))
          if (RegExp(r'^\d{3}  AX').hasMatch(l)) l,
      ];
      expect(events, hasLength(3));
      String recIn(String e) => e.split(RegExp(r'\s+'))[6];
      String recOut(String e) => e.split(RegExp(r'\s+'))[7];
      expect(recOut(events[0]), recIn(events[1]));
      expect(recOut(events[1]), recIn(events[2]));
    });

    test('占位镜不出事件但占记录时间：后面那条的记录入点被推后', () {
      final String edl = buildCmx3600(
        title: 'T',
        clips: <DeliveryClip>[
          DeliveryClip(fileName: 'a.mp4', durationMs: ms(24)),
          DeliveryClip(fileName: '', durationMs: ms(48), placeholder: true),
          DeliveryClip(fileName: 'c.mp4', durationMs: ms(24)),
        ],
        handleFrames: 0,
      );
      // 只有两条事件（占位那镜是空隙）。
      expect(RegExp(r'^\d{3}  AX', multiLine: true).allMatches(edl).length, 2);
      // 第二条事件的记录入点 = 1 秒 + 2 秒 = 01:00:03:00。
      expect(edl, contains('002  AX       V     C        00:00:00:00 00:00:01:00 01:00:03:00 01:00:04:00'));
    });

    test('占位镜带标记：* LOC 行落在空隙起点', () {
      final String edl = buildCmx3600(
        title: 'T',
        clips: <DeliveryClip>[
          DeliveryClip(fileName: 'a.mp4', durationMs: ms(24)),
          DeliveryClip(
            fileName: '',
            durationMs: ms(24),
            placeholder: true,
            marker: '008 收尾空镜',
          ),
        ],
        handleFrames: 0,
      );
      expect(edl, contains('* LOC: 01:00:01:00 WHITE  008 收尾空镜'));
    });

    test('镜头语言备注写成 * COMMENT 行；为空时整行不写', () {
      final String edl = buildCmx3600(
        title: 'T',
        clips: <DeliveryClip>[
          DeliveryClip(
            fileName: 'a.mp4',
            durationMs: ms(24),
            comment: '中景 MS · 推镜 · 35mm',
          ),
          DeliveryClip(fileName: 'b.mp4', durationMs: ms(24)),
        ],
        handleFrames: 0,
      );
      expect(edl, contains('* COMMENT: 中景 MS · 推镜 · 35mm'));
      expect(RegExp(r'^\* COMMENT:', multiLine: true).allMatches(edl).length, 1);
    });

    test('记录起点可改（稿上默认 01:00:00:00，可改成 0）', () {
      final String edl = buildCmx3600(
        title: 'T',
        clips: <DeliveryClip>[
          DeliveryClip(fileName: 'a.mp4', durationMs: ms(24)),
        ],
        handleFrames: 0,
        recordStartFrames: 0,
      );
      expect(edl, contains('00:00:00:00 00:00:01:00 00:00:00:00 00:00:01:00'));
    });

    test('文件名超过 CMX3600 的注释行不截断——NLE 按整行读，截了就找不到媒体', () {
      final String long = '${'长' * 60}.mp4';
      final String edl = buildCmx3600(
        title: 'T',
        clips: <DeliveryClip>[DeliveryClip(fileName: long, durationMs: ms(24))],
      );
      expect(edl, contains('* FROM CLIP NAME: $long'));
    });

    test('以换行结尾——有的解析器丢掉没有行尾的最后一行', () {
      final String edl = buildCmx3600(
        title: 'T',
        clips: <DeliveryClip>[
          DeliveryClip(fileName: 'a.mp4', durationMs: ms(24)),
        ],
      );
      expect(edl.endsWith('\n'), isTrue);
    });
  });
}
