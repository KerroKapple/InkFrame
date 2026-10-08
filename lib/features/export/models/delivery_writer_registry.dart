// 写出器 registry（P6）——「某个目标软件此刻能不能选」的唯一判据。
//
// ## 为什么要有这一层
//
// 第一版把「有没有写出器」写成了枚举上的两个布尔（`writesEdl` / `supported`）。
// 那是把同一件事记在两个地方：真相是「仓库里到底有没有这种格式的写出器」，
// 而布尔是人手抄的一份副本。将来接上剪映草稿写出器，还得记得回去把布尔改掉
// ——忘了改，用户看到的就是一个永远灰着的「剪映」段，而代码里明明能导。
//
// 所以：段只声明**自己需要哪个写出器 id**（[DeliveryTarget.writerId]），
// 可选性一律问 registry。接上写出器 ⇒ 那一段当场变可选，一个枚举字都不用动
// （test/features/export/models/delivery_writer_registry_test.dart 钉死这条）。
//
// registry 走 Riverpod 注入（见 lib/core/di/delivery.dart），测试里可以 override
// 成「多一个 jianying-draft」来自证这条路是活的。
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../util/edl_cmx3600.dart';
import 'delivery_plan.dart';
import 'delivery_settings.dart';

/// 写出器 id。英文协议字面量：落库、日志、段声明三处共用，不随 UI 语言变。
abstract final class DeliveryWriterIds {
  static const String edlCmx3600 = 'edl-cmx3600';
  static const String fcpXml = 'fcpxml';
  static const String jianyingDraft = 'jianying-draft';
}

/// 一种工程文件格式的写出器：交付计划 → 一段文本。
///
/// 刻意只收 [DeliveryPlan]（它自带 settings 与项目名）、只回字符串：写出器不碰
/// 文件系统，也就不需要为了测它去造临时目录。落盘是 DeliveryService 的事。
abstract class DeliveryProjectWriter {
  /// 与 [DeliveryTarget.writerId] 对表的 id。
  String get id;

  /// 输出文件扩展名，不含点（`edl` / `fcpxml` / `json`）。
  String get fileExtension;

  String write(DeliveryPlan plan);
}

/// 写出器登记处。
abstract class DeliveryWriterRegistry {
  /// 按 id 取写出器；没有返回 null。
  DeliveryProjectWriter? find(String writerId);

  bool has(String writerId);

  /// 某个目标软件对应的写出器；没有返回 null。
  DeliveryProjectWriter? forTarget(DeliveryTarget target);

  /// 这一段现在可不可选 = 它要的写出器在不在。
  bool supports(DeliveryTarget target);
}

/// 列表实现。出厂只有 EDL 一个；加一行就多一种格式。
@immutable
class MapDeliveryWriterRegistry implements DeliveryWriterRegistry {
  const MapDeliveryWriterRegistry(this._writers);

  /// 出厂配置：当前仓库真正有的写出器。
  factory MapDeliveryWriterRegistry.production() =>
      const MapDeliveryWriterRegistry(
        <DeliveryProjectWriter>[EdlCmx3600Writer()],
      );

  final List<DeliveryProjectWriter> _writers;

  @override
  DeliveryProjectWriter? find(String writerId) {
    for (final DeliveryProjectWriter w in _writers) {
      if (w.id == writerId) return w;
    }
    return null;
  }

  @override
  bool has(String writerId) => find(writerId) != null;

  @override
  DeliveryProjectWriter? forTarget(DeliveryTarget target) =>
      find(target.writerId);

  @override
  bool supports(DeliveryTarget target) => forTarget(target) != null;
}

/// CMX3600 EDL：Resolve 与 Premiere 都吃这个。
@immutable
class EdlCmx3600Writer implements DeliveryProjectWriter {
  const EdlCmx3600Writer();

  @override
  String get id => DeliveryWriterIds.edlCmx3600;

  @override
  String get fileExtension => 'edl';

  @override
  String write(DeliveryPlan plan) => buildCmx3600(
        // TITLE 是时间线名（自由文本），用项目名原文；项目名空了才退到文件名主体。
        title: plan.projectName.trim().isEmpty
            ? plan.projectFileBaseName
            : plan.projectName,
        // 手柄恒为 0。写出器默认留 ±12 帧是给「源素材比剪辑点长」的常规剪辑流程用的；
        // 这里导出的媒体**就是整条生成文件**，两端没有一帧余量——写 12 等于让
        // Resolve 去媒体外面找帧，片段会直接报 Media Offline（手柄也在 PLAN 不做清单里）。
        handleFrames: 0,
        recordStartFrames: plan.settings.timecodeStartFrames,
        clips: <DeliveryClip>[
          for (final DeliveryShotPlan s in plan.shots)
            DeliveryClip(
              // 相对引用（默认）= 只写文件名，NLE 按 EDL 所在目录去找，整个文件夹
              // 搬走还能用；开关关掉时写绝对路径，钉死在这台机器上。
              fileName: s.fileName == null
                  ? ''
                  : plan.mediaDirAbsolutePath == null
                      ? s.fileName!
                      : p.join(plan.mediaDirAbsolutePath!, s.fileName!),
              durationMs: s.durationMs,
              comment: s.comment,
              marker: s.marker,
              placeholder: s.isPlaceholder,
            ),
        ],
      );
}
