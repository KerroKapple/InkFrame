// 首启向导的测试锚点 Key。
//
// 单独成文件的理由和 batch_slot_parts.dart 一样：向导本体（onboarding_dialog.dart）
// 与第 2 步（onboarding_keys_step.dart）是两个文件，这几个 Key 两边都要用——
// 挂在任一侧都会把 import 绕成环。
//
// `OnboardingDialog` 上保留同名转发常量，好让既有的 widget 测试一行不改。
import 'package:flutter/widgets.dart';

import '../util/onboarding_provider_choices.dart';

abstract final class OnboardingAnchors {
  /// Provider 单选行。按 slot 分，便于测试直接点某一家。
  static Key providerRow(OnboardingProviderSlot slot) =>
      Key('onboarding.provider.${slot.name}');

  /// 单选圈本体——测「圈填没填」比测整行底色稳。
  static Key providerRadio(OnboardingProviderSlot slot) =>
      Key('onboarding.provider.${slot.name}.radio');

  /// Key 输入的 1px 底线。验证失败时它要变 danger。
  static const Key keyUnderline = Key('onboarding.key.underline');

  static const Key verify = Key('onboarding.key.verify');
}
