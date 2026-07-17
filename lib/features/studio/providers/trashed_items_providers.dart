// 回收站读侧（LB-15）：软删项目 / 软删画布（按项目）。
//
// 坏行策略同 workspaceProjectsProvider：id / name / deleted_at 任一缺失或
// 类型不符 → 跳过该行。排序由 SQL 保证（deleted_at DESC），映射不重排。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/di/repositories.dart';

/// 回收站行（项目 / 画布共用形状）。
class TrashedItem {
  const TrashedItem({
    required this.id,
    required this.name,
    required this.deletedAt,
  });

  final String id;
  final String name;
  final DateTime deletedAt;
}

List<TrashedItem> _mapRows(List<Map<String, Object?>> rows) {
  final result = <TrashedItem>[];
  for (final row in rows) {
    final id = row['id']?.toString();
    final name = row['name']?.toString();
    final deletedAt = row[CommonCol.deletedAt];
    if (id == null || name == null || deletedAt is! DateTime) continue;
    result.add(TrashedItem(id: id, name: name, deletedAt: deletedAt));
  }
  return result;
}

/// 回收站项目（projects.deleted_at IS NOT NULL，deleted_at DESC）。
final trashedProjectsProvider =
    FutureProvider.autoDispose<List<TrashedItem>>((ref) async {
  final repo = await ref.watch(projectRepositoryProvider.future);
  return _mapRows(await repo.listTrashed());
}, name: 'trashedProjectsProvider');

/// 项目下回收站画布（canvases.deleted_at IS NOT NULL，deleted_at DESC）。
final trashedCanvasesProvider = FutureProvider.autoDispose
    .family<List<TrashedItem>, String>((ref, projectId) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  return _mapRows(await repo.listTrashedByProject(projectId));
}, name: 'trashedCanvasesProvider');
