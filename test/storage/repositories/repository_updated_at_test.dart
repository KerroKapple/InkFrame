// Repository unit 测：验证 buildUpdate 会自动注入 updated_at，以及 BaseRepository 行为。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/base_repository.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:inkframe/storage/repositories/postgres_style_lane_repository.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('BaseRepository.buildUpdate', () {
    test('patch 未显式传 updated_at → 自动注入', () {
      final h = _Helper();
      final q = h.buildUpdate('projects', 'id-1', {'name': 'foo'});
      expect(q.sql, contains('updated_at = @p_updated_at'));
      expect(q.params['p_updated_at'], isNotNull);
      expect(q.params['p_name'], 'foo');
      expect(q.params['id'], 'id-1');
      expect(q.sql, contains('WHERE id = @id AND deleted_at IS NULL'));
    });

    test('patch 显式 updated_at → 原值保留', () {
      final h = _Helper();
      final q = h.buildUpdate('projects', 'id-1', {
        'name': 'foo',
        'updated_at': '2000-01-01T00:00:00Z',
      });
      expect(q.params['p_updated_at'], '2000-01-01T00:00:00Z');
    });

    test('includeDeletedFilter=false → WHERE 无 deleted_at', () {
      final h = _Helper();
      final q = h.buildUpdate('projects', 'id-1', {'name': 'foo'},
          includeDeletedFilter: false);
      expect(q.sql, contains('WHERE id = @id'));
      expect(q.sql.contains('deleted_at'), isFalse);
    });

    test('softDeletePatch / restorePatch 带时间戳', () {
      final h = _Helper();
      final sd = h.softDeletePatch();
      expect(sd['deleted_at'], isA<String>());
      expect(sd['updated_at'], isA<String>());
      final rs = h.restorePatch();
      expect(rs['deleted_at'], isNull);
      expect(rs['updated_at'], isA<String>());
    });
  });

  group('Postgres*Repository SQL spy', () {
    test('ProjectRepository.update 走 BaseRepository.withUpdatedAt', () async {
      final spy = _SpySession();
      final repo = PostgresProjectRepository(spy);
      await repo.update('p1', {'name': 'x'});
      expect(spy.lastSql, contains('UPDATE projects SET'));
      expect(spy.lastSql, contains('updated_at'));
      expect(spy.lastParams?['p_updated_at'], isA<String>());
    });

    test('CanvasRepository.update 维护 updated_at', () async {
      final spy = _SpySession();
      final repo = PostgresCanvasRepository(spy);
      await repo.update('c1', {'name': 'x'});
      expect(spy.lastSql, contains('UPDATE canvases SET'));
      expect(spy.lastSql, contains('updated_at'));
    });

    test('StyleLaneRepository.update 维护 updated_at', () async {
      final spy = _SpySession();
      final repo = PostgresStyleLaneRepository(spy);
      await repo.update('s1', {'label': 'x'});
      expect(spy.lastSql, contains('UPDATE style_lanes SET'));
      expect(spy.lastSql, contains('updated_at'));
    });

    test('NodeRepository.update 维护 updated_at 并对 type_config cast ::jsonb',
        () async {
      final spy = _SpySession();
      final repo = PostgresNodeRepository(spy);
      await repo.update('n1', {
        'label': 'x',
        'type_config': {'prompt': 'p'},
      });
      expect(spy.lastSql, contains('UPDATE nodes SET'));
      expect(spy.lastSql, contains('updated_at'));
      expect(spy.lastSql, contains('type_config = @p_type_config::jsonb'));
    });

    test('NodeRepository.patchTypeConfig 使用 jsonb 合并并维护 updated_at',
        () async {
      final spy = _SpySession();
      final repo = PostgresNodeRepository(spy);
      await repo.patchTypeConfig('n1', {'progress': 0.5});
      expect(spy.lastSql, contains('type_config = type_config || @patch::jsonb'));
      expect(spy.lastSql, contains('updated_at = @uat'));
    });
  });
}

class _Helper with BaseRepository {
  @override
  Session get session => throw UnimplementedError();
}

class _SpySession implements Session {
  String? lastSql;
  Map<String, Object?>? lastParams;

  @override
  Future<Result> execute(
    Object query,
    {Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout}) async {
    // Sql.named(String) 底层是 SqlImpl，通过 dynamic 拿到 sql 字段。
    if (query is String) {
      lastSql = query;
    } else {
      try {
        lastSql = (query as dynamic).sql as String;
      } on NoSuchMethodError {
        lastSql = query.toString();
      }
    }
    if (parameters is Map<String, Object?>) {
      lastParams = parameters;
    } else if (parameters is Map) {
      lastParams = parameters.cast<String, Object?>();
    }
    return Result(rows: const [], affectedRows: 0, schema: ResultSchema(const []));
  }

  @override
  Future<Statement> prepare(Object query) => throw UnimplementedError();
  @override
  bool get isOpen => true;
  @override
  Future<void> get closed async {}
}
