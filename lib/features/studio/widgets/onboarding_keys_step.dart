// 首启向导第 2 步「配置密钥」（Screens 稿第 4 屏左）：Provider 单选 + Key 验证。
//
// 从 onboarding_dialog.dart 搬出来的——那边连这一步有 986 行，是仓库第 4 长的
// 文件；这一步自成一块（选哪家 / 填哪把 Key / 验证结果），是天然接缝。
// 搬运零逻辑改动，向导的 19 条 widget 测试一行未改仍全绿。
//
// 存与校验一律复用 ApiKeyScopeController，不另造一套：向导里存完 Key，
// 设置页不刷新就显示「已配置」。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_primitives.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../settings/providers/api_key_scope_controller.dart';
import '../util/onboarding_provider_choices.dart';
import 'onboarding_anchors.dart';
// -------------------------------------------------------- 第 2 步：配置密钥

/// 「验证」这一次动作的本地结局。是否已配置由 ApiKeyScopeController 的
/// AsyncValue 回答——这里只记「刚才那下点出了什么」。
enum _VerifyOutcome { idle, verified, savedUnverified, failed }

class OnboardingKeysStep extends ConsumerStatefulWidget {
  const OnboardingKeysStep({super.key});

  @override
  ConsumerState<OnboardingKeysStep> createState() => _OnboardingKeysStepState();
}

class _OnboardingKeysStepState extends ConsumerState<OnboardingKeysStep> {
  final TextEditingController _ctrl = TextEditingController();

  /// null = 还没动过手，按 defaultOnboardingProviderSlot 落在第一个可选行。
  OnboardingProviderSlot? _selected;
  _VerifyOutcome _outcome = _VerifyOutcome.idle;

  /// 失败时的错误码原串（InkErrorCode.wire）。内部标识符，不进 ARB。
  String? _errorCode;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// [active] 是当前**生效**的选中行（可能还是默认值而非 _selected）——拿它比，
  /// 免得用户点一下已经选中的那行就把输入框清空。
  void _select(OnboardingProviderSlot slot, OnboardingProviderSlot? active) {
    if (slot == active) return;
    setState(() {
      _selected = slot;
      // 换家就清空：输入框里那串是给上一家的，绝不能顺着存进另一家的 scope。
      _ctrl.clear();
      _outcome = _VerifyOutcome.idle;
      _errorCode = null;
    });
  }

  Future<void> _verify(String? providerId) async {
    final String value = _ctrl.text.trim();
    if (providerId == null || value.isEmpty || _busy) return;
    final ApiKeyScopeController notifier =
        ref.read(apiKeyScopeControllerProvider(providerId).notifier);
    setState(() => _busy = true);
    try {
      final ApiKeySaveOutcome outcome = await notifier.save(value);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorCode = null;
        switch (outcome) {
          case ApiKeySaveOutcome.saved:
            _outcome = _VerifyOutcome.verified;
            _ctrl.clear();
          case ApiKeySaveOutcome.savedUnverified:
            _outcome = _VerifyOutcome.savedUnverified;
            _ctrl.clear();
          case ApiKeySaveOutcome.rejected:
            // 不清输入框——用户可直接改错重试。rejected 即 KeyInvalid：控制器没把
            // reason 透出来，对用户而言就是「这把 Key 被拒」，故记 invalid_key。
            _outcome = _VerifyOutcome.failed;
            _errorCode = InkErrorCode.invalidKey.wire;
        }
      });
    } on InkError catch (e) {
      // 捕获集 = save 的真实抛出集（存储层失败如 LocalIOError）。
      if (!mounted) return;
      setState(() {
        _busy = false;
        _outcome = _VerifyOutcome.failed;
        _errorCode = e.code.wire;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<OnboardingProviderChoice> choices =
        buildOnboardingProviderChoices(
      ref.watch(providerCapabilitiesListProvider),
    );
    final OnboardingProviderSlot? active =
        _selected ?? defaultOnboardingProviderSlot(choices);
    final String? providerId = _representativeOf(choices, active);
    final bool isSet = providerId == null
        ? false
        : (ref.watch(apiKeyScopeControllerProvider(providerId)).valueOrNull ??
            false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProviderGroup(
          choices: choices,
          active: active,
          onSelect: (OnboardingProviderSlot slot) => _select(slot, active),
        ),
        const SizedBox(height: InkSpacing.md),
        _KeyField(
          controller: _ctrl,
          enabled: providerId != null && !_busy,
          failed: _outcome == _VerifyOutcome.failed,
          onVerify: () => _verify(providerId),
          onChanged: _onChanged,
          result: _result(context, isSet: isSet),
        ),
      ],
    );
  }

  void _onChanged(String _) {
    // 任何改动都把上一次的结局清掉——红底线不该在用户已经改过的串上继续亮。
    setState(() {
      _outcome = _VerifyOutcome.idle;
      _errorCode = null;
    });
  }

  static String? _representativeOf(
    List<OnboardingProviderChoice> choices,
    OnboardingProviderSlot? slot,
  ) {
    if (slot == null) return null;
    for (final OnboardingProviderChoice choice in choices) {
      if (choice.slot == slot) return choice.representativeProviderId;
    }
    return null;
  }

  /// 结果行的三要素。null = 空态（槽位仍占 16，Provider 组不会被推上推下）。
  ({String glyph, Color color, String text, bool mono})? _result(
    BuildContext context, {
    required bool isSet,
  }) {
    final InkColors c = context.inkColors;
    final AppLocalizations l10n = context.l10n;
    return switch (_outcome) {
      _VerifyOutcome.failed => (
          glyph: '✕',
          color: c.danger,
          // 错误码原串：内部标识符，等宽呈现，便于用户原样贴给支持。
          text: _errorCode ?? InkErrorCode.unknown.wire,
          mono: true,
        ),
      _VerifyOutcome.verified => (
          glyph: '✓',
          color: c.success,
          text: l10n.onboardingKeyVerified,
          mono: false,
        ),
      _VerifyOutcome.savedUnverified => (
          glyph: '✓',
          color: c.accent,
          text: l10n.settingsApiKeySavedUnverified,
          mono: false,
        ),
      _VerifyOutcome.idle when isSet => (
          glyph: '✓',
          color: c.success,
          text: l10n.settingsApiKeySet,
          mono: false,
        ),
      _VerifyOutcome.idle => null,
    };
  }
}

/// Provider 单选框：1px control 边 + 4px 圆角 + overflow hidden，内含三行 63。
class _ProviderGroup extends StatelessWidget {
  const _ProviderGroup({
    required this.choices,
    required this.active,
    required this.onSelect,
  });

  final List<OnboardingProviderChoice> choices;
  final OnboardingProviderSlot? active;
  final ValueChanged<OnboardingProviderSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Column(
        children: <Widget>[
          for (final OnboardingProviderChoice choice in choices)
            _ProviderRow(
              choice: choice,
              checked: choice.slot == active,
              onTap: () => onSelect(choice.slot),
            ),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.choice,
    required this.checked,
    required this.onTap,
  });

  final OnboardingProviderChoice choice;
  final bool checked;
  final VoidCallback onTap;

  static String _name(AppLocalizations l10n, OnboardingProviderSlot slot) =>
      switch (slot) {
        OnboardingProviderSlot.gemini => l10n.onboardingProviderGemini,
        OnboardingProviderSlot.fal => l10n.onboardingProviderFal,
        OnboardingProviderSlot.dashscope => l10n.onboardingProviderDashscope,
      };

  static String _note(AppLocalizations l10n, OnboardingProviderSlot slot) =>
      switch (slot) {
        OnboardingProviderSlot.gemini => l10n.onboardingProviderGeminiNote,
        OnboardingProviderSlot.fal => l10n.onboardingProviderFalNote,
        OnboardingProviderSlot.dashscope =>
          l10n.onboardingProviderDashscopeNote,
      };

  static String _region(AppLocalizations l10n, ProviderRegion region) =>
      switch (region) {
        ProviderRegion.global => l10n.onboardingRegionGlobal,
        ProviderRegion.cn => l10n.onboardingRegionChina,
      };

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l10n = context.l10n;
    final bool supported = choice.supported;
    final String bareName = _name(l10n, choice.slot);
    // 有稿面、无实现 ⇒ 名字后缀「待支持」，禁用但不删行。
    final String name = supported
        ? bareName
        : l10n.onboardingProviderComingSoon(bareName);
    final ProviderRegion? region = choice.region;

    return Semantics(
      button: supported,
      selected: checked,
      enabled: supported,
      label: name,
      child: MouseRegion(
        cursor: supported
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        child: GestureDetector(
          key: OnboardingAnchors.providerRow(choice.slot),
          behavior: HitTestBehavior.opaque,
          // 同上：待支持那行不捕获点击。
          onTap: supported ? onTap : null,
          child: Container(
            // 行 63 = min-height 46 + padding 8×2 + 1px 行分隔。第三行底部也有这条
            // 线——稿写在每行的 border-bottom 上，被分组框的 overflow:hidden 压在
            // 框底边内侧，是两条相邻的线，不是一条。
            height: 63,
            padding: const EdgeInsets.symmetric(
              horizontal: InkSpacing.s14,
              vertical: InkSpacing.sm,
            ),
            decoration: BoxDecoration(
              // 未选中行透出卡片底色。
              color: checked ? c.accentWash : null,
              border: Border(bottom: BorderSide(color: c.outline)),
            ),
            child: Row(
              children: <Widget>[
                _Radio(
                  slot: choice.slot,
                  checked: checked,
                  enabled: supported,
                ),
                const SizedBox(width: InkSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body
                            .copyWith(color: supported ? c.fg1 : c.fg5),
                      ),
                      const SizedBox(height: InkSpacing.s2),
                      Text(
                        _note(l10n, choice.slot),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.meta.copyWith(color: c.fg6),
                      ),
                    ],
                  ),
                ),
                if (region != null) ...<Widget>[
                  const SizedBox(width: InkSpacing.sm),
                  Text(
                    _region(l10n, region),
                    style: t.meta.copyWith(color: c.fg5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单选圈：外径 14（稿 box-sizing:border-box），1px 圈线 + 圈内 6×6 实心点。
class _Radio extends StatelessWidget {
  const _Radio({
    required this.slot,
    required this.checked,
    required this.enabled,
  });

  final OnboardingProviderSlot slot;
  final bool checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final Color line = checked
        ? c.accent
        : enabled
            ? c.fg6
            : c.control;
    return Container(
      key: OnboardingAnchors.providerRadio(slot),
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: line),
      ),
      child: checked
          ? Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: c.accent),
            )
          : null,
    );
  }
}

/// API Key 行：标签 → 输入（只有 1px 底线）+「验证」→ 结果行。
class _KeyField extends StatelessWidget {
  const _KeyField({
    required this.controller,
    required this.enabled,
    required this.failed,
    required this.onVerify,
    required this.onChanged,
    required this.result,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool failed;
  final VoidCallback onVerify;
  final ValueChanged<String> onChanged;
  final ({String glyph, Color color, String text, bool mono})? result;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l10n = context.l10n;
    final bool canVerify = enabled && controller.text.trim().isNotEmpty;
    final ({String glyph, Color color, String text, bool mono})? row = result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.onboardingKeyLabel,
          style: t.body.copyWith(color: c.fg4),
        ),
        const SizedBox(height: InkSpacing.s6),
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                key: OnboardingAnchors.keyUnderline,
                // 输入框 27 = height 26 + 1px 底线。minHeight 而非定高：大字号档下
                // 让它自己长高，不撞溢出。
                constraints: const BoxConstraints(minHeight: 27),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: failed ? c.danger : c.control),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  onChanged: onChanged,
                  onSubmitted: (_) => onVerify(),
                  cursorColor: c.accent,
                  style: t.mono.copyWith(color: c.fg2),
                  decoration: InputDecoration.collapsed(
                    hintText: l10n.settingsApiKeyPlaceholder,
                    hintStyle: t.mono.copyWith(color: c.fg6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: InkSpacing.s10),
            Semantics(
              button: true,
              enabled: canVerify,
              label: l10n.onboardingKeyVerify,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: OnboardingAnchors.verify,
                  behavior: HitTestBehavior.opaque,
                  // 空输入 / 正在验证时不捕获点击（同时压到 0.5 透明度）。
                  onTap: canVerify ? onVerify : null,
                  child: Opacity(
                    opacity: canVerify ? 1 : 0.5,
                    // 稿：验证按钮 28 = content 26 + 1px 边 ×2。
                    child: InkSecondaryButton(
                      l10n.onboardingKeyVerify,
                      height: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: InkSpacing.s6),
        ConstrainedBox(
          // 稿：结果行 16。空态也占位，Provider 组不会被结果行推上推下。
          constraints: const BoxConstraints(minHeight: 16),
          child: row == null
              ? const SizedBox.shrink()
              : Row(
                  children: <Widget>[
                    Text(
                      row.glyph,
                      style: t.meta.copyWith(color: row.color),
                    ),
                    const SizedBox(width: InkSpacing.sm),
                    Expanded(
                      child: Text(
                        row.text,
                        style: row.mono
                            ? t.mono.copyWith(color: row.color)
                            : t.meta.copyWith(color: c.fg4),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

