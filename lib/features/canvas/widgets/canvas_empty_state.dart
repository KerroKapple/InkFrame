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
import '../../../theme/primitives/ink_amber_button.dart';
import '../../../theme/primitives/ink_ghost_button.dart';
import '../../shell/widgets/shell_empty_state.dart';
import '../../storyboard/widgets/script_import_dialog.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../util/node_position.dart';

class CanvasEmptyState extends ConsumerWidget {
  const CanvasEmptyState({
    super.key,
    required this.canvasId,
    required this.onBackgroundTap,
    this.random,
  });

  final String canvasId;

  /// 点击空白区域（非 CTA）时的回调：用于退出连线模式 + 清选中。
  final VoidCallback onBackgroundTap;

  /// 随机源注入口（测试用）；null 时每次取系统熵。
  final Random? random;

  /// 债150：视口中心落点（视口未上报时回退旧固定区随机——测试语义不变）。
  Offset _pickPosition(WidgetRef ref, CanvasNodeType type) =>
      pickViewportCenteredNodePosition(
        random: random ?? Random(),
        transform: ref.read(canvasTransformControllerProvider(canvasId)).value,
        viewportSize: ref.read(canvasViewportSizeProvider(canvasId)),
        nodeSize: defaultNodeSize(type),
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
            position: _pickPosition(ref, type),
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
    // 空态代替 _CanvasStage 渲染,视口上报也要跟着来（评审 P2-1）：否则
    // 首建路径读到 Size.zero(债150 不生效)或上一画布残值。模式同 canvas_view。
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ref.read(canvasViewportSizeProvider(canvasId).notifier).setSize(size);
          }
        });
        return _body(context, ref);
      },
    );
  }


  /// 外形走共用空态壳（中性灰语汇：72 圆底 + 标题 + 副文 + 动作行）。
  /// 四个动作按设计系统的按钮画：主动作一颗琥珀，其余三颗幽灵按钮——
  /// 原来用的 FilledButton / OutlinedButton 带 Material 自己的涟漪与主色，
  /// 是这一屏里唯一一处「别人家的按钮」。
  Widget _body(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBackgroundTap,
      child: Container(
        color: context.inkColors.surface1,
        child: ShellEmptyState(
          icon: Icons.add_photo_alternate_outlined,
          title: l.canvasEmptyTitle,
          body: l.canvasEmptySubtitle,
          actions: <Widget>[
            InkAmberButton(
              label: l.canvasEmptyAddImage,
              icon: Icons.add_photo_alternate_outlined,
              onPressed: () => _addNode(context, ref, CanvasNodeType.image),
            ),
            InkGhostButton(
              label: l.canvasEmptyAddVideo,
              icon: Icons.videocam_outlined,
              onPressed: () => _addNode(context, ref, CanvasNodeType.video),
            ),
            InkGhostButton(
              label: l.canvasEmptyAddShot,
              icon: Icons.movie_outlined,
              onPressed: () => _addNode(context, ref, CanvasNodeType.shot),
            ),
            // SB-2：手上已有本子的人，空画布该给的是「粘进来」而不是「一个个建」。
            InkGhostButton(
              label: l.canvasEmptyImportScript,
              icon: Icons.playlist_add,
              onPressed: () => showScriptImportDialog(
                context,
                canvasId: canvasId,
                origin: _pickPosition(ref, CanvasNodeType.shot),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
