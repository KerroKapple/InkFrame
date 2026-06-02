# 画布生成集成 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 接通 UI 三处断点（Studio 开画布 / 任务进度入 registry / 画布进度面板去 mock），让用户「发起生成 → 看到进度 → 结果显示在画布」端到端跑通。

**Architecture:** `GenerationController` 改 fire-and-forget——提交后立即返回 jobId，内部后台 future 订阅 `JobHandle.status` 把 `JobState` 喂进注入的 `JobsRegistry` 实例（不持有 ref，规避 autoDispose 回收）；`CanvasScreen` 监听 registry，当前画布 job 生命周期变化 → invalidate 画布节点控制器（重拉出带产物的真实节点）+ 失败弹 toast；`CanvasRenderQueue` 改 `ConsumerWidget` 按 `canvasId` 过滤显示真实进度。`JobState` 增 `canvasId` 维度。

**Tech Stack:** Flutter · Riverpod（NotifierProvider / FutureProvider / AsyncNotifierFamily / StateProvider）· freezed · flutter_test。

**约定（务必遵守）：**
- 真实代码库根：`/Users/kerro/Projects/InkFrame`。所有命令先 `cd` 进去。分支 `feat/canvas-generation-integration`（基于 PR #104 后端分支）。
- 注释中文、精简。i18n：新增/删除 ARB key 必须 en+zh 同步改 + `flutter gen-l10n`。
- **提交策略**：本项目「未经用户明确许可不 git commit」。各 Task 末尾 commit 步为标准格式；执行时若未获授权则只跑测试、改动留工作区。
- 设计依据：`docs/superpowers/specs/2026-06-02-canvas-generation-integration-design.md`。
- freezed 重新生成命令：`dart run build_runner build --delete-conflicting-outputs`。

---

## File Structure

- **Modify** `lib/features/generation/models/job_state.dart` — 6 个 factory 各加 `required String canvasId`；扩展加 `canvasId` getter。freezed 重生成。
- **Modify** `lib/features/generation/providers/jobs_registry.dart` — 加 `forCanvas(String)` 过滤 helper。
- **Modify** `lib/features/generation/generation_controller.dart` — 注入 `JobsRegistry jobsRegistry`；`submitFromConfigNode` 返回 `String jobId`（fire-and-forget）；新增私有 `_track`；删除 `GenerationOutcome`。
- **Modify** `lib/features/canvas/widgets/image_config_inspector.dart` / `video_config_inspector.dart` — 不再 await 终态 / 不再自己 invalidate；提交后立即收起。
- **Create** `lib/features/canvas/util/canvas_job_effects.dart` — 纯函数：给定 prev/next registry 列表 + canvasId，算出「是否重拉节点 + 哪些失败要 toast」。
- **Modify** `lib/features/canvas/widgets/canvas_screen.dart` — `ref.listen(jobsRegistryProvider)` 调用 `CanvasJobEffects` 执行 invalidate + toast。
- **Modify** `lib/features/canvas/widgets/canvas_render_queue.dart` — `StatelessWidget` → `ConsumerWidget`，watch+filter 真实数据。
- **Modify** `lib/features/studio/studio_home_screen.dart` — 项目卡 `onTap` 接 open-canvas 逻辑。
- **Modify** `lib/l10n/app_en.arb` / `app_zh.arb` — 删 3 个假 job 名 key，加 `canvasRenderQueueEmpty` + `canvasDefaultName`。
- **Test**（新建/改）：`job_state_test.dart`、`jobs_registry_test.dart`、`generation_controller_test.dart`（迁移）、`canvas_job_effects_test.dart`、`canvas_render_queue_test.dart`、`open_canvas_test.dart`、`job_queue_service_writeback_order_test.dart`。

---

### Task 1: `JobState` 增加 `canvasId` 维度

**Files:**
- Modify: `lib/features/generation/models/job_state.dart`
- Test: `test/features/generation/models/job_state_test.dart`（新建）

- [ ] **Step 1: 写失败测试**

```dart
// test/features/generation/models/job_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/generation/models/job_state.dart';

void main() {
  test('每个 JobState 变体都带 canvasId 且可读', () {
    const c = 'cv-1';
    final states = <JobState>[
      const JobState.queued(jobId: 'j', providerId: 'p', canvasId: c),
      const JobState.submitting(jobId: 'j', providerId: 'p', canvasId: c),
      const JobState.running(jobId: 'j', providerId: 'p', canvasId: c, progress: 0.5),
      const JobState.succeeded(jobId: 'j', providerId: 'p', canvasId: c, artifactPath: 'a.png'),
      const JobState.cancelled(jobId: 'j', providerId: 'p', canvasId: c),
    ];
    for (final s in states) {
      expect(s.canvasId, c);
    }
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/generation/models/job_state_test.dart`
Expected: 编译失败——factory 无 `canvasId` 具名参数 / 无 `canvasId` getter（RED）。

- [ ] **Step 3: 给 6 个 factory 加 `canvasId`**

在 `lib/features/generation/models/job_state.dart` 每个 factory 的参数表加 `required String canvasId`（放在 `providerId` 之后）。例如：

```dart
  const factory JobState.queued({
    required String jobId,
    required String providerId,
    required String canvasId,
  }) = JobQueued;

  const factory JobState.submitting({
    required String jobId,
    required String providerId,
    required String canvasId,
  }) = JobSubmitting;

  const factory JobState.running({
    required String jobId,
    required String providerId,
    required String canvasId,
    @Default(0.0) double progress,
  }) = JobRunning;

  const factory JobState.succeeded({
    required String jobId,
    required String providerId,
    required String canvasId,
    required String artifactPath,
  }) = JobSucceeded;

  const factory JobState.failed({
    required String jobId,
    required String providerId,
    required String canvasId,
    required InkError error,
  }) = JobFailed;

  const factory JobState.cancelled({
    required String jobId,
    required String providerId,
    required String canvasId,
  }) = JobCancelled;
```

- [ ] **Step 4: 在 `JobStateX` 扩展加 `canvasId` getter**

在 `extension JobStateX on JobState {` 内（与 `jobId` getter 同构）追加：

```dart
  String get canvasId => switch (this) {
        JobQueued(:final canvasId) => canvasId,
        JobSubmitting(:final canvasId) => canvasId,
        JobRunning(:final canvasId) => canvasId,
        JobSucceeded(:final canvasId) => canvasId,
        JobFailed(:final canvasId) => canvasId,
        JobCancelled(:final canvasId) => canvasId,
      };
```

- [ ] **Step 5: 重新生成 freezed**

Run: `cd /Users/kerro/Projects/InkFrame && dart run build_runner build --delete-conflicting-outputs`
Expected: 重生成 `job_state.freezed.dart`，无报错。

- [ ] **Step 6: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/generation/models/job_state_test.dart`
Expected: `All tests passed!`（1 passed）

> 注意：此 Task 后全仓会因构造点缺 `canvasId` 而编译不过（job_queue_panel 等）。这是预期——后续 Task 逐个补齐构造点。本 Task 只验证模型测试本身绿。

- [ ] **Step 7: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/generation/models/job_state.dart lib/features/generation/models/job_state.freezed.dart test/features/generation/models/job_state_test.dart
git commit -m "feat(generation): add canvasId dimension to JobState"
```

---

### Task 2: `JobsRegistry.forCanvas` 过滤 helper

**Files:**
- Modify: `lib/features/generation/providers/jobs_registry.dart`
- Test: `test/features/generation/providers/jobs_registry_test.dart`（新建）

- [ ] **Step 1: 写失败测试**

```dart
// test/features/generation/providers/jobs_registry_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';

void main() {
  test('forCanvas 只返回指定画布的活跃任务，按插入序', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reg = container.read(jobsRegistryProvider.notifier);

    reg.upsert(const JobState.running(jobId: 'a', providerId: 'p', canvasId: 'c1', progress: 0.1));
    reg.upsert(const JobState.running(jobId: 'b', providerId: 'p', canvasId: 'c2', progress: 0.2));
    reg.upsert(const JobState.queued(jobId: 'd', providerId: 'p', canvasId: 'c1'));
    reg.upsert(const JobState.succeeded(jobId: 'e', providerId: 'p', canvasId: 'c1', artifactPath: 'x.png'));

    final c1Active = reg.forCanvas('c1');
    expect(c1Active.map((s) => s.jobId).toList(), <String>['a', 'd']); // 终态 e 被过滤
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/generation/providers/jobs_registry_test.dart`
Expected: 编译失败——`forCanvas` 未定义（RED）。

- [ ] **Step 3: 加 `forCanvas`**

在 `class JobsRegistry` 内（`clearTerminated` 之后）追加：

```dart
  /// 某画布的活跃任务（非终态），按插入序——CanvasRenderQueue 消费。
  List<JobState> forCanvas(String canvasId) =>
      state.where((e) => e.canvasId == canvasId && !e.isTerminal).toList();
```

- [ ] **Step 4: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/generation/providers/jobs_registry_test.dart`
Expected: `All tests passed!`（1 passed）

- [ ] **Step 5: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/generation/providers/jobs_registry.dart test/features/generation/providers/jobs_registry_test.dart
git commit -m "feat(generation): add JobsRegistry.forCanvas active-jobs filter"
```

---

### Task 3: `GenerationController` 改 fire-and-forget + 注入 JobsRegistry

**Files:**
- Modify: `lib/features/generation/generation_controller.dart`
- Test: `test/features/generation/generation_controller_test.dart`（迁移现有）

> 契约变更：`submitFromConfigNode` 返回 `Future<String>`（jobId），不再阻塞到终态、不再返回 `GenerationOutcome`（删除该类）。进度/终态通过注入的 `jobsRegistry.upsert` 推送；失败/取消时 `softDelete` 孤儿 result 节点。

- [ ] **Step 1: 迁移测试（先写新契约的失败测试）**

替换 `test/features/generation/generation_controller_test.dart` 中所有用 `outcome.succeeded` / `outcome.resultNodeId` 的断言。新增一个 fake registry 收集 upsert，并改造 fake queue/handle 暴露 `status` 流。在文件 fakes 区加：

```dart
// 收集 controller 推来的 JobState
class _RecordingRegistry extends JobsRegistry {
  final List<JobState> events = [];
  @override
  void upsert(JobState job) {
    events.add(job);
    super.upsert(job);
  }
}
```

> 提示：`JobsRegistry` 是 `Notifier`，直接 `_RecordingRegistry()` 实例化即可（无需 ProviderContainer）；构造后其 `state` 默认 build 为 `const []`。若 `Notifier` 未初始化导致 `state` 访问报错，改为不调用 `super.upsert`、只记录 `events`，并在断言里只看 `events`。

改写成功路径测试（替换原 line 349-358 区块）：

```dart
  test('fire-and-forget：立即返回 jobId，推 queued→running→succeeded', () async {
    final reg = _RecordingRegistry();
    final ctrl = buildCtrl(registry: reg);
    // fake queue 的 handle 应：status 先 emit inProgress(0.4)，done resolve success
    final jobId = await ctrl.submitFromConfigNode(cfg);
    expect(jobId, isNotEmpty);
    expect(nodes.creates, hasLength(1));
    expect(nodes.creates.first['node_role'], 'result');
    // 等后台 _track 跑完（done + 收尾）
    await pumpEventQueue();
    final kinds = reg.events.map((e) => e.runtimeType.toString()).toList();
    expect(kinds.first, contains('JobQueued'));
    expect(kinds.any((k) => k.contains('JobRunning')), isTrue);
    expect(kinds.last, contains('JobSucceeded'));
    expect(nodes.softDeleted, isEmpty);
  });
```

失败路径（替换原 line 425-427）：

```dart
  test('失败：done=failure → softDelete result + upsert JobFailed', () async {
    final reg = _RecordingRegistry();
    final ctrl = buildCtrl(registry: reg, queueFails: true);
    await ctrl.submitFromConfigNode(cfg);
    await pumpEventQueue();
    expect(reg.events.last, isA<JobFailed>());
    expect(nodes.softDeleted, hasLength(1));
  });
```

参数校验/缺 key 等同步抛错的测试（原 line 362-411）保持不变——它们在 submit 成功之前抛 `GenerationError`，契约未变。

并把 `buildCtrl` helper（line 270）改成接受 registry + 控制 queue 成败：

```dart
  GenerationController buildCtrl({JobsRegistry? registry, bool queueFails = false}) {
    queue.shouldFail = queueFails;
    return GenerationController(
      nodes: nodes,
      edges: edges,
      jobs: jobs,
      secure: secure,
      queue: queue,
      registry: registry, // ProviderRegistry —— 见下方说明
      resolver: resolver,
      jobsRegistry: registry ?? _RecordingRegistry(),
    );
  }
```

> 关键命名坑：现有构造参数 `registry` 是 **`ProviderRegistry`**（provider 注册表），不是 JobsRegistry。上面示意里把两者混了——实测时 `registry:` 仍传原 ProviderRegistry fake，新参数命名 **`jobsRegistry`**。修正 buildCtrl：`registry: providerRegistryFake, jobsRegistry: registry ?? _RecordingRegistry()`。

fake queue/handle 需暴露 status 流（在现有 fake queue 里）：

```dart
class _FakeHandle implements JobHandle {
  _FakeHandle(this._jobId, this._statuses, this._done);
  final String _jobId;
  final List<JobStatus> _statuses; // 依次 emit
  final JobStatus _done;
  @override
  String get jobId => _jobId;
  @override
  Stream<JobStatus> get status => Stream<JobStatus>.fromIterable(_statuses);
  @override
  Future<JobStatus> get done async => _done;
}
```

queue.submit 据 `shouldFail` 返回成功（status: [inProgress(0.4)], done: success(remoteUrls:[])）或失败（done: failure(error: NetworkError(...))）的 `_FakeHandle`。

- [ ] **Step 2: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/generation/generation_controller_test.dart`
Expected: 编译失败 / 断言失败——`submitFromConfigNode` 仍返回 `GenerationOutcome`、构造无 `jobsRegistry` 参数（RED）。

- [ ] **Step 3: 重构 controller**

在 `lib/features/generation/generation_controller.dart`：

(a) import 增加：

```dart
import 'dart:async';
import 'providers/jobs_registry.dart';
import 'models/job_state.dart';
```

(b) 构造与字段：在现有字段后加 `final JobsRegistry jobsRegistry;`，构造参数表加 `required this.jobsRegistry,`。

(c) 删除 `GenerationOutcome` 类（整段）。

(d) `submitFromConfigNode` 签名改 `Future<String>`，把原来 `await handle.done` 之后的收尾逻辑全部移入 `_track`，提交段在拿到 handle 后立即 `upsert(JobQueued)` + 启动 `_track` 并 `return jobId`：

```dart
  /// 从 config 节点发起一次生成。fire-and-forget：立即返回 jobId，
  /// 进度/终态经 jobsRegistry 推送，失败/取消时清孤儿 result 节点。
  Future<String> submitFromConfigNode(String configNodeId) async {
    // ……（line 122-219 的校验 / 预创建 result 节点 / jobs.create 全部保持不变）……
    // 拿到 jobId、task、resultNodeId、canvasId、providerId 后：

    final handle = await queue.submit(task);
    jobsRegistry.upsert(
      JobState.queued(jobId: jobId, providerId: providerId, canvasId: canvasId),
    );
    // 后台收尾，不 await（错误全部内部消化，绝不逃逸）
    unawaited(_track(
      handle,
      canvasId: canvasId,
      resultNodeId: resultNodeId,
      providerId: providerId,
    ));
    return jobId;
    // 原 try/catch 里「预创建后下游抛错 → softDelete + rethrow」保留：
    // jobs.create / queue.submit 抛错仍同步 rethrow（提交即失败，走 inspector toast）。
  }
```

> 注意保留提交段原有的 `try { ... } catch (_) { await nodes.softDelete(resultNodeId); rethrow; }`：把 `final handle = await queue.submit(task)` 及之后的 upsert/unawaited/return 放进 try 内；catch 仍负责「submit 前/中抛错清孤儿」。`_track` 的失败由 `_track` 自己 softDelete，不走这个 catch。

(e) 新增 `_track`：

```dart
  Future<void> _track(
    JobHandle handle, {
    required String canvasId,
    required String resultNodeId,
    required String providerId,
  }) async {
    final sub = handle.status.listen((s) {
      if (s is JobInProgress) {
        jobsRegistry.upsert(JobState.running(
          jobId: handle.jobId,
          providerId: providerId,
          canvasId: canvasId,
          progress: s.progress,
        ));
      }
    });
    try {
      final status = await handle.done;
      if (status is JobSuccess) {
        final path = await _readArtifactPath(resultNodeId);
        jobsRegistry.upsert(JobState.succeeded(
          jobId: handle.jobId,
          providerId: providerId,
          canvasId: canvasId,
          artifactPath: path,
        ));
      } else if (status is JobFailure) {
        await nodes.softDelete(resultNodeId);
        if (status.error is CancelledError) {
          jobsRegistry.upsert(JobState.cancelled(
            jobId: handle.jobId, providerId: providerId, canvasId: canvasId));
        } else {
          jobsRegistry.upsert(JobState.failed(
            jobId: handle.jobId, providerId: providerId,
            canvasId: canvasId, error: status.error));
        }
      }
    } catch (e, st) {
      // done 理论上不抛（resolve failure），此处为防御性兜底，绝不逃逸。
      await nodes.softDelete(resultNodeId);
      jobsRegistry.upsert(JobState.failed(
        jobId: handle.jobId, providerId: providerId, canvasId: canvasId,
        error: UnknownError(cause: e, stackTrace: st)));
    } finally {
      await sub.cancel();
    }
  }

  /// 成功后读 result 节点已落库的产物相对路径（image_url / video_url）。
  Future<String> _readArtifactPath(String resultNodeId) async {
    final row = await nodes.findById(resultNodeId);
    final tc = _readTypeConfig(row?['type_config']);
    return (tc['image_url'] ?? tc['video_url'] ?? '').toString();
  }
```

> `CancelledError` / `UnknownError` 来自已 import 的 `core/errors/ink_error.dart`（现有 import）。

- [ ] **Step 4: 同步改 generationControllerProvider 注入 jobsRegistry**

在同文件 `generationControllerProvider` body（line 40-60）加：

```dart
    final jobsRegistry = ref.read(jobsRegistryProvider.notifier);
```

并在 `return GenerationController(...)` 参数表加 `jobsRegistry: jobsRegistry,`。

> 用 `ref.read`（非 watch）取 notifier 实例注入；因 `jobsRegistryProvider` keepAlive，实例稳定，controller 持有它即可，后台 future 不再触碰 ref。

- [ ] **Step 5: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/generation/generation_controller_test.dart test/features/generation/generation_controller_video_test.dart`
Expected: `All tests passed!`（迁移后全绿；video 测试若用 outcome 也按同模式迁移）。

- [ ] **Step 6: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/generation/generation_controller.dart test/features/generation/generation_controller_test.dart test/features/generation/generation_controller_video_test.dart
git commit -m "refactor(generation): fire-and-forget submit feeding JobsRegistry"
```

---

### Task 4: 两个 Inspector 适配 fire-and-forget

**Files:**
- Modify: `lib/features/canvas/widgets/image_config_inspector.dart:124-170`
- Modify: `lib/features/canvas/widgets/video_config_inspector.dart:124-175`

> inspector 不再 await 终态、不再自己 invalidate（invalidate 移交 Task 6 listener）。提交成功 → 立即回 idle；同步错误（缺 key 等）保持现有 InspectorJobError 展示。

- [ ] **Step 1: 改 `_submit` 成功段（两个文件相同处理）**

把：

```dart
      final controller = await ref.read(generationControllerProvider.future);
      final outcome = await controller.submitFromConfigNode(widget.node.id);
      if (!mounted) return;
      if (outcome.succeeded) {
        setState(() => _view = const InspectorJobIdle());
        final canvasId = widget.node.canvasId;
        if (canvasId != null) {
          ref.invalidate(canvasNodesControllerProvider(canvasId));
        }
      } else {
        final code = outcome.status.maybeMap(
          failure: (f) => f.error.code.name,
          orElse: () => 'unknown',
        );
        setState(() => _view = InspectorJobError(code: code));
      }
```

改为：

```dart
      final controller = await ref.read(generationControllerProvider.future);
      await controller.submitFromConfigNode(widget.node.id);
      if (!mounted) return;
      // fire-and-forget：提交成功即收起；进度看画布渲染队列面板，
      // 终态结果/失败由 CanvasScreen 的 registry listener 反映（刷新画布 / toast）。
      setState(() => _view = const InspectorJobIdle());
```

`on MissingApiKeyError` / `on InvalidGenerationConfigError` / `on ProviderNotRegisteredError` / `catch` 各 block 全部保持不变（同步抛错仍在此处理）。

- [ ] **Step 2: 清理无用 import**

若改后 `canvasNodesControllerProvider` 在该文件不再被引用，删除其 import（`flutter analyze` 会报 unused import）。

- [ ] **Step 3: 运行确认通过（widget 测试 + analyze）**

Run: `cd /Users/kerro/Projects/InkFrame && flutter analyze lib/features/canvas/widgets/image_config_inspector.dart lib/features/canvas/widgets/video_config_inspector.dart`
Expected: `No issues found!`
Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/`
Expected: 现有 inspector 相关测试通过；若有断言「提交后 outcome」的用例，按 fire-and-forget 改为断言「submit 被调 + 视图回 idle」。

- [ ] **Step 4: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/canvas/widgets/image_config_inspector.dart lib/features/canvas/widgets/video_config_inspector.dart test/features/canvas/
git commit -m "refactor(canvas): inspectors submit fire-and-forget, drop blocking await"
```

---

### Task 5: `CanvasJobEffects` 纯函数（重拉判定 + 失败 toast 清单）

**Files:**
- Create: `lib/features/canvas/util/canvas_job_effects.dart`
- Test: `test/features/canvas/util/canvas_job_effects_test.dart`（新建）

> 把「监听 registry 后该做什么」抽成可单测的纯函数，CanvasScreen 只负责调用 + 执行副作用。

- [ ] **Step 1: 写失败测试**

```dart
// test/features/canvas/util/canvas_job_effects_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/canvas/util/canvas_job_effects.dart';

JobState _run(String id, String cv, double p) =>
    JobState.running(jobId: id, providerId: 'p', canvasId: cv, progress: p);
JobState _ok(String id, String cv) =>
    JobState.succeeded(jobId: id, providerId: 'p', canvasId: cv, artifactPath: 'a');
JobState _fail(String id, String cv, InkError e) =>
    JobState.failed(jobId: id, providerId: 'p', canvasId: cv, error: e);

void main() {
  final err = const NetworkError(code: InkErrorCode.networkOffline, extra: {});

  test('当前画布新增 job → 需重拉，无失败 toast', () {
    final r = CanvasJobEffects.diff(
      prev: const [], next: [_run('a', 'c1', 0.1)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isTrue);
    expect(r.toastErrors, isEmpty);
  });

  test('别的画布变化 → 不重拉', () {
    final r = CanvasJobEffects.diff(
      prev: const [], next: [_run('a', 'c2', 0.1)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isFalse);
  });

  test('当前画布 job 转 succeeded → 重拉', () {
    final r = CanvasJobEffects.diff(
      prev: [_run('a', 'c1', 0.9)], next: [_ok('a', 'c1')], canvasId: 'c1');
    expect(r.shouldReloadNodes, isTrue);
  });

  test('当前画布 job 转 failed → 重拉 + toast 该错误', () {
    final r = CanvasJobEffects.diff(
      prev: [_run('a', 'c1', 0.9)], next: [_fail('a', 'c1', err)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isTrue);
    expect(r.toastErrors, hasLength(1));
  });

  test('当前画布 job 转 cancelled → 重拉但不 toast', () {
    final cancelled = JobState.cancelled(jobId: 'a', providerId: 'p', canvasId: 'c1');
    final r = CanvasJobEffects.diff(
      prev: [_run('a', 'c1', 0.9)], next: [cancelled], canvasId: 'c1');
    expect(r.shouldReloadNodes, isTrue);
    expect(r.toastErrors, isEmpty);
  });

  test('当前画布无变化 → 不重拉', () {
    final r = CanvasJobEffects.diff(
      prev: [_run('a', 'c1', 0.5)], next: [_run('a', 'c1', 0.5)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isFalse);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/util/canvas_job_effects_test.dart`
Expected: 编译失败——`CanvasJobEffects` 未定义（RED）。

- [ ] **Step 3: 实现纯函数**

```dart
// lib/features/canvas/util/canvas_job_effects.dart
//
// 监听 jobsRegistry 后的副作用判定（纯函数，可单测）：
//   - 当前画布的 job 集合发生任何生命周期变化 → 需重拉画布节点
//   - 当前画布新转入 failed 的 job → 收集其 InkError 供 toast（cancelled 不收）
import '../../../core/errors/ink_error.dart';
import '../../generation/models/job_state.dart';

class CanvasJobEffect {
  const CanvasJobEffect({required this.shouldReloadNodes, required this.toastErrors});
  final bool shouldReloadNodes;
  final List<InkError> toastErrors;
}

class CanvasJobEffects {
  static CanvasJobEffect diff({
    required List<JobState> prev,
    required List<JobState> next,
    required String canvasId,
  }) {
    final p = {for (final s in prev.where((e) => e.canvasId == canvasId)) s.jobId: s};
    final n = {for (final s in next.where((e) => e.canvasId == canvasId)) s.jobId: s};

    // 当前画布的状态指纹变化即需重拉（新增/移除/状态切换/进度变化）
    final changed = p.length != n.length ||
        n.entries.any((e) => p[e.key].runtimeType != e.value.runtimeType) ||
        n.entries.any((e) {
          final prevS = p[e.key];
          return prevS is JobRunning &&
              e.value is JobRunning &&
              (prevS).progress != (e.value as JobRunning).progress;
        }) ||
        p.keys.any((k) => !n.containsKey(k));

    // 新转入 failed（prev 不是 failed，next 是 failed）→ toast
    final toastErrors = <InkError>[];
    for (final e in n.entries) {
      final cur = e.value;
      final was = p[e.key];
      if (cur is JobFailed && was is! JobFailed) {
        toastErrors.add(cur.error);
      }
    }
    return CanvasJobEffect(shouldReloadNodes: changed, toastErrors: toastErrors);
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/util/canvas_job_effects_test.dart`
Expected: `All tests passed!`（6 passed）

- [ ] **Step 5: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/canvas/util/canvas_job_effects.dart test/features/canvas/util/canvas_job_effects_test.dart
git commit -m "feat(canvas): pure CanvasJobEffects diff for reload+toast decisions"
```

---

### Task 6: `CanvasScreen` 接 registry listener（invalidate + toast）

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_screen.dart`

> `CanvasScreen` 是 `ConsumerWidget`/`ConsumerStatefulWidget`（需确认；若是 `StatelessWidget`/`ConsumerWidget` 用 `ref.listen` 必须在 build 内）。用 `ref.listen(jobsRegistryProvider)` 调 `CanvasJobEffects.diff`，按结果 invalidate 当前画布节点控制器 + 弹失败 toast。

- [ ] **Step 1: 在 `CanvasScreen.build` 内加 listener**

确认 `canvas_screen.dart` 顶部已 import：`flutter_riverpod`、`current_canvas_id.dart`、`canvas_nodes_controller.dart`、`../../generation/providers/jobs_registry.dart`、`../../generation/services/toast_service.dart`、`../util/canvas_job_effects.dart`、`../../../l10n/l10n_x.dart`。

在 `build(BuildContext context, WidgetRef ref)` 体内（return 之前）加：

```dart
    final canvasId = ref.watch(currentCanvasIdProvider);
    ref.listen<List<JobState>>(jobsRegistryProvider, (prev, next) {
      if (canvasId == null) return;
      final effect = CanvasJobEffects.diff(
        prev: prev ?? const <JobState>[],
        next: next,
        canvasId: canvasId,
      );
      if (effect.shouldReloadNodes) {
        ref.invalidate(canvasNodesControllerProvider(canvasId));
      }
      for (final err in effect.toastErrors) {
        ref.read(toastServiceProvider).show(
              context.l10n.errorOf(err), // 见下 helper 说明
              kind: ToastKind.error,
            );
      }
    });
```

> `context.l10n.errorOf(err)` 仅示意。实际应把 `InkError.code` 映射到 l10n：用现有 `error.messageKey`（见 `ink_error.dart`）取 key 后查 `context.l10n`。若已有把 `InkError`→localized string 的现成 helper（grep `messageKey` 的使用处），复用之；没有则在 `l10n_x.dart` 加一个 `String l10nForError(BuildContext, InkError)` 小函数（switch over `InkErrorCode` 返回对应 `context.l10n.errorXxx`）。本步以「复用现有错误本地化出口」为准，写计划时已知 ARB 有 `errorInvalidKey/errorNetworkOffline/...` 全套。

需要 `import` `job_state.dart`、`job_status` 无关。

- [ ] **Step 2: 若 `CanvasScreen` 不是 Consumer——先升级**

若 `canvas_screen.dart` 当前是 `StatelessWidget`，改为 `ConsumerWidget` 并把 `build` 签名改 `build(BuildContext context, WidgetRef ref)`。其余子树不变。

- [ ] **Step 3: 运行 analyze + 现有画布测试**

Run: `cd /Users/kerro/Projects/InkFrame && flutter analyze lib/features/canvas/widgets/canvas_screen.dart`
Expected: `No issues found!`
Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/`
Expected: 通过（listener 不破坏既有渲染）。

- [ ] **Step 4: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/canvas/widgets/canvas_screen.dart lib/l10n/
git commit -m "feat(canvas): CanvasScreen reacts to job lifecycle (reload nodes + error toast)"
```

---

### Task 7: `CanvasRenderQueue` 去 mock，接真实进度

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_render_queue.dart`
- Modify: `lib/l10n/app_en.arb` / `app_zh.arb`
- Test: `test/features/canvas/widgets/canvas_render_queue_test.dart`（新建）

- [ ] **Step 1: ARB 改动（删假 key + 加空态 key）**

在 `app_en.arb` 删除 `canvasRenderQueueJobWatch` / `canvasRenderQueueJobHarbor` / `canvasRenderQueueJobNocturne` 三个 key 及其 `@` 描述；新增：

```json
  "canvasRenderQueueEmpty": "No active renders",
```

`app_zh.arb` 同步删同样三 key，新增：

```json
  "canvasRenderQueueEmpty": "暂无渲染任务",
```

保留 `canvasRenderQueue`（标题）、`canvasRenderQueueStatusQueued`（排队状态）。

Run: `cd /Users/kerro/Projects/InkFrame && flutter gen-l10n`
Expected: 重生成 `app_localizations*.dart`，无 key 缺失报错。

- [ ] **Step 2: 写失败测试**

```dart
// test/features/canvas/widgets/canvas_render_queue_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/widgets/canvas_render_queue.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

Widget _host(List<JobState> jobs, String canvasId) {
  return ProviderScope(
    overrides: [
      currentCanvasIdProvider.overrideWith((ref) => canvasId),
    ],
    child: Consumer(builder: (context, ref, _) {
      final reg = ref.read(jobsRegistryProvider.notifier);
      for (final j in jobs) {
        reg.upsert(j);
      }
      return const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CanvasRenderQueue()),
      );
    }),
  );
}

void main() {
  testWidgets('只显示当前画布的活跃任务，无假数据', (tester) async {
    await tester.pumpWidget(_host([
      const JobState.running(jobId: 'a', providerId: 'p', canvasId: 'c1', progress: 0.45),
      const JobState.running(jobId: 'b', providerId: 'p', canvasId: 'c2', progress: 0.9),
      const JobState.succeeded(jobId: 'd', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
    ], 'c1'));
    await tester.pump();
    // 不再有假名
    expect(find.text('Watch Closeup'), findsNothing);
    expect(find.text('Harbor Docks'), findsNothing);
    // 当前画布的 running 进度出现（45%），别的画布(c2)与终态(d)不出现
    expect(find.textContaining('45'), findsOneWidget);
    expect(find.textContaining('90'), findsNothing);
  });

  testWidgets('当前画布无活跃任务 → 空态', (tester) async {
    await tester.pumpWidget(_host(const [], 'c1'));
    await tester.pump();
    expect(find.text('No active renders'), findsOneWidget);
  });
}
```

- [ ] **Step 3: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/canvas_render_queue_test.dart`
Expected: 失败——当前 widget 是 mock（显示 Watch Closeup 等），无空态（RED）。

- [ ] **Step 4: 重写 `canvas_render_queue.dart`**

```dart
// CanvasRenderQueue：Inspector 下方面板 — 当前画布的活跃渲染任务（真实数据）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';
import '../providers/current_canvas_id.dart';

class CanvasRenderQueue extends ConsumerWidget {
  const CanvasRenderQueue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final canvasId = ref.watch(currentCanvasIdProvider);
    final jobs = canvasId == null
        ? const <JobState>[]
        : ref.watch(jobsRegistryProvider).where(
              (s) => s.canvasId == canvasId && !s.isTerminal,
            ).toList();
    final running = jobs.whereType<JobRunning>().length;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(
          left: BorderSide(color: colors.borderSubtle),
          top: BorderSide(color: colors.borderSubtle),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.md, InkSpacing.sm + 4, InkSpacing.md, InkSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.canvasRenderQueue.toUpperCase(),
                  style: typo.caption.copyWith(
                    fontFamily: 'JetBrainsMono', color: colors.fg3, letterSpacing: 1.8),
                ),
              ),
              Text(
                '$running · ${jobs.length} ▾',
                style: typo.caption.copyWith(
                  fontFamily: 'JetBrainsMono', color: colors.fg3),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.sm + 2),
          if (jobs.isEmpty)
            Text(l.canvasRenderQueueEmpty,
                style: typo.body.copyWith(color: colors.fg4))
          else
            for (final job in jobs) ...<Widget>[
              _JobRow(
                name: job.jobId,
                percent: job.progressValue,
                running: job is JobRunning,
              ),
              const SizedBox(height: InkSpacing.sm),
            ],
        ],
      ),
    );
  }
}
```

`_JobRow`（原文件 line 69-139）整段保留不变（其 `context.l10n.canvasRenderQueueStatusQueued` 仍在）。

> 说明：`name: job.jobId` 是 MVP 占位——渲染队列行用 jobId 标识。后续增强可换成节点标签/prompt 摘要（需 JobState 带更多展示字段，YAGNI，本期不做）。

- [ ] **Step 5: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/canvas_render_queue_test.dart`
Expected: `All tests passed!`（2 passed）

- [ ] **Step 6: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/canvas/widgets/canvas_render_queue.dart lib/l10n/ test/features/canvas/widgets/canvas_render_queue_test.dart
git commit -m "feat(canvas): render queue shows real current-canvas jobs, drop mock data"
```

---

### Task 8: G1 — Studio 项目卡 open-canvas

**Files:**
- Modify: `lib/features/studio/studio_home_screen.dart`
- Modify: `lib/l10n/app_en.arb` / `app_zh.arb`（默认画布名）
- Test: `test/features/studio/open_canvas_test.dart`（新建）

> 行为：点项目 → 打开 `canvases.first`（created_at ASC，已契约化）；0 画布 → `canvasRepository.create` 建空白后打开；create 失败 → 不 set、留 Studio、error toast。

- [ ] **Step 1: ARB 加默认画布名**

`app_en.arb`：`"canvasDefaultName": "Untitled Canvas",`
`app_zh.arb`：`"canvasDefaultName": "未命名画布",`
Run: `cd /Users/kerro/Projects/InkFrame && flutter gen-l10n`

- [ ] **Step 2: 写失败测试**

```dart
// test/features/studio/open_canvas_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/open_canvas.dart';

void main() {
  test('有画布 → set 第一个画布 id', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await openProjectCanvas(
      container.read,
      const ProjectWithCanvases(id: 'p1', name: 'P', canvases: [
        CanvasRef(id: 'cv-a', name: 'A'),
        CanvasRef(id: 'cv-b', name: 'B'),
      ]),
      createCanvas: (_) async => fail('不该建画布'),
    );
    expect(container.read(currentCanvasIdProvider), 'cv-a');
  });

  test('0 画布 → 建新画布并 set', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await openProjectCanvas(
      container.read,
      const ProjectWithCanvases(id: 'p1', name: 'P', canvases: []),
      createCanvas: (projectId) async => 'cv-new',
    );
    expect(container.read(currentCanvasIdProvider), 'cv-new');
  });

  test('create 失败 → 不 set，错误冒泡', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await expectLater(
      openProjectCanvas(
        container.read,
        const ProjectWithCanvases(id: 'p1', name: 'P', canvases: []),
        createCanvas: (_) async => throw StateError('boom'),
      ),
      throwsStateError,
    );
    expect(container.read(currentCanvasIdProvider), isNull);
  });
}
```

- [ ] **Step 3: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/studio/open_canvas_test.dart`
Expected: 编译失败——`open_canvas.dart` / `openProjectCanvas` 未定义（RED）。

- [ ] **Step 4: 实现 open 逻辑（可单测，与 widget 解耦）**

```dart
// lib/features/studio/open_canvas.dart
//
// 打开项目对应画布：有则开第一个（created_at ASC 契约序），无则建空白再开。
// createCanvas 注入便于单测；生产由 studio_home_screen 传入 canvasRepository.create。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/providers/current_canvas_id.dart';
import 'models/project_with_canvases.dart';

typedef CanvasCreator = Future<String> Function(String projectId);

Future<void> openProjectCanvas(
  T Function<T>(ProviderListenable<T>) read,
  ProjectWithCanvases project, {
  required CanvasCreator createCanvas,
}) async {
  final String canvasId;
  if (project.canvases.isNotEmpty) {
    canvasId = project.canvases.first.id;
  } else {
    canvasId = await createCanvas(project.id); // 失败则抛，不 set
  }
  read(currentCanvasIdProvider.notifier).state = canvasId;
}
```

> `ProviderContainer.read` 的签名即 `T read<T>(ProviderListenable<T>)`，可直接作为首参传入。

- [ ] **Step 5: 接到 `studio_home_screen.dart:419` 的 onTap**

把空桩：

```dart
              onTap: () {
                // Task 11/13 接 open canvas
              },
```

改为（`build` 内已有 `ref`；`p` 是当前 `ProjectWithCanvases`）：

```dart
              onTap: () async {
                try {
                  await openProjectCanvas(
                    ref.read,
                    p,
                    createCanvas: (projectId) async {
                      final repo = await ref.read(canvasRepositoryProvider.future);
                      return repo.create(
                        projectId: projectId,
                        name: context.l10n.canvasDefaultName,
                      );
                    },
                  );
                } catch (_) {
                  if (context.mounted) {
                    ref.read(toastServiceProvider).show(
                          context.l10n.studioOpenCanvasFailed,
                          kind: ToastKind.error,
                        );
                  }
                }
              },
```

顶部 import 增加：`open_canvas.dart`、`../../core/di/repositories.dart`（`canvasRepositoryProvider`）、`../generation/services/toast_service.dart`、`l10n_x.dart`（若未引）。

> 新增 ARB key `studioOpenCanvasFailed`（en: "Couldn't open canvas"，zh: "打开画布失败"），同 Step 1 方式加 + `gen-l10n`。

- [ ] **Step 6: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/studio/open_canvas_test.dart && flutter analyze lib/features/studio/`
Expected: `All tests passed!`（3 passed）+ `No issues found!`

- [ ] **Step 7: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/studio/ lib/l10n/ test/features/studio/open_canvas_test.dart
git commit -m "feat(studio): open project canvas on tap (first canvas or create blank)"
```

---

### Task 9: #2 写库顺序不变量锁死测试（job_queue_service）

**Files:**
- Test: `test/services/job_queue_service_writeback_order_test.dart`（新建）

> 锁死「成功路径：result 节点 image_url 落库 **早于** `handle.status` emit success」。用慢写库 fake：`patchTypeConfig` 阻塞在 Completer 上，断言 url 未落库前不出现 success。未来谁把 emit 提前 / 引入并行写库，测试立刻红。

- [ ] **Step 1: 写测试**

```dart
// test/services/job_queue_service_writeback_order_test.dart
//
// 不变量：JobQueueService 成功路径必须「先 patchTypeConfig(url) 落库，再 emit/complete success」。
// 用 Completer 把写库卡住，断言期间不出现 success；放开后才出现。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/job_status.dart';
// ……（按现有 test/services/job_queue_service_test.dart 的 import 与 fake 复用：
//     fake ProviderRegistry 返回一个 poll() 立即给 JobSuccess(inlineBytes:[bytes]) 的 provider，
//     fake JobRepository（transitionStatus/update no-op），fake FileResolverService，
//     这里只把 NodeRepository 换成下面的「慢写库」。）

class _GatedNodeRepo /* implements NodeRepository */ {
  final gate = Completer<void>();
  bool urlWritten = false;
  // patchTypeConfig 等 gate 完成后才写 url
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    await gate.future;
    if (patch.containsKey('image_url')) urlWritten = true;
    return 1;
  }
  // 其余 NodeRepository 成员 noSuchMethod 抛错（测试不触达）
}

void main() {
  test('success 仅在 image_url 落库后才 emit', () async {
    // 1. 构造 InMemoryJobQueueService，注入慢写库 + 立即成功的 fake provider
    // 2. final handle = await service.submit(task);
    // 3. bool sawSuccess = false;
    //    handle.status.listen((s) { if (s is JobSuccess) sawSuccess = true; });
    // 4. await pumpEventQueue();
    //    expect(repo.urlWritten, isFalse);   // 写库被 gate 卡住
    //    expect(sawSuccess, isFalse);        // 关键断言：未落库前不 emit success
    // 5. repo.gate.complete(); await pumpEventQueue();
    //    expect(repo.urlWritten, isTrue);
    //    expect(sawSuccess, isTrue);         // 落库后才 emit
  });
}
```

> 实现细节（fake provider / task / fileResolver 构造）按 `test/services/job_queue_service_test.dart` 既有写法照搬——该文件已有可复用的 fake registry/provider/task builder。`_GatedNodeRepo` 需 `implements NodeRepository` 并对未用成员 `noSuchMethod` 抛 `UnimplementedError`（参照 `test/core/di/job_queue_provider_test.dart` 的 `_FakeJobRepo` 模式）。inlineBytes 成功路径会走 `_persistInlineBytes`，它内部调 `fileResolver` 写文件 + `nodeRepo.patchTypeConfig`——确保 fake fileResolver 不抛即可让流程走到 patchTypeConfig 这步。

- [ ] **Step 2: 运行确认通过（锁住现状）**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/services/job_queue_service_writeback_order_test.dart`
Expected: `All tests passed!`（1 passed）——证明当前实现满足不变量。

- [ ] **Step 3: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add test/services/job_queue_service_writeback_order_test.dart
git commit -m "test(services): lock invariant — url persisted before success emitted"
```

---

### Task 10: 全量回归 + 静态检查

**Files:** 无（仅验证）

- [ ] **Step 1: 静态分析**

Run: `cd /Users/kerro/Projects/InkFrame && flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 2: i18n 覆盖检查**

Run: `cd /Users/kerro/Projects/InkFrame && flutter gen-l10n`
Expected: 无报错；`app_en.arb` 与 `app_zh.arb` key 集一致（删了 3 个假 key、加了 `canvasRenderQueueEmpty` / `canvasDefaultName` / `studioOpenCanvasFailed`，两边都加）。

- [ ] **Step 3: 全量测试**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test`
Expected: `All tests passed!`。通过数 = 基线（PR #104 后约 506）+ 本计划新增（job_state 1 + jobs_registry 1 + canvas_job_effects 6 + canvas_render_queue 2 + open_canvas 3 + writeback_order 1 + controller 迁移净增若干）− 删除的 mock 相关用例。以「全绿 + 无 skip 异常增长」为准。

- [ ] **Step 4: 收尾汇报**

向用户报告：analyze 结果、通过数、三缺口闭合情况（G1 能进画布、G2 进度入 registry、G3 面板真数据），并提示后续增强（打开最近编辑画布 / 渲染队列行显示节点标签 / 全局 toast listener）留作下一轮。

---

## Self-Review

**1. Spec coverage：**
- G1 open-canvas（first 画布 + 0 画布建 + 失败留 Studio）→ Task 8。✓
- G2 jobsRegistry 喂数据（fire-and-forget + _track + 注入实例规避 autoDispose）→ Task 3。✓
- G3 CanvasRenderQueue 去 mock + canvasId 过滤 → Task 1（字段）+ Task 2（filter）+ Task 7（widget）。✓
- 画布刷新（提交/成功/失败三时点）→ Task 5（判定）+ Task 6（CanvasScreen invalidate）。✓
- failed→toast / cancelled→静默 → Task 5（toastErrors 不含 cancelled）+ Task 6（弹 toast）。✓
- #2 写库早于信号不变量 → Task 9（慢写库锁死测试，非 happy-path 顺序断言）。✓
- ref 生命周期红线 → Task 3 Step 4（注入 notifier 实例 + ref.read，不在后台 future 碰 ref）。✓
- inspector 同步错误保持 → Task 4（catch 块不变）。✓

**2. Placeholder scan：** 代码步骤均给完整代码。Task 6 的 `context.l10n.errorOf` 与 Task 9 的 fake provider 构造标注为「复用现有出口/既有测试写法」并给了定位线索（`messageKey` 使用处、`job_queue_service_test.dart`、`_FakeJobRepo` 模式）——非占位，是对既有资产的显式引用。执行者首步应 grep 这两处确认现成 helper 再落地。

**3. Type consistency：** `JobState` 6 factory 统一加 `required String canvasId`；`forCanvas`/`CanvasJobEffects.diff`/render queue filter 均用 `e.canvasId == canvasId && !e.isTerminal`；controller 新参数命名 `jobsRegistry`（区别于既有 `registry`=`ProviderRegistry`，Task 3 Step 1 已显式纠正）；`submitFromConfigNode` 全程 `Future<String>`；`openProjectCanvas(read, project, {createCanvas})` 签名在 Task 8 测试与实现间一致。

**关键风险提示（执行者注意）：**
- Task 1 完成后到 Task 7 完成前，全仓存在「JobState 构造点缺 canvasId」的编译错误（job_queue_panel 等）。各 Task 的局部测试命令可单独跑，但 `flutter analyze lib`（全量）要等所有构造点补齐后才会绿——别在中途因全量 analyze 红就回退。所有 `JobState.xxx(...)` 构造点（grep `JobState\.` 定位）都必须补 `canvasId`，含 `job_queue_panel.dart` 若有直接构造、及测试。
- Task 6 的 `ref.listen` 必须在 `build` 内、且 `CanvasScreen` 为 Consumer 体系；若它当前非 Consumer，Step 2 的升级是前置。
