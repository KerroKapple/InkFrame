// ProjectWithCanvases / CanvasRef：Studio Home / LibrarySidebar 共用的
// 工作库列表数据模型，强类型流过 sidebar / grid。
//
// 纯模型，无 Riverpod 依赖；workspaceProjectsProvider 在
// providers/workspace_projects_provider.dart。
class ProjectWithCanvases {
  const ProjectWithCanvases({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.canvases,
  });

  final String id;
  final String name;

  /// 项目真实创建时间（UTC），来自 projects.created_at —— 卡片 meta 行的数据源。
  final DateTime createdAt;
  final List<CanvasRef> canvases;
}

class CanvasRef {
  const CanvasRef({required this.id, required this.name});

  final String id;
  final String name;
}
