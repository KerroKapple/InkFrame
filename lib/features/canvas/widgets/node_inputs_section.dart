// NodeInputsSection：config 节点的入边（data edge）列表 + role 切换。
// image / video inspector 共享。role 选项按当前 provider 能力过滤
// （supportsFirstFrame / supportsLastFrame），reference 恒可选；
// 已存 role 即使不在允许集也保留展示（钳制语义，防 DropdownButton 断言）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';

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
    final edges = edgesAsync.valueOrNull ?? const <CanvasEdge>[];
    final nodes = nodesAsync.valueOrNull ?? const <CanvasNode>[];
    final nodesById = {for (final n in nodes) n.id: n};

    final inputs = edges
        .where(
          (e) => e.targetNodeId == targetNode.id && e.edgeType == EdgeType.data,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.inspectorInputsLabel,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.xs),
        if (inputs.isEmpty)
          Text(
            context.l10n.inspectorInputsEmpty,
            style: typo.caption.copyWith(color: colors.fg3),
          )
        else
          for (final edge in inputs)
            _InputRow(
              edge: edge,
              source: nodesById[edge.sourceNodeId],
              canvasId: canvasId,
              roleOptions: _roleOptions(edge.role),
            ),
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
}

class _InputRow extends ConsumerWidget {
  const _InputRow({
    required this.edge,
    required this.source,
    required this.canvasId,
    required this.roleOptions,
  });

  final CanvasEdge edge;
  final CanvasNode? source;
  final String canvasId;
  final List<EdgeRole> roleOptions;

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
              ctrl.removeEdge(edge.id).catchError((Object _) {});
            },
          ),
        ],
      ),
    );
  }
}
