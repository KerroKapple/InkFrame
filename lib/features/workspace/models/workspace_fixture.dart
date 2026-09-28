// Workspace v2 静态复刻的数据形状 + 稿上原文（docs/design/handoff-2026-09/InkFrame Workspace v2.html）。
//
// 【为什么不是 freezed】与 ShellState 同例：build_runner 工具链受阻（docs/BOARD.md），
// 手写 const 不可变值对象；这些类只在呈现层被读，没有 copyWith 需求。
//
// 【为什么原文写死在这里】B 路径验收（任务书 + 用户拍板 2026-09-22）：静态复刻先与
// 稿并排比到只剩字形差异，再接 provider。假数据必须用稿上的原文——文字宽度一致，
// 并排对比时差异只剩视觉。接线后本文件整体删除，不保留。
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// 语义色调：呈现层按 tone 取 token，不传 Color。
enum WsTone { neutral, accent }

@immutable
class WsTool {
  const WsTool({required this.name, required this.shape, this.active = false});
  final String name;
  final WsToolShape shape;
  final bool active;
}

/// 稿上工具图标是不同圆角的 12×12 方框占位。
enum WsToolShape { square1, circle, pill, square0, square2, square3, cupBottom }

@immutable
class WsCanvasEntry {
  const WsCanvasEntry({
    required this.name,
    required this.count,
    this.expanded = false,
    this.selected = false,
  });
  final String name;
  final String count;
  final bool expanded;
  final bool selected;
}

@immutable
class WsNodeEntry {
  const WsNodeEntry({
    required this.name,
    required this.kind,
    this.selected = false,
  });
  final String name;
  final String kind;
  final bool selected;
}

/// 图区占位：稿上是纯色或 160° 渐变，接线后换真实缩略图。
@immutable
class WsThumb {
  const WsThumb.flat() : gradient = null;
  const WsThumb.gradient(WsThumbGradient g) : gradient = g;
  final WsThumbGradient? gradient;
}

enum WsThumbGradient { warmA, warmB, amber }

@immutable
class WsNode {
  const WsNode({
    required this.x,
    required this.y,
    required this.name,
    required this.kind,
    required this.thumb,
    required this.thumbLabel,
    required this.status,
    required this.meta,
    this.selected = false,
    this.hasIn = true,
    this.hasOut = true,
    this.statusTone = WsTone.neutral,
  });
  final double x;
  final double y;
  final String name;
  final String kind;
  final WsThumb thumb;
  final String thumbLabel;
  final String status;
  final String meta;
  final bool selected;
  final bool hasIn;
  final bool hasOut;
  final WsTone statusTone;
}

/// 三次贝塞尔连线：稿上 SVG path 的四个点原样搬。
@immutable
class WsEdge {
  const WsEdge({
    required this.from,
    required this.c1,
    required this.c2,
    required this.to,
    this.tone = WsTone.neutral,
    this.dashed = false,
  });
  final Offset from;
  final Offset c1;
  final Offset c2;
  final Offset to;
  final WsTone tone;
  final bool dashed;
}

@immutable
class WsEdgeLabel {
  const WsEdgeLabel({required this.x, required this.y, required this.text, required this.tone});
  final double x;
  final double y;
  final String text;
  final WsTone tone;
}

enum WsRowKind { select, slider, text, toggle }

@immutable
class WsInspectorRow {
  const WsInspectorRow.select(this.label, this.value)
      : kind = WsRowKind.select,
        fraction = 0,
        on = false;
  const WsInspectorRow.slider(this.label, this.value, this.fraction)
      : kind = WsRowKind.slider,
        on = false;
  const WsInspectorRow.text(this.label, this.value)
      : kind = WsRowKind.text,
        fraction = 0,
        on = false;
  const WsInspectorRow.toggle(this.label, this.value, {required this.on})
      : kind = WsRowKind.toggle,
        fraction = 0;
  final String label;
  final String value;
  final WsRowKind kind;
  final double fraction;
  final bool on;
}

@immutable
class WsInspectorGroup {
  const WsInspectorGroup({required this.title, required this.rows});
  final String title;
  final List<WsInspectorRow> rows;
}

@immutable
class WsJob {
  const WsJob({
    required this.idx,
    required this.name,
    required this.kind,
    required this.fraction,
    required this.status,
    required this.time,
    required this.model,
    required this.action,
    this.tone = WsTone.neutral,
  });
  final String idx;
  final String name;
  final String kind;
  final double fraction;
  final String status;
  final String time;
  final String model;
  final String action;
  /// 进行中 = accent（进度条 + 状态字同色）；其余中性。
  final WsTone tone;
}

/// 稿上那一屏的全部内容。
class WorkspaceFixture {
  const WorkspaceFixture._();

  static const List<String> menuItems = <String>['文件', '编辑', '画布', '节点', '窗口', '帮助'];
  static const String searchPlaceholder = '搜索项目、节点、产物…';
  static const String connected = '● 已连接';
  static const String providerName = 'fal.ai';

  static const List<String> tabs = <String>['Studio', '画布', '分镜', '画廊', '导出'];
  static const int activeTab = 1;
  static const List<String> breadcrumb = <String>['项目', '山径破晓', '画布 02 · 主线'];
  static const String importScript = '导入脚本';
  static const String sequencePreview = '序列预览';
  static const String exportVideo = '导出视频';

  static const List<WsTool> tools = <WsTool>[
    WsTool(name: '选择', shape: WsToolShape.square1, active: true),
    WsTool(name: '平移', shape: WsToolShape.circle),
    WsTool(name: '连线', shape: WsToolShape.pill),
    WsTool(name: '文本节点', shape: WsToolShape.square0),
    WsTool(name: '图像节点', shape: WsToolShape.square2),
    WsTool(name: '视频节点', shape: WsToolShape.square3),
    WsTool(name: '泳道', shape: WsToolShape.cupBottom),
  ];

  static const List<String> projectTabs = <String>['画布', '资产', '角色'];
  static const String filterPlaceholder = '筛选…';
  static const List<WsCanvasEntry> canvases = <WsCanvasEntry>[
    WsCanvasEntry(name: '画布 01 · 概念', count: '4'),
    WsCanvasEntry(name: '画布 02 · 主线', count: '6', expanded: true, selected: true),
    WsCanvasEntry(name: '画布 03 · 备选结尾', count: '2'),
  ];
  static const String nodesHeading = '当前画布 · 节点';
  static const List<WsNodeEntry> nodeList = <WsNodeEntry>[
    WsNodeEntry(name: '镜头 01 · 分镜描述', kind: 'shot'),
    WsNodeEntry(name: '镜头 01 · 图像', kind: 'image'),
    WsNodeEntry(name: '镜头 02 · 图像', kind: 'image'),
    WsNodeEntry(name: '镜头 03 · 图转视频', kind: 'video', selected: true),
    WsNodeEntry(name: '镜头 04 · 分镜描述', kind: 'shot'),
    WsNodeEntry(name: '角色 · 行者', kind: 'ref'),
  ];

  static const String canvasTitle = '画布 02 · 主线';
  static const String lanesPrefix = '泳道：';
  static const List<String> laneNames = <String>['场景 A', '场景 B'];
  static const String zoom = '82%';
  static const String autosave = '自动保存 · 2 秒前';
  static const String fit = '适应';
  static const List<String> laneLabels = <String>['场景 A · 山径', '场景 B · 破晓'];

  static const List<WsNode> nodes = <WsNode>[
    WsNode(x: 72, y: 130, name: '镜头 01 · 分镜描述', kind: 'shot', hasIn: false,
        thumb: WsThumb.flat(), thumbLabel: '晨雾中的山径，光线从左上穿过松林…',
        status: '已就绪', meta: 'txt'),
    WsNode(x: 372, y: 48, name: '镜头 01 · 图像', kind: 'image',
        thumb: WsThumb.gradient(WsThumbGradient.warmA), thumbLabel: '1024 × 576',
        status: '完成 · 2 个结果', meta: 'flux-pro'),
    WsNode(x: 372, y: 232, name: '镜头 02 · 图像', kind: 'image',
        thumb: WsThumb.gradient(WsThumbGradient.warmB), thumbLabel: '1024 × 576',
        status: '完成', meta: 'flux-pro'),
    WsNode(x: 692, y: 130, name: '镜头 03 · 图转视频', kind: 'video', selected: true,
        thumb: WsThumb.gradient(WsThumbGradient.amber),
        thumbLabel: '起始帧 ← 镜头 01 · 结束帧 ← 镜头 02 · 推镜',
        status: '渲染中 64%', statusTone: WsTone.accent, meta: 'kling-2.1'),
    WsNode(x: 72, y: 428, name: '镜头 04 · 分镜描述', kind: 'shot', hasIn: false,
        thumb: WsThumb.flat(), thumbLabel: '破晓，山脊线被第一缕光切开…',
        status: '已就绪', meta: 'txt'),
    WsNode(x: 372, y: 428, name: '镜头 04 · 图像', kind: 'image',
        thumb: WsThumb.flat(), thumbLabel: '等待生成', status: '队列中', meta: 'flux-pro'),
  ];

  static const List<WsEdge> edges = <WsEdge>[
    WsEdge(from: Offset(296, 217), c1: Offset(334, 217), c2: Offset(334, 135), to: Offset(367, 135)),
    WsEdge(from: Offset(296, 217), c1: Offset(334, 217), c2: Offset(334, 319), to: Offset(367, 319)),
    WsEdge(from: Offset(596, 135), c1: Offset(644, 135), c2: Offset(644, 217), to: Offset(687, 217), tone: WsTone.accent),
    WsEdge(from: Offset(596, 319), c1: Offset(644, 319), c2: Offset(644, 217), to: Offset(687, 217), dashed: true),
    WsEdge(from: Offset(296, 515), c1: Offset(334, 515), c2: Offset(334, 515), to: Offset(367, 515)),
  ];
  static const List<WsEdgeLabel> edgeLabels = <WsEdgeLabel>[
    WsEdgeLabel(x: 618, y: 156, text: '起始帧', tone: WsTone.accent),
    WsEdgeLabel(x: 618, y: 272, text: '结束帧', tone: WsTone.neutral),
  ];

  static const String promptTarget = '镜头 03 · 图转视频';
  static const String promptModel = 'Kling 2.1 Pro · 5s · 16:9 · 24fps · 推镜';
  static const String promptStyle = '基础风格：水墨';
  static const String promptAttached = '已附加';
  static const String promptText = '晨雾中的山径，中景缓慢推镜，逆光从左上方穿过松林形成丁达尔光束，人物背影逐渐清晰。';
  static const String promptCount = '38/500';
  static const String promptCost = '≈ 0.42';
  static const String generate = '生成';
  static const String generateShortcut = '⌘↵';

  static const List<String> inspectorTabs = <String>['属性', '状态', '历史'];
  static const String inspectorNodeName = '镜头 03 · 图转视频';
  static const String inspectorNodeMeta = 'video / config · fal · Kling 2.1';
  static const List<WsInspectorGroup> groups = <WsInspectorGroup>[
    WsInspectorGroup(title: '模型', rows: <WsInspectorRow>[
      WsInspectorRow.select('供应商', 'fal.ai'),
      WsInspectorRow.select('模型', 'Kling 2.1 Pro'),
      WsInspectorRow.slider('片长', '5s', 0.40),
      WsInspectorRow.select('画幅', '16:9'),
      WsInspectorRow.select('帧率', '24 fps'),
    ]),
    WsInspectorGroup(title: '关键帧', rows: <WsInspectorRow>[
      WsInspectorRow.text('起始帧', '镜头 01 · 图像 #2'),
      WsInspectorRow.text('结束帧', '镜头 02 · 图像'),
      WsInspectorRow.text('参考帧', '未连接'),
      WsInspectorRow.toggle('负向提示', '启用', on: true),
    ]),
    WsInspectorGroup(title: '镜头运动', rows: <WsInspectorRow>[
      WsInspectorRow.select('运镜方式', '推镜 Dolly In'),
      WsInspectorRow.select('景别', '中景 MS'),
      WsInspectorRow.select('机位角度', '平视 Eye Level'),
      WsInspectorRow.slider('运镜幅度', '0.35', 0.35),
      WsInspectorRow.select('焦段', '35mm'),
      WsInspectorRow.toggle('固定种子', '关闭', on: false),
    ]),
  ];
  static const String reset = '重置';
  static const String inspectorHint = '参数随选中节点切换';

  static const List<String> queueTabs = <String>['渲染队列', '序列', '导出历史'];
  static const String queueCount = '3';
  static const String concurrency = '并发 2';
  static const String clearDone = '清除已完成';
  static const List<String> queueHeaders = <String>['', '任务', '类型', '进度', '耗时', '模型', ''];
  static const List<WsJob> jobs = <WsJob>[
    WsJob(idx: '01', name: '镜头 03 · 图转视频', kind: 'video', fraction: 0.64, status: '渲染中',
        tone: WsTone.accent, time: '01:42', model: 'kling-2.1-pro', action: '取消'),
    WsJob(idx: '02', name: '镜头 04 · 图像', kind: 'image', fraction: 0, status: '队列中',
        time: '—', model: 'flux-pro-1.1', action: '取消'),
    WsJob(idx: '03', name: '镜头 02 · 图像', kind: 'image', fraction: 1, status: '完成',
        time: '00:18', model: 'flux-pro-1.1', action: '定位'),
    WsJob(idx: '04', name: '镜头 01 · 图像', kind: 'image', fraction: 1, status: '完成',
        time: '00:21', model: 'flux-pro-1.1', action: '定位'),
  ];

  static const List<String> statusLeft = <String>['山径破晓 · 画布 02', '6 节点 · 5 边', '选中 1'];
  static const String storagePath = '存储 ~/InkFrame/projects';
  static const String version = 'v0.1.0-alpha.9';
}
