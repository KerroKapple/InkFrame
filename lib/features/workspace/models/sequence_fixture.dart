// 序列视图静态复刻的数据形状 + 稿上原文（docs/design/handoff-2026-09/InkFrame Timeline.html，2026-09-25 默认 EDL 版）。
//
// 与 palette_fixture 同例：手写 const 值对象，只在呈现层被读；假数据必须是稿上原文。
// 时间码按稿的 JS 算：24fps，tc = 00:00:SS:FF，短格式 SS:FF；片段 x/w = 秒 × 34px。
// 复刻页随 replica_main 常驻（视觉由静态复刻锁定）；接线截图（dev_capture.seedSequenceFixture）也读这里的镜名 / 片长。
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

@immutable
class SqShot {
  const SqShot({required this.name, required this.seconds, this.selected = false, this.trimmed = false, this.placeholder = false});
  final String name;
  final double seconds;
  final bool selected;
  final bool trimmed;
  /// 占位镜头：无产物，列表里「缺失」琥珀，轨上虚线框。
  final bool placeholder;
}

@immutable
class SqMarker {
  const SqMarker({required this.seconds, required this.label, required this.kind});
  final double seconds;
  final String label;
  /// scene（#8A8A8A fg5）/ breakpoint（accent）/ missing（danger）。
  final SqMarkerKind kind;
}

enum SqMarkerKind { scene, breakpoint, missing }

@immutable
class SqAudio {
  const SqAudio({required this.seconds, required this.length, required this.name});
  final double seconds;
  final double length;
  final String name;
}

abstract final class SequenceFixture {
  static const Size designSize = Size(1600, 1000);

  /// 稿：1 s = 34 px（42.5 s 序列适配 ~1500px 轨道宽）。
  static const double pxPerSec = 34;
  static const int fps = 24;

  static const List<String> menuItems = <String>['文件', '编辑', '序列', '标记', '窗口', '帮助'];
  static const String searchPlaceholder = '搜索镜头、标记…';
  static const List<String> tabs = <String>['Studio', '画布', '序列', '画廊'];
  static const int activeTab = 2;
  static const List<String> breadcrumb = <String>['山径破晓', '画布 02 · 主线', '叙事链 · 8 镜'];
  static const String format = '1920×1080 · 24fps · 00:00:42:12';
  static const String locateInCanvas = '回到画布定位';
  static const String exportMp4 = '导出 mp4';
  static const String deliver = '交付到 DaVinci Resolve';

  static const String chainTab = '叙事链';
  static const String unchainedTab = '未入链 · 3';
  static const List<String> chainColumns = <String>['镜头', '片长', '产物'];
  static const String stateVideo = '视频';
  static const String stateMissing = '缺失';
  static const String chainNote = '顺序即画布上的 narrative 边。这里拖动排序会改写连线；裁切写回镜头节点的入出点。';

  static const List<SqShot> shots = <SqShot>[
    SqShot(name: '山径入镜', seconds: 5),
    SqShot(name: '松林逆光', seconds: 4.5),
    SqShot(name: '图转视频 · 推镜', seconds: 4.33, selected: true, trimmed: true),
    SqShot(name: '背影渐清', seconds: 5),
    SqShot(name: '破晓山脊', seconds: 6),
    SqShot(name: '第一缕光', seconds: 5),
    SqShot(name: '回望', seconds: 8),
    SqShot(name: '收尾 · 空镜', seconds: 4.67, placeholder: true),
  ];

  static const String monitorTitle = '节目监视器';
  static const String monitorShot = '镜头 03 · 图转视频';
  static const String safeFrame = '安全框';
  static const String fit = '适合';
  /// 稿原文四段（接线时景别要等 P3，先出三段——静态复刻按稿原文）。
  static const String overlayLeft = '003 · 推镜 · 中景 · Kling 2.1';
  static const String overlayRight = 'src 00:00:01:16 / 00:00:05:00';
  static const double playedFraction = 0.27;
  static const String playhead = '00:00:11:12';
  static const String total = '00:00:42:12';
  static const List<String> transport = <String>['I', '◀◀', '◀', '▶', '▶', '▶▶', 'O'];
  static const int transportPlayIndex = 3;

  static const List<String> deliveryTabs = <String>['交付', '片段', '历史'];
  static const String targetLabel = '目标软件';
  static const List<String> targets = <String>['Resolve', 'Premiere', 'Final Cut', '剪映'];
  static const String deliveryPlaceholder = '交付随 P6 到来';

  static const String sequenceTitle = '序列';
  static const String snap = '吸附';
  static const String linkVA = '链接 V/A';
  static const String markerKey = '标记 M';
  static const String totalPrefix = '总长 ';
  static const String countSummary = '8 镜 · 1 占位';
  static const String markerTrack = '标记';
  static const String v1 = 'V1';
  static const String v1Meta = '视频 · 8';
  static const String a1 = 'A1';
  static const String a1Meta = '模型音轨 · 2';

  static const List<SqMarker> markers = <SqMarker>[
    SqMarker(seconds: 0, label: 'SC01 山径', kind: SqMarkerKind.scene),
    SqMarker(seconds: 18.83, label: 'SC02 破晓 · 断点', kind: SqMarkerKind.breakpoint),
    SqMarker(seconds: 37.83, label: '待补 · 空镜', kind: SqMarkerKind.missing),
  ];
  static const List<SqAudio> audio = <SqAudio>[
    SqAudio(seconds: 9.5, length: 4.33, name: '003 模型音轨'),
    SqAudio(seconds: 24.83, length: 5, name: '006 模型音轨'),
  ];
  /// 稿：播放头 1px 竖线 left 391、三角 13×9 left 385。
  static const double playheadX = 391;
  static const int tickEverySeconds = 5;
  static const int tickMaxSeconds = 40;

  static const List<String> statusLeft = <String>['山径破晓 · 叙事链 · 8 镜', '选中 003 · 入 00:00:00:12 · 出 00:00:04:20'];
  static const String lastDelivery = '上次交付 v02 · 2 小时前 · Resolve';
  static const String version = 'v0.1.0-alpha.9';

  /// 稿的 tc(s)：00:00:SS:FF。
  static String tc(double s) {
    final int t = s.floor();
    final int f = ((s - t) * fps).round();
    return '00:00:${t.toString().padLeft(2, '0')}:${f.toString().padLeft(2, '0')}';
  }

  /// 稿的 tcShort(s)：SS:FF。
  static String tcShort(double s) {
    final int t = s.floor();
    final int f = ((s - t) * fps).round();
    return '${t.toString().padLeft(2, '0')}:${f.toString().padLeft(2, '0')}';
  }

  static String idx(int i) => (i + 1).toString().padLeft(3, '0');

  static double px(double seconds) => (seconds * pxPerSec).roundToDouble();
}
