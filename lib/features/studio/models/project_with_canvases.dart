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
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String name;

  /// 项目真实创建时间（UTC），来自 projects.created_at。
  final DateTime createdAt;

  /// 最近修改时间（UTC），来自 projects.updated_at——Studio 卡片「N 小时前」与排序的数据源；
  /// 缺失时回落 createdAt。
  final DateTime updatedAt;
  final List<CanvasRef> canvases;
}

class CanvasRef {
  const CanvasRef({required this.id, required this.name});

  final String id;
  final String name;
}
