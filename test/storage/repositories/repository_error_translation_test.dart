// Repository 错误翻译单测（不触 PG）：
//   底层 session 抛 postgres 异常 → repo 公开方法抛 LocalIOError，
//   不让裸 ServerException/PgException 冒泡到调用方（违反 docs/CLAUDE.md）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_edge_repository.dart';
import 'package:inkframe/storage/repositories/postgres_job_repository.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:postgres/messages.dart';
import 'package:postgres/postgres.dart';
// ignore: implementation_imports
import 'package:postgres/src/exceptions.dart' show buildExceptionFromErrorFields;

ServerException _serverException(String code) {
  return buildExceptionFromErrorFields(<ErrorField>[
    ErrorField(ErrorFieldId.severity, 'ERROR'),
    ErrorField(ErrorFieldId.code, code),
    ErrorField(ErrorFieldId.message, 'boom'),
  ]);
}

/// 每次 execute 都抛指定异常的 fake session。
class _ThrowingSession implements Session {
  _ThrowingSession(this.error);
  final Object error;

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) async {
    throw error;
  }

  @override
  Future<Statement> prepare(Object query) => throw UnimplementedError();
  @override
  bool get isOpen => true;
  @override
  Future<void> get closed async {}
}

void main() {
  group('ServerException → LocalIOError 翻译', () {
    test('ProjectRepository.create', () async {
      final repo = PostgresProjectRepository(_ThrowingSession(
        _serverException('42P01'),
      ));
      await expectLater(
        () => repo.create(name: 'P'),
        throwsA(isA<LocalIOError>()
            .having((e) => e.extra['db_code'], 'db_code', '42P01')
            .having((e) => e.extra['table'], 'table', 'projects')),
      );
    });

    test('ProjectRepository.listAll', () async {
      final repo = PostgresProjectRepository(_ThrowingSession(
        _serverException('08006'),
      ));
      await expectLater(repo.listAll, throwsA(isA<LocalIOError>()));
    });

    test('CanvasRepository.update', () async {
      final repo = PostgresCanvasRepository(_ThrowingSession(
        _serverException('23505'),
      ));
      await expectLater(
        () => repo.update('c1', {'name': 'x'}),
        throwsA(isA<LocalIOError>()),
      );
    });

    test('NodeRepository.softDelete', () async {
      final repo = PostgresNodeRepository(_ThrowingSession(
        _serverException('40001'),
      ));
      await expectLater(
        () => repo.softDelete('n1'),
        throwsA(isA<LocalIOError>()),
      );
    });

    test('EdgeRepository.listOutgoing', () async {
      final repo = PostgresEdgeRepository(_ThrowingSession(
        _serverException('42703'),
      ));
      await expectLater(
        () => repo.listOutgoing('a'),
        throwsA(isA<LocalIOError>()),
      );
    });

    test('JobRepository.transitionStatus', () async {
      final repo = PostgresJobRepository(_ThrowingSession(
        _serverException('23514'),
      ));
      await expectLater(
        () => repo.transitionStatus(
          id: 'j1',
          fromStatuses: const ['pending'],
          toStatus: 'polling',
        ),
        throwsA(isA<LocalIOError>()),
      );
    });
  });

  group('连接级 PgException → LocalIOError 翻译', () {
    test('JobRepository.create（socket error，无 db_code）', () async {
      final repo = PostgresJobRepository(_ThrowingSession(
        PgException('Socket error: connection reset'),
      ));
      await expectLater(
        () => repo.create(
          canvasId: 'c',
          sourceNodeId: 'n',
          providerId: 'kling',
          jobType: 'image',
          fullPrompt: 'fp',
          userPrompt: 'up',
        ),
        throwsA(isA<LocalIOError>()
            .having((e) => e.extra.containsKey('db_code'), 'no db_code', false)),
      );
    });
  });
}
