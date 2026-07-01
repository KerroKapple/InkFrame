// PostgresUnitOfWork —— 基于 postgres SessionExecutor.runTx 的事务工作单元。
//
// run 把 TxSession 交给注入的 scope 工厂构造一组仓储：同一事务内的写入共享连接，
// 闭包抛出即 runTx 回滚。仓储的具体 new 由 DI 层（lib/core/di）通过工厂提供，
// 本类只依赖 RepositoryScope 抽象与一个 `Session → RepositoryScope` 工厂（DIP）。
import 'package:postgres/postgres.dart';

import '../core/errors/ink_error.dart';
import '../core/interfaces/batch_result_repository.dart';
import '../core/interfaces/canvas_repository.dart';
import '../core/interfaces/character_repository.dart';
import '../core/interfaces/edge_repository.dart';
import '../core/interfaces/job_repository.dart';
import '../core/interfaces/node_repository.dart';
import '../core/interfaces/project_repository.dart';
import '../core/interfaces/prompt_preset_repository.dart';
import '../core/interfaces/style_lane_repository.dart';
import '../core/interfaces/unit_of_work.dart';

class PostgresUnitOfWork implements UnitOfWork {
  PostgresUnitOfWork(this._executor, this._scopeOf);

  /// Pool / Connection 皆可——runTx 把整个闭包落在同一连接的单事务内。
  final SessionExecutor _executor;

  /// 由 DI 层注入：把单个事务 [Session] 装配成一组仓储。
  final RepositoryScope Function(Session session) _scopeOf;

  /// 闭包内仓储的 PgException 已由 BaseRepository.guard 翻成 InkError；
  /// 此处再兜住 runTx 自身（BEGIN/COMMIT/ROLLBACK）冒出的 PgException，
  /// 保证事务边界对外只抛 InkError，绝不泄漏裸 PgException 到 UI。
  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) async {
    try {
      return await _executor.runTx((tx) => action(_scopeOf(tx)));
    } on InkError {
      rethrow;
    } on PgException catch (e, st) {
      throw LocalIOError(
        extra: const <String, Object?>{'op': 'transaction'},
        cause: e,
        stackTrace: st,
      );
    }
  }
}

/// RepositoryScope 的不可变持有者：只存已装配好的仓储，自身不 new 任何注入物。
class RepositoryScopeData implements RepositoryScope {
  RepositoryScopeData({
    required this.nodes,
    required this.edges,
    required this.canvas,
    required this.projects,
    required this.jobs,
    required this.styleLanes,
    required this.batchResults,
    required this.characters,
    required this.promptPresets,
  });

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
  @override
  final StyleLaneRepository styleLanes;
  @override
  final BatchResultRepository batchResults;
  @override
  final CharacterRepository characters;
  @override
  final PromptPresetRepository promptPresets;
}
