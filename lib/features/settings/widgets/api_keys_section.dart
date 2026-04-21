// ApiKeysSection — 设置页内"API Keys"分节。
//
// 每个已注册 Provider 一行：Provider id + 遮罩输入框 + Save/Clear。
// 状态条：已配置 / 未配置。保存写 SecureStorage；清除走 delete。
//
// 本组件不做 key 格式校验——Provider 自身的 validate 调用留给 Controller 层
// (后续 sprint)。此处只管"放进 / 取出 / 删除"三件事。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/interfaces/secure_storage_service.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';

class ApiKeysSection extends ConsumerWidget {
  const ApiKeysSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(providerCapabilitiesListProvider);
    final colors = context.inkColors;
    final typo = context.inkTypography;
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
        for (final c in caps) _ApiKeyRow(capabilities: c),
      ],
    );
  }
}

class _ApiKeyRow extends ConsumerStatefulWidget {
  const _ApiKeyRow({required this.capabilities});
  final ProviderCapabilities capabilities;

  @override
  ConsumerState<_ApiKeyRow> createState() => _ApiKeyRowState();
}

class _ApiKeyRowState extends ConsumerState<_ApiKeyRow> {
  final TextEditingController _ctrl = TextEditingController();
  bool _isSet = false;
  bool _loading = true;

  SecureStorageService get _secure =>
      ref.read(secureStorageServiceProvider);
  String get _key =>
      SecureStorageKeys.providerApiKey(widget.capabilities.providerId);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final has = await _secure.exists(_key);
    if (!mounted) return;
    setState(() {
      _isSet = has;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    await _secure.store(_key, v);
    if (!mounted) return;
    _ctrl.clear();
    setState(() => _isSet = true);
    _showToast(context.l10n.settingsApiKeySaved);
  }

  Future<void> _clear() async {
    await _secure.delete(_key);
    if (!mounted) return;
    setState(() => _isSet = false);
    _showToast(context.l10n.settingsApiKeyCleared);
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
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.capabilities.providerId,
                  style: typo.body.copyWith(color: colors.fg1),
                ),
              ),
              _StatusChip(isSet: _loading ? null : _isSet),
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
              FilledButton(
                onPressed: _loading ? null : _save,
                child: Text(context.l10n.settingsApiKeySave),
              ),
              const SizedBox(width: InkSpacing.xs),
              OutlinedButton(
                onPressed: (_loading || !_isSet) ? null : _clear,
                child: Text(context.l10n.settingsApiKeyClear),
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
