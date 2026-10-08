// 交付设置的读写（P6）：`projects.delivery_settings`（JSONB，迁移 v8）。
//
// 稿上这块**没有「保存」按钮**——改动即存。所以每个控件的 onChanged 直接调
// [DeliverySettingsController.save]，写库失败就把值退回去（界面不该留着一个
// 看起来已保存、实际没进库的开关）。
//
// 按 projectId 分族、**不 autoDispose**：切到画廊再切回来，这份设置不该重读一次库
// （与 gallery_filter / gallery_selection 同策略）。
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/di/logger.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/project_repository.dart';
import '../models/delivery_settings.dart';

const String _kLogModule = 'delivery';

final deliverySettingsProvider = AsyncNotifierProviderFamily<
    DeliverySettingsController, DeliverySettings, String>(
  DeliverySettingsController.new,
  name: 'deliverySettingsProvider',
);

class DeliverySettingsController
    extends FamilyAsyncNotifier<DeliverySettings, String> {
  bool _alive = false;

  @override
  Future<DeliverySettings> build(String projectId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final ProjectRepository repo =
        await ref.watch(projectRepositoryProvider.future);
    final Map<String, Object?>? row = await repo.findById(projectId);
    return DeliverySettings.fromMap(
      _asJsonMap(row?[ProjectCol.deliverySettings]),
    );
  }

  /// 改一项就存一次。值没变时直接返回（开关的 onChanged 可能被重复调）。
  Future<void> save(DeliverySettings next) async {
    final DeliverySettings? current = state.valueOrNull;
    if (current == next) return;
    // 先乐观上屏：开关要跟手，不能等一次往返。
    state = AsyncData<DeliverySettings>(next);
    try {
      final ProjectRepository repo =
          await ref.read(projectRepositoryProvider.future);
      await repo.update(arg, <String, Object?>{
        ProjectCol.deliverySettings: next.toMap(),
      });
    } on InkError catch (e) {
      // 写库失败就把值退回去——留着一个「看起来存了」的开关比报错更糟。
      if (!_alive) return;
      ref.read(loggerProvider).warn(
        _kLogModule,
        'delivery settings save failed',
        extra: <String, Object?>{'project_id': arg, 'code': e.code.wire},
      );
      if (current != null) state = AsyncData<DeliverySettings>(current);
    }
  }
}

/// JSONB 列：驱动可能回已解码的 Map，也可能回 JSON 文本。坏值一律当空对象
/// （[DeliverySettings.fromMap] 再把缺的键退默认）——**绝不抛**，一个坏字段
/// 不该让项目打不开。
Map<String, Object?>? _asJsonMap(Object? raw) {
  if (raw is Map<String, Object?>) return raw;
  if (raw is Map) {
    return raw.map((Object? k, Object? v) => MapEntry<String, Object?>(k.toString(), v));
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (Object? k, Object? v) => MapEntry<String, Object?>(k.toString(), v),
        );
      }
    } on FormatException {
      return null;
    }
  }
  return null;
}
