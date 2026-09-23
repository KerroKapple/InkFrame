// Studio 首页静态复刻页（B 路径，Screens 稿第 1 屏）：1600×1000，
// 菜单栏 30 → 标签栏 34 → 无 Key 引导条 → 主体（库 220 | 项目区 flex）→ 状态栏 22。
// 数据全部来自 StudioFixture；尺寸全部按稿的 CSS（content-box：高/宽 + 边框）。
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/components/ws_primitives.dart';
import '../../theme/tokens.dart';
import 'models/studio_fixture.dart';
import 'widgets/ws_menu_bar.dart' show WsSearchGlyph;

class StudioV2Screen extends StatelessWidget {
  const StudioV2Screen({super.key});

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
            _KeyBanner(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _LibraryPanel(),
                  Expanded(child: _ProjectsArea()),
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

/// 稿：height 30 + border-bottom 1；Logo 组 | 四个菜单字 | 撑开 | 280 宽搜索底线字段。
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
          for (final String item in StudioFixture.menuItems)
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
                Expanded(child: Text(StudioFixture.searchPlaceholder, style: t.body.copyWith(color: c.fg6))),
                Text('⌘K', style: t.monoSmall.copyWith(color: c.fg6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：height 34 + border-bottom 1；标签（未选中 fg6）| 撑开 | 次级「导入项目包」+ 主「新建项目」。
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
          for (int i = 0; i < StudioFixture.tabs.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
              alignment: Alignment.center,
              decoration: i == StudioFixture.activeTab
                  ? BoxDecoration(border: Border(bottom: BorderSide(color: c.accent, width: 2)))
                  : null,
              child: Text(
                StudioFixture.tabs[i],
                style: i == StudioFixture.activeTab
                    ? t.bodyStrong.copyWith(color: c.fg1)
                    : t.body.copyWith(color: c.fg6),
              ),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Row(
              children: <Widget>[
                WsSecondaryButton(StudioFixture.importPackage),
                SizedBox(width: InkSpacing.s6),
                WsPrimaryButton(StudioFixture.newProject, bordered: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：padding 10 20，gap 12，accentWash 底 + border-bottom 1；「!」等宽 11px 琥珀。
class _KeyBanner extends StatelessWidget {
  const _KeyBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s20, vertical: InkSpacing.s10),
      decoration: BoxDecoration(
        color: c.accentWash,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Text(StudioFixture.bannerMark, style: t.mono.copyWith(color: c.accent)),
          const SizedBox(width: InkSpacing.s12),
          Text(StudioFixture.bannerTitle, style: t.body.copyWith(color: c.fg1)),
          const SizedBox(width: InkSpacing.s12),
          Text(StudioFixture.bannerHint, style: t.body.copyWith(color: c.fg5)),
          const Spacer(),
          Container(
            height: 26, // content 24 + border 2
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: c.accentWashBorder),
              borderRadius: BorderRadius.circular(InkRadius.s3),
            ),
            child: Text(StudioFixture.bannerAction, style: t.body.copyWith(color: c.fg1)),
          ),
          const SizedBox(width: InkSpacing.s12),
          Text('✕', style: t.body.copyWith(color: c.fg5)),
        ],
      ),
    );
  }
}

/// 稿：width 220 + border-right 1，surface3；库四行 28 | 分隔线 | 最近画布四行 26 | 撑开 | 设置 30。
class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel();

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
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.s14, InkSpacing.s12, InkSpacing.sm),
            child: Text(StudioFixture.libraryHeading, style: t.meta.copyWith(color: c.fg6)),
          ),
          for (final StLibNav n in StudioFixture.libNav)
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              color: n.selected ? c.surface5 : null,
              child: Row(
                children: <Widget>[
                  // 稿是 content-box：12×10 + 1px 边 ⇒ 14×12。
                  Container(
                    width: 14,
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border.all(color: n.selected ? c.accent : c.fg6),
                      borderRadius: BorderRadius.circular(InkRadius.s1),
                    ),
                  ),
                  const SizedBox(width: InkSpacing.s10),
                  Expanded(child: Text(n.name, style: t.body.copyWith(color: n.selected ? c.fg1 : c.fg3))),
                  Text(n.count, style: t.monoSmall.copyWith(color: c.fg6)),
                ],
              ),
            ),
          Container(height: 1, margin: const EdgeInsets.symmetric(vertical: InkSpacing.s10), color: c.borderStrong),
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.xs, InkSpacing.s12, InkSpacing.sm),
            child: Text(StudioFixture.recentHeading, style: t.meta.copyWith(color: c.fg6)),
          ),
          for (final StRecentCanvas r in StudioFixture.recentCanvases)
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 20,
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: _gradient(r.thumb),
                      borderRadius: BorderRadius.circular(InkRadius.s1),
                    ),
                  ),
                  const SizedBox(width: InkSpacing.sm),
                  Expanded(
                    child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(color: c.fg3)),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Container(
            height: 31, // content 30 + border-top 1
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.fg6)),
                ),
                const SizedBox(width: InkSpacing.s10),
                Text(StudioFixture.settings, style: t.body.copyWith(color: c.fg4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

LinearGradient _gradient(int i) {
  final (Color a, Color b) = InkPalette.thumbPlaceholderGradients[i];
  return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[a, b]);
}

/// 稿：surface1；工具行 32 + border-bottom 1（padding 0 20）；内容 padding 20：恢复条 + 4 列网格 gap 16。
class _ProjectsArea extends StatelessWidget {
  const _ProjectsArea();

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
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s20),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Text(StudioFixture.gridTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s14),
                Text(StudioFixture.gridCount, style: t.mono.copyWith(color: c.fg5)),
                const Spacer(),
                Text(StudioFixture.sortLabel, style: t.body.copyWith(color: c.fg5)),
                for (int i = 0; i < StudioFixture.viewModes.length; i++) ...<Widget>[
                  const SizedBox(width: InkSpacing.s14),
                  Text(
                    StudioFixture.viewModes[i],
                    style: t.body.copyWith(color: i == StudioFixture.activeViewMode ? c.fg1 : c.fg5),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(InkSpacing.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _ResumeBar(),
                  const SizedBox(height: InkSpacing.s22),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      const int cols = 4;
                      final double w = (box.maxWidth - InkSpacing.md * (cols - 1)) / cols;
                      return Wrap(
                        spacing: InkSpacing.md,
                        runSpacing: InkSpacing.md,
                        children: <Widget>[
                          for (final StProject p in StudioFixture.projects)
                            SizedBox(width: w, child: _ProjectCard(project: p)),
                          SizedBox(width: w, child: const _NewProjectCard()),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：padding 14 16，border 1 control，圆角 4，#212121 底（取 surface3 槽）；两行 gap 10。
class _ResumeBar extends StatelessWidget {
  const _ResumeBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md, vertical: InkSpacing.s14),
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(StudioFixture.resumeLabel, style: t.meta.copyWith(color: c.fg4)),
              const SizedBox(width: InkSpacing.s10),
              Text(StudioFixture.resumeName, style: t.body.copyWith(color: c.fg1)),
              const SizedBox(width: InkSpacing.s10),
              Text(StudioFixture.resumeMeta, style: t.mono.copyWith(color: c.fg6)),
              const Spacer(),
              const WsPrimaryButton(
                StudioFixture.resumeAction,
                height: 26,
                bordered: false,
                horizontalPadding: InkSpacing.s14,
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.s10),
          Row(
            children: <Widget>[
              Text('✓', style: t.meta.copyWith(color: c.success)),
              const SizedBox(width: InkSpacing.sm),
              Text(StudioFixture.resumeNote, style: t.meta.copyWith(color: c.fg5)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 稿：封面 16:10 圆角 4 outline 1px 盒内；右上 ⋯ 11px；左下等宽 10px「3 画布 · 8 镜」；下方名称 + 11px 元信息。
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final StProject project;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final Color overlay = c.fg1.withValues(alpha: 0.8);
    final Color badge = c.fg1.withValues(alpha: 0.75);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Container(
            decoration: BoxDecoration(
              gradient: _gradient(project.cover),
              border: Border.all(color: c.outline),
              borderRadius: BorderRadius.circular(InkRadius.sm),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: 7,
                  top: 7,
                  child: Text('⋯', style: t.meta.copyWith(color: overlay)),
                ),
                Positioned(
                  left: 7,
                  bottom: 7,
                  child: Row(
                    children: <Widget>[
                      Text('${project.canvases} 画布', style: t.monoSmall.copyWith(color: badge)),
                      const SizedBox(width: InkSpacing.s6),
                      Text('·', style: t.monoSmall.copyWith(color: badge)),
                      const SizedBox(width: InkSpacing.s6),
                      Text('${project.shots} 镜', style: t.monoSmall.copyWith(color: badge)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.sm),
        Text(project.name, style: t.body.copyWith(color: c.fg1)),
        const SizedBox(height: InkSpacing.s3),
        Text(project.meta, style: t.meta.copyWith(color: c.fg6)),
      ],
    );
  }
}

/// 稿：16:10 虚线框（controlStrong）圆角 4，居中 20px「+」+ 11px「新建项目」；下方 11px 提示。
class _NewProjectCard extends StatelessWidget {
  const _NewProjectCard();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 10,
          child: CustomPaint(
            painter: _DashedBorderPainter(color: c.controlStrong, radius: InkRadius.sm),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('+', style: t.dialogTitle.copyWith(color: c.fg6, height: 1.0)),
                  const SizedBox(height: InkSpacing.s6),
                  Text(StudioFixture.newProject, style: t.meta.copyWith(color: c.fg6)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.sm),
        Text(StudioFixture.newProjectHint, style: t.meta.copyWith(color: c.fg6)),
      ],
    );
  }
}

/// 1px 虚线圆角框（稿 border: 1px dashed；Flutter 没有原生虚线边框）。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Offset(0.5, 0.5) & Size(size.width - 1, size.height - 1),
        Radius.circular(radius),
      ));
    // Chromium 的 dashed：段长约 3×线宽，间隔同长。
    const double dash = 3;
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), p);
        d += dash * 2;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}

/// 稿：height 22 + border-top 1；gap 16；11px fg5；右侧「未配置 Key」+ 等宽版本号。
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
          for (int i = 0; i < StudioFixture.statusLeft.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: InkSpacing.md),
            Text(StudioFixture.statusLeft[i], style: s),
          ],
          const Spacer(),
          Text(StudioFixture.statusKey, style: s),
          const SizedBox(width: InkSpacing.md),
          Text(StudioFixture.version, style: t.mono.copyWith(color: c.fg5)),
        ],
      ),
    );
  }
}
