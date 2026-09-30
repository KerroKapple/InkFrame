// 批量结果 + 角色静态复刻的数据形状 + 稿上原文
// （docs/design/handoff-2026-09/InkFrame Batch and Characters.html）。
//
// 与 sequence_fixture / palette_fixture 同例：手写 const 值对象，只在呈现层被读；
// 假数据必须是稿上原文。接线后本文件整体删除。
//
// 【坐标系】稿是一张规格书长图，四个块散落在上面。复刻屏用【稿上的绝对坐标】摆块，
// 这样参考图与复刻图可以用同一组 (x,y,w,h) 裁剪，不会因为两边布局不同而错位。
// 坐标是从 2600×1800 的 headless 渲染图上逐块量出来的（占用像素外接框）。
//
// 【content-box】稿全文没有 box-sizing reset，尺寸一律是 content + border：
// 面板 300+1×2 = 302、浮层 1080+1×2 = 1082、编辑框 560+1×2 = 562。
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

/// slot 的四种状态（稿上画全了四种；仓库的 SlotStatuses 另有 cancelled，稿未画）。
enum BcSlotState { success, promoted, error, generating }

/// 一个批量 slot。检查器内联与对比浮层是同一份数据的两个投影。
@immutable
class BcSlot {
  const BcSlot({
    required this.index,
    required this.state,
    required this.seed,
    this.gradient,
  });

  /// 1 起的槽位号（稿：检查器写 `#1`，浮层写 `slot #1`）。
  final int index;
  final BcSlotState state;

  /// 稿上原文；生成中那格是 em dash（真实 seed 60922 不上屏）。
  final String seed;

  /// InkPalette.thumbPlaceholderGradients 下标；null = 纯 thumbFill（失败 / 生成中）。
  final int? gradient;
}

/// 角色库列表的一行。
@immutable
class BcCharacter {
  const BcCharacter({required this.name, required this.meta, this.selected = false, required this.gradient});
  final String name;

  /// 稿上原文 `{N} 张参考图 · {M} 处引用`；M=0 时后半段整段换成「未引用」。
  final String meta;
  final bool selected;
  final int gradient;
}

/// 编辑框里的一张参考图。
@immutable
class BcReference {
  const BcReference({required this.index, required this.caption, required this.gradient});
  final int index;

  /// 备注。PLAN §P4 明写「无字段、不做」——静态复刻照稿画，接线时只留序号。
  final String caption;
  final int gradient;
}

abstract final class BatchFixture {
  /// 复刻屏画布 = 稿上四个块的外接范围 + 48 右下留白（稿根 padding 也是 48）。
  static const Size designSize = Size(1504, 1285);

  // ---- 块在稿上的绝对位置（裁图与复刻共用；量自 2600×1800 渲染图）----
  /// 01 检查器内联 · 批量结果（300 content + 1px 边 ×2）。
  /// 高 408 是量出来的：稿的 1px #0F0F0F 边框与页底 #141414 只差 5 级，
  /// 按亮度阈值找外接框会把它当背景漏掉——所以边框列是逐像素profile 出来的。
  static const Offset inspectorAt = Offset(48, 210);
  static const Size inspectorSize = Size(302, 408);

  /// 02 对比浮层（1080 content + 1px 边 ×2；高度是 content-box 逐层折算 + 实测）。
  static const Offset overlayAt = Offset(374, 210);
  static const Size overlaySize = Size(1082, 321);

  /// 03b 角色库（稿上是 260 宽的演示卡；接线后落在 241 的真实左栏里）。
  static const Offset libraryAt = Offset(374, 695);
  static const Size librarySize = Size(262, 311);

  /// 03c 编辑角色框（560 content + 1px 边 ×2）。
  static const Offset editorAt = Offset(660, 695);
  static const Size editorSize = Size(562, 542);

  // ---------------------------------------------------------------- 01 检查器
  static const List<String> inspectorTabs = <String>['属性', '状态', '历史'];
  static const int inspectorActiveTab = 0;
  static const String nodeTitle = '镜头 05 · 松林';
  static const String nodeSubtitle = 'image / result · flux-pro-1.1';
  static const String gridTitle = '批量结果';
  static const String gridCount = '4 slot';
  static const String gridCompare = '对比';

  /// 检查器格里的动作词（图下方右侧，9px mono，靠颜色区分，无按钮盒）。
  static const String actionPromote = '转正';
  static const String actionCurrent = '当前';
  static const String actionRerun = '重跑';
  static const String actionCancel = '取消';

  /// 检查器格里的覆盖层文案。
  static const String badgeChosen = '已选';
  static const String overlayGenerating = '生成中';
  static const String overlayBlocked = '内容被拦截';

  static const String btnRerunFailed = '重跑失败 slot';
  static const String btnDeriveAll = '全部派生节点';
  static const String inspectorFootnote = '转正即把该 slot 写为节点产物；其余 slot 保留在画廊，可随时改选。';

  // ---------------------------------------------------------------- 02 浮层
  static const String overlayTitle = '批量结果 · 镜头 05 · 松林';
  static const String overlayMeta = 'flux-pro-1.1 · 1024×576 · job 7c1e';
  static const String overlayModeSideBySide = '并排';
  static const String overlayModeStacked = '叠加对比';
  static const String overlayEsc = 'Esc';

  static const String slotPrefix = 'slot ';
  static const String badgeCurrentArtifact = '当前产物';
  static const String seedLabel = '种子';
  static const String overlayGeneratingPct = '生成中 45%';
  static const double overlayProgress = 0.45;
  static const String errorCode = 'content_filtered';

  static const String btnSetArtifact = '设为产物';
  static const String btnRerunSlot = '重跑此 slot';
  static const String btnRerunSeedGlyph = '⎘';
  static const String overlayHint = '←→ 切换 · ↵ 转正 · ⎘ 以该种子重跑';
  static const String btnSaveAllToGallery = '全部存入画廊';
  static const String btnDone = '完成';

  /// 四格数据，检查器与浮层共用（稿内 renderVals() 的 compare 数组）。
  static const List<BcSlot> slots = <BcSlot>[
    BcSlot(index: 1, state: BcSlotState.promoted, seed: '41207', gradient: 0),
    BcSlot(index: 2, state: BcSlotState.success, seed: '88316', gradient: 1),
    BcSlot(index: 3, state: BcSlotState.error, seed: '15043'),
    BcSlot(index: 4, state: BcSlotState.generating, seed: '—'),
  ];

  // ---------------------------------------------------------------- 03b 角色库
  static const List<String> libraryTabs = <String>['画布', '资产', '角色'];
  static const int libraryActiveTab = 2;
  static const String libraryTabsTrailing = '新增';
  static const String libraryHint = '项目级 · 跨画布复用';
  static const String libraryNewCharacter = '新建角色';
  static const String libraryMenuGlyph = '⋯';
  static const String libraryFootnote = '⋯ 菜单：编辑、改名、删除。检查器角色区加一个「管理」链接指到这里。';

  static const List<BcCharacter> characters = <BcCharacter>[
    BcCharacter(name: '行者', meta: '4 张参考图 · 6 处引用', selected: true, gradient: 4),
    BcCharacter(name: '少年', meta: '2 张参考图 · 3 处引用', gradient: 3),
    BcCharacter(name: '山中老者', meta: '1 张参考图 · 未引用', gradient: 7),
  ];

  // ---------------------------------------------------------------- 03c 编辑框
  static const String editorTitle = '编辑角色';
  static const String editorBadge = '提议新增';
  static const String editorClose = '✕';
  static const String fieldName = '名称';
  static const String fieldNameValue = '行者';
  static const String fieldDescription = '描述';
  static const String fieldDescriptionValue = '中年男性，粗布行囊，灰褐色斗篷，左颊有旧疤';
  static const String descriptionHint = '描述随参考图一同注入提示词，用来补图片传达不了的细节。';
  static const String fieldReferences = '参考图';
  static const String referencesHint = '顺序即注入次序 · 拖动重排';
  static const String referencesCount = '4 / 6';
  static const String referencesAdd = '添加';
  static const String referencesPathHint = '存为 characters/{uuid}.ext（项目相对路径），随项目包一同导出。';
  static const String fieldReferencedBy = '被引用';
  static const String editorFootnote = '改动影响 6 个引用节点的后续生成';
  static const String btnCancel = '取消';
  static const String btnSave = '保存';

  static const List<BcReference> references = <BcReference>[
    BcReference(index: 1, caption: '正面', gradient: 4),
    BcReference(index: 2, caption: '侧脸', gradient: 5),
    BcReference(index: 3, caption: '背影', gradient: 7),
    BcReference(index: 4, caption: '服装细节', gradient: 3),
  ];

  /// 被引用节点 chip（稿：16×10 色块 + 11px 文字）。
  static const List<String> referencedBy = <String>['镜头 02', '镜头 05', '镜头 06', '镜头 09'];
  static const List<int> referencedByGradients = <int>[0, 1, 4, 0];
}
