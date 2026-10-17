// 设计 token：三主题变体 + 间距/圆角/阴影/动效原值。
//
// 这是整个应用唯一允许出现原始色值 / 数值的文件。所有 widget 与组件必须
// 通过 InkSpacing / InkRadius / InkShadow / InkTypography / context.inkColors 消费。
//
// 色彩体系（docs/design/handoff-2026-09/README.md §Design Tokens）：
//   - 中性灰是唯一体系：六档 surface + 六档描边 + 六档 fg，全部无色相偏移。
//   - 强调色只有一个：琥珀。语义色（success / danger / audio*）只用于状态文字
//     与小图标，不做容器底色。
//   - dark 值直接取 README；light / highContrast 是同一语义的推导值，不自行调色。
//
// 三态变体：dark / light / highContrast。highContrast 是 A11y §20.1 基线的
// 开关目标；彩底前景（onAccent × accent）与正文（fg2 × surface3）的 AA ≥4.5
// 由 tokens_test 对三变体逐一锁定。
import 'package:flutter/widgets.dart';

/// 启动阶段（main 进入 runApp 前）唯一可暴露的原始色板常量入口。
///
/// 仅暴露在 BuildContext 可用之前必须使用的颜色（如 window_manager 背景），
/// 其他场景请走 `context.inkColors`。每个常量必须等于对应主题工厂的值，
/// 由 tokens_test 守护一致性。
class InkPalette {
  InkPalette._();

  /// 启动时 window_manager 背景色；必须等于 `InkColors.dark().surface0`。
  static const Color surface0Dark = Color(0xFF141414);

  /// 画布连线自定义色候选（设置页色板；「主题默认」档另行呈现，不在列）。
  static const List<Color> canvasEdgeColorChoices = <Color>[
    Color(0xFFE8A87C), // 琥珀
    Color(0xFF7CB8E8), // 天蓝
    Color(0xFF8FD694), // 青绿
    Color(0xFFE87C9E), // 桃粉
    Color(0xFFB89CE8), // 藤紫
    Color(0xFFE8D57C), // 芥黄
  ];

  /// 画布卡片背景自定义色候选（暗色系中性偏色面，保证前景可读）。
  static const List<Color> canvasCardColorChoices = <Color>[
    Color(0xFF2A2320), // 暖炭
    Color(0xFF20262E), // 蓝灰
    Color(0xFF212A22), // 墨绿
    Color(0xFF2C2129), // 暗紫
    Color(0xFF3A3330), // 浅暖
    Color(0xFF262626), // 纯中性
  ];
}

/// 语义化色板：widget 永远读这个接口，token 工厂决定具体值。
@immutable
class InkColors {
  const InkColors._({
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.surface4,
    required this.surface5,
    required this.borderStrong,
    required this.borderSubtle,
    required this.outline,
    required this.control,
    required this.controlStrong,
    required this.overlayBorder,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.fg4,
    required this.fg5,
    required this.fg6,
    required this.accent,
    required this.accentHover,
    required this.onAccent,
    required this.accentWash,
    required this.accentWashBorder,
    required this.success,
    required this.danger,
    required this.audioFill,
    required this.audioBorder,
    required this.audioFg,
    required this.scrim,
    required this.canvasGrid,
    required this.laneDivider,
    required this.thumbFill,
    required this.edgeFirstFrame,
    required this.edgeLastFrame,
    required this.edgeReference,
  });

  /// 深色主题（默认）——README dark 列原值。
  factory InkColors.dark() => const InkColors._(
        surface0: InkPalette.surface0Dark,
        surface1: Color(0xFF1A1A1A),
        surface2: Color(0xFF1D1D1D),
        surface3: Color(0xFF232323),
        surface4: Color(0xFF262626),
        surface5: Color(0xFF2E2E2E),
        borderStrong: Color(0xFF0F0F0F),
        borderSubtle: Color(0xFF1F1F1F),
        outline: Color(0xFF2C2C2C),
        control: Color(0xFF3A3A3A),
        controlStrong: Color(0xFF3F3F3F),
        overlayBorder: Color(0xFF4A4A4A),
        fg1: Color(0xFFE8E8E8),
        fg2: Color(0xFFD6D6D6),
        fg3: Color(0xFFC8C8C8),
        fg4: Color(0xFF9E9E9E),
        fg5: Color(0xFF8A8A8A),
        fg6: Color(0xFF6B6B6B),
        accent: Color(0xFFC9A85B),
        accentHover: Color(0xFFD8B96C),
        // 琥珀底上的文字必须是深色，禁止白色。
        onAccent: Color(0xFF1D1D1D),
        accentWash: Color(0xFF2A2318),
        accentWashBorder: Color(0xFF6B5A38),
        success: Color(0xFF7FB069),
        // 用户改口（2026-09-22）：README 的 #B04030 在 #232323 上只有 2.9:1，改 #D25A4A（约 4.6:1）；
        // light / hc 不动。
        danger: Color(0xFFD25A4A),
        audioFill: Color(0xFF22301F),
        audioBorder: Color(0xFF3A5334),
        audioFg: Color(0xFF8FB07E),
        scrim: Color(0x8C0A0A0A),
        canvasGrid: Color(0xFF222222),
        laneDivider: Color(0xFF2A2A2A),
        thumbFill: Color(0xFF202020),
        edgeFirstFrame: Color(0xFF8FD694),
        edgeLastFrame: Color(0xFFE87C9E),
        edgeReference: Color(0xFF7CB8E8),
      );

  /// 浅色主题——同一语义、反向 ramp；accent 压暗保对比。
  factory InkColors.light() => const InkColors._(
        surface0: Color(0xFFE4E4E4),
        surface1: Color(0xFFF4F4F4),
        surface2: Color(0xFFF8F8F8),
        surface3: Color(0xFFEFEFEF),
        surface4: Color(0xFFFFFFFF),
        // 比 surface3 更深：浅色主题的选中态靠压暗，不靠提亮。
        surface5: Color(0xFFE2E2E2),
        borderStrong: Color(0xFFC8C8C8),
        borderSubtle: Color(0xFFE6E6E6),
        outline: Color(0xFFD4D4D4),
        control: Color(0xFFC4C4C4),
        controlStrong: Color(0xFFB8B8B8),
        overlayBorder: Color(0xFFA8A8A8),
        fg1: Color(0xFF1A1A1A),
        fg2: Color(0xFF2E2E2E),
        fg3: Color(0xFF444444),
        fg4: Color(0xFF5E5E5E),
        fg5: Color(0xFF767676),
        fg6: Color(0xFF8E8E8E),
        accent: Color(0xFF8C6A30),
        accentHover: Color(0xFF7A5C28),
        onAccent: Color(0xFFFFFFFF),
        accentWash: Color(0xFFF3ECDC),
        accentWashBorder: Color(0xFFC9B689),
        success: Color(0xFF3E7A34),
        danger: Color(0xFFA03028),
        audioFill: Color(0xFFE3EEDF),
        audioBorder: Color(0xFFA9C49E),
        audioFg: Color(0xFF3E6B34),
        scrim: Color(0x8C0A0A0A),
        canvasGrid: Color(0xFFECECEC),
        laneDivider: Color(0xFFDADADA),
        thumbFill: Color(0xFFF0F0F0),
        edgeFirstFrame: Color(0xFF2F7D4A),
        edgeLastFrame: Color(0xFFB23A68),
        edgeReference: Color(0xFF2D6AA6),
      );

  /// 高对比度变体（A11y §20.1）——基于 dark：surface 塌到两档，描边纯白，
  /// 前景纯白 / 纯黑。
  factory InkColors.highContrast() => const InkColors._(
        surface0: Color(0xFF000000),
        surface1: Color(0xFF000000),
        surface2: Color(0xFF000000),
        surface3: Color(0xFF0A0A0A),
        surface4: Color(0xFF0A0A0A),
        surface5: Color(0xFF2A2A2A),
        // HC 下分隔线不可能比纯白更强——六个描边槽同值是刻意的，不是遗漏。
        borderStrong: Color(0xFFFFFFFF),
        borderSubtle: Color(0xFFFFFFFF),
        outline: Color(0xFFFFFFFF),
        control: Color(0xFFFFFFFF),
        controlStrong: Color(0xFFFFFFFF),
        overlayBorder: Color(0xFFFFFFFF),
        fg1: Color(0xFFFFFFFF),
        fg2: Color(0xFFFFFFFF),
        fg3: Color(0xFFFFFFFF),
        fg4: Color(0xFFD0D0D0),
        fg5: Color(0xFFD0D0D0),
        fg6: Color(0xFFD0D0D0),
        accent: Color(0xFFFFD060),
        accentHover: Color(0xFFFFE08A),
        onAccent: Color(0xFF000000),
        accentWash: Color(0xFF332A10),
        accentWashBorder: Color(0xFFFFD060),
        success: Color(0xFF6BFF6B),
        danger: Color(0xFFFF6B6B),
        audioFill: Color(0xFF0A1A0A),
        audioBorder: Color(0xFF6BFF6B),
        audioFg: Color(0xFF6BFF6B),
        scrim: Color(0x8C0A0A0A),
        canvasGrid: Color(0xFF1A1A1A),
        laneDivider: Color(0xFFFFFFFF),
        thumbFill: Color(0xFF0A0A0A),
        edgeFirstFrame: Color(0xFF6BFFB0),
        edgeLastFrame: Color(0xFFFF8AC8),
        edgeReference: Color(0xFF7CC8FF),
      );

  // ---- surface：越大越"抬升"（light 变体的 surface5 例外，见工厂注释）----
  final Color surface0; // 窗口外底（仅画布模式 / 浮层遮罩下可见）
  final Color surface1; // 中央工作区
  final Color surface2; // 应用主体默认底
  final Color surface3; // 侧栏 / 底栏面板
  final Color surface4; // 菜单栏 / 状态栏 / 节点头部 / 浮层容器底
  final Color surface5; // 选中行 / 激活标签底 / 次级按钮悬停

  // ---- 描边 ----
  final Color borderStrong; // 面板之间、标题栏下沿
  final Color borderSubtle; // 列表行间
  final Color outline; // 缩略图 / 图区默认描边
  final Color control; // 输入底线 / 分组框 / 分隔竖线
  final Color controlStrong; // 次级按钮边框
  final Color overlayBorder; // 浮层边框

  // ---- 前景 ----
  final Color fg1; // 标题 / 选中项
  final Color fg2; // 正文
  final Color fg3; // 菜单项 / 未选中标签
  final Color fg4; // 字段标签
  final Color fg5; // 元信息
  final Color fg6; // 占位 / 快捷键提示

  // ---- 强调（唯一）----
  final Color accent; // 选中 / 主操作 / 进行中；警告态与其同色，用「!」字符区分
  final Color accentHover;
  final Color onAccent; // 琥珀底上的文字（深色，禁止白色）
  final Color accentWash; // 提示条底 / 选中 Provider 行
  final Color accentWashBorder; // 提示条内次级按钮边

  // ---- 语义（只做文字与小图标，不做容器底色）----
  final Color success; // 已验证 ✓
  final Color danger; // 失败 ✕ / 缺失标记 / 待补菱形——文字与小图标，不做容器底色

  // ---- 序列 A1 音频轨 ----
  final Color audioFill;
  final Color audioBorder;
  final Color audioFg;

  /// 浮层遮罩 rgba(10,10,10,0.55)：模态 barrier 与缩略图上的渐变压暗共用。
  final Color scrim;

  // ---- 画布专用（Workspace v2 稿：24px 网格线 / 泳道上下边 / 空图区底）----
  final Color canvasGrid;
  final Color laneDivider;
  final Color thumbFill;

  // ---- 连线语义（画布重设计稿 › 画布交互）：颜色之外还靠线型和标签区分，色弱也分得清 ----
  // 叙事线用 fg4、产出线用 fg6，不另设色。三色对画布底（surface1）都 ≥ 3:1（图形对比度）。
  final Color edgeFirstFrame; // 首帧：实线 + 「首帧」标签
  final Color edgeLastFrame; // 尾帧：实线 + 「尾帧」标签
  final Color edgeReference; // 参考：虚线 + 「参考」标签
}

/// 间距（8 的倍数主刻度 + 半阶档位）。
///
/// 半阶档位（s10/s12/s14/s18/s28）覆盖设计稿的光学微调值，
/// 禁止在 widget 内对 token 做加减算术拼间距。
class InkSpacing {
  InkSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  // 半阶档位
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s18 = 18;
  static const double s20 = 20; // Studio 项目区内边距 / 引导条左右
  static const double s22 = 22; // Studio 恢复条到网格
  static const double s26 = 26; // 画廊筛选行的缩进
  static const double s28 = 28;
  // 光学微调小档（2/3/6）：覆盖 chip/inspector/toolbar 的非 8 倍数细间距
  static const double s2 = 2;
  static const double s3 = 3;
  static const double s6 = 6;
  // P4 批量 / 角色稿的细档：5 = slot 元信息行 gap 与「已选」徽标内边距；
  // 7 = 浮层「当前产物」徽标内边距；9 = 角色库行的缩略图↔文字↔⋯ 两处 gap。
  static const double s5 = 5;
  static const double s7 = 7;
  static const double s9 = 9;
}

/// 圆角。README 四档：2（缩略图内格）/ 3（按钮、输入、片段）/ 4（图区、分组框）/ 6（浮层）。
class InkRadius {
  InkRadius._();
  static const double s1 = 1; // 方点 / 缩略图占位框
  static const double xs = 2; // 缩略图内格 / 细进度条
  static const double s3 = 3; // 按钮 / 输入 / 片段
  static const double sm = 4; // 图区 / 分组框
  static const double s5 = 5; // 图区 outline：画在 4px 圆角盒子外一圈时的外径
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 999;
  static const double bento = 10; // bento 卡片圆角
  static const double bentoBtn = 6; // 浮层 / bento 按钮圆角
}

/// 阴影。节点无阴影（改为 1px 描边）；浮层用 README 的 0 24px 64px rgba(0,0,0,0.6)。
class InkShadow {
  InkShadow._();

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(
      color: Color(0x99000000),
      blurRadius: 64,
      offset: Offset(0, 24),
    ),
  ];

  /// 画布底部提示词条：0 10px 30px rgba(0,0,0,0.5)。
  static const List<BoxShadow> elevated = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 30,
      offset: Offset(0, 10),
    ),
  ];
}

/// 图标尺寸（图标集 v1，见 theme/icons/ink_glyph.dart）。
///
/// 路径画在 [grid] 边长的网格上，按目标尺寸等比缩放；描边宽度 [gridStroke] 随之一起缩
/// （20 → 1.5，16 → 1.2），和设计稿里 SVG 的缩放方式一致。
class InkIconSize {
  InkIconSize._();
  static const double s11 = 11; // 状态栏任务胶囊里的转圈
  static const double xs = 13; // 行内小图标：筛选框搜索、缩略占位里的类型图标、进行中转圈
  static const double s14 = 14; // 行尾状态图标（完成 ✓）
  static const double sm = 16; // 列表行、紧凑工具格、状态栏
  static const double md = 20; // 导航条、工具条（网格原尺寸）

  /// 路径数据所在网格的边长。
  static const double grid = 20;

  /// 网格原尺寸下的描边宽度。
  static const double gridStroke = 1.5;
}

/// 画布浮动工具条（画布重设计稿 › 画布页 · 改后：舞台顶部居中）。内边距 / 键间距 / 圆角 / 阴影
/// 仍走 InkSpacing / InkRadius / InkShadow。
///
/// 两个 inset 是舞台上其它浮层给工具条 / 缩放条让出的位置——写成令牌而不是在 widget 里拿
/// 「top 12 + 条高」现算（禁止对 token 做加减拼间距）。改了工具条或缩放条的尺寸，这里跟着改。
class InkToolbarSize {
  InkToolbarSize._();
  static const double button = 32; // 工具键边长
  static const double separatorHeight = 20; // 组间分隔竖线高

  /// 舞台顶部浮层（错误横幅 / 连线提示 / 多选计数）的 top：工具条 top 12 + 条高 42
  /// （32 键 + 2×4 内边距 + 2×1 边）+ 10 间隙。
  static const double stageTopInset = 64;

  /// 舞台左下浮层（泳道工具栏）的 bottom：缩放条 bottom 12 + 条高 26 + 10 间隙。
  static const double stageBottomInset = 48;

  /// 舞台左下那一簇（缩放条 + 叠在它上面的泳道工具栏）从舞台左沿量起占的宽度，含右侧一档间隙：
  /// 底部居中的提示词条居中时会压到这一段，就改在右边剩下的那段里居中（prompt_bar_width.dart）。
  /// 由 canvas_screen_layout_test 守着：两条的右沿 + 12 都得落在这里面，改了它们的宽度这里跟着改。
  static const double stageBottomLeftReserve = 176;

  /// 底部提示词条的 bottom：条子底边离舞台底。
  static const double promptBarBottom = 16;

  /// 提示词条显示时，「适应全部 / 适应选中」底部除了条子自己的高度还要让出的那一截：条子 bottom 16 + 10 间隙
  /// （canvas_tool_actions.canvasFitInsets）。条子高度随提示词行数变，不是令牌，运行时量。
  static const double promptBarClearance = 26;

  /// 左下缩放条的外宽（定宽：百分比从 10% 变到 300% 时整条不伸缩）：外框 1 + 缩小格 27 + 百分比格 46
  /// + 放大格 27 + 适应格 41 + 外框 1。格宽 27 / 41 写在 canvas_zoom_bar.dart 的 `_ZoomCell(width: ...)`
  /// 里——改了它们这里跟着改（canvas_zoom_bar_test 量整条宽，canvas_screen_layout_test 量让位线）。
  static const double zoomBarWidth = 143;

  /// 缩放条中间百分比读数格的定宽：装得下最宽的「300%」（等宽 11 号四个字 ≈ 27）+ 左右各 10 内边距，
  /// 取整到 46（原来按文字宽 + s10 内边距撑开，比例一变整条就跟着伸缩）。
  static const double zoomBarPercentCell = 46;
}

/// 画布轻提示胶囊（GapsCanvas 稿 ›「画布轻提示胶囊」：舞台底部居中，「我刚做了什么」）。
/// 圆角 / 底色 / 描边仍走 InkRadius.pill / surface4 / overlayBorder。
///
/// 每个数都写成令牌而不是在 widget 里现算（禁止对 token 做加减拼间距）；唯一的运行时加法是
/// 「提示词条量出来的高度 h + [barGap]」——h 随提示词行数变，不是令牌。
class InkCanvasCapsuleSize {
  InkCanvasCapsuleSize._();

  /// 胶囊高。
  static const double height = 28;

  /// 提示词条不显示时：胶囊底边离舞台底。
  static const double stageBottom = 16;

  /// 提示词条显示时：胶囊底边离舞台底 = 条高 h + 本值。本值 = 条子底边离舞台底 16
  /// （InkToolbarSize.promptBarBottom）+ 胶囊与条子顶边之间的间隙 8，于是胶囊贴在条子上方 8。
  /// 与 InkToolbarSize.promptBarClearance（= 26，「适应」的底部留白）不是一回事，别混用。
  static const double barGap = 24;

  /// 胶囊左右两侧各让出的宽度：缩放条 left 12 + 条宽 143（InkToolbarSize.zoomBarWidth）+ 间隙 16。
  /// 左右对称让，胶囊才能在舞台上水平居中。由 canvas_screen_layout_test 守着：缩放条右沿 + 16 不越过它。
  static const double sideReserve = 171;

  /// 两侧让位之后剩下的宽度小于本值就不画（舞台太窄，画出来只剩一个省略号）；计时照走。
  static const double minWidth = 96;
}

/// 通知卡（右下角，画布重设计稿 › 通知）。间距 / 圆角 / 阴影仍走 InkSpacing / InkRadius / InkShadow。
class InkToastSize {
  InkToastSize._();
  static const double width = 360; // 卡宽；窗口窄于 [narrowWindow] 时改为 窗口宽 − 2 × InkSpacing.md
  static const double narrowWindow = 480;
  static const double thumbnail = 40; // 左侧缩略图 / 类型图标底块
  static const double closeHit = 24; // 关闭按钮命中区
  static const double progress = 4; // 进度条高
  static const double historyWidth = 360; // 铃铛下拉面板宽
  static const double historyMaxHeight = 460;
}

/// 动画时长（MediaQuery.disableAnimations 时由上层替换为 Duration.zero）。
class InkMotion {
  InkMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
}
