// 项目导出进行中标志（LB-11）：防重入——同一时刻只允许一个导出任务。
// v1 不做进度 UI（记 BOARD 债），仅用于忽略导出期间的重复触发。
import 'package:flutter_riverpod/flutter_riverpod.dart';

final projectExportBusyProvider = StateProvider<bool>(
  (ref) => false,
  name: 'projectExportBusyProvider',
);
