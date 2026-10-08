// 交付面板静态复刻页（B 路径，Timeline 稿上半右栏）：321×608 的一栏。
//
// 稿是 content-box，每层的高都要把边框加回去：
//   页签条 29 = height:28 + 1px 下沿；页签 28 = 1px 上边（当前步的琥珀线）+ 27 内容；
//   分段控件 28 = 26 + 1px 边 ×2；设置行 26（min-height 生效，三种值形态自然高都更矮）；
//   值盒 23 = height:22 + 1px 底线；分组 141/115/141 = 组头 26 + 组身 + 1px 下沿；
//   底部条 59 = padding 10×2 + 16 + gap 6 + 16 + 1px 上沿。
// 竖向合账：29 + 520 + 59 = 608。
//
// **滚动区会裁掉一截**：可视只有 520，内容更高，超出的部分稿上就看不见——
// 复刻必须同样裁，不裁就对不上。
//
// 2026-10-08 稿把「媒体」组从 5 行减到 3 行（删了「手柄」「范围」，进不做清单），
// 组高 167 → 115，滚动区内容短了 52px：原本整块滚出视口的「交付前检查」现在
// **露出约 14.5px**，所以这一版把它画上了。
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'models/delivery_fixture.dart';

/// 稿的 `line-height:normal` 用值（px）：Noto Sans SC 是 floor(字号 × 1.48)。
const double _lhSans11 = 16;
const double _lhSans12 = 17;

/// 分段说明是本栏唯一写了 `line-height` 的一段：11 × 1.5 = 16.5。
/// 取 17 而不是 16.5：Chromium 把这半像素连同块高一起向上取整，「目标软件」块的
/// 下沿因此落在第 137 行；写 16.5 会让三条分组分隔线整体高 1px。
const double _lhHint = 17;

/// 等宽 11px 在稿里的 normal 用值。
const double _lhMono11 = 16;

/// 交付前检查：标记列 `line-height:1.45` × 11 = 15.938；条目文字 1.45 × 12 = 17.391。
const double _lhCheck = 15.938;
const double _lhCheckItem = 17.391;

/// 行网格：标签列硬写死 92，gap 8，值列 1fr = 196。
const double _kLabelColumn = 92;
const double _kValueColumn = 196;

/// 下拉三角。9px，比同行的值小 3。
const String _kCaret = '▼';

class DeliveryV2Screen extends StatelessWidget {
  const DeliveryV2Screen({super.key});

  static const Size designSize = DeliveryFixture.designSize;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    // 必须是 Container 不能是 DecoratedBox：后者只画边框、**不占位**，
    // 1px 左沿会盖掉内容第一列，整栏跟着左移 1px（行网格、开关、下划线全错位）。
    return Container(
      width: designSize.width,
      height: designSize.height,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(left: BorderSide(color: c.borderStrong)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[_Tabs(), _ScrollArea(), _Footer()],
      ),
    );
  }
}

// -------------------------------------------------------------- 页签条 29

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: DeliveryFixture.tabsHeight,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < DeliveryFixture.tabs.length; i++)
            SizedBox(
              width: DeliveryFixture.tabWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // 当前页签的底色与面板连成一片，标记线在**顶部**不是底部。
                  color: i == DeliveryFixture.currentTab ? c.surface3 : null,
                  border: i == DeliveryFixture.currentTab
                      ? Border(top: BorderSide(color: c.accent))
                      : null,
                ),
                child: Center(
                  child: Text(
                    DeliveryFixture.tabs[i],
                    style: (i == DeliveryFixture.currentTab
                            ? t.bodyStrong
                            : t.body)
                        .copyWith(
                          color: i == DeliveryFixture.currentTab
                              ? c.fg1
                              : c.fg5,
                          height: _lhSans12 / 12,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ 滚动区 520

class _ScrollArea extends StatelessWidget {
  const _ScrollArea();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DeliveryFixture.scrollHeight,
      // 裁掉溢出的那一截——稿上这里就是 `overflow:auto` 且没有滚动。
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _TargetBlock(),
              for (final DvGroup g in DeliveryFixture.groups) _Group(group: g),
              const _Preflight(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetBlock extends StatelessWidget {
  const _TargetBlock();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.s12,
        InkSpacing.s14,
        InkSpacing.s12,
        InkSpacing.s12,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            DeliveryFixture.targetLabel,
            style: t.body.copyWith(color: c.fg4, height: _lhSans12 / 12),
          ),
          const SizedBox(height: InkSpacing.s10),
          const _Segments(),
          const SizedBox(height: InkSpacing.s10),
          Text(
            DeliveryFixture.targetHint,
            maxLines: 1,
            style: t.meta.copyWith(color: c.fg6, height: _lhHint / 11),
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: 28,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < DeliveryFixture.targets.length; i++)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // 选中段的底色与边框同色——稿就是这么写的，不是描边。
                  color: i == DeliveryFixture.currentTarget ? c.control : null,
                  // 最后一段也有右边线，与外框边叠成 2px（稿的写法，照抄）。
                  border: Border(right: BorderSide(color: c.control)),
                ),
                child: Text(
                  DeliveryFixture.targets[i],
                  style: t.body.copyWith(
                    color: i == DeliveryFixture.currentTarget ? c.fg1 : c.fg4,
                    height: _lhSans12 / 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group});

  final DvGroup group;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 26,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              child: Row(
                children: <Widget>[
                  Text(
                    _kCaret,
                    style: t.nano.copyWith(color: c.fg5, height: 13 / 9),
                  ),
                  const SizedBox(width: InkSpacing.s6),
                  Text(
                    group.title,
                    style: t.bodyStrong.copyWith(
                      color: c.fg3,
                      height: _lhSans12 / 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            // 稿：组身 `padding: 2px 0 8px` —— 组头到首行只有 2px。
            padding: const EdgeInsets.only(
              top: InkSpacing.s2,
              bottom: InkSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final DvRow r in group.rows) _SettingRow(row: r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.row});

  final DvRow row;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return SizedBox(
      height: 26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
        child: Row(
          children: <Widget>[
            // 标签列是硬写死的 92px 网格轨道，不是内容宽。
            SizedBox(
              width: _kLabelColumn,
              child: Text(
                row.label,
                style: t.body.copyWith(color: c.fg4, height: _lhSans12 / 12),
              ),
            ),
            const SizedBox(width: InkSpacing.sm),
            SizedBox(width: _kValueColumn, child: _value(c, t)),
          ],
        ),
      ),
    );
  }

  Widget _value(InkColors c, InkTypography t) {
    switch (row.kind) {
      case DvRowKind.select:
        return _underlined(
          c,
          Row(
            children: <Widget>[
              Text(
                row.value,
                style: t.body.copyWith(color: c.fg2, height: _lhSans12 / 12),
              ),
              const Spacer(),
              // ▼ 比组头那个暗一档。
              Text(
                _kCaret,
                style: t.nano.copyWith(color: c.fg6, height: 13 / 9),
              ),
            ],
          ),
        );
      case DvRowKind.mono:
        // 等宽行是可编辑文本，**没有** ▼。
        return _underlined(
          c,
          Text(
            row.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.mono.copyWith(color: c.fg2, height: _lhMono11 / 11),
          ),
        );
      case DvRowKind.toggle:
        return SizedBox(
          height: 16,
          child: Row(
            children: <Widget>[
              _Toggle(on: row.on),
              const SizedBox(width: InkSpacing.sm),
              // 开关行的值是「注解」不是「值」，比下拉行暗两档。
              Text(
                row.value,
                style: t.meta.copyWith(color: c.fg5, height: _lhSans11 / 11),
              ),
            ],
          ),
        );
    }
  }

  /// 值盒 23 = height:22 + 1px 底线；无左右上边框、无底色、无圆角。
  Widget _underlined(InkColors c, Widget child) => Container(
    height: 23,
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: c.control)),
    ),
    child: child,
  );
}

/// 26×14 胶囊 + 10×10 圆钮。与 `ws_primitives.dart` 的 `WsToggle` 同几何——
/// 复刻件不引用它是因为那件带 `meta`/`fg5` 的标签排版，这里的说明文字要自己排。
class _Toggle extends StatelessWidget {
  const _Toggle({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return SizedBox(
      width: 26,
      height: 14,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: on ? c.accent : c.controlStrong,
                borderRadius: BorderRadius.circular(InkRadius.pill),
              ),
            ),
          ),
          Positioned(
            left: on ? 14 : 2,
            top: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: c.fg1,
                borderRadius: BorderRadius.circular(InkRadius.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 交付前检查。2026-10-08 稿把「媒体」组减到 3 行后，滚动区内容短了 52px，
/// 这一块的起点从 586.5 提到 534.5——可视区到 549 为止，**只露出约 14.5px**
/// （12 内边距 + 标题行的头 2.5px）。整块照规格画，露多少由 ClipRect 决定。
class _Preflight extends StatelessWidget {
  const _Preflight();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.all(InkSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                DeliveryFixture.preflightTitle,
                style: t.body.copyWith(color: c.fg4, height: _lhSans12 / 12),
              ),
              const Spacer(),
              Text(
                DeliveryFixture.preflightPending,
                style: t.meta.copyWith(color: c.accent, height: _lhSans11 / 11),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.sm),
          for (final DvCheck k in DeliveryFixture.preflight)
            Row(
              // 条目可能折行，标记要贴顶不是居中。
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 14,
                  child: Text(
                    k.ok ? '✓' : '!',
                    style: t.mono.copyWith(
                      color: k.ok ? c.success : c.accent,
                      height: _lhCheck / 11,
                    ),
                  ),
                ),
                const SizedBox(width: InkSpacing.sm),
                Expanded(
                  child: Text(
                    k.text,
                    style: t.body.copyWith(
                      // 「!」条比「✓」条亮一档——待处理的那条要先被看见。
                      color: k.ok ? c.fg4 : c.fg2,
                      height: _lhCheckItem / 12,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- 底部条 59

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final TextStyle label = t.meta.copyWith(
      color: c.fg5,
      height: _lhSans11 / 11,
    );
    return Container(
      height: DeliveryFixture.footerHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s12,
        vertical: InkSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(DeliveryFixture.outputLabel, style: label),
              const Spacer(),
              // 路径是等宽。
              Text(
                DeliveryFixture.outputPath,
                style: t.mono.copyWith(color: c.fg5, height: _lhMono11 / 11),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.s6),
          Row(
            children: <Widget>[
              Text(DeliveryFixture.includeLabel, style: label),
              const Spacer(),
              // 清单是无衬线——和上一行的字体不一样。
              Text(DeliveryFixture.includeList, style: label),
            ],
          ),
        ],
      ),
    );
  }
}
