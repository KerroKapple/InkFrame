// 镜头语言 → 英文提示词前缀（P3）。模板 `{景别}, {运镜}, {角度}, {焦段}mm lens`，空项跳过。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' show CameraMovement;
import 'package:inkframe/core/models/shot_language.dart';
import 'package:inkframe/features/generation/services/shot_language_prompt.dart';

void main() {
  test('四项齐全按模板顺序', () {
    const ShotLanguage s = ShotLanguage(
      shotSize: ShotSize.mediumShot,
      cameraAngle: CameraAngle.eyeLevel,
      motionStrength: 0.35,
      focalLengthMm: 35,
    );
    expect(shotLanguagePromptPrefix(s, camera: CameraMovement.pushIn), 'medium shot, dolly in, eye level, 35mm lens');
  });

  test('空项跳过；全空返回空串；幅度不注入', () {
    expect(shotLanguagePromptPrefix(ShotLanguage.empty), '');
    expect(shotLanguagePromptPrefix(const ShotLanguage(motionStrength: 0.9)), '');
    expect(shotLanguagePromptPrefix(const ShotLanguage(focalLengthMm: 85)), '85mm lens');
    expect(shotLanguagePromptPrefix(ShotLanguage.empty, camera: CameraMovement.orbit), 'arc shot');
    expect(
      shotLanguagePromptPrefix(const ShotLanguage(shotSize: ShotSize.extremeCloseUp, cameraAngle: CameraAngle.birdsEye)),
      "extreme close-up, bird's-eye view",
    );
  });

  test('每个枚举都有英文词（exhaustive switch 的运行期兜底）', () {
    for (final ShotSize s in ShotSize.values) {
      expect(shotSizePromptTerm(s), isNotEmpty);
    }
    for (final CameraAngle a in CameraAngle.values) {
      expect(cameraAnglePromptTerm(a), isNotEmpty);
    }
    for (final CameraMovement c in CameraMovement.values) {
      expect(cameraMovementPromptTerm(c), isNotEmpty);
      expect(cameraMovementPromptTerm(c), isNot(contains('_')), reason: '不许把枚举名漏进提示词');
    }
    expect(CameraMovement.values.length, 13, reason: 'PLAN §P3：运镜方式 13 项');
  });
}
