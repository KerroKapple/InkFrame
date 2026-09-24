// 项目卡（Screens 稿第 1 屏）：封面 16:10（圆角 4，1px outline 画在盒内）+ 右上 ⋯ 菜单 +
// 左下等宽徽标「N 画布」；下方 gap 8：名称（fg1）+ 3px + 11px 元信息（fg6）。
//
// 封面：仓库没有项目封面产物（cover_node_id 未接），用 thumbFill 纯色，不造渐变假图。
// 稿上的「· 8 镜」需要按项目聚合分镜数，没有现成的 count 查询，不画（PR #235）。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class StudioProjectCard extends StatelessWidget {
  const StudioProjectCard({
    super.key,
    required this.name,
    required this.metaLine,
    required this.canvasCount,
    required this.onTap,
    this.onOpenGallery,
    this.onOpenShowcase,
    this.onRename,
    this.onDelete,
    this.onManageCanvases,
    this.onExport,
  });

  final String name;
  final String metaLine;
  final int canvasCount;
  final VoidCallback onTap;
  final VoidCallback? onOpenGallery;
  final VoidCallback? onOpenShowcase;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onManageCanvases;
  final VoidCallback? onExport;

  bool get _hasMenu =>
      onOpenGallery != null ||
      onOpenShowcase != null ||
      onRename != null ||
      onDelete != null ||
      onManageCanvases != null ||
      onExport != null;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final Color badge = c.fg1.withValues(alpha: 0.75);
    return Semantics(
      button: true,
      label: name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.thumbFill,
                    border: Border.all(color: c.outline),
                    borderRadius: BorderRadius.circular(InkRadius.sm),
                  ),
                  child: Stack(
                    children: <Widget>[
                      if (_hasMenu)
                        Positioned(
                          right: 1,
                          top: 1,
                          // PopupMenuButton 的 InkResponse 要 Material 祖先；卡片本身不再是 Material 卡。
                          child: Material(
                            type: MaterialType.transparency,
                            child: _ProjectMenu(
                            onOpenGallery: onOpenGallery,
                            onOpenShowcase: onOpenShowcase,
                            onRename: onRename,
                            onDelete: onDelete,
                            onManageCanvases: onManageCanvases,
                            onExport: onExport,
                          ),
                          ),
                        ),
                      Positioned(
                        left: 7,
                        bottom: 7,
                        child: Text(l.studioCardCanvasBadge(canvasCount), style: t.monoSmall.copyWith(color: badge)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: InkSpacing.sm),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg1)),
              const SizedBox(height: InkSpacing.s3),
              Text(metaLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.meta.copyWith(color: c.fg6)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProjectAction { gallery, showcase, rename, canvases, export, delete }

/// 右上角 ⋯ 菜单（画廊 / 内置示例 / 重命名 / 管理画布 / 导出 / 删除）；菜单点击不冒泡到卡片 onTap。
class _ProjectMenu extends StatelessWidget {
  const _ProjectMenu({
    this.onOpenGallery,
    this.onOpenShowcase,
    this.onRename,
    this.onDelete,
    this.onManageCanvases,
    this.onExport,
  });

  final VoidCallback? onOpenGallery;
  final VoidCallback? onOpenShowcase;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onManageCanvases;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return PopupMenuButton<_ProjectAction>(
      tooltip: context.l10n.studioProjectMenuTooltip,
      color: c.surface2,
      padding: EdgeInsets.zero,
      onSelected: (_ProjectAction a) {
        switch (a) {
          case _ProjectAction.gallery:
            onOpenGallery?.call();
          case _ProjectAction.showcase:
            onOpenShowcase?.call();
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
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_ProjectAction>>[
        if (onOpenGallery != null)
          PopupMenuItem<_ProjectAction>(value: _ProjectAction.gallery, child: Text(context.l10n.galleryEntryLabel)),
        if (onOpenShowcase != null)
          PopupMenuItem<_ProjectAction>(value: _ProjectAction.showcase, child: Text(context.l10n.showcaseEntryLabel)),
        if (onRename != null)
          PopupMenuItem<_ProjectAction>(value: _ProjectAction.rename, child: Text(context.l10n.studioRenameProject)),
        if (onManageCanvases != null)
          PopupMenuItem<_ProjectAction>(value: _ProjectAction.canvases, child: Text(context.l10n.studioManageCanvases)),
        if (onExport != null)
          PopupMenuItem<_ProjectAction>(value: _ProjectAction.export, child: Text(context.l10n.studioExportProject)),
        if (onDelete != null)
          PopupMenuItem<_ProjectAction>(value: _ProjectAction.delete, child: Text(context.l10n.studioDeleteProject)),
      ],
      // 稿：右上 8px 处 11px「⋯」，rgba(232,232,232,0.8)。点击区放大到 24×24 好点。
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(child: Text('⋯', style: t.meta.copyWith(color: c.fg1.withValues(alpha: 0.8)))),
      ),
    );
  }
}
