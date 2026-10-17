// SB-2 剧本导入对话框：粘贴 → 实时预览 → 一键建链。
//
// 预览是这张卡的定心丸——拆分规则再讲究，用户也得先看见「拆成了几镜、每镜叫什么」
// 才敢按下创建。所以预览必须随文本与策略实时变，不能等到点了创建才知道结果。
// 创建按钮也写出数量（「创建 3 个镜头」），与预览头的「N 镜」同一个 N。
//
// 成败提示走通知卡（toastServiceProvider）：成功时对话框已关，失败时对话框还开着
// ——通知卡画在所有路由之上，两种时机都看得见。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/storyboard/widgets/script_import_dialog.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/fake_unit_of_work.dart';
import '../../../_harness/test_app.dart';

/// run 永远抛错的 UoW：模拟事务失败（真回滚由真 PG 集成测覆盖）。
class _ThrowingUnitOfWork implements UnitOfWork {
  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) async =>
      throw const LocalIOError();
}

/// run 卡在 [gate] 上、放行后抛错的 UoW：让「事务在途」停得住，测忙碌中的界面。
class _GatedUnitOfWork implements UnitOfWork {
  final Completer<void> gate = Completer<void>();

  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) async {
    await gate.future;
    throw const LocalIOError();
  }
}

void main() {
  const String canvasId = 'cv1';
  const String threeShots = '山径破晓\n晨光初现\n\n渡索桥\n\n茶棚避雨';

  late InMemoryNodeRepository nodeRepo;
  late InMemoryEdgeRepository edgeRepo;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
    edgeRepo = InMemoryEdgeRepository();
  });

  /// 打开对话框，返回记下的通知卡。
  Future<RecordingToastService> pump(
    WidgetTester tester, {
    UnitOfWork? uow,
    Locale locale = const Locale('en'),
  }) async {
    final UnitOfWork unitOfWork = uow ??
        FakeUnitOfWork(
          FakeRepositoryScope(nodes: nodeRepo, edges: edgeRepo),
        );
    final RecordingToastService toast = RecordingToastService();
    await pumpInkApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showScriptImportDialog(context, canvasId: canvasId),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: <Override>[
        unitOfWorkProvider.overrideWith((ref) async => unitOfWork),
        toastServiceProvider.overrideWithValue(toast),
      ],
      locale: locale,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return toast;
  }

  Future<void> paste(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  // B1：框常从画布开（空白处右键「导入剧本…」）。不持焦的话主焦点会被画布要回去，按键穿过框打到画布上。
  testWidgets('一打开粘贴框就持焦（autofocus）：不用先点一下就能粘贴', (tester) async {
    await pump(tester);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('刚打开：预览为空，创建按钮禁用', (tester) async {
    await pump(tester);

    expect(find.text('Import script'), findsOneWidget);
    expect(find.text('Nothing to import yet.'), findsOneWidget);
    final ButtonStyleButton confirm =
        tester.widget(find.widgetWithText(FilledButton, 'Create shots'));
    expect(confirm.onPressed, isNull);
  });

  testWidgets('粘贴文本 → 预览实时显示镜数与各镜标题', (tester) async {
    await pump(tester);
    await paste(tester, threeShots);

    expect(find.text('3 shots'), findsOneWidget);
    // 预览逐镜列出「序号. 标题」——序号让用户一眼看出链的走向。
    expect(find.text('1. 山径破晓'), findsOneWidget);
    expect(find.text('2. 渡索桥'), findsOneWidget);
    expect(find.text('3. 茶棚避雨'), findsOneWidget);
    // 按钮写出数量，与预览头「3 shots」同一个 N。
    final ButtonStyleButton confirm =
        tester.widget(find.widgetWithText(FilledButton, 'Create 3 shots'));
    expect(confirm.onPressed, isNotNull);
  });

  testWidgets('切到「每行一镜」→ 预览随策略重算', (tester) async {
    await pump(tester);
    await paste(tester, threeShots);
    expect(find.text('3 shots'), findsOneWidget);

    await tester.tap(find.text('Every line'));
    await tester.pumpAndSettle();

    // 同一段文本共 4 个非空行。
    expect(find.text('4 shots'), findsOneWidget);
    // 按钮跟着策略一起重算，不停在旧的 3。
    expect(find.widgetWithText(FilledButton, 'Create 4 shots'), findsOneWidget);
    expect(find.text('Create 3 shots'), findsNothing);
  });

  testWidgets('单镜文本 → 按钮写 Create 1 shot（单数）', (tester) async {
    await pump(tester);
    await paste(tester, '就一镜');

    final ButtonStyleButton confirm =
        tester.widget(find.widgetWithText(FilledButton, 'Create 1 shot'));
    expect(confirm.onPressed, isNotNull);
  });

  testWidgets('zh：标题「导入剧本」，按钮「创建 3 个镜头」，清空后回到「创建镜头」并置灰',
      (tester) async {
    await pump(tester, locale: const Locale('zh'));

    expect(find.text('导入剧本'), findsOneWidget);
    await paste(tester, threeShots);
    final ButtonStyleButton confirm =
        tester.widget(find.widgetWithText(FilledButton, '创建 3 个镜头'));
    expect(confirm.onPressed, isNotNull);

    await paste(tester, '');
    final ButtonStyleButton empty =
        tester.widget(find.widgetWithText(FilledButton, '创建镜头'));
    expect(empty.onPressed, isNull);
  });

  testWidgets('点创建 → 建出 shot 链、对话框关闭、成功提示', (tester) async {
    final RecordingToastService toast = await pump(tester);
    await paste(tester, threeShots);

    await tester.tap(find.text('Create 3 shots'));
    await tester.pumpAndSettle();

    expect(nodeRepo.rows, hasLength(3));
    expect(
      nodeRepo.rows.values.map((r) => r['type']),
      everyElement('shot'),
    );
    expect(edgeRepo.rows, hasLength(2));
    expect(
      edgeRepo.rows.values.map((r) => r['edge_type']),
      everyElement('narrative'),
    );
    expect(find.text('Import script'), findsNothing, reason: '对话框应已关闭');
    expect(toast.titles, <String>['3 shots added to the canvas']);
    expect(toast.kinds, <ToastKind>[ToastKind.success]);
    expect(toast.shown.single.chime, isFalse,
        reason: '建链是一次短事务、用户就等在对话框前——即时回应，不是后台事件');
  });

  testWidgets('单镜文本 → 建 1 个节点 0 条边', (tester) async {
    final RecordingToastService toast = await pump(tester);
    await paste(tester, '就一镜');

    await tester.tap(find.text('Create 1 shot'));
    await tester.pumpAndSettle();

    expect(nodeRepo.rows, hasLength(1));
    expect(edgeRepo.rows, isEmpty);
    expect(toast.titles, <String>['1 shot added to the canvas']);
  });

  testWidgets('事务失败 → 提示失败、画布无残留、对话框留着可重试', (tester) async {
    final RecordingToastService toast =
        await pump(tester, uow: _ThrowingUnitOfWork());
    await paste(tester, threeShots);

    await tester.tap(find.text('Create 3 shots'));
    await tester.pumpAndSettle();

    expect(nodeRepo.rows, isEmpty);
    expect(edgeRepo.rows, isEmpty);
    expect(
      toast.titles,
      <String>["Couldn't import the script. Nothing was added to the canvas."],
    );
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(find.text('Import script'), findsOneWidget, reason: '失败不该关掉对话框');
    // #15：「可重试」= 按钮恢复可点、文字仍是 N。
    final ButtonStyleButton retry =
        tester.widget(find.widgetWithText(FilledButton, 'Create 3 shots'));
    expect(retry.onPressed, isNotNull, reason: '失败后按钮必须恢复可点，否则再也重试不了');
  });

  testWidgets('zh：事务失败 → 失败提示「剧本导入失败，画布未做改动。」，按钮恢复可点', (tester) async {
    final RecordingToastService toast =
        await pump(tester, uow: _ThrowingUnitOfWork(), locale: const Locale('zh'));
    await paste(tester, threeShots);

    await tester.tap(find.text('创建 3 个镜头'));
    await tester.pumpAndSettle();

    expect(toast.titles, <String>['剧本导入失败，画布未做改动。']);
    final ButtonStyleButton retry =
        tester.widget(find.widgetWithText(FilledButton, '创建 3 个镜头'));
    expect(retry.onPressed, isNotNull);
  });

  // #14：事务在途时粘贴框仍可编辑（不禁用，免得丢焦点）。按钮与预览头都钉在提交时的 N——
  // 在提交的始终是那一份，不随框里的文字变、清空时也不闪回「Create shots」。
  testWidgets('提交途中清空粘贴框：按钮仍是 Create 3 shots 且置灰、预览头仍是 3 shots；失败后回到当前文本',
      (tester) async {
    final _GatedUnitOfWork gated = _GatedUnitOfWork();
    final RecordingToastService toast = await pump(tester, uow: gated);
    await paste(tester, threeShots);

    await tester.tap(find.text('Create 3 shots'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    final ButtonStyleButton busy =
        tester.widget(find.widgetWithText(FilledButton, 'Create 3 shots'));
    expect(busy.onPressed, isNull, reason: '忙碌中置灰');
    expect(find.text('Create shots'), findsNothing, reason: '不闪回 0');
    expect(find.text('3 shots'), findsOneWidget, reason: '预览头同样钉在提交时的 N');
    expect(toast.titles, isEmpty, reason: '前提：事务还卡在途中');

    gated.gate.complete();
    await tester.pumpAndSettle();

    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    // 复位后回到框里现在的文字：空框 ⇒「Create shots」并置灰。
    final ButtonStyleButton empty =
        tester.widget(find.widgetWithText(FilledButton, 'Create shots'));
    expect(empty.onPressed, isNull);
    expect(find.text('Nothing to import yet.'), findsOneWidget);
  });
}
