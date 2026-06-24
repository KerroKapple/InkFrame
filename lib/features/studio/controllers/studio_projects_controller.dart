// StudioProjectsController：Studio 项目创建的业务编排，从 widget 抽离。
//
// create 编排（项目 + 首画布）走单个事务：任一步失败整体回滚，不留半成品。
// 错误只走 InkError 链，原样冒泡给调用方渲染。
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}
