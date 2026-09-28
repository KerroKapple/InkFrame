// 画廊静态复刻页（B 路径，Screens 稿第 2 屏）：1600×1000，
// 菜单栏 30 → 标签栏 34 → 主体（筛选 220 | 网格 flex | 信息 320）→ 状态栏 22。
// 数据全部来自 GalleryFixture；尺寸全部按稿的 CSS（content-box：高/宽 + 边框）。
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/components/ws_primitives.dart';
import '../../theme/tokens.dart';
import 'models/gallery_fixture.dart';
import 'widgets/ws_menu_bar.dart' show WsSearchGlyph;

class GalleryV2Screen extends StatelessWidget {
  const GalleryV2Screen({super.key});

  static const Size designSize = Size(1600, 1000);

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return DefaultTextStyle(
      style: context.inkTypography.body.copyWith(color: c.fg2),
      child: Container(
        width: designSize.width,
        height: designSize.height,
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.borderStrong),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _MenuBar(),
            _TabBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _FilterPanel(),
                  Expanded(child: _GridArea()),
                  _InfoPanel(),
                ],
              ),
            ),
            _StatusBar(),
          ],
        ),
      ),
    );
  }
}

/// 稿：height 30 + border-bottom 1；Logo 组 | 撑开 | 280 宽搜索底线字段。
class _MenuBar extends StatelessWidget {
  const _MenuBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
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
          const Spacer(),
          Container(
            width: 280,
            height: 23, // content 22 + border-bottom 1
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
            child: Row(
              children: <Widget>[
                CustomPaint(size: const Size(12, 12), painter: WsSearchGlyph(c.fg6)),
                const SizedBox(width: InkSpacing.s6),
                Expanded(child: Text(GalleryFixture.searchPlaceholder, style: t.body.copyWith(color: c.fg6))),
                Text('⌘K', style: t.monoSmall.copyWith(color: c.fg6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：height 34 + border-bottom 1；标签 | 1px 竖线 | 面包屑 + 计数 | 撑开 | 两个次级按钮。
class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(width: InkSpacing.s12),
          for (int i = 0; i < GalleryFixture.tabs.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
              alignment: Alignment.center,
              decoration: i == GalleryFixture.activeTab
                  ? BoxDecoration(border: Border(bottom: BorderSide(color: c.accent, width: 2)))
                  : null,
              child: Text(
                GalleryFixture.tabs[i],
                style: i == GalleryFixture.activeTab
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
                Text(GalleryFixture.breadcrumb[0], style: t.body.copyWith(color: c.fg6)),
                const SizedBox(width: InkSpacing.xs),
                Text('›', style: t.body.copyWith(color: c.fg6)),
                const SizedBox(width: InkSpacing.xs),
                Text(GalleryFixture.breadcrumb[1], style: t.body.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s10),
                Text(GalleryFixture.counts, style: t.mono.copyWith(color: c.fg5)),
              ],
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Row(
              children: <Widget>[
                WsSecondaryButton(GalleryFixture.sendToCanvas),
                SizedBox(width: InkSpacing.s6),
                WsSecondaryButton(GalleryFixture.saveAsCharacter),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：width 220 + border-right 1，surface3；四个分组各带 1px 下边。
class _FilterPanel extends StatelessWidget {
  const _FilterPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: 221,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final GaFilterGroup g in GalleryFixture.filters)
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _GroupHeader(title: g.title),
                  Padding(
                    padding: const EdgeInsets.only(bottom: InkSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final GaFilterItem i in g.items)
                          Container(
                            height: 24,
                            padding: const EdgeInsets.only(left: InkSpacing.s26, right: InkSpacing.s12),
                            color: i.selected ? c.surface5 : null,
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    i.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.body.copyWith(color: i.selected ? c.fg1 : c.fg3),
                                  ),
                                ),
                                const SizedBox(width: InkSpacing.sm),
                                Text(i.count, style: t.monoSmall.copyWith(color: c.fg6)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 稿：26 高，padding 0 12，gap 6：9px ▼（fg5）+ 标题（fg3 500）。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      child: Row(
        children: <Widget>[
          Text('▼', style: t.micro.copyWith(color: c.fg5)),
          const SizedBox(width: InkSpacing.s6),
          Text(title, style: t.bodyStrong.copyWith(color: c.fg3)),
        ],
      ),
    );
  }
}

/// 稿：surface1；工具行 32 + border-bottom 1；网格 padding 16，5 列 gap 12。
class _GridArea extends StatelessWidget {
  const _GridArea();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return ColoredBox(
      color: c.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 33,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Text(GalleryFixture.gridTitle, style: t.body.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s14),
                Text(GalleryFixture.gridCount, style: t.mono.copyWith(color: c.fg5)),
                const Spacer(),
                Text(GalleryFixture.hoverAutoplay, style: t.body.copyWith(color: c.fg5)),
                for (int i = 0; i < GalleryFixture.sizes.length; i++) ...<Widget>[
                  const SizedBox(width: InkSpacing.s14),
                  Text(
                    GalleryFixture.sizes[i],
                    style: t.body.copyWith(color: i == GalleryFixture.activeSize ? c.fg1 : c.fg5),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(InkSpacing.md),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  const int cols = 5;
                  final double w = (box.maxWidth - InkSpacing.s12 * (cols - 1)) / cols;
                  final List<GaItem> items = GalleryFixture.items;
                  return Wrap(
                    spacing: InkSpacing.s12,
                    runSpacing: InkSpacing.s12,
                    children: <Widget>[
                      for (final GaItem g in items) SizedBox(width: w, child: _Tile(item: g)),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：图区 16:9 圆角 3、outline 1px 画在盒内；下方 gap 6 的序号 + 名称行。
class _Tile extends StatelessWidget {
  const _Tile({required this.item});
  final GaItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final (Color a, Color b) = InkPalette.thumbPlaceholderGradients[item.thumb];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[a, b],
              ),
              border: Border.all(color: item.isCurrent ? c.accent : c.outline),
              borderRadius: BorderRadius.circular(InkRadius.s3),
            ),
            child: Stack(
              children: <Widget>[
                if (item.isVideo)
                  Positioned(
                    left: 7,
                    bottom: 5,
                    child: Row(
                      children: <Widget>[
                        Text('▶', style: t.monoSmall.copyWith(color: c.fg1.withValues(alpha: 0.85))),
                        const SizedBox(width: 5),
                        Text(item.dur, style: t.monoSmall.copyWith(color: c.fg1.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                if (item.selected)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Container(
                      width: 14,
                      height: 14,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(InkRadius.s3),
                      ),
                      child: Text('✓', style: t.micro.copyWith(color: c.onAccent, height: 1.0)),
                    ),
                  ),
                if (item.isCurrent)
                  Positioned(
                    left: 5,
                    top: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s6, vertical: InkSpacing.s2),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(InkRadius.xs),
                      ),
                      child: Text('当前线', style: t.micro.copyWith(color: c.onAccent, height: 1.0)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.s6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(item.idx, style: t.monoSmall.copyWith(color: c.fg6)),
            const SizedBox(width: InkSpacing.s6),
            Expanded(
              child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.meta.copyWith(color: c.fg4)),
            ),
          ],
        ),
      ],
    );
  }
}

/// 稿：width 320 + border-left 1，surface3；28 标签条 | 内容 | 底部动作条。
class _InfoPanel extends StatelessWidget {
  const _InfoPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final (Color pa, Color pb) = InkPalette.thumbPlaceholderGradients[2];
    return Container(
      width: 321,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(left: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WsPanelTabs(tabs: GalleryFixture.panelTabs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(InkSpacing.s12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[pa, pb],
                        ),
                        border: Border.all(color: c.outline),
                        borderRadius: BorderRadius.circular(InkRadius.s3),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(InkSpacing.s12, 0, InkSpacing.s12, InkSpacing.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(GalleryFixture.itemName, style: t.body.copyWith(color: c.fg1)),
                      const SizedBox(height: InkSpacing.xs),
                      Text(GalleryFixture.itemSource, style: t.meta.copyWith(color: c.fg6)),
                    ],
                  ),
                ),
                for (final GaMetaGroup g in GalleryFixture.meta)
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderStrong))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _GroupHeader(title: g.title),
                        Padding(
                          padding: const EdgeInsets.only(top: InkSpacing.s2, bottom: InkSpacing.s10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[for (final GaMetaRow r in g.rows) _MetaRow(row: r)],
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(InkSpacing.s12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderStrong))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(GalleryFixture.lineageTitle, style: t.body.copyWith(color: c.fg4)),
                      for (final GaLineage l in GalleryFixture.lineage) ...<Widget>[
                        const SizedBox(height: InkSpacing.s10),
                        _LineageRow(row: l),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s10),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(top: BorderSide(color: c.borderStrong)),
            ),
            child: const Row(
              children: <Widget>[
                WsSecondaryButton(GalleryFixture.locateInCanvas, height: 26),
                Spacer(),
                WsPrimaryButton(GalleryFixture.deriveNode, height: 26, bordered: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：grid 84px 1fr，gap 8，min-height 24，padding 2 12，基线对齐；值 line-height 1.45 可换行。
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.row});
  final GaMetaRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      // 稿是 content-box：min-height 24 + padding 2×2 ⇒ 外框最小 28。
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          SizedBox(width: 84, child: Text(row.label, style: t.body.copyWith(color: c.fg4))),
          const SizedBox(width: InkSpacing.sm),
          Expanded(child: Text(row.value, style: t.body.copyWith(color: c.fg2))),
        ],
      ),
    );
  }
}

/// 稿：40×24 缩略图（圆角 2，outline 1px 盒内）+ 名称 11px / 关系 10px + 右侧分支数 10px。
class _LineageRow extends StatelessWidget {
  const _LineageRow({required this.row});
  final GaLineage row;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final int? g = row.thumb;
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 24,
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
            border: Border.all(color: row.current ? c.accent : c.outline),
            borderRadius: BorderRadius.circular(InkRadius.xs),
          ),
        ),
        const SizedBox(width: InkSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.meta.copyWith(color: row.current ? c.fg1 : c.fg4)),
              // 稿里这行 10px 继承 1.45 行高（实测行距 16 / 15），不是 micro 的 1.3。
              Text(row.rel, style: t.micro.copyWith(color: c.fg6, height: 1.45)),
            ],
          ),
        ),
        if (row.branchLabel.isNotEmpty) ...<Widget>[
          const SizedBox(width: InkSpacing.s10),
          Text(row.branchLabel, style: t.micro.copyWith(color: c.fg5)),
        ],
      ],
    );
  }
}

/// 稿：height 22 + border-top 1；gap 16；11px fg5；右侧等宽版本号。
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TextStyle s = t.meta.copyWith(color: c.fg5);
    return Container(
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Text(GalleryFixture.statusCount, style: s),
          const SizedBox(width: InkSpacing.md),
          Text(GalleryFixture.statusHint, style: s),
          const Spacer(),
          Text(GalleryFixture.version, style: t.mono.copyWith(color: c.fg5)),
        ],
      ),
    );
  }
}
