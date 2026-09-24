// InkInput：文本输入框骨架（Workspace v2 稿：无底色，只有 1px control 底线；多行时底线在末行下）。
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
    final typo = context.inkTypography;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: enabled ? colors.control : colors.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.sm,
          vertical: InkSpacing.xs,
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          minLines: minLines,
          maxLines: maxLines,
          enabled: enabled,
          cursorColor: colors.accent,
          style: typo.body.copyWith(color: colors.fg2),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: typo.body.copyWith(color: colors.fg6),
            isDense: true,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
