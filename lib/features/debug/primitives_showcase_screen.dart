// PrimitivesShowcase: debug-only 路由，并排展示 Sprint 2 v3 全部原子组件变体，
// 用于肉眼对照设计 token 视觉。仅通过 kDebugMode AppBar 按钮进入，不参与发布构建。

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/primitives/ink_accent_chip.dart';
import '../../theme/primitives/ink_compact_text_field.dart';
import '../../theme/primitives/ink_dashed_slot.dart';
import '../../theme/primitives/ink_glass_card.dart';
import '../../theme/primitives/ink_gradient_button.dart';
import '../../theme/primitives/ink_pill_tag.dart';
import '../../theme/primitives/ink_surface_button.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class PrimitivesShowcaseScreen extends StatelessWidget {
  const PrimitivesShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Scaffold(
      backgroundColor: colors.surface1,
      appBar: AppBar(
        title: const Text('Primitives Showcase'),
        backgroundColor: colors.surface1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(InkSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Section(
              title: 'InlinePanel Mock (node inline panel composition)',
              child: _InlinePanelMock(),
            ),
            const _Section(
              title: 'Glass Trio',
              child: Wrap(
                spacing: InkSpacing.md,
                runSpacing: InkSpacing.md,
                children: <Widget>[
                  InkGlassCard(
                    padding: EdgeInsets.all(InkSpacing.md),
                    child: Text('InkGlassCard\nradius lg (12) blur 40 sat 1.5'),
                  ),
                  InkGlassPanel(
                    padding: EdgeInsets.all(InkSpacing.md),
                    child: Text('InkGlassPanel\nradius md (8) blur 24 sat 1.25'),
                  ),
                  InkGlassPill(
                    padding: EdgeInsets.symmetric(
                      horizontal: InkSpacing.md,
                      vertical: InkSpacing.sm,
                    ),
                    child: Text('InkGlassPill (pill shape)'),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'GradientButton 6 variants',
              child: Wrap(
                spacing: InkSpacing.sm,
                runSpacing: InkSpacing.sm,
                children: <Widget>[
                  for (final v in InkGradientVariant.values)
                    InkGradientButton(
                      variant: v,
                      label: v.name,
                      icon: Icons.circle,
                      onPressed: () {},
                    ),
                ],
              ),
            ),
            _Section(
              title: 'SurfaceButton',
              child: Wrap(
                spacing: InkSpacing.sm,
                runSpacing: InkSpacing.sm,
                children: <Widget>[
                  InkSurfaceButton(
                    label: 'Home',
                    icon: Icons.home_outlined,
                    onPressed: () {},
                  ),
                  InkSurfaceButton(
                    label: 'Fit all',
                    icon: Icons.zoom_out_map,
                    onPressed: () {},
                  ),
                  InkSurfaceButton(label: 'No icon', onPressed: () {}),
                  InkSurfaceButton.icon(
                    icon: Icons.add,
                    onPressed: () {},
                    tooltip: 'Zoom in',
                  ),
                  InkSurfaceButton.icon(
                    icon: Icons.remove,
                    onPressed: () {},
                    tooltip: 'Zoom out',
                  ),
                  const InkSurfaceButton(label: 'disabled', onPressed: null),
                ],
              ),
            ),
            _Section(
              title: 'DashedSlot',
              child: Wrap(
                spacing: InkSpacing.md,
                runSpacing: InkSpacing.md,
                children: <Widget>[
                  InkDashedSlot(
                    onPressed: () {},
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.add, size: 14),
                        SizedBox(width: InkSpacing.xs),
                        Text('Add reference'),
                      ],
                    ),
                  ),
                  const InkDashedSlot(
                    child: Text('Static slot (non-tappable)'),
                  ),
                ],
              ),
            ),
            const _Section(
              title: 'AccentChip & PillTag',
              child: Wrap(
                spacing: InkSpacing.sm,
                runSpacing: InkSpacing.sm,
                children: <Widget>[
                  InkAccentChip(label: 'Active'),
                  InkAccentChip(label: 'Pinned', icon: Icons.push_pin),
                  InkPillTag(label: 'EP01'),
                  InkPillTag(label: 'Series', icon: Icons.folder_outlined),
                  InkPillTag(label: '4K'),
                ],
              ),
            ),
            const _Section(
              title: 'CompactTextField',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 320,
                    child: InkCompactTextField(placeholder: 'Enter prompt...'),
                  ),
                  SizedBox(height: InkSpacing.md),
                  SizedBox(
                    width: 320,
                    child: InkCompactTextField(
                      placeholder: 'Multiline: tell a story...',
                      minLines: 3,
                      maxLines: 6,
                    ),
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

/// InlinePanel Mock：用 Sprint 2 v3 的 primitive 演示节点内嵌操作面板
/// 的真实使用场景 —— 底下铺假画布 + 假节点卡片，让 glass-card 毛玻璃
/// 有实际"可模糊"的下层内容，才能看出效果。
class _InlinePanelMock extends StatelessWidget {
  const _InlinePanelMock();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;

    return ClipRRect(
      borderRadius: BorderRadius.circular(InkRadius.lg),
      child: Container(
        width: double.infinity,
        height: 640,
        color: colors.surfaceCanvas,
        child: Stack(
          children: <Widget>[
            // 伪画布斑驳背景（让 glass backdrop-blur 有东西可模糊）
            const _FakeCanvasBackdrop(),

            // 假节点卡（image result）
            Positioned(
              top: 80,
              left: 40,
              child: _FakeNodeCard(
                width: 220,
                height: 140,
                label: 'shot_42 / image result',
                colors: colors,
                typo: typo,
              ),
            ),

            // Inline panel 浮在节点下方
            Positioned(
              top: 80 + 140 + 16, // 节点底 + gap
              left: 40 - (380 - 220) / 2, // 面板宽 380，水平对齐节点中心
              child: SizedBox(
                width: 380,
                child: InkGlassCard(
                  padding: const EdgeInsets.fromLTRB(
                    InkSpacing.md,
                    InkSpacing.sm,
                    InkSpacing.md,
                    InkSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // 参考图区（紧凑一行）
                      Row(
                        children: <Widget>[
                          Text(
                            'Refs',
                            style: typo.nano.copyWith(color: colors.fg3),
                          ),
                          const SizedBox(width: InkSpacing.sm),
                          Expanded(
                            child: Wrap(
                              spacing: InkSpacing.xs,
                              runSpacing: InkSpacing.xs,
                              children: <Widget>[
                                const InkPillTag(
                                  label: 'ref-01',
                                  icon: Icons.image_outlined,
                                ),
                                const InkPillTag(
                                  label: 'ref-02',
                                  icon: Icons.image_outlined,
                                ),
                                InkDashedSlot(
                                  onPressed: () {},
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.add,
                                        size: 11,
                                        color: colors.fg3,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Add',
                                        style: typo.nano
                                            .copyWith(color: colors.fg3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: InkSpacing.sm),
                      // Prompt
                      const InkCompactTextField(
                        placeholder: 'Enter prompt (/ commands, @ refs)...',
                        minLines: 3,
                        maxLines: 5,
                      ),
                      const SizedBox(height: InkSpacing.sm),
                      // 底部控制条：左 Wrap(model/ratio/quality/cam) + 右 Generate
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Wrap(
                              spacing: InkSpacing.xs,
                              runSpacing: InkSpacing.xs,
                              children: <Widget>[
                                InkSurfaceButton(
                                  label: 'wanx-t2v',
                                  icon: Icons.auto_awesome,
                                  onPressed: () {},
                                ),
                                InkSurfaceButton(
                                  label: '16:9',
                                  icon: Icons.aspect_ratio,
                                  onPressed: () {},
                                ),
                                InkSurfaceButton(
                                  label: '1080p',
                                  onPressed: () {},
                                ),
                                InkAccentChip(
                                  icon: Icons.videocam_outlined,
                                  label: 'Camera',
                                  onPressed: () {},
                                ),
                                InkSurfaceButton(
                                  label: 'Advanced',
                                  icon: Icons.tune,
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: InkSpacing.sm),
                          InkGradientButton(
                            variant: InkGradientVariant.image,
                            label: 'Generate',
                            icon: Icons.bolt,
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 假画布背景：几个漂浮色斑，仅用来给 glass backdrop-blur 提供可模糊内容。
class _FakeCanvasBackdrop extends StatelessWidget {
  const _FakeCanvasBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: <Widget>[
        Positioned(
          left: 260,
          top: 40,
          child: _ColorBlob(size: 220, color: Color(0xFFA855F7)),
        ),
        Positioned(
          right: 80,
          top: 200,
          child: _ColorBlob(size: 160, color: Color(0xFFEAB308)),
        ),
        Positioned(
          left: 120,
          bottom: 40,
          child: _ColorBlob(size: 180, color: Color(0xFF22C55E)),
        ),
        Positioned(
          right: 200,
          bottom: 120,
          child: _ColorBlob(size: 140, color: Color(0xFFEC4899)),
        ),
      ],
    );
  }
}

class _ColorBlob extends StatelessWidget {
  const _ColorBlob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// 假节点卡：纯视觉，模拟 NodeCard 在画布上的样子。
class _FakeNodeCard extends StatelessWidget {
  const _FakeNodeCard({
    required this.width,
    required this.height,
    required this.label,
    required this.colors,
    required this.typo,
  });

  final double width;
  final double height;
  final String label;
  final InkColors colors;
  final InkTypography typo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Text(
              label,
              style: typo.micro.copyWith(color: colors.fg2),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              decoration: BoxDecoration(
                color: colors.surface3,
                borderRadius: BorderRadius.circular(InkRadius.sm),
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 32,
                  color: colors.fg3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final typo = context.inkTypography;
    final colors = context.inkColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: typo.title.copyWith(color: colors.fg1),
          ),
          const SizedBox(height: InkSpacing.md),
          child,
        ],
      ),
    );
  }
}
