// EDL CMX3600 写出器（P6 交付 B）。纯 Dart：片段表 → EDL 文本。
//
// 不碰文件系统、不认识 Riverpod、不认识序列模型——调用方把序列折算成
// [DeliveryClip] 再进来，这样「怎么算片段」和「怎么写 EDL」各测各的。
//
// 为什么全程用**帧**而不是毫秒：CMX3600 的记录时间码必须首尾相接（上一条的 out
// 就是下一条的 in），一旦每条各自从毫秒换算再取整，累计误差会让中段整体错位。
// 帧率没有字段（PLAN 不做清单），按稿的 24fps。
import 'package:flutter/foundation.dart';

import '../../sequence/util/timecode.dart' show kSequenceFps;

/// 稿上的默认记录起点 01:00:00:00。
const int kEdlDefaultRecordStartFrames = kSequenceFps * 3600;

/// 稿上的默认手柄：±12 帧（0.5s）。只影响 EDL 的**源**入出点，不改媒体。
const int kEdlDefaultHandleFrames = 12;

/// 卷名。媒体是文件而不是磁带，CMX3600 的惯例是 `AX`（auxiliary），
/// 真正的文件名走 `* FROM CLIP NAME:` 注释行——NLE 就是按这行找媒体的。
const String _kReel = 'AX';

/// 时间线上的一段。占位镜（无产物）也是一段：不出事件，但照样占记录时间。
@immutable
class DeliveryClip {
  const DeliveryClip({
    required this.fileName,
    required this.durationMs,
    this.comment,
    this.marker,
    this.placeholder = false,
  });

  /// 导出的媒体文件名（`{序号3位}_{镜头名}.mp4`）。占位镜为空串。
  final String fileName;

  final int durationMs;

  /// 片段备注（稿：镜头语言写入片段备注）。空 / null 时整行不写。
  final String? comment;

  /// 时间线标记文案。null 时不写 `* LOC` 行。
  final String? marker;

  /// 无产物 ⇒ 导出为空隙：不出事件，但记录时间照走。
  final bool placeholder;
}

/// 帧 → `HH:MM:SS:FF`。
///
/// 超过 24 小时**不回绕**——EDL 里出现 25 小时是合法的，回绕反而把信息丢了。
/// 负帧钳到 0：写出负时间码没有任何 NLE 能读。
String formatEdlTimecode(int frames) {
  final int f = frames < 0 ? 0 : frames;
  final int totalSeconds = f ~/ kSequenceFps;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(totalSeconds ~/ 3600)}:'
      '${two((totalSeconds % 3600) ~/ 60)}:'
      '${two(totalSeconds % 60)}:'
      '${two(f % kSequenceFps)}';
}

/// `HH:MM:SS:FF` → 帧；格式不对一律 null（**不抛**，不猜用户想打什么）。
///
/// 时位不设上限（EDL 里 25 小时合法），分 / 秒 ≤ 59，帧位 ≤ fps-1
/// ——写 `00:00:00:24` 在 24fps 下是不存在的那一帧。
int? parseEdlTimecode(String raw) {
  final RegExpMatch? m =
      RegExp(r'^(\d{1,2}):(\d{1,2}):(\d{1,2}):(\d{1,2})$').firstMatch(raw.trim());
  if (m == null) return null;
  final int h = int.parse(m.group(1)!);
  final int min = int.parse(m.group(2)!);
  final int s = int.parse(m.group(3)!);
  final int f = int.parse(m.group(4)!);
  if (min > 59 || s > 59 || f >= kSequenceFps) return null;
  return ((h * 3600 + min * 60 + s) * kSequenceFps) + f;
}

/// 毫秒 → 帧（就近取整；一帧都不到的片段至少给 1 帧，零长事件 NLE 会丢）。
int edlFramesFromMs(int ms) {
  if (ms <= 0) return 0;
  final int frames = (ms * kSequenceFps / 1000).round();
  return frames < 1 ? 1 : frames;
}

/// 片段表 → CMX3600 文本。
///
/// [handleFrames] 只推**源**入点：导出的媒体两端各多留这么多帧，所以剪辑点在
/// 媒体内部的 `handleFrames` 处。记录端不受影响（时间线上还是那么长）。
String buildCmx3600({
  required String title,
  required List<DeliveryClip> clips,
  int handleFrames = kEdlDefaultHandleFrames,
  int recordStartFrames = kEdlDefaultRecordStartFrames,
}) {
  final StringBuffer out = StringBuffer()
    ..writeln('TITLE: $title')
    ..writeln('FCM: NON-DROP FRAME');

  int recordFrames = recordStartFrames;
  int eventNumber = 0;

  for (final DeliveryClip clip in clips) {
    final int duration = edlFramesFromMs(clip.durationMs);
    final int recordIn = recordFrames;
    // 记录端先推进：占位镜也要占位，否则后面的镜整体提前。
    recordFrames += duration;

    if (clip.placeholder) {
      _writeMarker(out, clip.marker, recordIn);
      continue;
    }

    eventNumber++;
    final int sourceIn = handleFrames;
    out
      ..writeln()
      ..writeln(
        '${eventNumber.toString().padLeft(3, '0')}  '
        '${_kReel.padRight(8)} '
        'V     C        '
        '${formatEdlTimecode(sourceIn)} '
        '${formatEdlTimecode(sourceIn + duration)} '
        '${formatEdlTimecode(recordIn)} '
        '${formatEdlTimecode(recordFrames)}',
      )
      ..writeln('* FROM CLIP NAME: ${clip.fileName}');
    final String? comment = clip.comment;
    if (comment != null && comment.trim().isNotEmpty) {
      out.writeln('* COMMENT: $comment');
    }
    _writeMarker(out, clip.marker, recordIn);
  }

  return out.toString();
}

/// Resolve / Premiere 都按 `* LOC: <tc> <color>  <name>` 读时间线标记。
void _writeMarker(StringBuffer out, String? marker, int atFrames) {
  if (marker == null || marker.trim().isEmpty) return;
  out.writeln('* LOC: ${formatEdlTimecode(atFrames)} WHITE  $marker');
}
