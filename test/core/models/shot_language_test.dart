// ShotLanguage（P3）：type_config ↔ 值的解析与补丁。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/shot_language.dart';

void main() {
  test('缺键 / 非法值 → 全 null，isEmpty', () {
    final ShotLanguage a = ShotLanguage.fromTypeConfig(const <String, Object?>{});
    expect(a, ShotLanguage.empty);
    expect(a.isEmpty, isTrue);

    final ShotLanguage b = ShotLanguage.fromTypeConfig(const <String, Object?>{
      'shot_size': 'zoomBlur',
      'camera_angle': 42,
      'camera_motion_strength': 'high',
      'focal_length_mm': 40, // 不在可选表里
    });
    expect(b, ShotLanguage.empty);
  });

  test('合法值解析；幅度夹到 0–1；焦段只认可选表', () {
    final ShotLanguage s = ShotLanguage.fromTypeConfig(const <String, Object?>{
      'shot_size': 'mediumShot',
      'camera_angle': 'eyeLevel',
      'camera_motion_strength': 1.7,
      'focal_length_mm': 35,
    });
    expect(s.shotSize, ShotSize.mediumShot);
    expect(s.cameraAngle, CameraAngle.eyeLevel);
    expect(s.motionStrength, 1.0);
    expect(s.focalLengthMm, 35);
    expect(s.isEmpty, isFalse);
    expect(ShotLanguage.fromTypeConfig(const <String, Object?>{'camera_motion_strength': 0}).motionStrength, 0.0,
        reason: 'int 也当 num 收');
  });

  test('toTypeConfigPatch 四键齐全：设的写值、没设的写 null（合并时即清除）', () {
    const ShotLanguage s = ShotLanguage(shotSize: ShotSize.closeUp, focalLengthMm: 85);
    expect(s.toTypeConfigPatch(), <String, Object?>{
      'shot_size': 'closeUp',
      'camera_angle': null,
      'camera_motion_strength': null,
      'focal_length_mm': 85,
    });
    expect(ShotLanguage.fromTypeConfig(s.toTypeConfigPatch()), s, reason: '往返一致');
  });

  test('copyWith 可设可清', () {
    const ShotLanguage s = ShotLanguage(shotSize: ShotSize.closeUp, motionStrength: 0.35);
    expect(s.copyWith(cameraAngle: CameraAngle.low).cameraAngle, CameraAngle.low);
    expect(s.copyWith(clearShotSize: true).shotSize, isNull);
    expect(s.copyWith(clearMotionStrength: true).motionStrength, isNull);
    expect(s.copyWith().shotSize, ShotSize.closeUp);
  });

  test('焦段表与步进常量', () {
    expect(kFocalLengthsMm, <int>[14, 24, 35, 50, 85, 135]);
    expect(kMotionStrengthStep, 0.05);
  });
}
