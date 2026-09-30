// 序列视图静态复刻页（B 路径，Timeline 稿 2026-09-25 版）：1600×1000——
//   菜单 30 | 标签 34 | 上半（叙事链 320 | 节目监视器 | 交付 320）| 序列区 300 | 状态栏 22。
// 拍板（2026-09-29）：只做上半 + 序列区；交付面板位置放空态占位（宽照稿 320，一行「交付随 P6 到来」+
// 禁用的目标软件分段选择器），比对时该列剔除。叙事链行不画 ⠿ 拖柄。
// 数据全部来自 SequenceFixture；尺寸全部按稿的 CSS（content-box：高/宽 + 边框）。
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/components/ws_primitives.dart';
import '../../theme/tokens.dart';
import 'models/sequence_fixture.dart';
import 'widgets/ws_menu_bar.dart' show WsSearchGlyph;

class SequenceV2Screen extends StatelessWidget {
  const SequenceV2Screen({super.key});

  static const Size designSize = SequenceFixture.designSize;

  /// 稿：上半 flex:1 = 1000 − 2 边 − 31 菜单 − 35 标签 − 300 序列 − 23 状态 = 609（含 1px 下沿）。
  static const double upperHeight = 609;
  static const double sideWidth = 320;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return DefaultTextStyle(
      style: context.inkTypography.body.copyWith(color: c.fg2),
      child: Container(
        width: designSize.width,
        height: designSize.height,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(color: c.surface2, border: Border.all(color: c.surface0)),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _MenuBar(),
            _TabBar(),
            SizedBox(
              height: upperHeight,
              child: _Upper(),
            ),
            _SequenceArea(),
            _StatusBar(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 菜单栏 / 标签栏 / 状态栏

/// 稿：30 高 + 1px 下沿，surface4；Logo | 六个菜单项 | 撑开 | 260 宽搜索入口（22 高底线）。
class _MenuBar extends StatelessWidget {
  const _MenuBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(color: c.surface4, border: Border(bottom: BorderSide(color: c.borderStrong))),
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
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(InkRadius.s3)),
                  child: Text('If', style: t.micro.copyWith(color: c.onAccent, fontWeight: FontWeight.w600, height: 1.0)),
                ),
                const SizedBox(width: InkSpacing.sm),
                Text('InkFrame', style: t.bodyStrong.copyWith(color: c.fg1)),
              ],
            ),
          ),
          for (final String item in SequenceFixture.menuItems)
            Container(
              height: 31,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
              alignment: Alignment.center,
              child: Text(item, style: t.body.copyWith(color: c.fg3)),
            ),
          const Spacer(),
          Container(
            width: 280,
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
            child: Row(
              children: <Widget>[
                CustomPaint(size: const Size(12, 12), painter: WsSearchGlyph(c.fg6)),
                const SizedBox(width: InkSpacing.s6),
                Expanded(child: Text(SequenceFixture.searchPlaceholder, style: t.body.copyWith(color: c.fg6))),
                Text('⌘K', style: t.monoSmall.copyWith(color: c.fg6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：34 高 + 1px 下沿；四标签（序列选中）| 竖线 | 面包屑 + 等宽格式串 | 撑开 | 三按钮。
class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    const List<String> crumbs = SequenceFixture.breadcrumb;
    return Container(
      height: 35,
      decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(width: InkSpacing.s12),
          for (int i = 0; i < SequenceFixture.tabs.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
              alignment: Alignment.center,
              decoration: i == SequenceFixture.activeTab
                  ? BoxDecoration(border: Border(bottom: BorderSide(color: c.accent, width: 2)))
                  : null,
              child: Text(
                SequenceFixture.tabs[i],
                style: i == SequenceFixture.activeTab ? t.bodyStrong.copyWith(color: c.fg1) : t.body.copyWith(color: c.fg4),
              ),
            ),
          Container(width: 1, margin: const EdgeInsets.symmetric(vertical: InkSpacing.sm, horizontal: InkSpacing.s6), color: c.control),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
            child: Row(
              children: <Widget>[
                Text(crumbs[0], style: t.body.copyWith(color: c.fg6)),
                const SizedBox(width: InkSpacing.xs),
                Text('›', style: t.body.copyWith(color: c.fg6)),
                const SizedBox(width: InkSpacing.xs),
                Text(crumbs[1], style: t.body.copyWith(color: c.fg6)),
                const SizedBox(width: InkSpacing.xs),
                Text('›', style: t.body.copyWith(color: c.fg6)),
                const SizedBox(width: InkSpacing.xs),
                Text(crumbs[2], style: t.body.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s10),
                Text(SequenceFixture.format, style: t.mono.copyWith(color: c.fg5)),
              ],
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Row(
              children: <Widget>[
                WsSecondaryButton(SequenceFixture.locateInCanvas),
                SizedBox(width: InkSpacing.s6),
                WsSecondaryButton(SequenceFixture.exportMp4),
                SizedBox(width: InkSpacing.s6),
                WsPrimaryButton(SequenceFixture.deliver, bordered: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：22 高 + 1px 上沿，surface4，11px fg5，项间 16。
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
      decoration: BoxDecoration(color: c.surface4, border: Border(top: BorderSide(color: c.borderStrong))),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < SequenceFixture.statusLeft.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: InkSpacing.md),
            Text(SequenceFixture.statusLeft[i], style: s),
          ],
          const Spacer(),
          Text(SequenceFixture.lastDelivery, style: s),
          const SizedBox(width: InkSpacing.md),
          Text(SequenceFixture.version, style: t.mono.copyWith(color: c.fg5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 上半

class _Upper extends StatelessWidget {
  const _Upper();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ChainPanel(),
          Expanded(child: _Monitor()),
          _DeliveryPlaceholder(),
        ],
      ),
    );
  }
}

/// 稿：面板页签 28 + 1px 下沿，surface2；选中页 surface3 底 + 1px 琥珀上沿 + fg1/500，其余 fg5。
class _PanelTabs extends StatelessWidget {
  const _PanelTabs({required this.tabs});
  final List<String> tabs;
  // 稿上两块面板都是第一页选中。
  static const int active = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 29,
      decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < tabs.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              alignment: Alignment.center,
              decoration: i == active
                  ? BoxDecoration(color: c.surface3, border: Border(top: BorderSide(color: c.accent)))
                  : null,
              child: Text(tabs[i], style: i == active ? t.bodyStrong.copyWith(color: c.fg1) : t.body.copyWith(color: c.fg5)),
            ),
        ],
      ),
    );
  }
}

/// 稿：320 宽 + 右沿 1，surface3；页签 | 表头 24 | 行 32 | 底部说明。
class _ChainPanel extends StatelessWidget {
  const _ChainPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TextStyle head = t.meta.copyWith(color: c.fg6);
    return Container(
      width: SequenceV2Screen.sideWidth + 1,
      decoration: BoxDecoration(color: c.surface3, border: Border(right: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PanelTabs(tabs: <String>[SequenceFixture.chainTab, SequenceFixture.unchainedTab]),
          Container(
            height: 25,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: _ChainGrid(
              a: Text(SequenceFixture.chainColumns[0], style: head),
              b: Text(SequenceFixture.chainColumns[1], style: head),
              c: Text(SequenceFixture.chainColumns[2], style: head),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < SequenceFixture.shots.length; i++) _ChainRow(index: i, shot: SequenceFixture.shots[i]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderStrong))),
            child: Text(SequenceFixture.chainNote, style: t.meta.copyWith(color: c.fg6, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// 稿：grid 1fr 56 40，gap 8。
class _ChainGrid extends StatelessWidget {
  const _ChainGrid({required this.a, required this.b, required this.c});
  final Widget a;
  final Widget b;
  final Widget c;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(child: a),
          const SizedBox(width: InkSpacing.sm),
          SizedBox(width: 56, child: b),
          const SizedBox(width: InkSpacing.sm),
          SizedBox(width: 40, child: c),
        ],
      );
}

/// 稿：行 32 + 下沿 1（#1A1A1A surface1）；序号 monoSmall fg6 宽 20 | 28×16 缩略 | 名称；片长 mono fg4；产物 meta。
class _ChainRow extends StatelessWidget {
  const _ChainRow({required this.index, required this.shot});
  final int index;
  final SqShot shot;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final Color nameColor = shot.placeholder ? c.fg5 : (shot.selected ? c.fg1 : c.fg3);
    return Container(
      height: 33,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        color: shot.selected ? c.surface5 : null,
        border: Border(bottom: BorderSide(color: c.surface1)),
      ),
      child: _ChainGrid(
        a: Row(
          children: <Widget>[
            SizedBox(width: 20, child: Text(SequenceFixture.idx(index), style: t.monoSmall.copyWith(color: c.fg6))),
            const SizedBox(width: InkSpacing.sm),
            _Thumb(index: index, width: 28, height: 16, placeholder: shot.placeholder, radius: InkRadius.xs),
            const SizedBox(width: InkSpacing.sm),
            Expanded(
              child: Text(shot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: nameColor)),
            ),
          ],
        ),
        b: Text(SequenceFixture.tcShort(shot.seconds), style: t.mono.copyWith(color: c.fg4)),
        c: Text(
          shot.placeholder ? SequenceFixture.stateMissing : SequenceFixture.stateVideo,
          style: t.meta.copyWith(color: shot.placeholder ? c.accent : c.fg5),
        ),
      ),
    );
  }
}

/// 缩略占位：稿的渐变就近取 thumbPlaceholderGradients；占位镜头纯 laneDivider 底。
class _Thumb extends StatelessWidget {
  const _Thumb({required this.index, this.width, this.height, this.placeholder = false, this.radius = InkRadius.s1, this.opacity = 1});
  final int index;
  final double? width;
  final double? height;
  final bool placeholder;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final (Color a, Color b) = InkPalette.thumbPlaceholderGradients[index % InkPalette.thumbPlaceholderGradients.length];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: placeholder ? c.laneDivider : null,
        gradient: placeholder
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[a.withValues(alpha: opacity), b.withValues(alpha: opacity)],
              ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 稿：监视器列 surface1；头 28 | 画面（16:9 居中，安全框虚线，底部叠字）| 播放条 3px + 传输控件行。
class _Monitor extends StatelessWidget {
  const _Monitor();

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
            height: 29,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Text(SequenceFixture.monitorTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s12),
                Container(width: 1, height: 12, color: c.control),
                const SizedBox(width: InkSpacing.s12),
                Text(SequenceFixture.monitorShot, style: t.body.copyWith(color: c.fg5)),
                const Spacer(),
                Text(SequenceFixture.safeFrame, style: t.body.copyWith(color: c.fg5)),
                const SizedBox(width: InkSpacing.s12),
                Text(SequenceFixture.fit, style: t.body.copyWith(color: c.fg5)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(InkSpacing.lg, InkSpacing.md, InkSpacing.lg, InkSpacing.sm),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _Frame(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.lg, InkSpacing.xs, InkSpacing.lg, InkSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _ScrubBar(),
                const SizedBox(height: InkSpacing.sm),
                // 稿：这一行 line-height normal（≈1.2），行高由 14px 的 ▶ 决定（≈17）；
                // 取 1.2 让画面区多出的 2px 回到稿的 16:9 框上。
                Row(
                  children: <Widget>[
                    Text(SequenceFixture.playhead, style: t.mono.copyWith(color: c.fg1, height: 1.2)),
                    const Spacer(),
                    for (int i = 0; i < SequenceFixture.transport.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: InkSpacing.s14),
                      Text(
                        SequenceFixture.transport[i],
                        style: i == SequenceFixture.transportPlayIndex
                            ? t.sectionTitle.copyWith(color: c.fg1, height: 1.2)
                            : t.body.copyWith(color: c.fg4, height: 1.2),
                      ),
                    ],
                    const Spacer(),
                    Text(SequenceFixture.total, style: t.mono.copyWith(color: c.fg4, height: 1.2)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：画面渐变（就近取 thumbPlaceholderGradients[2]）圆角 2 描边 outline；inset 10% 虚线安全框 accent@.3；底部叠字 mono 11 fg1@.75。
class _Frame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final (Color a, Color b) = InkPalette.thumbPlaceholderGradients[2];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[a, b]),
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(InkRadius.xs),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _SafeFramePainter(c.accent.withValues(alpha: 0.3), inset: 0.10),
              ),
            ),
            Positioned(
              left: InkSpacing.s12,
              right: InkSpacing.s12,
              bottom: InkSpacing.s10,
              child: Row(
                children: <Widget>[
                  Text(SequenceFixture.overlayLeft, style: t.mono.copyWith(color: c.fg1.withValues(alpha: 0.75))),
                  const Spacer(),
                  Text(SequenceFixture.overlayRight, style: t.mono.copyWith(color: c.fg1.withValues(alpha: 0.75))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 稿：inset 10% 的 1px 虚线框（CSS dashed，按 4/3 的段画）。
class _SafeFramePainter extends CustomPainter {
  const _SafeFramePainter(this.color, {required this.inset});
  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Rect.fromLTRB(size.width * inset, size.height * inset, size.width * (1 - inset), size.height * (1 - inset));
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const double dash = 3;
    const double gap = 3;
    void line(Offset a, Offset b) {
      final double len = (b - a).distance;
      final Offset dir = (b - a) / len;
      double t = 0;
      while (t < len) {
        final double e = (t + dash).clamp(0, len);
        canvas.drawLine(a + dir * t, a + dir * e, p);
        t += dash + gap;
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_SafeFramePainter old) => old.color != color || old.inset != inset;
}

/// 稿：3px 轨 control 圆角 2；已播 27% fg6；播放头 2×13 accent 在 27%，top −5。
class _ScrubBar extends StatelessWidget {
  const _ScrubBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double x = box.maxWidth * SequenceFixture.playedFraction;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(decoration: BoxDecoration(color: c.control, borderRadius: BorderRadius.circular(InkRadius.xs))),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: x,
                child: DecoratedBox(decoration: BoxDecoration(color: c.fg6, borderRadius: BorderRadius.circular(InkRadius.xs))),
              ),
              Positioned(left: x - 1, top: -5, width: 2, height: 13, child: ColoredBox(color: c.accent)),
            ],
          );
        },
      ),
    );
  }
}

/// 拍板：交付面板位置空态占位——页签照稿、目标软件分段选择器禁用态、一行「交付随 P6 到来」。比对时剔除此列。
class _DeliveryPlaceholder extends StatelessWidget {
  const _DeliveryPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: SequenceV2Screen.sideWidth + 1,
      decoration: BoxDecoration(color: c.surface3, border: Border(left: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PanelTabs(tabs: SequenceFixture.deliveryTabs),
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.s14, InkSpacing.s12, InkSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(SequenceFixture.targetLabel, style: t.body.copyWith(color: c.fg6)),
                const SizedBox(height: InkSpacing.s10),
                Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(border: Border.all(color: c.control), borderRadius: BorderRadius.circular(InkRadius.s3)),
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < SequenceFixture.targets.length; i++)
                        Expanded(
                          child: Container(
                            height: 26,
                            alignment: Alignment.center,
                            decoration: i == SequenceFixture.targets.length - 1
                                ? null
                                : BoxDecoration(border: Border(right: BorderSide(color: c.control))),
                            child: Text(SequenceFixture.targets[i], style: t.body.copyWith(color: c.fg6)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s10),
                Text(SequenceFixture.deliveryPlaceholder, style: t.meta.copyWith(color: c.fg6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 序列区

/// 稿：300 高，surface3；头 28 | 轨道头 96 + 轨道区（时间尺 26 / 标记 22 / V1 96 / A1 34）。
class _SequenceArea extends StatelessWidget {
  const _SequenceArea();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TextStyle dim = t.body.copyWith(color: c.fg5);
    return Container(
      height: 300,
      color: c.surface3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 29,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Text(SequenceFixture.sequenceTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s12),
                Text(SequenceFixture.playhead, style: t.mono.copyWith(color: c.accent)),
                const SizedBox(width: InkSpacing.s12),
                Container(width: 1, height: 12, color: c.control),
                const SizedBox(width: InkSpacing.s12),
                Text(SequenceFixture.snap, style: dim),
                const SizedBox(width: InkSpacing.s12),
                Text(SequenceFixture.linkVA, style: t.body.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s12),
                Text(SequenceFixture.markerKey, style: dim),
                const Spacer(),
                Text(SequenceFixture.totalPrefix, style: dim),
                Text(SequenceFixture.total, style: t.mono.copyWith(color: c.fg2)),
                const SizedBox(width: InkSpacing.s12),
                Text(SequenceFixture.countSummary, style: dim),
              ],
            ),
          ),
          const Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TrackHeads(),
                Expanded(child: _Tracks()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：96 宽 + 右沿 1，surface2；四行各带 1px 下沿：26 空 / 22 标记 / 96 V1 / 34 A1。
class _TrackHeads extends StatelessWidget {
  const _TrackHeads();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    Widget row(double h, Widget child) => Container(
          height: h + 1,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
          child: child,
        );
    return Container(
      width: 97,
      decoration: BoxDecoration(color: c.surface2, border: Border(right: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          row(26, const SizedBox.shrink()),
          row(22, Align(alignment: Alignment.centerLeft, child: Text(SequenceFixture.markerTrack, style: t.meta.copyWith(color: c.fg5)))),
          row(
            96,
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(SequenceFixture.v1, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(height: InkSpacing.xs),
                Text(SequenceFixture.v1Meta, style: t.meta.copyWith(color: c.fg6)),
              ],
            ),
          ),
          row(
            34,
            Row(
              children: <Widget>[
                Text(SequenceFixture.a1, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.sm),
                // 稿：「模型音轨 · 2」在 96 宽里折成两行（flex 不禁折行）。
                Expanded(
                  child: Text(SequenceFixture.a1Meta, maxLines: 2, style: t.meta.copyWith(color: c.fg6, height: 1.2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 轨道区：时间尺 26 | 标记轨 22 | V1 96 | A1 34（各 +1 下沿）+ 贯穿的播放头。
class _Tracks extends StatelessWidget {
  const _Tracks();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return ClipRect(
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 时间尺：每 5 s 一个刻度（1×8 overlayBorder 贴底）+ monoSmall 标签（top 5，left +4）。
              Container(
                height: 27,
                decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
                child: Stack(
                  children: <Widget>[
                    for (int s = 0; s <= SequenceFixture.tickMaxSeconds; s += SequenceFixture.tickEverySeconds) ...<Widget>[
                      Positioned(
                        left: SequenceFixture.px(s.toDouble()),
                        bottom: 1,
                        child: Container(width: 1, height: 8, color: c.overlayBorder),
                      ),
                      Positioned(
                        left: SequenceFixture.px(s.toDouble()) + InkSpacing.xs,
                        top: 5,
                        child: Text(SequenceFixture.tc(s.toDouble()), style: t.monoSmall.copyWith(color: c.fg6)),
                      ),
                    ],
                  ],
                ),
              ),
              // 标记轨：8px 菱形 + 10px 标签。
              Container(
                height: 23,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
                child: Stack(
                  children: <Widget>[
                    for (final SqMarker m in SequenceFixture.markers)
                      Positioned(
                        left: SequenceFixture.px(m.seconds),
                        top: 4,
                        child: Row(
                          children: <Widget>[
                            Transform.rotate(
                              angle: 0.7853981634,
                              child: Container(
                                width: 8,
                                height: 8,
                                color: switch (m.kind) {
                                  SqMarkerKind.scene => c.fg5,
                                  SqMarkerKind.breakpoint => c.accent,
                                  SqMarkerKind.missing => c.danger,
                                },
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(m.label, style: t.micro.copyWith(color: c.fg3)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // V1：每 170px 一根 1px 竖线底纹 + 片段。
              Container(
                height: 97,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: CustomPaint(painter: _RepeatLinesPainter(c.borderSubtle, period: 170))),
                    ..._clips(context),
                  ],
                ),
              ),
              // A1：22 高音轨片段。
              Container(
                height: 35,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
                child: Stack(
                  children: <Widget>[
                    for (final SqAudio a in SequenceFixture.audio)
                      Positioned(
                        left: SequenceFixture.px(a.seconds),
                        top: 6,
                        width: SequenceFixture.px(a.length) - 3,
                        height: 22,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s6),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: c.audioFill,
                            border: Border.all(color: c.audioBorder),
                            borderRadius: BorderRadius.circular(InkRadius.xs),
                          ),
                          child: Text(a.name, maxLines: 1, overflow: TextOverflow.clip, softWrap: false,
                              style: t.micro.copyWith(color: c.audioFg)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // 播放头：1px 琥珀竖线贯穿 + 顶部 13×9 三角。
          Positioned(left: SequenceFixture.playheadX, top: 0, bottom: 0, width: 1, child: ColoredBox(color: c.accent)),
          Positioned(
            left: SequenceFixture.playheadX - 6,
            top: 0,
            width: 13,
            height: 9,
            child: CustomPaint(painter: _TrianglePainter(c.accent)),
          ),
        ],
      ),
    );
  }

  List<Widget> _clips(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final List<Widget> out = <Widget>[];
    double acc = 0;
    for (int i = 0; i < SequenceFixture.shots.length; i++) {
      final SqShot s = SequenceFixture.shots[i];
      final double x = SequenceFixture.px(acc);
      final double w = SequenceFixture.px(s.seconds) - 3;
      acc += s.seconds;
      final Color fg = s.placeholder ? c.fg6 : c.fg2;
      out.add(Positioned(
        left: x,
        top: 8,
        width: w,
        height: 80,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  // 稿：选中 #33301F（就近取 accentWash）、未选中 #2A2A2A（laneDivider）、占位透明。
                  color: s.placeholder ? null : (s.selected ? c.accentWash : c.laneDivider),
                  borderRadius: BorderRadius.circular(InkRadius.s3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(InkSpacing.s3),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: _Thumb(index: i, placeholder: s.placeholder)),
                            const SizedBox(width: InkSpacing.s2),
                            Expanded(child: _Thumb(index: i, placeholder: s.placeholder, opacity: 0.85)),
                            const SizedBox(width: InkSpacing.s2),
                            Expanded(child: _Thumb(index: i, placeholder: s.placeholder, opacity: 0.7)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s6),
                        child: Row(
                          children: <Widget>[
                            Text(SequenceFixture.idx(i), style: t.monoSmall.copyWith(color: fg)),
                            const SizedBox(width: InkSpacing.s6),
                            Expanded(
                              child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false,
                                  style: t.micro.copyWith(color: fg)),
                            ),
                            const SizedBox(width: InkSpacing.s6),
                            Text(SequenceFixture.tc(s.seconds), style: t.monoSmall.copyWith(color: c.fg5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 稿的 outline（offset −1，盒内一圈）：选中琥珀 / 未选中 control / 占位 overlayBorder 虚线。
            Positioned.fill(
              child: IgnorePointer(
                child: s.placeholder
                    ? CustomPaint(painter: _DashedRectPainter(c.overlayBorder, radius: InkRadius.s3))
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: s.selected ? c.accent : c.control),
                          borderRadius: BorderRadius.circular(InkRadius.s3),
                        ),
                      ),
              ),
            ),
            // 已裁切：两端 4px 琥珀竖条。
            if (s.trimmed) ...<Widget>[
              Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: c.accent)),
              Positioned(right: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: c.accent)),
            ],
          ],
        ),
      ));
    }
    return out;
  }
}

/// 稿：repeating-linear-gradient(90deg, transparent 0 169px, #1F1F1F 169px 170px)。
class _RepeatLinesPainter extends CustomPainter {
  const _RepeatLinesPainter(this.color, {required this.period});
  final Color color;
  final double period;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    for (double x = period - 1; x < size.width; x += period) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_RepeatLinesPainter old) => old.color != color || old.period != period;
}

/// 1px 虚线圆角框（CSS outline: 1px dashed，offset −1）。
class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter(this.color, {required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1), Radius.circular(radius)));
    const double dash = 3;
    const double gap = 3;
    for (final PathMetric metric in path.computeMetrics()) {
      double t = 0;
      while (t < metric.length) {
        final double e = (t + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(t, e), p);
        t += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color || old.radius != radius;
}

/// 稿：clip-path polygon(0 0, 100% 0, 50% 100%) 的 13×9 三角。
class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
