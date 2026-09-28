// 风格泳道静态复刻的数据形状 + 稿上原文（docs/design/handoff-2026-09/InkFrame Lanes.html 01 / 02 / 03）。
//
// 与 palette_fixture 同例：手写 const 值对象，只在呈现层被读；假数据必须是稿上原文。
// 泳道底色是数据（lane_tint 词表的五个色值），不是 token——与生产代码一样用 hex 字符串经 parseHexColor。
// 接线后本文件整体删除。
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

@immutable
class LaHLane {
  const LaHLane({
    required this.label,
    required this.prompt,
    required this.hex,
    required this.top,
    required this.height,
    required this.count,
    this.collapsed = false,
    this.empty = false,
  });
  final String label;
  final String prompt;
  /// 色轨 / 色点的 hex；空道用 #3A3A3A（control）。
  final String hex;
  final double top;
  final double height;
  final String count;
  final bool collapsed;
  /// 空道：不铺弱底色。
  final bool empty;
}

@immutable
class LaNode {
  const LaNode({
    required this.x,
    required this.y,
    required this.name,
    required this.thumb,
    this.kind,
    this.selected = false,
    this.railHex,
    this.laneName,
  });
  final double x;
  final double y;
  final String name;
  /// InkPalette.thumbPlaceholderGradients 的下标（稿的渐变就近取）。
  final int thumb;
  final String? kind;
  final bool selected;
  final String? railHex;
  final String? laneName;
}

@immutable
class LaVLane {
  const LaVLane({required this.label, required this.hex, required this.left, required this.width, required this.count});
  final String label;
  final String hex;
  final double left;
  final double width;
  final String count;
}

abstract final class LanesFixture {
  /// 01 横向泳道：1280×620；02 竖向：760×480；03 编辑框：宽 456。
  static const Size hSize = Size(1280, 620);
  static const Size vSize = Size(760, 480);
  static const double dialogWidth = 456;
  /// 复刻页里三块的排布：01 在上，02 / 03 并排在下（间距 24），块间 24。
  static const double gap = 24;

  static const List<LaHLane> hLanes = <LaHLane>[
    LaHLane(label: '水墨 · 开场', prompt: 'traditional Chinese ink wash painting, sumi-e', hex: '#9AD8D8', top: 0, height: 176, count: '4'),
    LaHLane(label: '黄昏 · 山径', prompt: 'warm dusk, golden hour, long shadows', hex: '#FF8A50', top: 176, height: 184, count: '6'),
    LaHLane(label: '废墟 · 结尾', prompt: '', hex: '#6A4C93', top: 360, height: 36, count: '3', collapsed: true, empty: true),
    LaHLane(label: '未命名泳道', prompt: '未设置风格提示词', hex: '#3A3A3A', top: 396, height: 224, count: '0', empty: true),
  ];
  static const String collapsedTag = '已折叠';
  static const String inheritPrefix = '继承 ';

  static const List<LaNode> hNodes = <LaNode>[
    LaNode(x: 300, y: 52, name: '镜头 01 · 远山', kind: 'image', thumb: 6, railHex: '#9AD8D8', laneName: '水墨 · 开场'),
    LaNode(x: 520, y: 52, name: '镜头 02 · 石阶', kind: 'image', thumb: 6, railHex: '#9AD8D8', laneName: '水墨 · 开场'),
    LaNode(x: 300, y: 228, name: '镜头 05 · 松林', kind: 'image', thumb: 2, selected: true, railHex: '#FF8A50', laneName: '黄昏 · 山径'),
    LaNode(x: 520, y: 228, name: '镜头 06 · 背影', kind: 'image', thumb: 4, railHex: '#FF8A50', laneName: '黄昏 · 山径'),
    LaNode(x: 740, y: 228, name: '镜头 07 · 推镜', kind: 'video', thumb: 2, railHex: '#FF8A50', laneName: '黄昏 · 山径'),
  ];
  /// 稿：拖拽分界线的 3px 琥珀高亮线（top 359）与提示。
  static const double resizeHighlightTop = 359;
  static const String resizeHint = '拖拽分界线改厚度 · 下限 80px';
  static const String toolbarAdd = '+';
  static const String toolbarHorizontalGlyph = '⇅';
  static const String toolbarHorizontal = '横向';
  static const String toolbarVerticalGlyph = '⇄';
  static const String toolbarVertical = '竖向';
  static const String glyphCollapse = '⌃';
  static const String glyphExpand = '⌄';
  static const String glyphEdit = '✎';
  static const String glyphDelete = '⌫';
  static const String glyphMore = '⋯';

  static const List<LaVLane> vLanes = <LaVLane>[
    LaVLane(label: '水墨 · 开场', hex: '#9AD8D8', left: 0, width: 236, count: '4'),
    LaVLane(label: '黄昏 · 山径', hex: '#FF8A50', left: 236, width: 268, count: '4'),
    LaVLane(label: '雨夜 · 追逐', hex: '#4A78C8', left: 504, width: 256, count: '4'),
  ];
  static const List<LaNode> vNodes = <LaNode>[
    LaNode(x: 46, y: 58, name: '镜头 01 · 远山', thumb: 6),
    LaNode(x: 46, y: 186, name: '镜头 02 · 石阶', thumb: 6),
    LaNode(x: 282, y: 58, name: '镜头 05 · 松林', thumb: 2),
    LaNode(x: 550, y: 58, name: '镜头 09 · 霓虹', thumb: 3),
  ];

  static const String dialogTitle = '编辑泳道';
  static const String dialogClose = '✕';
  static const String fieldName = '名称';
  static const String nameValue = '雨夜 · 追逐';
  static const String fieldPrompt = '风格提示词';
  static const String promptValue = 'cyberpunk, neon-lit, rain-slicked streets, high contrast';
  static const String promptNote = '道内节点生成时自动前置此段。提示词为模型合约，保持英文。';
  static const String fieldTint = '底色';
  static const String tintAuto = '自动';
  static const List<String> swatches = <String>['#FF8A50', '#4A78C8', '#9AD8D8', '#3E7C5A', '#6A4C93'];
  static const String tintNote = '「自动」时按提示词推断，当前命中「neon / rain」→ #4A78C8。';
  static const String fieldPreview = '预览';
  static const String previewHex = '#4A78C8';
  static const String footerNote = '厚度不在此处调，拖分界线改';
  static const String cancel = '取消';
  static const String save = '保存';
}
