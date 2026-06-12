// StudioProjectsController：Studio 项目创建的业务编排，从 widget 抽离。
//
// create 编排（项目 + 首画布）必须原子：画布建失败时补偿删除刚建的项目，
// 不留无画布的半成品；补偿本身失败则项目残留，由列表如实展示。
// 错误只走 InkError 链，原样冒泡给调用方渲染。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../providers/workspace_projects_provider.dart';

final studioProjectsControllerProvider =
    Provider.autoDispose<StudioProjectsController>(
  (ref) => StudioProjectsController(ref),
  name: 'studioProjectsControllerProvider',
);

class StudioProjectsController {
  StudioProjectsController(this._ref);

  final Ref _ref;

  /// 建项目 + 首画布，成功后刷新工作库列表。
  Future<void> createProject({
    required String name,
    required String firstCanvasName,
  }) async {
    final projects = await _ref.read(projectRepositoryProvider.future);
    final canvases = await _ref.read(canvasRepositoryProvider.future);
    final projectId = await projects.create(name: name);
    try {
      await canvases.create(projectId: projectId, name: firstCanvasName);
    } on InkError {
      try {
        await projects.hardDelete(projectId);
      } on InkError {
        // 补偿失败：保留原始错误语义，项目残留交给列表展示。
      }
      rethrow;
    }
    _ref.invalidate(workspaceProjectsProvider);
  }
}
