// 交付设置（P6）——按项目持久化的那一小撮。
//
// 钉的是容错解析：这份设置存在 `projects.delivery_settings` 这个 JSONB 列里，
// 旧项目是空对象 `{}`，手改坏了的值也可能进来。**解析绝不能抛**——一个坏字段
// 不该让项目打不开，只该退回默认。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/export/models/delivery_settings.dart';

void main() {
  group('默认值 = 稿上那一屏的初始态', () {
    test('空 map → 全默认', () {
      const DeliverySettings d = DeliverySettings.defaults;
      expect(DeliverySettings.fromMap(const <String, Object?>{}), d);
      expect(d.target, DeliveryTarget.resolve);
      // 01:00:00:00 @ 24fps。
      expect(d.timecodeStartFrames, 86400);
      expect(d.relativePaths, isTrue);
      expect(d.markersFromScenes, isTrue);
      expect(d.shotLanguageInComments, isTrue);
      // 稿上只有这一个开关是关的。
      expect(d.promptInMetadata, isFalse);
    });
  });

  group('fromMap 容错：坏值退默认，不抛', () {
    test('目标软件是没见过的串 → 退 Resolve', () {
      expect(
        DeliverySettings.fromMap(const <String, Object?>{'target': 'avid'}).target,
        DeliveryTarget.resolve,
      );
    });

    test('目标软件类型不对 → 退 Resolve', () {
      expect(
        DeliverySettings.fromMap(const <String, Object?>{'target': 7}).target,
        DeliveryTarget.resolve,
      );
    });

    test('开关不是 bool → 退默认，不是当成真', () {
      final DeliverySettings d = DeliverySettings.fromMap(
        const <String, Object?>{'prompt_in_metadata': 'yes', 'relative_paths': 1},
      );
      expect(d.promptInMetadata, isFalse);
      expect(d.relativePaths, isTrue);
    });

    test('时间码起点为负 / 非数 → 退默认；合法值照收', () {
      expect(
        DeliverySettings.fromMap(const <String, Object?>{'tc_start_frames': -1})
            .timecodeStartFrames,
        86400,
      );
      expect(
        DeliverySettings.fromMap(const <String, Object?>{'tc_start_frames': 'x'})
            .timecodeStartFrames,
        86400,
      );
      expect(
        DeliverySettings.fromMap(const <String, Object?>{'tc_start_frames': 0})
            .timecodeStartFrames,
        0,
      );
    });

    test('整个 map 为 null（列读出来是 null）→ 全默认', () {
      expect(DeliverySettings.fromMap(null), DeliverySettings.defaults);
    });
  });

  test('toMap / fromMap 往返不丢', () {
    const DeliverySettings d = DeliverySettings(
      target: DeliveryTarget.premiere,
      timecodeStartFrames: 0,
      relativePaths: false,
      markersFromScenes: false,
      shotLanguageInComments: false,
      promptInMetadata: true,
    );
    expect(DeliverySettings.fromMap(d.toMap()), d);
  });

  test('JSON 键是英文协议字面量，不随 UI 语言变', () {
    expect(
      DeliverySettings.defaults.toMap().keys.toSet(),
      <String>{
        'target',
        'tc_start_frames',
        'relative_paths',
        'markers_from_scenes',
        'shot_language_in_comments',
        'prompt_in_metadata',
      },
    );
    expect(DeliverySettings.defaults.toMap()['target'], 'resolve');
  });

  group('copyWith', () {
    test('只改给到的那一项', () {
      final DeliverySettings d = DeliverySettings.defaults.copyWith(
        promptInMetadata: true,
      );
      expect(d.promptInMetadata, isTrue);
      expect(d.target, DeliveryTarget.resolve);
      expect(d.relativePaths, isTrue);
    });
  });

  group('writesEdl：哪些目标软件走 EDL', () {
    test('Resolve / Premiere 出 EDL', () {
      expect(DeliveryTarget.resolve.writesEdl, isTrue);
      expect(DeliveryTarget.premiere.writesEdl, isTrue);
    });

    test('Final Cut 与剪映都还没有写出器——不能让它们看起来能导', () {
      expect(DeliveryTarget.finalCut.writesEdl, isFalse);
      expect(DeliveryTarget.jianying.writesEdl, isFalse);
      expect(DeliveryTarget.finalCut.supported, isFalse);
      expect(DeliveryTarget.jianying.supported, isFalse);
      expect(DeliveryTarget.resolve.supported, isTrue);
      expect(DeliveryTarget.premiere.supported, isTrue);
    });
  });
}
