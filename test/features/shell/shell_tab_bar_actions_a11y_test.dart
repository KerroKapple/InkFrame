// 标签栏右侧动作的可达性（BOARD 210 收口）。
//
// #249 只把标签 chip 改成了可键盘到达，紧挨着它的那排动作（导入项目包 / 新建项目 /
// 导入脚本 / 序列预览 / 导出视频 / 导出 mp4 / 交付 / 存为角色 / 回画布定位）还是裸
// GestureDetector——同一条标签栏上两套可达性语义。抽出 theme 层的 InkActivatable 后
// 三处一起换，这里钉死接线侧的三件事：动作能 Tab 到、回车走的是同一条动作回调、
// 不可点的动作不可聚焦。
//
// 顺带守住一条跨文件的隐含前提：焦点遍历序里 chip 在动作【之前】。
// shell_tab_bar_test.dart 那条「第 4 次 Tab 落在画廊格」依赖它；动作一旦抢到前面，
// 那条会红在一个看不出因果的地方，所以在这里显式写出来。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/project_archive.dart';
import 'package:inkframe/core/interfaces/project_import_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/export/providers/delivery_controller.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/widgets/shell_tab_bar.dart';

import '../../_harness/shell_app.dart';
import '../../_harness/test_app.dart';
import '../../helpers/recording_logger.dart';

/// 导入服务只为"别去真的起 postgres"而存在：picker 返回 null 时流程早退，
/// 这个 fake 的方法根本不会被调到。
class _NeverImportService implements ProjectImportService {
  @override
  Future<ImportResult> importArchive({required String zipPath}) async =>
      const ImportResult(outcome: ImportOutcome.failed);
}

/// 两镜一链：让序列标签上的「回画布定位」真的可用（canLocate = true），
/// 否则交付锁那条测的是"本来就禁用"，等于什么都没测。
class _Nodes extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        for (final String id in <String>['a', 'b'])
          CanvasNode(
            id: id,
            label: 'shot-$id',
            type: CanvasNodeType.shot,
            canvasId: canvasId,
            // 无产物也无 notes 的节点被 buildSequence 跳过 ⇒ 链会是空的。
            typeConfig: <String, Object?>{'shot_notes': 'notes $id'},
          ),
      ];
}

class _Edges extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => <CanvasEdge>[
        CanvasEdge(
          id: 'e',
          canvasId: canvasId,
          sourceNodeId: 'a',
          targetNodeId: 'b',
          edgeType: EdgeType.narrative,
        ),
      ];
}

/// 恒「在途」的交付控制器：锁态从第一帧就成立，不用驱动真服务、不用猜 pump 次数。
class _RunningDelivery extends DeliveryController {
  @override
  DeliveryState build() => const DeliveryRunning(done: 0, total: 1);
}

FocusNode _focusOf(WidgetTester tester, Key key) => tester
    .widget<FocusableActionDetector>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;

Future<void> _tabKey(WidgetTester tester, int times) async {
  for (int i = 0; i < times; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
}

void main() {
  late int pickerCalls;

  setUp(() => pickerCalls = 0);

  Future<void> pumpBar(WidgetTester tester, {bool importBusy = false}) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: Column(children: <Widget>[ShellTabBar()])),
      surfaceSize: const Size(1440, 400),
      overrides: <Override>[
        loggerProvider.overrideWithValue(RecordingLogger()),
        projectImportServiceProvider
            .overrideWith((_) async => _NeverImportService()),
        openFilePickerProvider.overrideWithValue(() async {
          pickerCalls += 1;
          return null; // 取消 ⇒ 流程早退，不碰磁盘
        }),
        if (importBusy) projectImportBusyProvider.overrideWith((_) => true),
      ],
    );
    await tester.pump();
  }

  testWidgets('焦点遍历序：五个 chip 之后才轮到右侧动作', (tester) async {
    await pumpBar(tester);

    // Studio 标签（初始态）右侧两个动作：导入项目包（次级）+ 新建项目（主）。
    await _tabKey(tester, 5);
    expect(
      _focusOf(tester, ShellTabBar.keyOf(ShellTab.export)).hasPrimaryFocus,
      isTrue,
      reason: '第 5 次 Tab 该还在 chip 上（五格）',
    );

    await _tabKey(tester, 1);
    expect(
      _focusOf(tester, ShellTabBar.importPackageKey).hasPrimaryFocus,
      isTrue,
      reason: '右侧动作不可聚焦 ⇒ 键盘用户到不了「导入项目包」',
    );

    await _tabKey(tester, 1);
    expect(
      _focusOf(tester, ShellTabBar.newProjectKey).hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('聚焦「导入项目包」后按 Enter → 走的是同一条导入流（picker 被调）',
      (tester) async {
    await pumpBar(tester);

    await _tabKey(tester, 6);
    expect(_focusOf(tester, ShellTabBar.importPackageKey).hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      pickerCalls,
      1,
      reason: '回车必须和鼠标点击走同一条 runProjectImportFlow',
    );
  });

  testWidgets('导入在途（onTap == null）⇒「导入项目包」不可聚焦，Tab 直接跳到「新建项目」',
      (tester) async {
    await pumpBar(tester, importBusy: true);

    await _tabKey(tester, 6);
    expect(
      _focusOf(tester, ShellTabBar.importPackageKey).hasPrimaryFocus,
      isFalse,
      reason: '在途时这格不可点，就不该能被聚焦——否则回车一次什么都不发生',
    );
    expect(_focusOf(tester, ShellTabBar.newProjectKey).hasPrimaryFocus, isTrue);
    expect(pickerCalls, 0);
  });

  // 交付锁（P6 §3）此前只靠 IgnorePointer——它吞指针，但【不挡 Tab / 回车】。
  // 右侧动作接上键盘可达之后，这就是一条真的绕行路：键盘用户能在交付途中按回车
  // 把标签切走。所以「锁住一块」必须连焦点一起排除。
  group('交付锁也锁键盘', () {
    const ShellState onSequence = ShellState(
      tab: ShellTab.sequence,
      canvasId: 'cv-1',
      project: ProjectRef(id: 'p1', name: 'Alpha'),
    );

    Future<void> pumpShell(WidgetTester tester, {required bool busy}) async {
      final AppPaths paths = await setupTempPaths(tester, 'ink_tabbar_a11y_');
      await pumpInkShell(
        tester,
        paths: paths,
        initial: onSequence,
        extraOverrides: <Override>[
          canvasNodesControllerProvider.overrideWith(_Nodes.new),
          canvasEdgesControllerProvider.overrideWith(_Edges.new),
          if (busy)
            deliveryControllerProvider.overrideWith(_RunningDelivery.new),
        ],
      );
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    testWidgets('不在交付：「回画布定位」可聚焦', (tester) async {
      await pumpShell(tester, busy: false);
      expect(
        _focusOf(tester, ShellTabBar.locateInCanvasKey).canRequestFocus,
        isTrue,
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('交付中：「回画布定位」连焦点都到不了', (tester) async {
      await pumpShell(tester, busy: true);
      expect(
        _focusOf(tester, ShellTabBar.locateInCanvasKey).canRequestFocus,
        isFalse,
        reason: 'IgnorePointer 只吞指针——锁住的块必须把焦点一起排除，'
            '否则键盘用户能绕过交付锁',
      );
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
