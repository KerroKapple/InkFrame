// CanvasScreen：Amber Noir 画布壳——顶栏 chrome + 左工具栏 + 中央 CanvasView + 右 Inspector / RenderQueue。
//
// 仅视觉编排；CanvasView 内部的节点编辑 / 边逻辑保持不变。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';
import '../../generation/services/toast_service.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/current_canvas_id.dart';
import '../util/canvas_job_effects.dart';
import 'canvas_add_node_fab.dart';
import 'canvas_inspector.dart';
import 'canvas_left_toolbar.dart';
import 'canvas_render_queue.dart';
import 'canvas_top_chrome.dart';
import 'canvas_view.dart';

class CanvasScreen extends ConsumerWidget {
  const CanvasScreen({super.key, required this.canvasName});

  final String canvasName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final l = context.l10n;
    final canvasId = ref.watch(currentCanvasIdProvider);
    ref.listen<List<JobState>>(jobsRegistryProvider, (prev, next) {
      if (canvasId == null) return;
      final effect = CanvasJobEffects.diff(
        prev: prev ?? const <JobState>[],
        next: next,
        canvasId: canvasId,
      );
      if (effect.shouldReloadNodes) {
        ref.invalidate(canvasNodesControllerProvider(canvasId));
      }
      for (final err in effect.toastErrors) {
        ref.read(toastServiceProvider).show(
              l10nError(context, err),
              kind: ToastKind.error,
            );
      }
    });
    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      floatingActionButton: canvasId == null
          ? null
          : CanvasAddNodeFab(canvasId: canvasId),
      body: Column(
        children: <Widget>[
          CanvasTopChrome(canvasName: canvasName),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const CanvasLeftToolbar(),
                const Expanded(child: CanvasView()),
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: CanvasInspector(
                          nodeTitle: l.canvasInspectorMockTitle,
                          nodeKindLabel: l.canvasInspectorKindCamera,
                          nodeId: l.canvasInspectorMockId,
                        ),
                      ),
                      const Expanded(flex: 1, child: CanvasRenderQueue()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
