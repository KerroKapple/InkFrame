// runProjectImportFlow：LB-12 项目包导入——picker → barrier 模态 → service →
// 成功选中新项目。三大重操作（导入/还原/导出）互斥；依赖首 await 前 read 持有
// （#188 P1-1）。
//
// 抽成公开顶层函数（而非 studio_home_screen.dart 里的私有方法），因为
// 2026-08-31 审计 P0 发现零项目空态和命令面板都够不到这个入口——两处都要能调用
// 同一份逻辑，不能只挂在 FAB 按钮的私有回调里。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/database_restore.dart';
import '../../core/di/logger.dart';
import '../../core/di/project_archive.dart';
import '../../core/interfaces/project_import_service.dart';
import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../generation/services/toast_service.dart';
import 'controllers/studio_state.dart';
import 'providers/project_export_busy.dart';
import 'providers/workspace_projects_provider.dart';

const String _logModule = 'studio.import';

Future<void> runProjectImportFlow(BuildContext context, WidgetRef ref) async {
  final importBusy = ref.read(projectImportBusyProvider.notifier);
  if (importBusy.state ||
      ref.read(databaseRestoreBusyProvider) ||
      ref.read(projectExportBusyProvider)) {
    return;
  }
  final toast = ref.read(toastServiceProvider);
  final logger = ref.read(loggerProvider);
  final picker = ref.read(openFilePickerProvider);
  final serviceFuture = ref.read(projectImportServiceProvider.future);
  final selected = ref.read(selectedProjectIdProvider.notifier);
  final container = ProviderScope.containerOf(context, listen: false);
  final navigator = Navigator.of(context, rootNavigator: true);
  final l10n = context.l10n;
  final progressMsg = l10n.importInProgress;
  final doneMsg = l10n.importDone;
  importBusy.state = true;
  try {
    final String? path;
    try {
      path = await picker();
    } catch (e, st) {
      // 放行点：平台 picker 异常不得静默（#192 评审 P3-5）。
      logger.error(_logModule, 'import picker failed', cause: e, stackTrace: st);
      toast.show(l10n.importFailed, kind: ToastKind.error);
      return;
    }
    if (path == null || !context.mounted) return;

    // barrier 模态罩全程（导入分钟级；LB-22 同款）。
    BuildContext? barrierCtx;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: context.inkColors.scrim,
      builder: (ctx) {
        barrierCtx = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: InkSpacing.md),
                Text(progressMsg),
              ],
            ),
          ),
        );
      },
    ));
    ImportResult result;
    try {
      final service = await serviceFuture;
      result = await service.importArchive(zipPath: path);
    } catch (e, st) {
      // 放行点：service 已收敛所有已知失败——这里兜装配错误，失败必须可见。
      logger.error(_logModule, 'import unexpected', cause: e, stackTrace: st);
      result = const ImportResult(outcome: ImportOutcome.failed);
    } finally {
      final ctx = barrierCtx;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      } else {
        navigator.pop();
      }
    }

    if (result.outcome == ImportOutcome.imported) {
      container.invalidate(workspaceProjectsProvider);
      selected.state = result.newProjectId;
      toast.show(doneMsg, kind: ToastKind.success);
    } else {
      final String msg = switch (result.outcome) {
        ImportOutcome.failedFormat => l10n.importFailedFormat,
        ImportOutcome.failedVersionNewer => l10n.importFailedVersionNewer,
        ImportOutcome.failedCorrupt => l10n.importFailedCorrupt,
        ImportOutcome.failed || ImportOutcome.imported => l10n.importFailed,
      };
      toast.show(msg, kind: ToastKind.error);
    }
  } finally {
    importBusy.state = false;
  }
}
