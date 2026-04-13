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
  });

  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

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
