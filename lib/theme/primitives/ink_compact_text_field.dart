// InkCompactTextField：CineFlow 紧凑 textarea（bg-white/0.04 + rounded-lg +
// ring-1 focus 细边）。单行/多行通用，配合 minLines/maxLines。
//
// 背景半透明白（与父面板层叠出微差异），聚焦时用 borderHover 做细 ring，
// placeholder 用 fg3。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkCompactTextField extends StatefulWidget {
  const InkCompactTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;

  @override
  State<InkCompactTextField> createState() => _InkCompactTextFieldState();
}

class _InkCompactTextFieldState extends State<InkCompactTextField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus != _focused) {
      setState(() => _focused = _focus.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.md,
        vertical: InkSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(
          color: _focused ? colors.borderHover : Colors.transparent,
          width: 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        style: typo.body.copyWith(color: colors.fg1),
        cursorColor: colors.fg1,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration.collapsed(
          hintText: widget.placeholder,
          hintStyle: typo.body.copyWith(color: colors.fg3),
        ),
      ),
    );
  }
}
