// CanvasScreen：Amber Noir 画布壳——顶栏 chrome + 左工具栏 + 中央 CanvasView + 右 RenderQueue。
// 节点 Inspector 由 CanvasView 在单选 config 节点时就地浮出（见 canvas_view.dart），此处无占位面板。
//
// 仅视觉编排；CanvasView 内部的节点编辑 / 边逻辑保持不变。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../providers/current_canvas_id.dart';
import '../providers/current_canvas_name.dart';
import 'canvas_add_node_fab.dart';
import 'canvas_job_listener.dart';
import 'canvas_left_toolbar.dart';
import 'canvas_render_queue.dart';
import 'canvas_top_chrome.dart';
import 'canvas_view.dart';

class CanvasScreen extends ConsumerWidget {
  const CanvasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final canvasId = ref.watch(currentCanvasIdProvider);
    final canvasName = ref.watch(currentCanvasNameProvider).valueOrNull ??
        context.l10n.canvasDefaultName;
    return CanvasJobListener(
      child: Scaffold(
        backgroundColor: colors.surfaceCanvas,
        floatingActionButton: canvasId == null
            ? null
            : CanvasAddNodeFab(canvasId: canvasId),
        body: Column(
          children: <Widget>[
            CanvasTopChrome(canvasName: canvasName),
            // 右栏：渲染队列。节点 Inspector 由 CanvasView 在单选 config 节点时
            // 就地浮出，不再用占位 mock 面板。
            const Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CanvasLeftToolbar(),
                  Expanded(child: CanvasView()),
                  SizedBox(
                    width: 320,
                    child: CanvasRenderQueue(),
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
