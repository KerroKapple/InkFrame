// 挂起写入注册表的注入点（BOARD 第 201 行）。
//
// app-scoped（非 autoDispose）：退出序列要在 `container.dispose()` 之前读到它，
// 而那一刻早就没有任何 widget 在 watch 了。
//
// `AppTeardown` 对它做存在性探测（只回收已实例化的 provider），所以「从没打开过
// 检查器」的退出路径连这个对象都不会被构造出来。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/pending_write_registry.dart';
import '../interfaces/pending_write_flush.dart';
import 'logger.dart';

/// logger 懒取（同 secureStorageServiceProvider 的 `() => ref.read(appPathsProvider)`
/// 口径）：注册表只在超时 / 实现方失手时需要日志，不该让「挂载检查器」把
/// FileLoggerService 变成硬依赖。理由详见 InMemoryPendingWriteRegistry 的字段注释。
final pendingWriteRegistryProvider = Provider<PendingWriteRegistry>(
  (ref) => InMemoryPendingWriteRegistry(logger: () => ref.read(loggerProvider)),
  name: 'pendingWriteRegistryProvider',
);
