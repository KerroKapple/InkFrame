// LockLogo：中央衬线 "Ink/Frame" 大字，斜杠走 accent 色。
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class LockLogo extends StatelessWidget {
  const LockLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final base = typo.display.copyWith(
      fontSize: 72,
      color: colors.fg1,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text('Ink', style: base),
          Text('/', style: base.copyWith(color: colors.accent)),
          Text('Frame', style: base),
        ],
      ),
    );
  }
}
