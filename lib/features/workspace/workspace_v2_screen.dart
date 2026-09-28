// Workspace v2 静态复刻页（B 路径）：1600×1000，菜单栏 30 → 标签栏 34 → 主体 → 渲染队列 172 → 状态栏 22。
// 主体三栏：工具条 36 | 项目面板 240 | 画布 flex | 检查器 300。数据全部来自 WorkspaceFixture。
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import 'widgets/ws_canvas_area.dart';
import 'widgets/ws_inspector.dart';
import 'widgets/ws_menu_bar.dart';
import 'widgets/ws_project_panel.dart';
import 'widgets/ws_render_queue.dart';
import 'widgets/ws_status_bar.dart';
import 'widgets/ws_tab_bar.dart';
import 'widgets/ws_tool_rail.dart';

class WorkspaceV2Screen extends StatelessWidget {
  const WorkspaceV2Screen({super.key});

  static const Size designSize = Size(1600, 1000);

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return DefaultTextStyle(
      style: context.inkTypography.body.copyWith(color: c.fg2),
      child: Container(
        width: designSize.width,
        height: designSize.height,
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.borderStrong),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            WsMenuBar(),
            WsTabBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  WsToolRail(),
                  WsProjectPanel(),
                  Expanded(child: WsCanvasArea()),
                  WsInspector(),
                ],
              ),
            ),
            WsRenderQueue(),
            WsStatusBar(),
          ],
        ),
      ),
    );
  }
}
