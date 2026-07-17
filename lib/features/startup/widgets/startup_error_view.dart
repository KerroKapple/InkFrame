// StartupErrorView：启动失败全屏 surface（LB-09 / LB-22）。
//
// 当 DB-ready future（pgMigratedPoolProvider）处于 AsyncError 时，顶层 gate
// （app.dart 的 _StartupGate）用它替代白屏：解释数据库启动失败、亮出日志目录、
// 给出「重试」「打开日志目录」，以及有备份时的「从最近备份还原」（LB-22——
// 目标排除 prerestore 族：那可能是坏库的 dump，盲还原会死循环，评审 UX P1-2）。
//
// 「重试」是 stateful 的：先 await 停掉当前 PG 实例，再失效整条链重建——避免旧
// stop() 与新 start() 的 postmaster.pid 探测竞态；busy 到链出确定态才复位
// （评审生命周期 P1-1：invalidate 即复位会在重建在途期放进第二次操作）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/database.dart';
import '../../../core/di/database_backup.dart';
import '../../../core/di/database_restore.dart';
import '../../../core/di/folder_opener.dart';
import '../../../core/di/paths.dart';
import '../../../core/interfaces/database_backup_service.dart';
import '../../../core/interfaces/database_restore_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../storage/pg_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/tokens.dart';
import '../../generation/services/toast_service.dart';

class StartupErrorView extends ConsumerStatefulWidget {
  const StartupErrorView({super.key, required this.error});

  /// pgMigratedPoolProvider 的 AsyncError 值（DI 边界已翻成 InkError）。
  final Object error;

  @override
  ConsumerState<StartupErrorView> createState() => _StartupErrorViewState();
}

class _StartupErrorViewState extends ConsumerState<StartupErrorView> {
  /// 重启/还原进行中：禁用按钮防重复触发（stop→invalidate→重建的异步窗口内）。
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final String logsPath = ref.watch(appPathsProvider).logs.path;
    // 还原目标 = 最新的 daily/manual（排除 prerestore：可能是坏库的 dump）。
    final List<BackupFileInfo> restorable = ref
        .watch(databaseBackupServiceProvider)
        .listBackups()
        .where((b) => b.kind != BackupKind.preRestore)
        .toList(growable: false);
    final BackupFileInfo? latest =
        restorable.isEmpty ? null : restorable.first;
    final bool busy = _working || ref.watch(databaseRestoreBusyProvider);

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
                InkErrorBanner(message: l10nAsyncError(context, widget.error)),
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
                      // 重启/还原进行中禁用，防重复触发并发 stop/start。
                      onPressed: busy ? null : _reboot,
                    ),
                    if (latest != null)
                      InkButton(
                        label: context.l10n.startupErrorRestoreLatest,
                        variant: InkButtonVariant.secondary,
                        icon: Icons.settings_backup_restore,
                        onPressed: busy ? null : () => _restoreLatest(latest),
                      ),
                    InkButton(
                      label: context.l10n.startupErrorOpenLogDir,
                      variant: InkButtonVariant.secondary,
                      icon: Icons.folder_open,
                      onPressed: () => _openLogs(logsPath),
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

  /// 重试：先 await 停掉当前 PG 实例，再失效整条链（控制器 → 池 → 迁移池）重建。
  /// busy 到链出确定态才复位——invalidate 即复位会在「重建在途」窗口放进第二次
  /// stop/start/还原，与在途 start() 竞速（评审生命周期 P1-1）。
  Future<void> _reboot() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await ref.read(pgControllerProvider).stop();
    } on PgLifecycleError {
      // 停机失败不阻断重试；重建时的崩溃恢复会清理 stale postmaster.pid。
    }
    if (!mounted) return;
    ref.invalidate(pgControllerProvider);
    ref.invalidate(pgPoolProvider);
    ref.invalidate(pgMigratedPoolProvider);
    // 等链出确定态（成功 → gate 换页卸载本 view；失败 → 同位复用本 State）。
    try {
      await ref.read(pgMigratedPoolProvider.future);
    } catch (_) {
      // 仍失败：错误横幅由 gate 以新 error 重建呈现。
    }
    if (mounted) setState(() => _working = false);
  }

  /// 从最近备份还原（LB-22）：确认框亮出目标名+时间 → flow（启动面语义：
  /// 预备份 best-effort——库已坏 dump 不出来不拦路）。失败经 app 级 toast 呈现
  /// （gate 可能已换页，本 State 的横幅不可依赖）。
  Future<void> _restoreLatest(BackupFileInfo target) async {
    if (_working) return;
    // 跨 await 依赖首个 await 前 read 持有（#188 P1-1）。
    final toast = ref.read(toastServiceProvider);
    final flow = ref.read(databaseRestoreFlowProvider);
    final l10n = context.l10n;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: context.inkColors.scrim,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.restoreConfirmTitle),
        content: Text(
          ctx.l10n.restoreConfirmBody(target.name, target.modified.toLocal()),
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

    setState(() => _working = true);
    // flow 内部 await 链重建：run 返回时成败已定——成功 gate 自行换页。
    final result = await flow.run(target.name, requirePreBackup: false);
    if (result.outcome != RestoreOutcome.restored) {
      toast.show(l10nRestoreFailure(l10n, result.outcome),
          kind: ToastKind.error);
    }
    if (mounted) setState(() => _working = false);
  }

  /// best-effort 打开日志目录；打不开（如缺可执行文件）静默吞错，不崩 UI。
  void _openLogs(String logsPath) {
    ref.read(folderOpenerProvider).open(logsPath).ignore();
  }
}
