// NodeInspectorRouter：按 node.type 将 Inspector 分流到 image / video / shot 子面板。
// result 节点与 text 类型返回空。

import 'package:flutter/material.dart';

import '../models/canvas_node.dart';
import 'image_config_inspector.dart';
import 'shot_config_inspector.dart';
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
      CanvasNodeType.shot => ShotConfigInspector(node: node),
      CanvasNodeType.text => const SizedBox.shrink(),
    };
  }
}
