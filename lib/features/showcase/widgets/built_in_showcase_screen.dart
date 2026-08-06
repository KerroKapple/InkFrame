// 内置示例页：展示随应用打包的 AI 生成预览图。
//
// 这些图片不是项目生成记录，不进入 Gallery 聚合器，也不依赖用户 API Key。
// 入口三处（零项目空态下项目卡菜单不存在，故三处并存）：
// Studio 项目卡 ⋮ 菜单 / Studio 空态 CTA / 命令面板 studio 上下文。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/current_screen.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_card.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/tokens.dart';

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
      color: colors.surfaceCanvas,
      child: Column(
        children: <Widget>[
          InkWindowChrome(
            leading: IconButton(
              tooltip: l.showcaseBackTooltip,
              icon: Icon(Icons.arrow_back, size: 18, color: colors.fg2),
              onPressed: () => ref.read(currentScreenProvider.notifier).state =
                  AppScreen.studio,
            ),
            center: Text(
              l.showcaseTitle,
              style: typo.headlineXs.copyWith(color: colors.fg1),
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
                      style: typo.headlineSm.copyWith(color: colors.fg1),
                    ),
                  ),
                  const SizedBox(width: InkSpacing.md),
                  Text(
                    meta,
                    style: typo.caption.copyWith(color: colors.accent),
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
