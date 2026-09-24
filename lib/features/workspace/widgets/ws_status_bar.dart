// 状态栏 22px：surface4 底，上沿 borderStrong，11px fg5，项间 16。
import 'package:flutter/widgets.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';

class WsStatusBar extends StatelessWidget {
  const WsStatusBar({super.key});

  /// 稿是 content-box：height 22 + border-top 1。
  static const double height = 23;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TextStyle s = t.meta.copyWith(color: c.fg5);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < WorkspaceFixture.statusLeft.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: InkSpacing.md),
            Text(WorkspaceFixture.statusLeft[i], style: s),
          ],
          const Spacer(),
          Text(WorkspaceFixture.storagePath, style: s),
          const SizedBox(width: InkSpacing.md),
          Text(WorkspaceFixture.version, style: t.mono.copyWith(color: c.fg5)),
        ],
      ),
    );
  }
}
