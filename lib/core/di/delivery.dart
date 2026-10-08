// 交付 DI（P6）—— app-scoped：把文件落进 `<项目目录>/exports/` 的服务。
//
// 写出器 registry **不在这里**：它认识 features/export 的模型，而 lib/core 不许
// import features/（test/quality/no_reverse_layer_import_test.dart）。
// 它在 lib/features/export/providers/delivery_writers.dart。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/file_delivery_service.dart';
import '../interfaces/delivery_service.dart';
import 'file_resolver.dart';
import 'logger.dart';

final deliveryServiceProvider = Provider<DeliveryService>(
  (ref) => FileDeliveryService(
    fileResolver: ref.watch(fileResolverServiceProvider),
    logger: ref.watch(loggerProvider),
  ),
  name: 'deliveryServiceProvider',
);
