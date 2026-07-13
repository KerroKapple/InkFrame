// 拖拽中节点的实时位移广播——供连线层跟手重绘（HI-13 的补充通道）。
//
// NodeCard 拖拽位移仍在卡片本地累积（不推全画布 state）；这里只发一个
// (nodeId, delta) 轻量信号，连线层窄域 watch 后仅重绘 EdgePainter 一层。
// 无拖拽时为 null。
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef NodeDragDelta = ({String nodeId, Offset delta});

final nodeDragDeltaProvider = StateProvider<NodeDragDelta?>(
  (_) => null,
  name: 'nodeDragDeltaProvider',
);
