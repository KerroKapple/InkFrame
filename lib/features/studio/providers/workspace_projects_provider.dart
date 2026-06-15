// workspaceProjectsProvider：工作库列表装配。
//
// 两条固定查询：projects.listAll() + canvases.listByProjects(ids)，
// 项目数无关——不做每项目串行 listByProject 的 N+1。
// 坏行策略：id / name / created_at 任一缺失或类型不符 → 跳过该行。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../models/project_with_canvases.dart';

final workspaceProjectsProvider =
    FutureProvider.autoDispose<List<ProjectWithCanvases>>((ref) async {
  final projects = await ref.watch(projectRepositoryProvider.future);
  final canvases = await ref.watch(canvasRepositoryProvider.future);
  final rows = await projects.listAll();

  final ids = <String>[
    for (final row in rows)
      if (row['id'] != null) row['id']!.toString(),
  ];
  final canvasRows = ids.isEmpty
      ? const <Map<String, Object?>>[]
      : await canvases.listByProjects(ids);

  final byProject = <String, List<CanvasRef>>{};
  for (final c in canvasRows) {
    final pid = c['project_id']?.toString();
    final cid = c['id']?.toString();
    if (pid == null || cid == null) continue;
    byProject.putIfAbsent(pid, () => <CanvasRef>[]).add(
          CanvasRef(id: cid, name: c['name']?.toString() ?? ''),
        );
  }

  final result = <ProjectWithCanvases>[];
  for (final row in rows) {
    final id = row['id']?.toString();
    final name = row['name']?.toString();
    final createdAt = row['created_at'];
    if (id == null || name == null || createdAt is! DateTime) continue;
    result.add(
      ProjectWithCanvases(
        id: id,
        name: name,
        createdAt: createdAt,
        canvases: byProject[id] ?? const <CanvasRef>[],
      ),
    );
  }
  return result;
});
