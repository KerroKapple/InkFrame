// InkOverlayDialog — 浮层壳（Screens 稿第 3 屏设置浮层的外形）。
//
// 一块居中的卡片：1px control 边框 + 6 圆角 + overlay 阴影，竖向三段
//   41 标题栏（标题 500 | 撑开 | Esc 等宽提示 | ✕）
//   内容（撑满剩余高）
//   45 底部条（11px 说明 | 撑开 | 动作）
// 稿是 content-box，所以 [width]/[height] 是内容盒尺寸，外面再加 1px 边框
// （ConstrainedBox 给 +2）——这也是「标题栏宽 == width」这条断言成立的原因。
//
// 设置浮层与回收站（P7：720×520，左侧无导航）共用这一个壳。两处各画一遍必然分叉
// ——稿上它们就是同一个外形。本组件是纯呈现：只收字符串 / 子树 / 回调，不认识
// 任何 feature 的模型（test/quality/no_reverse_layer_import_test.dart）。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';
import '../typography.dart';

class InkOverlayDialog extends StatelessWidget {
  const InkOverlayDialog({
    super.key,
    required this.title,
    required this.width,
    required this.height,
    required this.child,
    this.titleBarKey,
    this.closeKey,
    this.escHint,
    this.closeTooltip,
    this.onClose,
    this.footerNote,
    this.footerActions = const <Widget>[],
  });

  /// 标题栏左侧的标题。
  final String title;

  /// 内容盒尺寸（稿的 content-box；边框在外面另加 1px）。
  final double width;
  final double height;

  /// 标题栏与底部条之间那一段。
  final Widget child;

  /// 测试锚点（量标题栏高/宽、点 ✕）。
  final Key? titleBarKey;
  final Key? closeKey;

  /// 标题栏右侧的等宽键位提示（通常是 'Esc'）；null = 不画。
  final String? escHint;

  /// ✕ 的 tooltip；[onClose] 为 null 时整个 ✕ 不画（没有关闭动作就不留死按钮）。
  final String? closeTooltip;
  final VoidCallback? onClose;

  /// 底部条左侧的 11px 说明；null = 不画。
  final String? footerNote;

  /// 底部条右侧的动作（已按稿的 10px 间距排布）。空 = 不画底部条。
  final List<Widget> footerActions;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final bool hasFooter = footerNote != null || footerActions.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width + 2,
            maxHeight: height + 2,
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surface3,
              border: Border.all(color: c.control),
              borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
              boxShadow: InkShadow.overlay,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TitleBar(
                  barKey: titleBarKey,
                  closeKey: closeKey,
                  title: title,
                  escHint: escHint,
                  closeTooltip: closeTooltip,
                  onClose: onClose,
                ),
                Expanded(child: child),
                if (hasFooter)
                  _Footer(note: footerNote, actions: footerActions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 稿：40 高 + 1px 下沿，surface2；标题 500 | 撑开 | Esc 等宽 10 | ✕。
class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.barKey,
    required this.closeKey,
    required this.title,
    required this.escHint,
    required this.closeTooltip,
    required this.onClose,
  });

  final Key? barKey;
  final Key? closeKey;
  final String title;
  final String? escHint;
  final String? closeTooltip;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      key: barKey,
      height: 41, // content 40 + border-bottom 1
      padding: const EdgeInsets.only(left: InkSpacing.md, right: InkSpacing.sm),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodyStrong.copyWith(color: c.fg1),
            ),
          ),
          const Spacer(),
          if (escHint != null) ...<Widget>[
            Text(escHint!, style: t.monoSmall.copyWith(color: c.fg6)),
            const SizedBox(width: InkSpacing.xs),
          ],
          if (onClose != null)
            IconButton(
              key: closeKey,
              tooltip: closeTooltip,
              icon: Icon(Icons.close, size: InkSpacing.md, color: c.fg5),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

/// 稿：44 高 + 上沿 1，surface2；11px 说明 | 撑开 | 动作（彼此 10px）。
class _Footer extends StatelessWidget {
  const _Footer({required this.note, required this.actions});

  final String? note;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: 45, // content 44 + border-top 1
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          if (note != null)
            Flexible(
              child: Text(
                note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.meta.copyWith(color: c.fg6),
              ),
            ),
          const Spacer(),
          for (int i = 0; i < actions.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: InkSpacing.s10),
            actions[i],
          ],
        ],
      ),
    );
  }
}
