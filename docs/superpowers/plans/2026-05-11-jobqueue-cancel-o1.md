# JobQueueService O(1) Cancel Implementation Plan

> **Status: EXECUTED (2026-05-14)** — Landed via PR #79 series on origin/main:
> - `b4424f7` refactor: add pendingIndex map alongside Queue
> - `41afffb` fix: O(1) cancel via pendingIndex + soft-delete
> - `1d388f1` test: perf invariant — cancel N=10000 < 500ms
> - `3de2167` test: cancel diagnostic benchmark (baseline / red number)
> - `b70f0be` docs: data structure note for _pending + _pendingIndex
>
> Kept as historical record of the design + rollout.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `InMemoryJobQueueService.cancel(jobId)` 对 pending 队列的复杂度从 3 × O(n) 降到 O(1)，保持 FIFO 与对外契约不变，新增基准测试 + 回归测试守住性能不变量。

**Architecture:** Option A —— 在 `Queue<_PendingJob>` 旁加一份 `Map<String, _PendingJob>` 索引；cancel 通过 map 直接定位 `_PendingJob`，把它标记成 `cancelled` 并从 map 删除，**不再从 queue 重建**。dispatch loop（`_schedule` / `_pickNextSchedulable`）跳过 cancelled 的条目，自然清理。FIFO 顺序保持（queue 顺序未变），retry 语义不变。

**Tech Stack:** Dart `dart:collection.Queue`, `flutter_test`, `Stopwatch`。

**Issue:** [#79 — refactor: JobQueueService cancellation rebuilds the queue (O(n))](https://github.com/KerroKapple/InkFrame/issues/79)

---

## File Structure

- **Modify** `lib/services/job_queue_service.dart`
  - 新增字段 `Map<String, _PendingJob> _pendingIndex`
  - `_PendingJob` 加 `bool cancelled = false`
  - `submit()` 同步写 map
  - `cancel()` pending 分支改成 map 查找 + 标记 + map 删除（不动 queue）
  - `_schedule()` / `_pickNextSchedulable()` 跳过 cancelled 的条目并顺手出队
  - `dispose()` 清 map
  - Submit 重复检测改用 map（`_pendingIndex.containsKey`）
- **Modify** `test/services/job_queue_service_test.dart`
  - 新增 `group('InMemoryJobQueueService.cancel perf')`：N=10000 cancel head/tail/random < 50ms 各 1 个
- **New** `test/services/job_queue_service_cancel_bench_test.dart`（可选 benchmark；CI 跑、产数字；用 `Stopwatch` + 不带 `expect` 断言上限，仅 `print`，永不挂 CI）
  - 决策：把 benchmark 当 **diagnostic test**，跑出 before/after 数字贴 PR；不进 CI 失败矩阵，避免 flake

---

## Task 1: Baseline Benchmark — 拿到 red number

**Files:**
- Create: `test/services/job_queue_service_cancel_bench_test.dart`

- [ ] **Step 1: 写 benchmark 测试（diagnostic only，不卡 CI）**

```dart
// 性能诊断：测 cancel(jobId) 在不同 pending depth 下的耗时。
//
// 不做 expect 断言（避免环境抖动挂 CI），只 print 表格。
// 真正的性能护栏在 job_queue_service_test.dart 的 perf group 里，
// 那里只断 N=10000 < 50ms 这一条粗线。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/provider_registry.dart';
import 'package:inkframe/services/job_queue_service.dart';

// 复用现有 job_queue_service_test.dart 里的 _FakeProvider 模式
class _NoopProvider implements Submittable {
  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    providerId: 'bench-noop',
    region: ProviderRegion.global,
    modes: [GenerationMode.textToImage],
    supportedRatios: [],
    supportedResolutions: [],
    supportedDurations: [],
    supportedCameras: [],
    maxBatchSize: 1,
    maxRefImages: 0,
    refImagesIncludeKeyframes: false,
    supportsFirstFrame: false,
    supportsLastFrame: false,
    supportsNegativePrompt: false,
    supportsSeed: false,
    supportsSound: false,
    supportsBatch: false,
    supportsCancellation: false,
    supportsPolling: true,
    costModel: CostModel.flatPerImage(usdPerImage: 0),
    maxConcurrentJobs: 0, // 0 = 永远不调度，让任务全部堆在 pending
    qps: 1,
    burst: 1,
  );

  @override
  Future<JobId> submit(GenerationTask task) async => task.jobId;
}

GenerationTask _task(int i) => GenerationTask(
  jobId: 'bench-$i',
  projectId: 'p',
  canvasId: 'c',
  configNodeId: 'cfg',
  resultNodeId: 'r-$i',
  providerId: 'bench-noop',
  prompt: 'noop',
  mode: GenerationMode.textToImage,
  createdAt: DateTime(2026),
);

Future<int> _benchCancel(int n, String pattern) async {
  final svc = InMemoryJobQueueService(
    registry: ProviderRegistry({'bench-noop': () => _NoopProvider()}),
  );
  final ids = <String>[];
  for (var i = 0; i < n; i++) {
    await svc.submit(_task(i));
    ids.add('bench-$i');
  }
  final order = switch (pattern) {
    'head' => ids,
    'tail' => ids.reversed.toList(),
    'random' => (ids.toList()..shuffle()),
    _ => ids,
  };
  final sw = Stopwatch()..start();
  for (final id in order) {
    await svc.cancel(id);
  }
  sw.stop();
  svc.dispose();
  return sw.elapsedMicroseconds;
}

void main() {
  test('JobQueueService cancel — diagnostic bench (no assertions)', () async {
    final sizes = [10, 100, 1000, 10000];
    final patterns = ['head', 'tail', 'random'];
    // ignore: avoid_print
    print('| N | pattern | total μs | per-cancel μs |');
    // ignore: avoid_print
    print('|---|---------|---------|---------------|');
    for (final n in sizes) {
      for (final p in patterns) {
        final total = await _benchCancel(n, p);
        // ignore: avoid_print
        print('| $n | $p | $total | ${total / n} |');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

- [ ] **Step 2: 跑 benchmark 记录 baseline 数字**

Run:
```
flutter test test/services/job_queue_service_cancel_bench_test.dart -r expanded
```

Expected: 测试通过，输出表格。把 N=10000 的三个数（head/tail/random）记到 commit message 和 PR description 里。预期 per-cancel 应该呈 ~线性增长（10000 / 1000 ≈ 10×）。

- [ ] **Step 3: Commit benchmark + baseline numbers**

```bash
git add test/services/job_queue_service_cancel_bench_test.dart
git commit -m "test(jobqueue): cancel diagnostic benchmark (baseline / red number)

Per-cancel μs at N=10/100/1000/10000 × head/tail/random.
Baseline shows O(n) shape — see PR description for table."
```

---

## Task 2: 引入 pending index map（field + submit 路径）

**Files:**
- Modify: `lib/services/job_queue_service.dart:67-104`

- [ ] **Step 1: 加 index 字段 + cancelled flag**

在 `_pending` 字段下加一行 map；`_PendingJob` 加 `cancelled`：

```dart
// lib/services/job_queue_service.dart ~67
final Queue<_PendingJob> _pending = Queue<_PendingJob>();
// 与 _pending 一一对应的索引；jobId → 同一个 _PendingJob 引用。
// cancel(jobId) 用它做 O(1) 定位 + 移除，避免把 queue 拆成 List 重建。
final Map<String, _PendingJob> _pendingIndex = <String, _PendingJob>{};
```

```dart
// lib/services/job_queue_service.dart ~568
class _PendingJob {
  _PendingJob({required this.task, required this.handle});
  final GenerationTask task;
  final _Handle handle;
  // 被 cancel 后由 dispatch loop 跳过并丢弃。pending 队列只追加不重建。
  bool cancelled = false;
}
```

- [ ] **Step 2: submit 同步维护 map + 用 map 做重复检测**

把 `submit` 里的重复检测和入队改成：

```dart
// 原代码 lib/services/job_queue_service.dart ~95-105
if (_pending.any((p) => p.task.jobId == task.jobId) ||
    _running.containsKey(task.jobId)) {
  throw StateError('jobId ${task.jobId} already submitted');
}
// ... StreamController / Handle 构造保持原样 ...
_pending.add(_PendingJob(task: task, handle: handle));
_schedule();
return handle;
```

改为：

```dart
if (_pendingIndex.containsKey(task.jobId) ||
    _running.containsKey(task.jobId)) {
  throw StateError('jobId ${task.jobId} already submitted');
}
// ignore: close_sinks  // 终态由 _Handle._complete 关闭
final controller = StreamController<JobStatus>.broadcast();
final doneCompleter = Completer<JobStatus>();
final handle = _Handle(task.jobId, controller, doneCompleter);

final pendingJob = _PendingJob(task: task, handle: handle);
_pending.add(pendingJob);
_pendingIndex[task.jobId] = pendingJob;
_schedule();
return handle;
```

- [ ] **Step 3: 跑全套 job_queue 单测，确认未破坏**

Run:
```
flutter test test/services/job_queue_service_test.dart
```

Expected: 全绿。如果 perf group 还没加，原有所有用例不变。

- [ ] **Step 4: Commit**

```bash
git add lib/services/job_queue_service.dart
git commit -m "refactor(jobqueue): add pendingIndex map alongside Queue

Submit path maintains _pendingIndex in lock-step with _pending.
Duplicate-jobId check now O(1) via map.containsKey.
No behavior change yet — cancel/schedule still use _pending."
```

---

## Task 3: cancel 改走 map（核心 O(1) 改造）

**Files:**
- Modify: `lib/services/job_queue_service.dart:110-134`

- [ ] **Step 1: 把 cancel 的 pending 分支改成 map 标记**

把 `cancel(jobId)` 的 pending 分支替换：

```dart
// 原代码 lib/services/job_queue_service.dart ~110-121
Future<void> cancel(String jobId) async {
  final pendingIdx = _pending.toList().indexWhere((p) => p.task.jobId == jobId);
  if (pendingIdx >= 0) {
    final list = _pending.toList();
    final removed = list.removeAt(pendingIdx);
    _pending
      ..clear()
      ..addAll(list);
    await _persistCancel(jobId, fromStatuses: const ['pending']);
    _emitFailure(removed.handle, _cancelledError(jobId));
    return;
  }
  // ... running 分支保持原样 ...
}
```

改为：

```dart
Future<void> cancel(String jobId) async {
  final pending = _pendingIndex.remove(jobId);
  if (pending != null) {
    // 软删除：标记后 dispatch loop 自然跳过并出队，避免重建 Queue。
    pending.cancelled = true;
    await _persistCancel(jobId, fromStatuses: const ['pending']);
    _emitFailure(pending.handle, _cancelledError(jobId));
    return;
  }
  // ... running 分支保持原样 ...
}
```

- [ ] **Step 2: dispatch loop 跳过 cancelled**

把 `_schedule()` 和 `_pickNextSchedulable()` 改成跳过 cancelled，并顺手把 cancelled 的从队头出队：

```dart
// 原代码 lib/services/job_queue_service.dart ~151-170
void _schedule() {
  if (_disposed) return;
  while (_pending.isNotEmpty &&
      _running.length < _globalConcurrency) {
    final next = _pickNextSchedulable();
    if (next == null) return;
    _pending.remove(next);
    _occupy(next.task.providerId);
    _runJob(next.task, next.handle);
  }
}

_PendingJob? _pickNextSchedulable() {
  for (final p in _pending) {
    final cap = _perProviderCap(p.task.providerId);
    final used = _perProviderSlots[p.task.providerId] ?? 0;
    if (used < cap) return p;
  }
  return null;
}
```

改为：

```dart
void _schedule() {
  if (_disposed) return;
  // 把队头的 cancelled 条目顺手清掉；摊还 O(1)。
  while (_pending.isNotEmpty && _pending.first.cancelled) {
    _pending.removeFirst();
  }
  while (_pending.isNotEmpty &&
      _running.length < _globalConcurrency) {
    final next = _pickNextSchedulable();
    if (next == null) return;
    _pending.remove(next); // Queue.remove 是 O(n)，但 next 通常在队头附近
    _occupy(next.task.providerId);
    _runJob(next.task, next.handle);
  }
}

_PendingJob? _pickNextSchedulable() {
  for (final p in _pending) {
    if (p.cancelled) continue;
    final cap = _perProviderCap(p.task.providerId);
    final used = _perProviderSlots[p.task.providerId] ?? 0;
    if (used < cap) return p;
  }
  return null;
}
```

> **决策说明**：`_schedule` 里的 `_pending.remove(next)` 仍是 O(n)，但这条路径只在"真正调度"时跑，频率 = 全局并发 1-4，跟 cancel 风暴量级差几个数量级。本 issue 抓手在 cancel，不在 schedule。后续优化可以把 `_pending` 换成双向链表 + node 引用一并消掉。

- [ ] **Step 3: dispose 清 index**

```dart
// 原代码 ~137-147
void dispose() {
  if (_disposed) return;
  _disposed = true;
  for (final p in _pending) {
    _emitFailure(p.handle, _cancelledError(p.task.jobId));
  }
  _pending.clear();
  for (final entry in _running.entries) {
    entry.value.cancelled = true;
  }
}
```

改为：

```dart
void dispose() {
  if (_disposed) return;
  _disposed = true;
  for (final p in _pending) {
    if (p.cancelled) continue; // 已 cancel 的事件已发过
    _emitFailure(p.handle, _cancelledError(p.task.jobId));
  }
  _pending.clear();
  _pendingIndex.clear();
  for (final entry in _running.entries) {
    entry.value.cancelled = true;
  }
}
```

- [ ] **Step 4: 跑全套 job_queue 单测**

Run:
```
flutter test test/services/job_queue_service_test.dart
```

Expected: 全绿。重点关注：
- `pending 任务 cancel → JobStatus.failure(cancelledByUser)` 必须过（核心契约）
- `cancel 不存在的 jobId → no-op idempotent` 必须过
- `cancel pending → transitionStatus pending→cancelled` 必须过

如果挂了，先看是 _runJob 内部对 `_pending` 的某处遍历没跳 cancelled，按 step 2 的模式补一处 `continue`。

- [ ] **Step 5: 重跑 benchmark，拿 green number**

Run:
```
flutter test test/services/job_queue_service_cancel_bench_test.dart -r expanded
```

Expected: per-cancel μs 在 N=10000 处掉到接近 N=10 的水平（O(1)），不再呈线性增长。记数字到 commit message。

- [ ] **Step 6: Commit**

```bash
git add lib/services/job_queue_service.dart
git commit -m "fix(jobqueue): O(1) cancel via pendingIndex + soft-delete

cancel(jobId) 走 _pendingIndex 直接定位 _PendingJob，标记 cancelled
后由 dispatch loop 出队，不再 toList + indexWhere + clear + addAll。
FIFO 顺序保持（queue 顺序未变），retry/状态机契约不变。

Benchmark per-cancel μs @ N=10000 (before → after):
- head:   <填实测>
- tail:   <填实测>
- random: <填实测>

Closes #79."
```

---

## Task 4: 回归测试 — 守住性能不变量

**Files:**
- Modify: `test/services/job_queue_service_test.dart`（末尾追加 group）

- [ ] **Step 1: 加性能护栏测试**

在 `test/services/job_queue_service_test.dart` 最后一个 `group` 之后追加：

```dart
  group('InMemoryJobQueueService.cancel perf invariant', () {
    // 真正的护栏：N=10000 个 pending 全部 cancel 必须在 50ms 内。
    // 上限松到 50ms 是为了让 CI 在低配 runner 上不抖；O(1) 实现下
    // 实测应在个位数 ms。

    test('cancel head N=10000 < 50ms', () async {
      final svc = _buildBenchSvc();
      final ids = await _seedPending(svc, 10000);
      final sw = Stopwatch()..start();
      for (final id in ids) {
        await svc.cancel(id);
      }
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(50),
        reason: 'cancel head 退化回 O(n) — 检查 _pendingIndex 是否还在用',
      );
      svc.dispose();
    });

    test('cancel tail N=10000 < 50ms', () async {
      final svc = _buildBenchSvc();
      final ids = await _seedPending(svc, 10000);
      final sw = Stopwatch()..start();
      for (final id in ids.reversed) {
        await svc.cancel(id);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50));
      svc.dispose();
    });

    test('cancel random N=10000 < 50ms', () async {
      final svc = _buildBenchSvc();
      final ids = await _seedPending(svc, 10000);
      final shuffled = ids.toList()..shuffle();
      final sw = Stopwatch()..start();
      for (final id in shuffled) {
        await svc.cancel(id);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50));
      svc.dispose();
    });
  });
}

InMemoryJobQueueService _buildBenchSvc() {
  return InMemoryJobQueueService(
    registry: ProviderRegistry({
      // maxConcurrentJobs:0 → 永远不调度，任务全部堆在 pending
      'bench-noop': () => _BenchNoopProvider(),
    }),
  );
}

Future<List<String>> _seedPending(
  InMemoryJobQueueService svc,
  int n,
) async {
  final ids = <String>[];
  for (var i = 0; i < n; i++) {
    final id = 'bench-$i';
    await svc.submit(GenerationTask(
      jobId: id,
      projectId: 'p',
      canvasId: 'c',
      configNodeId: 'cfg',
      resultNodeId: 'r-$i',
      providerId: 'bench-noop',
      prompt: 'noop',
      mode: GenerationMode.textToImage,
      createdAt: DateTime(2026),
    ));
    ids.add(id);
  }
  return ids;
}

class _BenchNoopProvider implements Submittable {
  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    providerId: 'bench-noop',
    region: ProviderRegion.global,
    modes: [GenerationMode.textToImage],
    supportedRatios: [],
    supportedResolutions: [],
    supportedDurations: [],
    supportedCameras: [],
    maxBatchSize: 1,
    maxRefImages: 0,
    refImagesIncludeKeyframes: false,
    supportsFirstFrame: false,
    supportsLastFrame: false,
    supportsNegativePrompt: false,
    supportsSeed: false,
    supportsSound: false,
    supportsBatch: false,
    supportsCancellation: false,
    supportsPolling: true,
    costModel: CostModel.flatPerImage(usdPerImage: 0),
    maxConcurrentJobs: 0,
    qps: 1,
    burst: 1,
  );

  @override
  Future<JobId> submit(GenerationTask task) async => task.jobId;
}
```

注意：把 `_buildBenchSvc` / `_seedPending` / `_BenchNoopProvider` 放在文件 main() 大括号外面（顶层函数 + class）。如果 main() 已经在文件末尾闭合，按上面位置放即可。

- [ ] **Step 2: 跑新测试**

Run:
```
flutter test test/services/job_queue_service_test.dart -n "cancel perf invariant"
```

Expected: 3/3 通过，每个 elapsed < 50ms。如果挂，看实际 ms 数：>50 而 <500 说明仍有线性成分（检查是不是有遗漏的 `_pending.any` / `_pending.toList`）；>500 直接退化回 O(n)。

- [ ] **Step 3: 跑完整 job_queue suite**

Run:
```
flutter test test/services/job_queue_service_test.dart
```

Expected: 全绿（旧用例 + 新 perf group）。

- [ ] **Step 4: Commit**

```bash
git add test/services/job_queue_service_test.dart
git commit -m "test(jobqueue): perf invariant — cancel N=10000 < 50ms

回归护栏：head/tail/random 三种 pattern 各一条，捕获未来的退化。
50ms 上限对 O(1) 实现宽松到 CI flake-free，对 O(n) 退化敏感。"
```

---

## Task 5: 文档 + 收尾

**Files:**
- Modify: `lib/services/job_queue_service.dart`（class-level 注释）

- [ ] **Step 1: 在 InMemoryJobQueueService 顶部加一段数据结构说明**

把 class 顶部注释（行 1-8 块）后追加：

```dart
// 数据结构：
//   _pending      = Queue<_PendingJob>，保持 FIFO；只追加 / 队头出队
//   _pendingIndex = Map<jobId, _PendingJob>，cancel 用 O(1) 定位
//   cancel pending = pendingIndex.remove + 标记 cancelled；queue 不重建
//   dispatch loop  = 跳过 cancelled 条目并顺手出队（摊还 O(1)）
//   FIFO / retry / status 机 契约外部不变。
```

加在 `class InMemoryJobQueueService implements JobQueueService {` 这一行的紧上方。

- [ ] **Step 2: 跑 analyze + 完整测试 sanity**

Run:
```
flutter analyze lib/services/job_queue_service.dart test/services/job_queue_service_test.dart test/services/job_queue_service_cancel_bench_test.dart
```

Expected: `No issues found!`

Run:
```
flutter test test/services/
```

Expected: 全绿。

- [ ] **Step 3: Commit**

```bash
git add lib/services/job_queue_service.dart
git commit -m "docs(jobqueue): data structure note for _pending + _pendingIndex"
```

---

## Task 6: PR

- [ ] **Step 1: Push 分支**

```bash
git push -u origin perf/jobqueue-cancel-79
```

- [ ] **Step 2: 开 PR**

```bash
gh pr create --base main --head perf/jobqueue-cancel-79 \
  --title "perf(jobqueue): O(1) cancel via pendingIndex (#79)" \
  --body "<from template below>"
```

PR body 模板（填入实测数字）：

```markdown
Closes #79

## Background
`InMemoryJobQueueService.cancel(jobId)` pending 分支跑 `toList + indexWhere + clear + addAll`，3 次 O(n)。PRD §10.7 未限 pending 上限，最坏情况批量 cancel 退化 O(n²)。

## Approach (Option A)
- 在 `_pending: Queue` 旁加 `_pendingIndex: Map<jobId, _PendingJob>`
- cancel → `pendingIndex.remove(id)` + 标记 `_PendingJob.cancelled = true`
- dispatch loop 跳过 cancelled 并顺手从队头出队（摊还 O(1)）
- FIFO 顺序保持（Queue 顺序从未被打乱）；retry / status 机契约不变

## Benchmark (per-cancel μs)

| N     | pattern | before (μs) | after (μs) | speedup |
|-------|---------|-------------|------------|---------|
| 10    | head    | <fill>      | <fill>     | <fill>x |
| 10    | tail    | <fill>      | <fill>     | <fill>x |
| 10    | random  | <fill>      | <fill>     | <fill>x |
| 100   | head    | <fill>      | <fill>     | <fill>x |
| 100   | tail    | <fill>      | <fill>     | <fill>x |
| 100   | random  | <fill>      | <fill>     | <fill>x |
| 1000  | head    | <fill>      | <fill>     | <fill>x |
| 1000  | tail    | <fill>      | <fill>     | <fill>x |
| 1000  | random  | <fill>      | <fill>     | <fill>x |
| 10000 | head    | <fill>      | <fill>     | <fill>x |
| 10000 | tail    | <fill>      | <fill>     | <fill>x |
| 10000 | random  | <fill>      | <fill>     | <fill>x |

Baseline 呈线性，after 平坦。

## Tests
- 新增 `test/services/job_queue_service_cancel_bench_test.dart` — diagnostic（不卡 CI），跑出数字
- 新增 `cancel perf invariant` group — head/tail/random N=10000 各 < 50ms 护栏
- 全部既有 cancel / pending / dispatch 用例不变全绿

## Test plan
- [x] flutter test test/services/job_queue_service_test.dart — 全绿
- [x] flutter analyze — 0 issue
- [ ] CI 通过
```

- [ ] **Step 3: 等 CI 全绿**

Run:
```
gh pr checks <PR#>
```

Expected: 4/4 pass。

---

## Self-Review

**Spec coverage:**
- Acceptance criterion "Before/after benchmark numbers in PR" ✅ — Task 1（baseline）+ Task 3 step 5（after）+ Task 6 PR template
- "Refactor compiles, all existing tests pass" ✅ — Task 2 step 3, Task 3 step 4, Task 5 step 2
- "New test asserts upper bound at N=10000 (loose enough to avoid flake — 50ms is fine)" ✅ — Task 4
- "No behavioral change visible to callers (FIFO preserved, retry unchanged)" ✅ — Queue 顺序未被改写，整段 cancel/dispatch 改动都保留既有契约；既有 cancel/pending/dispatch 测试不修改
- "Brief comment in source explaining data-structure trade-off" ✅ — Task 5
- "CI green" ✅ — Task 6 step 3

**Placeholder scan:** PR body 模板里的 `<fill>` 是占位的数字，执行 Task 1 / Task 3 步骤时实测填入——这是计划要求实测的内容，不是计划本身的 TODO。其它步骤全部是具体代码 / 命令 / 期望输出。

**Type consistency:**
- `_PendingJob` 字段 `cancelled` Task 2 step 1 引入，Task 3 step 1/2/3 使用 — ✅
- `_pendingIndex` Task 2 step 1 引入，Task 2 step 2、Task 3 step 1/3 使用 — ✅
- benchmark 用的 `_BenchNoopProvider` 与 perf test 用的 `_BenchNoopProvider` 同名同结构（一个在 diagnostic 文件、一个在 test 文件，互不冲突）— ✅
- `_seedPending` / `_buildBenchSvc` 仅在 perf invariant group 内使用 — ✅
