// CanvasScreen：画布标签体（Workspace v2 稿 → 画布重设计稿「画布页 · 改后」）。
//
// 主体三栏：项目面板 241 | 画布区（29px 画布头 + 舞台 + 浮层）| 检查器 301；
// 底部渲染队列 173。状态栏在外壳（ShellStatusBar），菜单栏 / 标签栏也在外壳。
//
// 画布区浮层（稿）：顶部居中浮动工具条（top 12）、底部居中提示词条（bottom 16）、
// 左下缩放条（left 12 / bottom 12）；右下角留给通知卡。原来的左侧 37px 工具条与右下
// 32×32 加号已撤，它们的动作全部并进浮动工具条（canvas_toolbar.dart）。
// 节点 Inspector 不再浮在画布里，改住右侧面板。
//
// 【Scaffold 保留】外壳根 Scaffold 之下的 nested Scaffold，只提供画布区的底色与 Material 祖先。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/current_canvas_id.dart';
import 'canvas_header_bar.dart';
import 'canvas_inspector_panel.dart';
import 'canvas_job_listener.dart';
import 'canvas_project_panel.dart';
import 'canvas_prompt_bar.dart';
import 'canvas_render_queue.dart';
import 'canvas_shortcuts.dart';
import 'canvas_toolbar.dart';
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
                                  Positioned(
                                    left: InkSpacing.s12,
                                    bottom: InkSpacing.s12,
                                    child: CanvasZoomBar(canvasId: canvasId),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 16,
                                    child: Center(child: CanvasPromptBar(canvasId: canvasId)),
                                  ),
                                  // 最后画：压在舞台浮层（连线提示等）之上，那些浮层的 top 已让出
                                  // 工具条的高度（InkToolbarSize.stageTopInset）。
                                  Positioned(
                                    top: InkSpacing.s12,
                                    left: 0,
                                    right: 0,
                                    child: Center(child: CanvasToolbar(canvasId: canvasId)),
                                  ),
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
