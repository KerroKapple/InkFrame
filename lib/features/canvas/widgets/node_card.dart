// NodeCard：画布上的单个节点卡片。
//
// 负责渲染 + 选中态视觉 + 拖拽手势。S4：result 节点若 typeConfig.image_url 存在
// 渲染 Image.file（通过 FileResolverService 解析相对路径），尚无则显示
// "等待生成" 占位；文件缺失（人为删除 / 落盘失败）时兜底到 "图像文件缺失" 文案。
//
// 拖拽（HI-13）：位移累积在本卡片局部状态（Transform.translate），每帧只重建
// 自身；onPanEnd 把累计位移一次性回调 onDragEnd，由上层提交 controller。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/canvas_style.dart';
import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../generation/models/job_state.dart';
import '../models/canvas_node.dart';
import '../providers/node_active_job.dart';
import '../providers/node_drag_delta.dart';
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

  /// 拖拽期捕获的广播口——dispose 兜底清残留用（dispose 后 ref 不可用）。
  StateController<NodeDragDelta?>? _dragBroadcast;

  @override
  void dispose() {
    // 拖拽中被删（如 Delete 快捷键）不会走 onPanEnd，广播会残留脏值；
    // 微任务延后清理避开 widget 树锁，容器已销毁时静默放弃。
    final broadcast = _dragBroadcast;
    final nodeId = widget.node.id;
    if (_dragging && broadcast != null) {
      scheduleMicrotask(() {
        try {
          if (broadcast.state?.nodeId == nodeId) broadcast.state = null;
        } on StateError {
          // ProviderContainer 已 dispose（应用退出/测试收尾）——无需清理。
        }
      });
    }
    super.dispose();
  }

  void _endDrag({required bool commit}) {
    final total = _dragOffset;
    setState(() {
      _dragging = false;
      _dragOffset = Offset.zero;
    });
    // 先清广播再提交落点：连线层切回 controller 座标，避免一帧双重位移。
    ref.read(nodeDragDeltaProvider.notifier).state = null;
    if (commit && total != Offset.zero) {
      widget.onDragEnd(total);
    }
  }

  void _broadcastDrag() {
    final broadcast = ref.read(nodeDragDeltaProvider.notifier);
    _dragBroadcast = broadcast;
    broadcast.state = (nodeId: widget.node.id, delta: _dragOffset);
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final colors = context.inkColors;
    // 节点级实时进度：该节点当前活跃 job（无则 null），驱动卡片底部进度条。
    final activeJob = ref.watch(nodeActiveJobProvider(node.id));

    // 有全出血媒体的卡片默认态免边框——画面自身即轮廓（CineFlow 式）；
    // 选中/连线高亮态仍描边。
    final hasMedia = node.role == NodeRole.result &&
        (node.imageUrl != null || node.thumbnailUrl != null);
    final Border? border;
    if (widget.isLinkSource) {
      border = Border.all(color: colors.brand, width: 2.5);
    } else if (widget.isLinkCandidate) {
      border = Border.all(color: colors.brand, width: 2.0);
    } else if (widget.selected) {
      border = Border.all(color: colors.accent, width: 2.0);
    } else if (hasMedia) {
      border = null;
    } else {
      border = Border.all(color: colors.border);
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
        onPanStart: (_) {
          setState(() {
            _dragging = true;
            _dragOffset = Offset.zero;
          });
          _broadcastDrag();
        },
        onPanUpdate: (d) {
          setState(() => _dragOffset += d.delta);
          _broadcastDrag();
        },
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
                  color: ref.watch(canvasStyleControllerProvider).cardColor ??
                      colors.surface2,
                  borderRadius: BorderRadius.circular(InkRadius.lg),
                  border: border,
                  boxShadow: elevated ? InkShadow.elevated : InkShadow.card,
                ),
                // 简约化（CineFlow/Krea 式）：预览即主体、全出血，
                // 标题悬浮在预览底部（渐变 scrim 垫底），不占独立空间；
                // 参数留给选中态 Inspector。
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(InkRadius.lg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NodeBody(
                        node: node,
                        resolver: ref.watch(fileResolverServiceProvider),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _FloatingTitle(node: node),
                      ),
                    ],
                  ),
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
            // 生成进行中：卡片底缘一条实时进度条（悬浮标题之上）。
            if (activeJob != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _NodeProgressBar(job: activeJob),
              ),
          ],
        ),
      ),
      ),
    );
  }

}

/// 悬浮标题：类型图标 + 标题（空标题回退类型名）悬浮在预览底缘，
/// 下垫 overlay 渐变 scrim 保证任意画面上可读。卡片唯一的默认态文字。
class _FloatingTitle extends StatelessWidget {
  const _FloatingTitle({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.sm,
        InkSpacing.lg,
        InkSpacing.sm,
        InkSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.overlay.withValues(alpha: 0), colors.overlay],
        ),
      ),
      child: Row(
        children: [
          Icon(_iconFor(node.type), size: 14, color: colors.fg2),
          const SizedBox(width: InkSpacing.xs),
          Expanded(
            child: Text(
              node.label.isEmpty ? _typeLabel(context, node.type) : node.label,
              style: typo.caption.copyWith(color: colors.fg1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
        CanvasNodeType.text => context.l10n.canvasNodeTextType,
        CanvasNodeType.video => context.l10n.canvasNodeVideoType,
        CanvasNodeType.shot => context.l10n.canvasNodeShotType,
      };
}

/// 节点底部实时进度条：running 且有进度→确定值；queued/submitting/无进度→不确定动画。
class _NodeProgressBar extends StatelessWidget {
  const _NodeProgressBar({required this.job});
  final JobState job;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final progress = job.progressValue > 0 ? job.progressValue : null;
    return LinearProgressIndicator(
      value: progress,
      minHeight: 3,
      backgroundColor: colors.surface3,
      color: colors.accent,
    );
  }
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
    // 正文只放 prompt；标识（label/类型）归底部标题条，避免重复文字。
    final prompt = node.promptText;
    if (prompt == null || prompt.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(InkSpacing.sm),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          prompt,
          style: typo.body.copyWith(color: colors.fg1),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
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

    return Image.file(
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
      color: colors.surface3,
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
