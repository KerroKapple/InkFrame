// GalleryTile：画廊网格单元——图片缩略 / 视频缩略图+播放（GA-1/2）+ 类型/画布名 caption。
//
// 图片经 fileResolverServiceProvider 解析后 Image.file 渲染（同 BatchResultsGrid），
// 点击开图片 lightbox；视频有已落库缩略图（thumbnail_url）则渲染缩略图 +
// 播放/时长角标，点击经 existsSync 守卫开 video_lightbox，文件缺失显 broken 态。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../canvas/widgets/video_lightbox.dart';
import '../models/gallery_item.dart';
import 'gallery_image_lightbox.dart';

class GalleryTile extends ConsumerStatefulWidget {
  const GalleryTile({super.key, required this.projectId, required this.item});

  final String projectId;
  final GalleryItem item;

  @override
  ConsumerState<GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends ConsumerState<GalleryTile> {
  /// 点击时视频文件缺失 → broken 态（预览区替换为 broken 图标）。
  bool _videoBroken = false;

  GalleryItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
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
            Expanded(child: _preview(context)),
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

  /// canvas 双参根解析；非法路径 → null（渲染 broken 占位）。
  File? _resolve(String relativePath) {
    try {
      return ref.read(fileResolverServiceProvider).resolve(
            projectId: widget.projectId,
            canvasId: item.canvasId,
            relativePath: relativePath,
          );
    } on PathSecurityError {
      return null;
    }
  }

  Widget _preview(BuildContext context) {
    final colors = context.inkColors;
    if (item.kind == GalleryItemKind.video) {
      return _videoPreview(context, colors);
    }
    final file = _resolve(item.relativePath);
    if (file == null) {
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

  Widget _videoPreview(BuildContext context, InkColors colors) {
    if (_videoBroken) {
      return _iconPlaceholder(colors, Icons.broken_image_outlined);
    }
    final thumbRel = item.thumbnailRelativePath;
    final thumb = thumbRel == null ? null : _resolve(thumbRel);
    return GestureDetector(
      onTap: _playVideo,
      child: thumb == null
          ? _videoPlaceholder(context, colors)
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.file(
                  thumb,
                  fit: BoxFit.cover,
                  // 缩略图缺失/损坏 → 回退首切片占位（仍可点击播放）。
                  errorBuilder: (_, _, _) =>
                      _videoPlaceholder(context, colors),
                ),
                Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: colors.fg1,
                    size: 36,
                  ),
                ),
                if (item.durationMs != null)
                  Positioned(
                    right: InkSpacing.xs,
                    bottom: InkSpacing.xs,
                    child: _durationBadge(context, colors, item.durationMs!),
                  ),
              ],
            ),
    );
  }

  /// GA-2：existsSync 守卫 → video_lightbox（绝对路径一次性使用，不落状态）。
  Future<void> _playVideo() async {
    final file = _resolve(item.relativePath);
    if (file == null || !file.existsSync()) {
      setState(() => _videoBroken = true);
      return;
    }
    if (!mounted) return;
    await showVideoLightbox(context, videoPath: file.path);
  }

  Widget _durationBadge(BuildContext context, InkColors colors, int ms) {
    final typo = context.inkTypography;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.xs),
        child: Text(
          _fmtDuration(ms),
          style: typo.caption.copyWith(color: colors.fg1),
        ),
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
