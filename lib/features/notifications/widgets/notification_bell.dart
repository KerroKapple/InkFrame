// NotificationBell：外壳 chrome 右侧的铃铛 + 本次会话的通知历史下拉。
//
// - 铃铛：16px bell 图标，22 见方命中区（与 ⚙ 同大）。有未读时右上角一个点：accent；
//   未读里有失败则 danger
// - 下拉：OverlayPortal 挂到 Navigator 的 Overlay 上（铃铛在路由里，上面有 Overlay——
//   卡片层没有，所以历史面板不能放到卡片层去），锚在铃铛正下方、右边对齐。
//   宽 InkToastSize.historyWidth、最高 historyMaxHeight，超出滚动。
//   头部「通知」+「清空」；「本次会话」小标题；每行 32 见方缩略图 / 类型图块 + 标题 +
//   正文 + 相对时间（刚刚 / N 分钟前）；空态「还没有通知」
// - 开 / 关的唯一真相源是 ToastCenterState.historyOpen：点铃铛、点卡片栈上的「还有 N 条」
//   都只改它，这里监听它去 show / hide 浮层。打开即全部已读（ToastCenter.openHistory）
// - 关：点外面（TapRegion；铃铛与面板同组，点铃铛本身是切换、不算「外面」）、Esc
//   （面板开着时持焦）、再点一次铃铛
//
// 交付进行中（deliveryBusyProvider）不锁铃铛：看历史不改任何东西，与 ⚙ 的「不许开设置」不是一回事。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/clock.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_icon.dart';
import '../../../theme/components/ink_toast_card.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../models/toast_entry.dart';
import '../providers/toast_center.dart';
import 'toast_layer.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  static const Key buttonKey = Key('notifications.bell');
  static const Key dotKey = Key('notifications.bell.dot');
  static const Key panelKey = Key('notifications.panel');
  static const Key clearKey = Key('notifications.panel.clear');

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final OverlayPortalController _portal =
      OverlayPortalController(debugLabel: 'notificationHistory');
  final LayerLink _link = LayerLink();
  final FocusNode _panelFocus = FocusNode(debugLabel: 'notificationHistory');

  /// 铃铛与面板同属一个 TapRegion 组：点铃铛是切换，不是「点外面」——否则
  /// 面板先被「外面」关掉，铃铛的点击又把它打开。
  final Object _tapGroup = Object();

  @override
  void initState() {
    super.initState();
    ref.listenManual<bool>(
      toastCenterProvider.select((ToastCenterState s) => s.historyOpen),
      (bool? previous, bool open) => _sync(open),
      fireImmediately: true,
    );
  }

  /// historyOpen → 浮层。未挂上时 show() 只是记一笔，OverlayPortal 挂上那一刻生效。
  void _sync(bool open) {
    if (open == _portal.isShowing) return;
    if (open) {
      _portal.show();
      // 面板挂上之后再要焦点：Esc 要能直接关它。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _portal.isShowing) _panelFocus.requestFocus();
      });
    } else {
      _portal.hide();
    }
  }

  @override
  void dispose() {
    _panelFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    final ToastCenter center = ref.read(toastCenterProvider.notifier);
    if (ref.read(toastCenterProvider).historyOpen) {
      center.closeHistory();
    } else {
      center.openHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final bool open = ref.watch(
      toastCenterProvider.select((ToastCenterState s) => s.historyOpen),
    );
    final bool unread = ref.watch(
      toastCenterProvider.select((ToastCenterState s) => s.unreadCount > 0),
    );
    final bool unreadError = ref.watch(
      toastCenterProvider.select((ToastCenterState s) => s.hasUnreadError),
    );
    final Color? dot = !unread ? null : (unreadError ? c.danger : c.accent);
    return TapRegion(
      groupId: _tapGroup,
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (BuildContext context) => _HistoryOverlay(
            link: _link,
            groupId: _tapGroup,
            focusNode: _panelFocus,
          ),
          child: InkActivatable(
            key: NotificationBell.buttonKey,
            onTap: _toggle,
            semanticLabel: context.l10n.notificationsOpen,
            focusRingRadius: BorderRadius.circular(InkRadius.s3),
            builder: (BuildContext context, bool hovered, bool focused) {
              final bool lit = hovered || open;
              return Container(
                // 3 + 16 + 3 = 22，与 ⚙ 同大。
                padding: const EdgeInsets.all(InkSpacing.s3),
                decoration: BoxDecoration(
                  color: lit ? c.surface5 : Colors.transparent,
                  borderRadius: BorderRadius.circular(InkRadius.s3),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    InkIcon(
                      InkGlyph.bell,
                      size: InkIconSize.sm,
                      color: lit ? c.fg1 : c.fg3,
                    ),
                    if (dot != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          key: NotificationBell.dotKey,
                          width: InkSpacing.s6,
                          height: InkSpacing.s6,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 浮层根：铺满 Overlay 的 Align（本身不吃点击）+ 跟着铃铛走的面板。
class _HistoryOverlay extends ConsumerWidget {
  const _HistoryOverlay({
    required this.link,
    required this.groupId,
    required this.focusNode,
  });

  final LayerLink link;
  final Object groupId;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ToastCenter center = ref.read(toastCenterProvider.notifier);
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: link,
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: const Offset(0, InkSpacing.xs),
        child: TapRegion(
          groupId: groupId,
          onTapOutside: (_) => center.closeHistory(),
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape):
                  center.closeHistory,
            },
            child: Focus(
              focusNode: focusNode,
              child: const _HistoryPanel(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPanel extends ConsumerWidget {
  const _HistoryPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final List<ToastEntry> history = ref.watch(
      toastCenterProvider.select((ToastCenterState s) => s.history),
    );
    final ToastCenter center = ref.read(toastCenterProvider.notifier);
    final DateTime now = ref.read(clockProvider).nowUtc();
    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: NotificationBell.panelKey,
        width: InkToastSize.historyWidth,
        constraints:
            const BoxConstraints(maxHeight: InkToastSize.historyMaxHeight),
        decoration: BoxDecoration(
          color: c.surface4,
          border: Border.all(color: c.overlayBorder),
          borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
          boxShadow: InkShadow.overlay,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(
                InkSpacing.s12,
                InkSpacing.sm,
                InkSpacing.sm,
                InkSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.borderSubtle)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l.notificationsTitle,
                      style: t.bodyStrong.copyWith(color: c.fg1),
                    ),
                  ),
                  if (history.isNotEmpty)
                    _ClearButton(
                      label: l.notificationsClear,
                      onTap: center.clearHistory,
                    ),
                ],
              ),
            ),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(InkSpacing.lg),
                child: Text(
                  l.notificationsEmpty,
                  textAlign: TextAlign.center,
                  style: t.meta.copyWith(color: c.fg5),
                ),
              )
            else ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  InkSpacing.s12,
                  InkSpacing.sm,
                  InkSpacing.s12,
                  InkSpacing.xs,
                ),
                child: Text(
                  l.notificationsSession,
                  style: t.micro.copyWith(color: c.fg5),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  // 浮层与它下面的路由共享祖先：别去认领路由的 PrimaryScrollController。
                  primary: false,
                  padding: const EdgeInsets.only(bottom: InkSpacing.xs),
                  children: <Widget>[
                    for (final ToastEntry e in history)
                      _HistoryRow(entry: e, now: now),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.now});

  final ToastEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final String? path = entry.thumbnailPath;
    final String? body = entry.body;
    final int minutes = now.difference(entry.createdAt).inMinutes;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s12,
        vertical: InkSpacing.s6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkToastLeading(
            tone: toastToneOf(entry.kind),
            image: path == null
                ? null
                : toastThumbnailImage(context, path, InkSpacing.xl),
            size: InkSpacing.xl,
            glyphSize: InkIconSize.sm,
          ),
          const SizedBox(width: InkSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  entry.title,
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
                const SizedBox(height: InkSpacing.s2),
                Text(
                  minutes < 1
                      ? l.notificationsJustNow
                      : l.notificationsMinutesAgo(minutes),
                  style: t.micro.copyWith(color: c.fg5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 头部「清空」：文字按钮，悬停 surface5。
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return InkActivatable(
      key: NotificationBell.clearKey,
      onTap: onTap,
      semanticLabel: label,
      focusRingRadius: BorderRadius.circular(InkRadius.s3),
      builder: (BuildContext context, bool hovered, bool focused) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s6,
          vertical: InkSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: hovered ? c.surface5 : Colors.transparent,
          borderRadius: BorderRadius.circular(InkRadius.s3),
        ),
        child: Text(
          label,
          style: context.inkTypography.meta
              .copyWith(color: hovered ? c.fg1 : c.fg3),
        ),
      ),
    );
  }
}
