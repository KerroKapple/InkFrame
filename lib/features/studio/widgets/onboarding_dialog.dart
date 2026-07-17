// OnboardingDialog — ON-1 首启三步向导（语言 → API Key → 起步方式）。
//
// 弹出时机由 app.dart 首帧判断（AppPreferences.onboardingCompleted）；本文件
// 只负责向导 UI 与完成/跳过时写标记。步骤内容直接复用 Settings 的
// LanguageSection / ApiKeysSection——同一套 controller 逻辑，零平行实现。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_amber_button.dart';
import '../../../theme/primitives/ink_ghost_button.dart';
import '../../../theme/primitives/ink_noir_card.dart';
import '../../../theme/tokens.dart';
import '../../canvas/providers/canvas_bootstrap_controller.dart';
import '../../settings/widgets/api_keys_section.dart';
import '../../settings/widgets/language_section.dart';

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

  @override
  ConsumerState<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends ConsumerState<OnboardingDialog> {
  static const int _stepCount = 3;
  int _step = 0;

  /// 完成/跳过统一出口：写标记（内存立即生效，落盘失败由服务内部吞错）再关闭。
  Future<void> _finish() async {
    await ref
        .read(preferencesServiceProvider)
        .update((p) => p.copyWith(onboardingCompleted: true));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _createSample() async {
    final l10n = context.l10n;
    final failedMsg = l10n.studioCreateSampleFailed;
    final bootstrap = ref.read(canvasBootstrapControllerProvider);
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

  Widget _stepBody(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    switch (_step) {
      case 0:
        return const LanguageSection();
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ApiKeysSection(),
            Text(
              context.l10n.onboardingKeysConsoleHint,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.onboardingStepSampleTitle,
              style: typo.title.copyWith(color: colors.fg1),
            ),
            const SizedBox(height: InkSpacing.sm),
            Text(
              context.l10n.onboardingStepSampleBody,
              style: typo.body.copyWith(color: colors.fg3),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l10n = context.l10n;
    final bool lastStep = _step == _stepCount - 1;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(InkSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: InkNoirCard(
          padding: const EdgeInsets.all(InkSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.onboardingTitle,
                      style: typo.headline.copyWith(color: colors.fg1),
                    ),
                  ),
                  Text(
                    l10n.onboardingStepIndicator(_step + 1, _stepCount),
                    style: typo.caption.copyWith(color: colors.fg3),
                  ),
                ],
              ),
              const SizedBox(height: InkSpacing.md),
              Flexible(
                child: SingleChildScrollView(child: _stepBody(context)),
              ),
              const SizedBox(height: InkSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: lastStep
                    ? <Widget>[
                        InkGhostButton(
                          label: l10n.onboardingStartEmpty,
                          onPressed: _finish,
                        ),
                        const SizedBox(width: InkSpacing.sm),
                        InkAmberButton(
                          label: l10n.studioCreateSampleProject,
                          icon: Icons.auto_awesome_outlined,
                          onPressed: _createSample,
                        ),
                      ]
                    : <Widget>[
                        InkGhostButton(
                          label: l10n.onboardingSkip,
                          onPressed: _finish,
                        ),
                        const SizedBox(width: InkSpacing.sm),
                        InkAmberButton(
                          label: l10n.onboardingNext,
                          icon: Icons.arrow_forward,
                          onPressed: () => setState(() => _step++),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
