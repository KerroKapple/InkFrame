// 测试用 UnitOfWork：把给定 fake 仓储原样暴露给闭包，不做真事务/回滚。
// 真正的回滚语义由 test/storage/transaction_integration_test.dart（真 PG）覆盖。
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/job_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';

class FakeRepositoryScope implements RepositoryScope {
  FakeRepositoryScope({
    NodeRepository? nodes,
    EdgeRepository? edges,
    CanvasRepository? canvas,
    ProjectRepository? projects,
    JobRepository? jobs,
  })  : _nodes = nodes,
        _edges = edges,
        _canvas = canvas,
        _projects = projects,
        _jobs = jobs;

  final NodeRepository? _nodes;
  final EdgeRepository? _edges;
  final CanvasRepository? _canvas;
  final ProjectRepository? _projects;
  final JobRepository? _jobs;

  @override
  NodeRepository get nodes => _nodes ?? (throw StateError('nodes not provided'));
  @override
  EdgeRepository get edges => _edges ?? (throw StateError('edges not provided'));
  @override
  CanvasRepository get canvas =>
      _canvas ?? (throw StateError('canvas not provided'));
  @override
  ProjectRepository get projects =>
      _projects ?? (throw StateError('projects not provided'));
  @override
  JobRepository get jobs => _jobs ?? (throw StateError('jobs not provided'));
}

class FakeUnitOfWork implements UnitOfWork {
  FakeUnitOfWork(this.scope);
  final RepositoryScope scope;

  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) =>
      action(scope);
}

/// run 在调用闭包前先阻塞在 [gate]，用于模拟事务进行中 provider 被 dispose（ME-27）。
class GatedFakeUnitOfWork implements UnitOfWork {
  GatedFakeUnitOfWork(this.scope, this.gate);
  final RepositoryScope scope;
  final Future<void> gate;

  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) async {
    await gate;
    return action(scope);
  }
}
