// 画廊图片放大预览：轻量 Dialog lightbox（视频版见 canvas/widgets/video_lightbox.dart）。
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

Future<void> showGalleryImageLightbox(
  BuildContext context, {
  required File imageFile,
}) => showDialog<void>(
  context: context,
  barrierColor: context.inkColors.scrim,
  builder: (_) => Dialog(
    insetPadding: const EdgeInsets.all(InkSpacing.xl),
    backgroundColor: Colors.transparent,
    child: GalleryImageLightboxContent(imageFile: imageFile),
  ),
);

class GalleryImageLightboxContent extends StatelessWidget {
  const GalleryImageLightboxContent({super.key, required this.imageFile});

  final File imageFile;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: InteractiveViewer(
            child: Center(
              child: Image.file(
                imageFile,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.broken_image_outlined,
                  color: colors.fg3,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: InkSpacing.sm,
          right: InkSpacing.sm,
          child: IconButton(
            tooltip: context.l10n.lightboxClose,
            icon: Icon(Icons.close, color: colors.fg1),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
