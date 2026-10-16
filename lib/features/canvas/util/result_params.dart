// 产物检查器「生成参数」组的取值：纯函数，不碰 ref / BuildContext。
//
// 口径与画廊信息面板（gallery/util/gallery_meta.dart 的 galleryMetaFor）一致：
//   - 供应商 / 分辨率 / 画幅 / 运镜 / 镜头语言 / 提示词 → 取自来源 config 节点（result.sourceNodeId）；
//   - 尺寸 / 种子 → 取自产物自己的 type_config（落盘时写的是这一次真正用到的值，见
//     services/job_queue/job_media_persister.dart 的 _imageMetaPatch 与视频抽帧探针）；
//   - 时长 → 产物探针写的 duration_ms 优先，没有再退回 config 上设的时长。
// 来源 config 已删（孤儿产物）时，只剩产物自己那几项。
//
// image 与 video 两个产物检查器共用这一份，不各写一套。
import '../../../core/models/provider_capabilities.dart';
import '../../../core/models/shot_language.dart';
import '../models/canvas_node.dart';
import 'camera_labels.dart';

/// 一张产物「是用什么参数生成的」。字段为 null（镜头语言为 [ShotLanguage.empty]）= 没有这一项，不画那一行。
class ResultParams {
  const ResultParams({
    this.providerId,
    this.resolution,
    this.aspectRatio,
    this.width,
    this.height,
    this.seed,
    this.durationMs,
    this.camera,
    this.shotLanguage = ShotLanguage.empty,
    this.prompt,
  });

  final String? providerId;

  /// `Resolution.name` 原样（检查器的分辨率下拉也直接显示 name）。
  final String? resolution;
  final AspectRatio? aspectRatio;
  final int? width;
  final int? height;
  final int? seed;
  final int? durationMs;
  final CameraMovement? camera;
  final ShotLanguage shotLanguage;

  /// 用户提示词（去首尾空白；空串归 null）。
  final String? prompt;

  /// 宽高都有才算有尺寸。
  bool get hasDimensions => width != null && height != null;
}

/// [result] 的来源 config 节点：在 [nodes] 里按 sourceNodeId 找；不是产物 / 没有来源 / 来源已不在 ⇒ null。
CanvasNode? resultSourceNode(CanvasNode result, List<CanvasNode> nodes) {
  if (result.role != NodeRole.result) return null;
  final String? src = result.sourceNodeId;
  if (src == null) return null;
  for (final CanvasNode n in nodes) {
    if (n.id == src) return n;
  }
  return null;
}

/// 从产物 [result] 与它的来源 config [source]（可为 null）取「生成参数」。
ResultParams resultParamsOf(CanvasNode result, CanvasNode? source) {
  final Map<String, Object?> own = result.typeConfig;
  final Map<String, Object?> cfg = source?.typeConfig ?? const <String, Object?>{};
  final String? prompt = source?.promptText?.trim();
  return ResultParams(
    providerId: _nonEmptyString(cfg['provider_id']),
    resolution: _nonEmptyString(cfg['resolution']),
    aspectRatio: _parseAspect(cfg['aspect_ratio']),
    width: _positiveInt(own['width']),
    height: _positiveInt(own['height']),
    seed: _intOrNull(own['seed']),
    durationMs: _positiveInt(own['duration_ms']) ?? _positiveInt(cfg['duration_ms']),
    camera: parseCameraMovement(cfg['camera']),
    shotLanguage: source?.shotLanguage ?? ShotLanguage.empty,
    prompt: (prompt == null || prompt.isEmpty) ? null : prompt,
  );
}

String? _nonEmptyString(Object? v) => v is String && v.isNotEmpty ? v : null;

int? _positiveInt(Object? v) => v is int && v > 0 ? v : null;

int? _intOrNull(Object? v) => v is int ? v : null;

AspectRatio? _parseAspect(Object? raw) {
  if (raw is! String) return null;
  for (final AspectRatio a in AspectRatio.values) {
    if (a.name == raw) return a;
  }
  return null;
}
