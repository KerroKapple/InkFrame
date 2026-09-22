// 工作区标签栏 34px：五标签（选中 fg1/500 + 2px accent 下边，无底色）| 竖线 | 面包屑 | 三按钮。
import 'package:flutter/widgets.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';
import 'ws_primitives.dart';

class WsTabBar extends StatelessWidget {
  const WsTabBar({super.key});

  /// 稿是 content-box：height 34 + border-bottom 1。
  static const double height = 35;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    const List<String> crumbs = WorkspaceFixture.breadcrumb;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(width: InkSpacing.s12),
          for (int i = 0; i < WorkspaceFixture.tabs.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
              alignment: Alignment.center,
              decoration: i == WorkspaceFixture.activeTab
                  ? BoxDecoration(border: Border(bottom: BorderSide(color: c.accent, width: 2)))
                  : null,
              child: Text(
                WorkspaceFixture.tabs[i],
                style: i == WorkspaceFixture.activeTab
                    ? t.bodyStrong.copyWith(color: c.fg1)
                    : t.body.copyWith(color: c.fg4),
              ),
            ),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: InkSpacing.sm, horizontal: InkSpacing.s6),
            color: c.control,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
            child: Row(
              children: <Widget>[
                Text(crumbs[0], style: t.body.copyWith(color: c.fg6)),
                const SizedBox(width: InkSpacing.xs),
                Text('›', style: t.body.copyWith(color: c.fg6)),
                const SizedBox(width: InkSpacing.xs),
                Text(crumbs[1], style: t.body.copyWith(color: c.fg3)),
                const SizedBox(width: InkSpacing.xs),
                Text('›', style: t.body.copyWith(color: c.fg6)),
                const SizedBox(width: InkSpacing.xs),
                Text(crumbs[2], style: t.body.copyWith(color: c.fg1)),
              ],
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Row(
              children: <Widget>[
                WsSecondaryButton(WorkspaceFixture.importScript),
                SizedBox(width: InkSpacing.s6),
                WsSecondaryButton(WorkspaceFixture.sequencePreview),
                SizedBox(width: InkSpacing.s6),
                WsPrimaryButton(WorkspaceFixture.exportVideo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
