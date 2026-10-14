// CanvasLeftRailPanel：左栏面板宿主（画布重设计稿 main.js「左栏面板」）。
//
// 展开时 240 + 1px 右沿（borderStrong）、surface3 底，紧贴导航条右侧；收起时什么都不占
// （SizedBox.shrink）——舞台左沿直接贴上导航条右沿。
// 三页：大纲（OutlinePanel）/ 素材（AssetsPanel）/ 角色（CharacterLibraryPanel）。角色库是项目级的：
// 没有活动项目时没有数据源，只画面板头 + 一行说明，不画空壳。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../shell/models/shell_state.dart';
import '../../../shell/providers/active_project.dart';
import '../../providers/left_rail_state.dart';
import '../character_library_panel.dart';
import 'assets_panel.dart';
import 'left_panel_parts.dart';
import 'outline_panel.dart';

class CanvasLeftRailPanel extends ConsumerWidget {
  const CanvasLeftRailPanel({super.key, required this.canvasId});

  final String canvasId;

  /// 稿是 content-box：width 240 + border-right 1。
  static const double width = 241;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LeftRailState rail = ref.watch(leftRailProvider);
    if (!rail.expanded) return const SizedBox.shrink();
    final c = context.inkColors;
    final ProjectRef? project = ref.watch(activeProjectProvider);
    return Container(
      width: width,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: switch (rail.page) {
        LeftRailPage.outline => OutlinePanel(canvasId: canvasId),
        LeftRailPage.assets => AssetsPanel(canvasId: canvasId),
        LeftRailPage.characters => project == null
            ? const _CharactersWithoutProject()
            : CharacterLibraryPanel(projectId: project.id),
      },
    );
  }
}

/// 没有活动项目时的角色页：面板头照画，正文一行说明。
class _CharactersWithoutProject extends StatelessWidget {
  const _CharactersWithoutProject();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LeftPanelHeader(title: l.leftRailCharacters),
        Expanded(child: LeftPanelNote(l.leftRailCharactersNoProject)),
      ],
    );
  }
}
