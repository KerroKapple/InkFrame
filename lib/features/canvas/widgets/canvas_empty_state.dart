// CanvasEmptyState：当前画布没有节点时的引导态。
//
// 居中插图占位 + 主副标题 + 双 CTA（添加图片节点 / 添加视频节点）。
// 整块外层 GestureDetector 仍负责"点空白"语义：取消连线模式 + 清选中。
// CTA 调 canvasNodesControllerProvider(canvasId).addNode(...)，失败弹 snackbar。

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';

class CanvasEmptyState extends ConsumerWidget {
  const CanvasEmptyState({
    super.key,
    required this.canvasId,
    required this.onBackgroundTap,
  });

  final String canvasId;

  /// 点击空白区域（非 CTA）时的回调：用于退出连线模式 + 清选中。
  final VoidCallback onBackgroundTap;

  static final _rand = Random();

  Offset _pickPosition() => Offset(
        200 + _rand.nextDouble() * 400,
        200 + _rand.nextDouble() * 400,
      );

  Future<void> _addNode(
    BuildContext context,
    WidgetRef ref,
    CanvasNodeType type,
  ) async {
    try {
      await ref
          .read(canvasNodesControllerProvider(canvasId).notifier)
          .addNode(
            label: context.l10n.canvasNodeDefaultLabel,
            type: type,
            position: _pickPosition(),
          );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.canvasAddNodeFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBackgroundTap,
      child: Container(
        color: colors.surface1,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Illustration(colors: colors),
              const SizedBox(height: InkSpacing.lg),
              Text(
                l.canvasEmptyTitle,
                style: typo.headline.copyWith(color: colors.fg1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: InkSpacing.sm),
              Text(
                l.canvasEmptySubtitle,
                style: typo.body.copyWith(color: colors.fg3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: InkSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: InkSpacing.md,
                runSpacing: InkSpacing.sm,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () =>
                        _addNode(context, ref, CanvasNodeType.image),
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        size: 16),
                    label: Text(l.canvasEmptyAddImage),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _addNode(context, ref, CanvasNodeType.video),
                    icon: const Icon(Icons.videocam_outlined, size: 16),
                    label: Text(l.canvasEmptyAddVideo),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.colors});
  final InkColors colors;

  @override
  Widget build(BuildContext context) {
    // 简洁示意：双层圆框 + 加号图标，纯 token 配色，无外部资源。
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colors.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: colors.borderSubtle),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.surface3,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border),
            ),
            child: Icon(Icons.add, color: colors.accent, size: 28),
          ),
        ],
      ),
    );
  }
}
