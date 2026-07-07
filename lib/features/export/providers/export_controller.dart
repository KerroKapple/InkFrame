// ExportController — 视频导出编排（导出 UI 首切片，features/export 模块首件）。
//
// 路径根换算：result 节点 type_config.video_url 是**画布根**相对路径
// （FileResolverService.resolve(projectId, canvasId, rel) 语义），而
// VideoExportService.concat 收**项目根**相对路径——此处统一补
// `canvases/<canvasId>/` 前缀（projectRelativeVideoPath）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/video_export.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../canvas/models/canvas_node.dart';

/// 导出状态机：idle / busy / success / failure。
sealed class ExportVideoState {
  const ExportVideoState();
}

class ExportVideoIdle extends ExportVideoState {
  const ExportVideoIdle();
}

class ExportVideoBusy extends ExportVideoState {
  const ExportVideoBusy();
}

class ExportVideoSuccess extends ExportVideoState {
  const ExportVideoSuccess(this.relativePath);

  /// 导出产物的项目根相对路径（`exports/<name>.mp4`）。
  final String relativePath;
}

class ExportVideoFailure extends ExportVideoState {
  const ExportVideoFailure(this.error);
  final InkError error;
}

/// 画布相对 video_url → concat 的项目根相对路径。
String projectRelativeVideoPath({
  required String canvasId,
  required String videoUrl,
}) =>
    'canvases/$canvasId/$videoUrl';

final exportControllerProvider =
    AutoDisposeNotifierProvider<ExportController, ExportVideoState>(
  ExportController.new,
  name: 'exportControllerProvider',
);

class ExportController extends AutoDisposeNotifier<ExportVideoState> {
  @override
  ExportVideoState build() => const ExportVideoIdle();

  bool get isBusy => state is ExportVideoBusy;

  /// 按给定顺序导出 [nodes]（video result 节点）。
  /// videoUrl / canvasId 缺失的节点跳过（UI 入口已过滤，这里防御性兜底）。
  Future<void> export({
    required String projectId,
    required List<CanvasNode> nodes,
    String? outputBaseName,
  }) async {
    if (isBusy) return;
    final inputs = <String>[
      for (final n in nodes)
        if (n.canvasId != null && n.videoUrl != null)
          projectRelativeVideoPath(
            canvasId: n.canvasId!,
            videoUrl: n.videoUrl!,
          ),
    ];
    final service = ref.read(videoExportServiceProvider);
    // 导出期间挂起 autoDispose：对话框中途关闭也把状态机走完。
    final link = ref.keepAlive();
    state = const ExportVideoBusy();
    try {
      final out = await service.concat(
        projectId: projectId,
        inputRelativePaths: inputs,
        outputBaseName: outputBaseName,
      );
      state = ExportVideoSuccess(out);
    } on InkError catch (e) {
      state = ExportVideoFailure(e);
    } on PathSecurityError catch (e, st) {
      // 理论上被 UI 预校验挡住；防御性翻译为 invalidParameter。
      state = ExportVideoFailure(
        ProviderError(
          code: InkErrorCode.invalidParameter,
          cause: e,
          stackTrace: st,
          extra: const <String, Object?>{'reason': 'path_security'},
        ),
      );
    } finally {
      link.close();
    }
  }
}
