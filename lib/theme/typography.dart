// 排版 token：widget 只读 context.inkTypography 获得 TextStyle。
//
// 字号通过 A11y §20.1 的"界面字号"档位在上层 ThemeExtension 乘以缩放系数
// 后注入，不直接依赖 MediaQuery.textScaler——保证 golden test 可控。
// 禁止 widget 内 copyWith(fontSize:) 钉死字号——会绕过 a11y 缩放。
//
// 字体方案（docs/design/handoff-2026-09/README.md §字体）：
//   - 界面全无衬线：Noto Sans SC，**不打包**，回落 PingFang SC → Microsoft YaHei UI
//     → 平台默认无衬线（Flutter 回落链穷尽后隐式落到系统默认；**不写 'sans-serif'**
//     ——它是 Skia 通用族名，会在 widget test 里解析成真实系统字体，让度量随机器漂）。
//     字形与设计稿的差异属预期。
//   - 等宽只给数值 / 时间码 / 路径 / ID：JetBrains Mono（打包），回落 Consolas / Menlo。
//   - 正文 12 是桌面工具常规密度，不再往下压：11 只给元信息，10 只给徽标与时间码。
import 'package:flutter/widgets.dart';

const String _sans = 'Noto Sans SC';
const List<String> _sansFallback = <String>[
  'PingFang SC',
  'Microsoft YaHei UI',
];

const String _mono = 'JetBrainsMono';
const List<String> _monoFallback = <String>[
  'Consolas',
  'Menlo',
  'PingFang SC',
  'Microsoft YaHei UI',
];

@immutable
class InkTypography {
  const InkTypography({
    required this.body,
    required this.bodyStrong,
    required this.meta,
    required this.micro,
    required this.sectionTitle,
    required this.dialogTitle,
    required this.mono,
    required this.monoSmall,
  });

  factory InkTypography.defaults({double scale = 1.0}) => InkTypography(
        body: _sansStyle(12, FontWeight.w400, 1.45, scale),
        bodyStrong: _sansStyle(12, FontWeight.w500, 1.45, scale),
        meta: _sansStyle(11, FontWeight.w400, 1.45, scale),
        micro: _sansStyle(10, FontWeight.w400, 1.3, scale),
        sectionTitle: _sansStyle(15, FontWeight.w500, 1.3, scale),
        dialogTitle: _sansStyle(17, FontWeight.w500, 1.3, scale),
        mono: _monoStyle(11, scale),
        monoSmall: _monoStyle(10, scale),
      );

  final TextStyle body; // 12/400 正文
  final TextStyle bodyStrong; // 12/500 面板标题 / 选中标签 / 节点名
  final TextStyle meta; // 11/400 元信息、辅助说明
  final TextStyle micro; // 10/400 徽标、极小标签
  final TextStyle sectionTitle; // 15/500 区块标题
  final TextStyle dialogTitle; // 17/500 对话框主标题
  final TextStyle mono; // 11 等宽：数值 / 时间码 / 路径 / ID
  final TextStyle monoSmall; // 10 等宽：徽标内数值 / 序号

  /// 全部八档（测试遍历用）。
  List<TextStyle> get all => <TextStyle>[
        body,
        bodyStrong,
        meta,
        micro,
        sectionTitle,
        dialogTitle,
        mono,
        monoSmall,
      ];

  InkTypography scaled(double scale) => InkTypography(
        body: _scale(body, 12, scale),
        bodyStrong: _scale(bodyStrong, 12, scale),
        meta: _scale(meta, 11, scale),
        micro: _scale(micro, 10, scale),
        sectionTitle: _scale(sectionTitle, 15, scale),
        dialogTitle: _scale(dialogTitle, 17, scale),
        mono: _scale(mono, 11, scale),
        monoSmall: _scale(monoSmall, 10, scale),
      );

  static TextStyle _sansStyle(
    double size,
    FontWeight weight,
    double height,
    double scale,
  ) =>
      TextStyle(
        fontFamily: _sans,
        fontFamilyFallback: _sansFallback,
        fontSize: size * scale,
        fontWeight: weight,
        height: height,
      );

  static TextStyle _monoStyle(double size, double scale) => TextStyle(
        fontFamily: _mono,
        fontFamilyFallback: _monoFallback,
        fontSize: size * scale,
        fontWeight: FontWeight.w400,
        height: 1.0,
      );

  static TextStyle _scale(TextStyle s, double base, double scale) =>
      s.copyWith(fontSize: (s.fontSize ?? base) * scale);
}
