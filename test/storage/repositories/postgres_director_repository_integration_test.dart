// 导演会话 / 事件日志仓储（真 PG）：seq 连续、并发追加不撞号、会话写回与 updated_at
// 同事务、软删隐藏、项目软删隐藏、JSONB payload 往返。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/director.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_director_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:postgres/postgres.dart';

import '../schema/pg_test_harness.dart';

void main() {
  PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'director');
  });

  tearDown(() async => harness?.close());

  Future<({String projectId, String canvasId})> seed(Session s) async {
    final String pid = await PostgresProjectRepository(s).create(name: 'p');
    final String cid = await PostgresCanvasRepository(s).create(projectId: pid, name: 'c');
    return (projectId: pid, canvasId: cid);
  }

  test('seq 从 1 连续；parent_seq / payload 原样；写回语言与设定并 touch updated_at', () async {
    final PgTestHarness? h = harness;
    if (h == null) return markTestSkipped('TEST_PG_URL 未设置');
    final repo = PostgresDirectorRepository(h.conn);
    final ids = await seed(h.conn);
    final DirectorSession s = await repo.createSession(
      projectId: ids.projectId,
      canvasId: ids.canvasId,
    );
    expect(s.contentLanguage, '');
    expect(s.setting, DirectorSetting.empty);

    final DirectorEvent e1 = await repo.appendEvent(
      s.id,
      kind: DirectorEventKind.scriptSubmitted,
      payload: <String, Object?>{'text': '山径破晓', 'feedback': <Object?>[]},
    );
    final DirectorEvent e2 = await repo.appendEvent(
      s.id,
      kind: DirectorEventKind.storyboardProposed,
      parentSeq: e1.seq,
      payload: <String, Object?>{
        'shots': <Object?>[
          <String, Object?>{'label': 'a', 'duration_ms': 3000},
        ],
      },
      contentLanguage: 'zh-CN',
      setting: const DirectorSetting(era: '唐', artStyle: '水墨'),
    );
    expect(<int>[e1.seq, e2.seq], <int>[1, 2]);
    expect(e1.parentSeq, isNull);
    expect(e2.parentSeq, 1);

    final List<DirectorEvent> all = await repo.listEvents(s.id);
    expect(all.map((DirectorEvent e) => e.kind), <DirectorEventKind>[
      DirectorEventKind.scriptSubmitted,
      DirectorEventKind.storyboardProposed,
    ]);
    expect(all.last.payload['shots'], <Object?>[
      <String, Object?>{'label': 'a', 'duration_ms': 3000},
    ]);

    final DirectorSession? after = await repo.findSession(s.id);
    expect(after!.contentLanguage, 'zh-CN');
    expect(after.setting, const DirectorSetting(era: '唐', artStyle: '水墨'));
    expect(after.updatedAt.isAfter(s.updatedAt), isTrue);
  });

  test('并发追加不撞号：20 路同时追加 ⇒ seq 恰为 1..20', () async {
    final PgTestHarness? h = harness;
    if (h == null) return markTestSkipped('TEST_PG_URL 未设置');
    final ids = await seed(h.conn);
    final Uri url = Uri.parse(Platform.environment['TEST_PG_URL']!);
    final Pool<void> pool = Pool<void>.withEndpoints(
      <Endpoint>[
        Endpoint(
          host: url.host,
          port: url.hasPort ? url.port : 5432,
          database: url.pathSegments.isEmpty ? 'postgres' : url.pathSegments.first,
          username: url.userInfo.split(':').first,
          password: url.userInfo.contains(':') ? url.userInfo.split(':').last : null,
        ),
      ],
      settings: PoolSettings(
        maxConnectionCount: 8,
        sslMode: SslMode.disable,
        onOpen: (Connection c) => c.execute('SET search_path TO "${h.schema}"'),
      ),
    );
    addTearDown(pool.close);
    final repo = PostgresDirectorRepository(pool);
    final DirectorSession s = await repo.createSession(
      projectId: ids.projectId,
      canvasId: ids.canvasId,
    );

    final List<DirectorEvent> got = await Future.wait(<Future<DirectorEvent>>[
      for (int i = 0; i < 20; i++)
        repo.appendEvent(
          s.id,
          kind: DirectorEventKind.modelRequest,
          payload: <String, Object?>{'i': i},
        ),
    ]);
    expect(
      got.map((DirectorEvent e) => e.seq).toList()..sort(),
      List<int>.generate(20, (int i) => i + 1),
    );
  });

  test('会话软删 ⇒ 会话与事件都读不到，再追加报 session_not_found', () async {
    final PgTestHarness? h = harness;
    if (h == null) return markTestSkipped('TEST_PG_URL 未设置');
    final repo = PostgresDirectorRepository(h.conn);
    final ids = await seed(h.conn);
    final DirectorSession s = await repo.createSession(
      projectId: ids.projectId,
      canvasId: ids.canvasId,
    );
    await repo.appendEvent(s.id, kind: DirectorEventKind.scriptSubmitted);

    expect(await repo.softDeleteSession(s.id), 1);
    expect(await repo.findSession(s.id), isNull);
    expect(await repo.listEvents(s.id), isEmpty);
    await expectLater(
      repo.appendEvent(s.id, kind: DirectorEventKind.humanConfirmed),
      throwsA(isA<LocalIOError>()
          .having((LocalIOError e) => e.extra['reason'], 'reason', 'session_not_found')),
    );
  });

  test('项目软删 ⇒ 会话与事件随之隐藏', () async {
    final PgTestHarness? h = harness;
    if (h == null) return markTestSkipped('TEST_PG_URL 未设置');
    final repo = PostgresDirectorRepository(h.conn);
    final ids = await seed(h.conn);
    final DirectorSession s = await repo.createSession(
      projectId: ids.projectId,
      canvasId: ids.canvasId,
    );
    await repo.appendEvent(s.id, kind: DirectorEventKind.scriptSubmitted);
    await PostgresProjectRepository(h.conn).softDelete(ids.projectId);

    expect(await repo.findSession(s.id), isNull);
    expect(await repo.listEvents(s.id), isEmpty);
  });

  test('约束：parent_seq 必须早于自己；(session_id, seq) 唯一', () async {
    final PgTestHarness? h = harness;
    if (h == null) return markTestSkipped('TEST_PG_URL 未设置');
    final repo = PostgresDirectorRepository(h.conn);
    final ids = await seed(h.conn);
    final DirectorSession s = await repo.createSession(
      projectId: ids.projectId,
      canvasId: ids.canvasId,
    );
    await expectLater(
      repo.appendEvent(s.id, kind: DirectorEventKind.modelRequest, parentSeq: 1),
      throwsA(isA<LocalIOError>()),
    );
    await repo.appendEvent(s.id, kind: DirectorEventKind.scriptSubmitted);
    await expectLater(
      h.conn.execute(
        Sql.named(
          "INSERT INTO director_events (session_id, seq, kind) VALUES (@s, 1, 'x')",
        ),
        parameters: <String, Object?>{'s': s.id},
      ),
      throwsA(isA<ServerException>()),
    );
  });

  test('v8 → v9 前向迁移：存量数据原样保留，两张新表可用', () async {
    final String? url = Platform.environment['TEST_PG_URL'];
    if (url == null || url.isEmpty) return markTestSkipped('TEST_PG_URL 未设置');
    final Connection conn = await Connection.openFromUrl(url);
    final String schema = 'dir_up_${DateTime.now().microsecondsSinceEpoch}';
    try {
      await conn.execute('CREATE SCHEMA "$schema"');
      await conn.execute('SET search_path TO "$schema"');
      await MigrationRunner(conn, migrations: kAppMigrations.sublist(0, 8)).migrate();
      final ids = await seed(conn);

      await MigrationRunner(conn, migrations: kAppMigrations).migrate();
      final ver = await conn.execute('SELECT version FROM schema_version WHERE id = 1');
      expect(ver.first[0], 9);
      final Result p = await conn.execute(
        Sql.named('SELECT name FROM projects WHERE id = @id'),
        parameters: <String, Object?>{'id': ids.projectId},
      );
      expect(p.first[0], 'p');
      final repo = PostgresDirectorRepository(conn);
      final DirectorSession s = await repo.createSession(
        projectId: ids.projectId,
        canvasId: ids.canvasId,
      );
      expect((await repo.appendEvent(s.id, kind: DirectorEventKind.scriptSubmitted)).seq, 1);

      // 降级拒绝：v9 库被只认到 v8 的应用打开。
      await expectLater(
        MigrationRunner(conn, migrations: kAppMigrations.sublist(0, 8)).migrate(),
        throwsA(isA<SchemaDowngradeError>()),
      );
    } finally {
      await conn.execute('DROP SCHEMA "$schema" CASCADE');
      await conn.close();
    }
  });
}
