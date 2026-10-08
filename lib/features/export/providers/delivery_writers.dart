// 写出器 registry 的注入点（P6）。
//
// 单独一个文件而不是塞进 delivery_controller.dart：测试要 override 它来自证
// 「registry 多一个写出器 ⇒ 那一段自动可选」这条路是活的，而面板那层也要读它来
// 决定四个段的可选性——两边都 import controller 会把依赖绕成一团。
//
// 不在 lib/core/di/：registry 认识 features/export 的模型，core 不许 import features/。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/delivery_writer_registry.dart';

final deliveryWriterRegistryProvider = Provider<DeliveryWriterRegistry>(
  (ref) => MapDeliveryWriterRegistry.production(),
  name: 'deliveryWriterRegistryProvider',
);
