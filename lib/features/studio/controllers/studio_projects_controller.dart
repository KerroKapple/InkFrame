// StudioProjectsController：Studio 项目创建的业务编排，从 widget 抽离。
//
// create 编排（项目 + 首画布）走单个事务：任一步失败整体回滚，不留半成品。
// 错误只走 InkError 链，原样冒泡给调用方渲染。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/di/repositories.dart';
import '../providers/workspace_projects_provider.dart';

final studioProjectsControllerProvider =
    Provider.autoDispose<StudioProjectsController>(
  (ref) => StudioProjectsController(ref),
  name: 'studioProjectsControllerProvider',
);

class StudioProjectsController {
  StudioProjectsController(this._ref);

  final Ref _ref;

  /// 建项目 + 首画布——单事务原子：任一步失败整体回滚，成功后刷新工作库列表。
  Future<void> createProject({
    required String name,
    required String firstCanvasName,
  }) async {
    final uow = await _ref.read(unitOfWorkProvider.future);
    await uow.run((scope) async {
      final projectId = await scope.projects.create(name: name);
      await scope.canvas.create(projectId: projectId, name: firstCanvasName);
    });
    _ref.invalidate(workspaceProjectsProvider);
  }

  /// 重命名项目（单行 update）；成功后刷新工作库列表。错误走 InkError 冒泡。
  Future<void> renameProject({
    required String id,
    required String name,
  }) async {
    final repo = await _ref.read(projectRepositoryProvider.future);
    await repo.update(id, <String, Object?>{ProjectCol.name: name});
    _ref.invalidate(workspaceProjectsProvider);
  }

  /// 删除项目（软删——移出库、可恢复，不级联硬删画布）；成功后刷新列表。
  Future<void> deleteProject(String id) async {
    final repo = await _ref.read(projectRepositoryProvider.future);
    await repo.softDelete(id);
    _ref.invalidate(workspaceProjectsProvider);
  }

  /// 重命名画布（单行 update）；成功后刷新工作库列表。错误走 InkError 冒泡。
  Future<void> renameCanvas({
    required String id,
    required String name,
  }) async {
    final repo = await _ref.read(canvasRepositoryProvider.future);
    await repo.update(id, <String, Object?>{CanvasCol.name: name});
    _ref.invalidate(workspaceProjectsProvider);
  }

  /// 删除画布（软删——列表不再展示、可恢复）；成功后刷新列表。
  Future<void> deleteCanvas(String id) async {
    final repo = await _ref.read(canvasRepositoryProvider.future);
    await repo.softDelete(id);
    _ref.invalidate(workspaceProjectsProvider);
  }

  /// 从回收站恢复项目（清 deleted_at）；成功后刷新工作库列表（LB-15）。
  Future<void> restoreProject(String id) async {
    final repo = await _ref.read(projectRepositoryProvider.future);
    await repo.restore(id);
    _ref.invalidate(workspaceProjectsProvider);
  }

  /// 从回收站恢复画布；成功后刷新工作库列表（LB-15）。
  Future<void> restoreCanvas(String id) async {
    final repo = await _ref.read(canvasRepositoryProvider.future);
    await repo.restore(id);
    _ref.invalidate(workspaceProjectsProvider);
  }
}
