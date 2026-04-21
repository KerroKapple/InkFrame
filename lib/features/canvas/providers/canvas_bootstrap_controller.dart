// CanvasBootstrapController — 开发期的样例画布创建入口。
//
// 当 currentCanvasIdProvider 为 null 时，用户可以点 "新建示例画布"，本 Controller
// 创建一个示例 Project + Canvas，并把 currentCanvasIdProvider 置为新画布 id。
//
// 正式的项目/画布管理 UI 后续 sprint 重做；本 Controller 仅为让 T4 生成闭环
// 端到端跑通的 dev 入口。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import 'current_canvas_id.dart';

final canvasBootstrapControllerProvider = Provider.autoDispose(
  CanvasBootstrapController.new,
  name: 'canvasBootstrapControllerProvider',
);

class CanvasBootstrapController {
  CanvasBootstrapController(this._ref);

  final Ref _ref;

  /// 创建示例 Project + Canvas 并切换到该画布。返回新画布 id。
  Future<String> createSample({
    required String projectName,
    required String canvasName,
  }) async {
    final projects = await _ref.read(projectRepositoryProvider.future);
    final canvases = await _ref.read(canvasRepositoryProvider.future);
    final projectId = await projects.create(name: projectName);
    final canvasId = await canvases.create(
      projectId: projectId,
      name: canvasName,
    );
    _ref.read(currentCanvasIdProvider.notifier).state = canvasId;
    return canvasId;
  }
}
