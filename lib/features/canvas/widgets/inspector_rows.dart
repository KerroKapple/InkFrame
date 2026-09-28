// 检查器分组与行（Workspace v2 稿）：
//   InspectorGroup   26px 标题行「▼ 组名」（无底色）+ 组内 6px 上下留白 + 组底 1px borderStrong
//   InspectorRow     26px，`96px | 1fr` 两列，水平内边距 12
//   InspectorDropdown  22px 下拉：无底色 + 1px control 底线 + 右侧 ▼；内部仍是 DropdownButton<T>
//                      （测试按类型定位、行为不变）
//   InspectorToggleRow 26×14 胶囊开关（开 accent / 关 controlStrong）+ 右侧说明
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class InspectorGroup extends StatelessWidget {
  const InspectorGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Row(
              children: <Widget>[
                Text('▼', style: t.micro.copyWith(color: c.fg5)),
                const SizedBox(width: InkSpacing.s6),
                Text(title, style: t.bodyStrong.copyWith(color: c.fg3)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: InkSpacing.s6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }
}

class InspectorRow extends StatelessWidget {
  const InspectorRow({super.key, required this.label, required this.child, this.height = 26});

  final String label;
  final Widget child;

  /// 多行控件（备注 / 负向提示）传 null 让行自适应。
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
        child: Row(
          crossAxisAlignment: height == null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 96,
              child: Padding(
                padding: EdgeInsets.only(top: height == null ? InkSpacing.xs : 0),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: c.fg4)),
              ),
            ),
            const SizedBox(width: InkSpacing.sm),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// 只读值行（等宽）。
class InspectorValue extends StatelessWidget {
  const InspectorValue(this.value, {super.key, this.mono = false, this.accent = false});
  final String value;
  final bool mono;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TextStyle base = mono ? t.mono : t.body;
    return Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: base.copyWith(color: accent ? c.accent : c.fg2));
  }
}

class InspectorDropdown<T> extends StatelessWidget {
  const InspectorDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 23, // content 22 + border-bottom 1
      padding: const EdgeInsets.only(left: InkSpacing.sm, right: InkSpacing.xs),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        icon: Text('▼', style: t.micro.copyWith(color: c.fg6)),
        style: t.body.copyWith(color: c.fg2),
        dropdownColor: c.surface4,
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
    );
  }
}

class InspectorToggleRow extends StatelessWidget {
  const InspectorToggleRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.caption,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Row(
      children: <Widget>[
        Semantics(
          toggled: value,
          child: MouseRegion(
            cursor: onChanged == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : () => onChanged!(!value),
              child: Container(
                width: 26,
                height: 14,
                decoration: BoxDecoration(
                  color: value ? c.accent : c.controlStrong,
                  borderRadius: BorderRadius.circular(InkRadius.pill),
                ),
                child: Stack(
                  children: <Widget>[
                    AnimatedPositioned(
                      duration: InkMotion.fast,
                      left: value ? 14 : 2,
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
            ),
          ),
        ),
        if (caption != null) ...<Widget>[
          const SizedBox(width: InkSpacing.sm),
          Text(caption!, style: t.meta.copyWith(color: c.fg5)),
        ],
      ],
    );
  }
}
