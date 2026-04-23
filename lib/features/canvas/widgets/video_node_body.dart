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
import '../../../l10n/l10n_x.dart';
import '../../../services/file_resolver_service.dart';
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
      );
    }

    return const _VideoPlayOverlay();
  }
}

/// 有 thumbnail_url 的分支：解析相对路径 → 存在则 Image.file + play overlay，
/// 缺失 / PathSecurityError → broken 占位。
class _ThumbnailOrBroken extends StatelessWidget {
  const _ThumbnailOrBroken({
    required this.resolver,
    required this.projectId,
    required this.canvasId,
    required this.thumbnailUrl,
  });

  final FileResolverService resolver;
  final String projectId;
  final String canvasId;
  final String thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    File file;
    try {
      file = resolver.resolve(
        projectId: projectId,
        canvasId: canvasId,
        relativePath: thumbnailUrl,
      );
    } on PathSecurityError {
      return _VideoPlaceholder(
        icon: Icons.broken_image_outlined,
        text: context.l10n.resultNodeImageMissing,
      );
    }

    if (!file.existsSync()) {
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
