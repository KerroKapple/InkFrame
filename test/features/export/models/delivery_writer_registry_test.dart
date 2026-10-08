// 写出器 registry（P6）——「某个目标软件能不能选」的**唯一**判据。
//
// 这条测试存在的理由：可选性必须由「registry 里有没有这个 id」回答，不能由
// 枚举上的硬编码布尔回答。否则将来接上剪映写出器，还得记得回去改枚举——
// 忘了改，功能就静默不可用。下面最后一组就是把这件事钉死：**同一个
// DeliveryTarget，registry 多一个写出器，它自己就变可选**。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/export/models/delivery_plan.dart';
import 'package:inkframe/features/export/models/delivery_settings.dart';
import 'package:inkframe/features/export/models/delivery_writer_registry.dart';
import 'package:inkframe/features/export/util/edl_cmx3600.dart';

/// 24fps 下用帧数反推毫秒，免得测试里自己算错。
int ms(int frames) => (frames * 1000 / 24).round();

DeliveryShotPlan _shot({
  required int index,
  String name = 'shot',
  String? fileName,
  int frames = 24,
  bool placeholder = false,
  String? comment,
  String? marker,
}) =>
    DeliveryShotPlan(
      index: index,
      nodeId: 'n$index',
      name: name,
      durationMs: ms(frames),
      durationFrames: frames,
      isPlaceholder: placeholder,
      fileName: fileName,
      comment: comment,
      marker: marker,
    );

class _FakeJianyingWriter implements DeliveryProjectWriter {
  @override
  String get id => DeliveryWriterIds.jianyingDraft;
  @override
  String get fileExtension => 'json';
  @override
  String write(DeliveryPlan plan) => '{}';
}

void main() {
  group('每个目标软件声明它需要的写出器 id', () {
    test('id 是英文协议字面量（不随 UI 语言变）', () {
      expect(DeliveryTarget.resolve.writerId, DeliveryWriterIds.edlCmx3600);
      expect(DeliveryTarget.premiere.writerId, DeliveryWriterIds.edlCmx3600);
      expect(DeliveryTarget.finalCut.writerId, DeliveryWriterIds.fcpXml);
      expect(DeliveryTarget.jianying.writerId, DeliveryWriterIds.jianyingDraft);
    });

    test('四档都声明了写出器 id——不许有空', () {
      for (final DeliveryTarget t in DeliveryTarget.values) {
        expect(t.writerId, isNotEmpty, reason: '$t 没声明写出器 id');
      }
    });
  });

  group('出厂 registry：只有 EDL 一个写出器', () {
    final DeliveryWriterRegistry reg = MapDeliveryWriterRegistry.production();

    test('Resolve / Premiere 可选', () {
      expect(reg.supports(DeliveryTarget.resolve), isTrue);
      expect(reg.supports(DeliveryTarget.premiere), isTrue);
    });

    test('Final Cut / 剪映查不到写出器 ⇒ 不可选', () {
      expect(reg.supports(DeliveryTarget.finalCut), isFalse);
      expect(reg.supports(DeliveryTarget.jianying), isFalse);
      expect(reg.forTarget(DeliveryTarget.finalCut), isNull);
      expect(reg.forTarget(DeliveryTarget.jianying), isNull);
    });

    test('按 id 查：有的给实例，没有的给 null', () {
      expect(reg.has(DeliveryWriterIds.edlCmx3600), isTrue);
      expect(reg.find(DeliveryWriterIds.edlCmx3600), isNotNull);
      expect(reg.has(DeliveryWriterIds.fcpXml), isFalse);
      expect(reg.find('nope'), isNull);
    });
  });

  group('接上写出器 ⇒ 那一段自动变可选（枚举一个字都不用改）', () {
    test('registry 多一个 jianying-draft，剪映当场可选', () {
      final DeliveryWriterRegistry reg = MapDeliveryWriterRegistry(
        <DeliveryProjectWriter>[const EdlCmx3600Writer(), _FakeJianyingWriter()],
      );
      expect(reg.supports(DeliveryTarget.jianying), isTrue);
      expect(reg.forTarget(DeliveryTarget.jianying)?.fileExtension, 'json');
      // 其余三档不受影响。
      expect(reg.supports(DeliveryTarget.resolve), isTrue);
      expect(reg.supports(DeliveryTarget.finalCut), isFalse);
    });

    test('空 registry ⇒ 一档都不可选（UI 得全禁用，不是崩）', () {
      const DeliveryWriterRegistry reg =
          MapDeliveryWriterRegistry(<DeliveryProjectWriter>[]);
      for (final DeliveryTarget t in DeliveryTarget.values) {
        expect(reg.supports(t), isFalse);
      }
    });
  });

  group('EDL 写出器：计划 → CMX3600 文本', () {
    const DeliveryProjectWriter w = EdlCmx3600Writer();

    test('自报 id 与扩展名', () {
      expect(w.id, DeliveryWriterIds.edlCmx3600);
      expect(w.fileExtension, 'edl');
    });

    test('TITLE 取项目名；记录起点取设置里的时间码起点', () {
      final String edl = w.write(
        DeliveryPlan(
          projectName: '山径破晓',
          settings: DeliverySettings.defaults,
          shots: <DeliveryShotPlan>[
            _shot(index: 1, fileName: '001_a.mp4', frames: 24),
          ],
        ),
      );
      expect(edl.split('\n').first, 'TITLE: 山径破晓');
      expect(edl, contains('01:00:00:00 01:00:01:00'), reason: '默认起点 01:00:00:00');
    });

    test('手柄恒为 0：导出的媒体就是整条文件，没有余量可取', () {
      final String edl = w.write(
        DeliveryPlan(
          projectName: 'T',
          settings: DeliverySettings.defaults,
          shots: <DeliveryShotPlan>[
            _shot(index: 1, fileName: '001_a.mp4', frames: 48),
          ],
        ),
      );
      // 源入点落在 0 而不是 12——写 12 的话 Resolve 会去媒体外面找帧。
      expect(
        edl,
        contains(
          '001  AX       V     C        '
          '00:00:00:00 00:00:02:00 01:00:00:00 01:00:02:00',
        ),
      );
    });

    test('相对路径开关：默认只写文件名；关掉时 FROM CLIP NAME 写绝对路径', () {
      DeliveryPlan planOf({String? dir}) => DeliveryPlan(
            projectName: 'T',
            settings: DeliverySettings.defaults,
            shots: <DeliveryShotPlan>[
              _shot(index: 1, fileName: '001_a.mp4', frames: 24),
            ],
            mediaDirAbsolutePath: dir,
          );
      expect(w.write(planOf()), contains('* FROM CLIP NAME: 001_a.mp4'));
      final String abs = w.write(planOf(dir: '/tmp/p1/exports'));
      expect(abs, contains('* FROM CLIP NAME: /tmp/p1/exports'));
      expect(abs, contains('001_a.mp4'));
    });

    test('与写出器直调逐字相等（registry 只是转接，不改字）', () {
      final DeliveryPlan plan = DeliveryPlan(
        projectName: 'T',
        settings: DeliverySettings.defaults.copyWith(timecodeStartFrames: 0),
        shots: <DeliveryShotPlan>[
          _shot(index: 1, fileName: '001_a.mp4', frames: 24, comment: 'medium shot', marker: '场次一'),
          _shot(index: 2, name: '空镜', frames: 12, placeholder: true, marker: '场次二'),
          _shot(index: 3, fileName: '003_c.mp4', frames: 36),
        ],
      );
      final String expected = buildCmx3600(
        title: 'T',
        handleFrames: 0,
        recordStartFrames: 0,
        clips: <DeliveryClip>[
          DeliveryClip(
            fileName: '001_a.mp4',
            durationMs: ms(24),
            comment: 'medium shot',
            marker: '场次一',
          ),
          DeliveryClip(
            fileName: '',
            durationMs: ms(12),
            marker: '场次二',
            placeholder: true,
          ),
          DeliveryClip(fileName: '003_c.mp4', durationMs: ms(36)),
        ],
      );
      expect(w.write(plan), expected);
      // 占位镜不出事件：三镜只有两条事件号。
      expect(w.write(plan).contains('003  AX'), isFalse);
      expect(w.write(plan), contains('002  AX'));
    });
  });
}
