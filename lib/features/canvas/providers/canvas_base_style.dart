// canvas_base_style.dart — 共享画布基底风格 provider + setBaseStyle。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/di/repositories.dart';

/// 读画布 base_style_prefix / base_style_suffix；失败降级为空字符串。
final canvasBaseStyleProvider = FutureProvider.autoDispose
    .family<({String prefix, String suffix}), String>((ref, canvasId) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  final row = await repo.findById(canvasId);
  return (
    prefix: row?.optString(CanvasCol.baseStylePrefix) ?? '',
    suffix: row?.optString(CanvasCol.baseStyleSuffix) ?? '',
  );
});

/// 持久化基底风格并失效 provider 触发重读。
/// 调用方均为 widget，取 WidgetRef。
Future<void> setBaseStyle(
  WidgetRef ref,
  String canvasId, {
  required String prefix,
  required String suffix,
}) async {
  final repo = await ref.read(canvasRepositoryProvider.future);
  await repo.update(canvasId, {
    CanvasCol.baseStylePrefix: prefix,
    CanvasCol.baseStyleSuffix: suffix,
  });
  ref.invalidate(canvasBaseStyleProvider(canvasId));
}
