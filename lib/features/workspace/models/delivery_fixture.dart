// 交付面板静态复刻的假数据（Timeline 稿上半右栏）。
//
// 全部取自稿 markup 的 props 数组与行内文案，逐字照抄——标点都是稿上的原码位：
// 全角括号 U+FF08/U+FF09、全角逗号 U+FF0C、句号 U+3002、间隔号 U+00B7、
// 正负号 U+00B1、下拉三角 U+25BC。接线时这些串进 ARB，别在这里改写。
import 'dart:ui' show Size;

/// 设置行的三种形态（稿 markup 的 isSelect / isMono / isToggle）。
enum DvRowKind {
  /// 值 + 右端 ▼（12px 无衬线）。
  select,

  /// 可编辑的等宽文本，**没有** ▼（时间码起点 / 命名两行）。
  mono,

  /// 26×14 胶囊开关 + 说明文字；说明是「注解」不是「值」，色比下拉行暗两档。
  toggle,
}

/// 一行设置。
class DvRow {
  const DvRow({
    required this.label,
    required this.value,
    required this.kind,
    this.on = false,
  });

  final String label;
  final String value;
  final DvRowKind kind;

  /// 仅 [DvRowKind.toggle] 有意义。
  final bool on;
}

/// 一个可折叠分组。稿上三个组都是展开态，折叠态没画。
class DvGroup {
  const DvGroup({required this.title, required this.rows});

  final String title;
  final List<DvRow> rows;
}

class DeliveryFixture {
  DeliveryFixture._();

  /// 面板 border-box：稿 `width:320` content + 1px `border-left`。
  ///
  /// **高 608 稿里没写**，是上半区 `flex:1` 的余量（屏内容 998 =
  /// 菜单 31 + 工作区标签 35 + 上半 609 + 序列 300 + 状态栏 23）。
  static const Size designSize = Size(321, 608);

  /// 三层：页签条 29 + 滚动区 520 + 底部条 59。
  static const double tabsHeight = 29;
  static const double scrollHeight = 520;
  static const double footerHeight = 59;

  /// 每个页签 48 宽（`padding:0 12` + 2 CJK × 12）。当前页是**顶部** 1px 琥珀线，
  /// 不是底部下划线——底色与面板连成一片。
  static const double tabWidth = 48;
  static const List<String> tabs = <String>['交付', '片段', '历史'];
  static const int currentTab = 0;

  // -------------------------------------------------------------- 目标软件块
  static const String targetLabel = '目标软件';

  /// 四段等分 `flex:1` = 73.5（小数，不是内容宽）。最后一段也有 border-right，
  /// 与外框边叠成 2px。
  static const List<String> targets = <String>[
    'Resolve',
    'Premiere',
    'Final Cut',
    '剪映',
  ];
  static const int currentTarget = 0;

  static const String targetHint = '默认 EDL CMX3600（PRD P1），FCPXML 待支持。';

  // ---------------------------------------------------------------- 三个分组
  static const List<DvGroup> groups = <DvGroup>[
    DvGroup(
      title: '工程文件',
      rows: <DvRow>[
        DvRow(label: '格式', value: 'EDL CMX3600', kind: DvRowKind.select),
        DvRow(label: '帧率', value: '24 fps · 与序列一致', kind: DvRowKind.select),
        DvRow(label: '时间码起点', value: '01:00:00:00', kind: DvRowKind.mono),
        DvRow(label: '轨道', value: 'V1 视频 · A1 音频分离', kind: DvRowKind.select),
      ],
    ),
    DvGroup(
      title: '媒体',
      rows: <DvRow>[
        DvRow(label: '手柄', value: '±12 帧（0.5 s）', kind: DvRowKind.select),
        DvRow(label: '命名', value: '{序号3位}_{镜头名}.mp4', kind: DvRowKind.mono),
        DvRow(label: '范围', value: '仅入出点 + 手柄', kind: DvRowKind.select),
        DvRow(label: '转码', value: '保持源 · 不重编码', kind: DvRowKind.select),
        DvRow(
          label: '相对路径',
          value: '开启（随文件夹搬迁）',
          kind: DvRowKind.toggle,
          on: true,
        ),
      ],
    ),
    DvGroup(
      title: '标记与元数据',
      rows: <DvRow>[
        DvRow(
          label: '断点 → 标记',
          value: '导入为时间线标记',
          kind: DvRowKind.toggle,
          on: true,
        ),
        DvRow(
          label: '镜头语言',
          value: '写入片段备注（景别·运镜）',
          kind: DvRowKind.toggle,
          on: true,
        ),
        DvRow(
          label: '提示词',
          value: '写入 metadata.json',
          kind: DvRowKind.toggle,
        ),
        DvRow(label: '占位镜头', value: '导出为空隙 + 标记', kind: DvRowKind.select),
      ],
    ),
  ];

  // ---------------------------------------------------------------- 底部条
  static const String outputLabel = '输出';

  /// 等宽。
  static const String outputPath = '~/InkFrame/exports/山径破晓_v03/';
  static const String includeLabel = '包含';

  /// **无衬线**，不是等宽——和上一行的字体不一样，别顺手统一。
  static const String includeList = '8 mp4 · 1 edl · metadata.json';
}
