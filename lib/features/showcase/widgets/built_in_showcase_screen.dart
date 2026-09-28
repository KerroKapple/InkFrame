// 内置示例页：展示随应用打包的 AI 生成预览图。
//
// 这些图片不是项目生成记录，不进入 Gallery 聚合器，也不依赖用户 API Key。
// 入口三处（零项目空态下项目卡菜单不存在，故三处并存）：
// Studio 项目卡 ⋮ 菜单 / Studio 空态 CTA / 命令面板 studio 上下文。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_card.dart';
import '../../../theme/components/ink_tool_bar.dart';
import '../../../theme/tokens.dart';
import '../../shell/providers/shell_controller.dart';

class BuiltInShowcaseScreen extends ConsumerWidget {
  const BuiltInShowcaseScreen({super.key});

  static const double _wideLayoutBreakpoint = 960;
  static const double _contentMaxWidth = 1280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    return Material(
      color: colors.surface0,
      child: Column(
        children: <Widget>[
          // 浮层自己不带窗口 chrome：它盖在外壳 chrome【之下】、内容区之内，
          // 因此继承外壳的 DragToMoveArea 与三个窗口按钮（D6）。
          // 关闭途径三条：本工具条的关闭键、点任一标签、⌘K（Esc 刻意不做，见 §7.5）。
          InkToolBar(
            leading: IconButton(
              tooltip: l.shellCloseOverlay,
              icon: Icon(Icons.arrow_back, size: 18, color: colors.fg2),
              onPressed: () =>
                  ref.read(shellControllerProvider.notifier).closeOverlay(),
            ),
            title: Text(
              l.showcaseTitle,
              style: typo.sectionTitle.copyWith(color: colors.fg1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(InkSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l.showcaseSubtitle,
                        style: typo.body.copyWith(color: colors.fg3),
                      ),
                      const SizedBox(height: InkSpacing.xl),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final samples = <Widget>[
                            _ShowcaseCard(
                              assetPath:
                                  'assets/showcase/ink-wash-mountains-square.jpg',
                              aspectRatio: 1,
                              title: l.showcaseSquareTitle,
                              meta: l.showcaseSquareMeta,
                            ),
                            _ShowcaseCard(
                              assetPath:
                                  'assets/showcase/ink-wash-storyboard-wide.jpg',
                              aspectRatio: 16 / 9,
                              title: l.showcaseWideTitle,
                              meta: l.showcaseWideMeta,
                            ),
                          ];
                          if (constraints.maxWidth >= _wideLayoutBreakpoint) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(flex: 10, child: samples[0]),
                                const SizedBox(width: InkSpacing.lg),
                                Expanded(flex: 18, child: samples[1]),
                              ],
                            );
                          }
                          return Column(
                            children: <Widget>[
                              samples[0],
                              const SizedBox(height: InkSpacing.lg),
                              samples[1],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({
    required this.assetPath,
    required this.aspectRatio,
    required this.title,
    required this.meta,
  });

  /// 卡片最大显示宽（内容区 1280 双栏时宽卡约 800）——解码上限按它算。
  static const double _cardMaxWidth = 820;

  final String assetPath;
  final double aspectRatio;
  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    // 用设计系统组件而非手搓 BoxDecoration（评审 P2-3：与 InkCard 逐字段重复,
    // 违反 Components Over Primitives）。padding 归零让图铺满卡片。
    return InkCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(InkRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                // 按显示宽 × DPR 解码（ME-26 既有约定,同 node_card/
                // video_node_body）：否则两张图全尺寸解码常驻 ≈9.4MB。
                cacheWidth: (_cardMaxWidth *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
                semanticLabel: title,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: colors.surface3,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, color: colors.fg3),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(InkSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: typo.sectionTitle.copyWith(color: colors.fg1),
                    ),
                  ),
                  const SizedBox(width: InkSpacing.md),
                  Text(
                    meta,
                    style: typo.meta.copyWith(color: colors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
