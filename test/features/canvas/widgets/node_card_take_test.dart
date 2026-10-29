// NodeCard 的 take 状态（tc-set-current，TakesCost 稿「当前 take · 固定」）：同源 ≥ 2 个 take 时，当前那张描边 accent、
// 固定时右上角图钉；非当前图区半透明；状态行「take N / M」，当前加「· 当前」，比固定的当前新加「· 未采用」。
//
// 装配：卡片挂在一个先 watch 画布节点控制器的 Consumer 下面（与画布上一样：节点控制器一直有人看着，卡片才去订它）。
//
// 变异对照：
// - 卡片不画图钉 ⇒「固定旧 take：它描边 accent + 图钉…」红。
// - 非当前不半透明 / 状态行不分「未采用」⇒ 同一条红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/test_app.dart';

const String _cid = 'c1';

CanvasNode _config({String? pin}) => CanvasNode(
      id: 'cfg',
      label: 'Shot 01',
      type: CanvasNodeType.image,
      canvasId: _cid,
      typeConfig: <String, Object?>{'prompt': 'harbor', 'pinned_result_id': ?pin},
    );

CanvasNode _take(String id, int day) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      projectId: 'p1',
      canvasId: _cid,
      sourceNodeId: 'cfg',
      createdAt: DateTime.utc(2026, 5, day),
      typeConfig: <String, Object?>{'image_url': 'images/$id.png'},
    );

Finder _card(String id) => find.byKey(ValueKey<String>('take-card-$id'));

Finder _inCard(String id, Finder matching) => find.descendant(of: _card(id), matching: matching);

/// 图区外一圈描边（圆角 s5 的那个 DecoratedBox）的颜色。
Color _edgeOf(WidgetTester tester, String id) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    _inCard(
      id,
      find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border is Border &&
            (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(InkRadius.s5),
      ),
    ),
  );
  return ((box.decoration as BoxDecoration).border! as Border).top.color;
}

Future<void> _pump(WidgetTester tester, List<CanvasNode> nodes, List<String> cards) async {
  await pumpInkApp(
    tester,
    Scaffold(
      body: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final List<CanvasNode>? live = ref.watch(canvasNodesControllerProvider(_cid)).valueOrNull;
          if (live == null) return const SizedBox.shrink();
          return SingleChildScrollView(
            child: Column(
              children: <Widget>[
                for (final String id in cards)
                  Padding(
                    padding: const EdgeInsets.all(InkSpacing.md),
                    child: NodeCard(
                      key: ValueKey<String>('take-card-$id'),
                      node: live.firstWhere((CanvasNode n) => n.id == id),
                      selected: false,
                      onTap: () {},
                      onDragEnd: (_) {},
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
    overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(nodes)),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ],
    surfaceSize: const Size(400, 1000),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('固定旧 take：它描边 accent + 图钉，更新的那张状态行「未采用」且图区半透明', (tester) async {
    await _pump(
      tester,
      <CanvasNode>[_config(pin: 't2'), _take('t1', 1), _take('t2', 2), _take('t3', 3)],
      <String>['t1', 't2', 't3'],
    );
    final AppLocalizations l = tester.element(_card('t2')).l10n;
    final InkColors colors = tester.element(_card('t2')).inkColors;

    // 固定的当前 take：accent 描边 + 图钉、不半透明、「take 2 / 3 · 当前」。
    expect(_inCard('t2', find.byKey(NodeCard.takePinKey)), findsOneWidget);
    expect(_edgeOf(tester, 't2'), colors.accent);
    expect(_inCard('t2', find.byKey(NodeCard.takeDimKey)), findsNothing);
    expect(_inCard('t2', find.text(l.takeCardCaptionCurrent(2, 3))), findsOneWidget);

    // 比它新的 t3：未采用、半透明、无图钉、outline。
    expect(_inCard('t3', find.text(l.takeCardCaptionNotAdopted(3, 3))), findsOneWidget);
    expect(_inCard('t3', find.byKey(NodeCard.takeDimKey)), findsOneWidget);
    expect(_inCard('t3', find.byKey(NodeCard.takePinKey)), findsNothing);
    expect(_edgeOf(tester, 't3'), colors.outline);

    // 比它旧的 t1：只是非当前。
    expect(_inCard('t1', find.text(l.takeCardCaption(1, 3))), findsOneWidget);
    expect(_inCard('t1', find.byKey(NodeCard.takeDimKey)), findsOneWidget);
  });

  testWidgets('没固定：最新那张写「当前」、无图钉', (tester) async {
    await _pump(
      tester,
      <CanvasNode>[_config(), _take('t1', 1), _take('t2', 2)],
      <String>['t1', 't2'],
    );
    final AppLocalizations l = tester.element(_card('t2')).l10n;
    final InkColors colors = tester.element(_card('t2')).inkColors;

    expect(_inCard('t2', find.text(l.takeCardCaptionCurrent(2, 2))), findsOneWidget);
    expect(_edgeOf(tester, 't2'), colors.accent);
    expect(find.byKey(NodeCard.takePinKey), findsNothing, reason: '没固定：谁都不画图钉');
    expect(_inCard('t2', find.byKey(NodeCard.takeDimKey)), findsNothing);
    expect(_inCard('t1', find.text(l.takeCardCaption(1, 2))), findsOneWidget);
    expect(_inCard('t1', find.byKey(NodeCard.takeDimKey)), findsOneWidget);
  });

  testWidgets('只有一个 take：卡片照旧（「完成」、不描 accent、不半透明）', (tester) async {
    await _pump(tester, <CanvasNode>[_config(), _take('t1', 1)], <String>['t1']);
    final AppLocalizations l = tester.element(_card('t1')).l10n;
    final InkColors colors = tester.element(_card('t1')).inkColors;
    expect(_inCard('t1', find.text(l.nodeStatusDone)), findsOneWidget);
    expect(_edgeOf(tester, 't1'), colors.outline);
    expect(_inCard('t1', find.byKey(NodeCard.takeDimKey)), findsNothing);
  });
}
