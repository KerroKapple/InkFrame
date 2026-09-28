// NodeCard：画布上的单个节点卡片（Workspace v2 稿）。
//
// 224 宽：18px 标题行（名称 500 + 类型 10px）| 6 | 16:9 图区（4px 圆角 + 1px outline，
// 选中 accent；outline 画在盒子外一圈）| 6 | 16px 状态行（状态文字 + 等宽 meta）。
// 无外框、无阴影、无标题条底色。端口在图区垂直中心向外偏移 5px：入=空心，出=实心。
//
// 稿上没有卡片角落的连线 / 删除小圆钮：连线走工具条「连线」（选中节点后），
// 删除走 Delete 键——[onStartLink] / [onDelete] 保留在 API 上供上层继续持有，
// 本卡片不再渲染它们。
//
// 图区内容：result 节点 = 缩略图（image / video）；config 节点 = 提示词摘要，
// video config 另列出「起始帧 ← X · 结束帧 ← Y · 运镜」。
//
// 拖拽（HI-13）：位移累积在本卡片局部状态（Transform.translate），每帧只重建
// 自身；onPanEnd 把累计位移一次性回调 onDragEnd，由上层提交 controller。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../generation/models/job_state.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/node_active_job.dart';
import '../providers/node_drag_delta.dart';
import '../util/camera_labels.dart';
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

  /// 进入连线模式的入口（本卡片不渲染，见头注）。
  final VoidCallback? onStartLink;

  /// 删除入口（本卡片不渲染，见头注）。
  final VoidCallback? onDelete;

  /// 本节点是否为当前连线模式的起点（UI 高亮）。
  final bool isLinkSource;

  /// 连线模式下此节点是否为合法目标（非起点 → 高亮为点击候选）。
  final bool isLinkCandidate;

  static const double thumbHeight = 126; // 224 × 9 / 16

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
    final typo = context.inkTypography;
    final highlighted =
        widget.selected || widget.isLinkSource || widget.isLinkCandidate;
    final Color edge = highlighted ? colors.accent : colors.outline;
    final Color outPort = highlighted ? colors.accent : colors.fg5;
    // 稿：shot 节点只有出端口。
    final bool hasIn =
        !(node.type == CanvasNodeType.shot && node.role == NodeRole.config);

    return Transform.translate(
      offset: _dragOffset,
      child: MouseRegion(
        cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: GestureDetector(
          // opaque：卡片内任何位置（含空图区）都可点选 / 拖拽。
          behavior: HitTestBehavior.opaque,
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
          child: SizedBox(
            width: kNodeCardSize.width,
            height: kNodeCardSize.height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 18,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            nodeDisplayName(context, node),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typo.bodyStrong.copyWith(color: colors.fg1),
                          ),
                        ),
                        const SizedBox(width: InkSpacing.sm),
                        Text(node.type.name, style: typo.micro.copyWith(color: colors.fg5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: InkSpacing.s6),
                SizedBox(
                  height: NodeCard.thumbHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(InkRadius.sm),
                          child: ColoredBox(
                            color: colors.thumbFill,
                            child: _NodeBody(
                              node: node,
                              resolver: ref.watch(fileResolverServiceProvider),
                            ),
                          ),
                        ),
                      ),
                      // 稿用的是 CSS outline：画在盒子【外】一圈，不占布局。
                      Positioned(
                        left: -1,
                        top: -1,
                        right: -1,
                        bottom: -1,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: edge),
                              borderRadius: BorderRadius.circular(InkRadius.s5),
                            ),
                          ),
                        ),
                      ),
                      if (hasIn)
                        Positioned(
                          left: -5,
                          top: NodeCard.thumbHeight / 2 - 5,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors.surface1,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.fg5, width: 1.5),
                            ),
                          ),
                        ),
                      Positioned(
                        right: -5,
                        top: NodeCard.thumbHeight / 2 - 5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: outPort, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s6),
                SizedBox(
                  height: 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
                    child: _StatusRow(node: node),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 显示名：空标题回退类型名。
String nodeDisplayName(BuildContext context, CanvasNode node) =>
    node.label.isEmpty ? nodeTypeLabel(context, node.type) : node.label;

/// 引用名（用户拍板）：别处引用一个节点时不重复它的类型——「镜头 01 · 图像」引用为「镜头 01」。
/// 规则：label 以「 · <本地化类型名>」结尾时去掉该尾段；其余原样。
String nodeRefName(BuildContext context, CanvasNode node) {
  final String name = nodeDisplayName(context, node);
  final String suffix = ' · ${nodeTypeLabel(context, node.type)}';
  return name.endsWith(suffix) && name.length > suffix.length
      ? name.substring(0, name.length - suffix.length)
      : name;
}

String nodeTypeLabel(BuildContext context, CanvasNodeType type) => switch (type) {
      CanvasNodeType.image => context.l10n.canvasNodeImageType,
      CanvasNodeType.text => context.l10n.canvasNodeTextType,
      CanvasNodeType.video => context.l10n.canvasNodeVideoType,
      CanvasNodeType.shot => context.l10n.canvasNodeShotType,
    };

/// 状态行：左状态文字（进行中 accent，其余 fg4），右等宽 meta（provider id / camera / txt）。
class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final JobState? job = ref.watch(nodeActiveJobProvider(node.id));

    final String status;
    Color statusColor = colors.fg4;
    if (job != null) {
      switch (job) {
        case JobRunning(:final progress):
          status = l.inspectorStatusRunningWithProgress((progress * 100).round());
          statusColor = colors.accent;
        case JobQueued() || JobSubmitting():
          status = l.canvasRenderQueueStatusQueued;
        default:
          status = l.nodeStatusReady;
      }
    } else if (node.role == NodeRole.result) {
      status = (node.imageUrl ?? node.videoUrl) != null
          ? l.nodeStatusDone
          : l.nodeStatusPending;
    } else {
      final String? prompt = node.type == CanvasNodeType.shot
          ? (node.typeConfig['shot_notes'] as String?)
          : (node.type == CanvasNodeType.text ? node.textContent : node.promptText);
      status = (prompt == null || prompt.trim().isEmpty)
          ? l.nodeStatusDraft
          : l.nodeStatusReady;
    }

    final String meta = switch (node.type) {
      CanvasNodeType.text => 'txt',
      CanvasNodeType.shot => 'txt',
      _ => (node.typeConfig['provider_id'] as String?) ?? '',
    };

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.meta.copyWith(color: statusColor),
          ),
        ),
        const SizedBox(width: InkSpacing.sm),
        Text(meta, style: typo.monoSmall.copyWith(color: colors.fg5)),
      ],
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
    if (node.type == CanvasNodeType.video) {
      return _VideoConfigBody(node: node);
    }
    return _ConfigBody(node: node);
  }
}

/// 图区左下角 11px fg6 说明文字（稿：padding 8 10，行高 1.45）。
class _ThumbLabel extends StatelessWidget {
  const _ThumbLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(InkSpacing.s10, InkSpacing.sm, InkSpacing.s10, InkSpacing.sm),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: typo.meta.copyWith(color: colors.fg6),
        ),
      ),
    );
  }
}

class _ConfigBody extends StatelessWidget {
  const _ConfigBody({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    final String? text = switch (node.type) {
      CanvasNodeType.shot => node.typeConfig['shot_notes'] as String?,
      CanvasNodeType.text => node.textContent,
      _ => node.promptText,
    };
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return _ThumbLabel(text.trim());
  }
}

/// video config：起始帧 ← X · 结束帧 ← Y · 运镜（稿）；无入边时退回提示词。
class _VideoConfigBody extends ConsumerWidget {
  const _VideoConfigBody({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final String canvasId = node.canvasId ?? '';
    final List<CanvasEdge> edges = canvasId.isEmpty
        ? const <CanvasEdge>[]
        : (ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ?? const <CanvasEdge>[]);
    final List<CanvasNode> nodes = canvasId.isEmpty
        ? const <CanvasNode>[]
        : (ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[]);
    final Map<String, CanvasNode> byId = <String, CanvasNode>{for (final n in nodes) n.id: n};

    final List<String> parts = <String>[];
    for (final CanvasEdge e in edges) {
      if (e.targetNodeId != node.id || e.edgeType != EdgeType.data) continue;
      final CanvasNode? src = byId[e.sourceNodeId];
      if (src == null) continue;
      final String roleLabel = switch (e.role) {
        EdgeRole.firstFrame => l.inspectorRoleFirstFrame,
        EdgeRole.lastFrame => l.inspectorRoleLastFrame,
        EdgeRole.reference => l.inspectorRoleReference,
      };
      parts.add('$roleLabel ← ${nodeRefName(context, src)}');
    }
    final CameraMovement? camera = _cameraOf(node);
    if (camera != null) parts.add(cameraMovementLabel(context, camera));

    if (parts.isEmpty) {
      final String? prompt = node.promptText;
      if (prompt == null || prompt.trim().isEmpty) return const SizedBox.shrink();
      return _ThumbLabel(prompt.trim());
    }
    return _ThumbLabel(parts.join(' · '));
  }

  static CameraMovement? _cameraOf(CanvasNode node) {
    final String? name = node.cameraName;
    if (name == null) return null;
    for (final CameraMovement c in CameraMovement.values) {
      if (c.name == name) return c;
    }
    return null;
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
      return _ThumbLabel(context.l10n.resultNodePending);
    }
    // 单测允许 projectId/canvasId 为空 → 退化为占位（避免 PathSecurityError）。
    if (node.projectId == null || node.canvasId == null) {
      return _ThumbLabel(url);
    }

    File file;
    try {
      file = resolver.resolve(
        projectId: node.projectId!,
        canvasId: node.canvasId!,
        relativePath: url,
      );
    } on PathSecurityError {
      return _ThumbLabel(context.l10n.resultNodeImageMissing);
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // ME-26：按卡片宽度解码，避免原图全尺寸进 image cache。
      cacheWidth: (kNodeCardSize.width * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (_, _, _) => _ThumbLabel(context.l10n.resultNodeImageMissing),
    );
  }
}
