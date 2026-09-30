// 左栏项目面板的页签选中态（P4）：画布 / 资产 / 角色。
//
// 为什么不放面板本地 setState：检查器角色区的「管理」链接要把左栏切到角色页，
// 那是两棵子树之间的跨组件跳转，面板本地状态够不到。
// 为什么不 autoDispose：选中页是用户的阅读位置，切走画布再回来应当还在原页；
// 状态只有一个枚举，常驻代价可忽略。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左栏三页。顺序即 UI 上从左到右的顺序（索引直接喂给页签条）。
enum ProjectPanelTab { canvases, assets, characters }

final projectPanelTabProvider =
    NotifierProvider<ProjectPanelTabController, ProjectPanelTab>(
      ProjectPanelTabController.new,
      name: 'projectPanelTabProvider',
    );

class ProjectPanelTabController extends Notifier<ProjectPanelTab> {
  @override
  ProjectPanelTab build() => ProjectPanelTab.canvases;

  void select(ProjectPanelTab tab) => state = tab;
}
