// GalleryTile：画廊网格单元——图片缩略 / 视频占位（图标+时长）+ 类型/画布名 caption。
//
// 图片经 fileResolverServiceProvider 解析后 Image.file 渲染（同 BatchResultsGrid），
// 点击开图片 lightbox；视频首切片不接缩略图/播放（见 features/gallery/README.md）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/gallery_item.dart';
import 'gallery_image_lightbox.dart';

class GalleryTile extends ConsumerWidget {
  const GalleryTile({super.key, required this.projectId, required this.item});

  final String projectId;
  final GalleryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(InkRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: _preview(context, ref)),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InkSpacing.sm,
                vertical: InkSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    switch (item.kind) {
                      GalleryItemKind.image => context.l10n.galleryKindImage,
                      GalleryItemKind.video => context.l10n.galleryKindVideo,
                    },
                    style: typo.caption.copyWith(color: colors.fg2),
                  ),
                  const SizedBox(width: InkSpacing.sm),
                  Expanded(
                    child: Text(
                      item.canvasName,
                      style: typo.caption.copyWith(color: colors.fg3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    if (item.kind == GalleryItemKind.video) {
      return _videoPlaceholder(context, colors);
    }
    final File file;
    try {
      file = ref
          .read(fileResolverServiceProvider)
          .resolve(
            projectId: projectId,
            canvasId: item.canvasId,
            relativePath: item.relativePath,
          );
    } on PathSecurityError {
      return _iconPlaceholder(colors, Icons.broken_image_outlined);
    }
    return GestureDetector(
      onTap: () => showGalleryImageLightbox(context, imageFile: file),
      child: Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _iconPlaceholder(colors, Icons.broken_image_outlined),
      ),
    );
  }

  Widget _videoPlaceholder(BuildContext context, InkColors colors) {
    final typo = context.inkTypography;
    final durationMs = item.durationMs;
    return ColoredBox(
      color: colors.surface3,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.videocam_outlined, color: colors.fg3, size: 28),
            if (durationMs != null) ...<Widget>[
              const SizedBox(height: InkSpacing.xs),
              Text(
                _fmtDuration(durationMs),
                style: typo.caption.copyWith(color: colors.fg3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconPlaceholder(InkColors colors, IconData icon) =>
      Center(child: Icon(icon, color: colors.fg3, size: 20));
}

String _fmtDuration(int ms) {
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
