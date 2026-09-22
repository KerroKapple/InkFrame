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

  /// Workspace v2 稿上三种 160° 渐变缩略图占位（README §Assets：实现时换真实缩略图）。
  /// 只供静态复刻用；接线后随 WorkspaceFixture 一起删除。
  static const List<(Color, Color)> thumbPlaceholderGradients = <(Color, Color)>[
    (Color(0xFF3B3A36), Color(0xFF23221F)),
    (Color(0xFF34342F), Color(0xFF1F1E1B)),
    (Color(0xFF2F2A22), Color(0xFF1C1A16)),
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
  static const double s28 = 28;
  // 光学微调小档（2/3/6）：覆盖 chip/inspector/toolbar 的非 8 倍数细间距
  static const double s2 = 2;
  static const double s3 = 3;
  static const double s6 = 6;
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

/// 动画时长（MediaQuery.disableAnimations 时由上层替换为 Duration.zero）。
class InkMotion {
  InkMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
}
