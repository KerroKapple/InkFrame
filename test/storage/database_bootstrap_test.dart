// DatabaseBootstrap 单测：编排顺序（pgcrypto → 迁移链）、重复调用安全、
// ServerException 在储层边界的翻译（→ DatabaseBootstrapError）与 23505 吞并。
// ServerException 经 buildExceptionFromErrorFields 构造（同 repository_error_translation_test）。
// 真库 roundtrip 幂等另由 database_bootstrap_integration_test.dart（@Tags(['pg'])）覆盖。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/database_bootstrap.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:postgres/messages.dart';
import 'package:postgres/postgres.dart';
// ignore: implementation_imports
import 'package:postgres/src/exceptions.dart' show buildExceptionFromErrorFields;

import 'fake_session_executor.dart';

ServerException _serverException(String code) {
  return buildExceptionFromErrorFields(<ErrorField>[
    ErrorField(ErrorFieldId.severity, 'ERROR'),
    ErrorField(ErrorFieldId.code, code),
    ErrorField(ErrorFieldId.message, 'boom'),
  ]);
}

void main() {
  group('DatabaseBootstrap', () {
    test('run() 先建 pgcrypto 扩展，再按序跑迁移链', () async {
      final exec = FakeSessionExecutor()
        ..session.queueResult(const [], forQueryFragment: 'FROM schema_version');

      await DatabaseBootstrap(
        exec,
        migrations: const [Migration(version: 1, sql: 'DDL-v1')],
      ).run();

      final sql = exec.session.executedSql;
      expect(
        sql,
        containsAllInOrder(<Matcher>[
          contains('CREATE EXTENSION IF NOT EXISTS pgcrypto'),
          contains('FROM schema_version'),
          equals('BEGIN'),
          contains('DDL-v1'),
          contains('INSERT INTO schema_version'),
          equals('COMMIT'),
        ]),
      );
      // pgcrypto 必须是第一条语句（gen_random_uuid 在建表前就得可用）。
      expect(sql.first, contains('CREATE EXTENSION IF NOT EXISTS pgcrypto'));
    });

    test('重复 run() 安全：pgcrypto 幂等重发，已达目标版本的迁移为 no-op', () async {
      final exec = FakeSessionExecutor()
        // 第一次：空库(v0)；第二次：已 v1。
        ..session.queueResult(const [], forQueryFragment: 'FROM schema_version')
        ..session.queueResult(const [
          [1],
        ], forQueryFragment: 'FROM schema_version');
      final bootstrap = DatabaseBootstrap(
        exec,
        migrations: const [Migration(version: 1, sql: 'DDL-v1')],
      );

      await bootstrap.run();
      final txAfterFirst = exec.txCount;
      await bootstrap.run();

      // 第二次不应再开迁移事务（已达目标版本）。
      expect(exec.txCount, txAfterFirst);
      // pgcrypto DDL 两次都发（IF NOT EXISTS 幂等）。
      expect(
        exec.session.executedSql
            .where((s) => s.contains('CREATE EXTENSION IF NOT EXISTS pgcrypto'))
            .length,
        2,
      );
    });

    test('迁移领域错误（SchemaMigrationError 系）原样上抛，不吞不改包', () async {
      final exec = FakeSessionExecutor()
        // 库版本(v5) > 目标(v1) → MigrationRunner 抛 SchemaDowngradeError。
        ..session.queueResult(const [
          [5],
        ], forQueryFragment: 'FROM schema_version');

      await expectLater(
        DatabaseBootstrap(
          exec,
          migrations: const [Migration(version: 1, sql: 'DDL-v1')],
        ).run(),
        throwsA(isA<SchemaDowngradeError>()),
      );
    });

    test('pgcrypto 遇 23505（并发建扩展竞争）→ 吞掉并继续迁移', () async {
      final exec = FakeSessionExecutor()
        ..session.queueResult(const [], forQueryFragment: 'FROM schema_version')
        ..session.failOn = 'CREATE EXTENSION'
        ..session.failWith = _serverException('23505');

      // 不抛错，且迁移照常推进（DDL 执行）。
      await DatabaseBootstrap(
        exec,
        migrations: const [Migration(version: 1, sql: 'DDL-v1')],
      ).run();

      expect(exec.session.executedSql, contains('DDL-v1'));
    });

    test('pgcrypto 非 23505 ServerException → 翻成 DatabaseBootstrapError', () async {
      final exec = FakeSessionExecutor()
        ..session.failOn = 'CREATE EXTENSION'
        ..session.failWith = _serverException('42501'); // insufficient_privilege

      await expectLater(
        DatabaseBootstrap(
          exec,
          migrations: const [Migration(version: 1, sql: 'DDL-v1')],
        ).run(),
        throwsA(isA<DatabaseBootstrapError>()),
      );
    });

    test('迁移期 ServerException → 翻成 DatabaseBootstrapError', () async {
      final exec = FakeSessionExecutor()
        ..session.queueResult(const [], forQueryFragment: 'FROM schema_version')
        ..session.failOn = 'DDL-v1'
        ..session.failWith = _serverException('42601'); // syntax_error

      await expectLater(
        DatabaseBootstrap(
          exec,
          migrations: const [Migration(version: 1, sql: 'DDL-v1')],
        ).run(),
        throwsA(isA<DatabaseBootstrapError>()),
      );
    });
  });
}
