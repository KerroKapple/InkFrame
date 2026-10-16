// 左栏素材页（PR-4）：外壳级 pump，数据走真的画廊图（内存仓储里种两张画布的产物）。
//
// 钉：分段与类型 chip 的计数、网格标签（源配置名 · take N / 成片）、点格子定位（当前画布 =
// 单选 + 移到视口中心；别的画布 = 切过去）、「在画廊中打开全部」切到画廊标签。
// 新鲜度：画廊图被别处保活着时 job 成功，之后再打开本页也能看到新图（开页即重读）；本页开着时 job 成功，
// 新图跟着出来（本页对注册表的监听）。删除：当前画布删掉的节点，格子立刻消失、剩下的 take 号跟着变；点一个
// 在节点表里找不到的格子，不改选中集。
// take 号：普通生成和批量混在一起时，素材页格子与检查器历史页的号一致（批量 slot 不参与编号，照画廊写
// 「#n」）；名下只有一个产物时两处都写成片。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_tab.dart';
import 'package:inkframe/features/canvas/providers/left_rail_state.dart';
import 'package:inkframe/features/canvas/widgets/canvas_inspector_panel.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/inspector_history_panel.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/assets_model.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/assets_panel.dart';
import 'package:inkframe/features/gallery/providers/gallery_graph_provider.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../../_harness/fake_batch_result.dart';
import '../../../../_harness/fake_canvas.dart';
import '../../../../_harness/fake_repositories.dart';
import '../../../../_harness/fake_toast_service.dart';
import '../../../../_harness/shell_app.dart';

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');

/// 种好的两张画布：A（当前）= Harbor 名下两个图片 take + Boat 一个视频；B = Peaks 一张图。
class _Seed {
  _Seed(this.canvases, this.nodes, this.cvA, this.cvB, this.harborId, this.take2Id, this.peaksTakeId);

  final InMemoryCanvasRepository canvases;
  final InMemoryNodeRepository nodes;
  final String cvA;
  final String cvB;

  /// A 画布上的配置节点 Harbor。
  final String harborId;

  /// Harbor 的第二个（较新的）take。
  final String take2Id;

  /// B 画布上 Peaks 的唯一产物。
  final String peaksTakeId;
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
  final String peaksTake = await nodes.create(
    canvasId: cvB,
    type: 'image',
    nodeRole: 'result',
    label: 'Peaks take',
    sourceNodeId: peaks,
    typeConfig: <String, Object?>{'image_url': 'images/p.png'},
  );
  return _Seed(canvases, nodes, cvA, cvB, harbor, take2, peaksTake);
}

/// 节点表照常从内存仓储读（与画廊图同一份数据）；删除只改内存——仓储里还在、画廊图也不重读，格子还在不在
/// 全看本画布的实时节点表。（真控制器的删除走 UnitOfWork，外壳测试里连不上库。）
class _MemoryDeleteNodes extends CanvasNodesController {
  @override
  Future<NodeDeletion?> removeNode(String id) async {
    final List<CanvasNode> previous = state.valueOrNull ?? const <CanvasNode>[];
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      for (final CanvasNode n in previous)
        if (n.id != id) n,
    ]);
    return null;
  }
}

/// 画布节点一直在载入：节点表拿不到，画廊图却照样读得出来——格子画着，点了在节点表里找不到。
class _NeverLoadedNodes extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) => Completer<List<CanvasNode>>().future;
}

/// 素材格子的锚点：'leftRail-asset-' + galleryItemKey（'画布|相对路径|slot 序号'，节点主产物的 slot 是 null）。
Key _tileKey(String canvasId, String path, [int? slot]) =>
    ValueKey<String>('leftRail-asset-$canvasId|$path|$slot');

/// Harbor 又生成了一张：result 落库，然后 job 转成功。返回新产物的相对路径。
Future<String> _harborGeneratesAgain(ProviderContainer c, _Seed s) async {
  const String path = 'images/h3.png';
  final String id = await s.nodes.create(
    canvasId: s.cvA,
    type: 'image',
    nodeRole: 'result',
    label: 'Harbor take',
    sourceNodeId: s.harborId,
    positionX: 600,
    typeConfig: <String, Object?>{'image_url': path},
  );
  c.read(jobsRegistryProvider.notifier).upsert(
        JobState.succeeded(
          jobId: 'job-h3',
          providerId: 'p',
          canvasId: s.cvA,
          projectId: 'p1',
          sourceNodeId: s.harborId,
          resultNodeId: id,
          artifactPath: path,
        ),
      );
  return path;
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Seed s, {
  LeftRailPage page = LeftRailPage.assets,
  List<Override> extra = const <Override>[],
}) =>
    _pumpShell(
      tester,
      canvases: s.canvases,
      nodes: s.nodes,
      canvasId: s.cvA,
      page: page,
      extra: extra,
    );

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required InMemoryCanvasRepository canvases,
  required InMemoryNodeRepository nodes,
  required String canvasId,
  LeftRailPage page = LeftRailPage.assets,
  List<Override> extra = const <Override>[],
}) async {
  final paths = await setupTempPaths(tester, 'ink_left_assets_');
  await pumpInkShell(
    tester,
    paths: paths,
    initial: ShellState(tab: ShellTab.canvas, canvasId: canvasId, project: _alpha),
    extraOverrides: <Override>[
      canvasRepositoryProvider.overrideWith((_) async => canvases),
      nodeRepositoryProvider.overrideWith((_) async => nodes),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      // job 成功会弹通知卡（卡片带计时器）：换成只记录的假实现。
      toastServiceProvider.overrideWithValue(RecordingToastService()),
      ...extra,
    ],
  );
  final ProviderContainer c = readShellContainer(tester);
  c.read(leftRailProvider.notifier).open(page);
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

  testWidgets('点别的画布的格子：切到那张画布，挂上来后单选那个产物并移到视口中心', (tester) async {
    final _Seed s = await _seed();
    final ProviderContainer c = await _pump(tester, s);
    final AppLocalizations l = _l(tester);
    await _tap(tester, find.byKey(AssetsPanel.scopeKey(AssetScope.project)));

    await _tap(tester, find.text(l.leftRailAssetFinal('Peaks')));

    final ShellState shell = c.read(shellControllerProvider);
    expect(shell.tab, ShellTab.canvas);
    expect(shell.canvasId, s.cvB);
    expect(shell.project, _alpha);

    // 目标画布是切过去才挂上来的：它的选中 provider 在切换那一刻没有订阅者。定位要等它挂上、
    // 节点载入、视口上报之后再落地——多给几帧。
    for (int i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(
      c.read(canvasSelectionControllerProvider(s.cvB)),
      <String>{s.peaksTakeId},
      reason: '切过去以后那个产物要被选中（原先在目标画布挂载前就写选中，被 autoDispose 回收）',
    );
    final Offset card = tester.getCenter(find.byKey(ValueKey<String>('node-card-${s.peaksTakeId}')));
    final Offset stage = tester.getCenter(find.byType(CanvasView));
    expect(card.dx, closeTo(stage.dx, 1));
    expect(card.dy, closeTo(stage.dy, 1));
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('「在画廊中打开全部」：在外壳里切到当前项目的画廊', (tester) async {
    final _Seed s = await _seed();
    final ProviderContainer c = await _pump(tester, s);

    await _tap(tester, find.byKey(AssetsPanel.openGalleryKey));

    final ShellState shell = c.read(shellControllerProvider);
    expect(shell.tab, ShellTab.gallery);
    expect(shell.project, _alpha);
  }, timeout: const Timeout(Duration(seconds: 30)));

  group('新鲜度', () {
    testWidgets('画廊图被别处保活着时 job 成功，之后再切到素材页：新图在（开页即重读）', (tester) async {
      final _Seed s = await _seed();
      final ProviderContainer c = await _pump(tester, s, page: LeftRailPage.outline);
      // 别处（常驻的画廊标签、角色页的引用计数）保活着画廊图：此刻读出来的是还没有新图的那一版。
      c.listen(galleryGraphProvider('p1'), (_, _) {});
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(c.read(galleryGraphProvider('p1')).hasValue, isTrue, reason: '前置：画廊图已读出');

      // 素材页没开的时候，Harbor 又生成了一张。
      final String path = await _harborGeneratesAgain(c, s);
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }

      // 再切到素材页。
      c.read(leftRailProvider.notifier).open(LeftRailPage.assets);
      for (int i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(find.byKey(_tileKey(s.cvA, path)), findsOneWidget,
          reason: '画廊图被别处保活着、是旧的；开页时要让它重读，不能把开页前成功的 job 当成「已见」');
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('素材页开着时 job 成功：新图跟着出来', (tester) async {
      final _Seed s = await _seed();
      final ProviderContainer c = await _pump(tester, s);
      expect(find.byKey(_tileKey(s.cvA, 'images/h3.png')), findsNothing, reason: '前置：还没有这张');

      final String path = await _harborGeneratesAgain(c, s);
      for (int i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(find.byKey(_tileKey(s.cvA, path)), findsOneWidget,
          reason: '本页 watch 着画廊图，没人让它失效就一直不重读——要靠本页对注册表的监听');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('删除', () {
    testWidgets('删掉当前画布上的一个产物节点：它的格子立刻消失、剩下的 take 号跟着变，不等画廊图重读', (tester) async {
      final _Seed s = await _seed();
      final ProviderContainer c = await _pump(
        tester,
        s,
        extra: <Override>[canvasNodesControllerProvider.overrideWith(_MemoryDeleteNodes.new)],
      );
      final AppLocalizations l = _l(tester);
      final Finder tile = find.byKey(_tileKey(s.cvA, 'images/h2.png'));
      expect(tile, findsOneWidget, reason: '前置：格子在');
      expect(find.text(l.leftRailAssetsKindAll(3)), findsOneWidget);
      expect(find.text(l.leftRailAssetTake('Harbor', 1)), findsOneWidget, reason: '前置：Harbor 名下两个 take');

      await c.read(canvasNodesControllerProvider(s.cvA).notifier).removeNode(s.take2Id);
      await tester.pump();
      await tester.pump();

      expect(tile, findsNothing, reason: '节点已经不在画布上（画廊图里还有，它没重读）');
      expect(find.text(l.leftRailAssetsKindAll(2)), findsOneWidget, reason: '计数跟着少一个');
      expect(find.text(l.leftRailAssetFinal('Harbor')), findsOneWidget,
          reason: '剩下那张名下只有它一个：号在本画布的实时节点表上数，立刻改写成片（与检查器历史页同一份）');
      expect(find.text(l.leftRailAssetTake('Harbor', 1)), findsNothing);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('点一个在节点表里找不到的格子：不改选中集', (tester) async {
      final _Seed s = await _seed();
      final ProviderContainer c = await _pump(
        tester,
        s,
        extra: <Override>[canvasNodesControllerProvider.overrideWith(_NeverLoadedNodes.new)],
      );
      final Finder tile = find.byKey(_tileKey(s.cvA, 'images/h2.png'));
      expect(tile, findsOneWidget, reason: '前置：画廊图读得到，格子画着');

      await _tap(tester, tile);

      expect(c.read(canvasSelectionControllerProvider(s.cvA)), isEmpty,
          reason: '选中一个找不到的 id：状态栏写「选中 1」，检查器却是空的');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('take 号：素材页与检查器历史页同一口径', () {
    testWidgets('普通生成 + 批量混在一起：两处的号一致，批量 slot 写「#n」不占号；名下只有一个时两处都写成片', (tester) async {
      final InMemoryCanvasRepository canvases = InMemoryCanvasRepository();
      final InMemoryNodeRepository nodes = InMemoryNodeRepository();
      final String cv = await canvases.create(projectId: 'p1', name: 'A');
      Future<String> at(String id, DateTime t) async {
        await nodes.update(id, <String, Object?>{'created_at': t});
        return id;
      }

      // Harbor：1 月 1 日一张、1 月 2 日一次三格批量（没转正：result 容器没有产物 url）、1 月 3 日又一张。
      final String harbor = await nodes.create(
        canvasId: cv,
        type: 'text',
        nodeRole: 'config',
        label: 'Harbor',
        typeConfig: <String, Object?>{'text': 'dawn'},
      );
      final String first = await at(
        await nodes.create(
          canvasId: cv,
          type: 'image',
          nodeRole: 'result',
          label: 'Harbor take',
          sourceNodeId: harbor,
          positionX: 300,
          typeConfig: <String, Object?>{'image_url': 'images/h1.png'},
        ),
        DateTime.utc(2026, 1, 1),
      );
      final String batch = await at(
        await nodes.create(
          canvasId: cv,
          type: 'image',
          nodeRole: 'result',
          label: 'Harbor batch',
          sourceNodeId: harbor,
          positionX: 300,
          positionY: 300,
        ),
        DateTime.utc(2026, 1, 2),
      );
      final String latest = await at(
        await nodes.create(
          canvasId: cv,
          type: 'image',
          nodeRole: 'result',
          label: 'Harbor take',
          sourceNodeId: harbor,
          positionX: 300,
          positionY: 600,
          typeConfig: <String, Object?>{'image_url': 'images/h2.png'},
        ),
        DateTime.utc(2026, 1, 3),
      );
      // Boat：只生成过一次。
      final String boat = await nodes.create(
        canvasId: cv,
        type: 'text',
        nodeRole: 'config',
        label: 'Boat',
        positionY: 900,
        typeConfig: <String, Object?>{'text': 'drift'},
      );
      final String boatTake = await nodes.create(
        canvasId: cv,
        type: 'image',
        nodeRole: 'result',
        label: 'Boat take',
        sourceNodeId: boat,
        positionX: 300,
        positionY: 900,
        typeConfig: <String, Object?>{'image_url': 'images/b.png'},
      );
      final FakeBatchResultRepo slots = FakeBatchResultRepo(<String, Map<String, Object?>>{
        for (int i = 0; i < 3; i++)
          'slot-$i': <String, Object?>{
            'id': 'slot-$i',
            'node_id': batch,
            'job_id': 'job-batch',
            'slot_index': i,
            'status': 'success',
            'output_url': 'images/hb$i.png',
            'canvas_id': cv,
            'project_id': 'p1',
            'created_at': DateTime.utc(2026, 1, 2),
          },
      });

      final ProviderContainer c = await _pumpShell(
        tester,
        canvases: canvases,
        nodes: nodes,
        canvasId: cv,
        extra: <Override>[batchResultRepositoryProvider.overrideWith((_) async => slots)],
      );
      final AppLocalizations l = _l(tester);
      Finder tileText(String path, String text, [int? slot]) =>
          find.descendant(of: find.byKey(_tileKey(cv, path, slot)), matching: find.text(text));
      Finder rowText(String nodeId, String text) => find.descendant(
            of: find.byKey(InspectorHistoryPanel.takeKey(nodeId)),
            matching: find.text(text),
          );

      // 检查器切到历史页，选中 Harbor。
      await tester.tap(find.byKey(CanvasInspectorPanel.tabKey(InspectorTab.history)));
      await tester.pump();
      c.read(canvasSelectionControllerProvider(cv).notifier).select(harbor);
      await tester.pump();
      await tester.pump();

      // 历史页只数 result 节点：1 月 3 日那张是 take 2。素材页同一张也是 take 2（不是把三格 slot 也数进去的 take 5）。
      expect(rowText(first, l.inspectorHistoryTake(1)), findsOneWidget);
      expect(rowText(latest, l.inspectorHistoryTake(2)), findsOneWidget);
      expect(tileText('images/h1.png', l.leftRailAssetTake('Harbor', 1)), findsOneWidget);
      expect(tileText('images/h2.png', l.leftRailAssetTake('Harbor', 2)), findsOneWidget);
      // 批量 slot 不参与 take 编号，照画廊对 slot 的写法。
      for (int i = 0; i < 3; i++) {
        expect(tileText('images/hb$i.png', 'Harbor #${i + 1}', i), findsOneWidget);
      }

      // Boat 名下只有一个产物：两处都写成片。
      c.read(canvasSelectionControllerProvider(cv).notifier).select(boat);
      await tester.pump();
      await tester.pump();
      expect(rowText(boatTake, l.inspectorHistoryFinal), findsOneWidget);
      expect(tileText('images/b.png', l.leftRailAssetFinal('Boat')), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
