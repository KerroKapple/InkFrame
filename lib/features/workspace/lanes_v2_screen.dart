// 风格泳道静态复刻页（B 路径，Lanes 稿 01 / 02 / 03）：
//   01 横向泳道 1280×620（四条道：两条展开、一条折叠 36、一条空道；五个节点带「继承」行；分界线高亮；工具栏）
//   02 竖向泳道 760×480（三条道，标题栏转道首横条；四个节点；工具栏）
//   03 泳道编辑框 456 宽（名称 / 风格提示词 / 底色 / 预览；底部条）
// 三块按稿的排布放在同一张图里（01 在上，02 / 03 并排在下，间距 24），比对时按块裁。
// 数据全部来自 LanesFixture；尺寸全部按稿的 CSS（content-box：高/宽 + 边框）。
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../canvas/util/lane_tint.dart';
import 'models/lanes_fixture.dart';

class LanesV2Screen extends StatelessWidget {
  const LanesV2Screen({super.key});

  /// 1280 × (620 + 24 + 480)。
  static const Size designSize = Size(1280, 1124);

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return DefaultTextStyle(
      style: context.inkTypography.body.copyWith(color: c.fg2),
      child: SizedBox(
        width: designSize.width,
        height: designSize.height,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _HorizontalPanel(),
            SizedBox(height: LanesFixture.gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _VerticalPanel(),
                SizedBox(width: LanesFixture.gap),
                _EditDialog(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 稿：画布底 surface1 + 24px 线格（#222222 canvasGrid）+ 1px surface0 边框（border-box）。
class _CanvasPanel extends StatelessWidget {
  const _CanvasPanel({required this.size, required this.children});
  final Size size;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      width: size.width,
      height: size.height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: c.surface1, border: Border.all(color: c.surface0)),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: _LineGridPainter(c.canvasGrid))),
          ...children,
        ],
      ),
    );
  }
}

class _LineGridPainter extends CustomPainter {
  const _LineGridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    const double step = 24;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
    for (double x = 0; x < size.width; x += step) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_LineGridPainter old) => old.color != color;
}

Color _hex(BuildContext context, String hex) => parseHexColor(hex) ?? context.inkColors.control;

// ---------------------------------------------------------------- 01 横向

class _HorizontalPanel extends StatelessWidget {
  const _HorizontalPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return _CanvasPanel(
      size: LanesFixture.hSize,
      children: <Widget>[
        // 道体：弱底色（hex + 1A = alpha .10）+ 上沿 1px 分界线 + 道首 3px 色轨。
        for (final LaHLane l in LanesFixture.hLanes)
          Positioned(
            left: 0,
            right: 0,
            top: l.top,
            height: l.height,
            child: Container(
              decoration: BoxDecoration(
                color: l.empty ? null : _hex(context, l.hex).withValues(alpha: 0.10),
                border: Border(top: BorderSide(color: c.laneDivider)),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 3, color: _hex(context, l.hex)),
              ),
            ),
          ),
        // 标题栏：left 14、top = 道顶 + 14、宽 268、高 26。
        for (final LaHLane l in LanesFixture.hLanes)
          Positioned(
            left: 14,
            top: l.top + 14 - (l.collapsed ? 2 : 0),
            width: 268,
            height: 26,
            child: l.collapsed ? _CollapsedBar(lane: l) : _HBar(lane: l),
          ),
        for (final LaNode n in LanesFixture.hNodes)
          Positioned(left: n.x, top: n.y, width: 196, child: _HNode(node: n)),
        // 稿：拖拽分界线的 3px 琥珀高亮 + 提示。
        Positioned(
          left: 0,
          right: 0,
          top: LanesFixture.resizeHighlightTop,
          height: 3,
          child: ColoredBox(color: c.accent),
        ),
        Positioned(
          right: 16,
          top: 336,
          child: Text(LanesFixture.resizeHint, style: t.micro.copyWith(color: c.accent)),
        ),
        const Positioned(right: 14, bottom: 14, child: _Toolbar(horizontal: true)),
      ],
    );
  }
}

/// 稿：rgba(38,38,38,.82) 底、圆角 3、padding 0 6 0 10、gap 8；8×8 色点 | 两行 | 等宽计数 | 三个 18×18 键。
class _HBar extends StatelessWidget {
  const _HBar({required this.lane});
  final LaHLane lane;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      padding: const EdgeInsets.only(left: InkSpacing.s10, right: InkSpacing.s6),
      decoration: BoxDecoration(
        color: c.surface4.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        children: <Widget>[
          _Dot(size: 8, color: _hex(context, lane.hex)),
          const SizedBox(width: InkSpacing.sm),
          Expanded(
            // 稿：两行 line-height 1.2 + gap 1 = 27.4，在 26 的栏里居中溢出（CSS 不裁）；
            // OverflowBox 复现同样的居中溢出，不让 Column 报 1px 溢出条。
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(lane.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(color: c.fg1, height: 1.2)),
                  const SizedBox(height: 1),
                  Text(lane.prompt, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.micro.copyWith(color: c.fg5, height: 1.2)),
                ],
              ),
            ),
          ),
          const SizedBox(width: InkSpacing.sm),
          Text(lane.count, style: t.monoSmall.copyWith(color: c.fg6)),
          const SizedBox(width: InkSpacing.sm),
          const _IconKey(LanesFixture.glyphCollapse, size: 12),
          const SizedBox(width: InkSpacing.s2),
          const _IconKey(LanesFixture.glyphEdit, size: 10),
          const SizedBox(width: InkSpacing.s2),
          const _IconKey(LanesFixture.glyphDelete, size: 11),
        ],
      ),
    );
  }
}

/// 稿：折叠态标题栏——名称 fg4 单行 | 计数 | 「已折叠」| 展开键。
class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({required this.lane});
  final LaHLane lane;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      padding: const EdgeInsets.only(left: InkSpacing.s10, right: InkSpacing.s6),
      decoration: BoxDecoration(
        color: c.surface4.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        children: <Widget>[
          _Dot(size: 8, color: _hex(context, lane.hex)),
          const SizedBox(width: InkSpacing.sm),
          Expanded(
            child: Text(lane.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg4)),
          ),
          const SizedBox(width: InkSpacing.sm),
          Text(lane.count, style: t.monoSmall.copyWith(color: c.fg6)),
          const SizedBox(width: InkSpacing.sm),
          Text(LanesFixture.collapsedTag, style: t.micro.copyWith(color: c.fg6)),
          const SizedBox(width: InkSpacing.sm),
          const _IconKey(LanesFixture.glyphExpand, size: 12),
        ],
      ),
    );
  }
}

/// 稿：196 宽；16 高名称行（名称 500 fg1 + 类型 10px fg5）| 16:9 图区圆角 4 描边 | 14 高继承行。
class _HNode extends StatelessWidget {
  const _HNode({required this.node});
  final LaNode node;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 16,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(color: c.fg1)),
                ),
                const SizedBox(width: InkSpacing.s6),
                Text(node.kind ?? '', style: t.micro.copyWith(color: c.fg5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        _Thumb(index: node.thumb, outline: node.selected ? c.accent : c.outline),
        const SizedBox(height: 5),
        SizedBox(
          height: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
            child: Row(
              children: <Widget>[
                _Dot(size: 6, color: _hex(context, node.railHex!)),
                const SizedBox(width: InkSpacing.s6),
                Text('${LanesFixture.inheritPrefix}${node.laneName}', style: t.micro.copyWith(color: c.fg5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 02 竖向

class _VerticalPanel extends StatelessWidget {
  const _VerticalPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return _CanvasPanel(
      size: LanesFixture.vSize,
      children: <Widget>[
        for (final LaVLane l in LanesFixture.vLanes)
          Positioned(
            top: 0,
            bottom: 0,
            left: l.left,
            width: l.width,
            child: Container(
              decoration: BoxDecoration(
                color: _hex(context, l.hex).withValues(alpha: 0.10),
                border: Border(left: BorderSide(color: c.laneDivider)),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(height: 3, color: _hex(context, l.hex)),
              ),
            ),
          ),
        // 标题栏：top 14、left = 道左 + 12、宽 min(道宽 − 24, 240)。
        for (final LaVLane l in LanesFixture.vLanes)
          Positioned(
            top: 14,
            left: l.left + 12,
            width: (l.width - 24).clamp(0, 240).toDouble(),
            height: 26,
            child: _VBar(lane: l),
          ),
        for (final LaNode n in LanesFixture.vNodes)
          Positioned(left: n.x, top: n.y, width: 168, child: _VNode(node: n)),
        const Positioned(right: 14, bottom: 14, child: _Toolbar(horizontal: false)),
      ],
    );
  }
}

/// 稿：padding 0 6 0 9、gap 7；色点 | 名称 500 | 计数 | ⋯。
class _VBar extends StatelessWidget {
  const _VBar({required this.lane});
  final LaVLane lane;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      // 稿：padding-left 9 = sm + 1。
      padding: const EdgeInsets.only(left: InkSpacing.sm, right: InkSpacing.s6),
      decoration: BoxDecoration(
        color: c.surface4.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 1),
          _Dot(size: 8, color: _hex(context, lane.hex)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(lane.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(color: c.fg1)),
          ),
          const SizedBox(width: 7),
          Text(lane.count, style: t.monoSmall.copyWith(color: c.fg6)),
          const SizedBox(width: 7),
          const _IconKey(LanesFixture.glyphMore, size: 12),
        ],
      ),
    );
  }
}

/// 稿：168 宽；15 高名称行 | 16:9 图区。
class _VNode extends StatelessWidget {
  const _VNode({required this.node});
  final LaNode node;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 15,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
            child: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(color: c.fg1)),
          ),
        ),
        const SizedBox(height: 5),
        _Thumb(index: node.thumb, outline: c.outline),
      ],
    );
  }
}

// ---------------------------------------------------------------- 03 编辑框

/// 稿：456 宽，surface3 + 1px control + 圆角 6 + 浮层阴影；38 标题栏 | 表单 padding 16 14 gap 16 | 底部条 padding 12 14。
class _EditDialog extends StatelessWidget {
  const _EditDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TextStyle label = t.body.copyWith(color: c.fg4);
    final TextStyle note = t.micro.copyWith(color: c.fg6, height: 1.5);
    return Container(
      width: LanesFixture.dialogWidth + 2,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.overlay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 39,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14),
            decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Text(LanesFixture.dialogTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                const Spacer(),
                Text(LanesFixture.dialogClose, style: t.body.copyWith(color: c.fg5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14, vertical: InkSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(LanesFixture.fieldName, style: label),
                const SizedBox(height: InkSpacing.s6),
                Container(
                  height: 25,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(LanesFixture.nameValue, style: t.body.copyWith(color: c.fg1)),
                      const SizedBox(width: InkSpacing.s2),
                      Container(width: 1, height: 13, color: c.accent),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.md),
                Text(LanesFixture.fieldPrompt, style: label),
                const SizedBox(height: InkSpacing.s6),
                Container(
                  constraints: const BoxConstraints(minHeight: 56 + 12 + 1),
                  padding: const EdgeInsets.symmetric(vertical: InkSpacing.s6),
                  alignment: Alignment.topLeft,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
                  child: Text(LanesFixture.promptValue, style: t.body.copyWith(color: c.fg2, height: 1.5)),
                ),
                const SizedBox(height: InkSpacing.s6),
                Text(LanesFixture.promptNote, style: note),
                const SizedBox(height: InkSpacing.md),
                Text(LanesFixture.fieldTint, style: label),
                const SizedBox(height: InkSpacing.sm),
                Row(
                  children: <Widget>[
                    Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface4,
                        border: Border.all(color: c.control),
                        borderRadius: BorderRadius.circular(InkRadius.sm),
                      ),
                      child: Text(LanesFixture.tintAuto, style: t.meta.copyWith(color: c.fg5)),
                    ),
                    for (final String hex in LanesFixture.swatches) ...<Widget>[
                      const SizedBox(width: InkSpacing.sm),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _hex(context, hex),
                          border: Border.all(color: c.control),
                          borderRadius: BorderRadius.circular(InkRadius.sm),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: InkSpacing.sm),
                Text(LanesFixture.tintNote, style: note),
                const SizedBox(height: InkSpacing.md),
                Text(LanesFixture.fieldPreview, style: label),
                const SizedBox(height: InkSpacing.s6),
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: _hex(context, LanesFixture.previewHex).withValues(alpha: 0.15),
                    border: Border.all(color: c.control),
                    borderRadius: BorderRadius.circular(InkRadius.sm),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14, vertical: InkSpacing.s12),
            decoration: BoxDecoration(color: c.surface2, border: Border(top: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Text(LanesFixture.footerNote, style: t.micro.copyWith(color: c.fg6)),
                const Spacer(),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: c.controlStrong),
                    borderRadius: BorderRadius.circular(InkRadius.s3),
                  ),
                  child: Text(LanesFixture.cancel, style: t.body.copyWith(color: c.fg2)),
                ),
                const SizedBox(width: InkSpacing.sm),
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(InkRadius.s3)),
                  child: Text(LanesFixture.save, style: t.bodyStrong.copyWith(color: c.onAccent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 共用小件

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double radius = size >= 8 ? InkRadius.xs : InkRadius.s1;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// 稿：18×18、圆角 2、fg4 的字形键。
class _IconKey extends StatelessWidget {
  const _IconKey(this.glyph, {required this.size});
  final String glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TextStyle base = size <= 10 ? t.micro : (size <= 11 ? t.meta : t.body);
    return SizedBox(
      width: 18,
      height: 18,
      child: Center(child: Text(glyph, style: base.copyWith(color: c.fg4, height: 1.0))),
    );
  }
}

/// 稿：16:9 图区，圆角 4，1px 描边（outline-offset −1 ⇒ 描边在盒内）。
class _Thumb extends StatelessWidget {
  const _Thumb({required this.index, required this.outline});
  final int index;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    final (Color a, Color b) = InkPalette.thumbPlaceholderGradients[index % InkPalette.thumbPlaceholderGradients.length];
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[a, b]),
          border: Border.all(color: outline),
          borderRadius: BorderRadius.circular(InkRadius.sm),
        ),
      ),
    );
  }
}

/// 稿：右下角工具栏——surface4 底 + control 边 + 圆角 3；「+」30×26 带右分隔 | 方向键（字形 + 文字）。
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.horizontal});
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 30,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: c.control))),
            child: Text(LanesFixture.toolbarAdd, style: t.sectionTitle.copyWith(color: c.fg3, height: 1.0)),
          ),
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
            child: Row(
              children: <Widget>[
                Text(horizontal ? LanesFixture.toolbarHorizontalGlyph : LanesFixture.toolbarVerticalGlyph,
                    style: t.body.copyWith(color: c.fg3, height: 1.0)),
                const SizedBox(width: InkSpacing.s6),
                Text(horizontal ? LanesFixture.toolbarHorizontal : LanesFixture.toolbarVertical,
                    style: t.meta.copyWith(color: c.fg3, height: 1.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
