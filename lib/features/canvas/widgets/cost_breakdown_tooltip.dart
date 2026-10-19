// CostBreakdownTooltip：鼠标停在「生成」上出的花费明细卡（TakesCost 稿「花费预告」右侧「预计」卡）。
//
// 检查器的生成按钮（inspector_status_panel 的 _IdleButton）与画布底部提示词条的生成按钮共用。
// 只在按钮可点时由调用方包上；置灰时只出原有的原因 tooltip，不叠明细。
//
// 四行：
//   ① 「预计」+ 金额（算得出写「约 $0.75」，算不出写「—」+「价格未知」）
//   ② 服务商名 · 时长 · 分辨率（后两段只有视频有）
//   ③ 计价式：每次 / 批量 $0.032 × 4 = $0.13 / $0.30 / 秒（1080p）× 0.5 / 每千字 … + 每张 … × N，
//      算不出时写原因（自定义接口没有价目 / 找不到这个服务商 / 没选时长）
//   ④ 以服务商账单为准
// 金额与单价是格式量（cost_estimator / node_cost），句子走 ARB；拼行用 join，不写「字面量前缀 + l10n」。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/cost_model.dart';
import '../../../l10n/duration_format.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../generation/services/cost_estimator.dart';
import '../../generation/services/node_cost.dart';

class CostBreakdownTooltip extends ConsumerWidget {
  const CostBreakdownTooltip({super.key, required this.estimate, required this.child});

  /// null ⇒ 不出明细，原样返回 [child]（非配置节点 / 解析不出供应商）。
  final NodeCostEstimate? estimate;
  final Widget child;

  /// 明细正文的测试锚点（浮层里那张卡）。
  static const Key contentKey = Key('canvas.costBreakdown.content');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NodeCostEstimate? e = estimate;
    if (e == null) return child;
    final String providerName = ref.watch(providerDisplayNamesProvider)[e.providerId] ?? e.providerId;
    return Tooltip(
      // 正文是排好版的一张卡（WidgetSpan），读屏取不到有意义的纯文本；按钮自己有语义标签。
      excludeFromSemantics: true,
      richMessage: WidgetSpan(
        child: _CostBreakdownCard(key: contentKey, estimate: e, providerName: providerName),
      ),
      child: child,
    );
  }
}

class _CostBreakdownCard extends StatelessWidget {
  const _CostBreakdownCard({super.key, required this.estimate, required this.providerName});

  final NodeCostEstimate estimate;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final NodeCostEstimate e = estimate;
    final String amount = formatNodeCost(e);
    final bool known = e.usd != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l.costBreakdownTitle, style: t.meta.copyWith(color: c.fg5)),
            const SizedBox(width: InkSpacing.sm),
            Text(known ? l.costApprox(amount) : amount, style: t.bodyStrong.copyWith(color: c.fg1)),
            if (!known) ...<Widget>[
              const SizedBox(width: InkSpacing.sm),
              Text(l.costUnknown, style: t.meta.copyWith(color: c.fg5)),
            ],
          ],
        ),
        const SizedBox(height: InkSpacing.xs),
        Text(costSubjectLine(l, e, providerName), style: t.meta.copyWith(color: c.fg3)),
        const SizedBox(height: InkSpacing.s2),
        Text(costFormulaLine(l, e), style: t.mono.copyWith(color: c.fg3)),
        const SizedBox(height: InkSpacing.xs),
        Text(l.costBreakdownDisclaimer, style: t.meta.copyWith(color: c.fg6)),
      ],
    );
  }
}

/// 明细第 ② 行：服务商名 · 时长 · 分辨率（时长与分辨率只有视频有；没时长 / 没价目时不写那一段）。
String costSubjectLine(AppLocalizations l, NodeCostEstimate e, String providerName) => <String>[
      providerName,
      if (e.isVideo && e.durationSeconds > 0) formatDurationLabel(l, e.durationSeconds * 1000),
      if (e.isVideo && e.costModel != null) resolutionShortLabel(e.resolution),
    ].join(' · ');

/// 明细第 ③ 行：计价式；算不出时写原因。
String costFormulaLine(AppLocalizations l, NodeCostEstimate e) {
  final NodeCostUnknown? unknown = e.unknown;
  if (unknown != null) {
    return switch (unknown) {
      NodeCostUnknown.customEndpoint => l.costUnknownCustom,
      NodeCostUnknown.providerMissing => l.costUnknownProvider,
      NodeCostUnknown.noDuration => l.costUnknownDuration,
    };
  }
  final CostModel? model = e.costModel;
  final double? usd = e.usd;
  if (model == null || usd == null) return l.costUnknownProvider;
  return switch (model) {
    PerCall(:final usdPerCall) => e.batch > 1
        ? l.costFormulaBatch(formatUnitPriceUsd(usdPerCall), e.batch, formatCostUsd(usd))
        : l.costFormulaPerCall(formatUnitPriceUsd(usdPerCall)),
    PerSecondVideo(:final usdPerSecondAt1080p, :final resolutionMultiplier) =>
      _perSecond(l, usdPerSecondAt1080p, resolutionMultiplier[e.resolution] ?? 1.0),
    PerCharInput(:final usdPerKChar, :final usdPerImageOutput) => l.costFormulaPerChar(
        formatUnitPriceUsd(usdPerKChar),
        formatUnitPriceUsd(usdPerImageOutput),
        e.batch,
      ),
  };
}

/// 每秒计价：倍率为 1 时不写「× 1」。
String _perSecond(AppLocalizations l, double rate, double multiplier) => multiplier == 1.0
    ? l.costFormulaPerSecond(formatUnitPriceUsd(rate))
    : l.costFormulaPerSecondScaled(formatUnitPriceUsd(rate), formatCostMultiplier(multiplier));
