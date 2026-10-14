// CanvasSwitcher：大纲面板头右侧的画布切换胶囊——「当前画布名 ▾」（稿 main.js panelOutline 头部）。
//
// 22 高（+ 上下 1px 边）、outline 边、圆角 3、fg3、11 号字。点开是本项目的画布列表，当前画布打勾；
// 点另一张 = openCanvas。数据与行为照搬原 canvas_project_panel.dart 的画布树：activeProject 下的
// 画布（workspaceProjectsProvider）。
//
// openCanvas **不带 withProject**：这是在同一项目内换画布，沿用 state.project 正是要的语义——
// 本文件登记在 test/quality/shell_transition_reachability_test.dart 的同项目豁免名单里。
// 没有活动项目时大纲面板不画本胶囊（调用方判断）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/primitives/ink_activatable.dart';
import '../../../../theme/tokens.dart';
import '../../../shell/models/shell_state.dart';
import '../../../shell/providers/shell_controller.dart';
import '../../../studio/models/project_with_canvases.dart';
import '../../../studio/providers/workspace_projects_provider.dart';
import '../../providers/current_canvas_name.dart';

class CanvasSwitcher extends ConsumerWidget {
  const CanvasSwitcher({
    super.key,
    required this.canvasId,
    required this.project,
  });

  final String canvasId;
  final ProjectRef project;

  /// 胶囊本身的测试锚点。
  static const Key pillKey = ValueKey<String>('leftRail-canvas-switcher');

  /// 菜单里某张画布那一项的测试锚点。
  static Key itemKey(String canvasId) =>
      ValueKey<String>('leftRail-canvas-switcher-$canvasId');

  /// 稿 content-box：22 + 上下 1px 边。
  static const double height = 24;

  /// 菜单项高：Material 默认 48 与本稿密度差一倍（与角色库 ⋯ 菜单同一取值）。
  static const double _menuItemHeight = 26;

  /// 当前画布那一项前面的勾占位宽（其余项留同样的空，名字对齐）。
  static const double _checkWidth = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final String raw = ref.watch(currentCanvasNameProvider).valueOrNull ?? '';
    final String name = raw.isEmpty ? l.canvasDefaultName : raw;
    // watch 而不是到点开时才 read：autoDispose 的列表没人订阅就没有值，菜单会是空的。
    final List<CanvasRef> canvases = <CanvasRef>[
      for (final ProjectWithCanvases p
          in ref.watch(workspaceProjectsProvider).valueOrNull ??
              const <ProjectWithCanvases>[])
        if (p.id == project.id) ...p.canvases,
    ];

    return Builder(
      // 菜单要贴着胶囊往下弹：取胶囊自己的 context 做锚点。
      builder: (BuildContext anchor) => InkActivatable(
        key: pillKey,
        // 列表还没到（或项目下没有画布）时没有可选的项：不可点，也不可聚焦。
        onTap: canvases.isEmpty
            ? null
            : () => _showCanvasMenu(anchor, ref, canvases),
        semanticLabel: name,
        tooltip: l.leftRailSwitchCanvas,
        focusRingRadius: BorderRadius.circular(InkRadius.s3),
        builder: (BuildContext context, bool hovered, bool focused) =>
            Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
          decoration: BoxDecoration(
            color: hovered ? c.surface4 : null,
            border: Border.all(color: c.outline),
            borderRadius: BorderRadius.circular(InkRadius.s3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.meta.copyWith(color: c.fg3),
                ),
              ),
              const SizedBox(width: InkSpacing.s6),
              Text('▾', style: t.meta.copyWith(color: c.fg3)),
            ],
          ),
        ),
      ),
    );
  }

  /// 画布列表菜单：贴着胶囊下沿弹。选中另一张 = openCanvas（同项目，不带 withProject）。
  Future<void> _showCanvasMenu(
    BuildContext anchor,
    WidgetRef ref,
    List<CanvasRef> canvases,
  ) async {
    final RenderBox button = anchor.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    final Offset below = Offset(0, button.size.height);
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(below, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(below), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final InkColors c = anchor.inkColors;
    final t = anchor.inkTypography;
    final String fallback = anchor.l10n.canvasDefaultName;
    final String? picked = await showMenu<String>(
      context: anchor,
      position: position,
      color: c.surface4,
      items: <PopupMenuEntry<String>>[
        for (final CanvasRef cv in canvases)
          PopupMenuItem<String>(
            key: itemKey(cv.id),
            value: cv.id,
            height: _menuItemHeight,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: _checkWidth,
                  child: cv.id == canvasId
                      ? Text('✓', style: t.meta.copyWith(color: c.accent))
                      : null,
                ),
                const SizedBox(width: InkSpacing.sm),
                Flexible(
                  child: Text(
                    cv.name.isEmpty ? fallback : cv.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(
                      color: cv.id == canvasId ? c.fg1 : c.fg2,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (picked == null || picked == canvasId || !anchor.mounted) return;
    ref.read(shellControllerProvider.notifier).openCanvas(picked);
  }
}
