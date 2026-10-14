// 左栏面板的共用件：面板头（标题 + 右侧挂件）、筛选框、面板体里居中的说明行。
// 大纲 / 素材 / 角色三页同款（画布重设计稿 main.js「左栏面板」的 panelHeader / filter）。
//
// 稿的元素没写 box-sizing ⇒ content-box：高度不含边框。所以面板头是 36 + 1px 下沿 = 37，
// 筛选框是 24 + 上下 1px 边 = 26（Flutter 的 Container 把边框算进 height 里，这里写总高）。
import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../theme/components/ink_icon.dart';
import '../../../../theme/icons/ink_glyph.dart';
import '../../../../theme/tokens.dart';

/// 面板头：36 高 + 1px borderSubtle 下沿，左右 12；左标题 fg1 / 500，右侧可挂件。
class LeftPanelHeader extends StatelessWidget {
  const LeftPanelHeader({super.key, required this.title, this.trailing});

  /// 稿 content-box：36 + 1px 下沿。
  static const double height = 37;

  final String title;

  /// 标题右侧的挂件（大纲页的画布切换胶囊）。靠右对齐；放不下时由它自己省略，不挤掉标题。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final Widget? right = trailing;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          Text(title, maxLines: 1, style: t.bodyStrong.copyWith(color: c.fg1)),
          if (right != null) ...<Widget>[
            const SizedBox(width: InkSpacing.sm),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: right),
            ),
          ],
        ],
      ),
    );
  }
}

/// 筛选框：外边距上 10 / 左右 12 / 下 6；24 高（+ 上下 1px 边）；surface2 底 + outline 边 + 圆角 3；
/// 左侧搜索图标，提示文字 11 号 fg6。筛选逻辑在调用方（[onChanged] 回来自己重算）。
class LeftPanelFilterField extends StatelessWidget {
  const LeftPanelFilterField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  /// 稿 content-box：24 + 上下 1px 边。
  static const double height = 26;

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(
        InkSpacing.s12,
        InkSpacing.s10,
        InkSpacing.s12,
        InkSpacing.s6,
      ),
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        children: <Widget>[
          // TODO(token): 稿上是 13px 的搜索图标；InkIconSize 只有 16 / 20，先用最近的 sm。
          InkIcon(InkGlyph.search, size: InkIconSize.sm, color: c.fg6),
          const SizedBox(width: InkSpacing.s6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: t.meta.copyWith(color: c.fg2),
              cursorColor: c.accent,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: t.meta.copyWith(color: c.fg6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 面板体里居中的一行 fg5 说明（空态 / 没有活动项目）。
class LeftPanelNote extends StatelessWidget {
  const LeftPanelNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: t.meta.copyWith(color: c.fg5),
        ),
      ),
    );
  }
}
