// ProjectCard：16:10 占位静帧 + 衬线标题 + mono 元数据。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_noir_card.dart';
import '../../../theme/tokens.dart';

class StudioProjectCard extends StatelessWidget {
  const StudioProjectCard({
    super.key,
    required this.name,
    required this.metaLine,
    required this.onTap,
    this.onOpenGallery,
    this.onRename,
    this.onDelete,
    this.onManageCanvases,
    this.onExport,
  });

  final String name;
  final String metaLine;
  final VoidCallback onTap;
  final VoidCallback? onOpenGallery;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onManageCanvases;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return InkNoirCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            children: <Widget>[
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface3,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(InkRadius.lg),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        colors.surface3,
                        colors.surface1,
                      ],
                    ),
                  ),
                ),
              ),
              if (onOpenGallery != null ||
                  onRename != null ||
                  onDelete != null ||
                  onManageCanvases != null ||
                  onExport != null)
                Positioned(
                  top: InkSpacing.xs,
                  right: InkSpacing.xs,
                  child: _ProjectMenu(
                    onOpenGallery: onOpenGallery,
                    onRename: onRename,
                    onDelete: onDelete,
                    onManageCanvases: onManageCanvases,
                    onExport: onExport,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              InkSpacing.md,
              InkSpacing.s14,
              InkSpacing.md,
              InkSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: typo.headline.copyWith(color: colors.fg1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: InkSpacing.xs),
                Text(
                  metaLine,
                  style: typo.caption.copyWith(
                    color: colors.fg3,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProjectAction { gallery, rename, canvases, export, delete }

/// 项目卡右上角操作菜单（画廊 / 重命名 / 管理画布 / 导出 / 删除）；菜单点击不冒泡到卡片 onTap。
class _ProjectMenu extends StatelessWidget {
  const _ProjectMenu({
    this.onOpenGallery,
    this.onRename,
    this.onDelete,
    this.onManageCanvases,
    this.onExport,
  });

  final VoidCallback? onOpenGallery;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onManageCanvases;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return PopupMenuButton<_ProjectAction>(
      icon: Icon(Icons.more_vert, size: 18, color: colors.fg2),
      tooltip: context.l10n.studioProjectMenuTooltip,
      color: colors.surface2,
      onSelected: (a) {
        switch (a) {
          case _ProjectAction.gallery:
            onOpenGallery?.call();
          case _ProjectAction.rename:
            onRename?.call();
          case _ProjectAction.canvases:
            onManageCanvases?.call();
          case _ProjectAction.export:
            onExport?.call();
          case _ProjectAction.delete:
            onDelete?.call();
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_ProjectAction>>[
        if (onOpenGallery != null)
          PopupMenuItem<_ProjectAction>(
            value: _ProjectAction.gallery,
            child: Text(context.l10n.galleryEntryLabel),
          ),
        if (onRename != null)
          PopupMenuItem<_ProjectAction>(
            value: _ProjectAction.rename,
            child: Text(context.l10n.studioRenameProject),
          ),
        if (onManageCanvases != null)
          PopupMenuItem<_ProjectAction>(
            value: _ProjectAction.canvases,
            child: Text(context.l10n.studioManageCanvases),
          ),
        if (onExport != null)
          PopupMenuItem<_ProjectAction>(
            value: _ProjectAction.export,
            child: Text(context.l10n.studioExportProject),
          ),
        if (onDelete != null)
          PopupMenuItem<_ProjectAction>(
            value: _ProjectAction.delete,
            child: Text(context.l10n.studioDeleteProject),
          ),
      ],
    );
  }
}
