// ShellKeepAliveHost 的两条不变量（脱离外壳直接单测，不吃 boot 密封面）。
//
// 1. Key 落在【槽位】上：五个 shellTabBody-* 恒在树里，无论是否物化。
// 2. 内容懒物化、物化后【永不换回占位】。
//
// 这两条是 V4 成立的物理前提。「宿主 eager 建五子」与「切标签时把非活动槽换回
// SizedBox.shrink()」两个变异都必须在这里打红。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/widgets/shell_keep_alive_host.dart';

/// 每个标签体渲染一个带自身名字的探针，便于逐槽断言。
class _Probe extends StatelessWidget {
  const _Probe(this.tab);
  final ShellTab tab;
  @override
  Widget build(BuildContext context) => Text('body-${tab.name}');
}

Finder _slot(ShellTab t) =>
    find.byKey(ValueKey<String>('shellTabBody-${t.name}'), skipOffstage: false);

Finder _body(ShellTab t) => find.text('body-${t.name}', skipOffstage: false);

/// 可从外部改 activeTab 的驱动壳。
class _Host extends StatefulWidget {
  const _Host(this.initial);
  final ShellTab initial;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late ShellTab _tab = widget.initial;

  void go(ShellTab t) => setState(() => _tab = t);

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: ShellKeepAliveHost(
          activeTab: _tab,
          buildTab: (BuildContext _, ShellTab t) => _Probe(t),
        ),
      );
}

void main() {
  testWidgets('五个槽位 Key 恒在树里，无论是否物化', (tester) async {
    await tester.pumpWidget(const _Host(ShellTab.studio));

    for (final ShellTab t in ShellTab.values) {
      expect(_slot(t), findsOneWidget, reason: '槽位 ${t.name} 不在树里');
    }
  });

  testWidgets('懒物化：只有激活过的标签体在树里', (tester) async {
    await tester.pumpWidget(const _Host(ShellTab.studio));

    expect(_body(ShellTab.studio), findsOneWidget);
    for (final ShellTab t in ShellTab.values) {
      if (t == ShellTab.studio) continue;
      expect(
        _body(t),
        findsNothing,
        reason: '${t.name} 从未被激活，槽内必须仍是占位——'
            '宿主 eager 建五子会在这里红',
      );
    }
  });

  testWidgets('物化后永不换回占位：切走的标签体仍在树里、仍离台', (tester) async {
    await tester.pumpWidget(const _Host(ShellTab.studio));
    final _HostState host = tester.state<_HostState>(find.byType(_Host));

    host.go(ShellTab.gallery);
    await tester.pump();

    // 画廊在台。
    expect(find.text('body-gallery'), findsOneWidget);
    // Studio 离台，但【仍在树里】——切标签时把非活动槽换回 SizedBox.shrink()
    // 的变异会在这里红。
    expect(_body(ShellTab.studio), findsOneWidget);
    expect(find.text('body-studio'), findsNothing);

    // 再切回去：两者都还在树里。
    host.go(ShellTab.studio);
    await tester.pump();
    expect(find.text('body-studio'), findsOneWidget);
    expect(_body(ShellTab.gallery), findsOneWidget);
    expect(find.text('body-gallery'), findsNothing);
  });

  testWidgets('index 跟着 ShellTab.values 的位次走', (tester) async {
    await tester.pumpWidget(const _Host(ShellTab.export));
    final IndexedStack stack =
        tester.widget<IndexedStack>(find.byType(IndexedStack));

    expect(stack.index, ShellTab.values.indexOf(ShellTab.export));
    expect(stack.sizing, StackFit.expand);
  });
}
