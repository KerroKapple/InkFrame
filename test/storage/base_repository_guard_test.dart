// BaseRepository.guard 单测：postgres 异常 → LocalIOError 翻译边界。
//
// 覆盖：
//   - ServerException（带 pg code，如 42P01）→ LocalIOError，extra 含 db_code/op/table，
//     cause 为原异常。
//   - 连接级 PgException（无 code，如 socket error）→ LocalIOError，db_code 缺省。
//   - 正常路径透传返回值。
//   - 已是 InkError 的异常不被二次包裹。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/storage/base_repository.dart';
import 'package:postgres/messages.dart';
import 'package:postgres/postgres.dart';
// ignore: implementation_imports
import 'package:postgres/src/exceptions.dart' show buildExceptionFromErrorFields;

/// 构造一个带指定 pg code 的真 ServerException。
ServerException _serverException(String code, {String message = 'boom'}) {
  return buildExceptionFromErrorFields(<ErrorField>[
    ErrorField(ErrorFieldId.severity, 'ERROR'),
    ErrorField(ErrorFieldId.code, code),
    ErrorField(ErrorFieldId.message, message),
  ]);
}

/// 仅供测试：暴露 mixin 的 guard。
class _Guarded with BaseRepository {
  @override
  Session get session => throw UnimplementedError();

  Future<T> run<T>(String op, String table, Future<T> Function() body) =>
      guard(op, table, body);
}

void main() {
  late _Guarded g;
  setUp(() => g = _Guarded());

  test('正常路径透传返回值', () async {
    final v = await g.run('select', 'projects', () async => 42);
    expect(v, 42);
  });

  test('ServerException → LocalIOError，extra 带 db_code/op/table，cause 是原异常',
      () async {
    final original = _serverException('42P01');
    await expectLater(
      () => g.run('create', 'jobs', () async => throw original),
      throwsA(isA<LocalIOError>()
          .having((e) => e.code, 'code', InkErrorCode.localIOError)
          .having((e) => e.extra['db_code'], 'db_code', '42P01')
          .having((e) => e.extra['op'], 'op', 'create')
          .having((e) => e.extra['table'], 'table', 'jobs')
          .having((e) => e.cause, 'cause', same(original))),
    );
  });

  test('连接级 PgException（无 code）→ LocalIOError，db_code 缺省', () async {
    final original = PgException('Socket error: broken pipe');
    await expectLater(
      () => g.run('update', 'nodes', () async => throw original),
      throwsA(isA<LocalIOError>()
          .having((e) => e.cause, 'cause', same(original))
          .having((e) => e.extra.containsKey('db_code'), 'no db_code', false)
          .having((e) => e.extra['op'], 'op', 'update')
          .having((e) => e.extra['table'], 'table', 'nodes')),
    );
  });

  test('已是 InkError 的异常原样冒泡，不被二次包裹', () async {
    const original = LocalIOError(extra: {'op': 'inner'});
    await expectLater(
      () => g.run('outer', 'edges', () async => throw original),
      throwsA(same(original)),
    );
  });
}
