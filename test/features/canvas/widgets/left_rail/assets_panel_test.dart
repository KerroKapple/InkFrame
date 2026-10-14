// 左栏素材页（PR-4）：外壳级 pump，数据走真的画廊图（内存仓储里种两张画布的产物）。
//
// 钉：分段与类型 chip 的计数、网格标签（源配置名 · take N / 成片）、点格子定位（当前画布 =
// 单选 + 移到视口中心；别的画布 = 切过去）、「在画廊中打开全部」切到画廊标签。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/left_rail_state.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/assets_model.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/assets_panel.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../../_harness/fake_canvas.dart';
import '../../../../_harness/fake_repositories.dart';
import '../../../../_harness/shell_app.dart';

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');

/// 种好的两张画布：A（当前）= Harbor 名下两个图片 take + Boat 一个视频；B = Peaks 一张图。
class _Seed {
  _Seed(this.canvases, this.nodes, this.cvA, this.cvB, this.take2Id);

  final InMemoryCanvasRepository canvases;
  final InMemoryNodeRepository nodes;
  final String cvA;
  final String cvB;

  /// Harbor 的第二个（较新的）take。
  final String take2Id;
}

Future<_Seed> _seed() async {
  final InMemoryCanvasRepository canvases = InMemoryCanvasRepository();
  final InMemoryNodeRepository nodes = InMemoryNodeRepository();
  final String cvA = await canvases.create(projectId: 'p1', name: 'A');
  final String cvB = await canvases.create(projectId: 'p1', name: 'B');

  final String harbor = await nodes.create(
    canvasId: cvA,
    type: 'text',
    nodeRole: 'config',
    label: 'Harbor',
    typeConfig: <String, Object?>{'text': 'dawn'},
  );
  final String take1 = await nodes.create(
    canvasId: cvA,
    type: 'image',
    nodeRole: 'result',
    label: 'Harbor take',
    sourceNodeId: harbor,
    positionX: 300,
    typeConfig: <String, Object?>{'image_url': 'images/h1.png'},
  );
  await nodes.update(take1, <String, Object?>{'created_at': DateTime.utc(2026, 1, 1)});
  final String take2 = await nodes.create(
    canvasId: cvA,
    type: 'image',
    nodeRole: 'result',
    label: 'Harbor take',
    sourceNodeId: harbor,
    positionX: 2800,
    positionY: 1900,
    typeConfig: <String, Object?>{'image_url': 'images/h2.png'},
  );
  await nodes.update(take2, <String, Object?>{'created_at': DateTime.utc(2026, 1, 2)});

  final String boat = await nodes.create(
    canvasId: cvA,
    type: 'text',
    nodeRole: 'config',
    label: 'Boat',
    positionY: 400,
    typeConfig: <String, Object?>{'text': 'drift'},
  );
  await nodes.create(
    canvasId: cvA,
    type: 'video',
    nodeRole: 'result',
    label: 'Boat take',
    sourceNodeId: boat,
    positionX: 300,
    positionY: 400,
    typeConfig: <String, Object?>{'video_url': 'videos/b.mp4'},
  );

  final String peaks = await nodes.create(
    canvasId: cvB,
    type: 'text',
    nodeRole: 'config',
    label: 'Peaks',
    typeConfig: <String, Object?>{'text': 'far'},
  );
  await nodes.create(
    canvasId: cvB,
    type: 'image',
    nodeRole: 'result',
    label: 'Peaks take',
    sourceNodeId: peaks,
    typeConfig: <String, Object?>{'image_url': 'images/p.png'},
  );
  return _Seed(canvases, nodes, cvA, cvB, take2);
}

Future<ProviderContainer> _pump(WidgetTester tester, _Seed s) async {
  final paths = await setupTempPaths(tester, 'ink_left_assets_');
  await pumpInkShell(
    tester,
    paths: paths,
    initial: ShellState(tab: ShellTab.canvas, canvasId: s.cvA, project: _alpha),
    extraOverrides: <Override>[
      canvasRepositoryProvider.overrideWith((_) async => s.canvases),
      nodeRepositoryProvider.overrideWith((_) async => s.nodes),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ],
  );
  final ProviderContainer c = readShellContainer(tester);
  c.read(leftRailProvider.notifier).open(LeftRailPage.assets);
  // 画布节点载入 + 画廊图聚合 + 视口尺寸帧后上报：多给几帧。
  for (int i = 0; i < 8; i++) {
    await tester.pump();
  }
  return c;
}

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(AssetsPanel)));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  for (int i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('分段与类型 chip：计数随分段变；标签 =「源配置名 · take N」/「源配置名 · final」', (tester) async {
    final _Seed s = await _seed();
    await _pump(tester, s);
    final AppLocalizations l = _l(tester);

    // 本画布（默认）：Harbor ×2 图 + Boat ×1 视频。
    expect(find.text(l.leftRailAssetsKindAll(3)), findsOneWidget);
    expect(find.text(l.leftRailAssetsKindImage(2)), findsOneWidget);
    expect(find.text(l.leftRailAssetsKindVideo(1)), findsOneWidget);
    expect(find.text(l.leftRailAssetTake('Harbor', 1)), findsOneWidget);
    expect(find.text(l.leftRailAssetTake('Harbor', 2)), findsOneWidget);
    expect(find.text(l.leftRailAssetFinal('Boat')), findsOneWidget);
    expect(find.text(l.leftRailAssetFinal('Peaks')), findsNothing, reason: '别的画布的产物不在本画布段');

    // 项目全部：再加上 B 画布的 Peaks。
    await _tap(tester, find.byKey(AssetsPanel.scopeKey(AssetScope.project)));
    expect(find.text(l.leftRailAssetsKindAll(4)), findsOneWidget);
    expect(find.text(l.leftRailAssetsKindImage(3)), findsOneWidget);
    expect(find.text(l.leftRailAssetsKindVideo(1)), findsOneWidget);
    expect(find.text(l.leftRailAssetFinal('Peaks')), findsOneWidget);

    // 类型 chip：只看视频。
    await _tap(tester, find.byKey(AssetsPanel.kindKey(AssetKindFilter.video)));
    expect(find.text(l.leftRailAssetFinal('Boat')), findsOneWidget);
    expect(find.text(l.leftRailAssetTake('Harbor', 1)), findsNothing);
    expect(find.text(l.leftRailAssetFinal('Peaks')), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('点当前画布的格子：单选那个产物节点，并把它移到视口中心', (tester) async {
    final _Seed s = await _seed();
    final ProviderContainer c = await _pump(tester, s);
    final AppLocalizations l = _l(tester);
    final Finder card = find.byKey(ValueKey<String>('node-card-${s.take2Id}'));
    expect(
      (tester.getCenter(card) - tester.getCenter(find.byType(CanvasView))).distance,
      greaterThan(200),
      reason: '前置：这一格的节点一开始远离视口中心',
    );

    await _tap(tester, find.text(l.leftRailAssetTake('Harbor', 2)));

    expect(c.read(canvasSelectionControllerProvider(s.cvA)), <String>{s.take2Id});
    final Offset center = tester.getCenter(card);
    final Offset stage = tester.getCenter(find.byType(CanvasView));
    expect(center.dx, closeTo(stage.dx, 1));
    expect(center.dy, closeTo(stage.dy, 1));
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('点别的画布的格子：切到那张画布（同项目）', (tester) async {
    final _Seed s = await _seed();
    final ProviderContainer c = await _pump(tester, s);
    final AppLocalizations l = _l(tester);
    await _tap(tester, find.byKey(AssetsPanel.scopeKey(AssetScope.project)));

    await _tap(tester, find.text(l.leftRailAssetFinal('Peaks')));

    final ShellState shell = c.read(shellControllerProvider);
    expect(shell.tab, ShellTab.canvas);
    expect(shell.canvasId, s.cvB);
    expect(shell.project, _alpha);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('「在画廊中打开全部」：在外壳里切到当前项目的画廊', (tester) async {
    final _Seed s = await _seed();
    final ProviderContainer c = await _pump(tester, s);

    await _tap(tester, find.byKey(AssetsPanel.openGalleryKey));

    final ShellState shell = c.read(shellControllerProvider);
    expect(shell.tab, ShellTab.gallery);
    expect(shell.project, _alpha);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
