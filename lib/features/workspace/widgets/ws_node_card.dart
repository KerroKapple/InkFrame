// 画布节点 224px：18px 标题行 | 6 | 16:9 图区（4px 圆角 + 1px outline，选中 accent）| 6 | 16px 状态行。
// 无外框、无阴影、无标题条底色。端口在图区垂直中心，向外偏移 5px：入=空心，出=实心。
import 'package:flutter/widgets.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';
import 'ws_primitives.dart';

class WsNodeCard extends StatelessWidget {
  const WsNodeCard({super.key, required this.node});
  final WsNode node;

  static const double width = 224;
  static const double thumbHeight = width * 9 / 16;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final Color edge = node.selected ? c.accent : c.outline;
    final Color outPort = node.selected ? c.accent : c.fg5;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 18,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong.copyWith(color: c.fg1)),
                  ),
                  const SizedBox(width: InkSpacing.sm),
                  Text(node.kind, style: t.micro.copyWith(color: c.fg5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: InkSpacing.s6),
          SizedBox(
            height: thumbHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(InkSpacing.s10, InkSpacing.sm, InkSpacing.s10, InkSpacing.sm),
                    decoration: BoxDecoration(
                      color: node.thumb.gradient == null ? c.thumbFill : null,
                      gradient: _gradient(node.thumb.gradient, c),
                      borderRadius: BorderRadius.circular(InkRadius.sm),
                    ),
                    alignment: Alignment.bottomLeft,
                    child: Text(node.thumbLabel, style: t.meta.copyWith(color: c.fg6)),
                  ),
                ),
                // 稿用的是 CSS outline：画在盒子【外】一圈，不占布局。
                Positioned(
                  left: -1,
                  top: -1,
                  right: -1,
                  bottom: -1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: edge),
                      borderRadius: BorderRadius.circular(InkRadius.s5),
                    ),
                  ),
                ),
                if (node.hasIn)
                  Positioned(
                    left: -5,
                    top: thumbHeight / 2 - 5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.surface1,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.fg5, width: 1.5),
                      ),
                    ),
                  ),
                if (node.hasOut)
                  Positioned(
                    right: -5,
                    top: thumbHeight / 2 - 5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: outPort, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s6),
          SizedBox(
            height: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
              child: Row(
                children: <Widget>[
                  Text(node.status, style: t.meta.copyWith(color: node.statusTone.fg(c))),
                  const Spacer(),
                  Text(node.meta, style: t.monoSmall.copyWith(color: c.fg5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 稿上三种 160° 渐变占位色（InkPalette.thumbPlaceholderGradients；接线后换真实缩略图）。
  static Gradient? _gradient(WsThumbGradient? g, InkColors c) {
    if (g == null) return null;
    final (Color a, Color b) = InkPalette.thumbPlaceholderGradients[g.index];
    // CSS 160deg：从左上偏上指向右下偏下。
    return LinearGradient(begin: const Alignment(-0.34, -1), end: const Alignment(0.34, 1), colors: <Color>[a, b]);
  }
}
