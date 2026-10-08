// 交付计划（P6）：序列 lens + 画布节点 + 交付设置 → 「每镜导出成什么文件、工程文件里写什么」。
//
// 纯函数、不碰文件系统、不认识 Riverpod。它刻意**不认识 EDL**：写出器（registry）
// 才知道某种格式怎么落字，这里只回答与格式无关的那些问题——第几镜、叫什么、多少帧、
// 源文件在哪、备注写什么、标记在哪。接上 FCPXML / 剪映写出器时这一层不用改。
//
// 「占位镜」的口径：**没有视频 result 的镜一律是占位**，只有图片产物的也算。
// 交付的是一条 V1 视频时间线，一张图不是视频片段——它在 EDL 里只能是空隙。
// 这也是交付前检查第 3 条（缺失产物）的同一判据。
//
// 手写不可变类而非 freezed：与 features/sequence、features/canvas 既有惯例一致，
// 且规避 build_runner 卡点（BOARD 债 145）。
import 'package:flutter/foundation.dart';

import '../../../core/models/provider_capabilities.dart' show CameraMovement;
import '../../../core/models/shot_language.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/util/camera_labels.dart' show parseCameraMovement;
import '../../generation/services/shot_language_prompt.dart'
    show shotLanguagePromptPrefix;
import '../../sequence/models/sequence_lens.dart';
import '../../storyboard/models/sequence_shot.dart';
import '../util/edl_cmx3600.dart' show edlFramesFromMs;
import '../util/export_file_name.dart' show isValidExportBaseName;
import 'delivery_settings.dart';

/// 输出目录（项目根相对）。稿 2026-10-08 版：`<项目目录>/exports/`，
/// 版本号目录（`_v03`）与导出历史后置（PLAN 不做清单）。
const String kDeliveryOutputDirRelative = 'exports';

/// 镜头名在文件名里最多占多少个字符。
///
/// 为什么要截：Windows 的 MAX_PATH 是 260，而 60 字中文镜头名光自己就 60 个字符、
/// UTF-8 180 字节。`exports/` 之前还有 `%LOCALAPPDATA%\InkFrame\projects\<uuid>\`，
/// 不截就会在真实数据根下顶爆路径——而且那是落盘时才炸。
const int kDeliveryNameBudget = 32;

/// 清洗后彻底空掉的项目名用这个（英文常量，不是界面文案）。
const String _kFallbackProjectFileName = 'delivery';

/// 一镜的交付计划。
@immutable
class DeliveryShotPlan {
  const DeliveryShotPlan({
    required this.index,
    required this.nodeId,
    required this.name,
    required this.durationMs,
    required this.durationFrames,
    required this.isPlaceholder,
    this.fileName,
    this.sourceRelativePath,
    this.width,
    this.height,
    this.comment,
    this.marker,
    this.providerId,
    this.seed,
    this.prompt,
    this.stylePrompt,
    this.shotLanguage = ShotLanguage.empty,
    this.cameraMovement,
  });

  /// 链上序号，**1 起**（文件名与缺失提示都用它）。
  final int index;

  /// 链上贡献这一镜的节点 id（定位 / 诊断用）。
  final String nodeId;

  /// 镜头名原文——界面显示用，不是文件名。
  final String name;

  final int durationMs;

  /// 记录端帧数。与 EDL 同一换算（[edlFramesFromMs]），免得两处各自取整漂开。
  final int durationFrames;

  /// 没有视频产物 ⇒ 不出文件、不出事件，但照占记录时间。
  final bool isPlaceholder;

  /// 导出的媒体文件名（`{序号3位}_{镜头名}.mp4`）；占位镜为 null。
  final String? fileName;

  /// 源媒体的**项目根**相对路径（`canvases/<canvasId>/videos/x.mp4`）；占位镜为 null。
  final String? sourceRelativePath;

  /// 产物像素宽高；抽帧探针没记录时为 null（未知，不是 0）。
  final int? width;
  final int? height;

  /// 片段备注（镜头语言英文串）。开关关闭或一项都没设时为 null。
  final String? comment;

  /// 时间线标记文案（场次名）。开关关闭或这一镜不起场次时为 null。
  final String? marker;

  /// 以下五项取自**config 节点**（提示词 / provider / seed 的住所），占位镜全 null。
  final String? providerId;
  final int? seed;
  final String? prompt;
  final String? stylePrompt;
  final ShotLanguage shotLanguage;
  final CameraMovement? cameraMovement;
}

/// 一次交付要产出什么。
@immutable
class DeliveryPlan {
  const DeliveryPlan({
    required this.projectName,
    required this.shots,
    required this.settings,
    this.mediaDirAbsolutePath,
  });

  static const DeliveryPlan empty = DeliveryPlan(
    projectName: '',
    shots: <DeliveryShotPlan>[],
    settings: DeliverySettings.defaults,
  );

  final String projectName;
  final List<DeliveryShotPlan> shots;
  final DeliverySettings settings;

  /// 媒体引用要写**绝对路径**时，这里是交付目录的绝对路径；写相对路径时为 null。
  ///
  /// 这就是稿上「相对路径」开关真正改变的东西：NLE 把 EDL 里的相对片段名按
  /// **EDL 自己所在的目录**去找媒体（所以整个文件夹搬走还能用），写绝对路径就钉死在
  /// 这台机器上。面板构造计划时不知道绝对路径（它不该碰文件系统），由
  /// DeliveryController 在执行前用 [withMediaDir] 补上。
  final String? mediaDirAbsolutePath;

  /// 补上媒体目录绝对路径（开关关闭时用）。传 null 回到相对引用。
  DeliveryPlan withMediaDir(String? absolutePath) => DeliveryPlan(
        projectName: projectName,
        shots: shots,
        settings: settings,
        mediaDirAbsolutePath: absolutePath,
      );

  bool get isEmpty => shots.isEmpty;

  /// 真有视频产物的镜数 = 会落盘的 mp4 个数（底部摘要「包含」行的 N）。
  int get mp4Count =>
      shots.where((DeliveryShotPlan s) => !s.isPlaceholder).length;

  /// 缺视频产物的镜（交付前检查第 3 条）。
  List<DeliveryShotPlan> get placeholders =>
      shots.where((DeliveryShotPlan s) => s.isPlaceholder).toList();

  int get totalFrames => shots.fold<int>(
        0,
        (int acc, DeliveryShotPlan s) => acc + s.durationFrames,
      );

  /// 工程文件名（不含扩展名）。
  String get projectFileBaseName => deliveryProjectFileBaseName(projectName);
}

/// 镜头名 → 媒体文件名 `{序号3位}_{清洗后的名}.mp4`；名字清洗后为空时只留序号。
String deliveryMediaFileName({required int index, required String shotName}) {
  final String prefix = index.toString().padLeft(3, '0');
  final String safe = _sanitizeFileSegment(shotName);
  return safe.isEmpty ? '$prefix.mp4' : '${prefix}_$safe.mp4';
}

/// 项目名 → 工程文件名主体（不含扩展名）。
String deliveryProjectFileBaseName(String projectName) {
  final String safe = _sanitizeFileSegment(projectName);
  return safe.isEmpty ? _kFallbackProjectFileName : safe;
}

/// 文件名里不许出现的那些：控制字符、路径分隔符、盘符冒号、Windows 非法字符。
/// **点也一并换掉**——保留点就要再操心 `..` 与「保留设备名 + 扩展名」两种形态，
/// 换成下划线一次解决（`my.shot` → `my_shot`，可接受）。
final RegExp _kUnsafeInName = RegExp(r'[\x00-\x1f\x7f/\\:*?"<>|.]');

String _sanitizeFileSegment(String raw) {
  // 连续的替换痕迹并成一个下划线，再把首尾的下划线 / 空白削掉——否则 `///`
  // 这种全是非法字符的名字会变成 `___`，看着像个名字其实什么都没剩。
  final String replaced = raw
      .replaceAll(_kUnsafeInName, '_')
      .replaceAll(RegExp(r'_{2,}'), '_')
      .replaceAll(RegExp(r'^[\s_]+|[\s_]+$'), '');
  // 按 runes 截，不按 code unit——否则会把一个字符劈成半个代理对。
  final List<int> runes = replaced.runes.toList();
  final String clipped = runes.length <= kDeliveryNameBudget
      ? replaced
      : String.fromCharCodes(runes.take(kDeliveryNameBudget));
  final String trimmed = clipped.replaceAll(RegExp(r'[\s_]+$'), '');
  if (trimmed.isEmpty) return '';
  // 后置条件由既有校验器把关（与 ffmpeg 导出同一条规则）：`con` 这类保留设备名
  // 清洗不掉，补一个下划线让它不再是设备名。
  return isValidExportBaseName(trimmed) ? trimmed : '${trimmed}_';
}

/// 序列 lens + 画布节点 + 设置 → 交付计划。
///
/// [laneStylePrompts] 是 laneId → 泳道风格提示词；拿不到泳道（未加载 / 无泳道）
/// 时传空表，`stylePrompt` 就为 null——元数据少一个键，不影响交付。
DeliveryPlan buildDeliveryPlan({
  required String projectName,
  required SequenceLens lens,
  required List<CanvasNode> nodes,
  required DeliverySettings settings,
  Map<String, String> laneStylePrompts = const <String, String>{},
}) {
  if (lens.isEmpty) {
    return DeliveryPlan(
      projectName: projectName,
      shots: const <DeliveryShotPlan>[],
      settings: settings,
    );
  }
  final Map<String, CanvasNode> byId = <String, CanvasNode>{
    for (final CanvasNode n in nodes) n.id: n,
  };
  // 场次标记按 nodeId 索引：lens 的标记是「链上 shot 节点各起一个场次」，
  // 落点就是那一镜的起点，所以这里只需要「这一镜起不起场次」。
  final Set<String> markerNodeIds = <String>{
    for (final SceneMarker m in lens.markers) m.nodeId,
  };

  final List<DeliveryShotPlan> out = <DeliveryShotPlan>[];
  for (int i = 0; i < lens.shots.length; i++) {
    final SequenceShot shot = lens.shots[i];
    final CanvasNode? artifact = shot.artifactNodeId == null
        ? null
        : byId[shot.artifactNodeId!];
    // config 节点 = 产物的来源节点；提示词 / provider / seed / 镜头语言都在它身上。
    final CanvasNode? config = artifact?.sourceNodeId == null
        ? null
        : byId[artifact!.sourceNodeId!];
    final bool isVideo = shot.kind == SequenceArtifactKind.video &&
        shot.relativePath != null &&
        shot.canvasId != null;

    final ShotLanguage lang = _shotLanguageFor(config, byId[shot.nodeId]);
    final CameraMovement? camera =
        parseCameraMovement(config?.typeConfig['camera']);
    final String prefix =
        settings.shotLanguageInComments
            ? shotLanguagePromptPrefix(lang, camera: camera)
            : '';

    out.add(
      DeliveryShotPlan(
        index: i + 1,
        nodeId: shot.nodeId,
        name: shot.label,
        durationMs: shot.durationMs,
        durationFrames: edlFramesFromMs(shot.durationMs),
        isPlaceholder: !isVideo,
        fileName: isVideo
            ? deliveryMediaFileName(index: i + 1, shotName: shot.label)
            : null,
        sourceRelativePath: isVideo
            ? 'canvases/${shot.canvasId}/${shot.relativePath}'
            : null,
        width: shot.width,
        height: shot.height,
        comment: prefix.isEmpty ? null : prefix,
        marker: settings.markersFromScenes && markerNodeIds.contains(shot.nodeId)
            ? shot.label
            : null,
        providerId: _optString(config?.typeConfig['provider_id']),
        seed: _optInt(config?.typeConfig['seed']),
        prompt: _optString(config?.typeConfig['prompt']),
        stylePrompt: _laneStyleFor(config, laneStylePrompts),
        shotLanguage: lang,
        cameraMovement: camera,
      ),
    );
  }
  return DeliveryPlan(
    projectName: projectName,
    shots: out,
    settings: settings,
  );
}

/// 镜头语言优先看 config（P3 就写在 video config 上），退而看链上这一镜的节点
/// （shot 节点记的是导演意图，config 还没建时它是唯一来源）。
ShotLanguage _shotLanguageFor(CanvasNode? config, CanvasNode? chainNode) {
  final ShotLanguage fromConfig =
      config == null ? ShotLanguage.empty : config.shotLanguage;
  if (!fromConfig.isEmpty) return fromConfig;
  return chainNode?.shotLanguage ?? ShotLanguage.empty;
}

/// 泳道风格：ignoreLaneStyle 的节点按 PRD §7.4 拼接公式跳过泳道段，
/// 这里同口径——它的提示词里本来就没有泳道风格，写进元数据会是假的。
String? _laneStyleFor(CanvasNode? config, Map<String, String> prompts) {
  if (config == null || config.ignoreLaneStyle) return null;
  final String? laneId = config.laneId;
  if (laneId == null) return null;
  final String? prompt = prompts[laneId];
  return prompt == null || prompt.trim().isEmpty ? null : prompt;
}

String? _optString(Object? raw) =>
    raw is String && raw.trim().isNotEmpty ? raw : null;

int? _optInt(Object? raw) => raw is int ? raw : null;
