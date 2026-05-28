// CanvasNodeCard：Amber Noir 节点卡 — 4px 类型色条 + Cormorant 标题 + 16:9 缩略图 + ID/RES mono 行。
//
// 仅视觉：本组件不接节点编辑数据流（保留 features/canvas/widgets/node_card.dart 给真实节点）。
// 此卡片用于 mockup-parity 展示与未来 schema 演进时的视觉基线。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_noir_card.dart';
import '../../../theme/tokens.dart';

/// 节点视觉类型——只决定外观（标签 + stripe 颜色），不影响数据。
enum CanvasNodeType { character, scene, camera, prop, shot, imageGen }

extension CanvasNodeTypeX on CanvasNodeType {
  Color stripeColor(InkColors c) {
    switch (this) {
      case CanvasNodeType.character:
        return c.accent;
      case CanvasNodeType.scene:
        return c.info;
      case CanvasNodeType.camera:
        return c.warning;
      case CanvasNodeType.prop:
        return c.danger;
      case CanvasNodeType.shot:
        return c.border;
      case CanvasNodeType.imageGen:
        return c.success;
    }
  }

  String label(BuildContext context) {
    final l = context.l10n;
    switch (this) {
      case CanvasNodeType.character:
        return l.canvasNodeTypeCharacter;
      case CanvasNodeType.scene:
        return l.canvasNodeTypeScene;
      case CanvasNodeType.camera:
        return l.canvasNodeTypeCamera;
      case CanvasNodeType.prop:
        return l.canvasNodeTypeProp;
      case CanvasNodeType.shot:
        return l.canvasNodeTypeShot;
      case CanvasNodeType.imageGen:
        return l.canvasNodeTypeImageGen;
    }
  }
}

class CanvasNodeCard extends StatelessWidget {
  const CanvasNodeCard({
    super.key,
    required this.type,
    required this.title,
    required this.id,
    required this.resolution,
    this.selected = false,
    this.onTap,
  });

  final CanvasNodeType type;
  final String title;
  final String id;
  final String resolution;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return SizedBox(
      width: 200,
      child: InkNoirCard(
        onTap: onTap,
        selected: selected,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(height: 4, color: type.stripeColor(colors)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                InkSpacing.md,
                InkSpacing.sm,
                InkSpacing.md,
                0,
              ),
              child: Text(
                type.label(context),
                style: typo.nano.copyWith(
                  fontFamily: 'JetBrainsMono',
                  color: colors.fg3,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                InkSpacing.md,
                2,
                InkSpacing.md,
                InkSpacing.sm,
              ),
              child: Text(
                title,
                style: typo.headline.copyWith(fontSize: 18, color: colors.fg1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface3,
                    borderRadius: BorderRadius.circular(InkRadius.sm),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                InkSpacing.md,
                InkSpacing.sm,
                InkSpacing.md,
                InkSpacing.sm + 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    id,
                    style: typo.micro.copyWith(
                      fontFamily: 'JetBrainsMono',
                      color: colors.fg3,
                    ),
                  ),
                  Text(
                    resolution,
                    style: typo.micro.copyWith(
                      fontFamily: 'JetBrainsMono',
                      color: colors.fg3,
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
