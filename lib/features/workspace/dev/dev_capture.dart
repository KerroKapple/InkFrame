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
import 'package:flutter/services.dart' show ByteData, Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/di/database.dart';
import '../../../core/di/file_resolver.dart';
import '../../../core/di/repositories.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/unit_of_work.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../theme/tokens.dart';
import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_selection_controller.dart';
import '../../gallery/models/gallery_item.dart';
import '../../gallery/models/gallery_selection.dart';
import '../../gallery/providers/gallery_filter.dart';
import '../../gallery/providers/gallery_selection.dart';
import '../../gallery/util/gallery_meta.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../../studio/providers/workspace_projects_provider.dart';
import '../models/gallery_fixture.dart';
import '../models/workspace_fixture.dart';

const String kCaptureOut = String.fromEnvironment('INKFRAME_CAPTURE_OUT');
const int kCaptureDelayMs = int.fromEnvironment(
  'INKFRAME_CAPTURE_DELAY_MS',
  defaultValue: 12000,
);
const bool kSeedFixture = bool.fromEnvironment('INKFRAME_SEED_FIXTURE');
/// 截哪一屏：canvas（默认）/ gallery（再播 Screens 稿第 2 屏的 15 个产物并打开画廊标签）。
const String kCaptureScreen = String.fromEnvironment('INKFRAME_CAPTURE_SCREEN', defaultValue: 'canvas');

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
    if (kSeedFixture) {
      final WorkspaceFixtureIds ids = await seedWorkspaceFixture(ref);
      if (kCaptureScreen == 'gallery') await seedGalleryFixture(ref, ids);
    }
    if (kCaptureOut.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: kCaptureDelayMs));
      await _capture();
    }
  }

  Future<void> _capture() async {
    final RenderRepaintBoundary boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
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

/// 播种结果：打开画布 / 选中节点要用的三个 id。
typedef WorkspaceFixtureIds = ({
  String projectId,
  String canvasId,
  String videoId,
});

/// 把 GalleryFixture 的 15 个产物写进画布 02（远离画布视口的位置）：
/// 名称取稿上原文；003 / 006 是视频（00:04:08 / 00:05:00），003 在叙事链上（分镜 → 它）；
/// 缩略图是按 thumbPlaceholderGradients 现画的 PNG。然后打开画廊标签，范围筛到画布 02，
/// 选中 003 与 008（稿上就是这两项）。
Future<void> seedGalleryFixture(WidgetRef ref, WorkspaceFixtureIds ids) async {
  final UnitOfWork uow = await ref.read(unitOfWorkProvider.future);
  final FileResolverService files = ref.read(fileResolverServiceProvider);
  const List<String> names = GalleryFixture.names;
  final String shot = await uow.run((RepositoryScope s) => s.nodes.create(
        canvasId: ids.canvasId,
        type: CanvasNodeType.shot.name,
        nodeRole: NodeRole.config.name,
        label: '镜头 01 · 分镜描述',
        positionX: 0,
        positionY: 3000,
        typeConfig: <String, Object?>{'shot_notes': WorkspaceFixture.promptText},
      ));
  // 倒着建、每个产物单独一个事务：画廊按 createdAt 倒序，而 PG 的 now() 是事务开始时刻——
  // 同一事务里 15 条 created_at 全等，排序会退化成按路径。
  for (int i = names.length - 1; i >= 0; i--) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await uow.run((RepositoryScope s) async {
      final bool video = i == 2 || i == 5;
      final String stem = 'g${i.toString().padLeft(2, '0')}';
      final String cfg = await s.nodes.create(
        canvasId: ids.canvasId,
        type: video ? CanvasNodeType.video.name : CanvasNodeType.image.name,
        nodeRole: NodeRole.config.name,
        label: names[i],
        positionX: 300.0 * i,
        positionY: 3000,
        typeConfig: <String, Object?>{
          'provider_id': video ? 'kling-v3' : 'gemini-image',
          'prompt': WorkspaceFixture.promptText,
          if (video) 'duration_ms': i == 2 ? 248000 : 300000,
          if (video) 'camera': CameraMovement.pushIn.name,
        },
      );
      final String thumb = 'thumbs/$stem.png';
      await s.nodes.create(
        canvasId: ids.canvasId,
        type: video ? CanvasNodeType.video.name : CanvasNodeType.image.name,
        nodeRole: NodeRole.result.name,
        sourceNodeId: cfg,
        positionX: 300.0 * i,
        positionY: 3300,
        typeConfig: video
            ? <String, Object?>{
                'video_url': 'videos/$stem.mp4',
                'duration_ms': i == 2 ? 248000 : 300000,
                'thumbnail_url': thumb,
              }
            : <String, Object?>{'image_url': thumb},
      );
      if (i == 2) {
        await s.edges.create(canvasId: ids.canvasId, sourceNodeId: shot, targetNodeId: cfg, edgeType: 'narrative');
      }
    });
  }
  // 缩略图文件：160° 渐变 PNG（稿上 tk[i % 8]）。
  for (int i = 0; i < names.length; i++) {
    final String stem = 'g${i.toString().padLeft(2, '0')}';
    final File f = files.resolve(projectId: ids.projectId, canvasId: ids.canvasId, relativePath: 'thumbs/$stem.png');
    f.parent.createSync(recursive: true);
    await f.writeAsBytes(await _gradientPng(InkPalette.thumbPlaceholderGradients[i % 8]));
  }
  ref.read(shellControllerProvider.notifier).openGallery(
        ProjectRef(id: ids.projectId, name: WorkspaceFixture.breadcrumb[1]),
      );
  ref.read(galleryFilterProvider(ids.projectId).notifier).state = GalleryFilter(canvasId: ids.canvasId);
  GalleryItem item(int i, {bool video = false}) => GalleryItem(
        kind: video ? GalleryItemKind.video : GalleryItemKind.image,
        relativePath: video ? 'videos/g${i.toString().padLeft(2, '0')}.mp4' : 'thumbs/g${i.toString().padLeft(2, '0')}.png',
        canvasId: ids.canvasId,
        canvasName: '',
        nodeId: '',
        createdAt: DateTime.now(),
      );
  ref.read(gallerySelectionProvider(ids.projectId).notifier).state =
      GallerySelection.none.select(galleryItemKey(item(7))).toggle(galleryItemKey(item(2, video: true)));
}

Future<Uint8List> _gradientPng((Color, Color) g) async {
  const Size size = Size(320, 180);
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final Canvas canvas = Canvas(rec);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[g.$1, g.$2])
          .createShader(Offset.zero & size),
  );
  final ui.Image img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final ByteData? bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// 把 WorkspaceFixture 那一屏写进库并打开画布 02。节点位置 / 名称 / 类型 / 边角色都取稿上原文。
Future<WorkspaceFixtureIds> seedWorkspaceFixture(WidgetRef ref) async {
  final UnitOfWork uow = await ref.read(unitOfWorkProvider.future);
  final WorkspaceFixtureIds ids = await uow.run(seedWorkspaceFixtureInto);
  // 项目列表在播种前已算过一次（空表），刷新它，项目面板的画布树才有内容。
  ref.invalidate(workspaceProjectsProvider);
  ref
      .read(shellControllerProvider.notifier)
      .openCanvas(
        ids.canvasId,
        withProject: ProjectRef(
          id: ids.projectId,
          name: WorkspaceFixture.breadcrumb[1],
        ),
      );
  // 让节点控制器先加载完再选中，否则提示词条 / 检查器拿不到节点。
  await Future<void>.delayed(const Duration(seconds: 2));
  ref
      .read(canvasSelectionControllerProvider(ids.canvasId).notifier)
      .select(ids.videoId);
  return ids;
}

/// 只做写库这一步（与仓储实现无关）：真机截图走 PG，画布 golden 走内存仓储，
/// 两边播的是同一份稿数据。
Future<WorkspaceFixtureIds> seedWorkspaceFixtureInto(RepositoryScope s) async {
  final String projectId = await s.projects.create(
    name: WorkspaceFixture.breadcrumb[1],
  );
  final List<String> canvasIds = <String>[];
  for (final WsCanvasEntry cv in WorkspaceFixture.canvases) {
    canvasIds.add(await s.canvas.create(projectId: projectId, name: cv.name));
  }
  final String canvasId = canvasIds[1];
  // 两条泳道：稿上 A 带 top 20 高 380 → 400 一道；B 紧随其后。
  final String laneA = await s.styleLanes.create(
    canvasId: canvasId,
    label: WorkspaceFixture.laneLabels[0],
    sortOrder: 0,
  );
  final String laneB = await s.styleLanes.create(
    canvasId: canvasId,
    label: WorkspaceFixture.laneLabels[1],
    sortOrder: 1,
  );
  final Map<String, String> nodeIds = <String, String>{};
  for (final WsNode n in WorkspaceFixture.nodes) {
    final CanvasNodeType type = switch (n.kind) {
      'shot' => CanvasNodeType.shot,
      'video' => CanvasNodeType.video,
      _ => CanvasNodeType.image,
    };
    final Map<String, Object?> cfg = switch (type) {
      CanvasNodeType.shot => <String, Object?>{
        'shot_notes': n.thumbLabel,
        'duration_ms': 5000,
        'camera': CameraMovement.pushIn.name,
      },
      CanvasNodeType.video => <String, Object?>{
        'prompt': WorkspaceFixture.promptText,
        'provider_id': 'kling-v3',
        'duration_ms': 5000,
        'camera': CameraMovement.pushIn.name,
      },
      _ => <String, Object?>{
        'prompt': n.thumbLabel,
        'provider_id': 'gemini-image',
      },
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
  await s.edges.create(
    canvasId: canvasId,
    sourceNodeId: id(0),
    targetNodeId: id(1),
    edgeType: 'data',
  );
  await s.edges.create(
    canvasId: canvasId,
    sourceNodeId: id(0),
    targetNodeId: id(2),
    edgeType: 'data',
  );
  await s.edges.create(
    canvasId: canvasId,
    sourceNodeId: id(1),
    targetNodeId: id(3),
    edgeType: 'data',
    role: CanvasEdgeMapping.roleToDb(EdgeRole.firstFrame),
  );
  await s.edges.create(
    canvasId: canvasId,
    sourceNodeId: id(2),
    targetNodeId: id(3),
    edgeType: 'data',
    role: CanvasEdgeMapping.roleToDb(EdgeRole.lastFrame),
  );
  await s.edges.create(
    canvasId: canvasId,
    sourceNodeId: id(4),
    targetNodeId: id(5),
    edgeType: 'data',
  );
  return (projectId: projectId, canvasId: canvasId, videoId: id(3));
}
