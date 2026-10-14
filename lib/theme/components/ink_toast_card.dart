// InkToastCard：右下角通知卡的纯呈现层（画布重设计稿 › 通知）。
//
// 【它不认识 ToastKind / ToastEntry】只吃纯数据 + 回调。类型用本文件自己的
// [InkToastTone]，由 features/notifications 那层薄壳映射——theme 不得 import
// features/（test/quality/no_reverse_layer_import_test.dart），也不碰 core：theme 层
// 至今零 core 依赖，这里不开这个头。缩略图收 [ImageProvider] 而不是路径：按显示尺寸
// 缩略解码与 dart:io 都留在 feature 侧。
//
// 视觉规格：
// - surface4 底 + 1px overlayBorder + bentoBtn 圆角 + InkShadow.overlay；内边距 12，左右两栏间距 12
// - 左：40×40 缩略图（cover、sm 圆角，右下角叠 16px 类型徽标），或 40×40 surface5 底块 +
//   20px 类型图标（success → success、error → danger、warning / progress → accent（进行中转圈）、
//   info → fg4、undo → fg3）。【类型永远不只靠颜色】：有缩略图时图标退成徽标，不消失
// - 中：标题 bodyStrong fg1 ≤2 行；正文 meta fg4 ≤2 行；出处 micro fg5 一行；
//   进行中：4px 进度条（有值 = 确定态 + 右侧等宽百分比；无值 = 不确定态）；
//   按钮行靠右：次按钮（ghost）在左、主按钮（琥珀）在右，都是 24 高
// - 右上 ×：24×24 命中区、16px 图标，只在悬停 / 卡内有焦点时显形。语义节点一直在
//   （读屏随时能关）——透明的只是画面
// - 整张卡可点 = 主按钮。这只是指针的便捷入口（excludeFromSemantics）：键盘与读屏
//   走主按钮本身，同一个回调，不会出现两个焦点停靠点念同一句话
// - 进行中 → 终态原地切换：左侧图块交叉淡入，卡片本身不重放进场
//
// 【没有 Tooltip】这张卡画在 MaterialApp.builder 那一层，上面没有 Overlay。
//
// 读屏：卡是一个 liveRegion 容器（polite）；失败卡在平台支持播报时改走 assertive
// （SemanticsService.sendAnnouncement），此时不再标 liveRegion，免得同一句念两遍；
// 进行中的卡也不标（进度一跳就念一遍），原地变成终态时才标上。卡内每个按钮各自
// 成一个语义节点（见 _ownNode）。
// 减弱动效（MediaQuery.disableAnimations）下：进行中图标不转、交叉淡入缩到 fast 档。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../app_theme.dart';
import '../icons/ink_glyph.dart';
import '../primitives/ink_activatable.dart';
import '../tokens.dart';
import '../typography.dart';
import 'ink_icon.dart';
import 'ink_primitives.dart';

/// 通知卡的类型（呈现侧）。与 core 的 ToastKind 一一对应，映射在 feature 层。
enum InkToastTone {
  info,
  success,
  warning,
  error,
  progress,
  undo,
}

InkGlyph _glyphOf(InkToastTone tone) => switch (tone) {
      InkToastTone.info => InkGlyph.info,
      InkToastTone.success => InkGlyph.success,
      InkToastTone.warning => InkGlyph.warning,
      InkToastTone.error => InkGlyph.error,
      InkToastTone.progress => InkGlyph.progress,
      InkToastTone.undo => InkGlyph.undo,
    };

Color _colorOf(InkColors c, InkToastTone tone) => switch (tone) {
      InkToastTone.success => c.success,
      InkToastTone.error => c.danger,
      InkToastTone.warning || InkToastTone.progress => c.accent,
      InkToastTone.info => c.fg4,
      InkToastTone.undo => c.fg3,
    };

/// 卡内按钮高：与 InkPrimaryButton 不带边框时的默认内容高同为 24。
const double _kActionHeight = InkSpacing.lg;

/// 组件固有节奏（非全局 token）：进行中图标转一圈的时长。
const Duration _kSpinTurn = Duration(milliseconds: 900);

class InkToastCard extends StatefulWidget {
  const InkToastCard({
    super.key,
    required this.tone,
    required this.title,
    required this.dismissLabel,
    required this.onDismiss,
    this.body,
    this.meta,
    this.thumbnail,
    this.progress,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final InkToastTone tone;
  final String title;
  final String? body;

  /// 一行小字出处（项目 · 画布 · 时间这类）。
  final String? meta;

  /// 作品缩略图；null = 画类型图标底块。
  final ImageProvider<Object>? thumbnail;

  /// 0..1，只在 [InkToastTone.progress] 时画进度条；null = 不确定态。
  final double? progress;

  /// 主按钮（琥珀，在右）。文案与回调都给才画。
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// 次按钮（ghost，在左）。文案与回调都给才画。
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// × 的读屏标签——文案由调用方给（theme 层不碰 ARB）。
  final String dismissLabel;
  final VoidCallback onDismiss;

  /// × 的显隐层（AnimatedOpacity）。测试锚点：悬停前透明、悬停后不透明。
  static const Key closeKey = Key('inkToastCard.close');

  @override
  State<InkToastCard> createState() => _InkToastCardState();
}

class _InkToastCardState extends State<InkToastCard> {
  bool _hovered = false;

  /// 卡内任一控件持焦（Tab 走进来）——× 跟着显形，键盘用户看得见能关。
  bool _focusWithin = false;

  @override
  void initState() {
    super.initState();
    if (widget.tone == InkToastTone.error) _scheduleAnnounce();
  }

  @override
  void didUpdateWidget(InkToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 进行中原地变成失败：同样要播报。
    if (widget.tone == InkToastTone.error && oldWidget.tone != InkToastTone.error) {
      _scheduleAnnounce();
    }
  }

  /// 播报要读 View / Directionality——放到帧后，initState 里不能查继承件。
  void _scheduleAnnounce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.tone != InkToastTone.error) return;
      if (!MediaQuery.supportsAnnounceOf(context)) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          widget.title,
          Directionality.of(context),
          assertiveness: Assertiveness.assertive,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    final bool announces =
        widget.tone == InkToastTone.error && MediaQuery.supportsAnnounceOf(context);
    // 进行中的卡不标 liveRegion：进度每跳一格内容就变一次，读屏会一路念下去。
    // 它变成终态那一刻（原地 complete）才标上，念的是结果。
    final bool live = !announces && widget.tone != InkToastTone.progress;
    final bool reveal = _hovered || _focusWithin;

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border.all(color: c.overlayBorder),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.overlay,
      ),
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AnimatedSwitcher(
              duration: reduce ? InkMotion.fast : InkMotion.normal,
              child: KeyedSubtree(
                key: ValueKey<(InkToastTone, ImageProvider<Object>?)>(
                  (widget.tone, widget.thumbnail),
                ),
                child: InkToastLeading(
                  tone: widget.tone,
                  image: widget.thumbnail,
                  spin: widget.tone == InkToastTone.progress && !reduce,
                ),
              ),
            ),
            const SizedBox(width: InkSpacing.s12),
            Expanded(child: _content(context)),
            _CloseButton(
              label: widget.dismissLabel,
              onTap: widget.onDismiss,
              reveal: reveal,
              reduce: reduce,
            ),
          ],
        ),
      ),
    );

    final VoidCallback? onPrimary =
        widget.primaryLabel == null ? null : widget.onPrimary;
    if (onPrimary != null) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onPrimary,
          child: card,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (bool has) {
          if (mounted && has != _focusWithin) {
            setState(() => _focusWithin = has);
          }
        },
        child: Semantics(
          container: true,
          liveRegion: live,
          child: card,
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final String? body = widget.body;
    final String? meta = widget.meta;
    final String? primaryLabel = widget.primaryLabel;
    final VoidCallback? onPrimary = widget.onPrimary;
    final String? secondaryLabel = widget.secondaryLabel;
    final VoidCallback? onSecondary = widget.onSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.bodyStrong.copyWith(color: c.fg1),
        ),
        if (body != null) ...<Widget>[
          const SizedBox(height: InkSpacing.s2),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.meta.copyWith(color: c.fg4),
          ),
        ],
        if (meta != null) ...<Widget>[
          const SizedBox(height: InkSpacing.xs),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.micro.copyWith(color: c.fg5),
          ),
        ],
        if (widget.tone == InkToastTone.progress) ...<Widget>[
          const SizedBox(height: InkSpacing.sm),
          _ProgressRow(value: widget.progress),
        ],
        if ((primaryLabel != null && onPrimary != null) ||
            (secondaryLabel != null && onSecondary != null)) ...<Widget>[
          const SizedBox(height: InkSpacing.s10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (secondaryLabel != null && onSecondary != null)
                _GhostAction(label: secondaryLabel, onTap: onSecondary),
              if (primaryLabel != null &&
                  onPrimary != null &&
                  secondaryLabel != null &&
                  onSecondary != null)
                const SizedBox(width: InkSpacing.sm),
              if (primaryLabel != null && onPrimary != null)
                _PrimaryAction(label: primaryLabel, onTap: onPrimary),
            ],
          ),
        ],
      ],
    );
  }
}

/// 左侧图块：缩略图（右下角叠类型徽标），或 surface5 底块 + 类型图标。
///
/// 铃铛历史的行也用它（32 见方 + 16px 图标），所以尺寸可调。
class InkToastLeading extends StatelessWidget {
  const InkToastLeading({
    super.key,
    required this.tone,
    this.image,
    this.size = InkToastSize.thumbnail,
    this.glyphSize = InkIconSize.md,
    this.spin = false,
  });

  final InkToastTone tone;

  /// 作品缩略图；加载失败 / 还没解出第一帧时退回图标底块。
  final ImageProvider<Object>? image;
  final double size;
  final double glyphSize;

  /// 进行中图标转圈（调用方在减弱动效时传 false）。
  final bool spin;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final Widget tile = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface5,
          borderRadius: BorderRadius.circular(InkRadius.sm),
        ),
        child: Center(
          child: _ToneGlyph(tone: tone, size: glyphSize, spin: spin),
        ),
      ),
    );
    final ImageProvider<Object>? img = image;
    if (img == null) return tile;
    return SizedBox.square(
      dimension: size,
      child: Image(
        image: img,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        // 第一帧出来之前画底块；出来之后图 + 徽标。徽标不放在外层：解码失败时
        // errorBuilder 给的是底块，外层再叠一个徽标就成了两个图标。
        frameBuilder: (BuildContext _, Widget child, int? frame, bool _) =>
            frame == null
                ? tile
                : Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(InkRadius.sm),
                          child: child,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _ToneBadge(tone: tone),
                      ),
                    ],
                  ),
        errorBuilder: (_, _, _) => tile,
      ),
    );
  }
}

/// 缩略图右下角的类型徽标：16 见方的卡底色圆 + 16px 图标。
class _ToneBadge extends StatelessWidget {
  const _ToneBadge({required this.tone});

  final InkToastTone tone;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return Container(
      width: InkIconSize.sm,
      height: InkIconSize.sm,
      decoration: BoxDecoration(color: c.surface4, shape: BoxShape.circle),
      child: InkIcon(
        _glyphOf(tone),
        size: InkIconSize.sm,
        color: _colorOf(c, tone),
      ),
    );
  }
}

/// 类型图标；进行中可转圈。
class _ToneGlyph extends StatefulWidget {
  const _ToneGlyph({
    required this.tone,
    required this.size,
    required this.spin,
  });

  final InkToastTone tone;
  final double size;
  final bool spin;

  @override
  State<_ToneGlyph> createState() => _ToneGlyphState();
}

class _ToneGlyphState extends State<_ToneGlyph>
    with SingleTickerProviderStateMixin {
  /// 只在第一次需要转的时候才建——绝大多数卡不是进行中。
  AnimationController? _turns;

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(_ToneGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    if (widget.spin) {
      final AnimationController turns =
          _turns ??= AnimationController(vsync: this, duration: _kSpinTurn);
      if (!turns.isAnimating) unawaited(turns.repeat());
    } else {
      _turns?.stop();
    }
  }

  @override
  void dispose() {
    _turns?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget icon = InkIcon(
      _glyphOf(widget.tone),
      size: widget.size,
      color: _colorOf(context.inkColors, widget.tone),
    );
    final AnimationController? turns = _turns;
    if (!widget.spin || turns == null) return icon;
    return RotationTransition(turns: turns, child: icon);
  }
}

/// 4px 进度条 + 确定态时右侧的等宽百分比。
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final double? v = value?.clamp(0.0, 1.0);
    return Row(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(InkRadius.xs),
            child: LinearProgressIndicator(
              value: v,
              minHeight: InkToastSize.progress,
              backgroundColor: c.surface5,
              valueColor: AlwaysStoppedAnimation<Color>(c.accent),
            ),
          ),
        ),
        if (v != null) ...<Widget>[
          const SizedBox(width: InkSpacing.sm),
          // 数值读数，与画布缩放百分比同一写法（canvas_header_bar.dart）。读屏不再念它：
          // 进度条自己的语义 value 就是这个百分比。
          ExcludeSemantics(
            child: Text(
              '${(v * 100).round()}%',
              style: context.inkTypography.mono.copyWith(color: c.fg4),
            ),
          ),
        ],
      ],
    );
  }
}

/// 卡内每个按钮单独成一个语义节点。不包这一层的话，按钮（button + tap）与标题文字
/// 互相"兼容"，会被并进卡片那一个节点——读屏把整张卡念成「标题，关闭通知」按钮。
Widget _ownNode(Widget button) => Semantics(container: true, child: button);

/// 次按钮：透明底，悬停 surface5；24 高。
class _GhostAction extends StatelessWidget {
  const _GhostAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return _ownNode(
      InkActivatable(
        onTap: onTap,
        semanticLabel: label,
        focusRingRadius: BorderRadius.circular(InkRadius.s3),
        builder: (BuildContext context, bool hovered, bool focused) =>
            Container(
          height: _kActionHeight,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered ? c.surface5 : Colors.transparent,
            borderRadius: BorderRadius.circular(InkRadius.s3),
          ),
          child: Text(
            label,
            style: t.body.copyWith(color: hovered ? c.fg1 : c.fg2),
          ),
        ),
      ),
    );
  }
}

/// 主按钮：琥珀底，24 高（InkPrimaryButton 不带边框时的默认高）。
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ownNode(
      InkActivatable(
        onTap: onTap,
        semanticLabel: label,
        focusRingRadius: BorderRadius.circular(InkRadius.s3),
        builder: (BuildContext context, bool hovered, bool focused) =>
            InkPrimaryButton(label, bordered: false),
      ),
    );
  }
}

/// 右上 ×。透明只是画面上的：语义节点（InkActivatable 那层 Semantics）在
/// AnimatedOpacity 之外，读屏随时找得到它。
class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.label,
    required this.onTap,
    required this.reveal,
    required this.reduce,
  });

  final String label;
  final VoidCallback onTap;

  /// 卡片被悬停 / 卡内有焦点。
  final bool reveal;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return _ownNode(
      InkActivatable(
        onTap: onTap,
        semanticLabel: label,
        focusRingRadius: BorderRadius.circular(InkRadius.s3),
        builder: (BuildContext context, bool hovered, bool focused) =>
            AnimatedOpacity(
          key: InkToastCard.closeKey,
          opacity: reveal || focused ? 1.0 : 0.0,
          duration: reduce ? Duration.zero : InkMotion.fast,
          child: Container(
            width: InkToastSize.closeHit,
            height: InkToastSize.closeHit,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hovered ? c.surface5 : Colors.transparent,
              borderRadius: BorderRadius.circular(InkRadius.s3),
            ),
            child: InkIcon(
              InkGlyph.close,
              size: InkIconSize.sm,
              color: hovered ? c.fg1 : c.fg4,
            ),
          ),
        ),
      ),
    );
  }
}
