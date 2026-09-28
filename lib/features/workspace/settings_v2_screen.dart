// 设置浮层静态复刻页（B 路径，Screens 稿第 3 屏）：1600×1000——
// 24px 线格底 + 半透明遮罩 + 居中 1120×740 对话框（40 标题栏 | 左导航 200 + 内容 | 44 底部条）。
// 数据全部来自 SettingsFixture；尺寸全部按稿的 CSS（content-box：高/宽 + 边框）。
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'models/settings_fixture.dart';

class SettingsV2Screen extends StatelessWidget {
  const SettingsV2Screen({super.key});

  static const Size designSize = SettingsFixture.designSize;

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
          border: Border.all(color: c.surface0),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: CustomPaint(painter: _LineGridPainter(c.borderSubtle.withValues(alpha: 0.5)))),
            Positioned.fill(child: ColoredBox(color: c.scrim)),
            const Center(child: _Dialog()),
          ],
        ),
      ),
    );
  }
}

/// 稿：linear-gradient(#1F1F1F 1px, transparent 1px) 横纵各一，24px 一格，opacity .5。
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

/// 稿：1120×740 content + 1px #3A3A3A（control）+ 圆角 6 + 0 24px 64px 阴影，#232323（surface3）底。
class _Dialog extends StatelessWidget {
  const _Dialog();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      width: SettingsFixture.dialogSize.width + 2,
      height: SettingsFixture.dialogSize.height + 2,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.overlay,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TitleBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Nav(),
                // 稿：内容列 overflow: auto。
                Expanded(child: SingleChildScrollView(child: _Content())),
              ],
            ),
          ),
          _Footer(),
        ],
      ),
    );
  }
}

/// 稿：40 高 + 1px 下沿，#1D1D1D（surface2）；「设置」500 | 撑开 | Esc 等宽 10 | ✕。
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 41,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Text(SettingsFixture.title, style: t.bodyStrong.copyWith(color: c.fg1)),
          const Spacer(),
          Text(SettingsFixture.escHint, style: t.monoSmall.copyWith(color: c.fg6)),
          const SizedBox(width: InkSpacing.s12),
          Text(SettingsFixture.close, style: t.body.copyWith(color: c.fg5)),
        ],
      ),
    );
  }
}

/// 稿：宽 200 + 右沿 1，padding 10 0，#1F1F1F 底（就近取 surface2）；行 30 高 padding 0 16，左边框 2。
class _Nav extends StatelessWidget {
  const _Nav();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: 201,
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s10),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < SettingsFixture.nav.length; i++)
            Container(
              height: 30,
              padding: const EdgeInsets.only(left: InkSpacing.md),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: i == SettingsFixture.selectedNav ? c.surface5 : null,
                border: Border(
                  left: BorderSide(
                    width: 2,
                    color: i == SettingsFixture.selectedNav ? c.accent : c.surface2, // 未选中：与底同色，稿是 transparent
                  ),
                ),
              ),
              child: Text(
                SettingsFixture.nav[i],
                style: t.body.copyWith(color: i == SettingsFixture.selectedNav ? c.fg1 : c.fg4),
              ),
            ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 稿：padding 18 22 14，gap 6，下沿 1；标题 15/500，说明 fg5 lh 1.5。
        Container(
          padding: const EdgeInsets.fromLTRB(InkSpacing.s22, InkSpacing.s18, InkSpacing.s22, InkSpacing.s14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(SettingsFixture.pageTitle, style: t.sectionTitle.copyWith(color: c.fg1)),
              const SizedBox(height: InkSpacing.s6),
              Text(SettingsFixture.pageNote, style: t.body.copyWith(color: c.fg5, height: 1.5)),
            ],
          ),
        ),
        const _TableHeader(),
        for (final SeProvider p in SettingsFixture.providers) _ProviderRow(p),
        // 稿：padding 14 22，gap 10；两枚次级按钮 | 撑开 | 11px 说明。
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s22, vertical: InkSpacing.s14),
          child: Row(
            children: <Widget>[
              const _OutlineButton(SettingsFixture.addCustom),
              const SizedBox(width: InkSpacing.s10),
              const _OutlineButton(SettingsFixture.reverifyAll),
              const Spacer(),
              Text(SettingsFixture.customNote, style: t.meta.copyWith(color: c.fg6)),
            ],
          ),
        ),
        const _ConcurrencyBox(),
      ],
    );
  }
}

/// 稿：grid 168 / 1fr / 88 / 96，gap 12，padding 0 22。
class _Grid extends StatelessWidget {
  const _Grid({required this.provider, required this.key_, required this.region, required this.state});
  final Widget provider;
  final Widget key_;
  final Widget region;
  final Widget state;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          SizedBox(width: 168, child: provider),
          const SizedBox(width: InkSpacing.s12),
          Expanded(child: key_),
          const SizedBox(width: InkSpacing.s12),
          SizedBox(width: 88, child: region),
          const SizedBox(width: InkSpacing.s12),
          SizedBox(width: 96, child: state),
        ],
      );
}

/// 稿：26 高 + 下沿 1，11px fg6。
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final TextStyle s = context.inkTypography.meta.copyWith(color: c.fg6);
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s22),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
      child: _Grid(
        provider: Text(SettingsFixture.columns[0], style: s),
        key_: Text(SettingsFixture.columns[1], style: s),
        region: Text(SettingsFixture.columns[2], style: s),
        state: Text(SettingsFixture.columns[3], style: s),
      ),
    );
  }
}

/// 稿：min-height 40 + padding 6 22 + 下沿 1（#1F1F1F borderSubtle）。
class _ProviderRow extends StatelessWidget {
  const _ProviderRow(this.p);
  final SeProvider p;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final Color stateColor = switch (p.status) {
      SeState.verified => c.success,
      SeState.lowBalance => c.accent,
      SeState.missing => c.fg6,
      SeState.failed => c.danger,
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 53),
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s22, vertical: InkSpacing.s6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderSubtle))),
      child: _Grid(
        provider: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg1)),
            const SizedBox(height: InkSpacing.s2),
            Text(p.caps, style: t.micro.copyWith(color: c.fg6)),
          ],
        ),
        // 稿：24 高 + 底线 1，等宽 11。
        key_: Container(
          height: 25,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
          child: Text(p.key, style: t.mono.copyWith(color: p.keyMissing ? c.fg6 : c.fg2)),
        ),
        region: Text(p.region, style: t.meta.copyWith(color: c.fg4)),
        state: Row(
          children: <Widget>[
            Text(p.mark, style: t.mono.copyWith(color: stateColor)),
            const SizedBox(width: InkSpacing.s6),
            Text(p.state, style: t.meta.copyWith(color: stateColor)),
          ],
        ),
      ),
    );
  }
}

/// 稿：26 高 + 边框 1（#3F3F3F controlStrong）+ 圆角 3，padding 0 12，fg2。
class _OutlineButton extends StatelessWidget {
  const _OutlineButton(this.label, {this.horizontal = InkSpacing.s12});
  final String label;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      height: 28,
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: c.controlStrong),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Text(label, style: context.inkTypography.body.copyWith(color: c.fg2)),
    );
  }
}

/// 稿：margin 0 22 22，padding 14 16，边框 1（control）圆角 4，#1F1F1F 底（就近取 surface2），gap 10。
class _ConcurrencyBox extends StatelessWidget {
  const _ConcurrencyBox();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      margin: const EdgeInsets.fromLTRB(InkSpacing.s22, 0, InkSpacing.s22, InkSpacing.s22),
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md, vertical: InkSpacing.s14),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(SettingsFixture.concurrencyTitle, style: t.bodyStrong.copyWith(color: c.fg3)),
          for (final SeSlider s in SettingsFixture.concurrency) ...<Widget>[
            const SizedBox(height: InkSpacing.s10),
            _SliderRow(s),
          ],
          const SizedBox(height: InkSpacing.s10),
          Text(SettingsFixture.concurrencyNote, style: t.meta.copyWith(color: c.fg6, height: 1.5)),
        ],
      ),
    );
  }
}

/// 稿：grid 148 / 1fr / 72，gap 12；轨 2px controlStrong，填充 accent，10px 圆点 fg1；值等宽 11 accent 右对齐。
class _SliderRow extends StatelessWidget {
  const _SliderRow(this.s);
  final SeSlider s;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Row(
      children: <Widget>[
        SizedBox(width: 148, child: Text(s.label, style: t.body.copyWith(color: c.fg4))),
        const SizedBox(width: InkSpacing.s12),
        Expanded(
          child: SizedBox(
            height: 10,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final double x = box.maxWidth * s.pct;
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(left: 0, right: 0, top: 4, height: 2, child: ColoredBox(color: c.controlStrong)),
                    Positioned(left: 0, width: x, top: 4, height: 2, child: ColoredBox(color: c.accent)),
                    Positioned(
                      left: x - 5,
                      top: 0,
                      width: 10,
                      height: 10,
                      child: DecoratedBox(decoration: BoxDecoration(color: c.fg1, shape: BoxShape.circle)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: InkSpacing.s12),
        SizedBox(
          width: 72,
          child: Text(s.value, textAlign: TextAlign.right, style: t.mono.copyWith(color: c.accent)),
        ),
      ],
    );
  }
}

/// 稿：44 高 + 上沿 1，surface2；11px 说明 | 撑开 | 次级按钮 padding 0 14 | 主按钮 accent 底 padding 0 16。
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Text(SettingsFixture.footerNote, style: t.meta.copyWith(color: c.fg6)),
          const Spacer(),
          const _OutlineButton(SettingsFixture.exportDiagnostics, horizontal: InkSpacing.s14),
          const SizedBox(width: InkSpacing.s10),
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(InkRadius.s3),
            ),
            child: Text(SettingsFixture.done, style: t.bodyStrong.copyWith(color: c.onAccent)),
          ),
        ],
      ),
    );
  }
}
