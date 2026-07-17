// ApiKeysSection — 设置页内"API Keys"分节。
//
// 按 SecureStorageKeys.scopeOf 折叠家族。DashScope 的 6 款 Provider 合并为
// 一行，共用一把 Key；Gemini 独占一行。
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(providerCapabilitiesListProvider);
    final colors = context.inkColors;
    final typo = context.inkTypography;

    // 按 scope 折叠。LinkedHashMap 保持 caps 的注册顺序 → UI 稳定。
    final groups = <String, List<ProviderCapabilities>>{};
    for (final c in caps) {
      final scope = SecureStorageKeys.scopeOf(c.providerId);
      groups.putIfAbsent(scope, () => []).add(c);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsApiKeysSection,
          style: typo.title.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.xs),
        Text(
          context.l10n.settingsApiKeysHint,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.md),
        for (final entry in groups.entries)
          _ApiKeyRow(scope: entry.key, members: entry.value),
      ],
    );
  }
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
    final colors = context.inkColors;
    final typo = context.inkTypography;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: typo.body.copyWith(color: colors.fg1),
                    ),
                    if (showMembers)
                      Text(
                        memberIds,
                        style: typo.caption.copyWith(color: colors.fg3),
                      ),
                  ],
                ),
              ),
              _StatusChip(isSet: loading ? null : isSet),
            ],
          ),
          const SizedBox(height: InkSpacing.xs),
          Row(
            children: [
              Expanded(
                child: InkInput(
                  controller: _ctrl,
                  hintText: context.l10n.settingsApiKeyPlaceholder,
                ),
              ),
              const SizedBox(width: InkSpacing.sm),
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
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isSet});
  final bool? isSet;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    if (isSet == null) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final set = isSet!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
      decoration: BoxDecoration(
        color: set ? colors.success.withValues(alpha: 0.15) : colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Text(
        set
            ? context.l10n.settingsApiKeySet
            : context.l10n.settingsApiKeyNotSet,
        style: typo.caption.copyWith(
          color: set ? colors.success : colors.fg3,
        ),
      ),
    );
  }
}
