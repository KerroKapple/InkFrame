// Repository DI — 把 Postgres 实现注入到 app scope。
//
// 所有 Repository 绑定到 pgMigratedPoolProvider：首次解析时完成 PG start +
// schema migrate，后续 watch 直接拿到已就绪 Pool（Pool 实现 Session，断线自动换新连接）。
//
// ViewModels / Controllers 只依赖抽象接口；单测用 Riverpod override 打 mock。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/batch_result_repository.dart';
import '../interfaces/canvas_repository.dart';
import '../interfaces/edge_repository.dart';
import '../interfaces/job_repository.dart';
import '../interfaces/node_repository.dart';
import '../interfaces/project_repository.dart';
import '../interfaces/style_lane_repository.dart';
import '../interfaces/unit_of_work.dart';
import '../../storage/postgres_unit_of_work.dart';
import '../../storage/repositories/postgres_batch_result_repository.dart';
import '../../storage/repositories/postgres_canvas_repository.dart';
import '../../storage/repositories/postgres_edge_repository.dart';
import '../../storage/repositories/postgres_job_repository.dart';
import '../../storage/repositories/postgres_node_repository.dart';
import '../../storage/repositories/postgres_project_repository.dart';
import '../../storage/repositories/postgres_style_lane_repository.dart';
import 'database.dart';

final projectRepositoryProvider = FutureProvider<ProjectRepository>(
  (ref) async {
    final pool = await ref.watch(pgMigratedPoolProvider.future);
    return PostgresProjectRepository(pool);
  },
  name: 'projectRepositoryProvider',
);

final canvasRepositoryProvider = FutureProvider<CanvasRepository>(
  (ref) async {
    final pool = await ref.watch(pgMigratedPoolProvider.future);
    return PostgresCanvasRepository(pool);
  },
  name: 'canvasRepositoryProvider',
);

final nodeRepositoryProvider = FutureProvider<NodeRepository>(
  (ref) async {
    final pool = await ref.watch(pgMigratedPoolProvider.future);
    return PostgresNodeRepository(pool);
  },
  name: 'nodeRepositoryProvider',
);

final edgeRepositoryProvider = FutureProvider<EdgeRepository>(
  (ref) async {
    final pool = await ref.watch(pgMigratedPoolProvider.future);
    return PostgresEdgeRepository(pool);
  },
  name: 'edgeRepositoryProvider',
);

final jobRepositoryProvider = FutureProvider<JobRepository>(
  (ref) async {
    final pool = await ref.watch(pgMigratedPoolProvider.future);
    return PostgresJobRepository(pool);
  },
  name: 'jobRepositoryProvider',
);

final styleLaneRepositoryProvider = FutureProvider<StyleLaneRepository>(
  (ref) async {
    final pool = await ref.watch(pgMigratedPoolProvider.future);
    return PostgresStyleLaneRepository(pool);
  },
  name: 'styleLaneRepositoryProvider',
);

final batchResultRepositoryProvider = FutureProvider<BatchResultRepository>(
  (ref) async {
    final pool = await ref.watch(pgMigratedPoolProvider.future);
    return PostgresBatchResultRepository(pool);
  },
  name: 'batchResultRepositoryProvider',
);

/// 事务工作单元——多步写入原子化（仓储绑定到同一 runTx 事务）。
/// 具体仓储的装配（new）在此 DI 层完成，PostgresUnitOfWork 只依赖工厂抽象。
final unitOfWorkProvider = FutureProvider<UnitOfWork>(
  (ref) async {
    final pool = await ref.watch(pgMigratedPoolProvider.future);
    return PostgresUnitOfWork(
      pool,
      (s) => RepositoryScopeData(
        nodes: PostgresNodeRepository(s),
        edges: PostgresEdgeRepository(s),
        canvas: PostgresCanvasRepository(s),
        projects: PostgresProjectRepository(s),
        jobs: PostgresJobRepository(s),
      ),
    );
  },
  name: 'unitOfWorkProvider',
);
