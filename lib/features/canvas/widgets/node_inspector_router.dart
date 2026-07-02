// NodeInspectorRouter：按 node.role / node.type 将 Inspector 分流。
// config → image / video / shot 配置面板；result + image → 批量结果面板；其余返回空。

import 'package:flutter/material.dart';

import '../models/canvas_node.dart';
import 'image_config_inspector.dart';
import 'image_result_inspector.dart';
import 'shot_config_inspector.dart';
import 'video_config_inspector.dart';

class NodeInspectorRouter extends StatelessWidget {
  const NodeInspectorRouter({super.key, required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    if (node.role == NodeRole.result) {
      return switch (node.type) {
        CanvasNodeType.image => ImageResultInspector(node: node),
        _ => const SizedBox.shrink(),
      };
    }
    return switch (node.type) {
      CanvasNodeType.image => ImageConfigInspector(node: node),
      CanvasNodeType.video => VideoConfigInspector(node: node),
      CanvasNodeType.shot => ShotConfigInspector(node: node),
      CanvasNodeType.text => const SizedBox.shrink(),
    };
  }
}
