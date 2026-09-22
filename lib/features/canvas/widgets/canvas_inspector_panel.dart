// CanvasInspectorPanel：右侧检查器 301px（稿 300 + 1px 左沿）。
//
// 结构：三标签「属性 / 状态 / 历史」→ 选中节点摘要（8×8 琥珀方点 + 名称 + type / role · provider）
// → 内容（NodeInspectorRouter：现有 image / video / shot / result 检查器）→ 底部说明条。
//
// 稿上「状态 / 历史」两个标签在仓库里没有独立面板（状态已内嵌在各检查器的
// InspectorStatusPanel 里，历史无后端），只画标签不挂交互；「重置」按钮无对应动作，不画。
// 分组字段的稿样式（模型 / 关键帧 / 镜头运动）在下一切片改各检查器时落地。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import 'node_card.dart';
import 'node_inspector_router.dart';

class CanvasInspectorPanel extends ConsumerWidget {
  const CanvasInspectorPanel({super.key, required this.canvasId});

  final String canvasId;

  /// 稿是 content-box：width 300 + border-left 1。
  static const double width = 301;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final Set<String> selected = ref.watch(canvasSelectionControllerProvider(canvasId));
    CanvasNode? node;
    if (selected.length == 1) {
      final List<CanvasNode> nodes =
          ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
      for (final CanvasNode n in nodes) {
        if (n.id == selected.first) node = n;
      }
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(left: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WsPanelTabs(
            tabs: <String>[l.inspectorTabProperties, l.inspectorTabStatus, l.inspectorTabHistory],
            trailing: const WsPanelMenuGlyph(),
          ),
          Expanded(
            child: node == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(InkSpacing.md),
                      child: Text(l.inspectorNoSelection,
                          textAlign: TextAlign.center, style: t.meta.copyWith(color: c.fg6)),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _NodeSummary(node: node),
                      Expanded(
                        child: SingleChildScrollView(
                          child: NodeInspectorRouter(key: ValueKey<String>(node.id), node: node),
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s10),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(top: BorderSide(color: c.borderStrong)),
            ),
            child: Row(
              children: <Widget>[
                const Spacer(),
                Text(l.inspectorHintFollowsSelection, style: t.meta.copyWith(color: c.fg6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeSummary extends ConsumerWidget {
  const _NodeSummary({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final String? providerId = node.typeConfig['provider_id'] as String?;
    final String providerName =
        providerId == null ? '' : (ref.watch(providerDisplayNamesProvider)[providerId] ?? providerId);
    final String meta = <String>[
      '${node.type.name} / ${node.role.name}',
      if (providerName.isNotEmpty) providerName,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.s12, InkSpacing.s12, InkSpacing.s10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
      child: Row(
        children: <Widget>[
          WsSquareDot(size: 8, color: c.accent),
          const SizedBox(width: InkSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(nodeDisplayName(context, node),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(height: InkSpacing.s2),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.meta.copyWith(color: c.fg5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
