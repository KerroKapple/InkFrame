// OnboardingDialog — ON-1 首启三步向导（欢迎 → 配置密钥 → 首个项目）。
//
// 形态按 Screens 稿第 4 屏左：一块 640 content 的卡片，43 步骤条 | 正文 | 55 底部条。
// 所有尺寸常量（43 / 42+2 / 63 / 27 / 28 / 55 …）的「为什么是这个数」已在静态复刻件
// lib/features/workspace/onboarding_v2_screen.dart 的头注里逐像素核过——稿是
// content-box，每层的高都要把边框加回去。这里照搬，不再重算。
// 复刻件为了像素比对钉死的那两类值（页签宽、每段 line-height）本文件**不**照抄：
// 页签宽按稿自己的公式由内容撑（ARB 文案逐语言不同，钉死会把英文裁掉），行高走
// 排版 token（widget 不该再钉字号/行高，否则绕过 a11y 缩放）。
//
// 弹出时机由 app.dart 首帧判断（AppPreferences.onboardingCompleted）；本文件只负责
// 向导 UI 与完成/跳过时写标记。「跳过」= 完成但不配 Key，之后由 Studio 的引导条接手。
//
// 第 1 步的语言选择直接复用 Settings 的 LanguageSection；第 2 步的存 Key / 校验走
// ApiKeyScopeController（与设置页 Key 表同一套状态机 + 同一个 family arg，零平行实现）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../canvas/providers/canvas_bootstrap_controller.dart';
import '../../settings/providers/api_key_scope_controller.dart';
import '../../settings/widgets/language_section.dart';
import '../util/onboarding_provider_choices.dart';

/// 首启向导入口。障不可点关——所有退出路径都经按钮并落 onboardingCompleted，
/// 保证「完成/跳过后不再弹」的标记不被旁路。
Future<void> showOnboardingDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: context.inkColors.scrim,
    builder: (_) => const OnboardingDialog(),
  );
}

class OnboardingDialog extends ConsumerStatefulWidget {
  const OnboardingDialog({super.key});

  /// 稿 content-box：640 content + 1px 边 ×2。
  static const double cardWidth = 642;

  /// 竖向合账：1 + 43 步骤条 + 392 正文 + 55 底部条 + 1。
  /// 高度写死而非跟内容走——三步的内容长短不一，卡片框跳动比留白难看得多。
  static const double cardHeight = 492;

  static const int stepCount = 3;

  /// 步骤页签（点它回退）。
  static Key stepTabKey(int step) => Key('onboarding.step.$step');

  /// 页签下沿那条 2px 槽位——槽位恒留，只有当前步填琥珀。
  static Key stepUnderlineKey(int step) => Key('onboarding.step.$step.rule');

  /// Provider 行的点击区。
  static Key providerRowKey(OnboardingProviderSlot slot) =>
      Key('onboarding.provider.${slot.name}');

  /// Provider 行的单选圈——「选中了哪一行」的唯一读处。
  static Key providerRadioKey(OnboardingProviderSlot slot) =>
      Key('onboarding.provider.${slot.name}.radio');

  /// Key 输入框的底线（失败时转 danger）。
  static const Key keyUnderlineKey = Key('onboarding.key.underline');
  static const Key verifyKey = Key('onboarding.key.verify');
  static const Key skipKey = Key('onboarding.skip');
  static const Key nextKey = Key('onboarding.next');
  static const Key startEmptyKey = Key('onboarding.startEmpty');
  static const Key createSampleKey = Key('onboarding.createSample');

  @override
  ConsumerState<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends ConsumerState<OnboardingDialog> {
  int _step = 0;

  /// 到过的最远一步。页签只在 `index <= _furthest` 时可点——已完成的步能跳回去，
  /// 没走到的步点不动（不让用户跳过「下一步」直接落到末页）。
  int _furthest = 0;

  void _goto(int step) {
    if (step == _step || step > _furthest) return;
    setState(() => _step = step);
  }

  void _next() {
    if (_step >= OnboardingDialog.stepCount - 1) return;
    setState(() {
      _step += 1;
      if (_step > _furthest) _furthest = _step;
    });
  }

  /// 完成/跳过统一出口：写标记（内存立即生效，落盘失败由服务内部吞错）再关闭。
  Future<void> _finish() async {
    await ref
        .read(preferencesServiceProvider)
        .update((p) => p.copyWith(onboardingCompleted: true));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _createSample() async {
    final AppLocalizations l10n = context.l10n;
    final String failedMsg = l10n.studioCreateSampleFailed;
    final CanvasBootstrapController bootstrap =
        ref.read(canvasBootstrapControllerProvider);
    try {
      await bootstrap.createSample(
        projectName: l10n.canvasSampleProjectName,
        canvasName: l10n.canvasSampleCanvasName,
        seed: (
          laneLabel: l10n.canvasSampleLaneLabel,
          laneStylePrompt: l10n.canvasSampleLaneStylePrompt,
          nodeLabel: l10n.canvasSampleNodeLabel,
          nodePrompt: l10n.canvasSampleNodePrompt,
        ),
      );
    } on InkError {
      // 捕获集 = createSample 真实抛出集（仓储链路只抛 InkError）。
      // 失败留在向导——用户可改走「从空白开始」。
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(failedMsg),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    // createSample 已切 currentCanvasId——关向导后直接落在画布。
    await _finish();
  }

  /// 底部主按钮：末步建示例项目，其余步前进一格。
  Future<void> _primaryAction() async {
    if (_step == OnboardingDialog.stepCount - 1) {
      await _createSample();
      return;
    }
    _next();
  }

  Widget _stepBody(AppLocalizations l10n) {
    return switch (_step) {
      0 => _StepBody(title: l10n.onboardingTitle, child: const LanguageSection()),
      1 => _StepBody(
          title: l10n.onboardingKeysTitle,
          description: l10n.onboardingKeysBody,
          child: const _KeysStep(),
        ),
      _ => _StepBody(
          title: l10n.onboardingStepSampleTitle,
          description: l10n.onboardingStepSampleBody,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final AppLocalizations l10n = context.l10n;
    final bool lastStep = _step == OnboardingDialog.stepCount - 1;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(InkSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: OnboardingDialog.cardWidth,
          maxHeight: OnboardingDialog.cardHeight,
        ),
        // expand 而非 SizedBox 定值：窗口比卡片还矮时跟着缩，不画出屏幕。
        child: SizedBox.expand(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surface3,
              border: Border.all(color: c.control),
              borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
              boxShadow: InkShadow.overlay,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _StepBar(current: _step, furthest: _furthest, onSelect: _goto),
                // 正文可滚：卡片高固定，而大字号档 / 窄窗下内容会超出这一格。
                Expanded(
                  child: SingleChildScrollView(child: _stepBody(l10n)),
                ),
                _Footer(
                  lastStep: lastStep,
                  onSecondary: _finish,
                  onPrimary: _primaryAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 步骤条 43

class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.current,
    required this.furthest,
    required this.onSelect,
  });

  final int current;
  final int furthest;
  final ValueChanged<int> onSelect;

  static String _label(AppLocalizations l10n, int step) => switch (step) {
        0 => l10n.onboardingTabWelcome,
        1 => l10n.onboardingTabKeys,
        _ => l10n.onboardingTabFirstProject,
      };

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final AppLocalizations l10n = context.l10n;
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s20),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      // 文案长的语言下从右侧裁掉，不报溢出。
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < OnboardingDialog.stepCount; i++)
                _StepTab(
                  index: i,
                  label: _label(l10n, i),
                  current: i == current,
                  enabled: i <= furthest,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({
    required this.index,
    required this.label,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool current;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Semantics(
      button: enabled,
      selected: current,
      label: label,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: GestureDetector(
          key: OnboardingDialog.stepTabKey(index),
          behavior: HitTestBehavior.opaque,
          // 禁用态用 null 而非空闭包——不捕获点击，不造「看着能点」的假交互。
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 42,
            // 页签宽按稿的公式由内容撑出（16 + 序号 + gap 8 + 文字 + 16）；
            // IntrinsicWidth 是让下边框跟文字一样宽的那一步。
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: InkSpacing.md),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            // 等宽两位序号（01 / 02 / 03）——数字不进 ARB。
                            (index + 1).toString().padLeft(2, '0'),
                            style: t.monoSmall
                                .copyWith(color: current ? c.accent : c.fg6),
                          ),
                          const SizedBox(width: InkSpacing.sm),
                          Text(
                            label,
                            maxLines: 1,
                            style: t.body
                                .copyWith(color: current ? c.fg1 : c.fg4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 稿写的是 `border-bottom:2px solid transparent`——占位但不画。
                  // 槽位恒留（否则整条页签矮 2px、文字跟着上移），只有当前步填琥珀。
                  SizedBox(
                    key: OnboardingDialog.stepUnderlineKey(index),
                    height: 2,
                    child: current ? ColoredBox(color: c.accent) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 正文区

/// 每一步共用的正文外壳：标题 17 → 说明 12 → 内容，内边距 24 / 24 / 20。
class _StepBody extends StatelessWidget {
  const _StepBody({required this.title, this.description, this.child});

  final String title;
  final String? description;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.lg,
        InkSpacing.lg,
        InkSpacing.lg,
        InkSpacing.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: t.dialogTitle.copyWith(color: c.fg1)),
          if (description != null) ...<Widget>[
            const SizedBox(height: InkSpacing.sm),
            Text(description!, style: t.body.copyWith(color: c.fg4)),
          ],
          if (child != null) ...<Widget>[
            const SizedBox(height: InkSpacing.md),
            child!,
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------- 第 2 步：配置密钥

/// 「验证」这一次动作的本地结局。是否已配置由 ApiKeyScopeController 的
/// AsyncValue 回答——这里只记「刚才那下点出了什么」。
enum _VerifyOutcome { idle, verified, savedUnverified, failed }

class _KeysStep extends ConsumerStatefulWidget {
  const _KeysStep();

  @override
  ConsumerState<_KeysStep> createState() => _KeysStepState();
}

class _KeysStepState extends ConsumerState<_KeysStep> {
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
          key: OnboardingDialog.providerRowKey(choice.slot),
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
      key: OnboardingDialog.providerRadioKey(slot),
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
                key: OnboardingDialog.keyUnderlineKey,
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
                  key: OnboardingDialog.verifyKey,
                  behavior: HitTestBehavior.opaque,
                  // 空输入 / 正在验证时不捕获点击（同时压到 0.5 透明度）。
                  onTap: canVerify ? onVerify : null,
                  child: Opacity(
                    opacity: canVerify ? 1 : 0.5,
                    // 稿：验证按钮 28 = content 26 + 1px 边 ×2。
                    child: WsSecondaryButton(
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

// ------------------------------------------------------------- 底部条 55

class _Footer extends StatelessWidget {
  const _Footer({
    required this.lastStep,
    required this.onSecondary,
    required this.onPrimary,
  });

  final bool lastStep;
  final Future<void> Function() onSecondary;
  final Future<void> Function() onPrimary;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l10n = context.l10n;
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s20,
        vertical: InkSpacing.s14,
      ),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              // 稿这里写的是硬件探测结论（「已检测：32 GB · 独显…」）——本仓库没有
              // 硬件探测，不画假数据，换成一句「之后可在设置里调整」。
              l10n.onboardingFooterHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.meta.copyWith(color: c.fg6),
            ),
          ),
          const SizedBox(width: InkSpacing.s12),
          // 「跳过 / 从空白开始」与主按钮同高 26——次动作无边框无底色，别顺手加一圈。
          _TertiaryAction(
            actionKey: lastStep
                ? OnboardingDialog.startEmptyKey
                : OnboardingDialog.skipKey,
            label:
                lastStep ? l10n.onboardingStartEmpty : l10n.onboardingSkip,
            onTap: onSecondary,
          ),
          const SizedBox(width: InkSpacing.s10),
          Semantics(
            button: true,
            label: lastStep
                ? l10n.studioCreateSampleProject
                : l10n.onboardingNext,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: lastStep
                    ? OnboardingDialog.createSampleKey
                    : OnboardingDialog.nextKey,
                behavior: HitTestBehavior.opaque,
                onTap: onPrimary,
                child: WsPrimaryButton(
                  lastStep
                      ? l10n.studioCreateSampleProject
                      : l10n.onboardingNext,
                  height: 26,
                  bordered: false,
                  horizontalPadding: InkSpacing.md,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 三级动作：26 高、无边框无底色的纯文字按钮（稿上的「跳过」）。
class _TertiaryAction extends StatelessWidget {
  const _TertiaryAction({
    required this.actionKey,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: actionKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 26,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Text(label, style: t.body.copyWith(color: c.fg4)),
          ),
        ),
      ),
    );
  }
}
