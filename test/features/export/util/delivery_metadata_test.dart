// metadata.json（P6 §4）：交付目录里那份「这条时间线是怎么生成出来的」。
//
// 键名全是英文协议字面量（不随界面语言变）。空值一律**省略键**而不是写 null——
// 唯一例外是占位镜的 `file`，它必须显式为 null（「这一镜没有文件」是信息，不是缺失）。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/provider_capabilities.dart'
    show CameraMovement;
import 'package:inkframe/core/models/shot_language.dart';
import 'package:inkframe/features/export/models/delivery_plan.dart';
import 'package:inkframe/features/export/models/delivery_settings.dart';
import 'package:inkframe/features/export/util/delivery_metadata.dart';

final DateTime _at = DateTime.utc(2026, 10, 8, 9);

DeliveryShotPlan _full() => const DeliveryShotPlan(
      index: 1,
      nodeId: 'n1',
      name: '山径入镜',
      durationMs: 5000,
      durationFrames: 120,
      isPlaceholder: false,
      fileName: '001_山径入镜.mp4',
      sourceRelativePath: 'canvases/c1/videos/a.mp4',
      width: 1920,
      height: 1080,
      providerId: 'kling-v3',
      seed: 41207,
      prompt: 'a misty trail',
      stylePrompt: 'ink wash',
      shotLanguage: ShotLanguage(
        shotSize: ShotSize.mediumShot,
        cameraAngle: CameraAngle.eyeLevel,
        motionStrength: 0.35,
        focalLengthMm: 35,
      ),
      cameraMovement: CameraMovement.pushIn,
    );

DeliveryShotPlan _bare() => const DeliveryShotPlan(
      index: 2,
      nodeId: 'n2',
      name: '收尾空镜',
      durationMs: 4000,
      durationFrames: 96,
      isPlaceholder: true,
    );

Map<String, Object?> _decode(
  List<DeliveryShotPlan> shots, {
  DeliverySettings settings = DeliverySettings.defaults,
  String projectName = '山径破晓',
}) =>
    jsonDecode(
      buildDeliveryMetadataJson(
        plan: DeliveryPlan(
          projectName: projectName,
          shots: shots,
          settings: settings,
        ),
        exportedAt: _at,
      ),
    ) as Map<String, Object?>;

void main() {
  group('顶层结构', () {
    test('project / exportedAt / fps / timecodeStart / shots', () {
      final Map<String, Object?> m = _decode(<DeliveryShotPlan>[_full()]);
      expect(m.keys.toList(), <String>[
        'project',
        'exportedAt',
        'fps',
        'timecodeStart',
        'shots',
      ]);
      expect(m['project'], '山径破晓');
      expect(m['exportedAt'], '2026-10-08T09:00:00.000Z');
      expect(m['fps'], 24);
      expect(m['timecodeStart'], '01:00:00:00');
      expect((m['shots']! as List<Object?>).length, 1);
    });

    test('时间码起点跟着设置变', () {
      final Map<String, Object?> m = _decode(
        <DeliveryShotPlan>[_full()],
        settings: DeliverySettings.defaults.copyWith(timecodeStartFrames: 0),
      );
      expect(m['timecodeStart'], '00:00:00:00');
    });

    test('exportedAt 恒为 UTC（本地时区不进文件）', () {
      final String json = buildDeliveryMetadataJson(
        plan: DeliveryPlan(
          projectName: 'P',
          shots: <DeliveryShotPlan>[_full()],
          settings: DeliverySettings.defaults,
        ),
        exportedAt: DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal(),
      );
      final Map<String, Object?> m = jsonDecode(json) as Map<String, Object?>;
      expect(m['exportedAt'], '2026-01-02T03:04:05.000Z');
    });
  });

  group('每一镜', () {
    test('全字段都有时逐个落位', () {
      final Map<String, Object?> s =
          (_decode(<DeliveryShotPlan>[_full()])['shots']! as List<Object?>)
              .first as Map<String, Object?>;
      expect(s['index'], 1);
      expect(s['name'], '山径入镜');
      expect(s['file'], '001_山径入镜.mp4');
      expect(s['durationFrames'], 120);
      expect(s['isPlaceholder'], false);
      expect(s['provider'], 'kling-v3');
      expect(s['seed'], 41207);
      expect(s['prompt'], 'a misty trail');
      expect(s['stylePrompt'], 'ink wash');
      expect(s['shotLanguage'], <String, Object?>{
        'shotSize': 'MS',
        'cameraAngle': 'eye_level',
        'cameraMotion': 'dolly_in',
        'motionStrength': 0.35,
        'focalLengthMm': 35,
      });
    });

    test('占位镜：file 显式为 null，isPlaceholder 为真', () {
      final Map<String, Object?> s =
          (_decode(<DeliveryShotPlan>[_bare()])['shots']! as List<Object?>)
              .first as Map<String, Object?>;
      expect(s.containsKey('file'), isTrue);
      expect(s['file'], isNull);
      expect(s['isPlaceholder'], true);
      expect(s['durationFrames'], 96);
    });

    test('空值省略键：provider / seed / prompt / stylePrompt / shotLanguage', () {
      final Map<String, Object?> s =
          (_decode(<DeliveryShotPlan>[_bare()])['shots']! as List<Object?>)
              .first as Map<String, Object?>;
      for (final String k in <String>[
        'provider',
        'seed',
        'prompt',
        'stylePrompt',
        'shotLanguage',
      ]) {
        expect(s.containsKey(k), isFalse, reason: '$k 为空时应整键省略');
      }
    });

    test('shotLanguage 只写设了的那几项', () {
      const DeliveryShotPlan partial = DeliveryShotPlan(
        index: 1,
        nodeId: 'n1',
        name: 'x',
        durationMs: 1000,
        durationFrames: 24,
        isPlaceholder: false,
        fileName: '001_x.mp4',
        shotLanguage: ShotLanguage(shotSize: ShotSize.closeUp),
      );
      final Map<String, Object?> s =
          (_decode(<DeliveryShotPlan>[partial])['shots']! as List<Object?>)
              .first as Map<String, Object?>;
      expect(s['shotLanguage'], <String, Object?>{'shotSize': 'CU'});
    });

    test('只有运镜、镜头语言四项全空 → shotLanguage 仍要有（运镜是它的一员）', () {
      const DeliveryShotPlan onlyCamera = DeliveryShotPlan(
        index: 1,
        nodeId: 'n1',
        name: 'x',
        durationMs: 1000,
        durationFrames: 24,
        isPlaceholder: false,
        fileName: '001_x.mp4',
        cameraMovement: CameraMovement.orbit,
      );
      final Map<String, Object?> s =
          (_decode(<DeliveryShotPlan>[onlyCamera])['shots']! as List<Object?>)
              .first as Map<String, Object?>;
      expect(s['shotLanguage'], <String, Object?>{'cameraMotion': 'arc_shot'});
    });

    test('景别缩写与机位角度 / 运镜的 wire 值逐个钉死（跨工具可读）', () {
      expect(shotSizeMetadataValue(ShotSize.extremeLongShot), 'ELS');
      expect(shotSizeMetadataValue(ShotSize.longShot), 'LS');
      expect(shotSizeMetadataValue(ShotSize.mediumShot), 'MS');
      expect(shotSizeMetadataValue(ShotSize.mediumCloseUp), 'MCU');
      expect(shotSizeMetadataValue(ShotSize.closeUp), 'CU');
      expect(shotSizeMetadataValue(ShotSize.extremeCloseUp), 'ECU');
      expect(cameraAngleMetadataValue(CameraAngle.birdsEye), 'birds_eye');
      expect(cameraAngleMetadataValue(CameraAngle.dutch), 'dutch_angle');
      expect(cameraMotionMetadataValue(CameraMovement.static_), 'static_camera');
      expect(cameraMotionMetadataValue(CameraMovement.pullOut), 'dolly_out');
      expect(cameraMotionMetadataValue(CameraMovement.tracking), 'tracking_shot');
    });
  });

  test('输出是人读得懂的缩进 JSON（用户会打开它）', () {
    final String json = buildDeliveryMetadataJson(
      plan: DeliveryPlan(
        projectName: 'P',
        shots: <DeliveryShotPlan>[_full()],
        settings: DeliverySettings.defaults,
      ),
      exportedAt: _at,
    );
    expect(json, contains('\n  "project": "P"'));
    expect(json.endsWith('\n'), isTrue, reason: '文本文件以换行收尾');
  });

  test('空链：shots 为空数组，不是缺键', () {
    final Map<String, Object?> m = _decode(const <DeliveryShotPlan>[]);
    expect(m['shots'], isEmpty);
  });
}
