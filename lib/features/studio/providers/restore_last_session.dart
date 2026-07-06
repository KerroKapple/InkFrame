// 启动恢复上次会话：偏好里有 lastCanvasId/lastProjectId → 校验两者均未软删
// → 置 currentCanvasId 直接回画布。任一无效则清掉记录、停留 Studio。
//
// best-effort：PG 未就绪/查询失败不阻断启动（吞 InkError 静默留在首页）；
// 恢复完成前用户已手动打开画布时不抢占。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../canvas/providers/current_canvas_id.dart';

final restoreLastSessionProvider = FutureProvider<void>((ref) async {
  final prefs = ref.read(preferencesServiceProvider);
  final saved = prefs.current;
  final canvasId = saved.lastCanvasId;
  final projectId = saved.lastProjectId;
  if (canvasId == null || projectId == null) return;

  final bool valid;
  try {
    final canvases = await ref.read(canvasRepositoryProvider.future);
    final projects = await ref.read(projectRepositoryProvider.future);
    // findById 均带 deleted_at IS NULL 过滤：软删的画布/项目直接判无效。
    final canvasRow = await canvases.findById(canvasId);
    final projectRow = await projects.findById(projectId);
    valid = canvasRow != null &&
        projectRow != null &&
        canvasRow['project_id'] == projectId;
  } on InkError catch (_) {
    return; // 存储未就绪/失败：不恢复也不清记录，下次启动再试。
  }

  if (!valid) {
    await prefs.update((p) => p.copyWith(clearLastCanvas: true));
    return;
  }
  if (ref.read(currentCanvasIdProvider) == null) {
    ref.read(currentCanvasIdProvider.notifier).state = canvasId;
  }
}, name: 'restoreLastSessionProvider');
