// CanvasScreen：画布标签体（Workspace v2 稿）。
//
// 主体三栏：工具条 37 | 项目面板 241 | 画布区（29px 画布头 + 舞台 + 浮层）| 检查器 301；
// 底部渲染队列 173。状态栏在外壳（ShellStatusBar），菜单栏 / 标签栏也在外壳。
//
// 画布区浮层（稿）：右下缩放条（bottom 56）、底部居中提示词条（bottom 16）、右下 32×32 FAB。
// 节点 Inspector 不再浮在画布里，改住右侧面板。
//
// 【Scaffold 保留】它因为有外壳根 Scaffold 作祖先而变成 nested，_isRoot 返回 false ⇒
// 自动排除出 SnackBar 广播（V3b）。FAB 不再用 Scaffold.floatingActionButton（稿的位置在画布区内）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../providers/current_canvas_id.dart';
import 'canvas_add_node_fab.dart';
import 'canvas_header_bar.dart';
import 'canvas_inspector_panel.dart';
import 'canvas_job_listener.dart';
import 'canvas_project_panel.dart';
import 'canvas_prompt_bar.dart';
import 'canvas_render_queue.dart';
import 'canvas_shortcuts.dart';
import 'canvas_tool_rail.dart';
import 'canvas_view.dart';

class CanvasScreen extends ConsumerWidget {
  const CanvasScreen({super.key, required this.isVisible});

  /// 本画布页当前是否是外壳里可见的那一标签（保活场景下的可见性开关，
  /// 而非挂载与否）——直通给 CanvasShortcuts 的 isActive。
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final String? canvasId = ref.watch(currentCanvasIdProvider);
    return CanvasJobListener(
      child: Scaffold(
        backgroundColor: colors.surface2,
        body: Column(
          children: <Widget>[
            Expanded(
              // PL-2：画布快捷键层包裹整行（含 Inspector），autofocus 使按键即时生效；
              // 焦点在 Inspector 文本框时删除/全选让位文本编辑（见 CanvasShortcuts）。
              child: CanvasShortcuts(
                isActive: isVisible,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (canvasId != null) CanvasToolRail(canvasId: canvasId),
                    if (canvasId != null) CanvasProjectPanel(canvasId: canvasId),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (canvasId != null) CanvasHeaderBar(canvasId: canvasId),
                          Expanded(
                            child: Stack(
                              children: <Widget>[
                                const Positioned.fill(child: CanvasView()),
                                if (canvasId != null) ...<Widget>[
                                  Positioned(right: 12, bottom: 56, child: CanvasZoomBar(canvasId: canvasId)),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 16,
                                    child: Center(child: CanvasPromptBar(canvasId: canvasId)),
                                  ),
                                  Positioned(right: 12, bottom: 12, child: CanvasAddNodeFab(canvasId: canvasId)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canvasId != null) CanvasInspectorPanel(canvasId: canvasId),
                  ],
                ),
              ),
            ),
            const CanvasRenderQueue(),
          ],
        ),
      ),
    );
  }
}
