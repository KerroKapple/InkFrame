// StartupErrorView：启动失败全屏 surface（LB-09）。
//
// 当 DB-ready future（pgMigratedPoolProvider）处于 AsyncError 时，顶层 gate
// （app.dart 的 _StartupGate）用它替代白屏：解释数据库启动失败、亮出日志目录、
// 给出「重试」与「打开日志目录」。DI 边界已把底层 StateError 翻成 InkError，
// 故错误详情走共享 l10nAsyncError 本地化呈现。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/database.dart';
import '../../../core/di/folder_opener.dart';
import '../../../core/di/paths.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/tokens.dart';

class StartupErrorView extends ConsumerWidget {
  const StartupErrorView({super.key, required this.error});

  /// pgMigratedPoolProvider 的 AsyncError 值（DI 边界已翻成 InkError）。
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final String logsPath = ref.watch(appPathsProvider).logs.path;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(InkSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: InkSpacing.xxl,
                  color: colors.danger,
                ),
                const SizedBox(height: InkSpacing.md),
                Text(
                  context.l10n.startupErrorTitle,
                  style: typo.headline.copyWith(color: colors.fg1),
                ),
                const SizedBox(height: InkSpacing.sm),
                Text(
                  context.l10n.startupErrorBody,
                  style: typo.body.copyWith(color: colors.fg2),
                ),
                const SizedBox(height: InkSpacing.md),
                // DI 边界翻好的 InkError 走共享 l10nAsyncError 呈现（renderable，非白屏）。
                InkErrorBanner(message: l10nAsyncError(context, error)),
                const SizedBox(height: InkSpacing.md),
                Text(
                  context.l10n.startupErrorLogPathLabel,
                  style: typo.overline.copyWith(color: colors.fg3),
                ),
                const SizedBox(height: InkSpacing.xs),
                // 可选中即可复制——即便「打开目录」在某些环境不可用，用户仍能拿到路径。
                SelectableText(
                  logsPath,
                  style: typo.monoMicro.copyWith(color: colors.fg2),
                ),
                const SizedBox(height: InkSpacing.lg),
                Wrap(
                  spacing: InkSpacing.sm,
                  runSpacing: InkSpacing.sm,
                  children: <Widget>[
                    InkButton(
                      label: context.l10n.commonRetry,
                      icon: Icons.refresh,
                      onPressed: () => _retry(ref),
                    ),
                    InkButton(
                      label: context.l10n.startupErrorOpenLogDir,
                      variant: InkButtonVariant.secondary,
                      icon: Icons.folder_open,
                      onPressed: () => _openLogs(ref, logsPath),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 重试：失效整条 PG provider 链（控制器 → 池 → 迁移池），gate 随之回到
  /// loading 并重新引导 PG；成功则 AsyncData → 正常 shell。
  void _retry(WidgetRef ref) {
    ref.invalidate(pgControllerProvider);
    ref.invalidate(pgPoolProvider);
    ref.invalidate(pgMigratedPoolProvider);
  }

  /// best-effort 打开日志目录；打不开（如缺可执行文件）静默吞错，不崩 UI。
  void _openLogs(WidgetRef ref, String logsPath) {
    ref.read(folderOpenerProvider).open(logsPath).ignore();
  }
}
