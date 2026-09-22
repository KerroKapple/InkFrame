// ShellStatusBar：壳级状态栏 23px（稿 22 + 1px 上沿），surface4 底，11px fg5，项间 16。
//
// 内容随当前标签：画布 = 项目 · 画布 / N 节点 · M 边 / 选中 K；Studio = N 个项目；
// 其余标签只有右侧的存储路径 + 版本号。
//
// 【条件 watch】画布计数只在 canvasId != null 时 watch 节点 / 边控制器——与画布标签体
// 同条件，不额外炸开 boot 级测试的密封面；Studio 的项目数走 workspaceProjectsProvider
//（外壳测试已密封为空表）。版本号 FutureProvider 失败（无平台通道）时留空。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/package_info.dart';
import '../../../core/di/paths.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_edges_controller.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../../canvas/providers/canvas_selection_controller.dart';
import '../../canvas/providers/current_canvas_name.dart';
import '../../studio/models/project_with_canvases.dart';
import '../../studio/providers/workspace_projects_provider.dart';
import '../models/shell_state.dart';
import '../providers/shell_controller.dart';

class ShellStatusBar extends ConsumerWidget {
  const ShellStatusBar({super.key});

  /// 稿是 content-box：height 22 + border-top 1。
  static const double height = 23;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final ShellState s = ref.watch(shellControllerProvider);
    final TextStyle style = t.meta.copyWith(color: c.fg5);

    final List<String> left = <String>[];
    if (s.tab == ShellTab.canvas && s.canvasId != null) {
      final String canvasId = s.canvasId!;
      final String canvasName = ref.watch(currentCanvasNameProvider).valueOrNull ?? l.canvasDefaultName;
      left.add(s.project == null ? canvasName : '${s.project!.name} · $canvasName');
      final int nodes =
          (ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[]).length;
      final int edges =
          (ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ?? const <CanvasEdge>[]).length;
      left.add(l.statusBarNodesEdges(nodes, edges));
      final int selected = ref.watch(canvasSelectionControllerProvider(canvasId).select((Set<String> x) => x.length));
      if (selected > 0) left.add(l.statusBarSelected(selected));
    } else if (s.tab == ShellTab.studio) {
      final int projects =
          (ref.watch(workspaceProjectsProvider).valueOrNull ?? const <ProjectWithCanvases>[]).length;
      left.add(l.statusBarProjects(projects));
    }

    final String storage = ref.watch(appPathsProvider).projects.path;
    final String version = ref.watch(packageInfoProvider).valueOrNull?.version ?? '';

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < left.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: InkSpacing.md),
            Flexible(child: Text(left[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          ],
          const Spacer(),
          Flexible(
            child: Text(l.statusBarStorage(storage), maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
          if (version.isNotEmpty) ...<Widget>[
            const SizedBox(width: InkSpacing.md),
            Text('v$version', style: t.mono.copyWith(color: c.fg5)),
          ],
        ],
      ),
    );
  }
}
