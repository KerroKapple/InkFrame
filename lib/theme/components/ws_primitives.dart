// Workspace v2 基础件（纯呈现，theme 层）：面板标签条 / 按钮 / 底线字段 / 下拉 / 滑块 / 开关 / 方点。
// 尺寸全部来自稿的 CSS（docs/design/handoff-2026-09/InkFrame Workspace v2.html）。
// 静态复刻（features/workspace）与真实画布（features/canvas）共用。
import 'package:flutter/widgets.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// 28px 面板标题条：选中项 surface3 底 + 1px accent 上边，其余 fg5；右侧可挂动作。
class WsPanelTabs extends StatelessWidget {
  const WsPanelTabs({
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

/// 面板标题条右侧的「≡」。
class WsPanelMenuGlyph extends StatelessWidget {
  const WsPanelMenuGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
      child: Center(child: Text('≡', style: context.inkTypography.body.copyWith(color: c.fg6))),
    );
  }
}

/// 次级按钮：透明底 + 1px controlStrong 边 + 3px 圆角。
class WsSecondaryButton extends StatelessWidget {
  /// [height] 为稿上 content 高，实际 +2 边框。
  const WsSecondaryButton(this.label, {super.key, this.height = 24});
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      height: height + 2,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        border: Border.all(color: c.controlStrong),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      alignment: Alignment.center,
      child: Text(label, style: context.inkTypography.body.copyWith(color: c.fg2)),
    );
  }
}

/// 主按钮：琥珀底 + onAccent 深色字 + 500 字重。
class WsPrimaryButton extends StatelessWidget {
  /// [height] 为稿上 content 高，实际 +2 边框。
  const WsPrimaryButton(
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

/// 无底色 + 1px control 底线的 22px 字段容器。
class WsUnderlineField extends StatelessWidget {
  const WsUnderlineField({super.key, required this.child, this.width});
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      width: width,
      height: 23, // content 22 + border-bottom 1
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
      child: child,
    );
  }
}

/// 下拉：底线字段 + 右侧 ▼。
class WsSelect extends StatelessWidget {
  const WsSelect(this.value, {super.key});
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return WsUnderlineField(
      child: Row(
        children: <Widget>[
          Expanded(child: Text(value, style: t.body.copyWith(color: c.fg2), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('▼', style: t.micro.copyWith(color: c.fg6)),
        ],
      ),
    );
  }
}

/// 只读等宽文本字段。
class WsMonoField extends StatelessWidget {
  const WsMonoField(this.value, {super.key});
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return WsUnderlineField(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(value, style: context.inkTypography.mono.copyWith(color: c.fg2), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// 滑块：2px 轨道 + 琥珀已填充段 + 10px 圆钮 + 右侧 40px 等宽琥珀数值。
class WsSlider extends StatelessWidget {
  const WsSlider({super.key, required this.fraction, required this.value});
  final double fraction;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 10,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final double x = box.maxWidth * fraction;
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(left: 0, right: 0, top: 4, height: 2, child: ColoredBox(color: c.controlStrong)),
                    Positioned(left: 0, width: x, top: 4, height: 2, child: ColoredBox(color: c.accent)),
                    Positioned(
                      left: x - 5,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: c.fg1, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: InkSpacing.sm),
        SizedBox(
          width: 40,
          child: Text(value, textAlign: TextAlign.right, style: context.inkTypography.mono.copyWith(color: c.accent)),
        ),
      ],
    );
  }
}

/// 开关：26×14 胶囊，开启琥珀底、关闭 controlStrong，10px 圆钮。
class WsToggle extends StatelessWidget {
  const WsToggle({super.key, required this.on, required this.label});
  final bool on;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Row(
      children: <Widget>[
        Container(
          width: 26,
          height: 14,
          decoration: BoxDecoration(
            color: on ? c.accent : c.controlStrong,
            borderRadius: BorderRadius.circular(InkRadius.pill),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: on ? 14 : 2,
                top: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: c.fg1, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: InkSpacing.sm),
        Text(label, style: context.inkTypography.meta.copyWith(color: c.fg5)),
      ],
    );
  }
}

/// 1px 圆角小方点（6 / 8 px）。
class WsSquareDot extends StatelessWidget {
  const WsSquareDot({super.key, required this.size, required this.color});
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
