// toastServiceProvider：全应用唯一的通知出口。
//
// 实现就是 ToastCenter 本身（状态机 + 历史 + 提示音），这里只把它以契约类型暴露出去，
// 调用方只依赖 core/interfaces/toast_service.dart。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interfaces/toast_service.dart';
import 'toast_center.dart';

final toastServiceProvider = Provider<ToastService>(
  (ref) => ref.watch(toastCenterProvider.notifier),
  name: 'toastServiceProvider',
);
