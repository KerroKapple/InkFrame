// PostgresUnitOfWork —— 基于 postgres SessionExecutor.runTx 的事务工作单元。
//
// run 把一个 TxSession 喂给所有仓储构造器：同一事务内的写入共享连接，
// 闭包抛出即 runTx 回滚。仓储本身无需改动——它们本就接收 Session。
import 'package:postgres/postgres.dart';

import '../core/interfaces/canvas_repository.dart';
import '../core/interfaces/edge_repository.dart';
import '../core/interfaces/job_repository.dart';
import '../core/interfaces/node_repository.dart';
import '../core/interfaces/project_repository.dart';
import '../core/interfaces/unit_of_work.dart';
import 'repositories/postgres_canvas_repository.dart';
import 'repositories/postgres_edge_repository.dart';
import 'repositories/postgres_job_repository.dart';
import 'repositories/postgres_node_repository.dart';
import 'repositories/postgres_project_repository.dart';

class PostgresUnitOfWork implements UnitOfWork {
  PostgresUnitOfWork(this._executor);

  /// Pool / Connection 皆可——runTx 把整个闭包落在同一连接的单事务内。
  final SessionExecutor _executor;

  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) {
    return _executor.runTx((tx) => action(_PostgresRepositoryScope(tx)));
  }
}

class _PostgresRepositoryScope implements RepositoryScope {
  _PostgresRepositoryScope(Session s)
      : nodes = PostgresNodeRepository(s),
        edges = PostgresEdgeRepository(s),
        canvas = PostgresCanvasRepository(s),
        projects = PostgresProjectRepository(s),
        jobs = PostgresJobRepository(s);

  @override
  final NodeRepository nodes;
  @override
  final EdgeRepository edges;
  @override
  final CanvasRepository canvas;
  @override
  final ProjectRepository projects;
  @override
  final JobRepository jobs;
}
