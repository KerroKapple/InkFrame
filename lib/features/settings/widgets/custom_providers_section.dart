// CustomProvidersSection — 设置页自定义服务商编辑区（GAP-1）。
//
// 列表 + 5 字段表单对话框（校验=custom_provider_validation 纯函数,与文件
// 服务解析同一事实源）+ 删除确认。写仅落盘、重启生效——会话内发生过写
// 操作后常驻「重启后生效」提示条;不碰 registry 变异。
// 损坏文件:Store 拒写抛 LocalIOError → snackbar 提示,绝不覆盖。

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/custom_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/models/custom_provider_config.dart';
import '../../../core/models/custom_provider_validation.dart';
import '../../../core/models/provider_protocol_template.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/components/ink_card.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

/// 编辑区 fresh 读盘列表（不使用会话内快照;写后 invalidate 刷新）。
final customProvidersListProvider =
    FutureProvider.autoDispose<List<CustomProviderConfig>>(
  (ref) => ref.watch(customProviderStoreProvider).list(),
  name: 'customProvidersListProvider',
);

/// 会话内是否发生过写操作——驱动「重启后生效」常驻提示。
/// 非 autoDispose：离开设置页再回来提示仍在（重启前始终为真）。
final customProvidersDirtyProvider = StateProvider<bool>(
  (ref) => false,
  name: 'customProvidersDirtyProvider',
);

class CustomProvidersSection extends ConsumerWidget {
  const CustomProvidersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final listAsync = ref.watch(customProvidersListProvider);
    final dirty = ref.watch(customProvidersDirtyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsCustomProvidersSection,
          style: typo.title.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.xs),
        Text(
          context.l10n.settingsCustomProvidersHint,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        if (dirty) ...[
          const SizedBox(height: InkSpacing.sm),
          _RestartNotice(colors: colors, typo: typo),
        ],
        const SizedBox(height: InkSpacing.sm),
        listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // 列表读失败（损坏文件等）：呈现原因;增删入口仍在（Store 拒写兜底）。
          error: (e, _) => Text(
            l10nAsyncError(context, e),
            style: typo.body.copyWith(color: colors.danger),
          ),
          data: (configs) => configs.isEmpty
              ? Text(
                  context.l10n.settingsCustomProvidersEmpty,
                  style: typo.body.copyWith(color: colors.fg3),
                )
              : Column(
                  children: [
                    for (final c in configs) ...[
                      _ProviderRow(config: c),
                      const SizedBox(height: InkSpacing.xs),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: InkSpacing.sm),
        InkButton(
          label: context.l10n.settingsCustomProvidersAdd,
          variant: InkButtonVariant.secondary,
          icon: Icons.add,
          onPressed: () => unawaited(_openEditor(context, ref, existing: null)),
        ),
      ],
    );
  }
}

class _RestartNotice extends StatelessWidget {
  const _RestartNotice({required this.colors, required this.typo});
  final InkColors colors;
  final InkTypography typo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border.all(color: colors.warning),
        borderRadius: BorderRadius.circular(InkRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.sm),
        child: Text(
          context.l10n.settingsCustomProvidersRestartNotice,
          style: typo.caption.copyWith(color: colors.warning),
        ),
      ),
    );
  }
}

class _ProviderRow extends ConsumerWidget {
  const _ProviderRow({required this.config});
  final CustomProviderConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return InkCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.displayName,
                  style: typo.body.copyWith(color: colors.fg1),
                ),
                const SizedBox(height: InkSpacing.xs),
                Text(
                  '${config.providerId} · ${config.template} · ${config.baseUrl}',
                  style: typo.caption.copyWith(color: colors.fg3),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.settingsCustomProviderEditTitle,
            icon: Icon(Icons.edit_outlined,
                size: InkSpacing.md, color: colors.fg2),
            onPressed: () =>
                unawaited(_openEditor(context, ref, existing: config)),
          ),
          IconButton(
            tooltip: context.l10n.settingsCustomProviderDeleteTitle,
            icon: Icon(Icons.delete_outline,
                size: InkSpacing.md, color: colors.danger),
            onPressed: () => unawaited(_confirmDelete(context, ref, config)),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  CustomProviderConfig config,
) async {
  final l10n = context.l10n;
  final failedMsg = l10n.settingsCustomProviderSaveFailed;
  final store = ref.read(customProviderStoreProvider);
  final dirty = ref.read(customProvidersDirtyProvider.notifier);
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.settingsCustomProviderDeleteTitle),
      content: Text(l10n.settingsCustomProviderDeleteBody(config.displayName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.settingsCustomProviderDeleteConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await store.remove(config.id);
  } on InkError {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(failedMsg)));
    return;
  }
  dirty.state = true;
  // unmount 后 autoDispose 的 list provider 下次挂载天然重建,无需 invalidate。
  if (context.mounted) ref.invalidate(customProvidersListProvider);
}

Future<void> _openEditor(
  BuildContext context,
  WidgetRef ref, {
  required CustomProviderConfig? existing,
}) async {
  final l10n = context.l10n;
  final failedMsg = l10n.settingsCustomProviderSaveFailed;
  final store = ref.read(customProviderStoreProvider);
  final dirty = ref.read(customProvidersDirtyProvider.notifier);
  // 冲突校验基线：现存文件条目（编辑时剔除自身）+ 内置 providerId。
  final List<CustomProviderConfig> current;
  try {
    current = await store.list();
  } on InkError {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(failedMsg)));
    return;
  }
  final takenIds = {
    for (final c in current)
      if (c.id != existing?.id) c.id,
  };
  final reserved = {
    for (final caps in kAllProviderCapabilities) caps.providerId,
  };
  if (!context.mounted) return;
  final CustomProviderConfig? result = await showDialog<CustomProviderConfig>(
    context: context,
    builder: (ctx) => _EditorDialog(
      existing: existing,
      takenIds: takenIds,
      reservedProviderIds: reserved,
    ),
  );
  if (result == null) return;
  try {
    await store.upsert(result);
  } on InkError {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(failedMsg)));
    return;
  }
  dirty.state = true;
  if (context.mounted) ref.invalidate(customProvidersListProvider);
}

/// 5 字段表单：Save 时全量校验,错误内联呈现,通过才 pop 结果。
class _EditorDialog extends StatefulWidget {
  const _EditorDialog({
    required this.existing,
    required this.takenIds,
    required this.reservedProviderIds,
  });

  final CustomProviderConfig? existing;
  final Set<String> takenIds;
  final Set<String> reservedProviderIds;

  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  late final TextEditingController _id =
      TextEditingController(text: widget.existing?.id ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.displayName ?? '');
  late final TextEditingController _baseUrl =
      TextEditingController(text: widget.existing?.baseUrl ?? '');
  late final TextEditingController _modelId =
      TextEditingController(text: widget.existing?.modelId ?? '');
  late String _template = widget.existing?.template ??
      kProviderProtocolTemplates.keys.first;

  final Map<String, CustomProviderFieldError> _errors = {};

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _baseUrl.dispose();
    _modelId.dispose();
    super.dispose();
  }

  String _errorText(BuildContext context, CustomProviderFieldError e) =>
      switch (e) {
        CustomProviderFieldError.emptyField =>
          context.l10n.settingsCustomProviderErrorRequired,
        CustomProviderFieldError.invalidId =>
          context.l10n.settingsCustomProviderErrorInvalidId,
        CustomProviderFieldError.duplicateId =>
          context.l10n.settingsCustomProviderErrorDuplicateId,
        CustomProviderFieldError.reservedId =>
          context.l10n.settingsCustomProviderErrorReservedId,
        CustomProviderFieldError.unknownTemplate =>
          context.l10n.settingsCustomProviderErrorInvalidId,
        CustomProviderFieldError.invalidBaseUrl =>
          context.l10n.settingsCustomProviderErrorInvalidBaseUrl,
      };

  void _save() {
    final errors = <String, CustomProviderFieldError>{};
    final idErr = widget.existing != null
        ? null // 编辑态 id 锁定,免校验
        : validateId(
            _id.text,
            takenIds: widget.takenIds,
            reservedProviderIds: widget.reservedProviderIds,
          );
    if (idErr != null) errors['id'] = idErr;
    final nameErr = validateRequired(_name.text);
    if (nameErr != null) errors['name'] = nameErr;
    final tplErr = validateTemplate(_template);
    if (tplErr != null) errors['template'] = tplErr;
    final urlErr = validateBaseUrl(_baseUrl.text);
    if (urlErr != null) errors['base_url'] = urlErr;
    final modelErr = validateRequired(_modelId.text);
    if (modelErr != null) errors['model_id'] = modelErr;

    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }
    Navigator.of(context).pop(CustomProviderConfig(
      id: widget.existing?.id ?? _id.text.trim(),
      displayName: _name.text.trim(),
      template: _template,
      baseUrl: normalizeBaseUrl(_baseUrl.text),
      modelId: _modelId.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l10n = context.l10n;

    Widget field({
      required String label,
      required TextEditingController controller,
      required String errorKey,
      bool enabled = true,
      String? hint,
    }) {
      final err = _errors[errorKey];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: typo.caption.copyWith(color: colors.fg3)),
          const SizedBox(height: InkSpacing.xs),
          InkInput(controller: controller, enabled: enabled, hintText: hint),
          if (err != null) ...[
            const SizedBox(height: InkSpacing.xs),
            Text(
              _errorText(context, err),
              style: typo.caption.copyWith(color: colors.danger),
            ),
          ],
          const SizedBox(height: InkSpacing.sm),
        ],
      );
    }

    return AlertDialog(
      title: Text(widget.existing == null
          ? l10n.settingsCustomProviderAddTitle
          : l10n.settingsCustomProviderEditTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field(
                label: l10n.settingsCustomProviderFieldId,
                controller: _id,
                errorKey: 'id',
                enabled: widget.existing == null,
                hint: 'my-openrouter',
              ),
              field(
                label: l10n.settingsCustomProviderFieldDisplayName,
                controller: _name,
                errorKey: 'name',
              ),
              Text(
                l10n.settingsCustomProviderFieldTemplate,
                style: typo.caption.copyWith(color: colors.fg3),
              ),
              const SizedBox(height: InkSpacing.xs),
              DropdownButton<String>(
                value: _template,
                isExpanded: true,
                items: [
                  for (final t in kProviderProtocolTemplates.keys)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) =>
                    setState(() => _template = v ?? _template),
              ),
              const SizedBox(height: InkSpacing.sm),
              field(
                label: l10n.settingsCustomProviderFieldBaseUrl,
                controller: _baseUrl,
                errorKey: 'base_url',
                hint: 'https://openrouter.ai/api/v1',
              ),
              field(
                label: l10n.settingsCustomProviderFieldModelId,
                controller: _modelId,
                errorKey: 'model_id',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _save,
          child: Text(l10n.settingsCustomProviderSave),
        ),
      ],
    );
  }
}
