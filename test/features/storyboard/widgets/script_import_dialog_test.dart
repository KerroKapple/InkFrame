// SB-2 脚本导入对话框：粘贴 → 实时预览 → 一键建链。
//
// 预览是这张卡的定心丸——拆分规则再讲究，用户也得先看见「拆成了几镜、每镜叫什么」
// 才敢按下创建。所以预览必须随文本与策略实时变，不能等到点了创建才知道结果。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/storyboard/widgets/script_import_dialog.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';
import '../../../_harness/test_app.dart';

/// run 永远抛错的 UoW：模拟事务失败（真回滚由真 PG 集成测覆盖）。
class _ThrowingUnitOfWork implements UnitOfWork {
  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) async =>
      throw const LocalIOError();
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

  Future<void> pump(WidgetTester tester, {UnitOfWork? uow}) async {
    final UnitOfWork unitOfWork = uow ??
        FakeUnitOfWork(
          FakeRepositoryScope(nodes: nodeRepo, edges: edgeRepo),
        );
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
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> paste(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

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
    final ButtonStyleButton confirm =
        tester.widget(find.widgetWithText(FilledButton, 'Create shots'));
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
  });

  testWidgets('点创建 → 建出 shot 链、对话框关闭、成功提示', (tester) async {
    await pump(tester);
    await paste(tester, threeShots);

    await tester.tap(find.text('Create shots'));
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
    expect(find.text('3 shots added to the canvas'), findsOneWidget);
  });

  testWidgets('单镜文本 → 建 1 个节点 0 条边', (tester) async {
    await pump(tester);
    await paste(tester, '就一镜');

    await tester.tap(find.text('Create shots'));
    await tester.pumpAndSettle();

    expect(nodeRepo.rows, hasLength(1));
    expect(edgeRepo.rows, isEmpty);
    expect(find.text('1 shot added to the canvas'), findsOneWidget);
  });

  testWidgets('事务失败 → 提示失败、画布无残留、对话框留着可重试', (tester) async {
    await pump(tester, uow: _ThrowingUnitOfWork());
    await paste(tester, threeShots);

    await tester.tap(find.text('Create shots'));
    await tester.pumpAndSettle();

    expect(nodeRepo.rows, isEmpty);
    expect(edgeRepo.rows, isEmpty);
    expect(
      find.text("Couldn't import the script. Nothing was added to the canvas."),
      findsOneWidget,
    );
    expect(find.text('Import script'), findsOneWidget, reason: '失败不该关掉对话框');
  });
}
