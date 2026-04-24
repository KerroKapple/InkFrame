// PrimitivesShowcase: debug-only 路由，并排展示 Sprint 2 v3 全部原子组件变体，
// 用于肉眼对照 CineFlow 视觉。仅通过 kDebugMode AppBar 按钮进入，不参与发布构建。

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
              title: 'Glass Trio',
              child: Wrap(
                spacing: InkSpacing.md,
                runSpacing: InkSpacing.md,
                children: <Widget>[
                  InkGlassCard(
                    padding: EdgeInsets.all(InkSpacing.md),
                    child: Text('InkGlassCard\n圆角 lg (12) blur 40 sat 1.5'),
                  ),
                  InkGlassPanel(
                    padding: EdgeInsets.all(InkSpacing.md),
                    child: Text('InkGlassPanel\n圆角 md (8) blur 24 sat 1.25'),
                  ),
                  InkGlassPill(
                    padding: EdgeInsets.symmetric(
                      horizontal: InkSpacing.md,
                      vertical: InkSpacing.sm,
                    ),
                    child: Text('InkGlassPill 圆胶囊'),
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
                    label: '原点',
                    icon: Icons.home_outlined,
                    onPressed: () {},
                  ),
                  InkSurfaceButton(
                    label: '全览',
                    icon: Icons.zoom_out_map,
                    onPressed: () {},
                  ),
                  InkSurfaceButton(label: '无 icon', onPressed: () {}),
                  InkSurfaceButton.icon(
                    icon: Icons.add,
                    onPressed: () {},
                    tooltip: '放大',
                  ),
                  InkSurfaceButton.icon(
                    icon: Icons.remove,
                    onPressed: () {},
                    tooltip: '缩小',
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
                        Text('添加参考图'),
                      ],
                    ),
                  ),
                  const InkDashedSlot(
                    child: Text('静态占位（不可 tap）'),
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
                    child: InkCompactTextField(placeholder: '输入提示词...'),
                  ),
                  SizedBox(height: InkSpacing.md),
                  SizedBox(
                    width: 320,
                    child: InkCompactTextField(
                      placeholder: '多行模式：讲一个故事...',
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
