// 菜单栏 30px：Logo | 菜单项 | ⌘K 搜索入口 260px | 连接状态。surface4 底，下沿 borderStrong。
import 'package:flutter/widgets.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';

class WsMenuBar extends StatelessWidget {
  const WsMenuBar({super.key});

  /// 稿是 content-box：height 30 + border-bottom 1。
  static const double height = 31;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          // Logo：16×16 琥珀方块「If」+ InkFrame，右侧 1px control 竖线
          Container(
            padding: const EdgeInsets.only(right: InkSpacing.s18),
            margin: const EdgeInsets.only(right: InkSpacing.s6),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: c.control))),
            child: Row(
              children: <Widget>[
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(InkRadius.s3),
                  ),
                  child: Text(
                    'If',
                    style: t.micro.copyWith(color: c.onAccent, fontWeight: FontWeight.w600, height: 1.0),
                  ),
                ),
                const SizedBox(width: InkSpacing.sm),
                Text('InkFrame', style: t.bodyStrong.copyWith(color: c.fg1)),
              ],
            ),
          ),
          for (final String item in WorkspaceFixture.menuItems)
            Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
              alignment: Alignment.center,
              child: Text(item, style: t.body.copyWith(color: c.fg3)),
            ),
          const Spacer(),
          // ⌘K 搜索入口：无底色，1px control 底线，260 宽
          Container(
            width: 280, // content 260 + padding 2×10
            height: 23, // content 22 + border-bottom 1
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
            child: Row(
              children: <Widget>[
                CustomPaint(size: const Size(12, 12), painter: WsSearchGlyph(c.fg6)),
                const SizedBox(width: InkSpacing.s6),
                Expanded(child: Text(WorkspaceFixture.searchPlaceholder, style: t.body.copyWith(color: c.fg6))),
                Text('⌘K', style: t.monoSmall.copyWith(color: c.fg6)),
              ],
            ),
          ),
          const SizedBox(width: InkSpacing.md),
          Text(WorkspaceFixture.connected, style: t.body.copyWith(color: c.accent)),
          const SizedBox(width: InkSpacing.s14),
          Text(WorkspaceFixture.providerName, style: t.body.copyWith(color: c.fg4)),
        ],
      ),
    );
  }
}

/// 稿上的 12×12 放大镜：圆 r3.6@(5.2,5.2) + 斜柄 (8,8)→(10.6,10.6)，1.3 描边。
class WsSearchGlyph extends CustomPainter {
  const WsSearchGlyph(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(const Offset(5.2, 5.2), 3.6, p);
    canvas.drawLine(const Offset(8, 8), const Offset(10.6, 10.6), p);
  }

  @override
  bool shouldRepaint(WsSearchGlyph old) => old.color != color;
}
