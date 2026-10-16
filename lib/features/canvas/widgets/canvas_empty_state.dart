// CanvasEmptyState：当前画布没有节点时的引导态。
//
// 居中插图占位 + 主副标题 + 双 CTA（添加图片节点 / 添加视频节点）。
// 整块按下都把键盘焦点要回画布（与舞台按下同一个口，CTA 上按下也算）；外层 GestureDetector 负责"点空白"语义：
// 取消连线模式 + 清选中。
// 建节点的三个 CTA 与工具条、I / G / T 同一条路（canvas_tool_actions.addNodeAtViewportCenter）：视口中心 + 散布、
// 判泳道、新节点只单选不挪相机，失败弹错误通知卡「添加节点失败」。

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
import '../providers/canvas_transform_controller.dart';
import '../util/canvas_tool_actions.dart';
import '../util/node_position.dart';
import 'canvas_shortcuts.dart';

class CanvasEmptyState extends ConsumerWidget {
  const CanvasEmptyState({
    super.key,
    required this.canvasId,
    required this.onBackgroundTap,
    this.random,
  });

  final String canvasId;

  /// 点击空白区域（非 CTA）时的回调：用于退出连线模式 + 清选中。键盘焦点由本层自己要回画布，不归它。
  final VoidCallback onBackgroundTap;

  /// 随机源注入口（测试用）；null 时每次取系统熵。
  final Random? random;

  /// 导入脚本的铺链起点：视口中心（债150；视口未上报时回退旧固定区随机）。
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
  ) =>
      addNodeAtViewportCenter(context, ref, canvasId: canvasId, type: type, random: random);

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
    // 按下就把键盘焦点要回画布（与舞台按下时同一个口，B6）：在提示词条 / 检查器之类的文本框里打完字再点空画布，
    // 文本框的失焦只把焦点交还给路由作用域，画布不持焦——Delete / Esc / 工具单键全收不到。只听原始指针事件：
    // 按在 CTA 上也算（CTA 自己的点击赢了手势竞技场，外层的 onTap 收不到）。
    return Listener(
      onPointerDown: (PointerDownEvent _) => CanvasShortcuts.reclaimFocus(context),
      child: GestureDetector(
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
      ),
    );
  }
}
