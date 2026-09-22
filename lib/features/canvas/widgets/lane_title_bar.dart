// 泳道标题栏（Lanes 稿 §1）：26px、圆角 3、rgba(38,38,38,0.82) 底；左 8×8 色点（tint），
// 名称 12/500 fg1 + 风格提示词摘要 10px fg5 单行省略；右侧折叠 / 编辑 / 删除三个 18×18 图标键。
// 宽度由调用方给定（横向固定 268，竖向 min(道宽 − 24, 240)），不再跨满整条泳道。
// 双击标题栏折叠 / 展开。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../models/style_lane.dart';
import '../util/lane_tint.dart';

class LaneTitleBar extends StatelessWidget {
  const LaneTitleBar({
    super.key,
    required this.lane,
    required this.onEdit,
    required this.onDelete,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final StyleLane lane;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  /// 当前是否处于折叠态。
  final bool collapsed;
  /// 触发折叠/展开回调；null 表示不支持折叠。
  final VoidCallback? onToggleCollapse;

  static const double height = 26;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typography = context.inkTypography;
    final l10n = context.l10n;
    final Color? tint = effectiveLaneTint(tintColor: lane.tintColor, stylePrompt: lane.stylePrompt);
    final String prompt = lane.stylePrompt.trim();

    final bar = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface4.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        children: [
          WsSquareDot(size: 8, color: tint ?? colors.fg6),
          const SizedBox(width: InkSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  lane.label.isEmpty ? l10n.laneUntitled : lane.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyStrong.copyWith(color: colors.fg1, height: 1.0),
                ),
                if (prompt.isNotEmpty)
                  Text(
                    prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.micro.copyWith(color: colors.fg5, height: 1.0),
                  ),
              ],
            ),
          ),
          if (onToggleCollapse != null)
            _IconKey(
              icon: collapsed ? Icons.unfold_more : Icons.unfold_less,
              tooltip: collapsed ? l10n.laneExpand : l10n.laneCollapse,
              onTap: onToggleCollapse!,
            ),
          _IconKey(icon: Icons.edit, tooltip: l10n.laneEditTitle, onTap: onEdit),
          _IconKey(icon: Icons.delete_outline, tooltip: l10n.laneDelete, onTap: onDelete),
        ],
      ),
    );

    if (onToggleCollapse == null) return bar;

    // 双击标题栏也触发折叠/展开。
    return GestureDetector(
      onDoubleTap: onToggleCollapse,
      child: bar,
    );
  }
}

/// 18×18 图标键（稿）。
class _IconKey extends StatelessWidget {
  const _IconKey({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: 18,
              height: 18,
              child: Icon(icon, size: 12, color: colors.fg3),
            ),
          ),
        ),
      ),
    );
  }
}
