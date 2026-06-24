# Backend P0#1 — Multi-step Write Transactions (UnitOfWork) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the three multi-step DB write sites atomic by introducing a `UnitOfWork` abstraction that runs a closure over a set of repositories bound to a single Postgres transaction, and removing the hand-rolled compensation logic it replaces.

**Architecture:** A `UnitOfWork.run((scope) async {...})` executes the closure inside `SessionExecutor.runTx`; every repository in `scope` is constructed over the same `TxSession`, so any throw rolls back the whole unit. Repositories are unchanged — they already accept a `Session`. Controllers stop simulating atomicity by hand (compensating deletes) and instead wrap their multi-write sequences in `uow.run`.

**Tech Stack:** Dart, Flutter, Riverpod (hand-written providers), `postgres` v3 (`Pool`/`SessionExecutor`/`TxSession`/`runTx`), flutter_test.

## Global Constraints

- DI only via Riverpod providers; depend on abstractions, never concrete repos (docs/CLAUDE.md §SOLID-D).
- Zero backward compatibility: replace the compensation logic outright, do not keep it "just in case".
- Errors are `InkError` subtypes only; repository `guard()` already maps `PgException` → `LocalIOError`. `runTx` rolls back on any throw.
- Comments in Chinese, minimal.
- Every commit compiles, passes `flutter analyze`, passes `flutter test`, keeps en/zh ARB parity (no ARB changes expected here).
- Flutter is not on PATH: invoke `C:\Users\Kerro\flutter\bin\flutter.bat`.
- Real-PG tests are tagged `@Tags(['pg'])` and skipped unless `TEST_PG_URL` is set; unit tests use in-memory fakes which do **not** roll back — true rollback is asserted only in the pg integration test.

---

### Task 1: `UnitOfWork` + `RepositoryScope` interfaces

**Files:**
- Create: `lib/core/interfaces/unit_of_work.dart`

**Interfaces:**
- Produces:
  - `abstract class RepositoryScope { NodeRepository get nodes; EdgeRepository get edges; CanvasRepository get canvas; ProjectRepository get projects; JobRepository get jobs; }`
  - `abstract class UnitOfWork { Future<T> run<T>(Future<T> Function(RepositoryScope scope) action); }`

- [ ] **Step 1: Write the interface file**

```dart
// UnitOfWork — 把多步写入收敛进单个数据库事务的工作单元。
//
// run 的闭包内任一步抛出 InkError → 整个事务回滚（由底层 runTx 保证）。
// 闭包通过 RepositoryScope 拿到的仓储全部绑定到同一 TxSession，
// 因此跨仓储的写入要么全部提交、要么全部回滚。
//
// 读多步、纯查询不必走 UnitOfWork——它只为"必须原子"的写入序列存在。
import 'canvas_repository.dart';
import 'edge_repository.dart';
import 'job_repository.dart';
import 'node_repository.dart';
import 'project_repository.dart';

/// 一组绑定到同一事务的仓储，供 [UnitOfWork.run] 的闭包使用。
abstract class RepositoryScope {
  NodeRepository get nodes;
  EdgeRepository get edges;
  CanvasRepository get canvas;
  ProjectRepository get projects;
  JobRepository get jobs;
}

/// 事务工作单元：在单个事务内执行 [action]。
abstract class UnitOfWork {
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action);
}
```

- [ ] **Step 2: Analyze**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat analyze lib/core/interfaces/unit_of_work.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/interfaces/unit_of_work.dart
git commit -m "feat(core): UnitOfWork + RepositoryScope abstractions for transactional writes"
```

---

### Task 2: `PostgresUnitOfWork` implementation + DI provider

**Files:**
- Create: `lib/storage/postgres_unit_of_work.dart`
- Modify: `lib/core/di/repositories.dart` (add `unitOfWorkProvider`)

**Interfaces:**
- Consumes: `UnitOfWork`, `RepositoryScope` (Task 1); `pgMigratedPoolProvider` from `lib/core/di/database.dart`.
- Produces:
  - `class PostgresUnitOfWork implements UnitOfWork { PostgresUnitOfWork(SessionExecutor executor); }`
  - `final unitOfWorkProvider = FutureProvider<UnitOfWork>(...)`

- [ ] **Step 1: Write the implementation**

```dart
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
```

- [ ] **Step 2: Add the DI provider** to `lib/core/di/repositories.dart` (append after the existing providers; add imports for `unit_of_work.dart` and `postgres_unit_of_work.dart`):

```dart
final unitOfWorkProvider = FutureProvider<UnitOfWork>(
  (ref) async {
    final pool = await ref.watch(pgMigratedPoolProvider.future);
    return PostgresUnitOfWork(pool);
  },
  name: 'unitOfWorkProvider',
);
```

- [ ] **Step 3: Analyze**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat analyze lib/storage/postgres_unit_of_work.dart lib/core/di/repositories.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/storage/postgres_unit_of_work.dart lib/core/di/repositories.dart
git commit -m "feat(storage): PostgresUnitOfWork over runTx + unitOfWorkProvider DI"
```

---

### Task 3: `FakeUnitOfWork` test harness

**Files:**
- Create: `test/_harness/fake_unit_of_work.dart`

**Interfaces:**
- Consumes: `UnitOfWork`, `RepositoryScope`, the 5 repo interfaces.
- Produces:
  - `class FakeRepositoryScope implements RepositoryScope` — built from caller-supplied fakes (any omitted repo throws on access).
  - `class FakeUnitOfWork implements UnitOfWork` — runs the closure against a fixed scope; **no rollback** (documented).

- [ ] **Step 1: Write the harness**

```dart
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
```

- [ ] **Step 2: Analyze**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat analyze test/_harness/fake_unit_of_work.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add test/_harness/fake_unit_of_work.dart
git commit -m "test(harness): FakeUnitOfWork + FakeRepositoryScope for transactional controller tests"
```

---

### Task 4: `StudioProjectsController.createProject` → UnitOfWork

**Files:**
- Modify: `lib/features/studio/controllers/studio_projects_controller.dart`
- Modify: `test/features/studio/controllers/studio_projects_controller_test.dart`

**Interfaces:**
- Consumes: `unitOfWorkProvider` (Task 2), `FakeUnitOfWork` (Task 3).

- [ ] **Step 1: Rewrite the test** (drop the compensation-semantics test; assert orchestration + error propagation; rollback moves to pg integration). Replace the body of `test/features/studio/controllers/studio_projects_controller_test.dart` with:

```dart
// StudioProjectsController 单测：create 编排走 UnitOfWork + 列表刷新 + 错误冒泡。
// 真正的事务回滚（项目不残留）由 transaction_integration_test.dart（真 PG）断言。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/studio/controllers/studio_projects_controller.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';

class _FailingCanvasCreateRepository extends InMemoryCanvasRepository {
  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async {
    throw const LocalIOError();
  }
}

ProviderContainer _containerWith(
  InMemoryProjectRepository projects,
  InMemoryCanvasRepository canvases,
) {
  final c = ProviderContainer(
    overrides: <Override>[
      projectRepositoryProvider.overrideWith((_) async => projects),
      canvasRepositoryProvider.overrideWith((_) async => canvases),
      unitOfWorkProvider.overrideWith(
        (_) async => FakeUnitOfWork(
          FakeRepositoryScope(projects: projects, canvas: canvases),
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('StudioProjectsController.createProject', () {
    test('成功：项目 + 首画布都建出来，列表刷新可见', () async {
      final projects = InMemoryProjectRepository();
      final canvases = InMemoryCanvasRepository();
      final c = _containerWith(projects, canvases);

      await c.read(studioProjectsControllerProvider).createProject(
            name: 'Alpha',
            firstCanvasName: 'Untitled Canvas',
          );

      expect(projects.rows, hasLength(1));
      expect(canvases.rows, hasLength(1));
      expect(canvases.rows.values.single['name'], 'Untitled Canvas');

      final list = await c.read(workspaceProjectsProvider.future);
      expect(list.single.name, 'Alpha');
      expect(list.single.canvases.single.name, 'Untitled Canvas');
    });

    test('画布建失败：InkError 原样冒泡（事务回滚由 pg 集成测覆盖）', () async {
      final projects = InMemoryProjectRepository();
      final canvases = _FailingCanvasCreateRepository();
      final c = _containerWith(projects, canvases);

      await expectLater(
        c.read(studioProjectsControllerProvider).createProject(
              name: 'Alpha',
              firstCanvasName: 'Untitled Canvas',
            ),
        throwsA(isA<LocalIOError>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test, watch it fail**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/features/studio/controllers/studio_projects_controller_test.dart`
Expected: FAIL — `unitOfWorkProvider` referenced but controller still uses compensation path / `FakeUnitOfWork` unused, or compile error because controller doesn't read uow yet.

- [ ] **Step 3: Rewrite the controller**. Replace `createProject` body:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../providers/workspace_projects_provider.dart';

final studioProjectsControllerProvider =
    Provider.autoDispose<StudioProjectsController>(
  (ref) => StudioProjectsController(ref),
  name: 'studioProjectsControllerProvider',
);

class StudioProjectsController {
  StudioProjectsController(this._ref);

  final Ref _ref;

  /// 建项目 + 首画布——单事务原子：任一步失败整体回滚，不留半成品。
  Future<void> createProject({
    required String name,
    required String firstCanvasName,
  }) async {
    final uow = await _ref.read(unitOfWorkProvider.future);
    await uow.run((scope) async {
      final projectId = await scope.projects.create(name: name);
      await scope.canvas.create(projectId: projectId, name: firstCanvasName);
    });
    _ref.invalidate(workspaceProjectsProvider);
  }
}
```

(Remove the now-unused `ink_error.dart` import.)

- [ ] **Step 4: Run the test, watch it pass**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/features/studio/controllers/studio_projects_controller_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/studio/controllers/studio_projects_controller.dart test/features/studio/controllers/studio_projects_controller_test.dart
git commit -m "refactor(studio): createProject project+canvas in one transaction (drop manual compensation)"
```

---

### Task 5: `CanvasNodesController.removeNode` → atomic node + cascade edges

**Files:**
- Modify: `lib/features/canvas/providers/canvas_nodes_controller.dart`
- Modify: `test/features/canvas/canvas_nodes_controller_test.dart`

**Interfaces:**
- Consumes: `unitOfWorkProvider`, `FakeUnitOfWork`, `GatedFakeUnitOfWork`.
- Behavior: `removeNode` does optimistic memory removal, then `uow.run` soft-deletes all incoming+outgoing edges and the node atomically; on `InkError` it rolls back memory and rethrows; ME-27 dispose guard preserved.

- [ ] **Step 1: Rewrite `removeNode` and drop `_edgeRepoOrNull` / `_softDeleteConnectedEdges`**:

```dart
  /// 软删除节点 + 级联软删所有关联 edges（入/出）——单事务原子（PRD §4.3）。
  ///
  /// 乐观更新内存；事务内任一步失败 → 整体回滚 + 内存复原 + InkError 冒泡。
  /// 成功后让 CanvasEdgesController(canvasId) 失效，UI 重新加载新边集。
  Future<void> removeNode(String id) async {
    final canvasId = arg;
    final uow = await ref.read(unitOfWorkProvider.future);
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    final next = previous.where((n) => n.id != id).toList(growable: false);
    if (_alive) state = AsyncData(next);

    try {
      await uow.run((scope) async {
        final outgoing = await scope.edges.listOutgoing(id);
        final incoming = await scope.edges.listIncoming(id);
        final edgeIds = <String>{
          for (final r in outgoing) r['id']!.toString(),
          for (final r in incoming) r['id']!.toString(),
        };
        for (final eid in edgeIds) {
          await scope.edges.softDelete(eid);
        }
        await scope.nodes.softDelete(id);
      });
      if (_alive) ref.invalidate(canvasEdgesControllerProvider(canvasId));
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }
```

Remove `_edgeRepoOrNull` and `_softDeleteConnectedEdges`. Remove the now-unused `edge_repository.dart` import if no longer referenced (it is not). Keep `_repo`, `_alive`, `addNode`, `moveNode` unchanged.

- [ ] **Step 2: Update the tests** in `test/features/canvas/canvas_nodes_controller_test.dart`:
  - Add import `import '../../_harness/fake_unit_of_work.dart';`.
  - In `setUp`, add to the container overrides a `unitOfWorkProvider.overrideWith(...)` wiring the same `repo` + a fresh `_FakeEdgeRepo`. Since `setUp`'s container is reused by several tests, store the edge repo on a top-level `late _FakeEdgeRepo edgeRepo;` and build the scope from `repo` + `edgeRepo`.
  - Replace the cascade test's bespoke container with the shared one (it now always has a uow).
  - Replace the "无 EdgeRepository 依然成功" test: rename to "无关联 edges → 只软删节点" — seed no edges, expect `repo.softDeleted contains id` and `edgeRepo.softDeleted` empty.
  - The dispose test ("removeNode await 期间 provider dispose") now gates the **uow** via `GatedFakeUnitOfWork`; expect `LocalIOError` still bubbles. Concretely, make the gated uow's scope use a node repo whose `softDelete` throws after the gate opens, OR have the gate complete then the closure throw. Simplest: build scope with a node repo whose `softDeleteError` is set; gate the uow; dispose mid-await; complete gate; `expectLater(..., throwsA(isA<LocalIOError>()))`.

Concrete `setUp` and key tests:

```dart
  late _FakeNodeRepository repo;
  late _FakeEdgeRepo edgeRepo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeNodeRepository();
    edgeRepo = _FakeEdgeRepo();
    container = ProviderContainer(
      overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => repo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        unitOfWorkProvider.overrideWith(
          (ref) async => FakeUnitOfWork(
            FakeRepositoryScope(nodes: repo, edges: edgeRepo),
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());
```

Cascade test becomes (uses shared `container`/`edgeRepo`):

```dart
    test('removeNode 级联软删相邻 edges（入+出）— 单事务', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final c = await ctrl.addNode(label: 'C', type: CanvasNodeType.image);

      await edgeRepo.create(
          canvasId: canvasId, sourceNodeId: a.id, targetNodeId: b.id, edgeType: 'data');
      await edgeRepo.create(
          canvasId: canvasId, sourceNodeId: c.id, targetNodeId: b.id, edgeType: 'data');
      await edgeRepo.create(
          canvasId: canvasId, sourceNodeId: b.id, targetNodeId: a.id, edgeType: 'narrative');

      await ctrl.removeNode(b.id);

      expect(edgeRepo.softDeleted, hasLength(3));
      expect(repo.softDeleted, contains(b.id));
    });

    test('removeNode 无关联 edges → 只软删节点', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'X', type: CanvasNodeType.image);
      await ctrl.removeNode(n.id);
      expect(repo.softDeleted, contains(n.id));
      expect(edgeRepo.softDeleted, isEmpty);
    });
```

Dispose test:

```dart
    test('removeNode await 期间 provider dispose → 不抛 StateError（ME-27）',
        () async {
      final gate = Completer<void>();
      final gnode = _FakeNodeRepository()..softDeleteError = 'late failure';
      final gedge = _FakeEdgeRepo();
      final c = ProviderContainer(overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => gnode),
        edgeRepositoryProvider.overrideWith((ref) async => gedge),
        unitOfWorkProvider.overrideWith(
          (ref) async => GatedFakeUnitOfWork(
            FakeRepositoryScope(nodes: gnode, edges: gedge),
            gate.future,
          ),
        ),
      ]);

      await c.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = c.read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);

      final pending = ctrl.removeNode(n.id);
      c.dispose(); // await 挂起期间整个容器销毁
      gate.complete();

      await expectLater(pending, throwsA(isA<LocalIOError>()));
    });
```

(`addNode`/`moveNode` tests still pass `repo` only — they don't touch uow; they keep working because `unitOfWorkProvider` is overridden but unused by those paths.)

- [ ] **Step 3: Run the test file, watch fail then pass**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/features/canvas/canvas_nodes_controller_test.dart`
Expected: After controller rewrite → PASS (all tests in file).

- [ ] **Step 4: Commit**

```bash
git add lib/features/canvas/providers/canvas_nodes_controller.dart test/features/canvas/canvas_nodes_controller_test.dart
git commit -m "refactor(canvas): removeNode node+cascade-edges in one transaction"
```

---

### Task 6: `GenerationController.submitFromConfigNode` → transactional create + complete rollback

**Files:**
- Modify: `lib/features/generation/generation_controller.dart`
- Modify: `test/features/generation/generation_controller_test.dart`

**Interfaces:**
- Constructor gains `required UnitOfWork uow`. The provider passes `await ref.watch(unitOfWorkProvider.future)`.
- `submitFromConfigNode`: result-node creation + job-row creation run in one `uow.run`, returning `(String resultNodeId, String jobId)`. On post-commit submit/registry failure, compensation cleans **both** rows (job row was leaking before).

- [ ] **Step 1: Update the provider + constructor**. In `generationControllerProvider`, add `final uow = await ref.watch(unitOfWorkProvider.future);` and pass `uow: uow`. Add field `final UnitOfWork uow;` and `required this.uow,` to the constructor. Add import `import '../../core/interfaces/unit_of_work.dart';`.

- [ ] **Step 2: Rewrite the create+submit region** of `submitFromConfigNode` (replace the block from `// 预创建 result 节点` through the `catch` at end of method):

```dart
    // 预创建 result 节点 + 建 job 行——单事务原子（任一失败整体回滚，不留半行）。
    final (resultNodeId, jobId) = await uow.run((scope) async {
      final rNode = await scope.nodes.create(
        canvasId: canvasId,
        type: nodeType,
        nodeRole: 'result',
        sourceNodeId: configNodeId,
      );
      final jId = await scope.jobs.create(
        canvasId: canvasId,
        sourceNodeId: configNodeId,
        resultNodeId: rNode,
        providerId: providerId,
        jobType: nodeType,
        fullPrompt: fullPrompt,
        userPrompt: prompt,
        parameters: <String, Object?>{
          'resolution': resolution.name,
          'aspect_ratio': aspect.name,
          if (durationSeconds > 0) 'duration_seconds': durationSeconds,
          if (cameraEnum != null) 'camera': cameraEnum.name,
          if (refs.refImagePaths.isNotEmpty)
            'ref_image_paths': refs.refImagePaths,
          if (refs.firstFramePath != null)
            'first_frame_path': refs.firstFramePath,
          if (refs.lastFramePath != null)
            'last_frame_path': refs.lastFramePath,
        },
      );
      return (rNode, jId);
    });

    try {
      final task = GenerationTask(
        providerId: providerId,
        jobId: jobId,
        projectId: projectId,
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        mode: mode,
        prompt: fullPrompt,
        resolution: resolution,
        aspectRatio: aspect,
        durationSeconds: durationSeconds,
        camera: cameraEnum,
        refImagePaths: refs.refImagePaths,
        firstFramePath: refs.firstFramePath,
        lastFramePath: refs.lastFramePath,
      );

      final handle = await queue.submit(task);
      logger?.info(_logModule, 'job submitted', extra: {
        'job_id': jobId,
        'provider_id': providerId,
        'mode': mode.name,
      });
      jobsRegistry.upsert(
        JobState.queued(
          jobId: jobId,
          providerId: providerId,
          canvasId: canvasId,
        ),
      );
      unawaited(_track(
        handle,
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        providerId: providerId,
      ));
      return jobId;
    } catch (e, st) {
      // node+job 已提交，但 submit / registry 挂了——原子清掉两行，不留孤儿。
      logger?.error(
        _logModule,
        'submit rolled back: orphan result + job cleaned',
        extra: {
          'result_node_id': resultNodeId,
          'job_id': jobId,
          'provider_id': providerId,
        },
        cause: e,
        stackTrace: st,
      );
      try {
        await uow.run((scope) async {
          await scope.jobs.hardDelete(jobId);
          await scope.nodes.softDelete(resultNodeId);
        });
      } on InkError {
        // 补偿失败：保留原始错误语义，残留行交给孤儿回收/清理路径。
      }
      rethrow;
    }
```

Note: `jobs.create` here no longer passes the `maxRetries` named arg (the interface has none). The local var pattern `final (resultNodeId, jobId) = ...` requires Dart records (SDK ≥ 3.0; already used elsewhere via `({...})` in base_repository — records are available).

- [ ] **Step 3: Update the test** `test/features/generation/generation_controller_test.dart`:
  - Add import `import '../../_harness/fake_unit_of_work.dart';`.
  - In `buildCtrl()`, pass `uow: FakeUnitOfWork(FakeRepositoryScope(nodes: nodes, jobs: jobs))`.
  - The "jobs.create 抛错" test: `jobs.createThrows = true`. Now `jobs.create` throws *inside* `uow.run` (the FakeUnitOfWork just propagates). The node was already created in the fake (no rollback in fake) — but the controller's catch only runs for failures *after* the uow.run (submit stage). A throw *inside* uow.run propagates straight out of `submitFromConfigNode` (no result cleanup, because with a real tx the node create would roll back). So assertion `expect(nodes.softDeleted, hasLength(1))` is no longer valid — with transactional semantics the node is rolled back by the DB, not soft-deleted. Update: assert it throws (`throwsStateError`) and that **no** `queue.submit` happened (`queue.lastTask` is null). Drop the softDelete assertion (rollback is a pg-integration concern). Keep the logger test variant: the in-`uow` throw does NOT hit the controller's catch logger; instead it bubbles. So the "jobs.create 抛错回滚 → ERROR 日志" test must change — there is no longer a controller-level error log for an in-transaction failure (the transaction itself rolls back; logging an in-tx failure is not this method's job). Replace that test with: assert `throwsStateError` and `queue.lastTask` is null (submit never reached).
  - Add a NEW test for the completed compensation: make `queue.submit` throw, assert both `nodes.softDeleted` contains the result id AND `jobs` hardDelete was invoked. Requires `_FakeJobRepo` to record `hardDelete` and `_FakeJobQueue.submit` to optionally throw. Extend those fakes:
    - `_FakeJobRepo`: add `final List<String> hardDeleted = [];` and `hardDelete` records id, returns 1.
    - `_FakeJobQueue`: add `bool submitThrows = false;` and throw `StateError('submit boom')` when set.
  - New test:

```dart
  test('queue.submit 失败 → 清孤儿 result + job（补偿）后 rethrow', () async {
    final cfg = await seedConfigNode();
    await secure.store(SecureStorageKeys.providerApiKey(providerId), 'sk');
    queue.submitThrows = true;

    await expectLater(
      buildCtrl().submitFromConfigNode(cfg),
      throwsA(isA<StateError>()),
    );
    expect(nodes.softDeleted, contains(nodes.creates.first['id']));
    expect(jobs.hardDeleted, contains(jobs.creates.first['id']));
  });
```

- [ ] **Step 4: Run the test file, watch fail then pass**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/features/generation/generation_controller_test.dart`
Expected: PASS after controller + fakes updated. Also run the prompt + video test files to confirm they still pass (they build the controller too):
Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/features/generation/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/generation/generation_controller.dart test/features/generation/generation_controller_test.dart
git commit -m "refactor(generation): result-node + job creation in one transaction; compensation cleans both rows"
```

---

### Task 7: Real-PG transaction rollback integration test

**Files:**
- Create: `test/storage/transaction_integration_test.dart`

**Interfaces:**
- Consumes: `PgTestHarness` (`test/storage/schema/pg_test_harness.dart`), `PostgresUnitOfWork`, the postgres repos.

- [ ] **Step 1: Write the integration test** (tagged `pg`; skipped without `TEST_PG_URL`):

```dart
// 真 PG 事务回滚集成测：UnitOfWork.run 中途抛错 → 整体回滚，无残留行。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/storage/postgres_unit_of_work.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';

import 'schema/pg_test_harness.dart';

class _Skip implements Exception {}

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'tx');
  });
  tearDown(() async {
    await harness?.close();
  });

  PgTestHarness req() {
    final x = harness;
    if (x == null) {
      markTestSkipped('TEST_PG_URL 未设置，跳过真 PG 集成测试');
      throw _Skip();
    }
    return x;
  }

  test('闭包中途抛错 → 已写入的 project 行回滚（不残留）', () async {
    try {
      final h = req();
      final uow = PostgresUnitOfWork(h.conn);
      final projects = PostgresProjectRepository(h.conn);

      await expectLater(
        uow.run((scope) async {
          await scope.projects.create(name: 'Alpha');
          // 第二步用非法 FK 触发 ServerException → guard 翻成 LocalIOError → 回滚。
          await scope.canvas
              .create(projectId: 'not-a-real-uuid', name: 'X');
        }),
        throwsA(isA<LocalIOError>()),
      );

      // 回滚后 projects 表应为空。
      expect(await projects.listAll(), isEmpty);
    } on _Skip {
      return;
    }
  });

  test('闭包全部成功 → project + canvas 双双提交', () async {
    try {
      final h = req();
      final uow = PostgresUnitOfWork(h.conn);
      final projects = PostgresProjectRepository(h.conn);
      final canvases = PostgresCanvasRepository(h.conn);

      await uow.run((scope) async {
        final pid = await scope.projects.create(name: 'Alpha');
        await scope.canvas.create(projectId: pid, name: 'C1');
      });

      final all = await projects.listAll();
      expect(all, hasLength(1));
      final cs = await canvases.listByProject(all.single['id']!.toString());
      expect(cs, hasLength(1));
    } on _Skip {
      return;
    }
  });
}
```

- [ ] **Step 2: Analyze + run (skips without TEST_PG_URL)**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/storage/transaction_integration_test.dart`
Expected: PASS or skipped (no `TEST_PG_URL` locally). On CI with PG → real assertions run.

- [ ] **Step 3: Commit**

```bash
git add test/storage/transaction_integration_test.dart
git commit -m "test(storage): real-PG UnitOfWork rollback + commit integration tests"
```

---

### Task 8: Full verification + branch finish

- [ ] **Step 1: gen-l10n (no ARB change expected, parity sanity)**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat gen-l10n`
Expected: success, no diff.

- [ ] **Step 2: Analyze whole project**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat analyze`
Expected: No issues.

- [ ] **Step 3: Full test suite (exclude pg-tagged on machines without PG)**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test --exclude-tags pg`
Expected: All pass.

- [ ] **Step 4: requesting-code-review skill, then finishing-a-development-branch → push + PR**

## Self-Review

- **Spec coverage:** P0#1's three sites — createProject (Task 4), removeNode (Task 5), result-node+job create (Task 6) — each wrapped in `runTx` via `UnitOfWork`. ✅ Abstraction (`UnitOfWork`/`RepositoryScope`) Tasks 1–3. Real rollback proof Task 7. The job-row leak on submit failure (review §logic) fixed in Task 6.
- **Placeholder scan:** none — every step carries full code.
- **Type consistency:** `RepositoryScope` getters (`nodes/edges/canvas/projects/jobs`) match across interface, Postgres impl, and fakes. `UnitOfWork.run<T>` signature identical everywhere. `unitOfWorkProvider` is `FutureProvider<UnitOfWork>`, read via `.future` consistently. `(String, String)` record destructuring in Task 6 matches `(rNode, jId)` return.
- **Out of scope (follow-up branches, noted in review report):** P0#2 repository typing, P0#3 `SyncProviderBase`, all P1/P2 items.
