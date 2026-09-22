// 左侧工具条 36px：七个 26×26 格，当前工具琥珀底 + 深色图标，其余透明 + fg3。
// 图标沿用稿上的 12×12 描边方框占位（不同圆角），实现时换项目图标集。
import 'package:flutter/widgets.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';

class WsToolRail extends StatelessWidget {
  const WsToolRail({super.key});

  /// 稿是 content-box：width 36 + border-right 1。
  static const double width = 37;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s6),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < WorkspaceFixture.tools.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: InkSpacing.s2),
            _ToolCell(tool: WorkspaceFixture.tools[i]),
          ],
        ],
      ),
    );
  }
}

class _ToolCell extends StatelessWidget {
  const _ToolCell({required this.tool});
  final WsTool tool;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final Color fg = tool.active ? c.onAccent : c.fg3;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tool.active ? c.accent : null,
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      // 稿是 content-box：12×12 + 1.5px 边 ⇒ 15×15。
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          border: Border.all(color: fg, width: 1.5),
          borderRadius: _radius(tool.shape),
        ),
      ),
    );
  }

  static BorderRadius _radius(WsToolShape s) => switch (s) {
        WsToolShape.square1 => BorderRadius.circular(InkRadius.s1),
        WsToolShape.circle => BorderRadius.circular(InkRadius.pill),
        WsToolShape.pill => const BorderRadius.horizontal(
            left: Radius.circular(InkRadius.s1),
            right: Radius.circular(InkRadius.bentoBtn),
          ),
        WsToolShape.square0 => BorderRadius.zero,
        WsToolShape.square2 => BorderRadius.circular(InkRadius.xs),
        WsToolShape.square3 => BorderRadius.circular(InkRadius.s3),
        WsToolShape.cupBottom => const BorderRadius.vertical(
            bottom: Radius.circular(InkRadius.bentoBtn),
          ),
      };
}
