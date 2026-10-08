// PerformanceSection — 设置「性能」页（Screens 稿第 3 屏左导航第 4 项）。
//
// 【这一页是只读的，而且这是有意的】稿上「并发与配额」画了三个滑块，正文还写
// 「性能档位会改写全局上限」——但仓库里没有性能档位：ARCHITECTURE §10 的
// PerformanceTier / PerformanceDegradationController 整章未实现，JobQueue 的
// globalConcurrency 是构造期注入的定值（kDefaultGlobalConcurrency）。P7 的口径是
// 「有后端才画，没有的行不留空位」，所以这里画的是**真实生效的上限**，不画假滑块：
// 滑块能拖却拖不动任何东西，比没有滑块更坏。
//
// 数据源都是现成的真相源：全局上限取 kDefaultGlobalConcurrency（渲染队列面板读的
// 同一个常量），每个 Provider 的并发 / QPS 取 providerCapabilitiesListProvider
// （API 密钥页读的同一张能力表），图像缓存上限取 kImageCacheMaxBytes。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/image_cache.dart';
import '../../../core/di/providers.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../services/job_queue_service.dart' show kDefaultGlobalConcurrency;
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

class PerformanceSection extends ConsumerWidget {
  const PerformanceSection({super.key});

  /// 数值列宽（并发 / QPS 两列）。
  static const double numberColumnWidth = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final List<ProviderCapabilities> caps =
        ref.watch(providerCapabilitiesListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.settingsPerformanceConcurrencyTitle,
          style: t.sectionTitle.copyWith(color: c.fg1),
        ),
        const SizedBox(height: InkSpacing.s12),
        _ValueRow(
          label: context.l10n.settingsPerformanceGlobalLimit,
          value: '$kDefaultGlobalConcurrency',
        ),
        _ValueRow(
          label: context.l10n.settingsPerformanceImageCache,
          value: context.l10n
              .settingsPerformanceMegabytes(kImageCacheMaxBytes >> 20),
        ),
        const SizedBox(height: InkSpacing.s12),
        Text(
          context.l10n.settingsPerformanceDispatchNote,
          style: t.meta.copyWith(color: c.fg5, height: 1.5),
        ),
        const SizedBox(height: InkSpacing.xs),
        Text(
          context.l10n.settingsPerformanceReadOnlyNote,
          style: t.meta.copyWith(color: c.fg5, height: 1.5),
        ),
        const SizedBox(height: InkSpacing.xl),
        Text(
          context.l10n.settingsPerformanceProvidersTitle,
          style: t.sectionTitle.copyWith(color: c.fg1),
        ),
        const SizedBox(height: InkSpacing.sm),
        const _ProviderHeader(),
        for (final ProviderCapabilities cap in caps)
          _ProviderRow(cap: cap),
      ],
    );
  }
}

/// 「标签 ……… 值」一行：值等宽右对齐（与存储页的只读行同形）。
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: 29, // content 28 + border-bottom 1
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(color: c.fg2),
            ),
          ),
          Text(value, style: t.mono.copyWith(color: c.fg1)),
        ],
      ),
    );
  }
}

class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final TextStyle head = context.inkTypography.meta.copyWith(color: c.fg6);
    return Container(
      height: 27, // content 26 + border-bottom 1
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(context.l10n.settingsColumnProvider, style: head),
          ),
          SizedBox(
            width: PerformanceSection.numberColumnWidth,
            child: Text(
              context.l10n.settingsColumnConcurrency,
              style: head,
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(
            width: PerformanceSection.numberColumnWidth,
            child: Text(
              context.l10n.settingsColumnQps,
              style: head,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.cap});

  final ProviderCapabilities cap;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: 29,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              cap.displayName ?? cap.providerId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(color: c.fg2),
            ),
          ),
          SizedBox(
            width: PerformanceSection.numberColumnWidth,
            child: Text(
              '${cap.maxConcurrentJobs}',
              style: t.mono.copyWith(color: c.fg1),
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(
            width: PerformanceSection.numberColumnWidth,
            child: Text(
              '${cap.qps}',
              style: t.mono.copyWith(color: c.fg1),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
