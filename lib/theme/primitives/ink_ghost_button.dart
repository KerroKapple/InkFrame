// InkGhostButton：默认透明、hover 才显边框的次按钮。
//
// 点击壳走 InkActivatable（与标签 chip 同一件）：可 Tab 聚焦、Enter / Space 激活、
// 聚焦时画一圈 accent 环。此前它是裸 GestureDetector + Semantics——仓库里 11 处
// 消费点全都键盘到不了（BOARD 210）。本件只负责"长什么样"，所以是无状态的。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';
import 'ink_activatable.dart';

class InkGhostButton extends StatelessWidget {
  const InkGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
  });

  final String label;

  /// null = 此刻不可点，**并且不可聚焦**。不要传空闭包
  /// （test/quality/no_dead_interactive_test.dart）。
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return InkActivatable(
      onTap: onPressed,
      semanticLabel: label,
      // 环跟按钮同一个圆角；画在前景位，不参与布局 ⇒ 不撑大按钮。
      focusRingRadius: BorderRadius.circular(InkRadius.sm),
      builder: (BuildContext context, bool hovered, bool focused) =>
          AnimatedContainer(
        duration: InkMotion.fast,
        height: compact ? 28 : 36,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? InkSpacing.sm : InkSpacing.md,
        ),
        decoration: BoxDecoration(
          color: hovered ? colors.surface3 : Colors.transparent,
          borderRadius: BorderRadius.circular(InkRadius.sm),
          border: Border.all(
            color: hovered ? colors.outline : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 16, color: colors.fg2),
              const SizedBox(width: InkSpacing.xs),
            ],
            Text(label, style: typo.body.copyWith(color: colors.fg2)),
          ],
        ),
      ),
    );
  }
}
