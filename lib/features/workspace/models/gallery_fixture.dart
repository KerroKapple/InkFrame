// 画廊静态复刻的数据形状 + 稿上原文（docs/design/handoff-2026-09/InkFrame Screens.html 第 2 屏）。
//
// 与 workspace_fixture 同例：手写 const 值对象，只在呈现层被读；假数据必须是稿上原文，
// 并排比对时差异只剩视觉。接线后本文件整体删除。
import 'package:flutter/foundation.dart';

@immutable
class GaFilterItem {
  const GaFilterItem(this.name, this.count, {this.selected = false});
  final String name;
  final String count;
  final bool selected;
}

@immutable
class GaFilterGroup {
  const GaFilterGroup(this.title, this.items);
  final String title;
  final List<GaFilterItem> items;
}

@immutable
class GaItem {
  const GaItem({
    required this.idx,
    required this.name,
    required this.thumb,
    this.isVideo = false,
    this.dur = '',
    this.selected = false,
    this.isCurrent = false,
  });
  final String idx;
  final String name;
  /// InkPalette.thumbPlaceholderGradients 的下标（稿 tk[i % 8]）。
  final int thumb;
  final bool isVideo;
  final String dur;
  final bool selected;
  final bool isCurrent;
}

@immutable
class GaMetaRow {
  const GaMetaRow(this.label, this.value);
  final String label;
  final String value;
}

@immutable
class GaMetaGroup {
  const GaMetaGroup(this.title, this.rows);
  final String title;
  final List<GaMetaRow> rows;
}

@immutable
class GaLineage {
  const GaLineage({
    required this.name,
    required this.rel,
    this.thumb,
    this.current = false,
    this.branchLabel = '',
  });
  final String name;
  final String rel;
  /// null = 稿上的纯色 #262626（surface4）；否则渐变下标。
  final int? thumb;
  final bool current;
  final String branchLabel;
}

abstract final class GalleryFixture {
  static const String searchPlaceholder = '搜索产物、提示词、模型…';
  static const List<String> tabs = <String>['Studio', '画布', '序列', '画廊'];
  static const int activeTab = 3;
  static const List<String> breadcrumb = <String>['山径破晓', '全部产物'];
  static const String counts = '168 图 · 24 视频';
  static const String sendToCanvas = '已选 2 · 发送到画布';
  static const String saveAsCharacter = '存为角色';

  static const List<GaFilterGroup> filters = <GaFilterGroup>[
    GaFilterGroup('范围', <GaFilterItem>[
      GaFilterItem('本项目全部', '192'),
      GaFilterItem('画布 02 · 主线', '42', selected: true),
      GaFilterItem('画布 01 · 概念', '88'),
      GaFilterItem('画布 03 · 备选结尾', '24'),
    ]),
    GaFilterGroup('类型', <GaFilterItem>[
      GaFilterItem('图像', '168'),
      GaFilterItem('视频', '24'),
      GaFilterItem('角色参考', '6'),
    ]),
    GaFilterGroup('模型', <GaFilterItem>[
      GaFilterItem('flux-pro-1.1', '121'),
      GaFilterItem('kling-2.1-pro', '24'),
      GaFilterItem('gemini-image', '47'),
    ]),
    GaFilterGroup('标记', <GaFilterItem>[
      GaFilterItem('当前线', '8'),
      GaFilterItem('已入序列', '8'),
      GaFilterItem('收藏', '14'),
    ]),
  ];

  static const String gridTitle = '画布 02 · 主线';
  static const String gridCount = '42 项';
  static const String hoverAutoplay = '悬停自动播';
  static const List<String> sizes = <String>['中', '大', '特大'];
  static const int activeSize = 0;

  static const List<String> _names = <String>[
    '山径入镜', '松林逆光', '推镜 · 中景', '背影渐清', '破晓山脊', '第一缕光', '回望空镜', '角色 · 行者',
    '雾中石阶', '树影', '远山轮廓', '逆光剪影', '收尾空镜', '晨光特写', '侧脸',
  ];

  /// 稿：i===2 当前线 + 选中 + 视频（00:04:08）；i===5 视频（00:05:00）；i===7 选中。
  static List<GaItem> get items => <GaItem>[
        for (int i = 0; i < _names.length; i++)
          GaItem(
            idx: (i + 1).toString().padLeft(3, '0'),
            name: _names[i],
            thumb: i % 8,
            isVideo: i == 2 || i == 5,
            dur: i == 2 ? '00:04:08' : '00:05:00',
            selected: i == 2 || i == 7,
            isCurrent: i == 2,
          ),
      ];

  static const List<String> panelTabs = <String>['信息', '血缘'];
  static const String itemName = '镜头 03 · 图转视频';
  static const String itemSource = '画布 02 · 主线 · 2 小时前';

  static const List<GaMetaGroup> meta = <GaMetaGroup>[
    GaMetaGroup('生成参数', <GaMetaRow>[
      GaMetaRow('模型', 'kling-2.1-pro · fal.ai'),
      GaMetaRow('画幅 / 帧率', '16:9 · 1920×1080 · 24 fps'),
      GaMetaRow('片长', '00:00:05:00（已裁切为 00:00:04:08）'),
      GaMetaRow('镜头语言', '中景 MS · 推镜 Dolly In · 35mm · 平视'),
      GaMetaRow('关键帧', '起始帧 ← 镜头 01 · 结束帧 ← 镜头 02'),
    ]),
    GaMetaGroup('提示词', <GaMetaRow>[
      GaMetaRow('最终提示词', '水墨 · 晨雾中的山径，中景缓慢推镜，逆光从左上方穿过松林形成丁达尔光束，人物背影逐渐清晰。'),
      GaMetaRow('基础风格', '水墨（项目基底前缀）'),
      GaMetaRow('费用', '≈ 0.42 credits'),
    ]),
  ];

  static const String lineageTitle = '血缘 · 当前线';
  static const List<GaLineage> lineage = <GaLineage>[
    GaLineage(name: '镜头 01 · 分镜描述', rel: '分镜文本'),
    GaLineage(name: '镜头 01 · 图像 #2', rel: '起始帧 · 从 4 个结果中选定', thumb: 0, branchLabel: '+3 分支'),
    GaLineage(name: '镜头 02 · 图像', rel: '结束帧', thumb: 1),
    GaLineage(name: '镜头 03 · 图转视频', rel: '当前项 · 已入序列 003', thumb: 2, current: true, branchLabel: '+1 分支'),
  ];

  static const String locateInCanvas = '在画布中定位';
  static const String deriveNode = '派生新节点';

  static const String statusCount = '192 项 · 已选 2';
  static const String statusHint = '空格预览 · ↑↓ 切换 · 双击放大';
  static const String version = 'v0.1.0-alpha.9';
}
