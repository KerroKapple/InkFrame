// InspectorAutoSaveRow：自动保存的失败面（检查器底部常驻一行）。
//
// 为什么是常驻一行而不是 toast：自动保存失败是**节点级**的持续事实——那一笔改动
// 到现在还没落盘。toast 会自己消失，用户错过就再没有重试入口，等于回到「静默丢」
// 那个旧行为；常驻行既说清原因又一直把「重试」摆在手边。
//
// 为什么挂在 CanvasInspectorPanel 而不是各检查器里：所有自动保存入口（提示词条的
// prompt、shot 备注、各下拉、角色挂载）都要求恰好选中一个节点，而检查器面板正是
// 「选中一个节点就在屏上」的那一层——一处接线覆盖全部写点。
//
// Clean 态不占位（SizedBox.shrink），面板布局与今天完全一致。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/inspector_submit_controller.dart';

class InspectorAutoSaveRow extends ConsumerWidget {
  const InspectorAutoSaveRow({super.key, required this.nodeId});

  /// 被编辑的 config 节点 id（= inspectorAutoSaveStatusProvider 的 family key）。
  final String nodeId;

  /// 「重试」按钮的测试锚点。
  static const Key retryKey = Key('inspector.autoSave.retry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InspectorAutoSaveState state =
        ref.watch(inspectorAutoSaveStatusProvider(nodeId));
    final c = context.inkColors;
    final l = context.l10n;
    return switch (state) {
      InspectorAutoSaveClean() => const SizedBox.shrink(),
      // 重试中用 accent（稿里警告态与强调同色），且不给按钮——此刻点「重试」
      // 只会插队到同一条写入链后面，徒增困惑。
      InspectorAutoSaveRetrying() => _Banner(
          message: l.inspectorAutoSaveRetrying,
          tint: c.accent,
          icon: Icons.sync_problem_outlined,
        ),
      InspectorAutoSaveFailed(error: final e) => _Banner(
          message: l.inspectorAutoSaveFailed(l10nError(context, e)),
          tint: c.danger,
          icon: Icons.save_outlined,
          // fire-and-forget：写入的成败由本行自己反映，点击方不必等它。
          onRetry: () => unawaited(
            ref
                .read(inspectorSubmitControllerProvider(nodeId).notifier)
                .retryUnsaved(),
          ),
        ),
    };
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.tint,
    required this.icon,
    this.onRetry,
  });

  /// 已本地化的说明文案。
  final String message;
  final Color tint;
  final IconData icon;

  /// null = 不给动作（自动重试还在走）。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final retry = onRetry;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s12,
        vertical: InkSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: InkSpacing.md, color: tint),
          const SizedBox(width: InkSpacing.sm),
          Expanded(
            child: Text(message, style: t.meta.copyWith(color: c.fg2)),
          ),
          if (retry != null) ...<Widget>[
            const SizedBox(width: InkSpacing.sm),
            TextButton(
              key: InspectorAutoSaveRow.retryKey,
              onPressed: retry,
              child: Text(context.l10n.inspectorRetry),
            ),
          ],
        ],
      ),
    );
  }
}
