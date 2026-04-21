// NodeCard：画布上的单个节点卡片。
//
// 负责渲染 + 选中态视觉 + 拖拽手势。S4：result 节点若 typeConfig.image_url 存在
// 渲染 Image.file（通过 FileResolverService 解析相对路径），尚无则显示
// "等待生成" 占位；文件缺失（人为删除 / 落盘失败）时兜底到 "图像文件缺失" 文案。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../l10n/l10n_x.dart';
import '../../../services/file_resolver_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';

class NodeCard extends ConsumerWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onPanUpdate,
  });

  final CanvasNode node;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset delta) onPanUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;

    return GestureDetector(
      onTap: onTap,
      onPanUpdate: (d) => onPanUpdate(d.delta),
      child: Container(
        width: node.size.width,
        height: node.size.height,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(InkRadius.lg),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? InkShadow.elevated : InkShadow.card,
        ),
        padding: const EdgeInsets.all(InkSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconFor(node.type),
                  size: 16,
                  color: colors.fg3,
                ),
                const SizedBox(width: InkSpacing.xs),
                Text(
                  _typeLabel(context, node.type),
                  style: typo.caption.copyWith(color: colors.fg3),
                ),
              ],
            ),
            const SizedBox(height: InkSpacing.sm),
            Expanded(
              child: _NodeBody(
                node: node,
                resolver: ref.watch(fileResolverServiceProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(CanvasNodeType type) => switch (type) {
        CanvasNodeType.image => Icons.image_outlined,
        CanvasNodeType.text => Icons.text_fields,
        CanvasNodeType.video => Icons.videocam_outlined,
        CanvasNodeType.shot => Icons.movie_outlined,
      };

  static String _typeLabel(BuildContext context, CanvasNodeType type) =>
      switch (type) {
        CanvasNodeType.image => context.l10n.canvasNodeImageType,
        _ => type.name,
      };
}

class _NodeBody extends StatelessWidget {
  const _NodeBody({required this.node, required this.resolver});

  final CanvasNode node;
  final FileResolverService resolver;

  @override
  Widget build(BuildContext context) {
    if (node.role == NodeRole.result) {
      return _ResultBody(node: node, resolver: resolver);
    }
    return _ConfigBody(node: node);
  }
}

class _ConfigBody extends StatelessWidget {
  const _ConfigBody({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        node.label.isEmpty ? (node.typeConfig['prompt'] as String? ?? '') : node.label,
        style: typo.body.copyWith(color: colors.fg1),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.node, required this.resolver});

  final CanvasNode node;
  final FileResolverService resolver;

  @override
  Widget build(BuildContext context) {
    final url = node.imageUrl;
    if (url == null) {
      return _Placeholder(
        icon: Icons.hourglass_empty_outlined,
        text: context.l10n.resultNodePending,
      );
    }
    // 单测允许 projectId/canvasId 为空 → 退化为占位（避免 PathSecurityError）。
    if (node.projectId == null || node.canvasId == null) {
      return _Placeholder(
        icon: Icons.image_outlined,
        text: url,
      );
    }

    File file;
    try {
      file = resolver.resolve(
        projectId: node.projectId!,
        canvasId: node.canvasId!,
        relativePath: url,
      );
    } on PathSecurityError {
      return _Placeholder(
        icon: Icons.broken_image_outlined,
        text: context.l10n.resultNodeImageMissing,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(InkRadius.md),
      child: Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _Placeholder(
          icon: Icons.broken_image_outlined,
          text: context.l10n.resultNodeImageMissing,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text});
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
