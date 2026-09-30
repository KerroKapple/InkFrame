// 首启向导静态复刻页（B 路径，Screens 稿第 4 屏左）：642×492 的一块卡片。
//
// 稿是 content-box（全稿无 box-sizing reset），所以每一层的「高」都要把边框加回去：
//   步骤条 43 = 内容 42 + 1px 下沿；页签 42 = height:40 + 2px 下边框（transparent 也占位）；
//   Provider 行 63 = min-height:46 + padding 8×2 + 1px 行分隔；分组框 191 = 1 + 63×3 + 1；
//   输入框 27 = height:26 + 1px 底线；验证按钮 28 = 26 + 1px 边 ×2；底部条 55 = 26 + 14×2 + 1。
// 竖向合账：1 + 43 + 391.594 + 55 + 1 = 491.594（光栅 492）。
//
// 行高全部按稿的 `line-height:normal` 用值显式钉死——Chrome 对 Noto Sans SC 的 normal
// 是 floor(字号 × 1.48)（11→16 / 12→17 / 17→25），对 JetBrains Mono 是 floor(字号 × 1.3)
// （10→13）；仓库 token 的 1.45 / 1.3 / mono 1.0 都对不上，不钉就整屏错位。
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'models/onboarding_fixture.dart';

/// 稿的 `line-height:normal` 用值（px）。
const double _lhMono10 = 13;
const double _lhSans11 = 16;
const double _lhSans12 = 17;
const double _lhSans17 = 25;

/// 说明文案是全屏唯一写了 `line-height` 的一段：12 × 1.55。
const double _lhDescription = 18.6;

/// `✓` 走回落字体，稿量到的行高是 15 而不是 14。
const double _lhCheck = 15;

/// 掩码值：JetBrains Mono 11px 在稿里的 normal 用值。
const double _lhMono11 = 14;

class OnboardingV2Screen extends StatelessWidget {
  const OnboardingV2Screen({super.key});

  static const Size designSize = OnboardingFixture.designSize;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return ColoredBox(
      // 卡片圆角外露出的那几个像素。稿上这里是「遮罩 + 卡片阴影」压暗后的 #0C0C0C；
      // 取最暗的既有槽位近似（Δ3，低于比对容差 24），不为四个角另造颜色。
      color: c.borderStrong,
      child: SizedBox(
        width: designSize.width,
        height: designSize.height,
        // 稿里这张卡的页面 y 是 3400.203（`translate(-50%,-50%)` 落在半像素上），
        // 我们的基准图从整数行 3400 起裁，于是稿的每条横线都跨两行做了 0.203 的
        // 混色。复刻按同一偏移画，边缘的软硬才对得上——这不是调参，是照抄稿的光栅。
        child: Transform.translate(
          offset: const Offset(0, 0.203),
          child: Container(
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
                _StepBar(),
                Expanded(child: _Body()),
                _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 步骤条 43

class _StepBar extends StatelessWidget {
  const _StepBar();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s20),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          for (final ObStep s in OnboardingFixture.steps) _StepTab(step: s),
        ],
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({required this.step});

  final ObStep step;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return SizedBox(
      width: step.width,
      height: 42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
              // 盒宽按稿钉死，内容用自然宽画出去——回落中文字体每个页签比稿宽 1px，
              // 硬塞进 44px 的内容区会撞 RenderFlex 溢出（debug 下直接画黄黑条）。
              // 多出来的 1px 落在 16px 内边距里，看不出来；而下划线的起点与长度必须准。
              child: OverflowBox(
                maxWidth: double.infinity,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      step.index,
                      style: t.monoSmall.copyWith(
                        color: step.current ? c.accent : c.fg6,
                        height: _lhMono10 / 10,
                      ),
                    ),
                    const SizedBox(width: InkSpacing.sm),
                    Text(
                      step.name,
                      style: t.body.copyWith(
                        color: step.current ? c.fg1 : c.fg4,
                        height: _lhSans12 / 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 稿写的是 `border-bottom:2px solid transparent`——**占位但不画**。
          // 槽位恒留（不留整条页签矮 2px、文字跟着上移），只有当前步才填琥珀。
          SizedBox(
            height: 2,
            child: step.current ? ColoredBox(color: c.accent) : null,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ 正文区 391.594

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.lg,
        InkSpacing.lg,
        InkSpacing.lg,
        InkSpacing.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            OnboardingFixture.title,
            style: t.dialogTitle.copyWith(color: c.fg1, height: _lhSans17 / 17),
          ),
          const SizedBox(height: InkSpacing.sm),
          Text(
            OnboardingFixture.description,
            maxLines: 1,
            style: t.body.copyWith(color: c.fg4, height: _lhDescription / 12),
          ),
          const SizedBox(height: InkSpacing.md),
          const _ProviderGroup(),
          const SizedBox(height: InkSpacing.md),
          const _KeyField(),
        ],
      ),
    );
  }
}

class _ProviderGroup extends StatelessWidget {
  const _ProviderGroup();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return Container(
      height: 191,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Column(
        children: <Widget>[
          for (final ObProvider p in OnboardingFixture.providers)
            _ProviderRow(provider: p),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider});

  final ObProvider provider;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: 63,
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s14,
        vertical: InkSpacing.sm,
      ),
      decoration: BoxDecoration(
        // 未选中行是 transparent，透出卡片底色。
        color: provider.checked ? c.accentWash : null,
        // 第三行底部也有这条线——稿写在每行的 border-bottom 上，被分组框的
        // overflow:hidden 压在框底边内侧，是两条相邻的线，不是一条。
        border: Border(bottom: BorderSide(color: c.outline)),
      ),
      child: Row(
        children: <Widget>[
          _Radio(checked: provider.checked),
          const SizedBox(width: InkSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  provider.name,
                  style: t.body.copyWith(color: c.fg1, height: _lhSans12 / 12),
                ),
                const SizedBox(height: InkSpacing.s2),
                Text(
                  provider.note,
                  // 稿是 #7A7A7A，色板里没有这一档；fg6 差 15，低于比对容差 24。
                  style: t.meta.copyWith(color: c.fg6, height: _lhSans11 / 11),
                ),
              ],
            ),
          ),
          Text(
            provider.region,
            style: t.meta.copyWith(color: c.fg5, height: _lhSans11 / 11),
          ),
        ],
      ),
    );
  }
}

/// 单选圈：外径 14（稿 box-sizing:border-box），圈线稿写 1.5px 但 Chrome 在
/// DSF=1 下用值取 1px，渲染图量到的也是 1px——跟渲染图走，写 1.5 会比稿粗。
class _Radio extends StatelessWidget {
  const _Radio({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final Color line = checked ? c.accent : c.fg6;
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: line),
      ),
      child: checked
          ? Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent),
            )
          : null,
    );
  }
}

class _KeyField extends StatelessWidget {
  const _KeyField();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          OnboardingFixture.keyLabel,
          style: t.body.copyWith(color: c.fg4, height: _lhSans12 / 12),
        ),
        const SizedBox(height: InkSpacing.s6),
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 27,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.control)),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      OnboardingFixture.keyMasked,
                      style: t.mono.copyWith(
                        color: c.fg2,
                        height: _lhMono11 / 11,
                      ),
                    ),
                    // 光标：稿 margin-left:2，1×13 实心琥珀。
                    const SizedBox(width: InkSpacing.s2),
                    Container(width: 1, height: 13, color: c.accent),
                  ],
                ),
              ),
            ),
            const SizedBox(width: InkSpacing.s10),
            Container(
              height: 28,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              decoration: BoxDecoration(
                border: Border.all(color: c.controlStrong),
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              child: Text(
                OnboardingFixture.verify,
                style: t.body.copyWith(color: c.fg2, height: _lhSans12 / 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: InkSpacing.s6),
        Row(
          children: <Widget>[
            Text(
              OnboardingFixture.checkGlyph,
              style: t.meta.copyWith(color: c.success, height: _lhCheck / 11),
            ),
            const SizedBox(width: InkSpacing.sm),
            Text(
              OnboardingFixture.verified,
              style: t.meta.copyWith(color: c.fg4, height: _lhSans11 / 11),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- 底部条 55

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s20,
        vertical: InkSpacing.s14,
      ),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            OnboardingFixture.footerHint,
            style: t.meta.copyWith(color: c.fg6, height: _lhSans11 / 11),
          ),
          const Spacer(),
          // 「跳过」与「下一步」同高 26——两者都没有边框，别顺手给次动作加一圈。
          Container(
            height: 26,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Text(
              OnboardingFixture.skip,
              style: t.body.copyWith(color: c.fg4, height: _lhSans12 / 12),
            ),
          ),
          const SizedBox(width: InkSpacing.s10),
          Container(
            height: 26,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(InkRadius.s3),
            ),
            child: Text(
              OnboardingFixture.next,
              style: t.bodyStrong.copyWith(
                color: c.onAccent,
                height: _lhSans12 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
