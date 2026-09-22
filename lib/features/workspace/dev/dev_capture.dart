// 接线验收工具（B 路径第二步，用户要求：接完 provider 再截一张同尺寸图做像素比对）。
//
// 两个编译期开关，都不设时 [DevCaptureFrame] 原样返回 child，零行为差异：
//   --dart-define=INKFRAME_CAPTURE_OUT=D:/x.png   把整个 app 固定在 1600×1000 逻辑像素里渲染
//                                                （FittedBox 缩放显示），首帧后 INKFRAME_CAPTURE_DELAY_MS
//                                                （默认 12000）按 pixelRatio=1 截 RepaintBoundary 落盘并退出。
//   --dart-define=INKFRAME_SEED_FIXTURE=1          DB 就绪后把 Workspace v2 稿上那一屏的数据
//                                                （山径破晓 / 镜头 01–04 / 两条泳道 / 五条边）写进库，
//                                                打开画布 02 并选中「镜头 03 · 图转视频」。
// 配合把 LOCALAPPDATA 指到临时目录，就能在一个全新的库上复现稿的画面；只作开发验收，不进产品路径。
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/di/database.dart';
import '../../../core/di/repositories.dart';
import '../../../core/interfaces/unit_of_work.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../theme/tokens.dart';
import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_selection_controller.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../../studio/providers/workspace_projects_provider.dart';
import '../models/workspace_fixture.dart';

const String kCaptureOut = String.fromEnvironment('INKFRAME_CAPTURE_OUT');
const int kCaptureDelayMs = int.fromEnvironment('INKFRAME_CAPTURE_DELAY_MS', defaultValue: 12000);
const bool kSeedFixture = bool.fromEnvironment('INKFRAME_SEED_FIXTURE');

class DevCaptureFrame extends ConsumerStatefulWidget {
  const DevCaptureFrame({super.key, required this.child});
  final Widget child;

  static bool get enabled => kCaptureOut.isNotEmpty || kSeedFixture;

  @override
  ConsumerState<DevCaptureFrame> createState() => _DevCaptureFrameState();
}

class _DevCaptureFrameState extends ConsumerState<DevCaptureFrame> {
  final GlobalKey _boundary = GlobalKey();
  bool _kicked = false;

  @override
  void initState() {
    super.initState();
    if (!DevCaptureFrame.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _kick());
  }

  Future<void> _kick() async {
    if (_kicked) return;
    _kicked = true;
    // 等 DB 就绪（pool 可用 = 迁移完成）。
    await ref.read(pgMigratedPoolProvider.future);
    if (kSeedFixture) await seedWorkspaceFixture(ref);
    if (kCaptureOut.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: kCaptureDelayMs));
      await _capture();
    }
  }

  Future<void> _capture() async {
    final RenderRepaintBoundary boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(kCaptureOut).writeAsBytes(bytes!.buffer.asUint8List());
    // 走正常关窗 → AppTeardown（停 PG）；exit(0) 会把内嵌 PG 留成孤儿锁住数据目录。
    await windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    if (kCaptureOut.isEmpty) return widget.child;
    return ColoredBox(
      // 截图外的留白只是取景背景，不进 PNG；取深色底槽位，不另造颜色。
      color: InkPalette.surface0Dark,
      child: FittedBox(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _boundary,
          child: SizedBox(width: 1600, height: 1000, child: widget.child),
        ),
      ),
    );
  }
}

/// 把 WorkspaceFixture 那一屏写进库并打开画布 02。节点位置 / 名称 / 类型 / 边角色都取稿上原文。
Future<void> seedWorkspaceFixture(WidgetRef ref) async {
  final UnitOfWork uow = await ref.read(unitOfWorkProvider.future);
  final ({String projectId, String canvasId, String videoId}) ids = await uow.run((RepositoryScope s) async {
    final String projectId = await s.projects.create(name: WorkspaceFixture.breadcrumb[1]);
    final List<String> canvasIds = <String>[];
    for (final WsCanvasEntry cv in WorkspaceFixture.canvases) {
      canvasIds.add(await s.canvas.create(projectId: projectId, name: cv.name));
    }
    final String canvasId = canvasIds[1];
    // 两条泳道：稿上 A 带 top 20 高 380 → 400 一道；B 紧随其后。
    final String laneA = await s.styleLanes.create(canvasId: canvasId, label: WorkspaceFixture.laneLabels[0], sortOrder: 0);
    final String laneB = await s.styleLanes.create(canvasId: canvasId, label: WorkspaceFixture.laneLabels[1], sortOrder: 1);
    final Map<String, String> nodeIds = <String, String>{};
    for (final WsNode n in WorkspaceFixture.nodes) {
      final CanvasNodeType type = switch (n.kind) {
        'shot' => CanvasNodeType.shot,
        'video' => CanvasNodeType.video,
        _ => CanvasNodeType.image,
      };
      final Map<String, Object?> cfg = switch (type) {
        CanvasNodeType.shot => <String, Object?>{'shot_notes': n.thumbLabel, 'duration_ms': 5000, 'camera': CameraMovement.pushIn.name},
        CanvasNodeType.video => <String, Object?>{
            'prompt': WorkspaceFixture.promptText,
            'provider_id': 'kling-v3',
            'duration_ms': 5000,
            'camera': CameraMovement.pushIn.name,
          },
        _ => <String, Object?>{'prompt': n.thumbLabel, 'provider_id': 'gemini-image'},
      };
      nodeIds[n.name] = await s.nodes.create(
        canvasId: canvasId,
        type: type.name,
        nodeRole: NodeRole.config.name,
        label: n.name,
        laneId: n.y < 400 ? laneA : laneB,
        positionX: n.x,
        positionY: n.y,
        width: kNodeCardSize.width,
        height: kNodeCardSize.height,
        typeConfig: cfg,
      );
    }
    String id(int i) => nodeIds[WorkspaceFixture.nodes[i].name]!;
    // 稿上五条边：shot01→img01、shot01→img02、img01→video03（起始帧）、img02→video03（结束帧）、shot04→img04。
    await s.edges.create(canvasId: canvasId, sourceNodeId: id(0), targetNodeId: id(1), edgeType: 'data');
    await s.edges.create(canvasId: canvasId, sourceNodeId: id(0), targetNodeId: id(2), edgeType: 'data');
    await s.edges.create(canvasId: canvasId, sourceNodeId: id(1), targetNodeId: id(3), edgeType: 'data', role: CanvasEdgeMapping.roleToDb(EdgeRole.firstFrame));
    await s.edges.create(canvasId: canvasId, sourceNodeId: id(2), targetNodeId: id(3), edgeType: 'data', role: CanvasEdgeMapping.roleToDb(EdgeRole.lastFrame));
    await s.edges.create(canvasId: canvasId, sourceNodeId: id(4), targetNodeId: id(5), edgeType: 'data');
    return (projectId: projectId, canvasId: canvasId, videoId: id(3));
  });
  // 项目列表在播种前已算过一次（空表），刷新它，项目面板的画布树才有内容。
  ref.invalidate(workspaceProjectsProvider);
  ref.read(shellControllerProvider.notifier).openCanvas(
        ids.canvasId,
        withProject: ProjectRef(id: ids.projectId, name: WorkspaceFixture.breadcrumb[1]),
      );
  // 让节点控制器先加载完再选中，否则提示词条 / 检查器拿不到节点。
  await Future<void>.delayed(const Duration(seconds: 2));
  ref.read(canvasSelectionControllerProvider(ids.canvasId).notifier).select(ids.videoId);
}
