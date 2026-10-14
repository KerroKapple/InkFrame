// Ink 基础件（纯呈现，theme 层）：面板标签条 / 按钮 / 方点。
// 尺寸全部来自 Workspace v2 稿的 CSS（docs/design/handoff-2026-09/InkFrame Workspace v2.html）。
// 原为静态复刻与真实画布共用；复刻脚手架已随 P7 删除，现在只服务 features/。
//
// 【2026-10-10 删了四件】`InkSelect` / `InkMonoField` / `InkSlider` / `InkToggle`
// 是复刻件退场后留下的死件——`lib/` 下零消费点、`test/` 下也零引用。判据不是肉眼
// grep，是 test/quality/no_dead_theme_component_test.dart：那道闸把本目录与
// primitives/ 的公开件逐个找消费点，首跑（删之前，30 个公开件）点出 8 个，其中
// 这四个是本次范围（另外四个记在 BOARD）——剩下 22 个各有消费点，证明"死"是这
// 几个独有的事实，不是闸口径太严把一批都误判了。
// 【2026-10-14 又删一件】`InkUnderlineField`（1px 底线的 22px 字段）最后一个消费点是
// 左栏旧项目面板 canvas_project_panel.dart 的筛选框；左栏换成图标导航条后筛选框按稿是
// 填色带边框的盒子，它就没人用了——同一道闸点出来的。
// 【同日再删】`InkPanelMenuGlyph`（面板标题条右侧的「≡」）：最后一个消费点是检查器页签条，
// 去重 PR 按稿把页签条改成「属性 / 历史」两页、右侧不再放「≡」。
import 'package:flutter/widgets.dart';

import '../app_theme.dart';
import '../icons/ink_glyph.dart';
import '../tokens.dart';
import 'ink_icon.dart';

/// 28px 面板标题条：选中项 surface3 底 + 1px accent 上边，其余 fg5；右侧可挂动作。
class InkPanelTabs extends StatelessWidget {
  const InkPanelTabs({
    super.key,
    required this.tabs,
    this.active = 0,
    this.badge,
    this.trailing,
  });

  final List<String> tabs;
  final int active;
  /// 选中标签右侧的等宽小数字（渲染队列的「3」）。
  final String? badge;
  final Widget? trailing;

  /// 稿是 content-box：height 28 + border-bottom 1。
  static const double height = 29;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 面板窄于标签总宽（英文文案 / 窄屏）时从右侧裁掉，不报溢出。
          Expanded(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = 0; i < tabs.length; i++)
                      Container(
                        height: height - 1,
                        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                        decoration: i == active
                            ? BoxDecoration(
                                color: c.surface3,
                                border: Border(top: BorderSide(color: c.accent)),
                              )
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              tabs[i],
                              style: i == active
                                  ? t.bodyStrong.copyWith(color: c.fg1)
                                  : t.body.copyWith(color: c.fg5),
                            ),
                            if (i == active && badge != null) ...<Widget>[
                              const SizedBox(width: InkSpacing.sm),
                              Text(badge!, style: t.monoSmall.copyWith(color: c.accent)),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 次级按钮：透明底 + 1px controlStrong 边 + 3px 圆角。
class InkSecondaryButton extends StatelessWidget {
  /// [height] 为稿上 content 高，实际 +2 边框。[leading] 非空时文字左边带一个 14px 图标
  /// （稿：标签栏「在序列中查看」——左右内边距收成 10，图标与文字间距 6，图标与字同为 fg2）。
  const InkSecondaryButton(this.label, {super.key, this.height = 24, this.leading});
  final String label;
  final double height;
  final InkGlyph? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final Widget text = Text(label, style: context.inkTypography.body.copyWith(color: c.fg2));
    final InkGlyph? glyph = leading;
    return Container(
      height: height + 2,
      padding: EdgeInsets.symmetric(
        horizontal: glyph == null ? InkSpacing.s12 : InkSpacing.s10,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: c.controlStrong),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      alignment: Alignment.center,
      child: glyph == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                InkIcon(glyph, size: InkIconSize.s14, color: c.fg2),
                const SizedBox(width: InkSpacing.s6),
                text,
              ],
            ),
    );
  }
}

/// 主按钮：琥珀底 + onAccent 深色字 + 500 字重。
class InkPrimaryButton extends StatelessWidget {
  /// [height] 为稿上 content 高，实际 +2 边框。
  const InkPrimaryButton(
    this.label, {
    super.key,
    this.height = 24,
    this.trailing,
    this.horizontalPadding = InkSpacing.s12,
    this.bordered = true,
  });
  final String label;
  final double height;
  final Widget? trailing;
  final double horizontalPadding;
  /// 标签栏的主按钮带 1px 同色边（占 2px），提示词条的「生成」没有。
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      height: bordered ? height + 2 : height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: c.accent,
        border: bordered ? Border.all(color: c.accent) : null,
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: context.inkTypography.bodyStrong.copyWith(color: c.onAccent)),
          if (trailing != null) ...<Widget>[const SizedBox(width: InkSpacing.s6), trailing!],
        ],
      ),
    );
  }
}

/// 1px 圆角小方点（6 / 8 px）。
class InkSquareDot extends StatelessWidget {
  const InkSquareDot({super.key, required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(InkRadius.s1)),
    );
  }
}
