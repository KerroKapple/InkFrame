// NodeCard：画布上的单个节点卡片。
//
// 负责渲染 + 选中态视觉 + 拖拽手势。S4：result 节点若 typeConfig.image_url 存在
// 渲染 Image.file（通过 FileResolverService 解析相对路径），尚无则显示
// "等待生成" 占位；文件缺失（人为删除 / 落盘失败）时兜底到 "图像文件缺失" 文案。
//
// 拖拽（HI-13）：位移累积在本卡片局部状态（Transform.translate），每帧只重建
// 自身；onPanEnd 把累计位移一次性回调 onDragEnd，由上层提交 controller。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import 'video_node_body.dart';

class NodeCard extends ConsumerStatefulWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onDragEnd,
    this.onStartLink,
    this.onDelete,
    this.isLinkSource = false,
    this.isLinkCandidate = false,
  });

  final CanvasNode node;
  final bool selected;
  final VoidCallback onTap;

  /// 拖拽结束时回调一次累计位移（落点提交）；拖拽中不触发。
  final void Function(Offset totalDelta) onDragEnd;

  /// 选中后点击该回调 → 进入连线模式。null 代表不可发起连线（例如 result 节点）。
  final VoidCallback? onStartLink;

  /// 选中后点击右上角 X → 删除本节点（含级联软删 edges）。null 代表禁用。
  final VoidCallback? onDelete;

  /// 本节点是否为当前连线模式的起点（UI 高亮）。
  final bool isLinkSource;

  /// 连线模式下此节点是否为合法目标（非起点 → 高亮为点击候选）。
  final bool isLinkCandidate;

  @override
  ConsumerState<NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends ConsumerState<NodeCard> {
  bool _dragging = false;

  /// 拖拽中的累计位移——只重建本卡片，不推全画布 state。
  Offset _dragOffset = Offset.zero;

  void _endDrag({required bool commit}) {
    final total = _dragOffset;
    setState(() {
      _dragging = false;
      _dragOffset = Offset.zero;
    });
    if (commit && total != Offset.zero) {
      widget.onDragEnd(total);
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final colors = context.inkColors;
    final typo = context.inkTypography;

    final Color borderColor;
    final double borderWidth;
    if (widget.isLinkSource) {
      borderColor = colors.brand;
      borderWidth = 2.5;
    } else if (widget.isLinkCandidate) {
      borderColor = colors.brand;
      borderWidth = 2.0;
    } else if (widget.selected) {
      borderColor = colors.accent;
      borderWidth = 2.0;
    } else {
      borderColor = colors.border;
      borderWidth = 1.0;
    }

    final elevated = _dragging || widget.selected || widget.isLinkSource;
    final cursor = _dragging
        ? SystemMouseCursors.grabbing
        : SystemMouseCursors.grab;

    return Transform.translate(
      offset: _dragOffset,
      child: MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (_) => setState(() {
          _dragging = true;
          _dragOffset = Offset.zero;
        }),
        onPanUpdate: (d) => setState(() => _dragOffset += d.delta),
        onPanEnd: (_) => _endDrag(commit: true),
        onPanCancel: () => _endDrag(commit: false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedScale(
              scale: _dragging ? 1.02 : 1.0,
              duration: InkMotion.fast,
              child: AnimatedContainer(
                duration: InkMotion.fast,
                width: node.size.width,
                height: node.size.height,
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(InkRadius.lg),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: elevated ? InkShadow.elevated : InkShadow.card,
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
            ),
            if (widget.selected &&
                widget.onStartLink != null &&
                !widget.isLinkSource)
              Positioned(
                right: -8,
                top: -8,
                child: _LinkAnchor(onPressed: widget.onStartLink!),
              ),
            if (widget.selected &&
                widget.onDelete != null &&
                !widget.isLinkSource)
              Positioned(
                left: -8,
                top: -8,
                child: _DeleteAnchor(onPressed: widget.onDelete!),
              ),
          ],
        ),
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

class _LinkAnchor extends StatelessWidget {
  const _LinkAnchor({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Tooltip(
      message: context.l10n.linkModeStart,
      child: Material(
        color: colors.surface1,
        shape: CircleBorder(side: BorderSide(color: colors.brand, width: 1.5)),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(Icons.link, size: 14, color: colors.brand),
          ),
        ),
      ),
    );
  }
}

class _DeleteAnchor extends StatelessWidget {
  const _DeleteAnchor({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Tooltip(
      message: context.l10n.nodeDelete,
      child: Material(
        color: colors.surface1,
        shape: CircleBorder(side: BorderSide(color: colors.danger, width: 1.5)),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(Icons.close, size: 14, color: colors.danger),
          ),
        ),
      ),
    );
  }
}

class _NodeBody extends StatelessWidget {
  const _NodeBody({required this.node, required this.resolver});

  final CanvasNode node;
  final FileResolverService resolver;

  @override
  Widget build(BuildContext context) {
    if (node.role == NodeRole.result) {
      if (node.type == CanvasNodeType.video) {
        return VideoNodeBody(node: node);
      }
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
        // ME-26：按卡片宽度解码，避免原图全尺寸进 image cache。
        cacheWidth: (node.size.width * MediaQuery.devicePixelRatioOf(context))
            .round(),
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
