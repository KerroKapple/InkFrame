// 首启向导第 2 步的 Provider 单选行（Screens 稿第 4 屏左画了三行）。
//
// 为什么要把「哪行能选」单独抽成一层纯函数：稿上有 fal.ai，而本仓库没有
// fal.ai 适配器。按既有口径（交付面板「剪映」那一格——有稿面、无实现 ⇒ 标
// 「待支持」，不假装能点）这一行必须留着且不可选；于是可选性不能写死在
// widget 里，只能由 registry 的能力位回答，否则哪天真接上了还要改两处。
//
// 代表 providerId 的取法与设置页 Key 表（api_keys_section.dart 取
// members.first）完全一致：同 scope 下注册顺序里的第一个成员。两处算出同一个
// family arg，apiKeyScopeControllerProvider 才是同一份状态——在向导里存完
// Key，设置页不用刷新就是「已配置」。
import 'package:flutter/foundation.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/models/provider_capabilities.dart';

/// 稿上的三行。声明顺序即展示顺序。
enum OnboardingProviderSlot {
  gemini('gemini-image'),
  fal('fal-ai'),
  dashscope('dashscope');

  const OnboardingProviderSlot(this.keyScope);

  /// SecureStorage 家族 scope。某行能不能选，等价于「registry 里有没有 Provider
  /// 落在这个 scope」——日后真接了 fal.ai（providerId `fal-ai`），这一行不改代码
  /// 就自动变可选、「待支持」后缀自动消失。
  final String keyScope;
}

/// 解析后的一行：能不能选、Key 存给谁、区域标签读哪儿。
@immutable
class OnboardingProviderChoice {
  const OnboardingProviderChoice({
    required this.slot,
    required this.representativeProviderId,
    required this.region,
  });

  final OnboardingProviderSlot slot;

  /// apiKeyScopeControllerProvider 的 family arg。null ⇒ 本行无适配器（待支持）。
  final String? representativeProviderId;

  /// 区域标签的数据源。待支持行没有能力位可读，故为 null——不另造一份写死的区域，
  /// 免得代码里的「全球 / 中国」和 Provider 真实声明各说一套。
  final ProviderRegion? region;

  bool get supported => representativeProviderId != null;
}

/// 能力位列表（注册顺序）→ 稿上的三行。
List<OnboardingProviderChoice> buildOnboardingProviderChoices(
  List<ProviderCapabilities> caps,
) {
  return <OnboardingProviderChoice>[
    for (final OnboardingProviderSlot slot in OnboardingProviderSlot.values)
      _resolve(slot, caps),
  ];
}

/// 默认选中第一个可选行；全不可选时为 null（UI 退化为只有说明、无法验证）。
OnboardingProviderSlot? defaultOnboardingProviderSlot(
  List<OnboardingProviderChoice> choices,
) {
  for (final OnboardingProviderChoice choice in choices) {
    if (choice.supported) return choice.slot;
  }
  return null;
}

OnboardingProviderChoice _resolve(
  OnboardingProviderSlot slot,
  List<ProviderCapabilities> caps,
) {
  for (final ProviderCapabilities cap in caps) {
    if (SecureStorageKeys.scopeOf(cap.providerId) != slot.keyScope) continue;
    return OnboardingProviderChoice(
      slot: slot,
      representativeProviderId: cap.providerId,
      region: cap.region,
    );
  }
  return OnboardingProviderChoice(
    slot: slot,
    representativeProviderId: null,
    region: null,
  );
}
