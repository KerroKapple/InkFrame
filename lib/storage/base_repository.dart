// BaseRepository mixin：统一 updated_at 维护 + 通用构造器。
//
// PRD §21 硬规则：updated_at 必须由应用层维护，不走 DB trigger。
// 所有 Repository 的 update/upsert 都必须经 withUpdatedAt 包装——
// CI 的 check-updated-at.sh 扫描 UPDATE 语句强制执行。
import 'package:postgres/postgres.dart';

/// Repository 共享工具集。
mixin BaseRepository {
  Session get session;

  /// 给 patch 注入 updated_at = 当前 UTC ISO8601（TIMESTAMPTZ 会自动解析）。
  Map<String, Object?> withUpdatedAt(Map<String, Object?> patch) {
    return <String, Object?>{
      ...patch,
      'updated_at': utcNowIso(),
    };
  }

  String utcNowIso() => DateTime.now().toUtc().toIso8601String();

  /// 构造带时间戳的软删除 patch。
  Map<String, Object?> softDeletePatch() => <String, Object?>{
        'deleted_at': utcNowIso(),
        'updated_at': utcNowIso(),
      };

  /// 构造恢复 patch。
  Map<String, Object?> restorePatch() => <String, Object?>{
        'deleted_at': null,
        'updated_at': utcNowIso(),
      };

  /// 通用 UPDATE 构造：返回 (SQL, params)。
  /// 例：buildUpdate('projects', 'a-uuid', {'name': 'x'})
  ///     → UPDATE projects SET name = @p_name, updated_at = @p_updated_at
  ///       WHERE id = @id
  /// patch 若不含 updated_at，会自动注入。
  ({String sql, Map<String, Object?> params}) buildUpdate(
    String table,
    String id,
    Map<String, Object?> patch, {
    bool includeDeletedFilter = true,
  }) {
    final merged = patch.containsKey('updated_at')
        ? Map<String, Object?>.from(patch)
        : withUpdatedAt(patch);

    final setParts = <String>[];
    final params = <String, Object?>{'id': id};
    merged.forEach((key, value) {
      final param = 'p_$key';
      setParts.add('$key = @$param');
      params[param] = value;
    });

    final where = includeDeletedFilter
        ? 'WHERE id = @id AND deleted_at IS NULL'
        : 'WHERE id = @id';
    final sql = 'UPDATE $table SET ${setParts.join(', ')} $where';
    return (sql: sql, params: params);
  }

  /// 从 Result 中解析行 → Map；空结果返回 null。
  Map<String, Object?>? firstRow(Result result) {
    if (result.isEmpty) return null;
    return _rowToMap(result.first);
  }

  List<Map<String, Object?>> allRows(Result result) {
    return result.map(_rowToMap).toList(growable: false);
  }

  Map<String, Object?> _rowToMap(ResultRow row) {
    final out = <String, Object?>{};
    for (final (i, col) in row.schema.columns.indexed) {
      final name = col.columnName ?? '[$i]';
      out[name] = row[i];
    }
    return out;
  }
}
