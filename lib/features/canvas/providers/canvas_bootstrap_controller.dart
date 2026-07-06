// CanvasBootstrapController — 开发期的样例画布创建入口。
//
// 当 currentCanvasIdProvider 为 null 时，用户可以点 "新建示例画布"，本 Controller
// 创建一个示例 Project + Canvas，并把 currentCanvasIdProvider 置为新画布 id。
//
// 正式的项目/画布管理 UI 后续 sprint 重做；本 Controller 仅为让 T4 生成闭环
// 端到端跑通的 dev 入口。

import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
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
  ///
  /// ME-27：本 provider 是 autoDispose，await 期间可能被 dispose——所有
  /// _ref.read 在入口同步完成，await 之后不再触 _ref。
  Future<String> createSample({
    required String projectName,
    required String canvasName,
  }) async {
    final projectsFuture = _ref.read(projectRepositoryProvider.future);
    final canvasesFuture = _ref.read(canvasRepositoryProvider.future);
    final currentCanvasId = _ref.read(currentCanvasIdProvider.notifier);
    final prefs = _ref.read(preferencesServiceProvider);
    final projects = await projectsFuture;
    final canvases = await canvasesFuture;
    final projectId = await projects.create(name: projectName);
    final canvasId = await canvases.create(
      projectId: projectId,
      name: canvasName,
    );
    currentCanvasId.state = canvasId;
    // 记住上次会话（fire-and-forget，服务内部吞盘错误）。
    unawaited(prefs.update(
      (p) => p.copyWith(lastCanvasId: canvasId, lastProjectId: projectId),
    ));
    return canvasId;
  }
}
