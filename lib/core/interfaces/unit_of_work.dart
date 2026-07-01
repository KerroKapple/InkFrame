// UnitOfWork — 把多步写入收敛进单个数据库事务的工作单元。
//
// run 的闭包内任一步抛出 InkError → 整个事务回滚（由底层 runTx 保证）。
// 闭包通过 RepositoryScope 拿到的仓储全部绑定到同一 TxSession，
// 因此跨仓储的写入要么全部提交、要么全部回滚。
//
// 读多步、纯查询不必走 UnitOfWork——它只为"必须原子"的写入序列存在。
import 'batch_result_repository.dart';
import 'canvas_repository.dart';
import 'character_repository.dart';
import 'edge_repository.dart';
import 'job_repository.dart';
import 'node_repository.dart';
import 'project_repository.dart';
import 'style_lane_repository.dart';

/// 一组绑定到同一事务的仓储，供 [UnitOfWork.run] 的闭包使用。
abstract class RepositoryScope {
  NodeRepository get nodes;
  EdgeRepository get edges;
  CanvasRepository get canvas;
  ProjectRepository get projects;
  JobRepository get jobs;
  StyleLaneRepository get styleLanes;
  BatchResultRepository get batchResults;
  CharacterRepository get characters;
}

/// 事务工作单元：在单个事务内执行 [action]。
abstract class UnitOfWork {
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action);
}
