// ToastLayer：通知卡层。挂在 MaterialApp.builder 上——Stack[ Navigator, 右下角卡片栈 ]，
// 所以卡片画在所有路由之上：设置浮层、showDialog 的对话框开着也看得见、点得到。
//
// 【这一层上面没有 Overlay / Navigator】有 Theme / Localizations / MediaQuery，但
// 不能用 Tooltip、不能 showDialog。卡片包一层透明 Material：builder 层的默认文字样式
// 是 WidgetsApp 的调试红字（带黄色双下划线），不包就会漏出来。
//
// 位置：右 16，底 = 状态栏高 + 16（两段分开写：Positioned 管状态栏、Padding 管间距，
// 不在 widget 里拿 token 做加法）。窗口窄于 [InkToastSize.narrowWindow] 时左右各留 16 撑满。
// 最新的一张贴着角，更旧的往上叠，间距 8；最多 [kToastMaxVisible] 张，多出来的收成
// 卡片栈上方的「还有 N 条 · 查看全部」，点它打开铃铛历史。
//
// 动效：进场上移 16 + 淡入 200ms easeOutCubic；退场淡出 + 下移 8、150ms（与 ToastCenter
// 的移除时刻对齐）；减弱动效时只淡入淡出、120ms。进行中 → 终态是同一张卡（同一个
// ValueKey），不重放进场。
//
// 暂停：鼠标在卡片栈上（MouseRegion，deferToChild——卡与卡之间的缝不吃点击）、
// 窗口不在前台（AppLifecycleListener）时，ToastCenter 停表。
//
// 生成完成 / 失败的通知也从这一层发出（JobNotificationListener），与哪个标签在台上无关。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_toast_card.dart';
import '../../../theme/motion.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../shell/widgets/shell_status_bar.dart';
import '../models/toast_entry.dart';
import '../providers/toast_center.dart';
import 'job_notification_listener.dart';

/// ToastKind → 呈现侧的类型（theme 层不认识 core 的枚举）。
InkToastTone toastToneOf(ToastKind kind) => switch (kind) {
      ToastKind.info => InkToastTone.info,
      ToastKind.success => InkToastTone.success,
      ToastKind.warning => InkToastTone.warning,
      ToastKind.error => InkToastTone.error,
      ToastKind.progress => InkToastTone.progress,
      ToastKind.undo => InkToastTone.undo,
    };

/// 缩略图绝对路径 → 按显示尺寸缩略解码的 ImageProvider（LB-23：别把原图整张塞进
/// ImageCache）。卡片与铃铛历史共用。
ImageProvider<Object> toastThumbnailImage(
  BuildContext context,
  String absolutePath,
  double logicalSize,
) =>
    ResizeImage.resizeIfNeeded(
      (logicalSize * MediaQuery.devicePixelRatioOf(context)).round(),
      null,
      FileImage(File(absolutePath)),
    );

class ToastLayer extends ConsumerStatefulWidget {
  const ToastLayer({super.key, required this.child});

  /// MaterialApp.builder 交进来的 Navigator。
  final Widget child;

  /// 「还有 N 条 · 查看全部」。
  static const Key moreKey = Key('toastLayer.more');

  @override
  ConsumerState<ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends ConsumerState<ToastLayer> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // 窗口失焦 / 最小化 / 被遮住 ⇒ 停表；回到前台接着走。
    _lifecycle = AppLifecycleListener(
      onStateChange: (AppLifecycleState s) => ref
          .read(toastCenterProvider.notifier)
          .setWindowActive(s == AppLifecycleState.resumed),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return JobNotificationListener(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          const _ToastStack(),
        ],
      ),
    );
  }
}

/// 右下角的卡片栈。必须是 Stack 的直接子（返回 Positioned）。
class _ToastStack extends ConsumerWidget {
  const _ToastStack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ToastCenterState s = ref.watch(toastCenterProvider);
    final ToastCenter center = ref.read(toastCenterProvider.notifier);
    final List<ToastEntry> shown = s.shown;
    final int more = s.overflowCount;
    final bool any = shown.isNotEmpty || more > 0;
    final bool narrow =
        MediaQuery.sizeOf(context).width < InkToastSize.narrowWindow;

    final List<Widget> children = <Widget>[
      if (more > 0)
        Align(
          alignment: Alignment.centerRight,
          child: _MorePill(
            label: context.l10n.toastMore(more),
            onTap: center.openHistory,
          ),
        ),
      for (final ToastEntry e in shown)
        _ToastSlot(
          key: ValueKey<int>(e.id),
          entry: e,
          onDismiss: () => center.dismiss(e.id),
        ),
    ];

    return Positioned(
      left: narrow ? InkSpacing.md : null,
      right: InkSpacing.md,
      bottom: ShellStatusBar.height,
      width: narrow ? null : InkToastSize.width,
      child: Padding(
        padding: const EdgeInsets.only(bottom: InkSpacing.md),
        // MouseRegion 恒在树里：卡片栈被抽空时它若跟着卸载，onExit 就不会来，
        // ToastCenter 会一直以为鼠标还停在上面。
        child: MouseRegion(
          hitTestBehavior: HitTestBehavior.deferToChild,
          onEnter: (_) => center.setHovered(true),
          onExit: (_) => center.setHovered(false),
          child: Semantics(
            container: any,
            explicitChildNodes: true,
            label: any ? context.l10n.toastRegion : null,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < children.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: InkSpacing.sm),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 一张卡的进场 / 退场动画 + 接线（ToastEntry → InkToastCard）。
class _ToastSlot extends ConsumerStatefulWidget {
  const _ToastSlot({
    super.key,
    required this.entry,
    required this.onDismiss,
  });

  final ToastEntry entry;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_ToastSlot> createState() => _ToastSlotState();
}

class _ToastSlotState extends ConsumerState<_ToastSlot>
    with TickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: InkMotion.normal);
  late final AnimationController _exit =
      AnimationController(vsync: this, duration: InkMotionSpring.popoverOut);
  bool _started = false;
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _enter.duration = _reduce ? InkMotion.fast : InkMotion.normal;
    _exit.duration = _reduce ? InkMotion.fast : InkMotionSpring.popoverOut;
    if (!_started) {
      _started = true;
      _enter.forward();
      if (widget.entry.leaving) _exit.forward();
    }
  }

  @override
  void didUpdateWidget(_ToastSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.leaving && !oldWidget.entry.leaving) _exit.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    super.dispose();
  }

  /// 卡上的按钮：先做事，再收卡——按下了就是这张卡完成了使命。
  VoidCallback? _act(ToastAction? action) {
    if (action == null) return null;
    final int id = widget.entry.id;
    return () {
      action.onPressed();
      ref.read(toastCenterProvider.notifier).dismiss(id);
    };
  }

  @override
  Widget build(BuildContext context) {
    final ToastEntry e = widget.entry;
    final String? thumbnail = e.thumbnailPath;
    final Widget card = IgnorePointer(
      ignoring: e.leaving,
      child: InkToastCard(
        tone: toastToneOf(e.kind),
        title: e.title,
        body: e.body,
        meta: e.meta,
        thumbnail: thumbnail == null
            ? null
            : toastThumbnailImage(context, thumbnail, InkToastSize.thumbnail),
        progress: e.progress,
        primaryLabel: e.primary?.label,
        onPrimary: _act(e.primary),
        secondaryLabel: e.secondary?.label,
        onSecondary: _act(e.secondary),
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: widget.onDismiss,
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_enter, _exit]),
      builder: (BuildContext context, Widget? child) {
        final double enter = Curves.easeOutCubic.transform(_enter.value);
        final double exit = Curves.easeIn.transform(_exit.value);
        final double dy = _reduce
            ? 0.0
            : (1 - enter) * InkSpacing.md + exit * InkSpacing.sm;
        return Opacity(
          opacity: enter * (1 - exit),
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: card,
    );
  }
}

/// 「还有 N 条 · 查看全部」：卡片栈上方右对齐的小胶囊。
class _MorePill extends StatelessWidget {
  const _MorePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return InkActivatable(
      key: ToastLayer.moreKey,
      onTap: onTap,
      semanticLabel: label,
      focusRingRadius: BorderRadius.circular(InkRadius.pill),
      builder: (BuildContext context, bool hovered, bool focused) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s10,
          vertical: InkSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: hovered ? c.surface5 : c.surface4,
          border: Border.all(color: c.overlayBorder),
          borderRadius: BorderRadius.circular(InkRadius.pill),
        ),
        child: Text(
          label,
          style: context.inkTypography.meta.copyWith(color: c.fg3),
        ),
      ),
    );
  }
}
