// NetworkSection — 设置「网络」页（Screens 稿第 3 屏左导航第 6 项）。
//
// 【只读，且这是有意的】本仓库的代理支持就是环境变量（LB-24 P0）：没有「在设置里
// 填代理」这个后端，能填的那一版是 LB-24 P1。P7 的口径是「有后端才画」，所以这页
// 画的是真实读到的四个变量 + 此刻到底走不走代理，不画一个存不下去的输入框。
//
// 「走不走代理」由 util/proxy_status.dart 复用 core/net 的 proxyRuleFor 算出——
// 空串=显式禁用 / loopback 恒直连 / NO_PROXY 后缀匹配这些约定只许有一处实现。
// 凭据恒掩码：代理串里的口令与 API Key 同级，不上屏。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/net.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../util/proxy_status.dart';

class NetworkSection extends ConsumerWidget {
  const NetworkSection({super.key});

  /// 变量名列：等宽，放得下 HTTPS_PROXY。
  static const double nameColumnWidth = 140;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final Map<String, String> env = ref.watch(processEnvironmentProvider);
    final String? target = effectiveHttpsProxyTarget(env);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.settingsNetworkEnvTitle,
          style: t.sectionTitle.copyWith(color: c.fg1),
        ),
        const SizedBox(height: InkSpacing.s12),
        for (final ProxyVarRow row in readProxyVars(env))
          _VarRow(name: proxyVarName(row.variable), value: row.value),
        const SizedBox(height: InkSpacing.md),
        _EffectiveRow(target: target),
        const SizedBox(height: InkSpacing.s12),
        Text(
          context.l10n.settingsNetworkEnvNote,
          style: t.meta.copyWith(color: c.fg5, height: 1.5),
        ),
      ],
    );
  }
}

class _VarRow extends StatelessWidget {
  const _VarRow({required this.name, required this.value});

  final String name;

  /// null = 未设置；'' = 存在但空串（显式禁用该档）。
  final String? value;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final bool unset = value == null;
    final bool disabled = value != null && value!.isEmpty;
    final String text = unset
        ? context.l10n.settingsNetworkUnset
        : (disabled ? context.l10n.settingsNetworkDisabled : value!);
    return Container(
      height: 29, // content 28 + border-bottom 1
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: NetworkSection.nameColumnWidth,
            child: Text(name, style: t.mono.copyWith(color: c.fg4)),
          ),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 未设置 / 显式禁用是缺省态，走 fg6（与 Key 表「未配置」同色）。
              style: unset || disabled
                  ? t.body.copyWith(color: c.fg6)
                  : t.mono.copyWith(color: c.fg2),
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前状态行：直连 / 经某个代理。走不走代理是用户唯一真正想知道的一行。
class _EffectiveRow extends StatelessWidget {
  const _EffectiveRow({required this.target});

  /// null = 直连。
  final String? target;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            context.l10n.settingsNetworkEffectiveLabel,
            style: t.body.copyWith(color: c.fg2),
          ),
        ),
        Text(
          target == null
              ? context.l10n.settingsNetworkDirect
              : context.l10n.settingsNetworkViaProxy(target!),
          style: t.mono.copyWith(color: target == null ? c.fg5 : c.accent),
        ),
      ],
    );
  }
}
