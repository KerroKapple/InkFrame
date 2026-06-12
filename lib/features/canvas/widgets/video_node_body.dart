// VideoNodeBody：video 类型 result 节点在 NodeCard 里的展示主体。
//
// 状态机：
//   - videoUrl 为空 → hourglass 占位（"等待生成"）
//   - projectId / canvasId 任一为空 → 简化为 play_circle 占位（单测兜底）
//   - thumbnailUrl 存在 → Image.file 缩略图 + 右下角 play 浮标；
//     文件缺失 / PathSecurityError → broken_image 占位
//   - 只有 videoUrl 没 thumbnailUrl → surface3 底色 + play_circle 居中

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';

class VideoNodeBody extends ConsumerWidget {
  const VideoNodeBody({super.key, required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoUrl = node.videoUrl;
    if (videoUrl == null) {
      return _VideoPlaceholder(
        icon: Icons.hourglass_empty_outlined,
        text: context.l10n.resultNodePending,
      );
    }

    // 单测兜底：projectId / canvasId 缺失 → 直接显示 play_circle。
    final projectId = node.projectId;
    final canvasId = node.canvasId;
    if (projectId == null || canvasId == null) {
      return const _VideoPlayOverlay();
    }

    final resolver = ref.watch(fileResolverServiceProvider);
    final thumbnailUrl = node.thumbnailUrl;

    if (thumbnailUrl != null) {
      return _ThumbnailOrBroken(
        resolver: resolver,
        projectId: projectId,
        canvasId: canvasId,
        thumbnailUrl: thumbnailUrl,
        decodeWidth: node.size.width,
      );
    }

    return const _VideoPlayOverlay();
  }
}

/// 有 thumbnail_url 的分支：解析相对路径 → 存在则 Image.file + play overlay，
/// 缺失 / PathSecurityError → broken 占位。
///
/// ME-25：解析 + existsSync 只在路径变化时做一次并缓存，不在每次 build 重复
/// 同步 IO（Image.file 自身的解码失败仍由 errorBuilder 兜底）。
class _ThumbnailOrBroken extends StatefulWidget {
  const _ThumbnailOrBroken({
    required this.resolver,
    required this.projectId,
    required this.canvasId,
    required this.thumbnailUrl,
    required this.decodeWidth,
  });

  final FileResolverService resolver;
  final String projectId;
  final String canvasId;
  final String thumbnailUrl;

  /// 逻辑像素宽（节点卡片宽），供 cacheWidth 计算。
  final double decodeWidth;

  @override
  State<_ThumbnailOrBroken> createState() => _ThumbnailOrBrokenState();
}

class _ThumbnailOrBrokenState extends State<_ThumbnailOrBroken> {
  File? _file; // null = 路径非法或文件缺失 → broken 占位

  @override
  void initState() {
    super.initState();
    _resolveOnce();
  }

  @override
  void didUpdateWidget(covariant _ThumbnailOrBroken old) {
    super.didUpdateWidget(old);
    if (old.thumbnailUrl != widget.thumbnailUrl ||
        old.projectId != widget.projectId ||
        old.canvasId != widget.canvasId ||
        old.resolver != widget.resolver) {
      _resolveOnce();
    }
  }

  void _resolveOnce() {
    try {
      final f = widget.resolver.resolve(
        projectId: widget.projectId,
        canvasId: widget.canvasId,
        relativePath: widget.thumbnailUrl,
      );
      _file = f.existsSync() ? f : null;
    } on PathSecurityError {
      _file = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) {
      return _VideoPlaceholder(
        icon: Icons.broken_image_outlined,
        text: context.l10n.resultNodeImageMissing,
      );
    }

    final colors = context.inkColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(InkRadius.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            file,
            fit: BoxFit.cover,
            // ME-26：按卡片宽度解码，避免原图全尺寸进 image cache。
            cacheWidth:
                (widget.decodeWidth * MediaQuery.devicePixelRatioOf(context))
                    .round(),
            errorBuilder: (_, _, _) => _VideoPlaceholder(
              icon: Icons.broken_image_outlined,
              text: context.l10n.resultNodeImageMissing,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Icon(
              Icons.play_circle_outline,
              size: 40,
              color: colors.fg1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 有 videoUrl 但未抽帧缩略：展示 surface3 底色 + 居中 play icon。
class _VideoPlayOverlay extends StatelessWidget {
  const _VideoPlayOverlay();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: BorderRadius.circular(InkRadius.md),
      ),
      child: Icon(
        Icons.play_circle_outline,
        size: 40,
        color: colors.fg3,
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: BorderRadius.circular(InkRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.fg3),
          const SizedBox(height: InkSpacing.xs),
          Text(
            text,
            style: typo.caption.copyWith(color: colors.fg3),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
