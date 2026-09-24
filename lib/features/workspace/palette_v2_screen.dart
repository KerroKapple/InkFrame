// 命令面板静态复刻页（B 路径，Screens 稿第 4 屏右）：788×620 的一块——
// 22px 点阵底 + 半透明遮罩 + 距顶 64、宽 620 的面板（44 输入行 | 分组 24 + 行 34 | 32 提示条）。
// 数据全部来自 PaletteFixture；尺寸全部按稿的 CSS（content-box：高/宽 + 边框）。
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'models/palette_fixture.dart';

class PaletteV2Screen extends StatelessWidget {
  const PaletteV2Screen({super.key});

  static const Size designSize = PaletteFixture.designSize;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return DefaultTextStyle(
      style: context.inkTypography.body.copyWith(color: c.fg2),
      child: Container(
        width: designSize.width,
        height: designSize.height,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: c.surface1,
          border: Border.all(color: c.borderStrong),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter(c.canvasGrid))),
            Positioned.fill(child: ColoredBox(color: c.scrim)),
            Positioned(
              // 稿：left 50% + translateX(-50%)；边框盒内宽 786。
              left: (designSize.width - 2 - PaletteFixture.panelWidth) / 2,
              top: PaletteFixture.panelTop,
              width: PaletteFixture.panelWidth,
              child: const _Panel(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 稿：radial-gradient(#242424 1px, transparent 1px) / 22px——每格左上一个 1px 点。
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    const double step = 22;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

/// 稿：surface4 底 + 1px overlayBorder + 圆角 6 + 阴影 0 24 64 rgba(0,0,0,.65)。
class _Panel extends StatelessWidget {
  const _Panel();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border.all(color: c.overlayBorder),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.overlay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _QueryRow(),
          for (final PaGroup g in PaletteFixture.groups) _Group(group: g),
          const _Footer(),
        ],
      ),
    );
  }
}

/// 稿：44 高 + 1px borderSubtle 下沿，padding 0 16，gap 10：⌘K（琥珀等宽 11）| 查询 13px + 琥珀光标 | 「12 条结果」。
class _QueryRow extends StatelessWidget {
  const _QueryRow();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderSubtle))),
      child: Row(
        children: <Widget>[
          Text(PaletteFixture.badge, style: t.mono.copyWith(color: c.accent)),
          const SizedBox(width: InkSpacing.s10),
          Expanded(
            child: Row(
              children: <Widget>[
                // 稿是 13px；typography 没有 13 档，用 body（12）——字形差异按预期看。
                Text(PaletteFixture.query, style: t.body.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s2),
                Container(width: 1, height: 15, color: c.accent),
              ],
            ),
          ),
          const SizedBox(width: InkSpacing.s10),
          Text(PaletteFixture.resultCount, style: t.meta.copyWith(color: c.fg6)),
        ],
      ),
    );
  }
}

/// 稿：组标题 24 高 surface3 底 10px fg6 letter-spacing .6；行 min 34（padding 4 16，gap 12）。
class _Group extends StatelessWidget {
  const _Group({required this.group});
  final PaGroup group;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
          color: c.surface3,
          alignment: Alignment.centerLeft,
          child: Text(group.title, style: t.micro.copyWith(color: c.fg6, letterSpacing: 0.6)),
        ),
        for (final PaRow r in group.rows) _RowView(row: r),
      ],
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({required this.row});
  final PaRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final int? g = row.thumb;
    return Container(
      // 稿是 content-box：min-height 34 + padding 4×2 ⇒ 外框最小 42。
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md, vertical: InkSpacing.xs),
      color: row.selected ? c.surface5 : null,
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 18,
            decoration: BoxDecoration(
              color: g == null ? c.surface4 : null,
              gradient: g == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        InkPalette.thumbPlaceholderGradients[g].$1,
                        InkPalette.thumbPlaceholderGradients[g].$2,
                      ],
                    ),
              borderRadius: BorderRadius.circular(InkRadius.xs),
            ),
          ),
          const SizedBox(width: InkSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: row.selected ? c.fg1 : c.fg2)),
                Text(row.path, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.micro.copyWith(color: c.fg6, height: 1.45)),
              ],
            ),
          ),
          if (row.hint.isNotEmpty) ...<Widget>[
            const SizedBox(width: InkSpacing.s12),
            Text(row.hint, style: t.monoSmall.copyWith(color: c.fg6)),
          ],
        ],
      ),
    );
  }
}

/// 稿：32 高 surface3 底 + 1px borderSubtle 上沿，gap 14，10px fg6。
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TextStyle s = t.micro.copyWith(color: c.fg6);
    return Container(
      height: 33,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(top: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < PaletteFixture.footerHints.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: InkSpacing.s14),
            Text(PaletteFixture.footerHints[i], style: s),
          ],
          const Spacer(),
          Text(PaletteFixture.footerClose, style: s),
        ],
      ),
    );
  }
}
