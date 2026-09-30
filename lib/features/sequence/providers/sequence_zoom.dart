// 序列时间轴比例（px / s）。稿是 34px/s（42 秒适配约 1500px 轨道宽）；Ctrl + 滚轮缩放，
// 有上下限。纯 UI 态，不落库。
import 'package:flutter_riverpod/flutter_riverpod.dart';

const double kSequenceDefaultPxPerSec = 34;
const double kSequenceMinPxPerSec = 8;
const double kSequenceMaxPxPerSec = 160;
const double kSequenceZoomStep = 1.15;

final sequenceZoomProvider = StateProvider.autoDispose.family<double, String>(
  (ref, canvasId) => kSequenceDefaultPxPerSec,
  name: 'sequenceZoomProvider',
);

double clampSequenceZoom(double pxPerSec) => pxPerSec.clamp(kSequenceMinPxPerSec, kSequenceMaxPxPerSec);
