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
import '../../../core/errors/ink_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../canvas/providers/canvas_bootstrap_controller.dart';
import '../../settings/widgets/language_section.dart';
import '../util/onboarding_provider_choices.dart';
import 'onboarding_anchors.dart';
import 'onboarding_keys_step.dart';
import 'onboarding_step_body.dart';

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

  // 下面四个转发到 onboarding_anchors.dart——第 2 步在另一个文件里，这几个 Key
  // 两边都要用，挂在任一侧都会把 import 绕成环（与 batch_slot_parts.dart 同因）。
  // 保留同名转发是为了让既有的 widget 测试一行不改。

  /// Provider 行的点击区。
  static Key providerRowKey(OnboardingProviderSlot slot) =>
      OnboardingAnchors.providerRow(slot);

  /// Provider 行的单选圈——「选中了哪一行」的唯一读处。
  static Key providerRadioKey(OnboardingProviderSlot slot) =>
      OnboardingAnchors.providerRadio(slot);

  /// Key 输入框的底线（失败时转 danger）。
  static const Key keyUnderlineKey = OnboardingAnchors.keyUnderline;
  static const Key verifyKey = OnboardingAnchors.verify;
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
      0 => OnboardingStepBody(title: l10n.onboardingTitle, child: const LanguageSection()),
      1 => OnboardingStepBody(
          title: l10n.onboardingKeysTitle,
          description: l10n.onboardingKeysBody,
          child: const OnboardingKeysStep(),
        ),
      _ => OnboardingStepBody(
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
