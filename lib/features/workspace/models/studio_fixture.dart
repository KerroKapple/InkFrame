// Studio 首页静态复刻的数据形状 + 稿上原文（docs/design/handoff-2026-09/InkFrame Screens.html 第 1 屏）。
//
// 与 workspace_fixture 同例：手写 const 值对象，只在呈现层被读；假数据必须是稿上原文。
// 接线后本文件整体删除。
import 'package:flutter/foundation.dart';

@immutable
class StLibNav {
  const StLibNav(this.name, this.count, {this.selected = false});
  final String name;
  final String count;
  final bool selected;
}

@immutable
class StRecentCanvas {
  const StRecentCanvas(this.name, this.thumb);
  final String name;
  /// InkPalette.thumbPlaceholderGradients 的下标。
  final int thumb;
}

@immutable
class StProject {
  const StProject({
    required this.name,
    required this.meta,
    required this.canvases,
    required this.shots,
    required this.cover,
  });
  final String name;
  final String meta;
  final int canvases;
  final int shots;
  final int cover;
}

abstract final class StudioFixture {
  static const List<String> menuItems = <String>['文件', '编辑', '窗口', '帮助'];
  static const String searchPlaceholder = '搜索项目、画布、镜头、产物…';
  static const List<String> tabs = <String>['Studio', '画布', '序列', '画廊'];
  static const int activeTab = 0;
  static const String importPackage = '导入项目包';
  static const String newProject = '新建项目';

  static const String bannerMark = '!';
  static const String bannerTitle = '尚未配置任何 API Key，生成功能不可用。';
  static const String bannerHint = 'Key 存入系统钥匙串，不进数据库。';
  static const String bannerAction = '前往设置';

  static const String libraryHeading = '库';
  static const List<StLibNav> libNav = <StLibNav>[
    StLibNav('全部项目', '4', selected: true),
    StLibNav('最近打开', '6'),
    StLibNav('归档', '2'),
    StLibNav('回收站', '7'),
  ];
  static const String recentHeading = '最近画布';
  static const List<StRecentCanvas> recentCanvases = <StRecentCanvas>[
    StRecentCanvas('画布 02 · 主线', 2),
    StRecentCanvas('画布 01 · 概念', 0),
    StRecentCanvas('画布 03 · 备选结尾', 3),
    StRecentCanvas('角色测试 · 行者', 4),
  ];
  static const String settings = '设置';

  static const String gridTitle = '全部项目';
  static const String gridCount = '4';
  static const String sortLabel = '排序：最近修改';
  static const List<String> viewModes = <String>['网格', '列表'];
  static const int activeViewMode = 0;

  static const String resumeLabel = '上次离开时';
  static const String resumeName = '山径破晓 · 画布 02 · 主线';
  static const String resumeMeta = '2 小时前 · 6 节点';
  static const String resumeAction = '继续创作';
  static const String resumeNote = '3 个渲染任务已在上次退出时保存进度，恢复后可继续。';

  static const List<StProject> projects = <StProject>[
    StProject(name: '山径破晓', meta: '2 小时前 · 6 节点在渲染', canvases: 3, shots: 8, cover: 2),
    StProject(name: '夜航船', meta: '昨天', canvases: 1, shots: 4, cover: 1),
    StProject(name: '角色测试', meta: '3 天前', canvases: 5, shots: 12, cover: 4),
    StProject(name: '短剧示例', meta: '示例项目 · 未修改', canvases: 1, shots: 3, cover: 6),
  ];
  static const String newProjectHint = '空白 / 短剧示例 / 单画布';

  static const List<String> statusLeft = <String>['4 项目 · 11 画布', '存储 42.3 GB · 可用 128 GB'];
  static const String statusKey = '未配置 Key';
  static const String version = 'v0.1.0-alpha.9';
}
