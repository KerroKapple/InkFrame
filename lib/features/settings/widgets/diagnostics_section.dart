// DiagnosticsSection — 日志目录入口 + 诊断包导出（LB-18）。
//
// 打开日志目录走 FolderOpener（best-effort）；导出经 saveLocationPickerProvider
// seam（LB-11 同款）→ DiagnosticsBundleService → 成败 toast。
// 跨 await 依赖首个 await 前 read 持有（#188 P1-1 惯例）。
//
// 导出按钮抽成 [DiagnosticsExportButton]：设置浮层的底部条（Screens 稿）也放一枚，
// 两处同一条导出路径，不复制逻辑。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/clock.dart';
import '../../../core/di/diagnostics.dart';
import '../../../core/di/folder_opener.dart';
import '../../../core/di/logger.dart';
import '../../../core/di/paths.dart';
import '../../../core/di/project_archive.dart';
import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../services/diagnostics_bundle_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/tokens.dart';
import '../../generation/services/toast_service.dart';

class DiagnosticsSection extends ConsumerWidget {
  const DiagnosticsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsDiagnosticsSection,
          style: typo.sectionTitle.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.xs),
        Text(
          context.l10n.settingsDiagnosticsHint,
          style: typo.meta.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.sm),
        Wrap(
          spacing: InkSpacing.sm,
          runSpacing: InkSpacing.sm,
          children: [
            InkButton(
              label: context.l10n.settingsOpenLogDir,
              variant: InkButtonVariant.secondary,
              icon: Icons.folder_open,
              onPressed: () => _openLogs(ref),
            ),
            const DiagnosticsExportButton(),
          ],
        ),
      ],
    );
  }

  /// best-effort 打开日志目录（同 StartupErrorView：打不开静默，不崩 UI）。
  void _openLogs(WidgetRef ref) {
    final logsPath = ref.read(appPathsProvider).logs.path;
    ref.read(folderOpenerProvider).open(logsPath).ignore();
  }
}

/// 「导出诊断包…」：选保存位置 → 打包 → toast。在途时禁用（防重入）。
class DiagnosticsExportButton extends ConsumerStatefulWidget {
  const DiagnosticsExportButton({super.key, this.variant = InkButtonVariant.primary});

  final InkButtonVariant variant;

  @override
  ConsumerState<DiagnosticsExportButton> createState() => _DiagnosticsExportButtonState();
}

class _DiagnosticsExportButtonState extends ConsumerState<DiagnosticsExportButton> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return InkButton(
      label: context.l10n.settingsExportDiagnostics,
      variant: widget.variant,
      icon: widget.variant == InkButtonVariant.primary ? Icons.medical_information_outlined : null,
      onPressed: _exporting ? null : _export,
    );
  }

  Future<void> _export() async {
    // 跨 await 依赖首个 await 前 read 持有。
    final toast = ref.read(toastServiceProvider);
    final logger = ref.read(loggerProvider);
    final picker = ref.read(saveLocationPickerProvider);
    final serviceFuture = ref.read(diagnosticsBundleServiceProvider.future);
    final suggested =
        diagnosticsBundleFileName(ref.read(clockProvider).nowUtc());
    final doneMsg = context.l10n.settingsDiagnosticsExported;
    final failedMsg = context.l10n.settingsDiagnosticsExportFailed;
    setState(() => _exporting = true);
    try {
      final path = await picker(suggested);
      if (path == null) return; // 用户取消。
      final service = await serviceFuture;
      await service.exportBundle(targetPath: path);
      toast.show(doneMsg, kind: ToastKind.success);
    } on InkError catch (e, st) {
      logger.error(kDiagnosticsModule, 'diagnostics export failed',
          cause: e, stackTrace: st);
      toast.show(failedMsg, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
