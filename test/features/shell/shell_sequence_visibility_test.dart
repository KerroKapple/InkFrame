// 外壳 → 序列标签的可见性接线（P2 拍板：Player 切走即停、回来不续播）。
//
// 监视器"paused=true 即停、回来不续播"的行为在 sequence_monitor_test.dart 单测；本文件钉的是
// 【接线】：ShellState.isTabVisible(sequence) 必须逐帧落到 SequenceScreen.isVisible 上——
// 两种不可见（① 切走标签 ② 浮层盖住）都走同一个谓词。把 shell_content_stack 里的
// `SequenceTab(isVisible: _isVisible(ShellTab.sequence))` 改回常量 true，本文件三条全红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/sequence/widgets/sequence_monitor.dart';
import 'package:inkframe/features/sequence/widgets/sequence_screen.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/shell_tab_bar.dart';

import '../../_harness/shell_app.dart';

class _Nodes extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        for (final String id in <String>['a', 'b'])
          CanvasNode(
            id: id,
            label: 'shot-$id',
            type: CanvasNodeType.shot,
            canvasId: canvasId,
            typeConfig: <String, Object?>{'shot_notes': 'notes $id'},
          ),
      ];
}

class _Edges extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => <CanvasEdge>[
        CanvasEdge(id: 'e', canvasId: canvasId, sourceNodeId: 'a', targetNodeId: 'b', edgeType: EdgeType.narrative),
      ];
}

const ShellState _onSequence = ShellState(
  tab: ShellTab.sequence,
  canvasId: 'cv-1',
  project: ProjectRef(id: 'p1', name: 'Alpha'),
);

Future<void> _pump(WidgetTester tester, String prefix) async {
  final paths = await setupTempPaths(tester, prefix);
  await pumpInkShell(
    tester,
    paths: paths,
    initial: _onSequence,
    extraOverrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_Nodes.new),
      canvasEdgesControllerProvider.overrideWith(_Edges.new),
    ],
  );
  for (int i = 0; i < 4; i++) {
    await tester.pump();
  }
}

bool _screenVisible(WidgetTester tester) =>
    tester.widget<SequenceScreen>(find.byType(SequenceScreen, skipOffstage: false)).isVisible;

bool _monitorPaused(WidgetTester tester) =>
    tester.widget<SequenceMonitor>(find.byType(SequenceMonitor, skipOffstage: false)).paused;

void main() {
  testWidgets('序列标签在台 → isVisible=true，监视器未 paused；状态栏出序列行', (tester) async {
    await _pump(tester, 'ink_seq_vis_on_');
    expect(_screenVisible(tester), isTrue);
    expect(_monitorPaused(tester), isFalse);
    expect(find.text('Alpha · Narrative chain · 2 shots'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 15)));

  testWidgets('切走标签 → 保活的序列 isVisible=false，监视器 paused', (tester) async {
    await _pump(tester, 'ink_seq_vis_tab_');
    await tapShellTab(tester, ShellTab.canvas);
    await tester.pump();

    expect(_screenVisible(tester), isFalse);
    expect(_monitorPaused(tester), isTrue);
  }, timeout: const Timeout(Duration(seconds: 15)));

  testWidgets('浮层盖住 → 同样 isVisible=false；关掉浮层回到 true', (tester) async {
    await _pump(tester, 'ink_seq_vis_overlay_');
    final ProviderContainer c = readShellContainer(tester);

    c.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.settings);
    await tester.pump();
    await tester.pump();
    expect(_screenVisible(tester), isFalse);
    expect(_monitorPaused(tester), isTrue);

    c.read(shellControllerProvider.notifier).closeOverlay();
    await tester.pump();
    await tester.pump();
    expect(_screenVisible(tester), isTrue);
    expect(_monitorPaused(tester), isFalse);
  }, timeout: const Timeout(Duration(seconds: 15)));

  testWidgets('标签条：回到画布定位 = 选中当前镜节点 + 切到画布；无 video result 时导出 mp4 半透明', (tester) async {
    await _pump(tester, 'ink_seq_vis_actions_');
    final ProviderContainer c = readShellContainer(tester);
    // 生产路径：序列总是从画布进来的——画布标签已物化、持着选中态控制器的订阅。
    await tapShellTab(tester, ShellTab.canvas);
    await tapShellTab(tester, ShellTab.sequence);

    // 先把播放头挪到第二镜，再点「回到画布定位」。
    await tester.tap(find.byKey(SequenceScreen.chainRowKey(1)));
    await tester.pump();
    await tester.pump();

    final Opacity exportOpacity = tester.widget<Opacity>(
      find.descendant(of: find.byKey(ShellTabBar.exportMp4Key), matching: find.byType(Opacity)),
    );
    expect(exportOpacity.opacity, 0.5, reason: '没有可导出的 video result');

    await tester.tap(find.byKey(ShellTabBar.locateInCanvasKey));
    await tester.pump();
    await tester.pump();

    expect(c.read(shellControllerProvider).tab, ShellTab.canvas);
    expect(c.read(canvasSelectionControllerProvider('cv-1')), <String>{'b'});
  }, timeout: const Timeout(Duration(seconds: 15)));
}
