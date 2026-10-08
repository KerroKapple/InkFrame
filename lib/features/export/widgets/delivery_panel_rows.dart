// 交付面板的行级构件（P6）。几何**逐个照抄静态复刻件**
// （lib/features/workspace/delivery_v2_screen.dart，#243 已逐像素验收）：
//
//   页签条 29 = height:28 + 1px 下沿；分段控件 28 = 26 + 1px 边 ×2；
//   设置行 26；值盒 23 = height:22 + 1px 底线；分组 = 组头 26 + 组身 + 1px 下沿；
//   组身 padding 2/0/8；行网格 标签列 92 + gap 8 + 值列 1fr（320 宽时正好 196）。
//
// 行高（稿的 `line-height: normal` 实测用值）：Noto Sans SC 是 floor(字号 × 1.48)
// ——12px → 17，11px → 16；等宽 11px → 16。不照抄这些值，整栏会整体长出几像素。
//
// 与复刻件的两处**刻意不同**（任务书 §2.2/§2.4 点名）：
//   - 「格式 / 轨道 / 转码 / 占位镜头」四行是只读派生值，**不画 ▼**：▼ 承诺一个
//     菜单，而这四行点了没有菜单（任务书：「只读文本（下拉样式但无 ▼）」）。
//   - 值列用 Expanded 而不是写死 196：稿里它就是 `1fr`，320 宽下两者等价。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../util/edl_cmx3600.dart' show formatEdlTimecode, parseEdlTimecode;

/// 稿的 `line-height:normal` 用值（px）。
const double kDvLhSans11 = 16;
const double kDvLhSans12 = 17;
const double kDvLhMono11 = 16;

/// 分段说明那一段是本栏唯一写了 `line-height` 的：11 × 1.5 → 取 17（见复刻件头注）。
const double kDvLhHint = 17;

/// 三层高度：页签条 29 / 底部条 59。
const double kDvTabsHeight = 29;
const double kDvFooterHeight = 59;

/// 页签 48 宽（padding 0 12 + 2 CJK × 12）。
const double kDvTabWidth = 48;

/// 分段控件 28 = 26 内容 + 1px 边 ×2。
const double kDvSegmentsHeight = 28;

/// 组头 / 设置行同高 26；值盒 23 = 22 + 1px 底线。
const double kDvRowHeight = 26;
const double kDvValueBoxHeight = 23;

/// 行网格：标签列硬写死 92（不是内容宽），gap 8。
const double kDvLabelColumn = 92;

/// 结果条 32（任务书 §3）。
const double kDvResultBarHeight = 32;

/// 组头的折叠三角。9px，比同行的值小 3。**只是稿上的装饰，不挂点击**
/// ——三个组在稿里只有展开态，折叠态没画，挂上去就是个死交互。
const String kDvCaret = '▼';

/// 长路径**中间省略**（稿 §2.6：底部摘要的输出路径「过长中间省略」）。
///
/// 为什么不用 `TextOverflow.ellipsis`：它只从尾部截，而路径的尾部
/// （`.../projects/<uuid>/exports`）才是有信息的那一半，截掉它等于什么都没显示。
/// 纯字数版，给测试用；界面上走 [fitMiddleEllipsis]（按实测宽度定字数）。
String middleEllipsisPath(String path, {int maxChars = 40}) {
  if (maxChars < 5 || path.length <= maxChars) return path;
  // 留一个字符给省略号，头尾各分一半；头部多一个（奇数时）。
  final int keep = maxChars - 1;
  final int head = (keep + 1) ~/ 2;
  final int tail = keep - head;
  return '${path.substring(0, head)}…${path.substring(path.length - tail)}';
}

/// 在 [maxWidth] 内放得下的最长「中间省略」串。
///
/// **不要按字宽估。** 等宽步进看着是 0.6em，可这一栏按 0.6 算出来还是 40 字——
/// 和原先写死的值一模一样，照样放不下，Flutter 再从尾部硬裁一刀，于是只剩
/// 「C:\Users\Kerro\AppDa…」：头部留着、尾部连同中间省略号一起没了，白做。
/// 这里直接用 TextPainter 量，顺带把 a11y 字号档也算进去。
String fitMiddleEllipsis(
  String path,
  TextStyle style,
  double maxWidth,
  TextScaler scaler,
) {
  final TextPainter painter = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  );
  bool fits(String s) {
    painter.text = TextSpan(text: s, style: style);
    painter.layout();
    return painter.width <= maxWidth;
  }

  try {
    if (fits(path)) return path;
    // 「放得下」对字数单调，二分即可，省得逐字试。
    int lo = 5;
    int hi = path.length;
    while (lo < hi) {
      final int mid = (lo + hi + 1) ~/ 2;
      if (fits(middleEllipsisPath(path, maxChars: mid))) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return middleEllipsisPath(path, maxChars: lo);
  } finally {
    painter.dispose();
  }
}

/// 设置行：标签列 + 值列。
class DeliverySettingRow extends StatelessWidget {
  const DeliverySettingRow({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return SizedBox(
      height: kDvRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: kDvLabelColumn,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.body.copyWith(color: c.fg4, height: kDvLhSans12 / 12),
              ),
            ),
            const SizedBox(width: InkSpacing.sm),
            Expanded(child: value),
          ],
        ),
      ),
    );
  }
}

/// 值盒：23 高 + 1px 底线，无左右上边框、无底色、无圆角。
class DeliveryUnderlineBox extends StatelessWidget {
  const DeliveryUnderlineBox({super.key, required this.child, this.danger = false});

  final Widget child;

  /// 校验失败时底线转 danger（时间码起点非法）。
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return Container(
      height: kDvValueBoxHeight,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: danger ? c.danger : c.control),
        ),
      ),
      child: child,
    );
  }
}

/// 只读派生值（无衬线）。**没有 ▼**，见文件头注。
class DeliveryReadonlyValue extends StatelessWidget {
  const DeliveryReadonlyValue({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return DeliveryUnderlineBox(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.body.copyWith(color: c.fg2, height: kDvLhSans12 / 12),
      ),
    );
  }
}

/// 只读等宽值（帧率 / 命名）。
class DeliveryMonoValue extends StatelessWidget {
  const DeliveryMonoValue({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return DeliveryUnderlineBox(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.mono.copyWith(color: c.fg2, height: kDvLhMono11 / 11),
      ),
    );
  }
}

/// 开关行的值 = 26×14 胶囊 + 注解文字（比只读值暗两档）。
/// 胶囊与文字整块可点——14px 高的胶囊单独做点击区太小。
///
/// 几何与 `ws_primitives.dart` 的 `WsToggle` 相同，但**不引用它**：那件把标签
/// 放在一个无约束 Row 里，196px 的值列放不下英文注解（"Written to clip comments
/// (size · motion)" 要 228px）就会 RenderFlex overflow。这里的标签要能省略号收尾，
/// 所以自己排（复刻件同样没引用 WsToggle，理由相同）。
class DeliveryToggleValue extends StatelessWidget {
  const DeliveryToggleValue({
    super.key,
    required this.on,
    required this.label,
    required this.onChanged,
  });

  final bool on;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Semantics(
      toggled: on,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!on),
          child: SizedBox(
            height: 16,
            child: Row(
              children: <Widget>[
                _Pill(on: on, colors: c),
                const SizedBox(width: InkSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.meta.copyWith(
                      color: c.fg5,
                      height: kDvLhSans11 / 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 26×14 胶囊 + 10×10 圆钮（开启琥珀底，关闭 controlStrong）。
class _Pill extends StatelessWidget {
  const _Pill({required this.on, required this.colors});

  final bool on;
  final InkColors colors;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 26,
        height: 14,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: on ? colors.accent : colors.controlStrong,
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
                  color: colors.fg1,
                  borderRadius: BorderRadius.circular(InkRadius.pill),
                ),
              ),
            ),
          ],
        ),
      );
}

/// 目标软件的四段分段控件。
///
/// 可选性由调用方（registry）给，本构件只管呈现：选中段 control 底 + fg1；
/// 可选未选中 fg4；**不可选的段 fg6 + onTap null**（不是空闭包——
/// test/quality/no_dead_interactive_test.dart 明文禁止）。
class DeliverySegments<T> extends StatelessWidget {
  const DeliverySegments({
    super.key,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.enabledOf,
    required this.keyOf,
    required this.tooltipOf,
    required this.onSelect,
  });

  final List<T> items;
  final T selected;
  final String Function(T item) labelOf;
  final bool Function(T item) enabledOf;
  final Key Function(T item) keyOf;

  /// 不可选时的 Tooltip 文案；可选段返回 null。
  final String? Function(T item) tooltipOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: kDvSegmentsHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        children: <Widget>[
          for (final T item in items)
            Expanded(
              child: _Segment(
                itemKey: keyOf(item),
                label: labelOf(item),
                selected: item == selected,
                enabled: enabledOf(item),
                tooltip: tooltipOf(item),
                onTap: enabledOf(item) ? () => onSelect(item) : null,
                colors: c,
                typo: t,
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.itemKey,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
    required this.colors,
    required this.typo,
  });

  final Key itemKey;
  final String label;
  final bool selected;
  final bool enabled;
  final String? tooltip;
  final VoidCallback? onTap;
  final InkColors colors;
  final InkTypography typo;

  @override
  Widget build(BuildContext context) {
    final Widget cell = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // 选中段的底色与边框同色——稿就是这么写的，不是描边（复刻件同注）。
        color: selected ? colors.control : null,
        // 最后一段也有右边线，与外框边叠成 2px（稿的写法，照抄）。
        border: Border(right: BorderSide(color: colors.control)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: typo.body.copyWith(
          color: !enabled
              ? colors.fg6
              : selected
                  ? colors.fg1
                  : colors.fg4,
          height: kDvLhSans12 / 12,
        ),
      ),
    );
    final Widget tappable = Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          key: itemKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: cell,
        ),
      ),
    );
    final String? message = tooltip;
    return message == null
        ? tappable
        : Tooltip(message: message, child: tappable);
  }
}

/// 时间码起点输入框：等宽 + 底线，失焦校验 `HH:MM:SS:FF`。
///
/// 非法时**底线转 danger 并回退原值**（任务书 §2.2）。danger 态一直留着，
/// 直到用户再动一次这个框——改完就被弹回去、还什么痕迹都不留，用户只会以为自己手滑。
class DeliveryTimecodeField extends StatefulWidget {
  const DeliveryTimecodeField({
    super.key,
    required this.frames,
    required this.onCommit,
  });

  final int frames;
  final ValueChanged<int> onCommit;

  @override
  State<DeliveryTimecodeField> createState() => _DeliveryTimecodeFieldState();
}

class _DeliveryTimecodeFieldState extends State<DeliveryTimecodeField> {
  late final TextEditingController _controller =
      TextEditingController(text: formatEdlTimecode(widget.frames));
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);
  bool _invalid = false;

  @override
  void didUpdateWidget(DeliveryTimecodeField old) {
    super.didUpdateWidget(old);
    // 外部值变了（切项目 / 回滚）而用户没在编辑 ⇒ 同步显示。
    if (widget.frames != old.frames && !_focus.hasFocus) {
      _controller.text = formatEdlTimecode(widget.frames);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    _commit();
  }

  void _commit() {
    final int? parsed = parseEdlTimecode(_controller.text);
    if (parsed == null) {
      setState(() => _invalid = true);
      _controller.text = formatEdlTimecode(widget.frames);
      return;
    }
    if (_invalid) setState(() => _invalid = false);
    if (parsed != widget.frames) widget.onCommit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final Widget field = DeliveryUnderlineBox(
      danger: _invalid,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onSubmitted: (_) => _commit(),
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        cursorColor: c.accent,
        cursorWidth: 1,
        style: t.mono.copyWith(color: c.fg2, height: kDvLhMono11 / 11),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
    return _invalid
        ? Tooltip(message: context.l10n.deliveryTcInvalid, child: field)
        : field;
  }
}

/// 可折叠分组的外壳（稿上三个组都是展开态；组头 26 + 组身 + 1px 下沿）。
class DeliveryGroup extends StatelessWidget {
  const DeliveryGroup({super.key, required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

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
            height: kDvRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              child: Row(
                children: <Widget>[
                  Text(
                    kDvCaret,
                    style: t.nano.copyWith(color: c.fg5, height: 13 / 9),
                  ),
                  const SizedBox(width: InkSpacing.s6),
                  Text(
                    title,
                    style: t.bodyStrong.copyWith(
                      color: c.fg3,
                      height: kDvLhSans12 / 12,
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
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}
