// ProjectWithCanvases / CanvasRef：Studio Home / LibrarySidebar 共用的
// 工作库列表数据模型，强类型流过 sidebar / grid。
//
// workspaceProjectsProvider 在此处定义。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';

class ProjectWithCanvases {
  const ProjectWithCanvases({
    required this.id,
    required this.name,
    required this.canvases,
  });

  final String id;
  final String name;
  final List<CanvasRef> canvases;
}

class CanvasRef {
  const CanvasRef({required this.id, required this.name});

  final String id;
  final String name;
}

final workspaceProjectsProvider =
    FutureProvider.autoDispose<List<ProjectWithCanvases>>((ref) async {
  final projects = await ref.watch(projectRepositoryProvider.future);
  final canvases = await ref.watch(canvasRepositoryProvider.future);
  final rows = await projects.listAll();
  final result = <ProjectWithCanvases>[];
  for (final row in rows) {
    final id = row['id']?.toString();
    final name = row['name']?.toString();
    if (id == null || name == null) continue;
    final list = await canvases.listByProject(id);
    result.add(
      ProjectWithCanvases(
        id: id,
        name: name,
        canvases: list
            .map(
              (c) => CanvasRef(
                id: c['id']!.toString(),
                name: c['name']?.toString() ?? '',
              ),
            )
            .toList(),
      ),
    );
  }
  return result;
});
