// 交付前检查的呈现（P6 §2.5）。判据在 util/delivery_preflight.dart，这里只做
// 「检查项 → ARB 文案 + 标记色」。
//
// 稿：每条 = 14px 宽标记位（mono 11）+ 正文，行高 1.45；`✓` success / `!` accent /
// `✕` danger；右上角「N 项待处理」，0 项时「可交付」success 色。
// 「!」条的正文比「✓」条亮一档——待处理的那条要先被看见。
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../delivery_keys.dart';
import '../models/delivery_plan.dart';
import '../util/delivery_check_labels.dart';
import '../util/delivery_preflight.dart';
import 'delivery_panel_rows.dart' show kDvLhSans11, kDvLhSans12;

/// 标记列 `line-height:1.45` × 11 = 15.938；条目文字 1.45 × 12 = 17.391。
const double _lhMark = 15.938;
const double _lhItem = 17.391;

/// 标记列宽（稿：14px）。
const double _kMarkColumn = 14;

/// 三个标记字符。稿用字符区分级别（警告与选中同色，靠「!」区分）。
const String _kMarkOk = '✓';
const String _kMarkWarn = '!';
const String _kMarkBlock = '✕';

/// 检查清单里的一行（一个检查项可能摊成多行——缺失产物每个镜一行）。
class _Line {
  const _Line({required this.mark, required this.text, this.key});

  /// null = 不画标记（「另有 N 个」这类续行）。
  final DeliveryCheckLevel? mark;
  final String text;
  final Key? key;
}

class DeliveryPreflightList extends StatelessWidget {
  const DeliveryPreflightList({
    super.key,
    required this.preflight,
    required this.projectName,
  });

  final DeliveryPreflight preflight;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final int pending = preflight.pendingCount;
    return Padding(
      key: DeliveryKeys.preflight,
      padding: const EdgeInsets.all(InkSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                l.deliveryPreflightTitle,
                style: t.body.copyWith(color: c.fg4, height: kDvLhSans12 / 12),
              ),
              const Spacer(),
              Text(
                key: DeliveryKeys.preflightCount,
                pending == 0
                    ? l.deliveryPreflightReady
                    : l.deliveryPreflightPending(pending),
                style: t.meta.copyWith(
                  color: pending == 0 ? c.success : c.accent,
                  height: kDvLhSans11 / 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.sm),
          for (final DeliveryCheck check in preflight.checks)
            for (final _Line line in _linesFor(l, check))
              _CheckRow(line: line),
        ],
      ),
    );
  }

  /// 一个检查项 → 一到多行文案。顺序即稿上的渲染顺序。
  ///
  /// 只有「缺失产物」会摊成多行（每个缺失镜一行，超过 3 个折成「另有 N 个」）；
  /// 其余四条各一行，文案与主按钮 Tooltip 同源（deliveryCheckHeadline）。
  List<_Line> _linesFor(AppLocalizations l, DeliveryCheck check) {
    final Key key = DeliveryKeys.check(check.id);
    final String headline =
        deliveryCheckHeadline(l, check, projectName: projectName);
    if (check.id != DeliveryCheckId.missingArtifacts ||
        check.missing.isEmpty) {
      return <_Line>[_Line(mark: check.level, text: headline, key: key)];
    }
    final ({List<DeliveryShotPlan> shown, int extra}) collapsed =
        collapseMissingShots(check.missing);
    return <_Line>[
      for (int i = 0; i < collapsed.shown.length; i++)
        _Line(
          mark: check.level,
          text: deliveryMissingItemText(l, collapsed.shown[i]),
          key: i == 0 ? key : null,
        ),
      if (collapsed.extra > 0)
        _Line(mark: null, text: l.deliveryCheckMissingMore(collapsed.extra)),
    ];
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.line});

  final _Line line;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final DeliveryCheckLevel? mark = line.mark;
    return Row(
      key: line.key,
      // 条目可能折行，标记要贴顶不是居中。
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: _kMarkColumn,
          child: mark == null
              ? null
              : Text(
                  switch (mark) {
                    DeliveryCheckLevel.ok => _kMarkOk,
                    DeliveryCheckLevel.warn => _kMarkWarn,
                    DeliveryCheckLevel.block => _kMarkBlock,
                  },
                  style: t.mono.copyWith(
                    color: switch (mark) {
                      DeliveryCheckLevel.ok => c.success,
                      DeliveryCheckLevel.warn => c.accent,
                      DeliveryCheckLevel.block => c.danger,
                    },
                    height: _lhMark / 11,
                  ),
                ),
        ),
        const SizedBox(width: InkSpacing.sm),
        Expanded(
          child: Text(
            line.text,
            style: t.body.copyWith(
              // 「✓」条比有待处理的条暗一档——要先被看见的是没过的那几条。
              color: mark == DeliveryCheckLevel.ok ? c.fg4 : c.fg2,
              height: _lhItem / 12,
            ),
          ),
        ),
      ],
    );
  }
}
