# Correctness Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 2 P0 bugs and the latent-correctness P1 cluster from `docs/AUDIT-REPORT.md` (canvas title, JobQueue silent data loss, edges-controller dispose crash, hash/equals contract, unsafe casts, N+1 queries, non-transactional lane reorder).

**Architecture:** Each task is a self-contained, TDD-driven fix touching one concern. Production code already verified verbatim against `main @ a5ba6a0`. No behavior is added — only correctness restored. Repositories/controllers stay behind their existing interfaces; tests use the in-memory fakes in `test/_harness/`.

**Tech Stack:** Flutter Desktop · Dart 3.11 · Riverpod · embedded PostgreSQL · freezed · InkError taxonomy.

## Global Constraints

- **Dart SDK** `^3.11.0`, **Flutter** `>=3.41.0` (null-aware collection elements `[?x]` / `{?k: v}` are valid — do not "fix" them).
- **Test runner:** `flutter` is NOT on PATH on this machine — invoke `C:\Users\Kerro\flutter\bin\flutter.bat`. Commands below write `flutter`; substitute that absolute path when running.
- **Before every commit:** `flutter analyze` must report `No issues found!` AND the task's tests must pass. No `--no-verify`, no skipping hooks.
- **Error handling:** all thrown domain errors are `InkError` subtypes; never `catch (Exception)` / `catch (_)` / `on Object` (see `lib/core/errors/ink_error.dart`).
- **Comments/code:** Chinese, minimal (per `docs/CLAUDE.md`). No new ARB keys are required by this plan.
- **Zero backward-compat:** no migration shims; change call sites directly.
- Each task ends with a commit. Conventional-commit messages; end the body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

| File | Task | Responsibility |
|---|---|---|
| `lib/features/canvas/providers/current_canvas_name.dart` | 1 | **Create** — resolve current canvas's real name from id |
| `lib/features/canvas/widgets/canvas_screen.dart` | 1 | **Modify** — consume the name provider, drop the param |
| `lib/app.dart` | 1 | **Modify** — `const CanvasScreen()` |
| `lib/services/job_queue_service.dart` | 2 | **Modify** — split persist guards (skip vs fail) |
| `lib/features/canvas/providers/canvas_edges_controller.dart` | 3 | **Modify** — add `_alive` guard |
| `lib/features/canvas/models/canvas_node.dart` | 4,5 | **Modify** — order-independent hashCode; safe `promptText`/`textContent` getters |
| `lib/features/canvas/widgets/node_card.dart` | 5 | **Modify** — use safe getter |
| `lib/features/canvas/widgets/image_config_inspector.dart` | 5 | **Modify** — use safe getter |
| `lib/core/interfaces/node_repository.dart` | 6 | **Modify** — add `findByIds` |
| `lib/storage/repositories/postgres_node_repository.dart` | 6 | **Modify** — implement `findByIds` |
| `lib/features/generation/generation_controller.dart` | 6 | **Modify** — batch ref/text resolution |
| `lib/core/interfaces/unit_of_work.dart` | 7 | **Modify** — add `styleLanes`/`batchResults` to scope |
| `lib/storage/postgres_unit_of_work.dart` | 7 | **Modify** — `RepositoryScopeData` two new fields |
| `lib/core/di/repositories.dart` | 7 | **Modify** — wire the two repos into `unitOfWorkProvider` |
| `lib/features/canvas/providers/canvas_lanes_controller.dart` | 7 | **Modify** — `reorderLanes` via UnitOfWork |
| `test/_harness/fake_repositories.dart` | 6 | **Modify** — add `findByIds` to `InMemoryNodeRepository` |
| `test/_harness/fake_unit_of_work.dart` | 7 | **Modify** — `FakeRepositoryScope` two new optional repos |
| `test/storage/transaction_integration_test.dart` | 7 | **Modify** — construct `RepositoryScopeData` with new fields |

---

## Task 1 (P0): Canvas title shows the real canvas name

**Files:**
- Create: `lib/features/canvas/providers/current_canvas_name.dart`
- Create: `test/features/canvas/providers/current_canvas_name_test.dart`
- Modify: `lib/features/canvas/widgets/canvas_screen.dart:17-20,34`
- Modify: `lib/app.dart:79`

**Interfaces:**
- Consumes: `currentCanvasIdProvider` (`StateProvider<String?>`), `canvasRepositoryProvider` (`FutureProvider<CanvasRepository>`), `CanvasRepository.findById(String) → Future<Map<String,Object?>?>`, `DbRow.optString`, `CanvasCol.name`.
- Produces: `currentCanvasNameProvider` (`AutoDisposeFutureProvider<String?>`) — `null` when no canvas selected / name unreadable.

- [ ] **Step 1: Write the failing test**

Create `test/features/canvas/providers/current_canvas_name_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_name.dart';

import '../../../_harness/fake_repositories.dart';

void main() {
  test('currentCanvasNameProvider 解析当前画布真实 name', () async {
    final canvasRepo = InMemoryCanvasRepository();
    final id = await canvasRepo.create(projectId: 'p1', name: '分镜画布 A');
    final container = ProviderContainer(overrides: [
      canvasRepositoryProvider.overrideWith((ref) async => canvasRepo),
    ]);
    addTearDown(container.dispose);
    container.read(currentCanvasIdProvider.notifier).state = id;

    final name = await container.read(currentCanvasNameProvider.future);
    expect(name, '分镜画布 A');
  });

  test('未选中画布时返回 null', () async {
    final container = ProviderContainer(overrides: [
      canvasRepositoryProvider
          .overrideWith((ref) async => InMemoryCanvasRepository()),
    ]);
    addTearDown(container.dispose);
    final name = await container.read(currentCanvasNameProvider.future);
    expect(name, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/providers/current_canvas_name_test.dart`
Expected: FAIL — `current_canvas_name.dart` does not exist / `currentCanvasNameProvider` undefined.

- [ ] **Step 3: Create the provider**

Create `lib/features/canvas/providers/current_canvas_name.dart`:

```dart
// currentCanvasNameProvider — 当前打开画布的真实 name（从 canvases 表读）。
//
// 未选中画布 / 名称不可读时返回 null；CanvasScreen 据此回退到本地化默认名。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/di/repositories.dart';
import 'current_canvas_id.dart';

final currentCanvasNameProvider = FutureProvider.autoDispose<String?>(
  (ref) async {
    final canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId == null) return null;
    final repo = await ref.watch(canvasRepositoryProvider.future);
    final row = await repo.findById(canvasId);
    return row?.optString(CanvasCol.name);
  },
  name: 'currentCanvasNameProvider',
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/canvas/providers/current_canvas_name_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Wire the provider into CanvasScreen**

In `lib/features/canvas/widgets/canvas_screen.dart` replace the constructor + field (lines 17-20):

```dart
class CanvasScreen extends ConsumerWidget {
  const CanvasScreen({super.key});
```

Remove the `final String canvasName;` line. Add the import near the other provider imports (after line 9):

```dart
import '../providers/current_canvas_name.dart';
```

In `build`, replace the `CanvasTopChrome(canvasName: canvasName)` line (34). First, just under the existing `final canvasId = ref.watch(currentCanvasIdProvider);` (line 25), add:

```dart
    final canvasName =
        ref.watch(currentCanvasNameProvider).valueOrNull ??
            context.l10n.canvasDefaultName;
```

Add the l10n import if not present (top of file, with other imports):

```dart
import '../../../l10n/l10n_x.dart';
```

Line 34 stays `CanvasTopChrome(canvasName: canvasName)` — now fed the resolved name.

- [ ] **Step 6: Update the only caller**

In `lib/app.dart` change line 79 from:

```dart
      return CanvasScreen(canvasName: context.l10n.canvasDefaultName);
```

to:

```dart
      return const CanvasScreen();
```

- [ ] **Step 7: Verify analyze + full canvas tests pass**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/features/canvas/`
Expected: PASS (no test constructs `CanvasScreen(canvasName:)` — verified via grep; `CanvasTopChrome` tests are unaffected).

- [ ] **Step 8: Commit**

```bash
git add lib/features/canvas/providers/current_canvas_name.dart \
        test/features/canvas/providers/current_canvas_name_test.dart \
        lib/features/canvas/widgets/canvas_screen.dart lib/app.dart
git commit -m "fix(canvas): 画布标题显示真实画布名而非本地化默认名 (P0)"
```

---

## Task 2 (P0): JobQueue fails (not silent-success) when production IDs are missing

**Files:**
- Modify: `lib/services/job_queue_service.dart:549-555` (`_persistInlineBytes`), `616-623` (`_persistRemoteUrls`)
- Test: `test/services/job_queue_service_remote_urls_test.dart` (add one case)

**Interfaces:**
- Consumes: `LocalIOError` (`lib/core/errors/ink_error.dart`), `GenerationTask.{projectId,canvasId,resultNodeId,jobId}`.
- Produces: both `_persist*` return a non-null `InkError` when persistence deps are injected but a task ID is null (job → failure); they still return `null` (skip) when deps themselves are absent (no-persistence/unit-test mode).

**Background (verified):** Caller at `job_queue_service.dart:368-372` and `378-383` treats a non-null return as failure. Today both methods `return null` when *either* the deps (`_nodeRepo`/`_fileResolver`/`_videoDownloader`) *or* the IDs are null — so a production task with a null ID is silently marked success. The deps are nullable for tests; the IDs are a production fault. Split them.

- [ ] **Step 1: Write the failing test**

In `test/services/job_queue_service_remote_urls_test.dart`, first read the existing `setUp`/queue-construction helper in that file (it already wires `_FakeProvider`, `_FakeJobRepo`, a node repo, a real `FileResolverService`, and a `VideoDownloadService`). Add this test inside the top-level `group`, mirroring the existing success-path test but with `resultNodeId: null`:

```dart
  test('远程产物：resultNodeId 为空(生产缺 ID) → job 失败而非静默成功', () async {
    // 复用本文件既有 fakes 构造队列（fileResolver + nodeRepo + videoDownloader 均已注入）。
    // 仅把任务的 resultNodeId 置空，断言不会被当成成功。
    final queue = buildQueue(
      pollSequence: const [
        JobSuccess(remoteUrls: ['https://example.com/out.png']),
      ],
    );
    fakeJobRepo.seedPending('job-missing-id');
    final handle = await queue.submit(
      makeTask(
        jobId: 'job-missing-id',
        mode: GenerationMode.textToImage,
        resultNodeId: null, // ← 生产缺 ID
      ),
    );
    final done = await handle.done;
    expect(done, isA<JobFailure>());
    // 节点未被 patch（产物没有被静默丢弃当成功）。
    expect(fakeNodeRepo.patchCalls, isEmpty);
  });
```

> If the file's helpers are named differently than `buildQueue`/`makeTask`/`fakeJobRepo`/`fakeNodeRepo`/`patchCalls`, adapt these references to the names already present in the file (they exist — this file already injects nodeRepo + fileResolver to exercise the persist path). Do not invent a new harness.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/job_queue_service_remote_urls_test.dart`
Expected: FAIL — `done` is `JobSuccess` (current silent-success bug), not `JobFailure`.

- [ ] **Step 3: Fix `_persistInlineBytes` guard**

In `lib/services/job_queue_service.dart`, replace the guard block at lines 549-555:

```dart
    if (projectId == null ||
        canvasId == null ||
        resultNodeId == null ||
        fileResolver == null ||
        nodeRepo == null) {
      return null;
    }
```

with:

```dart
    // 依赖未注入 = 纯内存/单测模式：跳过落盘（非故障）。
    if (fileResolver == null || nodeRepo == null) {
      return null;
    }
    // 依赖已注入但关键 ID 缺失 = 生产故障：必须失败，绝不静默丢产物当成功。
    if (projectId == null || canvasId == null || resultNodeId == null) {
      return LocalIOError(
        extra: <String, Object?>{
          'job_id': task.jobId,
          'reason': 'missing_result_ids',
        },
      );
    }
```

- [ ] **Step 4: Fix `_persistRemoteUrls` guard**

Replace the guard block at lines 616-623:

```dart
    if (projectId == null ||
        canvasId == null ||
        resultNodeId == null ||
        fileResolver == null ||
        nodeRepo == null ||
        downloader == null) {
      return null;
    }
```

with:

```dart
    // 依赖未注入 = 纯内存/单测模式：跳过下载落盘（非故障）。
    if (fileResolver == null || nodeRepo == null || downloader == null) {
      return null;
    }
    // 依赖已注入但关键 ID 缺失 = 生产故障：失败，不静默丢产物。
    if (projectId == null || canvasId == null || resultNodeId == null) {
      return LocalIOError(
        extra: <String, Object?>{
          'job_id': task.jobId,
          'reason': 'missing_result_ids',
        },
      );
    }
```

- [ ] **Step 5: Run the new test + the full service suite**

Run: `flutter test test/services/job_queue_service_remote_urls_test.dart test/services/job_queue_service_test.dart`
Expected: PASS — the new case fails the job; existing tests (deps absent → skip) still pass.

- [ ] **Step 6: Verify analyze + commit**

Run: `flutter analyze`
Expected: `No issues found!`

```bash
git add lib/services/job_queue_service.dart test/services/job_queue_service_remote_urls_test.dart
git commit -m "fix(jobqueue): 关键 ID 缺失时任务失败而非静默丢弃产物 (P0)"
```

---

## Task 3 (P1): CanvasEdgesController `_alive` guard (dispose-during-await crash)

**Files:**
- Modify: `lib/features/canvas/providers/canvas_edges_controller.dart`
- Test: `test/features/canvas/canvas_edges_controller_test.dart` (add one case)

**Interfaces:**
- Consumes: `AutoDisposeFamilyAsyncNotifier` lifecycle (`build`, `ref.onDispose`).
- Produces: post-`await` `state =` writes guarded by `_alive` (matches `CanvasNodesController`/`CanvasLanesController` ME-27 pattern).

- [ ] **Step 1: Write the failing test**

In `test/features/canvas/canvas_edges_controller_test.dart`, add a gated fake + test. Add this fake class above `void main()`:

```dart
class _GatedEdgeRepo implements EdgeRepository {
  final Completer<void> gate = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async => [];
  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) async {
    await gate.future; // 阻塞，模拟 await 期间 provider 被 dispose
    return 'e1';
  }
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listOutgoing(String s) async => [];
  @override
  Future<List<Map<String, Object?>>> listIncoming(String t) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;
  @override
  Future<int> softDelete(String id) async => 1;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}
```

Add `import 'dart:async';` at the top of the test file (for `Completer`). Inside the `group('CanvasEdgesController', ...)`, add:

```dart
    test('addEdge 在 await 期间被 dispose 不抛 StateError (ME-27 _alive 守卫)',
        () async {
      final gated = _GatedEdgeRepo();
      final c = ProviderContainer(overrides: [
        edgeRepositoryProvider.overrideWith((ref) async => gated),
      ]);
      await c.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl =
          c.read(canvasEdgesControllerProvider(canvasId).notifier);
      final future = ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      c.dispose();          // await 期间销毁 notifier
      gated.gate.complete(); // 放行 create
      await expectLater(future, completes); // 守卫存在 → 无 StateError
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/canvas_edges_controller_test.dart -n "_alive"`
Expected: FAIL — `Bad state: Cannot use ... after dispose` thrown from the post-await `state = AsyncData([...])`.

- [ ] **Step 3: Add the `_alive` field + lifecycle + guards**

In `lib/features/canvas/providers/canvas_edges_controller.dart`:

After the class opening (line 20, before `build`), add the field:

```dart
  bool _alive = false;
```

Replace `build` (lines 21-26) with:

```dart
  @override
  Future<List<CanvasEdge>> build(String canvasId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final repo = await ref.watch(edgeRepositoryProvider.future);
    final rows = await repo.listByCanvas(canvasId);
    return rows.map(CanvasEdgeMapping.fromRow).toList(growable: false);
  }
```

Guard the four post-await `state =` writes:
- Line 65 `state = AsyncData([...previous, edge]);` → `if (_alive) state = AsyncData([...previous, edge]);`
- Line 68 `state = AsyncData(previous);` (addEdge catch) → `if (_alive) state = AsyncData(previous);`
- Line 79 `state = AsyncData(previous);` (removeEdge catch) → `if (_alive) state = AsyncData(previous);`
- Line 98 `state = AsyncData(previous);` (updateRole catch) → `if (_alive) state = AsyncData(previous);`

Also correct the now-accurate comment on `addEdge` (line 37): change `/// 创建连线。乐观写——先更新内存，DB 失败回滚并 rethrow。` to `/// 创建连线。await create 成功后写内存；失败 rethrow（与 nodes/lanes 对齐 ME-27 守卫）。`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/canvas/canvas_edges_controller_test.dart`
Expected: PASS (the new case + all existing cases).

- [ ] **Step 5: Verify analyze + commit**

Run: `flutter analyze`
Expected: `No issues found!`

```bash
git add lib/features/canvas/providers/canvas_edges_controller.dart \
        test/features/canvas/canvas_edges_controller_test.dart
git commit -m "fix(canvas): CanvasEdgesController 补 _alive 守卫防 dispose 期写 state (P1)"
```

---

## Task 4 (P1): CanvasNode order-independent hashCode

**Files:**
- Modify: `lib/features/canvas/models/canvas_node.dart:153-154`
- Test: `test/features/canvas/models/canvas_node_video_test.dart` (add one case) — or create `test/features/canvas/models/canvas_node_hash_test.dart`

**Interfaces:**
- Consumes: `Object.hashAllUnordered` (dart:core).
- Produces: `CanvasNode.hashCode` consistent with `==` (both order-independent over `typeConfig`).

- [ ] **Step 1: Write the failing test**

Create `test/features/canvas/models/canvas_node_hash_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  test('typeConfig 内容相同、插入顺序不同 → == 为真且 hashCode 相等', () {
    const a = CanvasNode(
      id: 'n1',
      label: 'L',
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{'a': 1, 'b': 2},
    );
    const b = CanvasNode(
      id: 'n1',
      label: 'L',
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{'b': 2, 'a': 1}, // 不同插入顺序
    );
    expect(a == b, isTrue);
    expect(a.hashCode, b.hashCode); // 契约：== 为真则 hashCode 必相等
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/models/canvas_node_hash_test.dart`
Expected: FAIL — `a.hashCode != b.hashCode` (current `Object.hashAll` is order-dependent).

- [ ] **Step 3: Make the hash order-independent**

In `lib/features/canvas/models/canvas_node.dart`, replace lines 153-154:

```dart
        Object.hashAll(typeConfig.entries
            .map((e) => Object.hash(e.key, e.value))),
```

with:

```dart
        Object.hashAllUnordered(
            typeConfig.entries.map((e) => Object.hash(e.key, e.value))),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/canvas/models/canvas_node_hash_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify analyze + commit**

Run: `flutter analyze`
Expected: `No issues found!`

```bash
git add lib/features/canvas/models/canvas_node.dart \
        test/features/canvas/models/canvas_node_hash_test.dart
git commit -m "fix(canvas): CanvasNode hashCode 改顺序无关，修复 ==/hashCode 契约 (P1)"
```

---

## Task 5 (P1): Safe typeConfig string accessors (no CastError)

**Files:**
- Modify: `lib/features/canvas/models/canvas_node.dart` (add two getters after `videoMode`, ~line 95)
- Modify: `lib/features/canvas/widgets/node_card.dart:282-283`
- Modify: `lib/features/canvas/widgets/image_config_inspector.dart:411`
- Test: `test/features/canvas/models/canvas_node_hash_test.dart` (extend) or new `canvas_node_typeconfig_test.dart`

**Interfaces:**
- Produces: `CanvasNode.promptText` (`String?`) and `CanvasNode.textContent` (`String?`) — return `null` when the key is absent or non-String (never throw).

**Background (verified):** `node_card.dart:283` does `node.typeConfig['prompt'] as String?` and `image_config_inspector.dart:411` does `(src.typeConfig['text'] as String?)` — both throw `TypeError` if the JSONB value is a non-String. The model already uses the safe `is String` pattern for `imageUrl`/`videoUrl`; extend it.

- [ ] **Step 1: Write the failing test**

Create `test/features/canvas/models/canvas_node_typeconfig_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  test('promptText / textContent：非 String 值返回 null 不抛', () {
    const n = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.text,
      typeConfig: <String, Object?>{'prompt': 123, 'text': true},
    );
    expect(n.promptText, isNull);
    expect(n.textContent, isNull);
  });

  test('promptText / textContent：String 值原样返回', () {
    const n = CanvasNode(
      id: 'n2',
      label: '',
      type: CanvasNodeType.text,
      typeConfig: <String, Object?>{'prompt': '画一只猫', 'text': '旁白'},
    );
    expect(n.promptText, '画一只猫');
    expect(n.textContent, '旁白');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/models/canvas_node_typeconfig_test.dart`
Expected: FAIL — `promptText`/`textContent` undefined.

- [ ] **Step 3: Add the getters to the model**

In `lib/features/canvas/models/canvas_node.dart`, after the `videoMode` getter (ends line 95), add:

```dart

  /// config 节点用户 prompt 文本；非 String 或未设置时为 null。
  String? get promptText {
    final v = typeConfig['prompt'];
    return v is String ? v : null;
  }

  /// text 节点正文（type_config.text）；非 String 或未设置时为 null。
  String? get textContent {
    final v = typeConfig['text'];
    return v is String ? v : null;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/canvas/models/canvas_node_typeconfig_test.dart`
Expected: PASS.

- [ ] **Step 5: Swap the unsafe call sites**

In `lib/features/canvas/widgets/node_card.dart`, replace the `Text(...)` first argument (line 283):

```dart
        node.label.isEmpty ? (node.typeConfig['prompt'] as String? ?? '') : node.label,
```

with:

```dart
        node.label.isEmpty ? (node.promptText ?? '') : node.label,
```

In `lib/features/canvas/widgets/image_config_inspector.dart`, replace line 411:

```dart
      final t = (src.typeConfig['text'] as String?)?.trim();
```

with:

```dart
      final t = src.textContent?.trim();
```

- [ ] **Step 6: Verify analyze + canvas tests + commit**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/features/canvas/`
Expected: PASS.

```bash
git add lib/features/canvas/models/canvas_node.dart \
        lib/features/canvas/widgets/node_card.dart \
        lib/features/canvas/widgets/image_config_inspector.dart \
        test/features/canvas/models/canvas_node_typeconfig_test.dart
git commit -m "fix(canvas): typeConfig 字符串读取改 is-String 安全访问器，消除 CastError (P1)"
```

---

## Task 6 (P1): Eliminate N+1 queries in GenerationController

**Files:**
- Modify: `lib/core/interfaces/node_repository.dart` (add `findByIds`)
- Modify: `lib/storage/repositories/postgres_node_repository.dart` (implement)
- Modify: `test/_harness/fake_repositories.dart` (`InMemoryNodeRepository.findByIds`)
- Modify: `lib/features/generation/generation_controller.dart:458-533` (`_resolveRefImages`), `577-602` (`_resolveAssociatedTexts`)
- Test: `test/_harness/_fakes_test.dart` (add `findByIds` behavior case)

**Interfaces:**
- Produces: `NodeRepository.findByIds(List<String> ids) → Future<List<Map<String,Object?>>>` — alive nodes whose id ∈ ids (JOIN canvases for `project_id`, like `findById`). Order unspecified; callers index by id.
- Consumes (in controller): build a `Map<String,row>` from one `findByIds` call instead of per-edge `findById`.

- [ ] **Step 1: Write the failing test (interface + fake behavior)**

In `test/_harness/_fakes_test.dart`, add:

```dart
  test('InMemoryNodeRepository.findByIds 返回匹配的存活节点', () async {
    final repo = InMemoryNodeRepository();
    final a = await repo.create(canvasId: 'c', type: 'text', nodeRole: 'config');
    final b = await repo.create(canvasId: 'c', type: 'image', nodeRole: 'config');
    await repo.create(canvasId: 'c', type: 'text', nodeRole: 'config'); // 不在 ids 内
    final rows = await repo.findByIds([a, b, 'missing']);
    expect(rows.map((r) => r['id']), containsAll(<String>[a, b]));
    expect(rows, hasLength(2));
  });
```

> Ensure `import 'package:inkframe/...'` for `InMemoryNodeRepository` matches the file's existing imports (it imports the harness fakes already).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/_harness/_fakes_test.dart`
Expected: FAIL — `findByIds` not defined on `NodeRepository`.

- [ ] **Step 3: Add to the interface**

In `lib/core/interfaces/node_repository.dart`, after `findById` (line 19), add:

```dart

  /// 批量按 id 取存活节点（消除调用方 N+1）。返回顺序不保证，调用方按 id 建索引。
  Future<List<Map<String, Object?>>> findByIds(List<String> ids);
```

- [ ] **Step 4: Implement in the fake**

In `test/_harness/fake_repositories.dart`, inside `InMemoryNodeRepository`, after `findById` (line 250), add:

```dart

  @override
  Future<List<Map<String, Object?>>> findByIds(List<String> ids) async {
    final wanted = ids.toSet();
    return _rows.values
        .where((r) => wanted.contains(r['id']) && r['deleted_at'] == null)
        .map(Map<String, Object?>.of)
        .toList();
  }
```

- [ ] **Step 5: Implement in PostgresNodeRepository**

In `lib/storage/repositories/postgres_node_repository.dart`, after `findById` (line 74), add:

```dart

  @override
  Future<List<Map<String, Object?>>> findByIds(List<String> ids) {
    return guard('findByIds', 'nodes', () async {
      if (ids.isEmpty) return const <Map<String, Object?>>[];
      final r = await session.execute(
        Sql.named(
          '$_selectWithProject WHERE n.id = ANY(@ids) AND n.deleted_at IS NULL',
        ),
        parameters: <String, Object?>{'ids': ids},
      );
      return allRows(r);
    });
  }
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/_harness/_fakes_test.dart`
Expected: PASS.
Run: `flutter analyze`
Expected: `No issues found!` (confirms every `NodeRepository` implementor now satisfies the interface).

- [ ] **Step 7: Refactor `_resolveRefImages` to batch-fetch**

In `lib/features/generation/generation_controller.dart`, replace the per-edge loop body. Replace lines 465-514 (from `final List<String> refs = [];` through the closing of the `for (final row in incoming)` loop) with:

```dart
    final List<String> refs = [];
    String? firstFrame;
    String? lastFrame;
    var failedResolves = 0;

    // 先收集 (srcId, role)，一次 findByIds 批量取源节点，消除 N+1。
    final dataRows = incoming
        .where((row) => row[EdgeCol.edgeType] == 'data')
        .toList();
    final srcIds = <String>{
      for (final row in dataRows)
        if (row.optId(EdgeCol.sourceNodeId) case final id?) id,
    };
    Map<String, Map<String, Object?>> srcById = const {};
    if (srcIds.isNotEmpty) {
      try {
        final rows = await nodes.findByIds(srcIds.toList());
        srcById = {for (final r in rows) r.reqId(NodeCol.id): r};
      } on InkError catch (e) {
        logger?.warn(_logModule, 'ref source batch lookup failed (swallowed)',
            extra: {'reason': e.toString()});
      }
    }

    for (final row in dataRows) {
      final srcId = row.optId(EdgeCol.sourceNodeId);
      if (srcId == null) continue;
      final role = row.optString(EdgeCol.role) ?? 'reference';
      final srcRow = srcById[srcId];
      if (srcRow == null) continue;

      final tc = _readTypeConfig(srcRow[NodeCol.typeConfig]);
      final relPath = tc['image_url'];
      if (relPath is! String || relPath.isEmpty) continue;

      final String absPath;
      try {
        absPath = resolver
            .resolve(
              projectId: projectId,
              canvasId: canvasId,
              relativePath: relPath,
            )
            .path;
      } catch (e) {
        failedResolves++;
        logger?.warn(_logModule, 'ref path resolve failed (swallowed)',
            extra: {'source_node_id': srcId, 'reason': e.toString()});
        continue;
      }

      switch (role) {
        case 'first_frame':
          firstFrame ??= absPath;
        case 'last_frame':
          lastFrame ??= absPath;
        default:
          refs.add(absPath);
      }
    }
```

> `reqId`/`optId` are `DbRow` extension methods already imported via `row_reader.dart` in this file (used at line 472). `NodeCol.id` exists in `columns.dart`. The `catch (e)` on `resolver.resolve` is pre-existing (PathSecurityError is not an InkError) — leave it; narrowing it is out of scope for this task.

- [ ] **Step 8: Refactor `_resolveAssociatedTexts` to batch-fetch**

Replace `_resolveAssociatedTexts` (lines 578-602) with:

```dart
  Future<List<String>> _resolveAssociatedTexts(
    List<Map<String, Object?>> incoming,
  ) async {
    final rows = incoming.where((r) => r[EdgeCol.edgeType] == 'data').toList()
      ..sort((a, b) => (a[EdgeCol.createdAt]?.toString() ?? '')
          .compareTo(b[EdgeCol.createdAt]?.toString() ?? ''));
    final srcIds = <String>{
      for (final r in rows)
        if (r.optId(EdgeCol.sourceNodeId) case final id?) id,
    };
    if (srcIds.isEmpty) return const <String>[];
    Map<String, Map<String, Object?>> srcById = const {};
    try {
      final fetched = await nodes.findByIds(srcIds.toList());
      srcById = {for (final r in fetched) r.reqId(NodeCol.id): r};
    } on InkError catch (_) {
      return const <String>[];
    }

    final out = <String>[];
    for (final r in rows) {
      final srcId = r.optId(EdgeCol.sourceNodeId);
      if (srcId == null) continue;
      final src = srcById[srcId];
      if (src == null || src[NodeCol.type] != 'text') continue;
      final tc = _readTypeConfig(src[NodeCol.typeConfig]);
      final text = (tc['text'] as String?)?.trim();
      final label = src.optString(NodeCol.label)?.trim();
      final content = (text != null && text.isNotEmpty) ? text : (label ?? '');
      if (content.isNotEmpty) out.add(content);
    }
    return out;
  }
```

- [ ] **Step 9: Run analyze + the generation e2e regression**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/e2e/generation_render_node_e2e_test.dart test/_harness/_fakes_test.dart`
Expected: PASS — the e2e exercise of the generation path still produces the same result with one batched fetch.

- [ ] **Step 10: Commit**

```bash
git add lib/core/interfaces/node_repository.dart \
        lib/storage/repositories/postgres_node_repository.dart \
        test/_harness/fake_repositories.dart test/_harness/_fakes_test.dart \
        lib/features/generation/generation_controller.dart
git commit -m "perf(generation): findByIds 批量取源节点，消除 ref/text 解析 N+1 (P1)"
```

---

## Task 7 (P1): Atomic lane reorder via expanded transaction scope

**Files:**
- Modify: `lib/core/interfaces/unit_of_work.dart` (add 2 getters)
- Modify: `lib/storage/postgres_unit_of_work.dart` (`RepositoryScopeData` 2 fields + imports)
- Modify: `lib/core/di/repositories.dart:89-98` (construct the 2 repos)
- Modify: `test/_harness/fake_unit_of_work.dart` (`FakeRepositoryScope` 2 optional repos)
- Modify: `test/storage/transaction_integration_test.dart:24` (construct with 2 new fields)
- Modify: `lib/features/canvas/providers/canvas_lanes_controller.dart:111-133` (`reorderLanes` via UoW)
- Test: `test/features/canvas/canvas_lanes_controller_test.dart` (**create**)

**Interfaces:**
- Consumes: `StyleLaneRepository`, `BatchResultRepository`, `PostgresStyleLaneRepository`, `PostgresBatchResultRepository`, `unitOfWorkProvider`, `RepositoryScope`, `StyleLaneCol.sortOrder`.
- Produces: `RepositoryScope.styleLanes` (`StyleLaneRepository`) and `RepositoryScope.batchResults` (`BatchResultRepository`); `CanvasLanesController.reorderLanes` performs all sort_order updates inside a single `UnitOfWork.run`.

**Background (verified):** `RepositoryScope` (unit_of_work.dart:15-21) exposes only nodes/edges/canvas/projects/jobs. `reorderLanes` (canvas_lanes_controller.dart:111-133) loops `await repo.update(...)` per lane — non-atomic; a mid-loop failure half-updates the DB while memory rolls back. Three `RepositoryScopeData`/`FakeRepositoryScope` construction sites must learn the two new repos.

### Subtask 7a — Expand the transaction scope (compile-gated)

- [ ] **Step 1: Add the two getters to the interface**

In `lib/core/interfaces/unit_of_work.dart`, add imports after line 12:

```dart
import 'batch_result_repository.dart';
import 'style_lane_repository.dart';
```

Add to `abstract class RepositoryScope` (after `JobRepository get jobs;`, line 20):

```dart
  StyleLaneRepository get styleLanes;
  BatchResultRepository get batchResults;
```

- [ ] **Step 2: Run analyze to see every construction site break**

Run: `flutter analyze`
Expected: FAIL — `RepositoryScopeData` and `FakeRepositoryScope` are missing concrete `styleLanes`/`batchResults`; `unitOfWorkProvider` constructor call lacks the args. (This is the TDD "red" for a compile-gated change — it enumerates the sites to fix.)

- [ ] **Step 3: Update `RepositoryScopeData`**

In `lib/storage/postgres_unit_of_work.dart`, add imports after line 13:

```dart
import '../core/interfaces/batch_result_repository.dart';
import '../core/interfaces/style_lane_repository.dart';
```

In `RepositoryScopeData`, add to the constructor (after `required this.jobs,`):

```dart
    required this.styleLanes,
    required this.batchResults,
```

And add the fields (after the `jobs` field, line 63):

```dart
  @override
  final StyleLaneRepository styleLanes;
  @override
  final BatchResultRepository batchResults;
```

- [ ] **Step 4: Wire them in DI**

In `lib/core/di/repositories.dart`, in `unitOfWorkProvider` (lines 91-97), add to the `RepositoryScopeData(...)` construction (after `jobs: PostgresJobRepository(s),`):

```dart
        styleLanes: PostgresStyleLaneRepository(s),
        batchResults: PostgresBatchResultRepository(s),
```

(Imports for both Postgres classes already exist at lines 19 & 25.)

- [ ] **Step 5: Update the test harness `FakeRepositoryScope`**

In `test/_harness/fake_unit_of_work.dart`, add imports after line 7:

```dart
import 'package:inkframe/core/interfaces/batch_result_repository.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
```

Add optional ctor params (after `JobRepository? jobs,`):

```dart
    StyleLaneRepository? styleLanes,
    BatchResultRepository? batchResults,
```

Add to the initializer list (after `_jobs = jobs;` → change to `_jobs = jobs,` and append):

```dart
        _styleLanes = styleLanes,
        _batchResults = batchResults;
```

Add fields + getters (after the `_jobs`/`jobs` members):

```dart
  final StyleLaneRepository? _styleLanes;
  final BatchResultRepository? _batchResults;

  @override
  StyleLaneRepository get styleLanes =>
      _styleLanes ?? (throw StateError('styleLanes not provided'));
  @override
  BatchResultRepository get batchResults =>
      _batchResults ?? (throw StateError('batchResults not provided'));
```

- [ ] **Step 6: Update the PG integration test construction**

In `test/storage/transaction_integration_test.dart`, in the `RepositoryScopeData(...)` at line ~24, add the two fields (mirror the DI site):

```dart
        styleLanes: PostgresStyleLaneRepository(s),
        batchResults: PostgresBatchResultRepository(s),
```

Add the imports for both Postgres classes at the top of that test file if not already present:

```dart
import 'package:inkframe/storage/repositories/postgres_style_lane_repository.dart';
import 'package:inkframe/storage/repositories/postgres_batch_result_repository.dart';
```

- [ ] **Step 7: Verify analyze is green again**

Run: `flutter analyze`
Expected: `No issues found!` (all scope implementors satisfied).

### Subtask 7b — `reorderLanes` becomes transactional

- [ ] **Step 8: Write the failing test**

Create `test/features/canvas/canvas_lanes_controller_test.dart`:

```dart
// CanvasLanesController.reorderLanes 单测：sort_order 更新必须经 UnitOfWork。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';

import '../../_harness/fake_unit_of_work.dart';

class _FakeLaneRepo implements StyleLaneRepository {
  _FakeLaneRepo({this.updateThrows = false});
  final bool updateThrows;
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  final List<Map<String, Object?>> updateCalls = <Map<String, Object?>>[];

  void seed(String id, int order) => rows.add(<String, Object?>{
        'id': id,
        'canvas_id': 'cvx',
        'label': '',
        'style_prompt': '',
        'sort_order': order,
        'tint_color': null,
        'size': 400.0,
      });

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      rows.where((r) => r['canvas_id'] == canvasId).toList();
  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    if (updateThrows) {
      throw const LocalIOError(extra: {'op': 'update', 'table': 'style_lanes'});
    }
    updateCalls.add({'id': id, ...patch});
    return 1;
  }
  @override
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = 400.0,
  }) async => 'l-new';
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<int> softDelete(String id) async => 1;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

void main() {
  const canvasId = 'cvx';

  test('reorderLanes 经 UnitOfWork 更新 sort_order（不走直连 repo）', () async {
    // build/_repo 用的直连仓储：update 抛异常——若 reorder 误走直连即失败。
    final direct = _FakeLaneRepo(updateThrows: true)
      ..seed('l1', 0)
      ..seed('l2', 1)
      ..seed('l3', 2);
    // 事务作用域内的仓储：记录更新。
    final scoped = _FakeLaneRepo();
    final uow = FakeUnitOfWork(FakeRepositoryScope(styleLanes: scoped));

    final container = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => direct),
      unitOfWorkProvider.overrideWith((ref) async => uow),
    ]);
    addTearDown(container.dispose);

    await container.read(canvasLanesControllerProvider(canvasId).future);
    final ctrl =
        container.read(canvasLanesControllerProvider(canvasId).notifier);

    await ctrl.reorderLanes(['l3', 'l1', 'l2']); // l3→0, l1→1, l2→2

    expect(scoped.updateCalls.map((c) => c['id']),
        containsAll(<String>['l1', 'l2', 'l3']));
    expect(direct.updateCalls, isEmpty); // 证明没走直连 repo
  });
}
```

- [ ] **Step 9: Run test to verify it fails**

Run: `flutter test test/features/canvas/canvas_lanes_controller_test.dart`
Expected: FAIL — current `reorderLanes` calls `_repo.update` (the `direct` repo, which throws) → `LocalIOError` propagates, `scoped.updateCalls` empty.

- [ ] **Step 10: Rewrite `reorderLanes` to use UnitOfWork**

In `lib/features/canvas/providers/canvas_lanes_controller.dart`, add the import after line 7 (`import '../../../core/di/repositories.dart';` already present — it provides both `styleLaneRepositoryProvider` and `unitOfWorkProvider`, so no new import needed).

Replace `reorderLanes` (lines 110-133) with:

```dart
  /// 按给定 id 顺序重排泳道，sort_order=下标。乐观更新 + 失败回滚。
  /// 所有 sort_order 更新落在单个 UnitOfWork 事务内（原子，半重排不可见）。
  Future<void> reorderLanes(List<String> orderedIds) async {
    final previous = state.valueOrNull ?? const <StyleLane>[];
    final byId = {for (final l in previous) l.id: l};
    final reordered = <StyleLane>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final lane = byId[orderedIds[i]];
      if (lane != null) reordered.add(lane.copyWith(sortOrder: i));
    }
    if (reordered.length != previous.length) return; // 不完整顺序，跳过
    state = AsyncData(reordered);
    try {
      final uow = await ref.read(unitOfWorkProvider.future);
      await uow.run((scope) async {
        for (var i = 0; i < reordered.length; i++) {
          if (byId[reordered[i].id]!.sortOrder != i) {
            await scope.styleLanes.update(
                reordered[i].id, <String, Object?>{StyleLaneCol.sortOrder: i});
          }
        }
      });
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }
```

(This also removes the O(n²) `previous.firstWhere(...)` by reusing the `byId` map.)

- [ ] **Step 11: Run test to verify it passes**

Run: `flutter test test/features/canvas/canvas_lanes_controller_test.dart`
Expected: PASS.

- [ ] **Step 12: Verify analyze + commit**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/features/canvas/ test/storage/`
Expected: PASS (PG integration tests skip locally if `TEST_PG_URL` is unset; they run in CI).

```bash
git add lib/core/interfaces/unit_of_work.dart lib/storage/postgres_unit_of_work.dart \
        lib/core/di/repositories.dart test/_harness/fake_unit_of_work.dart \
        test/storage/transaction_integration_test.dart \
        lib/features/canvas/providers/canvas_lanes_controller.dart \
        test/features/canvas/canvas_lanes_controller_test.dart
git commit -m "fix(canvas): reorderLanes 经 UnitOfWork 原子重排；RepositoryScope 补 style_lanes/batch_results (P1)"
```

---

## Final Verification

- [ ] **Run the full suite + analyzer**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test`
Expected: all pass (PG-gated storage tests run in CI; locally they skip without `TEST_PG_URL`).

---

## Self-Review Notes (author)

- **Spec coverage:** the 7 tasks map 1:1 to the chosen audit slice — P0-1 (T1), P0-2 (T2), P1 edges `_alive` (T3), P1 hash/equals (T4), P1 unsafe casts (T5), P1 N+1 (T6), P1 reorderLanes+RepositoryScope (T7). The "misleading optimistic comment" (audit P1-22) is folded into T3 Step 3.
- **Type consistency:** `findByIds(List<String>) → Future<List<Map<String,Object?>>>` is defined in T6 Step 3 and consumed identically in Steps 7–8; `RepositoryScope.styleLanes`/`batchResults` defined in T7 Step 1 and consumed in T7 Step 10.
- **Out of scope (separate plans):** error-handling unification (GenerationError/catch-all/ServerException), design-token tiers, freezed migration, SQL allow-list, i18n displayName — tracked in `docs/AUDIT-REPORT.md` §3–§4.
- **Test fidelity caveat:** T2's test reuses the existing in-file harness in `job_queue_service_remote_urls_test.dart`; read that file's `setUp`/builders first and match their real names. The reorder-atomicity *rollback* semantics (vs. routing) are covered by PG integration tests, not the fake-based unit test.
```
