// CanvasScreen：画布标签体（Workspace v2 稿 → 画布重设计稿「画布页 · 改后」）。
//
// 主体三栏：左栏（43px 图标导航条 + 241 面板，面板可收起）| 画布区（舞台 + 浮层）| 检查器 301。
// 状态栏在外壳（ShellStatusBar），菜单栏 / 标签栏也在外壳。
// PR-6 页签去重撤掉了舞台上方的 29px 画布头和底部 173px 的渲染队列：画布名在面包屑里，泳道名写在
// 泳道上，缩放比例在左下缩放条；任务进度挪到外壳状态栏的任务胶囊 + 任务弹层（job 是全局的，所有
// 标签下都在）。于是舞台上沿紧贴外壳标签栏，下沿紧贴状态栏。
// 左栏（widgets/left_rail/）：导航条切大纲 / 素材 / 角色三页，点当前页或收起键（Ctrl+\ / ⌘\）
// 收起面板——收起时舞台左沿直接贴上导航条右沿。浮层都按舞台定位，不进左栏那一列。
//
// 画布区浮层（稿）：顶部居中浮动工具条（top 12）、底部居中提示词条（bottom 16）、
// 左下缩放条（left 12 / bottom 12，canvas_zoom_bar.dart）；右下角留给通知卡。原来的左侧 37px
// 工具条与右下 32×32 加号已撤，它们的动作全部并进浮动工具条（canvas_toolbar.dart）。
// 节点 Inspector 不再浮在画布里，改住右侧面板。
//
// 【Scaffold 保留】外壳根 Scaffold 之下的 nested Scaffold，只提供画布区的底色与 Material 祖先。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/current_canvas_id.dart';
import 'canvas_inspector_panel.dart';
import 'canvas_job_listener.dart';
import 'canvas_prompt_bar.dart';
import 'canvas_shortcuts.dart';
import 'canvas_toolbar.dart';
import 'canvas_view.dart';
import 'canvas_zoom_bar.dart';
import 'left_rail/canvas_left_rail.dart';
import 'left_rail/left_rail_panel.dart';

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
        // PL-2：画布快捷键层包裹整行（含 Inspector），autofocus 使按键即时生效；
        // 焦点在 Inspector 文本框时删除/全选让位文本编辑（见 CanvasShortcuts）。
        body: CanvasShortcuts(
          isActive: isVisible,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (canvasId != null) ...<Widget>[
                const CanvasLeftRail(),
                CanvasLeftRailPanel(canvasId: canvasId),
              ],
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
              if (canvasId != null) CanvasInspectorPanel(canvasId: canvasId),
            ],
          ),
        ),
      ),
    );
  }
}
