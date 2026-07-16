// StoragePathSection — 显示嵌入 Postgres 数据目录。
//
// 该路径由 DefaultAppPaths 在启动时锁定（<root>/database，root=平台惯例路径 DIR-1）。当前 sprint
// 仅展示 + 复制；切换需要重启迁移流程，留给后续 sprint。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/paths.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/components/ink_card.dart';
import '../../../theme/tokens.dart';

class StoragePathSection extends ConsumerWidget {
  const StoragePathSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(appPathsProvider);
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final dbPath = paths.database.path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsStorageSection,
          style: typo.title.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.xs),
        Text(
          context.l10n.settingsStorageReadOnlyHint,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.sm),
        InkCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.settingsStorageDatabasePathLabel,
                      style: typo.caption.copyWith(color: colors.fg3),
                    ),
                    const SizedBox(height: InkSpacing.xs),
                    SelectableText(
                      dbPath,
                      style: typo.body.copyWith(color: colors.fg1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: InkSpacing.sm),
              InkButton(
                label: context.l10n.settingsStorageCopyPath,
                variant: InkButtonVariant.secondary,
                icon: Icons.copy_outlined,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: dbPath));
                  if (!context.mounted) return;
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.settingsStoragePathCopied),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
