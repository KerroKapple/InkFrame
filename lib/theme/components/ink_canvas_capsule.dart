// InkCanvasCapsule：画布轻提示胶囊的纯呈现层（GapsCanvas 稿 ›「画布轻提示胶囊」：「我刚做了什么」）。
//
// 【它不认识画布】只吃文案 + 回调：文案由调用方给（theme 层不碰 ARB），出现 / 消失 / 计时 / 定位都在
// features/canvas 的 CanvasCapsuleHost 与 canvasCapsuleProvider——theme 不得 import features/
// （test/quality/no_reverse_layer_import_test.dart）。
//
// 视觉规格：
// - 高 28（InkCanvasCapsuleSize.height）、全圆角（InkRadius.pill）、surface4 底、1px overlayBorder 描边；左右内边距 12
// - 文字 meta fg2，单行，放不下时省略号——收窄的是文字，动作与键位保持完整
// - 动作（可选）：accent 文字 +（可选）fg5 等宽键位提示，如「重做 Ctrl Y」
//
// 【动作不进 Tab 序】胶囊会自己消失，焦点停在一个转眼就没的控件上只会把键盘用户甩回路由作用域；
// 动作包 ExcludeFocus，只给鼠标，键盘用户走该动作自己的快捷键（胶囊上写着键位）。读屏仍能点（语义上它是按钮）。
//
// 读屏：整枚胶囊是一个 liveRegion 容器（polite），出现时念一次；同一张卡原地改字只念当前文字，不新增节点。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../primitives/ink_activatable.dart';
import '../tokens.dart';

class InkCanvasCapsule extends StatelessWidget {
  const InkCanvasCapsule({
    super.key,
    required this.text,
    this.actionLabel,
    this.actionHint,
    this.onAction,
  });

  final String text;

  /// 动作按钮的字（如「重做」）。与 [onAction] 都给才画动作。
  final String? actionLabel;

  /// 动作旁的键位提示（如「Ctrl Y」/「⌘⇧Z」），按平台由调用方给。
  final String? actionHint;

  final VoidCallback? onAction;

  /// 胶囊底板（DecoratedBox）。测试锚点：量底色 / 描边 / 圆角。
  static const Key surfaceKey = Key('inkCanvasCapsule.surface');

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final t = context.inkTypography;
    final String? label = actionLabel;
    final VoidCallback? onTap = onAction;
    final String? hint = actionHint;

    return Semantics(
      container: true,
      liveRegion: true,
      child: SizedBox(
        height: InkCanvasCapsuleSize.height,
        child: DecoratedBox(
          key: surfaceKey,
          decoration: BoxDecoration(
            color: c.surface4,
            border: Border.all(color: c.overlayBorder),
            borderRadius: BorderRadius.circular(InkRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: t.meta.copyWith(color: c.fg2),
                  ),
                ),
                if (label != null && onTap != null) ...<Widget>[
                  const SizedBox(width: InkSpacing.sm),
                  ExcludeFocus(
                    child: InkActivatable(
                      onTap: onTap,
                      paintFocusRing: false,
                      builder: (BuildContext context, bool hovered, bool focused) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            style: t.meta.copyWith(
                              color: c.accent,
                              decoration: hovered ? TextDecoration.underline : null,
                              decorationColor: c.accent,
                            ),
                          ),
                          if (hint != null) ...<Widget>[
                            const SizedBox(width: InkSpacing.xs),
                            Text(
                              hint,
                              maxLines: 1,
                              softWrap: false,
                              style: t.mono.copyWith(color: c.fg5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
