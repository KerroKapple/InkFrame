// LockSecureField：下划线密码输入框（mask + 右侧眼图标切换可见性）。
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class LockSecureField extends StatefulWidget {
  const LockSecureField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<LockSecureField> createState() => _LockSecureFieldState();
}

class _LockSecureFieldState extends State<LockSecureField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border, width: 1),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscure,
              autofocus: widget.autofocus,
              onSubmitted: widget.onSubmitted,
              style: typo.body.copyWith(color: colors.fg1, letterSpacing: 2),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: InkSpacing.sm,
                ),
                hintText: widget.hintText,
                hintStyle: typo.body.copyWith(color: colors.fg3),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: colors.fg3,
            ),
            splashRadius: 18,
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ],
      ),
    );
  }
}
