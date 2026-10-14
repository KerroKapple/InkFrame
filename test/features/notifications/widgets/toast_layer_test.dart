// ToastLayer：MaterialApp.builder 上的通知卡层——位置、最多 3 张 +「还有 N 条」、
// 最新的贴着角、画在对话框之上、悬停 / 窗口失焦停表、按钮与 × 的接线。
//
// ProviderScope 放在被 pump 的树里（不是 UncontrolledProviderScope + addTearDown）：
// 测试结束卸树时容器跟着释放、ToastCenter 的 Timer 跟着取消，绑定的「还有 Timer 没收」
// 检查在 addTearDown 之前跑。全文件只 pump 固定时长，不 pumpAndSettle。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/notifications/providers/toast_center.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/notifications/widgets/toast_layer.dart';
import 'package:inkframe/features/shell/widgets/shell_status_bar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_toast_card.dart';
import 'package:inkframe/theme/tokens.dart';

/// 进场 200ms 画完。
const Duration _settle = Duration(milliseconds: 250);

Future<ProviderContainer> _pumpLayer(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  Widget home = const Scaffold(body: SizedBox.expand()),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // 窄窗口判据读的是 MediaQuery（窗口尺寸），setSurfaceSize 只改布局面——两边要一起设。
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) =>
            ToastLayer(child: child!),
        home: home,
      ),
    ),
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(ToastLayer)),
    listen: false,
  );
}

ToastService _toasts(ProviderContainer c) => c.read(toastServiceProvider);

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(ToastLayer)).l10n;

void main() {
  testWidgets('右下角：右边距 16，底边在状态栏 + 16 之上，卡宽 360', (tester) async {
    final ProviderContainer c = await _pumpLayer(tester);
    _toasts(c).show('hello');
    await tester.pump();
    await tester.pump(_settle);

    final Rect card = tester.getRect(find.byType(InkToastCard));
    expect(card.right, 1280 - InkSpacing.md);
    expect(card.bottom, 800 - ShellStatusBar.height - InkSpacing.md);
    expect(card.width, InkToastSize.width);
  });

  testWidgets('窄窗口：左右各留 16 撑满', (tester) async {
    final ProviderContainer c =
        await _pumpLayer(tester, size: const Size(420, 700));
    _toasts(c).show('hello');
    await tester.pump();
    await tester.pump(_settle);

    final Rect card = tester.getRect(find.byType(InkToastCard));
    expect(card.left, InkSpacing.md);
    expect(card.right, 420 - InkSpacing.md);
  });

  testWidgets('最多 3 张在场；更旧的收成「还有 N 条」；最新的贴着角、旧的往上叠',
      (tester) async {
    final ProviderContainer c = await _pumpLayer(tester);
    for (int i = 0; i < 5; i++) {
      _toasts(c).show('e$i', kind: ToastKind.error);
    }
    await tester.pump();
    await tester.pump(_settle);

    expect(find.byType(InkToastCard), findsNWidgets(3));
    expect(find.text('e0'), findsNothing);
    expect(find.text('e1'), findsNothing);
    expect(
      tester.getRect(find.text('e4')).top,
      greaterThan(tester.getRect(find.text('e3')).top),
      reason: '最新的在最下面（贴着角）',
    );
    expect(
      tester.getRect(find.text('e3')).top,
      greaterThan(tester.getRect(find.text('e2')).top),
    );

    final Finder more = find.text(_l10n(tester).toastMore(2));
    expect(more, findsOneWidget);
    expect(
      tester.getRect(more).bottom,
      lessThan(tester.getRect(find.text('e2')).top),
      reason: '「还有 N 条」在卡片栈上方',
    );

    await tester.tap(find.byKey(ToastLayer.moreKey));
    await tester.pump();
    expect(c.read(toastCenterProvider).historyOpen, isTrue,
        reason: '点它打开铃铛历史');
  });

  testWidgets('对话框开着时卡片仍在遮罩之上：可命中，点按钮不会落到遮罩上',
      (tester) async {
    final ProviderContainer c = await _pumpLayer(
      tester,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (BuildContext _) =>
                    const AlertDialog(content: Text('modal')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('modal'), findsOneWidget);

    int retried = 0;
    _toasts(c).show(
      'Generation failed',
      kind: ToastKind.error,
      primary: ToastAction('Retry', () => retried++),
    );
    await tester.pump();
    await tester.pump(_settle);

    expect(
      find.byType(InkToastCard).hitTestable(),
      findsOneWidget,
      reason: '卡片在 Navigator 之上，对话框遮罩挡不住它',
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, 1);
    expect(find.text('modal'), findsOneWidget, reason: '点击没有漏到遮罩上把对话框关掉');
  });

  testWidgets('鼠标停在卡片栈上停表，移开后接着走', (tester) async {
    final ProviderContainer c = await _pumpLayer(tester);
    _toasts(c).show('hello');
    await tester.pump();
    await tester.pump(_settle);

    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('hello')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 8));
    expect(find.text('hello'), findsOneWidget, reason: '悬停期间不该走表');

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('hello'), findsNothing);
  });

  testWidgets('窗口不在前台时停表，回到前台接着走', (tester) async {
    final ProviderContainer c = await _pumpLayer(tester);
    _toasts(c).show('hello');
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('hello'), findsOneWidget, reason: '失焦期间不该走表');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('hello'), findsNothing);
  });

  testWidgets('× 关卡：淡出后移除', (tester) async {
    final ProviderContainer c = await _pumpLayer(tester);
    _toasts(c).show('boom', kind: ToastKind.error);
    await tester.pump();
    await tester.pump(_settle);

    await tester.tap(find.byKey(InkToastCard.closeKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('boom'), findsNothing);
    expect(c.read(toastCenterProvider).live, isEmpty);
  });

  testWidgets('按下卡上的按钮：先执行动作，再收卡', (tester) async {
    final ProviderContainer c = await _pumpLayer(tester);
    int viewed = 0;
    _toasts(c).show(
      'Shot 3 is ready',
      kind: ToastKind.success,
      primary: ToastAction('View', () => viewed++),
    );
    await tester.pump();
    await tester.pump(_settle);

    await tester.tap(find.text('View'));
    await tester.pump();
    expect(viewed, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Shot 3 is ready'), findsNothing);
  });

  testWidgets('进行中原地变成完成：同一张卡，不重放进场', (tester) async {
    final ProviderContainer c = await _pumpLayer(tester);
    final ToastHandle h =
        _toasts(c).show('Exporting', kind: ToastKind.progress);
    await tester.pump();
    await tester.pump(_settle);

    h.complete(kind: ToastKind.success, title: 'Exported');
    await tester.pump();
    expect(find.text('Exported'), findsOneWidget);
    final Opacity fade = tester.widget<Opacity>(
      find
          .ancestor(of: find.byType(InkToastCard), matching: find.byType(Opacity))
          .first,
    );
    expect(fade.opacity, 1.0, reason: '原地换内容，不该从透明重新淡入');
  });
}
