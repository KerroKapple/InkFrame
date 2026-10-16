// NodeInspectorRouter：按 node.role / node.type 将 Inspector 分流。
// config → image / video / shot 配置面板，text → 正文编辑面板；
// result → image / video 产物面板（预览 + 生成参数 + 动作；image 有批量 slot 时顶部换成批量网格）。
// result 只会是 image / video（生成只产这两种）；其余组合不画。

import 'package:flutter/material.dart';

import '../models/canvas_node.dart';
import 'image_config_inspector.dart';
import 'image_result_inspector.dart';
import 'shot_config_inspector.dart';
import 'text_node_inspector.dart';
import 'video_config_inspector.dart';
import 'video_result_inspector.dart';

class NodeInspectorRouter extends StatelessWidget {
  const NodeInspectorRouter({super.key, required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    if (node.role == NodeRole.result) {
      return switch (node.type) {
        CanvasNodeType.image => ImageResultInspector(node: node),
        CanvasNodeType.video => VideoResultInspector(node: node),
        CanvasNodeType.text || CanvasNodeType.shot => const SizedBox.shrink(),
      };
    }
    return switch (node.type) {
      CanvasNodeType.image => ImageConfigInspector(node: node),
      CanvasNodeType.video => VideoConfigInspector(node: node),
      CanvasNodeType.shot => ShotConfigInspector(node: node),
      CanvasNodeType.text => TextNodeInspector(node: node),
    };
  }
}
