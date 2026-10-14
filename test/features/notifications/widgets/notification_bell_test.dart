// NotificationBell：未读点（accent / 有未读失败时 danger）、历史下拉（列表 / 清空 / 空态）、
// 打开即已读、点外面与 Esc 关闭、ToastCenter.historyOpen 翻成 true 时自己弹开。
//
// 只 pump 固定帧：ToastCenter 的倒计时 Timer 在跑，pumpAndSettle 不是这里要的语义。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/clock.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/features/notifications/providers/toast_center.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/notifications/widgets/notification_bell.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/tokens.dart';

class _Clock implements Clock {
  _Clock(this.value);
  DateTime value;
  @override
  DateTime nowUtc() => value;
}

Future<ProviderContainer> _pumpBell(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.all(40),
              child: NotificationBell(),
            ),
          ),
        ),
      ),
    ),
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(NotificationBell)),
    listen: false,
  );
}

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(NotificationBell)).l10n;

Color _dotColor(WidgetTester tester) {
  final Container dot =
      tester.widget<Container>(find.byKey(NotificationBell.dotKey));
  return (dot.decoration! as BoxDecoration).color!;
}

Future<void> _tapBell(WidgetTester tester) async {
  await tester.tap(find.byKey(NotificationBell.buttonKey));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('有未读才有点；未读里有失败时点是 danger，否则 accent', (tester) async {
    final ProviderContainer c = await _pumpBell(tester);
    expect(find.byKey(NotificationBell.dotKey), findsNothing);

    c.read(toastServiceProvider).show('done', kind: ToastKind.success);
    await tester.pump();
    expect(find.byKey(NotificationBell.dotKey), findsOneWidget);
    expect(_dotColor(tester), InkColors.dark().accent);

    c.read(toastServiceProvider).show('boom', kind: ToastKind.error);
    await tester.pump();
    expect(_dotColor(tester), InkColors.dark().danger);
  });

  testWidgets('打开下拉：列出本次会话的历史（新的在上），并把未读清掉', (tester) async {
    final ProviderContainer c = await _pumpBell(tester);
    c.read(toastServiceProvider)
      ..show('first', kind: ToastKind.error)
      ..show('second', kind: ToastKind.success, body: 'Saved to the canvas');
    await tester.pump();
    expect(c.read(toastCenterProvider).unreadCount, 2);

    await _tapBell(tester);
    expect(find.byKey(NotificationBell.panelKey), findsOneWidget);
    expect(find.text(_l10n(tester).notificationsSession), findsOneWidget);
    expect(find.text('Saved to the canvas'), findsOneWidget);
    expect(
      tester.getRect(find.text('second')).top,
      lessThan(tester.getRect(find.text('first')).top),
      reason: '新 → 旧',
    );
    expect(find.text(_l10n(tester).notificationsJustNow), findsNWidgets(2));
    expect(c.read(toastCenterProvider).unreadCount, 0, reason: '打开即已读');
    expect(find.byKey(NotificationBell.dotKey), findsNothing);
  });

  testWidgets('面板开着时到达的通知不点亮铃铛', (tester) async {
    final ProviderContainer c = await _pumpBell(tester);
    await _tapBell(tester);
    c.read(toastServiceProvider).show('while open', kind: ToastKind.error);
    await tester.pump();
    expect(find.text('while open'), findsOneWidget);
    expect(find.byKey(NotificationBell.dotKey), findsNothing);
  });

  testWidgets('清空 → 空态', (tester) async {
    final ProviderContainer c = await _pumpBell(tester);
    c.read(toastServiceProvider).show('first', kind: ToastKind.error);
    await tester.pump();
    await _tapBell(tester);

    await tester.tap(find.byKey(NotificationBell.clearKey));
    await tester.pump();
    expect(c.read(toastCenterProvider).history, isEmpty);
    expect(find.text(_l10n(tester).notificationsEmpty), findsOneWidget);
    expect(find.byKey(NotificationBell.clearKey), findsNothing);
  });

  testWidgets('再点铃铛 / 点外面 / Esc 都关', (tester) async {
    final ProviderContainer c = await _pumpBell(tester);

    await _tapBell(tester);
    expect(find.byKey(NotificationBell.panelKey), findsOneWidget);
    await _tapBell(tester);
    expect(find.byKey(NotificationBell.panelKey), findsNothing, reason: '点铃铛是切换');
    expect(c.read(toastCenterProvider).historyOpen, isFalse);

    await _tapBell(tester);
    await tester.tapAt(const Offset(20, 760));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(NotificationBell.panelKey), findsNothing, reason: '点外面关');

    await _tapBell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(NotificationBell.panelKey), findsNothing, reason: 'Esc 关');
    expect(c.read(toastCenterProvider).historyOpen, isFalse);
  });

  testWidgets('historyOpen 被别处翻成 true（「还有 N 条」）时自己弹开', (tester) async {
    final ProviderContainer c = await _pumpBell(tester);
    c.read(toastCenterProvider.notifier).openHistory();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(NotificationBell.panelKey), findsOneWidget);
    expect(find.text(_l10n(tester).notificationsEmpty), findsOneWidget);
  });

  testWidgets('面板宽 = historyWidth，锚在铃铛下方', (tester) async {
    await _pumpBell(tester);
    await _tapBell(tester);
    final Rect panel = tester.getRect(find.byKey(NotificationBell.panelKey));
    final Rect bell = tester.getRect(find.byKey(NotificationBell.buttonKey));
    expect(panel.width, InkToastSize.historyWidth);
    expect(panel.top, greaterThanOrEqualTo(bell.bottom));
    expect(panel.right, moreOrLessEquals(bell.right));
  });

  testWidgets('上面压着对话框时承接不了历史面板：开着的历史关上；对话框关掉后恢复承接', (tester) async {
    final ProviderContainer c = await _pumpBell(tester);
    await tester.pump();
    expect(c.read(toastCenterProvider).historyHostReady, isTrue, reason: '铃铛挂着、路由在最上层');
    c.read(toastCenterProvider.notifier).openHistory();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(NotificationBell.panelKey), findsOneWidget);

    final BuildContext ctx = tester.element(find.byType(NotificationBell));
    unawaited(showDialog<void>(
      context: ctx,
      builder: (_) => const AlertDialog(content: Text('dialog')),
    ));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.read(toastCenterProvider).historyHostReady, isFalse);
    expect(c.read(toastCenterProvider).historyOpen, isFalse,
        reason: '面板挂在铃铛那层路由后面：留着就画在对话框遮罩底下');
    expect(find.byKey(NotificationBell.panelKey), findsNothing);

    Navigator.of(ctx).pop();
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.read(toastCenterProvider).historyHostReady, isTrue);
  });

  testWidgets('读屏：铃铛的语义标签带上未读 / 未读失败（点只靠颜色，读屏拿不到）', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final ProviderContainer c = await _pumpBell(tester);
    final AppLocalizations l = _l10n(tester);
    expect(find.bySemanticsLabel(l.notificationsOpen), findsOneWidget);

    c.read(toastServiceProvider).show('done', kind: ToastKind.success);
    await tester.pump();
    expect(find.bySemanticsLabel(l.notificationsOpenUnread), findsOneWidget);

    c.read(toastServiceProvider).show('boom', kind: ToastKind.error);
    await tester.pump();
    expect(find.bySemanticsLabel(l.notificationsOpenUnreadFailure), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('面板开着时相对时间会走：过了两分钟，「刚刚」变成「2 分钟前」', (tester) async {
    final _Clock clock = _Clock(DateTime.utc(2026, 10, 15, 12));
    final ProviderContainer c = await _pumpBell(
      tester,
      overrides: <Override>[clockProvider.overrideWithValue(clock)],
    );
    final AppLocalizations l = _l10n(tester);
    c.read(toastServiceProvider).show('boom', kind: ToastKind.error);
    await tester.pump();
    await _tapBell(tester);
    expect(find.text(l.notificationsJustNow), findsOneWidget);

    clock.value = clock.value.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 30));
    expect(find.text(l.notificationsMinutesAgo(2)), findsOneWidget,
        reason: '没有新通知也要刷新，否则时间停在打开那一刻');
  });

}
