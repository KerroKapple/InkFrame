// ShellTaskCapsule：状态栏里的任务胶囊 + 任务弹层的开关（画布重设计稿 main.js「状态栏 + 任务胶囊」）。
//
// 取代画布底栏的渲染队列（PR-6 页签去重）。job 是全局的，所以胶囊挂在外壳状态栏上、所有标签下都在，
// 范围是 jobsRegistry 里的全部 job（不再只看当前画布）。三态：
//   - 有活动 job：wash 底 + washBorder 边 + accent 字，转圈的进度图标，「生成中 N · 排队 M」，为 0 的那段
//     省掉。提交中（submitting）算排队——与 nodeStatusOf、原渲染队列同一口径。
//   - 只剩终态 job（注册表里还没清）：outline 边、fg5 字，「任务 N」；有失败再加「· 失败 K」（danger）。
//   - 注册表空：什么都不画（连同左侧间距一起收成零宽）。
// 点胶囊开弹层（shell_task_popover.dart），再点、点外面（含铃铛）或按 Esc 关（弹层开着时持焦）。弹层走 OverlayPortal 挂到
// Navigator 的 Overlay 上，锚在胶囊正上方、左沿对齐，底边距状态栏上沿 8——与铃铛下拉同一套做法
// （notification_bell.dart）。注册表清空时胶囊连同弹层一起消失。
//
// 只 watch 四个计数的摘要（record 自带值相等）：job 的进度每跳一次都会改注册表，胶囊不该跟着重建。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_icon.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';
import 'shell_status_bar.dart';
import 'shell_task_popover.dart';

/// 进行中图标转一圈的时长（与左栏大纲、通知卡的进行中图标同速）。
const Duration _kSpinTurn = Duration(milliseconds: 900);

/// 胶囊要的四个数：生成中 / 排队（含提交中）/ 终态 / 其中失败。
typedef TaskCapsuleSummary = ({int running, int queued, int terminal, int failed});

/// 注册表 → 胶囊摘要。顶层函数（不是闭包）：喂给 provider.select 时多次 build 之间 identical。
TaskCapsuleSummary taskCapsuleSummaryOf(List<JobState> jobs) {
  int running = 0;
  int queued = 0;
  int terminal = 0;
  int failed = 0;
  for (final JobState job in jobs) {
    switch (job) {
      case JobRunning():
        running++;
      case JobQueued() || JobSubmitting():
        queued++;
      case JobFailed():
        terminal++;
        failed++;
      case JobSucceeded() || JobCancelled():
        terminal++;
    }
  }
  return (running: running, queued: queued, terminal: terminal, failed: failed);
}

class ShellTaskCapsule extends ConsumerStatefulWidget {
  const ShellTaskCapsule({super.key, this.leadingGap = 0});

  /// 胶囊左侧与前一项的间距——只在胶囊画出来时才占位。
  final double leadingGap;

  /// 稿：18 高（button 默认 border-box，含 1px 边）。
  static const double height = 18;

  /// 弹层底边到胶囊上沿的距离：稿「底边距状态栏上沿 8」，再加上胶囊上沿到状态栏上沿那一段
  /// （状态栏 1px 上描边 + 胶囊在 22 高内容区里竖直居中的余量）。
  static const double popoverLift = InkSpacing.sm +
      ShellStatusBar.topBorder +
      (ShellStatusBar.height - ShellStatusBar.topBorder - height) / 2;

  /// 胶囊本体（点击壳）的测试锚点。
  static const Key capsuleKey = Key('shell.tasks.capsule');

  /// 胶囊的描边盒（三态的底色 / 边色画在这上面）。
  static const Key bodyKey = Key('shell.tasks.capsule.body');

  @override
  ConsumerState<ShellTaskCapsule> createState() => _ShellTaskCapsuleState();
}

class _ShellTaskCapsuleState extends ConsumerState<ShellTaskCapsule> {
  final OverlayPortalController _portal = OverlayPortalController(debugLabel: 'shellTasks');
  final LayerLink _link = LayerLink();
  final FocusNode _panelFocus = FocusNode(debugLabel: 'shellTasks');

  /// 胶囊与弹层同属一个 TapRegion 组（与铃铛同一做法）：点胶囊是切换，不算「点外面」；
  /// 点别处（含铃铛）就关。
  final Object _tapGroup = Object();

  @override
  void dispose() {
    _panelFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_portal.isShowing) {
      _portal.hide();
      return;
    }
    _portal.show();
    // 弹层挂上之后再要焦点：Esc 要能直接关它。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _portal.isShowing) _panelFocus.requestFocus();
    });
  }

  void _close() {
    if (_portal.isShowing) _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    final TaskCapsuleSummary summary = ref.watch(jobsRegistryProvider.select(taskCapsuleSummaryOf));
    if (summary.running + summary.queued + summary.terminal == 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: widget.leadingGap),
      child: TapRegion(
        groupId: _tapGroup,
        child: CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (BuildContext context) => _PopoverLayer(
              link: _link,
              groupId: _tapGroup,
              focusNode: _panelFocus,
              onClose: _close,
            ),
            child: InkActivatable(
              key: ShellTaskCapsule.capsuleKey,
              onTap: _toggle,
              focusRingRadius: BorderRadius.circular(InkRadius.pill),
              builder: (BuildContext context, bool hovered, bool focused) =>
                  _CapsuleBody(summary: summary, hovered: hovered),
            ),
          ),
        ),
      ),
    );
  }
}

/// 胶囊本体：18 高、圆角 999、左右 8、图标和文字间距 6、10 号字。
class _CapsuleBody extends StatelessWidget {
  const _CapsuleBody({required this.summary, required this.hovered});

  final TaskCapsuleSummary summary;
  final bool hovered;

  static String _activeLabel(AppLocalizations l, TaskCapsuleSummary s) => <String>[
        if (s.running > 0) l.taskCapsuleRunning(s.running),
        if (s.queued > 0) l.taskCapsuleQueued(s.queued),
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final bool active = summary.running + summary.queued > 0;
    return Container(
      key: ShellTaskCapsule.bodyKey,
      height: ShellTaskCapsule.height,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
      decoration: BoxDecoration(
        // 稿：活动态的 wash 底是行内样式，压过 hover 的 surface5；只有终态胶囊有 hover 底。
        color: active ? c.accentWash : (hovered ? c.surface5 : null),
        border: Border.all(color: active ? c.accentWashBorder : c.outline),
        borderRadius: BorderRadius.circular(InkRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: active
            ? <Widget>[
                _Spin(
                  child: InkIcon(InkGlyph.progress, size: InkIconSize.s11, color: c.accent),
                ),
                const SizedBox(width: InkSpacing.s6),
                Text(
                  _activeLabel(l, summary),
                  maxLines: 1,
                  style: t.micro.copyWith(color: c.accent),
                ),
              ]
            : <Widget>[
                Text.rich(
                  TextSpan(
                    text: l.taskCapsuleTotal(summary.terminal),
                    children: <InlineSpan>[
                      // 「· 失败 K」整段 danger（连同前面的分隔点）。
                      if (summary.failed > 0)
                        TextSpan(
                          text: ' · ',
                          style: TextStyle(color: c.danger),
                          children: <InlineSpan>[
                            TextSpan(text: l.taskCapsuleFailed(summary.failed)),
                          ],
                        ),
                    ],
                  ),
                  maxLines: 1,
                  style: t.micro.copyWith(color: c.fg5),
                ),
              ],
      ),
    );
  }
}

/// 浮层根：铺满 Overlay 的 Align（本身不吃点击）+ 跟着胶囊走的弹层。
/// 弹层左沿对齐胶囊左沿、底边在胶囊上沿之上 [ShellTaskCapsule.popoverLift]。
class _PopoverLayer extends StatelessWidget {
  const _PopoverLayer({
    required this.link,
    required this.groupId,
    required this.focusNode,
    required this.onClose,
  });

  final LayerLink link;
  final Object groupId;
  final FocusNode focusNode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: link,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0, -ShellTaskCapsule.popoverLift),
        child: TapRegion(
          groupId: groupId,
          onTapOutside: (_) => onClose(),
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): onClose,
            },
            child: Focus(focusNode: focusNode, child: const ShellTaskPopover()),
          ),
        ),
      ),
    );
  }
}

/// 进行中图标转圈；减弱动效（MediaQuery.disableAnimations）下不转——与左栏大纲、通知卡同一口径。
class _Spin extends StatefulWidget {
  const _Spin({required this.child});

  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(vsync: this, duration: _kSpinTurn);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turns.stop();
    } else if (!_turns.isAnimating) {
      unawaited(_turns.repeat());
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _turns, child: widget.child);
}
