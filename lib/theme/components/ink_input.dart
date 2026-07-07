// InkInput：文本输入框骨架（单行）。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkInput extends StatelessWidget {
  const InkInput({
    super.key,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.focusNode,
    this.minLines,
    this.maxLines = 1,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final int? minLines;

  /// 最大行数——null 表示无限扩展，适合 prompt 长文本。
  final int? maxLines;

  /// 禁用时不可编辑（busy 等场景与其余交互一致）。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.md,
          vertical: InkSpacing.sm,
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          minLines: minLines,
          maxLines: maxLines,
          enabled: enabled,
          style: context.inkTypography.body.copyWith(color: colors.fg1),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: context.inkTypography.body.copyWith(color: colors.fg3),
            isDense: true,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
