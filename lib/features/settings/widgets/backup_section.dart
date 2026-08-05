// BackupSection — 备份与还原（LB-22）。
//
// 列表 + 立即备份 + 按份还原。还原经 DatabaseRestoreFlow（flow 级单飞，busy 经
// app-scoped provider 展示——widget 级守卫会随切页归零，评审 P1-2）；确认框亮出
// 目标备份名+时间（盲还原不可接受，评审 UX P1-2）；还原全程 barrier 模态罩住
// （关池窗口内画布/画廊操作必炸，评审生命周期 P2-1）。
// 所有跨 await 依赖在首个 await 前 read 持有（#188 P1-1 教训）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/database.dart';
import '../../../core/di/database_backup.dart';
import '../../../core/di/database_restore.dart';
import '../../../core/di/project_archive.dart';
import '../../../core/di/current_screen.dart';
import '../../../core/interfaces/database_backup_service.dart';
import '../../../core/interfaces/database_restore_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../studio/providers/project_export_busy.dart';
import '../../../l10n/l10n_x.dart';
import '../../../storage/pg_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/components/ink_card.dart';
import '../../../theme/tokens.dart';
import '../../canvas/providers/current_canvas_id.dart';
import '../../gallery/providers/current_gallery_project.dart';
import '../../generation/services/toast_service.dart';

class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  List<BackupFileInfo> _backups = const <BackupFileInfo>[];

  /// 本地立即备份 busy（还原 busy 走 app-scoped databaseRestoreBusyProvider）。
  bool _backingUp = false;

  @override
  void initState() {
    super.initState();
    _backups = ref.read(databaseBackupServiceProvider).listBackups();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _backups = ref.read(databaseBackupServiceProvider).listBackups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    // 债158：三大重操作互斥的反向补查——项目导入/导出进行中,备份/还原区
    // 整体禁用（此前只有导入侧单向查,导入中仍可点还原）。
    final bool busy = _backingUp ||
        ref.watch(databaseRestoreBusyProvider) ||
        ref.watch(projectImportBusyProvider) ||
        ref.watch(projectExportBusyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsBackupSection,
          style: typo.title.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.xs),
        Text(
          context.l10n.settingsBackupHint,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.sm),
        InkButton(
          label: context.l10n.settingsBackupNow,
          icon: Icons.save_alt,
          onPressed: busy ? null : _backupNow,
        ),
        const SizedBox(height: InkSpacing.sm),
        if (_backups.isEmpty)
          Text(
            context.l10n.settingsBackupsEmpty,
            style: typo.caption.copyWith(color: colors.fg3),
          )
        else
          InkCard(
            child: Column(
              children: [
                for (final b in _backups) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.name,
                              style: typo.monoMicro.copyWith(color: colors.fg1),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: InkSpacing.xs),
                            Text(
                              '${_kindLabel(context.l10n, b.kind)} · '
                              '${context.l10n.settingsBackupMetaLine(_humanSize(b.sizeBytes), b.modified.toLocal())}',
                              style:
                                  typo.caption.copyWith(color: colors.fg3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: InkSpacing.sm),
                      InkButton(
                        label: context.l10n.settingsRestore,
                        variant: InkButtonVariant.secondary,
                        onPressed: busy ? null : () => _restore(b),
                      ),
                    ],
                  ),
                  if (b != _backups.last)
                    const SizedBox(height: InkSpacing.sm),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static String _kindLabel(AppLocalizations l10n, BackupKind kind) {
    return switch (kind) {
      BackupKind.daily => l10n.settingsBackupKindDaily,
      BackupKind.manual => l10n.settingsBackupKindManual,
      BackupKind.preRestore => l10n.settingsBackupKindPreRestore,
    };
  }

  /// 尺寸人话（单位符号跨语言通用，不进 ARB）。
  static String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _backupNow() async {
    // 跨 await 依赖首个 await 前 read 持有。
    final toast = ref.read(toastServiceProvider);
    final controller = ref.read(pgControllerProvider);
    final service = ref.read(databaseBackupServiceProvider);
    final doneMsg = context.l10n.settingsBackupDone;
    final failedMsg = context.l10n.settingsBackupFailed;
    final noBinMsg = context.l10n.settingsBackupNoBinaries;
    setState(() => _backingUp = true);
    try {
      final PgRuntime runtime;
      try {
        // 与还原 flow 同一 ensure-started 语义（评审 UX P2-4）。
        runtime = controller.runtime ?? await controller.start();
      } on PgLifecycleError {
        toast.show(failedMsg, kind: ToastKind.error);
        return;
      }
      final result = await service.backupNow(
        BackupConnection(
          host: runtime.host,
          port: runtime.port,
          username: kPgSuperuser,
          database: kPgDatabaseName,
          password: runtime.password,
        ),
        kind: BackupKind.manual,
      );
      switch (result.outcome) {
        case BackupOutcome.created:
          toast.show(doneMsg, kind: ToastKind.success);
        case BackupOutcome.skippedNoBinaries:
          toast.show(noBinMsg, kind: ToastKind.error);
        case BackupOutcome.failed:
        case BackupOutcome.skippedAlreadyToday: // backupNow 契约上不产生。
          toast.show(failedMsg, kind: ToastKind.error);
      }
      _refresh();
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _restore(BackupFileInfo b) async {
    // 跨 await 依赖首个 await 前 read 持有（成功路径会切走本页，#188 P1-1）。
    final toast = ref.read(toastServiceProvider);
    final flow = ref.read(databaseRestoreFlowProvider);
    final navigator = Navigator.of(context, rootNavigator: true);
    final screen = ref.read(currentScreenProvider.notifier);
    final canvasId = ref.read(currentCanvasIdProvider.notifier);
    final gallery = ref.read(currentGalleryProjectProvider.notifier);
    final l10n = context.l10n;
    final doneMsg = l10n.restoreDone;
    final progressMsg = l10n.restoreInProgress;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: context.inkColors.scrim,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.restoreConfirmTitle),
        content: Text(
          ctx.l10n.restoreConfirmBody(b.name, b.modified.toLocal()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.settingsRestore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // barrier 模态罩住全程：关池窗口内其它站点写库必炸（评审生命周期 P2-1）。
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
    RestoreFlowResult result;
    try {
      result = await flow.run(b.name, requirePreBackup: true);
    } catch (_) {
      // 放行点：flow 已 catch-all，走到这里只剩 override/装配错误——
      // 失败必须可见（本卡不变量），按 failed 收口。
      result = const RestoreFlowResult(outcome: RestoreOutcome.failed);
    } finally {
      // 收 barrier：优先按 dialog 自身 route 收；builder 未及构建时兜底
      // 弹根导航栈顶（showDialog 的 route 推入是同步的）。
      final ctx = barrierCtx;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      } else {
        navigator.pop();
      }
    }

    if (result.outcome == RestoreOutcome.restored) {
      // 会话重置：还原后的库里旧画布/画廊目标可能已不存在（评审 UX P2-2）。
      canvasId.state = null;
      gallery.state = null;
      screen.state = AppScreen.studio;
      toast.show(doneMsg, kind: ToastKind.success);
    } else {
      toast.show(l10nRestoreFailure(l10n, result.outcome),
          kind: ToastKind.error);
    }
    _refresh();
  }
}
