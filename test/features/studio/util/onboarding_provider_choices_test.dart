// buildOnboardingProviderChoices 纯函数单测。
//
// 钉的是「哪行能选由 registry 说话」这条行为：稿上三行恒定，但可选性、代表
// providerId、区域标签全部从传入的能力位推——没有适配器的行降级为待支持，
// 真接上适配器后同一行不改代码就变可选。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/studio/util/onboarding_provider_choices.dart';

import '../../../_harness/fake_providers.dart';

/// 仓库当前的真实注册顺序片段：Gemini → DashScope 家族（wanx 先于 kling）。
List<ProviderCapabilities> _registeredLikeRepo() => <ProviderCapabilities>[
      fakeImageCapabilities(id: 'gemini-image'),
      fakeImageCapabilities(id: 'wanx-image', region: ProviderRegion.cn),
      fakeVideoCapabilities(id: 'wanx-t2v', region: ProviderRegion.cn),
      fakeVideoCapabilities(id: 'kling-v3', region: ProviderRegion.cn),
    ];

OnboardingProviderChoice _of(
  List<OnboardingProviderChoice> choices,
  OnboardingProviderSlot slot,
) =>
    choices.firstWhere((OnboardingProviderChoice c) => c.slot == slot);

void main() {
  test('三行照稿且顺序固定：Gemini → fal.ai → DashScope', () {
    final List<OnboardingProviderChoice> choices =
        buildOnboardingProviderChoices(_registeredLikeRepo());

    expect(
      choices.map((OnboardingProviderChoice c) => c.slot).toList(),
      <OnboardingProviderSlot>[
        OnboardingProviderSlot.gemini,
        OnboardingProviderSlot.fal,
        OnboardingProviderSlot.dashscope,
      ],
    );
  });

  test('Gemini 行的代表 id 就是 gemini-image，Key 落在自己的 scope', () {
    final OnboardingProviderChoice gemini =
        _of(buildOnboardingProviderChoices(_registeredLikeRepo()),
            OnboardingProviderSlot.gemini);

    expect(gemini.supported, isTrue);
    expect(gemini.representativeProviderId, 'gemini-image');
  });

  test('DashScope 行取家族里注册顺序第一个成员——与设置页 Key 表同口径', () {
    final OnboardingProviderChoice dashscope =
        _of(buildOnboardingProviderChoices(_registeredLikeRepo()),
            OnboardingProviderSlot.dashscope);

    // kling-v3 / wanx-t2v 同属 dashscope scope，取到的必须是靠前的那个。
    expect(dashscope.representativeProviderId, 'wanx-image');
  });

  test('DashScope 家族内换注册顺序，代表 id 跟着换（不是写死 wanx-image）', () {
    final List<OnboardingProviderChoice> choices =
        buildOnboardingProviderChoices(<ProviderCapabilities>[
      fakeVideoCapabilities(id: 'kling-v3', region: ProviderRegion.cn),
      fakeImageCapabilities(id: 'wanx-image', region: ProviderRegion.cn),
    ]);

    expect(
      _of(choices, OnboardingProviderSlot.dashscope).representativeProviderId,
      'kling-v3',
    );
  });

  test('fal.ai 没有适配器 ⇒ 不可选、无代表 id、无区域（行仍在）', () {
    final OnboardingProviderChoice fal = _of(
        buildOnboardingProviderChoices(_registeredLikeRepo()),
        OnboardingProviderSlot.fal);

    expect(fal.supported, isFalse);
    expect(fal.representativeProviderId, isNull);
    expect(fal.region, isNull);
  });

  test('真注册了 fal-ai 适配器后，同一行不改代码就变可选', () {
    final List<OnboardingProviderChoice> choices =
        buildOnboardingProviderChoices(<ProviderCapabilities>[
      ..._registeredLikeRepo(),
      fakeImageCapabilities(id: 'fal-ai'),
    ]);

    final OnboardingProviderChoice fal =
        _of(choices, OnboardingProviderSlot.fal);
    expect(fal.supported, isTrue);
    expect(fal.representativeProviderId, 'fal-ai');
  });

  test('Gemini 若未注册也降级为待支持——不假装能选', () {
    final List<OnboardingProviderChoice> choices =
        buildOnboardingProviderChoices(<ProviderCapabilities>[
      fakeImageCapabilities(id: 'wanx-image', region: ProviderRegion.cn),
    ]);

    expect(_of(choices, OnboardingProviderSlot.gemini).supported, isFalse);
    expect(_of(choices, OnboardingProviderSlot.dashscope).supported, isTrue);
  });

  test('区域标签取自能力位，不是行里写死的常量', () {
    final List<OnboardingProviderChoice> flipped =
        buildOnboardingProviderChoices(<ProviderCapabilities>[
      // 故意把 Gemini 声明成 cn、DashScope 声明成 global。
      fakeImageCapabilities(id: 'gemini-image', region: ProviderRegion.cn),
      fakeImageCapabilities(id: 'wanx-image'),
    ]);

    expect(_of(flipped, OnboardingProviderSlot.gemini).region,
        ProviderRegion.cn);
    expect(_of(flipped, OnboardingProviderSlot.dashscope).region,
        ProviderRegion.global);
  });

  test('默认选中第一个可选行；全不可选时为 null', () {
    expect(
      defaultOnboardingProviderSlot(
          buildOnboardingProviderChoices(_registeredLikeRepo())),
      OnboardingProviderSlot.gemini,
    );
    // Gemini 缺席 ⇒ 默认落到下一个可选行（fal.ai 不可选，跳过它）。
    expect(
      defaultOnboardingProviderSlot(
          buildOnboardingProviderChoices(<ProviderCapabilities>[
        fakeImageCapabilities(id: 'wanx-image', region: ProviderRegion.cn),
      ])),
      OnboardingProviderSlot.dashscope,
    );
    expect(
      defaultOnboardingProviderSlot(
          buildOnboardingProviderChoices(const <ProviderCapabilities>[])),
      isNull,
    );
  });
}
