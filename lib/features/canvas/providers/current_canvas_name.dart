// currentCanvasNameProvider — 当前打开画布的真实 name（从 canvases 表读）。
//
// 未选中画布 / 名称不可读时返回 null；CanvasScreen 据此回退到本地化默认名。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/di/repositories.dart';
import 'current_canvas_id.dart';

final currentCanvasNameProvider = FutureProvider.autoDispose<String?>(
  (ref) async {
    final canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId == null) return null;
    final repo = await ref.watch(canvasRepositoryProvider.future);
    final row = await repo.findById(canvasId);
    return row?.optString(CanvasCol.name);
  },
  name: 'currentCanvasNameProvider',
);
