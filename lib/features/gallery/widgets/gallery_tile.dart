// GalleryTile：稿的网格单元——16:9 图区（圆角 3、1px 描边画在盒内；在当前线上用琥珀）+
// 左下 ▶ 时长（视频）+ 右上 14×14 琥珀勾（选中）+ 左上「当前线」徽标 + 下方「序号 名称」。
//
// 图片经 fileResolverServiceProvider 解析后 Image.file 渲染（LB-23：按 tile 上限缩略解码）；
// 视频画已落库缩略图（thumbnail_url），没有就是纯色占位。文件缺失 → broken 图标占位。
// 交互全交给上层（onTap / onPreview）：tile 自己不碰选中集与 lightbox。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../canvas/widgets/node_card.dart' show nodeTypeLabel;
import '../../canvas/models/canvas_node.dart';
import '../models/gallery_item.dart';
import '../util/gallery_meta.dart';
import '../util/gallery_time.dart';
import 'gallery_actions.dart';

class GalleryTile extends ConsumerWidget {
  const GalleryTile({
    super.key,
    required this.projectId,
    required this.item,
    required this.meta,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onPreview,
  });

  final String projectId;
  final GalleryItem item;
  final GalleryItemMeta meta;
  /// 网格里的序号（1 起），稿上是三位等宽「001」。
  final int index;
  final bool selected;
  /// [toggle] = 按住 ⌘/Ctrl 点。
  final void Function(bool toggle) onTap;
  final VoidCallback onPreview;

  /// 说明行高：11px × 1.45。
  static const double captionHeight = 16;

  /// 缩略解码上限（逻辑 px，再乘 dpr）：特大档 3 列时单格 ≈ 340。
  static const int _decodeWidth = 340;

  static bool _isMultiSelectModifier() {
    final Set<LogicalKeyboardKey> pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final String name = meta.label.isNotEmpty
        ? meta.label
        : nodeTypeLabel(context, item.kind == GalleryItemKind.video ? CanvasNodeType.video : CanvasNodeType.image);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(_isMultiSelectModifier()),
          onDoubleTap: onPreview,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: c.thumbFill,
                    border: Border.all(color: meta.onNarrativeChain ? c.accent : c.outline),
                    borderRadius: BorderRadius.circular(InkRadius.s3),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _thumb(context, ref, c),
                      if (item.kind == GalleryItemKind.video && item.durationMs != null)
                        Positioned(
                          left: 7,
                          bottom: 5,
                          child: Row(
                            children: <Widget>[
                              Text('▶', style: t.monoSmall.copyWith(color: c.fg1.withValues(alpha: 0.85))),
                              const SizedBox(width: 5),
                              Text(galleryFormatDuration(item.durationMs!),
                                  style: t.monoSmall.copyWith(color: c.fg1.withValues(alpha: 0.85))),
                            ],
                          ),
                        ),
                      if (selected)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: Container(
                            width: 14,
                            height: 14,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(InkRadius.s3),
                            ),
                            child: Text('✓', style: t.micro.copyWith(color: c.onAccent, height: 1.0)),
                          ),
                        ),
                      if (meta.onNarrativeChain)
                        Positioned(
                          left: 5,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s6, vertical: InkSpacing.s2),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(InkRadius.xs),
                            ),
                            child: Text(l.galleryMarkCurrentLine, style: t.micro.copyWith(color: c.onAccent, height: 1.0)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: InkSpacing.s6),
              SizedBox(
                height: captionHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(index.toString().padLeft(3, '0'), style: t.monoSmall.copyWith(color: c.fg6)),
                    const SizedBox(width: InkSpacing.s6),
                    Expanded(
                      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: t.meta.copyWith(color: c.fg4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context, WidgetRef ref, InkColors c) {
    final String? rel = item.kind == GalleryItemKind.video ? item.thumbnailRelativePath : item.relativePath;
    if (rel == null) return _placeholder(c, Icons.videocam_outlined);
    final File? file = galleryResolveFile(ref, projectId: projectId, canvasId: item.canvasId, relativePath: rel);
    if (file == null) return _placeholder(c, Icons.broken_image_outlined);
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: (_decodeWidth * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (_, _, _) => _placeholder(c, Icons.broken_image_outlined),
    );
  }

  Widget _placeholder(InkColors c, IconData icon) => Center(child: Icon(icon, color: c.fg5, size: 20));
}
