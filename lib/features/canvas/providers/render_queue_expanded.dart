// 渲染队列折叠状态：null = 自动（有活跃任务或最近失败则展开，否则收起），
// true / false = 用户手动覆盖（点展开/收起后生效，直至再次切换）。
// 会话级记忆，跨画布共享（非 autoDispose）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

final renderQueueExpandedOverrideProvider = StateProvider<bool?>(
  (_) => null,
  name: 'renderQueueExpandedOverrideProvider',
);
