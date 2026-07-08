// 共享测试替身：SessionExecutor / Session / TxSession 的内存 fake。
//
// run 直通共享 session；runTx 记录 BEGIN/COMMIT/ROLLBACK；execute 记录 SQL、
// 可按片段排队返回行、可按片段抛错。MigrationRunner 与 DatabaseBootstrap 单测共用，
// 避免各自维护一份重复 fake。
import 'package:postgres/postgres.dart';

/// 假 SessionExecutor：run 直通共享 session；runTx 记录 BEGIN/COMMIT/ROLLBACK。
class FakeSessionExecutor implements SessionExecutor {
  final FakeSession session = FakeSession();
  int txCount = 0;

  @override
  Future<R> run<R>(
    Future<R> Function(Session session) fn, {
    SessionSettings? settings,
  }) =>
      fn(session);

  @override
  Future<R> runTx<R>(
    Future<R> Function(TxSession session) fn, {
    TransactionSettings? settings,
  }) async {
    txCount += 1;
    session.executedSql.add('BEGIN');
    try {
      final r = await fn(FakeTxSession(session));
      session.executedSql.add('COMMIT');
      return r;
    } catch (_) {
      session.executedSql.add('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> close({bool force = false}) async {}
}

class FakeTxSession implements TxSession {
  FakeTxSession(this._inner);
  final FakeSession _inner;

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) =>
      _inner.execute(
        query,
        parameters: parameters,
        ignoreRows: ignoreRows,
        queryMode: queryMode,
        timeout: timeout,
      );

  @override
  Future<void> rollback() async {}

  @override
  Future<Statement> prepare(Object query) =>
      throw UnimplementedError('prepare not used in fake');

  @override
  bool get isOpen => true;

  @override
  Future<void> get closed async {}
}

class FakeSession implements Session {
  final List<String> executedSql = <String>[];
  final List<_Expectation> _queue = <_Expectation>[];

  /// 命中该片段的 SQL 直接抛错（模拟执行失败）。
  String? failOn;

  void queueResult(
    List<List<Object?>> rows, {
    required String forQueryFragment,
  }) {
    _queue.add(_Expectation(fragment: forQueryFragment, rows: rows));
  }

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) async {
    final sql = query.toString();
    executedSql.add(sql);
    final f = failOn;
    if (f != null && sql.contains(f)) {
      throw StateError('boom: $f');
    }
    final idx = _queue.indexWhere((e) => sql.contains(e.fragment));
    if (idx == -1) {
      return _emptyResult();
    }
    final match = _queue.removeAt(idx);
    return Result(
      rows: match.rows
          .map(
            (values) =>
                ResultRow(values: values, schema: ResultSchema(const [])),
          )
          .toList(),
      affectedRows: 0,
      schema: ResultSchema(const []),
    );
  }

  Result _emptyResult() => Result(
        rows: const [],
        affectedRows: 0,
        schema: ResultSchema(const []),
      );

  @override
  Future<Statement> prepare(Object query) =>
      throw UnimplementedError('prepare not used in fake');

  @override
  bool get isOpen => true;

  @override
  Future<void> get closed async {}
}

class _Expectation {
  _Expectation({required this.fragment, required this.rows});
  final String fragment;
  final List<List<Object?>> rows;
}
