// 首启向导静态复刻的假数据（Screens 稿第 4 屏左）。
//
// 全部取自稿 markup 的 `onboardSteps` / `onboardProviders` 数组与行内文案，逐字照抄——
// 标点都是稿上的原码位：全角括号 U+FF08/U+FF09、全角冒号 U+FF1A、间隔号 U+00B7、
// 直角引号 U+300C/U+300D。接线时这些串进 ARB，别在这里改写。
//
// 稿只画了第 2 步「配置密钥」，所以复刻件也只画这一步；第 1/3 步的页签只出现在步骤条上。
import 'dart:ui' show Size;

/// 稿上一行 Provider。
class ObProvider {
  const ObProvider({
    required this.name,
    required this.note,
    required this.region,
    required this.checked,
  });

  final String name;
  final String note;
  final String region;
  final bool checked;
}

/// 稿上一个步骤页签。
class ObStep {
  const ObStep({
    required this.index,
    required this.name,
    required this.current,
    required this.width,
  });

  /// 等宽两位序号（`01`/`02`/`03`）。
  final String index;
  final String name;
  final bool current;

  /// 稿上的页签宽：`16 + 序号12 + gap8 + 文字(24|48) + 16`。
  ///
  /// 稿里这个宽是**内容撑出来**的，不是等分；但撑它的是稿打包的 Noto Sans SC，
  /// 而本仓库按 pubspec 注释不打包界面无衬线字体、走系统回落链，同一串中文宽度
  /// 差 1px 就会把后面两个页签整体推走（下划线跟着错位）。所以这里按稿钉死。
  final double width;
}

class OnboardingFixture {
  OnboardingFixture._();

  /// 卡片 border-box：稿 `width:640` content + 1px 边 ×2；高度 auto 算出 491.594，
  /// 光栅取整 492（竖向合账：1 + 43 步骤条 + 391.594 正文 + 55 底部条 + 1）。
  static const Size designSize = Size(642, 492);

  // ------------------------------------------------------------------ 步骤条
  static const List<ObStep> steps = <ObStep>[
    ObStep(index: '01', name: '欢迎', current: false, width: 76),
    ObStep(index: '02', name: '配置密钥', current: true, width: 100),
    ObStep(index: '03', name: '首个项目', current: false, width: 100),
  ];

  // -------------------------------------------------------------------- 正文
  /// `API` 前是一个半角空格。
  static const String title = '配置一个 API Key';
  static const String description =
      'InkFrame 自带密钥（BYOK），不做差价。先配一个就能开始，其余随时在设置里补。';

  static const List<ObProvider> providers = <ObProvider>[
    ObProvider(
      name: 'Google Gemini',
      note: '全球可用，最快验证闭环',
      region: '全球',
      checked: true,
    ),
    ObProvider(
      name: 'fal.ai',
      note: '图像与视频一站，模型最全',
      region: '全球',
      checked: false,
    ),
    ObProvider(
      name: 'DashScope（阿里）',
      note: '国内直连，Kling 与 Wanx',
      region: '中国',
      checked: false,
    ),
  ];

  // ---------------------------------------------------------------- API Key
  /// 字面 ASCII，稿上不翻译。
  static const String keyLabel = 'API Key';

  /// `AIza` + 24 个 U+2022 BULLET + `3f2a`，共 32 字符。
  static const String keyMasked =
      'AIza••••••••••••••••••••••••3f2a';
  static const String verify = '验证';

  /// U+2713。稿声明等宽但该码位不在打包子集里，两边都会回落到符号字体。
  static const String checkGlyph = '✓';
  static const String verified = '验证通过 · 已写入系统钥匙串';

  // ------------------------------------------------------------------ 底部条
  /// 无硬件探测——静态复刻照稿画，接线时按 PLAN 换成「可在设置 › 性能中调整」。
  static const String footerHint = '已检测：32 GB · 独显 · 推荐「极致」档';
  static const String skip = '跳过';
  static const String next = '下一步';
}
