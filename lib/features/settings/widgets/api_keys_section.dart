// ApiKeysSection — 设置「API 密钥」页的 Key 表（Screens 稿第 3 屏）。
//
// 按 SecureStorageKeys.scopeOf 折叠家族。DashScope 的 6 款 Provider 合并为
// 一行，共用一把 Key；Gemini 独占一行。
//
// 表列照稿：Provider（名称 + 10px 成员说明）| Key（等宽输入，只有 1px 底线）| 状态。
// 稿上的「区域」列与「✓ 已验证 / ! 余额不足 / ✕ 连接失败」没有对应字段——
// 安全存储只回答「有没有这把 Key」，所以状态只有 ✓ 已配置 / – 未配置 两态；
// 掩码尾 4 位也不画（控制器不回读密钥原文）。保存 / 清除按钮是稿上没有、接线必需的。
//
// 存取/验证状态全部由 ApiKeyScopeController（family by providerId）承载，
// 本组件只持有输入框 controller 并渲染 AsyncValue。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/models/custom_provider_config.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../providers/api_key_scope_controller.dart';

class ApiKeysSection extends ConsumerWidget {
  const ApiKeysSection({super.key});

  /// 稿：grid 168px 1fr … 96px，gap 12。
  static const double providerColumnWidth = 168;
  static const double statusColumnWidth = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(providerCapabilitiesListProvider);
    final c = context.inkColors;
    final t = context.inkTypography;

    // 按 scope 折叠。LinkedHashMap 保持 caps 的注册顺序 → UI 稳定。
    final groups = <String, List<ProviderCapabilities>>{};
    for (final cap in caps) {
      final scope = SecureStorageKeys.scopeOf(cap.providerId);
      groups.putIfAbsent(scope, () => []).add(cap);
    }

    final TextStyle head = t.meta.copyWith(color: c.fg6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 稿：表头 26 高 + 下沿 1，11px fg6。
        Container(
          height: 27,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
          child: _Columns(
            provider: Text(context.l10n.settingsColumnProvider, style: head),
            key_: Text(context.l10n.settingsColumnKey, style: head),
            status: Text(context.l10n.settingsColumnStatus, style: head),
            actions: const SizedBox.shrink(),
          ),
        ),
        for (final entry in groups.entries)
          _ApiKeyRow(scope: entry.key, members: entry.value),
      ],
    );
  }
}

/// 稿的四列网格：168 | 1fr | 96 | 动作（稿上没有的保存 / 清除）。
class _Columns extends StatelessWidget {
  const _Columns({required this.provider, required this.key_, required this.status, required this.actions});
  final Widget provider;
  final Widget key_;
  final Widget status;
  final Widget actions;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          SizedBox(width: ApiKeysSection.providerColumnWidth, child: provider),
          const SizedBox(width: InkSpacing.s12),
          Expanded(child: key_),
          const SizedBox(width: InkSpacing.s12),
          SizedBox(width: ApiKeysSection.statusColumnWidth, child: status),
          const SizedBox(width: InkSpacing.s12),
          actions,
        ],
      );
}

class _ApiKeyRow extends ConsumerStatefulWidget {
  const _ApiKeyRow({required this.scope, required this.members});

  final String scope;
  final List<ProviderCapabilities> members;

  @override
  ConsumerState<_ApiKeyRow> createState() => _ApiKeyRowState();
}

class _ApiKeyRowState extends ConsumerState<_ApiKeyRow> {
  final TextEditingController _ctrl = TextEditingController();

  /// scope 下所有 Provider 共用同一把 Key——任选一成员做 family arg。
  String get _providerId => widget.members.first.providerId;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    final notifier =
        ref.read(apiKeyScopeControllerProvider(_providerId).notifier);
    try {
      final outcome = await notifier.save(v);
      if (!mounted) return;
      switch (outcome) {
        case ApiKeySaveOutcome.saved:
          _ctrl.clear();
          _showToast(context.l10n.settingsApiKeySaved);
        case ApiKeySaveOutcome.savedUnverified:
          _ctrl.clear();
          _showToast(context.l10n.settingsApiKeySavedUnverified);
        case ApiKeySaveOutcome.rejected:
          // 不清输入框——用户可直接修改重试。
          _showToast(context.l10n.settingsApiKeyRejected);
      }
    } on InkError catch (e) {
      if (!mounted) return;
      _showToast(l10nError(context, e));
    }
  }

  Future<void> _clear() async {
    final notifier =
        ref.read(apiKeyScopeControllerProvider(_providerId).notifier);
    try {
      await notifier.clear();
      if (!mounted) return;
      _showToast(context.l10n.settingsApiKeyCleared);
    } on InkError catch (e) {
      if (!mounted) return;
      _showToast(l10nError(context, e));
    }
  }

  void _showToast(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final keyState = ref.watch(apiKeyScopeControllerProvider(_providerId));
    final loading = keyState.isLoading;
    final isSet = keyState.valueOrNull ?? false;
    // custom:* 行显示配置里的 displayName（GAP-1 顺带修——此前裸 custom:<id>）。
    final String? customDisplayName = widget.members.first.displayName;
    final label = widget.scope.startsWith(kCustomProviderIdPrefix) &&
            customDisplayName != null &&
            customDisplayName.isNotEmpty
        ? customDisplayName
        : SecureStorageKeys.displayNameOf(widget.scope);
    final memberIds =
        widget.members.map((c) => c.providerId).join(' / ');
    final showMembers =
        widget.members.length > 1 || memberIds != label;

    // 稿：行 min 40 + padding 6，下沿 1（borderSubtle）。
    return Container(
      constraints: const BoxConstraints(minHeight: 53),
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderSubtle))),
      child: _Columns(
        provider: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg1)),
            if (showMembers) ...<Widget>[
              const SizedBox(height: InkSpacing.s2),
              Text(memberIds, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.micro.copyWith(color: c.fg6)),
            ],
          ],
        ),
        key_: InkInput(
          controller: _ctrl,
          hintText: context.l10n.settingsApiKeyPlaceholder,
          enabled: !loading,
        ),
        status: _Status(isSet: loading ? null : isSet),
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkButton(
              label: context.l10n.settingsApiKeySave,
              onPressed: loading ? null : _save,
            ),
            const SizedBox(width: InkSpacing.xs),
            InkButton(
              label: context.l10n.settingsApiKeyClear,
              variant: InkButtonVariant.secondary,
              onPressed: (loading || !isSet) ? null : _clear,
            ),
          ],
        ),
      ),
    );
  }
}

/// 稿：状态列 = 等宽标记 + 11px 文字，同一语义色。已配置 ✓ 绿；未配置 – 灰。
class _Status extends StatelessWidget {
  const _Status({required this.isSet});
  final bool? isSet;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    if (isSet == null) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final bool set = isSet!;
    final Color color = set ? c.success : c.fg6;
    return Row(
      children: <Widget>[
        Text(set ? '✓' : '–', style: t.mono.copyWith(color: color)),
        const SizedBox(width: InkSpacing.s6),
        Text(
          set ? context.l10n.settingsApiKeySet : context.l10n.settingsApiKeyNotSet,
          style: t.meta.copyWith(color: color),
        ),
      ],
    );
  }
}
