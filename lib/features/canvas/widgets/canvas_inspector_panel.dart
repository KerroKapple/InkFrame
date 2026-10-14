// CanvasInspectorPanel：右侧检查器 301px（稿 300 + 1px 左沿）。
//
// 结构：页签条「属性 / 历史」→ 内容 → 自动保存失败行 → 底部说明条。
//   - 属性：选中节点摘要（8×8 琥珀方点 + 名称 + type / role · provider）+ NodeInspectorRouter
//     （现有 image / video / shot / result 检查器）。
//   - 历史：选中节点的 take 列表（inspector_history_panel.dart）。
// PR-6 页签去重删掉了原来的「状态」页签：它只画标签、不挂交互，状态早已内嵌在各配置检查器的
// InspectorStatusPanel 里。停在哪一页记在 inspectorTabProvider——换选中节点不重置。
// 没选中（或多选）时两页都是同一句空态。稿上「重置」按钮无对应动作，不画。
//
// 历史页只在选中它时才 build：它要 watch 边控制器（「在用」标记），属性页用不着，不让属性页多一条
// 仓储依赖。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_primitives.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/inspector_tab.dart';
import 'inspector_auto_save_row.dart';
import 'inspector_history_panel.dart';
import 'node_card.dart';
import 'node_inspector_router.dart';

class CanvasInspectorPanel extends ConsumerWidget {
  const CanvasInspectorPanel({super.key, required this.canvasId});

  final String canvasId;

  /// 稿是 content-box：width 300 + border-left 1。
  static const double width = 301;

  /// 页签条：稿 content-box，29 + 1px 下沿。
  static const double tabBarHeight = 30;

  /// 某个页签的测试锚点。
  static Key tabKey(InspectorTab tab) => ValueKey<String>('inspector-tab-${tab.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final InspectorTab tab = ref.watch(inspectorTabProvider);
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
          _InspectorTabs(active: tab),
          Expanded(
            child: node == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(InkSpacing.md),
                      child: Text(l.inspectorNoSelection,
                          textAlign: TextAlign.center, style: t.meta.copyWith(color: c.fg6)),
                    ),
                  )
                : switch (tab) {
                    InspectorTab.properties => Column(
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
                    InspectorTab.history => InspectorHistoryPanel(canvasId: canvasId, node: node),
                  },
          ),
          // 自动保存失败面：Clean 时不占位，失败时说清原因 + 「重试」。
          // 挂在这一层而不是各检查器里——所有自动保存入口都要求「恰好选中一个
          // 节点」，而本面板正是那个条件下常驻在屏上的那一层。两个页签下都在：失败不会因为
          // 切到历史页就不存在了。
          if (node != null) InspectorAutoSaveRow(nodeId: node.id),
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

/// 页签条（稿）：surface4 底 + borderStrong 下沿，每格左右 14。
/// 选中 = fg1 字 + surface3 底 + 顶部 1px accent 内描边（稿是 box-shadow: inset 0 1px 0，不占布局，
/// 所以走前景装饰）；未选中 = fg4。两格都走 InkActivatable：可点、可 Tab 聚焦、回车切换。
class _InspectorTabs extends ConsumerWidget {
  const _InspectorTabs({required this.active});

  final InspectorTab active;

  static String _labelOf(AppLocalizations l, InspectorTab tab) => switch (tab) {
        InspectorTab.properties => l.inspectorTabProperties,
        InspectorTab.history => l.inspectorTabHistory,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    return Container(
      height: CanvasInspectorPanel.tabBarHeight,
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final InspectorTab tab in InspectorTab.values)
            InkActivatable(
              key: CanvasInspectorPanel.tabKey(tab),
              onTap: () => ref.read(inspectorTabProvider.notifier).select(tab),
              selected: tab == active,
              builder: (BuildContext context, bool hovered, bool focused) => Container(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14),
                alignment: Alignment.center,
                color: tab == active ? c.surface3 : null,
                foregroundDecoration: tab == active
                    ? BoxDecoration(border: Border(top: BorderSide(color: c.accent)))
                    : null,
                child: Text(
                  _labelOf(l, tab),
                  maxLines: 1,
                  style: t.body.copyWith(color: tab == active ? c.fg1 : c.fg4),
                ),
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
          InkSquareDot(size: 8, color: c.accent),
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
