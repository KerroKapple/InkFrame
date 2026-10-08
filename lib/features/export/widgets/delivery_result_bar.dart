// 交付结果条（P6 §3.5）：面板顶部 32px。
//
// 成功：surface5 底 + success `✓` +「已交付到 {目录}」+「打开文件夹」「复制路径」。
// 失败：accentWash 底 + danger `✕` + **errorCode 原串** +「重试」。
//
// 为什么失败条写原串而不是本地化文案：这一条是给用户贴给我的（诊断包 / issue）。
// `local_io_error` 这种码在任何语言的日志里都是同一个词，翻译它等于把检索能力拿掉。
//
// 结果条手动关闭（右侧 ✕），或下次交付时被替换。
import 'package:flutter/material.dart';

import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/delivery_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../delivery_keys.dart';
import 'delivery_panel_rows.dart' show kDvLhSans11, kDvResultBarHeight;

class DeliveryResultBar extends StatelessWidget {
  const DeliveryResultBar.success({
    super.key,
    required DeliveryOutcome this.outcome,
    required this.onOpenFolder,
    required this.onCopyPath,
    required this.onDismiss,
  })  : error = null,
        onRetry = null;

  const DeliveryResultBar.failure({
    super.key,
    required InkError this.error,
    required this.onRetry,
    required this.onDismiss,
  })  : outcome = null,
        onOpenFolder = null,
        onCopyPath = null;

  final DeliveryOutcome? outcome;
  final InkError? error;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onCopyPath;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final bool ok = outcome != null;
    final TextStyle body = t.meta.copyWith(
      color: ok ? c.fg2 : c.fg1,
      height: kDvLhSans11 / 11,
    );
    return Container(
      key: DeliveryKeys.resultBar,
      height: kDvResultBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        color: ok ? c.surface5 : c.accentWash,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            ok ? '✓' : '✕',
            style: t.mono.copyWith(color: ok ? c.success : c.danger),
          ),
          const SizedBox(width: InkSpacing.s6),
          Expanded(
            child: Text(
              ok
                  ? l.deliveryResultSuccess(outcome!.outputDirRelative)
                  // errorCode 原串，不走 ARB（见文件头注）。
                  : error!.code.wire,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body,
            ),
          ),
          if (ok) ...<Widget>[
            _Link(
              itemKey: DeliveryKeys.resultOpenFolder,
              label: l.deliveryOpenFolder,
              onTap: onOpenFolder,
            ),
            const SizedBox(width: InkSpacing.s10),
            _Link(
              itemKey: DeliveryKeys.resultCopyPath,
              label: l.deliveryCopyPath,
              onTap: onCopyPath,
            ),
          ] else
            _Link(
              itemKey: DeliveryKeys.resultRetry,
              label: l.deliveryRetry,
              onTap: onRetry,
            ),
          const SizedBox(width: InkSpacing.s10),
          _Link(
            itemKey: DeliveryKeys.resultDismiss,
            label: l.deliveryResultDismiss,
            glyph: '✕',
            onTap: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// 32px 条里放不下按钮，用文字链（11px accent）。
class _Link extends StatelessWidget {
  const _Link({
    required this.itemKey,
    required this.label,
    required this.onTap,
    this.glyph,
  });

  final Key itemKey;
  final String label;
  final VoidCallback? onTap;

  /// 给出时只画这个字符（关闭用 ✕），label 仍进 Semantics / Tooltip。
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: Tooltip(
        message: label,
        child: MouseRegion(
          cursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            key: itemKey,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Text(
              glyph ?? label,
              style: t.meta.copyWith(
                color: onTap == null ? c.fg6 : c.accent,
                height: kDvLhSans11 / 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
