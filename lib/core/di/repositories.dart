// Repository DI — 把 Postgres 实现注入到 app scope。
//
// 所有 Repository 绑定到 pgMigratedConnectionProvider：首次解析时完成 PG start +
// schema migrate，后续 watch 直接拿到已就绪 Connection。
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
    final conn = await ref.watch(pgMigratedConnectionProvider.future);
    return PostgresProjectRepository(conn);
  },
  name: 'projectRepositoryProvider',
);

final canvasRepositoryProvider = FutureProvider<CanvasRepository>(
  (ref) async {
    final conn = await ref.watch(pgMigratedConnectionProvider.future);
    return PostgresCanvasRepository(conn);
  },
  name: 'canvasRepositoryProvider',
);

final nodeRepositoryProvider = FutureProvider<NodeRepository>(
  (ref) async {
    final conn = await ref.watch(pgMigratedConnectionProvider.future);
    return PostgresNodeRepository(conn);
  },
  name: 'nodeRepositoryProvider',
);

final edgeRepositoryProvider = FutureProvider<EdgeRepository>(
  (ref) async {
    final conn = await ref.watch(pgMigratedConnectionProvider.future);
    return PostgresEdgeRepository(conn);
  },
  name: 'edgeRepositoryProvider',
);

final jobRepositoryProvider = FutureProvider<JobRepository>(
  (ref) async {
    final conn = await ref.watch(pgMigratedConnectionProvider.future);
    return PostgresJobRepository(conn);
  },
  name: 'jobRepositoryProvider',
);

final styleLaneRepositoryProvider = FutureProvider<StyleLaneRepository>(
  (ref) async {
    final conn = await ref.watch(pgMigratedConnectionProvider.future);
    return PostgresStyleLaneRepository(conn);
  },
  name: 'styleLaneRepositoryProvider',
);

final batchResultRepositoryProvider = FutureProvider<BatchResultRepository>(
  (ref) async {
    final conn = await ref.watch(pgMigratedConnectionProvider.future);
    return PostgresBatchResultRepository(conn);
  },
  name: 'batchResultRepositoryProvider',
);
