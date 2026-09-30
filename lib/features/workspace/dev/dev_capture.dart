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

import '../../../core/db/columns.dart';
import '../../../core/di/database.dart';
import '../../../core/di/file_resolver.dart';
import '../../../core/di/preferences.dart';
import '../../../core/di/repositories.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/unit_of_work.dart';
import '../../../core/models/app_preferences.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../core/models/shot_language.dart';
import '../../../theme/tokens.dart';
import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_selection_controller.dart';
import '../../gallery/models/gallery_item.dart';
import '../../gallery/models/gallery_selection.dart';
import '../../gallery/providers/gallery_filter.dart';
import '../../gallery/providers/gallery_selection.dart';
import '../../gallery/util/gallery_meta.dart';
import '../../settings/providers/settings_page.dart';
import '../../settings/providers/shell_keep_last_canvas_controller.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../../studio/providers/workspace_projects_provider.dart';
import '../models/gallery_fixture.dart';
import '../models/sequence_fixture.dart';
import '../models/studio_fixture.dart';
import '../models/workspace_fixture.dart';

const String kCaptureOut = String.fromEnvironment('INKFRAME_CAPTURE_OUT');
const int kCaptureDelayMs = int.fromEnvironment(
  'INKFRAME_CAPTURE_DELAY_MS',
  defaultValue: 12000,
);
const bool kSeedFixture = bool.fromEnvironment('INKFRAME_SEED_FIXTURE');
/// 截哪一屏：canvas（默认）/ gallery（再播 Screens 稿第 2 屏的 15 个产物并打开画廊标签）/ studio / settings（Studio + 设置浮层「API 密钥」页）
/// / sequence（再播 Timeline 稿的 8 镜叙事链 + 3 个未入链产物，打开序列标签）
/// / batch（Batch 稿的四态 slot，选中批量 result 节点）/ characters（三个角色 + 引用节点）。
const String kCaptureScreen = String.fromEnvironment('INKFRAME_CAPTURE_SCREEN', defaultValue: 'canvas');
/// 截图逻辑尺寸「宽x高」（PLAN_remaining：每屏两张，1600x1000 与 960x600）。
const String kCaptureSize = String.fromEnvironment('INKFRAME_CAPTURE_SIZE', defaultValue: '1600x1000');

Size parseCaptureSize(String spec) {
  final List<String> parts = spec.toLowerCase().split('x');
  final double? w = parts.length == 2 ? double.tryParse(parts[0]) : null;
  final double? h = parts.length == 2 ? double.tryParse(parts[1]) : null;
  return (w == null || h == null || w <= 0 || h <= 0) ? const Size(1600, 1000) : Size(w, h);
}

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
      if (kCaptureScreen == 'sequence') await seedSequenceFixture(ref, ids);
      if (kCaptureScreen == 'batch') await seedBatchFixture(ref, ids);
      if (kCaptureScreen == 'characters') await seedCharactersFixture(ref, ids);
      if (kCaptureScreen == 'studio') await seedStudioFixture(ref, ids);
      if (kCaptureScreen == 'settings') {
        // Screens 稿第 3 屏：设置浮层盖在 Studio 上，停在「API 密钥」页。
        // 不播种任何 Key——截图 app 用的是真平台安全存储，绝不往里写。
        await seedStudioFixture(ref, ids);
        ref.read(settingsPageProvider.notifier).state = SettingsPage.apiKeys;
        ref.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.settings);
      }
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
          child: SizedBox.fromSize(size: parseCaptureSize(kCaptureSize), child: widget.child),
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

/// Timeline 稿那一屏：铺一条 8 镜叙事链（名称 / 片长 / 占位取稿原文 `SequenceFixture.shots`）。
/// 铺在「画布 03 · 备选结尾」（Workspace 夹具建好的空画布）而不是画布 02：叙事序会把走不到链的
/// 节点按位置追加在末尾，画布 02 上那 4 镜 + 各自 config 会混进列表，就不再是稿的 8 镜。
/// 每镜 = shot 节点 →narrative→ 图像 config（带 result 缩略图）→narrative→ 下一镜；占位镜没有 config。
/// 「回望」那一镜给视频产物（列表出「视频」、导出 mp4 可用；文件不落盘——播放头停在首镜，监视器不会去开它）。
/// 另放 3 个不在链上的图像产物 = 稿的「未入链 · 3」。然后打开该画布并切到序列标签。
Future<void> seedSequenceFixture(WidgetRef ref, WorkspaceFixtureIds ids) async {
  final UnitOfWork uow = await ref.read(unitOfWorkProvider.future);
  final FileResolverService files = ref.read(fileResolverServiceProvider);
  const List<SqShot> shots = SequenceFixture.shots;
  const int videoIndex = 6;
  final String targetName = WorkspaceFixture.canvases[2].name;
  final List<Map<String, Object?>> canvases =
      await ref.read(canvasRepositoryProvider.future).then((repo) => repo.listByProject(ids.projectId));
  final String canvasId =
      canvases.firstWhere((Map<String, Object?> row) => row[CanvasCol.name] == targetName)[CanvasCol.id]! as String;
  Future<void> writeThumb(String rel, int gradient) async {
    final File f = files.resolve(projectId: ids.projectId, canvasId: canvasId, relativePath: rel);
    f.parent.createSync(recursive: true);
    await f.writeAsBytes(await _gradientPng(InkPalette.thumbPlaceholderGradients[gradient % 8]));
  }

  await uow.run((RepositoryScope s) async {
    String? prev;
    for (int i = 0; i < shots.length; i++) {
      final SqShot shot = shots[i];
      final int ms = (shot.seconds * 1000).round();
      final String shotId = await s.nodes.create(
        canvasId: canvasId,
        type: CanvasNodeType.shot.name,
        nodeRole: NodeRole.config.name,
        label: shot.name,
        positionX: 320.0 * i,
        positionY: 4000,
        typeConfig: <String, Object?>{'shot_notes': shot.name, 'duration_ms': ms},
      );
      if (prev != null) {
        await s.edges.create(canvasId: canvasId, sourceNodeId: prev, targetNodeId: shotId, edgeType: 'narrative');
      }
      prev = shotId;
      if (shot.placeholder) continue;
      final bool video = i == videoIndex;
      final String stem = 'sq${i.toString().padLeft(2, '0')}';
      final String cfg = await s.nodes.create(
        canvasId: canvasId,
        type: video ? CanvasNodeType.video.name : CanvasNodeType.image.name,
        nodeRole: NodeRole.config.name,
        label: shot.name,
        positionX: 320.0 * i,
        positionY: 4250,
        typeConfig: <String, Object?>{
          'provider_id': video ? 'kling-v3' : 'gemini-image',
          'prompt': shot.name,
          if (video) 'duration_ms': ms,
          // 稿的叠字「003 · 推镜 · 中景 · Kling 2.1」：运镜 + 景别（P3）给监视器叠字；景别按镜轮换。
          'camera': (i == 2 ? CameraMovement.pushIn : CameraMovement.static_).name,
          ShotLanguage.keyShotSize: ShotSize.values[i % ShotSize.values.length].name,
        },
      );
      await s.nodes.create(
        canvasId: canvasId,
        type: video ? CanvasNodeType.video.name : CanvasNodeType.image.name,
        nodeRole: NodeRole.result.name,
        sourceNodeId: cfg,
        positionX: 320.0 * i,
        positionY: 4500,
        typeConfig: video
            ? <String, Object?>{'video_url': 'videos/$stem.mp4', 'duration_ms': ms, 'thumbnail_url': 'thumbs/$stem.png'}
            : <String, Object?>{'image_url': 'thumbs/$stem.png'},
      );
      await s.edges.create(canvasId: canvasId, sourceNodeId: shotId, targetNodeId: cfg, edgeType: 'narrative');
      prev = cfg;
    }
    // 未入链 · 3：有产物、不在任何叙事边上。
    for (int i = 0; i < 3; i++) {
      final String cfg = await s.nodes.create(
        canvasId: canvasId,
        type: CanvasNodeType.image.name,
        nodeRole: NodeRole.config.name,
        label: '未入链 ${i + 1}',
        positionX: 320.0 * i,
        positionY: 4800,
        typeConfig: <String, Object?>{'provider_id': 'gemini-image', 'prompt': '未入链 ${i + 1}'},
      );
      await s.nodes.create(
        canvasId: canvasId,
        type: CanvasNodeType.image.name,
        nodeRole: NodeRole.result.name,
        sourceNodeId: cfg,
        positionX: 320.0 * i,
        positionY: 5050,
        typeConfig: <String, Object?>{'image_url': 'thumbs/loose$i.png'},
      );
    }
  });
  for (int i = 0; i < shots.length; i++) {
    if (shots[i].placeholder) continue;
    await writeThumb('thumbs/sq${i.toString().padLeft(2, '0')}.png', i);
  }
  for (int i = 0; i < 3; i++) {
    await writeThumb('thumbs/loose$i.png', i + 4);
  }
  ref.read(shellControllerProvider.notifier).openCanvas(canvasId, withProject: ProjectRef(id: ids.projectId, name: WorkspaceFixture.breadcrumb[1]));
  ref.read(shellControllerProvider.notifier).goTab(ShellTab.sequence);
}

/// P4 批量结果那一屏：在画布 02 上放一个 image config + 它的批量 result 容器 +
/// 四个 slot（已转正 / 成功 / 失败带 errorCode / 生成中），然后选中 result 节点
/// ——批量网格挂在 ImageResultInspector 里，选中 result 才看得到。
///
/// slot 的 seed / 尺寸 / errorCode 照稿：41207 promoted · 88316 · 15043 failed · 生成中无 seed。
Future<void> seedBatchFixture(WidgetRef ref, WorkspaceFixtureIds ids) async {
  final UnitOfWork uow = await ref.read(unitOfWorkProvider.future);
  final FileResolverService files = ref.read(fileResolverServiceProvider);

  final String resultId = await uow.run((RepositoryScope s) async {
    final String cfg = await s.nodes.create(
      canvasId: ids.canvasId,
      type: CanvasNodeType.image.name,
      nodeRole: NodeRole.config.name,
      label: '镜头 05 · 松林',
      positionX: 1200,
      positionY: 120,
      typeConfig: <String, Object?>{
        'provider_id': 'wanx-image',
        'prompt': WorkspaceFixture.promptText,
        'batch_size': 4,
      },
    );
    // 批量的 result 节点是容器：转正之前不持有 image_url，四张都在 slot 里。
    final String result = await s.nodes.create(
      canvasId: ids.canvasId,
      type: CanvasNodeType.image.name,
      nodeRole: NodeRole.result.name,
      sourceNodeId: cfg,
      positionX: 1200,
      positionY: 420,
    );
    final String jobId = await s.jobs.create(
      canvasId: ids.canvasId,
      sourceNodeId: cfg,
      resultNodeId: result,
      providerId: 'wanx-image',
      jobType: 'image',
      fullPrompt: WorkspaceFixture.promptText,
      userPrompt: WorkspaceFixture.promptText,
      batchSize: 4,
    );

    // 稿上四态：0 已转正 / 1 成功 / 2 失败（带 errorCode）/ 3 生成中。
    const List<(String, int?, String?)> spec = <(String, int?, String?)>[
      ('success', 41207, null),
      ('success', 88316, null),
      ('error', 15043, 'content_filtered'),
      ('generating', null, null),
    ];
    for (int i = 0; i < spec.length; i++) {
      final (String status, int? seed, String? code) = spec[i];
      final String slotId = await s.batchResults.create(
        nodeId: result,
        jobId: jobId,
        slotIndex: i,
        status: status,
      );
      await s.batchResults.update(slotId, <String, Object?>{
        BatchResultCol.status: status,
        if (status == 'success') BatchResultCol.outputUrl: 'images/slot$i.png',
        if (status == 'success') BatchResultCol.width: 1024,
        if (status == 'success') BatchResultCol.height: 576,
        BatchResultCol.seed: seed,
        BatchResultCol.errorCode: code,
      });
      if (i == 0) {
        await s.batchResults.markPromoted(id: slotId, promotedNodeId: result);
      }
    }
    return result;
  });

  for (int i = 0; i < 2; i++) {
    final File f = files.resolve(
      projectId: ids.projectId,
      canvasId: ids.canvasId,
      relativePath: 'images/slot$i.png',
    );
    f.parent.createSync(recursive: true);
    await f.writeAsBytes(await _gradientPng(InkPalette.thumbPlaceholderGradients[i]));
  }
  ref.read(canvasSelectionControllerProvider(ids.canvasId).notifier).select(resultId);
}

/// P4 角色那一屏：播三个角色（稿上原文的名字 + 参考图张数），并把它们挂到若干
/// config 节点上，好让「N 张参考图 · M 处引用」有真数。
Future<void> seedCharactersFixture(WidgetRef ref, WorkspaceFixtureIds ids) async {
  final UnitOfWork uow = await ref.read(unitOfWorkProvider.future);
  final FileResolverService files = ref.read(fileResolverServiceProvider);

  // 名字 / 参考图张数 / 要挂到几个节点上——对齐稿的「4 张参考图 · 6 处引用」等三行。
  const List<(String, String, int, int)> spec = <(String, String, int, int)>[
    ('行者', '中年男性，粗布行囊，灰褐色斗篷，左颊有旧疤', 4, 6),
    ('少年', '十五六岁，短打，背一把柴刀', 2, 3),
    ('山中老者', '白须及胸，竹杖，粗麻衣', 1, 0),
  ];

  final List<String> charIds = await uow.run((RepositoryScope s) async {
    final List<String> out = <String>[];
    for (final (String name, String desc, int refs, int _) in spec) {
      final String id = await s.characters.create(projectId: ids.projectId, name: name);
      await s.characters.update(id, <String, Object?>{
        CharacterCol.description: desc,
        CharacterCol.referenceImagePaths: <String>[
          for (int i = 0; i < refs; i++) 'characters/$id-$i.png',
        ],
      });
      out.add(id);
    }
    // 引用：给每个角色建 N 个挂着它的 config 节点（放在画布视口外，只为计数）。
    for (int c = 0; c < spec.length; c++) {
      for (int k = 0; k < spec[c].$4; k++) {
        await s.nodes.create(
          canvasId: ids.canvasId,
          type: CanvasNodeType.image.name,
          nodeRole: NodeRole.config.name,
          label: '引用 ${c + 1}-${k + 1}',
          positionX: 300.0 * k,
          positionY: 6000 + 300.0 * c,
          typeConfig: <String, Object?>{
            'provider_id': 'gemini-image',
            'character_ids': <String>[out[c]],
          },
        );
      }
    }
    return out;
  });

  for (int c = 0; c < spec.length; c++) {
    for (int i = 0; i < spec[c].$3; i++) {
      final File f = files.resolveInProject(
        projectId: ids.projectId,
        relativePath: 'characters/${charIds[c]}-$i.png',
      );
      f.parent.createSync(recursive: true);
      await f.writeAsBytes(
        await _gradientPng(InkPalette.thumbPlaceholderGradients[(c * 3 + i) % 8]),
      );
    }
  }
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

/// Studio 稿那一屏：再建三个项目（稿上的名字与画布数），把「上次离开时」指到画布 02，
/// 山径破晓摸一下让它排到最前（排序 = 最近修改），然后切到 Studio 标签。
/// 无 Key 引导条靠临时数据根本来就没配 Key。
Future<void> seedStudioFixture(WidgetRef ref, WorkspaceFixtureIds ids) async {
  final UnitOfWork uow = await ref.read(unitOfWorkProvider.future);
  // 倒着建：列表按最近修改倒序，稿上 夜航船 / 角色测试 / 短剧示例 就是这个顺序。
  for (final StProject p in StudioFixture.projects.skip(1).toList().reversed) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await uow.run((RepositoryScope s) async {
      final String id = await s.projects.create(name: p.name);
      for (int i = 0; i < p.canvases; i++) {
        await s.canvas.create(projectId: id, name: '画布 ${(i + 1).toString().padLeft(2, '0')}');
      }
    });
  }
  await Future<void>.delayed(const Duration(milliseconds: 5));
  await uow.run((RepositoryScope s) =>
      s.projects.update(ids.projectId, <String, Object?>{'name': WorkspaceFixture.breadcrumb[1]}));
  // 恢复条要开关打开 + 有记录；临时数据根的 preferences.json 可能把开关关着，这里显式打开。
  await ref.read(preferencesServiceProvider).update(
        (AppPreferences p) => p.copyWith(
          lastCanvasId: ids.canvasId,
          lastProjectId: ids.projectId,
          shellKeepLastCanvas: true,
        ),
      );
  ref.invalidate(shellKeepLastCanvasControllerProvider);
  ref.invalidate(workspaceProjectsProvider);
  ref.read(shellControllerProvider.notifier).goTab(ShellTab.studio);
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
    stylePrompt: WorkspaceFixture.lanePrompts[0],
    sortOrder: 0,
  );
  final String laneB = await s.styleLanes.create(
    canvasId: canvasId,
    label: WorkspaceFixture.laneLabels[1],
    stylePrompt: WorkspaceFixture.lanePrompts[1],
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
        // P3：稿的检查器「镜头运动」组四行原文——中景 MS / 平视 Eye Level / 0.35 / 35mm。
        ShotLanguage.keyShotSize: ShotSize.mediumShot.name,
        ShotLanguage.keyCameraAngle: CameraAngle.eyeLevel.name,
        ShotLanguage.keyMotionStrength: 0.35,
        ShotLanguage.keyFocalLength: 35,
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
      // 稿的 y 贴道顶放，P1 之后 +14 的泳道标题栏会压住卡片一角——播种时整体下移 30，
      // 画布 golden 不带着这个已知遮挡当基线（用户 2026-09-29）。静态复刻的 y 不动。
      positionY: n.y + 30,
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
