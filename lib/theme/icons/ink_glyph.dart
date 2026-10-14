// 图标集 v1 的路径数据：20×20 网格，1.5 描边（随尺寸等比缩放），圆头圆角，单色。
//
// 与设计稿「InkFrame 画布重设计稿 › 图标集 v1」是同一份路径——稿上改了哪一笔，
// 这里整条替换，别在应用侧单独微调，否则两边会悄悄分叉。
// 解析见 svg_path_data.dart，绘制见 components/ink_icon.dart。
import 'package:flutter/foundation.dart';

/// 一个图标由若干笔组成：描边笔（默认）或实心笔（圆点、星芒）。
@immutable
class InkGlyphPart {
  const InkGlyphPart.stroke(this.data) : filled = false;
  const InkGlyphPart.fill(this.data) : filled = true;

  /// SVG path 的 d 字符串，坐标落在 20×20 网格里。
  final String data;

  /// true = 实心填充；false = 按图标描边宽度描线。
  final bool filled;
}

enum InkGlyph {
  // ---- 导航（画布左栏 / 工作室左栏） ----
  /// 大纲
  outline(<InkGlyphPart>[
    InkGlyphPart.fill('M3.4 5a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0 -2.2 0z'),
    InkGlyphPart.stroke('M7.75 5H16'),
    InkGlyphPart.stroke('M4.5 7.25V15h1.75'),
    InkGlyphPart.stroke('M4.5 10h1.75'),
    InkGlyphPart.fill('M7.4 10a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0 -2.2 0z'),
    InkGlyphPart.stroke('M11.25 10H16'),
    InkGlyphPart.fill('M7.4 15a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0 -2.2 0z'),
    InkGlyphPart.stroke('M11.25 15H16'),
  ]),
  /// 素材
  assets(<InkGlyphPart>[
    InkGlyphPart.stroke('M6.5 3.5H15a1.5 1.5 0 0 1 1.5 1.5v8.5'),
    InkGlyphPart.stroke('M5 6.5h7a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1 -1.5 1.5h-7a1.5 1.5 0 0 1 -1.5 -1.5v-7a1.5 1.5 0 0 1 1.5 -1.5z'),
    InkGlyphPart.stroke('M3.75 14.25l2.75-2.75 2.5 2.5 1.5-1.5 2.75 2.75'),
    InkGlyphPart.fill('M9.25 9.25a1 1 0 1 0 2 0a1 1 0 1 0 -2 0z'),
  ]),
  /// 角色
  characters(<InkGlyphPart>[
    InkGlyphPart.stroke('M7 6.75a3 3 0 1 0 6 0a3 3 0 1 0 -6 0z'),
    InkGlyphPart.stroke('M4 16.75c.9-3.2 3.2-5 6-5s5.1 1.8 6 5'),
  ]),
  /// 剧本
  script(<InkGlyphPart>[
    InkGlyphPart.stroke('M5.5 2.5h5.75L15 6.25V16a1.5 1.5 0 0 1-1.5 1.5h-8A1.5 1.5 0 0 1 4 16V4a1.5 1.5 0 0 1 1.5-1.5z'),
    InkGlyphPart.stroke('M11 2.75V6.5h3.75'),
    InkGlyphPart.stroke('M7 10h5.75M7 12.75h5.75M7 15.5h3.25'),
  ]),
  /// 节点库
  nodeLibrary(<InkGlyphPart>[
    InkGlyphPart.stroke('M4.75 3.5h3a1.25 1.25 0 0 1 1.25 1.25v3a1.25 1.25 0 0 1 -1.25 1.25h-3a1.25 1.25 0 0 1 -1.25 -1.25v-3a1.25 1.25 0 0 1 1.25 -1.25z'),
    InkGlyphPart.stroke('M12.25 3.5h3a1.25 1.25 0 0 1 1.25 1.25v3a1.25 1.25 0 0 1 -1.25 1.25h-3a1.25 1.25 0 0 1 -1.25 -1.25v-3a1.25 1.25 0 0 1 1.25 -1.25z'),
    InkGlyphPart.stroke('M4.75 11h3a1.25 1.25 0 0 1 1.25 1.25v3a1.25 1.25 0 0 1 -1.25 1.25h-3a1.25 1.25 0 0 1 -1.25 -1.25v-3a1.25 1.25 0 0 1 1.25 -1.25z'),
    InkGlyphPart.stroke('M13.75 11.25v5M11.25 13.75h5'),
  ]),
  /// 模板
  templates(<InkGlyphPart>[
    InkGlyphPart.stroke('M4.5 3.5h11a1.5 1.5 0 0 1 1.5 1.5v10a1.5 1.5 0 0 1 -1.5 1.5h-11a1.5 1.5 0 0 1 -1.5 -1.5v-10a1.5 1.5 0 0 1 1.5 -1.5z'),
    InkGlyphPart.stroke('M3 7.5h14M8.25 7.5v9'),
  ]),
  /// 收起侧栏
  panelToggle(<InkGlyphPart>[
    InkGlyphPart.stroke('M4.25 3.75h11.5a1.5 1.5 0 0 1 1.5 1.5v9.5a1.5 1.5 0 0 1 -1.5 1.5h-11.5a1.5 1.5 0 0 1 -1.5 -1.5v-9.5a1.5 1.5 0 0 1 1.5 -1.5z'),
    InkGlyphPart.stroke('M7.75 3.75v12.5'),
    InkGlyphPart.stroke('M12.75 8.25L11 10l1.75 1.75'),
  ]),
  /// 快捷键
  shortcuts(<InkGlyphPart>[
    InkGlyphPart.stroke('M4.25 5h11.5a1.75 1.75 0 0 1 1.75 1.75v6.5a1.75 1.75 0 0 1 -1.75 1.75h-11.5a1.75 1.75 0 0 1 -1.75 -1.75v-6.5a1.75 1.75 0 0 1 1.75 -1.75z'),
    InkGlyphPart.stroke('M5.5 8.25h1M9.5 8.25h1M13.5 8.25h1'),
    InkGlyphPart.stroke('M6.5 11.75h7'),
  ]),
  /// 帮助
  help(<InkGlyphPart>[
    InkGlyphPart.stroke('M2.75 10a7.25 7.25 0 1 0 14.5 0a7.25 7.25 0 1 0 -14.5 0z'),
    InkGlyphPart.stroke('M7.75 8.1a2.25 2.25 0 1 1 3.35 1.95c-.65.4-1.1.9-1.1 1.6v.4'),
    InkGlyphPart.fill('M9.1 14.1a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0 -1.8 0z'),
  ]),
  /// 全部项目
  projects(<InkGlyphPart>[
    InkGlyphPart.stroke('M2.75 6.25V5A1.5 1.5 0 0 1 4.25 3.5h3.5l1.75 2h6.25a1.5 1.5 0 0 1 1.5 1.5v8A1.5 1.5 0 0 1 15.75 16.5H4.25A1.5 1.5 0 0 1 2.75 15z'),
    InkGlyphPart.stroke('M2.75 8.25h14.5'),
  ]),
  /// 回收站
  trash(<InkGlyphPart>[
    InkGlyphPart.stroke('M3.5 5.5h13'),
    InkGlyphPart.stroke('M8 5.5V4a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v1.5'),
    InkGlyphPart.stroke('M5 5.5l.75 10.6a1.5 1.5 0 0 0 1.5 1.4h5.5a1.5 1.5 0 0 0 1.5-1.4L15 5.5'),
    InkGlyphPart.stroke('M8.5 9v5M11.5 9v5'),
  ]),
  /// 设置
  settings(<InkGlyphPart>[
    InkGlyphPart.stroke('M8.137 4.56L8.51 2.65L11.49 2.65L11.863 4.56A5.75 5.75 0 0 1 12.529 4.836L14.144 3.749L16.251 5.856L15.164 7.471A5.75 5.75 0 0 1 15.44 8.137L17.35 8.51L17.35 11.49L15.44 11.863A5.75 5.75 0 0 1 15.164 12.529L16.251 14.144L14.144 16.251L12.529 15.164A5.75 5.75 0 0 1 11.863 15.44L11.49 17.35L8.51 17.35L8.137 15.44A5.75 5.75 0 0 1 7.471 15.164L5.856 16.251L3.749 14.144L4.836 12.529A5.75 5.75 0 0 1 4.56 11.863L2.65 11.49L2.65 8.51L4.56 8.137A5.75 5.75 0 0 1 4.836 7.471L3.749 5.856L5.856 3.749L7.471 4.836A5.75 5.75 0 0 1 8.137 4.56Z'),
    InkGlyphPart.stroke('M7.5 10a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0z'),
  ]),
  // ---- 画布工具 ----
  /// 选择
  select(<InkGlyphPart>[
    InkGlyphPart.stroke('M5.25 3.25v12.5l3.6-3.4 2.25 4.4 2.05-1-2.2-4.35h4.8z'),
  ]),
  /// 平移
  pan(<InkGlyphPart>[
    InkGlyphPart.stroke('M7.5 10.5V5.25a1.25 1.25 0 0 1 2.5 0V9'),
    InkGlyphPart.stroke('M10 9V3.75a1.25 1.25 0 0 1 2.5 0V9'),
    InkGlyphPart.stroke('M12.5 9V5.25a1.25 1.25 0 0 1 2.5 0v6.5c0 3.2-2.25 5.5-5.25 5.5h-.75c-1.6 0-2.95-.75-3.9-2l-2.6-3.6a1.3 1.3 0 0 1 2.05-1.6l1.95 2.2'),
  ]),
  /// 图像配置
  imageConfig(<InkGlyphPart>[
    InkGlyphPart.stroke('M9.75 3.75H4.75a1.5 1.5 0 0 0-1.5 1.5v10a1.5 1.5 0 0 0 1.5 1.5h10a1.5 1.5 0 0 0 1.5-1.5v-5'),
    InkGlyphPart.stroke('M3.25 14.25l3.5-3.5 3 3 2-2 4.5 4.5'),
    InkGlyphPart.fill('M14.75 2c0.487 1.95 1.3 2.762 3.25 3.25c-1.95 0.487 -2.762 1.3 -3.25 3.25c-0.487 -1.95 -1.3 -2.762 -3.25 -3.25c1.95 -0.487 2.762 -1.3 3.25 -3.25z'),
  ]),
  /// 视频配置
  videoConfig(<InkGlyphPart>[
    InkGlyphPart.stroke('M9.75 3.75H4.75a1.5 1.5 0 0 0-1.5 1.5v10a1.5 1.5 0 0 0 1.5 1.5h10a1.5 1.5 0 0 0 1.5-1.5v-5'),
    InkGlyphPart.stroke('M7.75 8.75v5l4.25-2.5z'),
    InkGlyphPart.fill('M14.75 2c0.487 1.95 1.3 2.762 3.25 3.25c-1.95 0.487 -2.762 1.3 -3.25 3.25c-0.487 -1.95 -1.3 -2.762 -3.25 -3.25c1.95 -0.487 2.762 -1.3 3.25 -3.25z'),
  ]),
  /// 泳道
  lane(<InkGlyphPart>[
    InkGlyphPart.stroke('M3.75 3.5h12.5a1.25 1.25 0 0 1 1.25 1.25v3a1.25 1.25 0 0 1 -1.25 1.25h-12.5a1.25 1.25 0 0 1 -1.25 -1.25v-3a1.25 1.25 0 0 1 1.25 -1.25z'),
    InkGlyphPart.stroke('M3.75 11h12.5a1.25 1.25 0 0 1 1.25 1.25v3a1.25 1.25 0 0 1 -1.25 1.25h-12.5a1.25 1.25 0 0 1 -1.25 -1.25v-3a1.25 1.25 0 0 1 1.25 -1.25z'),
    InkGlyphPart.stroke('M5 6.25h3.5M5 13.75h3.5'),
  ]),
  /// 连线
  link(<InkGlyphPart>[
    InkGlyphPart.stroke('M2.9 15a2.1 2.1 0 1 0 4.2 0a2.1 2.1 0 1 0 -4.2 0z'),
    InkGlyphPart.stroke('M12.9 5a2.1 2.1 0 1 0 4.2 0a2.1 2.1 0 1 0 -4.2 0z'),
    InkGlyphPart.stroke('M7.1 15c3.9 0 1.9-10 5.8-10'),
  ]),
  /// 便签
  note(<InkGlyphPart>[
    InkGlyphPart.stroke('M4.5 3.5h11a1 1 0 0 1 1 1v7.75L12.25 16.5H4.5a1 1 0 0 1-1-1v-11a1 1 0 0 1 1-1z'),
    InkGlyphPart.stroke('M16.5 12.25h-3.25a1 1 0 0 0-1 1v3.25'),
    InkGlyphPart.stroke('M6.5 7.25h7M6.5 10h4.5'),
  ]),
  /// 上传
  upload(<InkGlyphPart>[
    InkGlyphPart.stroke('M10 12.75V3.5'),
    InkGlyphPart.stroke('M6.75 6.75L10 3.5l3.25 3.25'),
    InkGlyphPart.stroke('M3.5 12.5V15A1.5 1.5 0 0 0 5 16.5h10a1.5 1.5 0 0 0 1.5-1.5v-2.5'),
  ]),
  /// 更多
  more(<InkGlyphPart>[
    InkGlyphPart.fill('M3.55 10a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0 -2.4 0z'),
    InkGlyphPart.fill('M8.8 10a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0 -2.4 0z'),
    InkGlyphPart.fill('M14.05 10a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0 -2.4 0z'),
  ]),
  /// 运行
  run(<InkGlyphPart>[
    InkGlyphPart.stroke('M6.25 4.25v11.5L15.5 10z'),
  ]),
  /// 搜索
  search(<InkGlyphPart>[
    InkGlyphPart.stroke('M3.5 8.75a5.25 5.25 0 1 0 10.5 0a5.25 5.25 0 1 0 -10.5 0z'),
    InkGlyphPart.stroke('M12.75 12.75l3.75 3.75'),
  ]),
  /// 文本
  text(<InkGlyphPart>[
    InkGlyphPart.stroke('M4.5 5.5V3.75h11V5.5'),
    InkGlyphPart.stroke('M10 3.75v12.5'),
    InkGlyphPart.stroke('M7.75 16.25h4.5'),
  ]),
  // ---- 视图 ----
  /// 放大
  zoomIn(<InkGlyphPart>[
    InkGlyphPart.stroke('M10 4.5v11M4.5 10h11'),
  ]),
  /// 缩小
  zoomOut(<InkGlyphPart>[
    InkGlyphPart.stroke('M4.5 10h11'),
  ]),
  /// 适应全部
  fit(<InkGlyphPart>[
    InkGlyphPart.stroke('M3.5 7.5V5A1.5 1.5 0 0 1 5 3.5h2.5M12.5 3.5H15A1.5 1.5 0 0 1 16.5 5v2.5M16.5 12.5V15a1.5 1.5 0 0 1-1.5 1.5h-2.5M7.5 16.5H5A1.5 1.5 0 0 1 3.5 15v-2.5'),
  ]),
  /// 小地图
  minimap(<InkGlyphPart>[
    InkGlyphPart.stroke('M4 4h12a1.5 1.5 0 0 1 1.5 1.5v9a1.5 1.5 0 0 1 -1.5 1.5h-12a1.5 1.5 0 0 1 -1.5 -1.5v-9a1.5 1.5 0 0 1 1.5 -1.5z'),
    InkGlyphPart.stroke('M10 8.5h4.25a0.75 0.75 0 0 1 0.75 0.75v3.5a0.75 0.75 0 0 1 -0.75 0.75h-4.25a0.75 0.75 0 0 1 -0.75 -0.75v-3.5a0.75 0.75 0 0 1 0.75 -0.75z'),
  ]),
  // ---- 通知与状态 ----
  /// 通知
  bell(<InkGlyphPart>[
    InkGlyphPart.stroke('M5.5 13.25V9a4.5 4.5 0 0 1 9 0v4.25l1.25 1.75H4.25z'),
    InkGlyphPart.stroke('M8.5 17.25a1.6 1.6 0 0 0 3 0'),
  ]),
  /// 完成
  success(<InkGlyphPart>[
    InkGlyphPart.stroke('M4.75 10.5l3.25 3.25 7.25-7.5'),
  ]),
  /// 失败
  error(<InkGlyphPart>[
    InkGlyphPart.stroke('M6 6l8 8M14 6l-8 8'),
  ]),
  /// 警告
  warning(<InkGlyphPart>[
    InkGlyphPart.stroke('M10 4.75v6.5'),
    InkGlyphPart.fill('M8.95 14.75a1.05 1.05 0 1 0 2.1 0a1.05 1.05 0 1 0 -2.1 0z'),
  ]),
  /// 提示
  info(<InkGlyphPart>[
    InkGlyphPart.stroke('M10 8.75v6.5'),
    InkGlyphPart.fill('M8.95 5.25a1.05 1.05 0 1 0 2.1 0a1.05 1.05 0 1 0 -2.1 0z'),
  ]),
  /// 进行中
  progress(<InkGlyphPart>[
    InkGlyphPart.stroke('M10 3.5a6.5 6.5 0 1 1-6.5 6.5'),
  ]),
  /// 撤销
  undo(<InkGlyphPart>[
    InkGlyphPart.stroke('M7.5 4.75L4.25 8l3.25 3.25'),
    InkGlyphPart.stroke('M4.25 8h7.5a4.25 4.25 0 0 1 0 8.5H9.25'),
  ]),
  /// 关闭
  close(<InkGlyphPart>[
    InkGlyphPart.stroke('M6.5 6.5l7 7M13.5 6.5l-7 7'),
  ]),
  /// 提示音
  sound(<InkGlyphPart>[
    InkGlyphPart.stroke('M3.5 8v4h3l4 3.25V4.75L6.5 8z'),
    InkGlyphPart.stroke('M13.25 7.25a3.75 3.75 0 0 1 0 5.5'),
    InkGlyphPart.stroke('M15.25 5.25a6.5 6.5 0 0 1 0 9.5'),
  ]),
  /// 静音
  soundOff(<InkGlyphPart>[
    InkGlyphPart.stroke('M3.5 8v4h3l4 3.25V4.75L6.5 8z'),
    InkGlyphPart.stroke('M13.5 8l4 4M17.5 8l-4 4'),
  ]),
  /// 已过期
  dirty(<InkGlyphPart>[
    InkGlyphPart.stroke('M10 3.25L17.25 16H2.75z'),
    InkGlyphPart.stroke('M10 8v3.75'),
    InkGlyphPart.fill('M9.1 13.6a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0 -1.8 0z'),
  ]),
  /// 固定
  pin(<InkGlyphPart>[
    InkGlyphPart.stroke('M7.25 3.25h5.5'),
    InkGlyphPart.stroke('M8.5 3.25v4.5l-2.75 3v1.5h8.5v-1.5l-2.75-3v-4.5'),
    InkGlyphPart.stroke('M10 12.25V17'),
  ]),
  /// 历史
  history(<InkGlyphPart>[
    InkGlyphPart.stroke('M3.6 10a6.4 6.4 0 1 0 1.9-4.55'),
    InkGlyphPart.stroke('M3.5 3.5v2.75h2.75'),
    InkGlyphPart.stroke('M10 6.75V10l2.25 1.5'),
  ]),
  /// 导出
  export(<InkGlyphPart>[
    InkGlyphPart.stroke('M11.75 3.5h4.75v4.75'),
    InkGlyphPart.stroke('M16.5 3.5l-7 7'),
    InkGlyphPart.stroke('M14.5 11.5V15a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 15V7A1.5 1.5 0 0 1 5 5.5h3.5'),
  ]),
  /// 序列
  sequence(<InkGlyphPart>[
    InkGlyphPart.stroke('M4 5h12a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1 -1.5 1.5h-12a1.5 1.5 0 0 1 -1.5 -1.5v-7a1.5 1.5 0 0 1 1.5 -1.5z'),
    InkGlyphPart.stroke('M7.5 5v10M12.5 5v10'),
  ]),
  /// 渲染队列
  queue(<InkGlyphPart>[
    InkGlyphPart.stroke('M10 3.25l7 3.5-7 3.5-7-3.5z'),
    InkGlyphPart.stroke('M3 10.25l7 3.5 7-3.5'),
    InkGlyphPart.stroke('M3 13.75l7 3.5 7-3.5'),
  ]);

  const InkGlyph(this.parts);

  final List<InkGlyphPart> parts;
}
