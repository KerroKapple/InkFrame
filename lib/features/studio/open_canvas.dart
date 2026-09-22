// 打开项目对应画布：有则开第一个（created_at ASC 契约序），无则建空白再开。
// createCanvas 注入便于单测；生产由 studio_home_screen 传入 canvasRepository.create。
import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/preferences.dart';
import '../shell/models/shell_state.dart';
import '../shell/providers/shell_controller.dart';
import 'models/project_with_canvases.dart';

typedef CanvasCreator = Future<String> Function(String projectId);

Future<void> openProjectCanvas(
  T Function<T>(ProviderListenable<T>) read,
  ProjectWithCanvases project, {
  required CanvasCreator createCanvas,
}) async {
  final String canvasId;
  if (project.canvases.isNotEmpty) {
    canvasId = project.canvases.first.id;
  } else {
    canvasId = await createCanvas(project.id); // 失败则抛，不 set
  }
  read(shellControllerProvider.notifier).openCanvas(
    canvasId,
    withProject: ProjectRef(id: project.id, name: project.name),
  );
  // 记住上次会话（fire-and-forget，服务内部吞盘错误），重启恢复见
  // restoreLastSessionProvider。
  unawaited(read(preferencesServiceProvider).update(
    (p) => p.copyWith(lastCanvasId: canvasId, lastProjectId: project.id),
  ));
}
