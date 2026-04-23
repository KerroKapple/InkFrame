// NodeInspectorRouter：按 node.type 将 Inspector 分流到 image / video 子面板。
// result 节点与不支持的类型（text / shot）一律返回空。

import 'package:flutter/material.dart';

import '../models/canvas_node.dart';
import 'image_config_inspector.dart';
import 'video_config_inspector.dart';

class NodeInspectorRouter extends StatelessWidget {
  const NodeInspectorRouter({super.key, required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    if (node.role != NodeRole.config) return const SizedBox.shrink();
    return switch (node.type) {
      CanvasNodeType.image => ImageConfigInspector(node: node),
      CanvasNodeType.video => VideoConfigInspector(node: node),
      CanvasNodeType.text || CanvasNodeType.shot => const SizedBox.shrink(),
    };
  }
}
