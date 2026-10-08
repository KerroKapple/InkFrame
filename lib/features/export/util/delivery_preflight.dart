// 交付前检查（P6 §2.5）：五条，顺序固定，纯函数。
//
// 这一层**不出文案**，只出「哪一条、什么级别、拿什么数据」——文案在
// widgets/delivery_preflight_list.dart 走 ARB。这样「判据」能纯单测，
// 「文案」能随界面语言变，两件事不互相绑死。
//
// ## 五条里有一条算不出来
//
// **1 帧率一致**：仓库里没有任何 fps 字段——`kSequenceFps = 24` 是 timecode.dart
// 里的常量，所有产物、所有时间码换算都按它走。所以「链上帧率是否一致」这个判断
// 在当前数据模型下**恒为真**，它不可能发现任何问题、也永远不会成为阻断原因。
// 照稿把它画出来，但文案只说「按 24 fps 统一处理」（见 ARB
// `deliveryCheckFrameRate`），不写成「已校验一致」——那是假装在比对。
// 等 provider 真给出帧率字段，这一条才有内容可比。
//
// **2 画幅一致**：算得出。宽高来自 video result 节点 type_config 的 width/height
// （XM-1 抽帧探针写的，见 job_media_persister）。**抽帧失败时这两个键是缺的** ⇒
// 算「未知」，不算「不一致」——把探针失败渲染成画幅冲突会让人去改不存在的问题。
import 'package:flutter/foundation.dart';

import '../models/delivery_plan.dart';

/// 五条检查的身份。顺序即稿上从上到下的渲染顺序（[kDeliveryCheckOrder]）。
enum DeliveryCheckId {
  frameRate,
  frameSize,
  missingArtifacts,
  projectContext,
  outputWritable,
}

/// 稿：`✓` success / `!` accent / `✕` danger。
enum DeliveryCheckLevel { ok, warn, block }

/// 固定顺序。第一条阻断原因就是按这个序取的。
const List<DeliveryCheckId> kDeliveryCheckOrder = <DeliveryCheckId>[
  DeliveryCheckId.frameRate,
  DeliveryCheckId.frameSize,
  DeliveryCheckId.missingArtifacts,
  DeliveryCheckId.projectContext,
  DeliveryCheckId.outputWritable,
];

/// 缺失镜最多展开几条，其余折成「另有 N 个」。
const int kDeliveryMissingShown = 3;

@immutable
class DeliveryCheck {
  const DeliveryCheck({
    required this.id,
    required this.level,
    this.shotCount = 0,
    this.aspectLabel,
    this.aspectLabels = const <String>[],
    this.unknownSizeCount = 0,
    this.missing = const <DeliveryShotPlan>[],
  });

  final DeliveryCheckId id;
  final DeliveryCheckLevel level;

  /// 帧率条：参与的镜数（稿的「8 镜…」）。
  final int shotCount;

  /// 画幅条：一致时的比值文本（`16:9`）；未知 / 不一致时为 null。
  final String? aspectLabel;

  /// 画幅条：不一致时出现的全部比值，链上首次出现序。
  final List<String> aspectLabels;

  /// 画幅条：宽高未记录的镜数。
  final int unknownSizeCount;

  /// 缺失条：缺视频产物的镜（**不折叠**，折叠是呈现的事）。
  final List<DeliveryShotPlan> missing;

  bool get isOk => level == DeliveryCheckLevel.ok;
}

@immutable
class DeliveryPreflight {
  const DeliveryPreflight(this.checks);

  final List<DeliveryCheck> checks;

  /// 稿右上角的「N 项待处理」。
  int get pendingCount =>
      checks.where((DeliveryCheck c) => !c.isOk).length;

  bool get canDeliver => firstBlocking == null;

  /// 第一条阻断原因（主按钮 Tooltip 写它）。按 [kDeliveryCheckOrder] 取。
  DeliveryCheck? get firstBlocking {
    for (final DeliveryCheck c in checks) {
      if (c.level == DeliveryCheckLevel.block) return c;
    }
    return null;
  }
}

/// 跑一遍五条检查。
///
/// [outputWritable] 由调用方探测（试建目录 + 写探针文件）后传进来——本层不碰磁盘。
DeliveryPreflight runDeliveryPreflight({
  required DeliveryPlan plan,
  required bool hasProject,
  required bool outputWritable,
}) {
  return DeliveryPreflight(<DeliveryCheck>[
    DeliveryCheck(
      id: DeliveryCheckId.frameRate,
      // 恒 ok：见本文件头注，没有帧率字段可比。
      level: DeliveryCheckLevel.ok,
      shotCount: plan.shots.length,
    ),
    _frameSizeCheck(plan),
    DeliveryCheck(
      id: DeliveryCheckId.missingArtifacts,
      level: plan.placeholders.isEmpty
          ? DeliveryCheckLevel.ok
          : DeliveryCheckLevel.warn,
      missing: plan.placeholders,
    ),
    DeliveryCheck(
      id: DeliveryCheckId.projectContext,
      level: hasProject ? DeliveryCheckLevel.ok : DeliveryCheckLevel.block,
    ),
    DeliveryCheck(
      id: DeliveryCheckId.outputWritable,
      level: outputWritable ? DeliveryCheckLevel.ok : DeliveryCheckLevel.block,
    ),
  ]);
}

DeliveryCheck _frameSizeCheck(DeliveryPlan plan) {
  final List<String> seen = <String>[];
  int unknown = 0;
  for (final DeliveryShotPlan s in plan.shots) {
    // 占位镜没有产物，不参与画幅判定。
    if (s.isPlaceholder) continue;
    final String? label = aspectRatioLabel(s.width, s.height);
    if (label == null) {
      unknown++;
      continue;
    }
    if (!seen.contains(label)) seen.add(label);
  }
  if (seen.length >= 2) {
    return DeliveryCheck(
      id: DeliveryCheckId.frameSize,
      level: DeliveryCheckLevel.warn,
      aspectLabels: seen,
      unknownSizeCount: unknown,
    );
  }
  return DeliveryCheck(
    id: DeliveryCheckId.frameSize,
    level: DeliveryCheckLevel.ok,
    aspectLabel: seen.isEmpty ? null : seen.single,
    unknownSizeCount: unknown,
  );
}

/// 宽高 → 约分后的画幅比文本（`1920×1080` → `16:9`）。任一缺失 / 非正 → null（未知）。
String? aspectRatioLabel(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) return null;
  final int g = _gcd(width, height);
  return '${width ~/ g}:${height ~/ g}';
}

int _gcd(int a, int b) {
  int x = a;
  int y = b;
  while (y != 0) {
    final int t = y;
    y = x % y;
    x = t;
  }
  return x == 0 ? 1 : x;
}

/// 缺失镜折叠：前 [max] 条展开，其余算 extra（稿：「另有 N 个」）。
({List<DeliveryShotPlan> shown, int extra}) collapseMissingShots(
  List<DeliveryShotPlan> missing, {
  int max = kDeliveryMissingShown,
}) {
  if (missing.length <= max) {
    return (shown: missing, extra: 0);
  }
  return (
    shown: missing.take(max).toList(),
    extra: missing.length - max,
  );
}
