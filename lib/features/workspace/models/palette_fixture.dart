// 命令面板静态复刻的数据形状 + 稿上原文（docs/design/handoff-2026-09/InkFrame Screens.html 第 4 屏右）。
//
// 与 workspace_fixture 同例：手写 const 值对象，只在呈现层被读；假数据必须是稿上原文。
// 接线后本文件整体删除。
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

@immutable
class PaRow {
  const PaRow({
    required this.name,
    required this.path,
    this.hint = '',
    this.thumb,
    this.selected = false,
  });
  final String name;
  final String path;
  final String hint;
  /// InkPalette.thumbPlaceholderGradients 的下标；null = 稿上的纯色 #262626（surface4）。
  final int? thumb;
  final bool selected;
}

@immutable
class PaGroup {
  const PaGroup(this.title, this.rows);
  final String title;
  final List<PaRow> rows;
}

abstract final class PaletteFixture {
  /// 稿上第 4 屏右是 788×620 的一块（不是整窗）。
  static const Size designSize = Size(788, 620);
  static const double panelWidth = 620;
  static const double panelTop = 64;

  static const String badge = '⌘K';
  static const String query = '推镜';
  static const String resultCount = '12 条结果';

  static const List<PaGroup> groups = <PaGroup>[
    PaGroup('镜头', <PaRow>[
      PaRow(name: '镜头 03 · 图转视频 · 推镜', path: '山径破晓 › 画布 02 › 序列 003', hint: '↵', thumb: 2, selected: true),
      PaRow(name: '镜头 06 · 第一缕光 · 推镜', path: '山径破晓 › 画布 02 › 序列 006', thumb: 5),
    ]),
    PaGroup('产物', <PaRow>[
      PaRow(name: '推镜 · 中景 · 00:04:08', path: '画廊 › 视频 › kling-2.1-pro', thumb: 2),
      PaRow(name: '推镜测试 #4', path: '画廊 › 图像 › 已弃分支', thumb: 7),
    ]),
    PaGroup('设置项', <PaRow>[
      PaRow(name: '运镜方式 · 默认值', path: '设置 › 节点布局 › 视频检查器'),
    ]),
    PaGroup('动作', <PaRow>[
      PaRow(name: '为选中镜头设置推镜', path: '画布 › 检查器 › 镜头运动'),
      PaRow(name: '按运镜筛选画廊', path: '画廊 › 标记'),
    ]),
  ];

  static const List<String> footerHints = <String>['↑↓ 移动', '↵ 打开', '⌘↵ 在画布中定位'];
  static const String footerClose = 'Esc 关闭';
}
