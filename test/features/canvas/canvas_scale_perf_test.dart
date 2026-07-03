// 画布规模性能基线 + 粗护栏（DoD #6）。
//
// 背景：CanvasView 不做视口裁剪——`for (final node in nodes) Positioned(NodeCard(...))`
// 把全部节点建进 4000×4000 的 Stack，EdgePainter 画全部边。故 build/layout/paint 成本
// 随节点数增长，这正是 "节点 > 200 帧率下降"（ROADMAP / PRD §3.9）的来源。
//
// headless flutter test 无 GPU、无真实 vsync，测不到真实光栅帧率。本测试覆盖可在无头
// 环境稳定测量的代理指标：
//   1) 节点+边层 pumpWidget(build+layout+paint) 耗时——诊断基线，只 print 不硬断言
//      （避免环境抖动挂 CI，与 job_queue_service_cancel_bench_test 同 philosophy）；
//   2) 命中测试 hitTestEdge（画布规模敏感的纯函数热路径）的 O(n+m) 确定性护栏
//      （纯 CPU、零抖动、巨大余量，与 job_queue perf group 的 N=10000<50ms 粗线同形）；
//   3) 一条极宽松的灾难性回归绝对上限（仅捕获爆炸式退化，不做微基准）。
// 真实 GPU 帧率验证需 integration_test 在带 GPU 的 runner 上跑——见 docs/internal/perf-baseline.md。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/edge_hit_test.dart';
import 'package:inkframe/features/canvas/widgets/edge_painter.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

class _StubFileResolver implements FileResolverService {
  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) =>
      throw UnimplementedError();

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File(relativePath);

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      source.path;

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      Directory.systemTemp;
}

// config 节点 + 无 image_url → 不触发 Image.file，渲染廉价且确定。
List<CanvasNode> _nodes(int n) => List.generate(
      n,
      (i) => CanvasNode(
        id: 'n$i',
        label: 'Node $i',
        type: CanvasNodeType.image,
        typeConfig: const <String, Object?>{'prompt': 'scale bench node'},
        position: Offset((i % 20) * 190.0, (i ~/ 20) * 175.0),
      ),
    );

// 链式连边：n-1 条 data 边。
List<CanvasEdge> _edges(List<CanvasNode> nodes) => <CanvasEdge>[
      for (var i = 0; i < nodes.length - 1; i++)
        CanvasEdge(
          id: 'e$i',
          canvasId: 'c',
          sourceNodeId: nodes[i].id,
          targetNodeId: nodes[i + 1].id,
          edgeType: EdgeType.data,
        ),
    ];

// 镜像 _CanvasStage 的两个规模敏感层：EdgePainter（全部边）+ 节点层（全部 NodeCard）。
Widget _scaleScene(List<CanvasNode> nodes, List<CanvasEdge> edges) => ProviderScope(
      overrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(_StubFileResolver()),
      ],
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 4000,
            height: 4000,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: EdgePainter(
                      edges: edges,
                      nodes: nodes,
                      dataColor: const Color(0xFF888888),
                      narrativeColor: const Color(0xFF888888),
                      generationSourceColor: const Color(0xFF888888),
                      selectedColor: const Color(0xFFFFFFFF),
                      selectedEdgeId: null,
                    ),
                  ),
                ),
                for (final node in nodes)
                  Positioned(
                    left: node.position.dx,
                    top: node.position.dy,
                    child: RepaintBoundary(
                      child: NodeCard(
                        node: node,
                        selected: false,
                        onTap: () {},
                        onDragEnd: (_) {},
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

Future<int> _pumpMicros(WidgetTester tester, int n) async {
  final nodes = _nodes(n);
  final edges = _edges(nodes);
  final sw = Stopwatch()..start();
  await tester.pumpWidget(_scaleScene(nodes, edges));
  sw.stop();
  return sw.elapsedMicroseconds;
}

void main() {
  testWidgets(
    'canvas scale — node-layer build baseline (diagnostic, no hard assert)',
    (tester) async {
      // 4000×4000 surface：全部节点在视口内完成 layout，避免裁剪/overflow 噪音。
      await tester.binding.setSurfaceSize(const Size(4000, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 预热一帧，吸收字体/binding 一次性成本，避免污染首个测点。
      await _pumpMicros(tester, 10);

      // ignore: avoid_print
      print('| N nodes | build+layout+paint ms | per-node μs |');
      // ignore: avoid_print
      print('|---------|----------------------|-------------|');
      for (final n in <int>[50, 100, 200, 400]) {
        final us = await _pumpMicros(tester, n);
        // ignore: avoid_print
        print('| $n | ${(us / 1000).toStringAsFixed(1)} | '
            '${(us / n).toStringAsFixed(1)} |');
      }
    },
  );

  testWidgets(
    'canvas scale — 400 nodes build under catastrophic-regression ceiling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(4000, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpMicros(tester, 10); // warmup

      final us = await _pumpMicros(tester, 400);
      // 极宽松上限：仅捕获爆炸式退化（如误引入 O(n²) layout / 每节点全表扫描）。
      // 不是微基准——CI 机器波动大，阈值留巨大余量。实测基线见 perf-baseline.md。
      expect(
        us,
        lessThan(8 * 1000 * 1000), // 8s；本机实测 400 节点远低于此
        reason: 'building 400 canvas nodes took ${us / 1000}ms — far above '
            'baseline; suspect a non-linear regression in the node layer.',
      );
    },
  );

  test('canvas scale — hitTestEdge stays O(n+m) at scale (deterministic guard)',
      () {
    final nodes = _nodes(3000);
    final edges = _edges(nodes);
    // 命中点放在远处，强制遍历全部边（最坏路径）。
    final sw = Stopwatch()..start();
    final hit = hitTestEdge(
      point: const Offset(-99999, -99999),
      edges: edges,
      nodes: nodes,
    );
    sw.stop();
    expect(hit, isNull);
    // 纯 CPU，N=M=3000 线性遍历应在毫秒级；50ms 上限留巨大余量、零抖动。
    expect(
      sw.elapsedMilliseconds,
      lessThan(50),
      reason: 'hitTestEdge over 3000 edges took ${sw.elapsedMilliseconds}ms — '
          'suspect worse than O(n+m).',
    );
  });
}
