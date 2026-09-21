// 保活宿主：五个标签槽，懒物化、物化后常驻。
//
// 两条不变量，缺一 V4 就塌：
// 1. Key 落在【槽位】上——五个 shellTabBody-* 恒在树里，无论是否物化。
//    保活断言因此锚在稳定 Key 上，不会因"画廊未选项目所以 GalleryScreen 不 mount"
//    而假红。守护它的是 test/features/shell/shell_keep_alive_host_test.dart。
// 2. 内容懒物化、物化后【永不换回占位】——于是
//    find.byType(GalleryScreen, skipOffstage: false) 在从未访问过画廊的用例里
//    真的 findsNothing。这是 V4 成立的唯一物理前提。
//    守护它的是 test/app/app_routing_test.dart。
import 'package:flutter/material.dart';

import '../models/shell_state.dart';

class ShellKeepAliveHost extends StatefulWidget {
  const ShellKeepAliveHost({
    super.key,
    required this.activeTab,
    required this.buildTab,
  });

  final ShellTab activeTab;

  /// 惰性构造器，每帧重新调用（不缓存 Widget 实例）——isActive / isVisible
  /// 靠这条路径逐帧下传。
  ///
  /// 用函数 + exhaustive switch，不用 `Map<ShellTab, WidgetBuilder>`：
  /// 加第六个标签时编译器在 switch 上报错，Map 版本是 builders[t]! 的运行时崩溃。
  final Widget Function(BuildContext, ShellTab) buildTab;

  @override
  State<ShellKeepAliveHost> createState() => _ShellKeepAliveHostState();
}

class _ShellKeepAliveHostState extends State<ShellKeepAliveHost> {
  final Set<ShellTab> _materialized = <ShellTab>{};

  @override
  void initState() {
    super.initState();
    _materialized.add(widget.activeTab);
  }

  @override
  void didUpdateWidget(ShellKeepAliveHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _materialized.add(widget.activeTab);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: ShellTab.values.indexOf(widget.activeTab),
      // 必需：默认 StackFit.loose 会让画布/画廊 shrink-wrap，Column+Expanded 直接错位。
      sizing: StackFit.expand,
      children: <Widget>[
        for (final ShellTab t in ShellTab.values)
          KeyedSubtree(
            key: ValueKey<String>('shellTabBody-${t.name}'),
            child: _materialized.contains(t)
                ? widget.buildTab(context, t)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
