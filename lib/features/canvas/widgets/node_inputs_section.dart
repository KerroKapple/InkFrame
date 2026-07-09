// NodeInputsSection：config 节点的入边（data edge）列表 + role 切换。
// image / video inspector 共享。role 选项按当前 provider 能力过滤
// （supportsFirstFrame / supportsLastFrame），reference 恒可选；
// 已存 role 即使不在允许集也保留展示（钳制语义，防 DropdownButton 断言）。
// maxRefImages > 0 时标签带 n/max 计数，超限给忽略警告（截断发生在 provider）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/primitives/ink_dashed_slot.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';

/// 入边行缩略图边长（正方形裁切）。
const double _kThumbSize = 28;

class NodeInputsSection extends ConsumerWidget {
  const NodeInputsSection({
    super.key,
    required this.targetNode,
    required this.selectedCaps,
  });

  final CanvasNode targetNode;
  final ProviderCapabilities? selectedCaps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = targetNode.canvasId!;
    final colors = context.inkColors;
    final typo = context.inkTypography;

    final edgesAsync = ref.watch(canvasEdgesControllerProvider(canvasId));
    final nodesAsync = ref.watch(canvasNodesControllerProvider(canvasId));
    // 入边/节点任一加载失败 → 错误横幅（此前静默降级为空 = 误报"无入边"）。
    final loadError = edgesAsync.error ?? nodesAsync.error;
    if (loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.inspectorInputsLabel,
            style: typo.caption.copyWith(color: colors.fg3),
          ),
          const SizedBox(height: InkSpacing.xs),
          InkErrorBanner(message: l10nAsyncError(context, loadError)),
        ],
      );
    }
    final edges = edgesAsync.valueOrNull ?? const <CanvasEdge>[];
    final nodes = nodesAsync.valueOrNull ?? const <CanvasNode>[];
    final nodesById = {for (final n in nodes) n.id: n};

    final inputs = edges
        .where(
          (e) => e.targetNodeId == targetNode.id && e.edgeType == EdgeType.data,
        )
        .toList();
    // 首/尾帧不占参考图配额，计数只数 reference。
    final refCount = inputs.where((e) => e.role == EdgeRole.reference).length;
    final maxRefs = selectedCaps?.maxRefImages ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          maxRefs > 0
              ? context.l10n.inspectorInputsLabelCounted(refCount, maxRefs)
              : context.l10n.inspectorInputsLabel,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.xs),
        if (inputs.isEmpty)
          InkDashedSlot(
            child: Text(
              context.l10n.inspectorInputsEmpty,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
          )
        else ...[
          for (final edge in inputs)
            _InputRow(
              edge: edge,
              source: nodesById[edge.sourceNodeId],
              canvasId: canvasId,
              roleOptions: _roleOptions(edge.role),
              thumbPath: _thumbPathFor(ref, nodesById[edge.sourceNodeId]),
            ),
          if (maxRefs > 0 && refCount > maxRefs)
            Padding(
              padding: const EdgeInsets.only(bottom: InkSpacing.xs),
              child: Text(
                context.l10n.inspectorInputsOverLimit(maxRefs),
                style: typo.caption.copyWith(color: colors.warning),
              ),
            ),
        ],
      ],
    );
  }

  /// 可选 role：reference 恒可选；首/尾帧看 provider 能力位；
  /// 当前值不在允许集也保留（旧数据/能力切换后不崩、可见可改）。
  List<EdgeRole> _roleOptions(EdgeRole current) {
    final options = <EdgeRole>[
      EdgeRole.reference,
      if (selectedCaps?.supportsFirstFrame ?? false) EdgeRole.firstFrame,
      if (selectedCaps?.supportsLastFrame ?? false) EdgeRole.lastFrame,
    ];
    if (!options.contains(current)) options.add(current);
    return options;
  }

  /// 来源节点缩略图绝对路径；无图 / 无 projectId / 越权路径 → null 不渲染。
  String? _thumbPathFor(WidgetRef ref, CanvasNode? source) {
    final rel = source?.imageUrl;
    final projectId = targetNode.projectId;
    final canvasId = targetNode.canvasId;
    if (rel == null || rel.isEmpty || projectId == null || canvasId == null) {
      return null;
    }
    try {
      return ref
          .read(fileResolverServiceProvider)
          .resolve(projectId: projectId, canvasId: canvasId, relativePath: rel)
          .path;
    } on PathSecurityError {
      return null;
    }
  }
}

class _InputRow extends ConsumerWidget {
  const _InputRow({
    required this.edge,
    required this.source,
    required this.canvasId,
    required this.roleOptions,
    required this.thumbPath,
  });

  final CanvasEdge edge;
  final CanvasNode? source;
  final String canvasId;
  final List<EdgeRole> roleOptions;
  final String? thumbPath;

  String _roleLabel(BuildContext context, EdgeRole role) => switch (role) {
    EdgeRole.reference => context.l10n.inspectorRoleReference,
    EdgeRole.firstFrame => context.l10n.inspectorRoleFirstFrame,
    EdgeRole.lastFrame => context.l10n.inspectorRoleLastFrame,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final ctrl = ref.read(canvasEdgesControllerProvider(canvasId).notifier);
    final sourceLabel = source?.label.isNotEmpty == true
        ? source!.label
        : (source?.id ?? edge.sourceNodeId);

    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.xs),
      child: Row(
        children: [
          if (thumbPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(InkRadius.sm),
              child: Image.file(
                File(thumbPath!),
                width: _kThumbSize,
                height: _kThumbSize,
                fit: BoxFit.cover,
                // 缺文件/坏图占位，不崩 UI。
                errorBuilder: (_, _, _) =>
                    Icon(Icons.image_outlined, size: 16, color: colors.fg3),
              ),
            ),
            const SizedBox(width: InkSpacing.xs),
          ],
          Expanded(
            child: Text(
              sourceLabel,
              style: typo.body.copyWith(color: colors.fg1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: InkSpacing.xs),
          DropdownButton<EdgeRole>(
            value: edge.role,
            isDense: true,
            items: [
              for (final r in roleOptions)
                DropdownMenuItem(value: r, child: Text(_roleLabel(context, r))),
            ],
            onChanged: (v) {
              if (v == null || v == edge.role) return;
              ctrl.updateRole(edge.id, v).catchError((Object _) {
                // 失败已由 Controller 回滚内存；UI 由 edges 列表自动重渲染
              });
            },
          ),
          IconButton(
            tooltip: context.l10n.inspectorRemoveInput,
            icon: Icon(Icons.link_off, size: 16, color: colors.danger),
            onPressed: () {
              // 失败已由 Controller 回滚内存；UI 由 edges 列表自动重渲染。
              ctrl.removeEdge(edge.id).catchError((Object _) => null);
            },
          ),
        ],
      ),
    );
  }
}
