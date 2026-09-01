# Audit P0 Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 3 P0 findings from the 2026-08-31 full audit: a real (non-dry-run) file-delete path in `OrphanFileReaper`, silent loss of the user's last edit in the canvas Inspector's debounced autosave, and the missing "Import project" entry point when Studio has zero projects.

**Architecture:** Three independent, surgical fixes — no shared code between them. (1) Delete the dead `dryRun:false` branch and its `_reapFile` implementation from `DiskOrphanFileReaper`, narrowing the interface so the real-delete path no longer exists in this class at all. (2) Make the two independent debounce mechanisms (`InspectorSubmitController.savePromptDebounced`, and `_ShotConfigInspectorState`'s local `Timer`) flush their pending write before the timer's owner is torn down, instead of just cancelling it. (3) Extract the private `_importProject` flow in `studio_home_screen.dart` into a public, reusable function so it can be wired into both the zero-project empty state and the Studio command-palette context, not just the FAB.

**Tech Stack:** Flutter (Dart), Riverpod (manual providers, `AutoDisposeFamilyNotifier` + `KeepAliveLink`), `flutter_test` + `ProviderContainer`/`pumpInkApp` test harness.

**Spec:** `docs/review/2026-08-31/AUDIT-SUMMARY.md` (§一 P0 list), with full evidence in `docs/review/2026-08-31/W12.md` (P0-1), `docs/review/2026-08-31/W17.md` + `W3.md` + `W4.md` (P0-2), `docs/review/2026-08-31/W17.md` (P0-3).

## Global Constraints

- TDD: write the failing test first, watch it fail, then implement (per `docs/CLAUDE.md` Testing section).
- Local gate before considering any task done: `flutter analyze lib test` must report "No issues found!" and `flutter test --exclude-tags golden` must pass for every test file touched or added.
- No hardcoded user-facing strings — reuse the existing `context.l10n.studioImportProject` ARB key for Task 4/5 (already present; no new ARB keys needed for this plan).
- No `--no-verify`, no skipping hooks. Conventional commit messages (`fix:`).
- Every commit must compile clean and pass its own new/updated tests before moving to the next task.
- **Non-goal (explicitly out of scope for this plan):** the deeper race where an *already in-flight* (already fired, awaiting the repository write) debounced autosave can still land its stale patch *after* `submit()`'s own write completes. That requires a write-sequencing/versioning mechanism and is part of the broader "autoDispose vs. async write races" systemic pattern called out in the audit summary §二A — deliberately deferred to a separate, larger plan. This plan only fixes the concretely reproducible bug: a pending (not-yet-fired) debounced write being discarded outright when its owner is disposed.
- **Non-goal:** making autosave failures visible to the user with a retry affordance (`saveConfig`'s `catch (_) {}` stays as-is). That is a UX feature, not a data-loss bug, and is tracked separately in the audit (W17).

---

## File Structure

**Modify:**
- `lib/core/interfaces/orphan_file_reaper.dart` — drop the `dryRun` parameter from the `reap()` contract.
- `lib/services/orphan_file_reaper.dart` — delete the `if (!dryRun)` delete branch and the `_reapFile` method entirely.
- `lib/core/di/orphan_reaper.dart` — update the stale comment referencing `dryRun`.
- `test/services/orphan_file_reaper_test.dart` — update the `_ThrowingReaper` fake's signature to match.
- `lib/features/canvas/providers/inspector_submit_controller.dart` — make the shared prompt-debounce keep its provider alive until the pending write lands.
- `lib/features/canvas/widgets/shot_config_inspector.dart` — flush the local shot-notes debounce on `dispose()`.
- `lib/features/studio/studio_home_screen.dart` — remove the private `_importProject` method; wire the extracted flow into the FAB and the new empty-state button.
- `lib/features/command_palette/command_actions.dart` — add an `importProject` command in the Studio context.
- `test/features/canvas/providers/inspector_submit_controller_test.dart` — add the dispose-flush regression test.
- `test/features/canvas/widgets/shot_config_inspector_test.dart` — add the dispose-flush regression test.
- `test/features/studio/widgets/studio_import_test.dart` — add the empty-state import test.
- `test/features/command_palette/command_palette_test.dart` — add the Studio-context import command test.

**Create:**
- `lib/features/studio/project_import_flow.dart` — the extracted, public `runProjectImportFlow(BuildContext, WidgetRef)`, so both the widget layer and the command palette can call it without a private-member coupling.

---

### Task 1: Remove the real-delete path from `OrphanFileReaper`

**Files:**
- Modify: `lib/core/interfaces/orphan_file_reaper.dart`
- Modify: `lib/services/orphan_file_reaper.dart`
- Modify: `lib/core/di/orphan_reaper.dart`
- Test: `test/services/orphan_file_reaper_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `Future<OrphanReapReport> reap()` (no parameters) on `OrphanFileReaper` / `DiskOrphanFileReaper` — used by `lib/core/di/orphan_reaper.dart:31` (`await reaper.reap();`, already parameterless at the call site, so that line does not need to change).

- [ ] **Step 1: Write the failing test — analyzer-level proof the delete path is gone**

Open `test/services/orphan_file_reaper_test.dart` and update the `_ThrowingReaper` fake at the bottom of the file (currently line 339) so it matches the interface we're about to narrow. This makes the test file fail to *compile* against the current interface only after Step 3 removes the parameter — so first confirm today's baseline compiles, then make this edit, which will fail to compile until Task 1's implementation change lands (that compile failure *is* the "red" step for an interface-narrowing change):

```dart
/// reap() 抛给定异常的 reaper——验证启动兜底吞成 warn（InkError 与非 InkError 皆可）。
class _ThrowingReaper implements OrphanFileReaper {
  _ThrowingReaper(this._error);

  final Object _error;

  @override
  Future<OrphanReapReport> reap() async => throw _error;
}
```

- [ ] **Step 2: Run the test file to verify it fails**

Run: `flutter test test/services/orphan_file_reaper_test.dart`
Expected: FAIL to compile — `The method 'reap' isn't overriding an inherited method with a compatible signature` (or similar), because `lib/core/interfaces/orphan_file_reaper.dart` still declares `reap({bool dryRun = true})`.

- [ ] **Step 3: Narrow the interface**

In `lib/core/interfaces/orphan_file_reaper.dart`, replace the whole file with:

```dart
// OrphanFileReaper 契约：磁盘孤儿媒体文件回收（GC）。
//
// 「孤儿」= projects/*/canvases/*/{images,videos} 下、画布相对路径不在引用集、
// 且 mtime 早于阈值（默认 7 天）的文件。本服务只识别 + 记 orphan.reap.dryrun 日志，
// **没有任何删除实现**——不是"默认关闭的开关"，是这个类里根本不存在删除代码。
// 真正的删除需要独立实现、独立评审，不在本契约里。
abstract class OrphanFileReaper {
  /// 扫描并识别孤儿文件，只记 orphan.reap.dryrun 日志、不删除、不改动磁盘。
  /// 节流：距上次成功回收不足阈值则直接跳过（返回 [OrphanReapReport.skipped]）。
  /// 引用集构建失败（InkError）向上抛——由启动兜底 swallow 成 warn，绝不阻断。
  Future<OrphanReapReport> reap();
}

/// 一次回收的结果快照（供启动日志 / 测试断言）。
///
/// 本服务从不删除文件，故此处不含「已删列表」——只有识别统计。
class OrphanReapReport {
  const OrphanReapReport({
    required this.throttledSkip,
    required this.dryRun,
    required this.orphanCount,
    required this.totalBytes,
  });

  /// 因节流未执行本次扫描。
  const OrphanReapReport.skipped()
      : throttledSkip = true,
        dryRun = true,
        orphanCount = 0,
        totalBytes = 0;

  /// 本次因节流被跳过（未扫描）。
  final bool throttledSkip;

  /// 恒 true——本服务没有删除实现，报告字段保留以标记"这是一次只读扫描"。
  final bool dryRun;

  /// 识别出的孤儿文件数。
  final int orphanCount;

  /// 孤儿文件总字节数。
  final int totalBytes;
}
```

- [ ] **Step 4: Run the test file again to verify the interface-level failure is gone and see the real target**

Run: `flutter test test/services/orphan_file_reaper_test.dart`
Expected: Still FAIL to compile — now `lib/services/orphan_file_reaper.dart`'s `DiskOrphanFileReaper.reap({bool dryRun = true})` no longer matches the (now parameterless) abstract method.

- [ ] **Step 5: Remove the delete branch and `_reapFile` from the implementation**

In `lib/services/orphan_file_reaper.dart`, replace lines 1–12 (the file-level doc comment) with:

```dart
// DiskOrphanFileReaper：OrphanFileReaper 的磁盘实现（LB-13 slice B）。
//
// 只扫 projects/<p>/canvases/<c>/{images,videos}——绝不碰其它任何目录（安全#3）。
// 三重安全：
//   #1 mtime 守卫：只有 mtime 早于 kOrphanMinAge（7d）的文件才可能是孤儿——
//      保护刚写盘、DB 行还在提交中的新文件。
//   #2 引用集含软删节点：NodeRepository.listAllMediaUrls 连 deleted_at IS NOT NULL
//      的节点也算引用——软删可 LB-15 恢复，其产物必须留。
//   #3 目录白名单：只列 images/ 与 videos/，其余一律不扫描、不识别。
//
// 只读：识别到的孤儿只 logger.info('orphan.reap.dryrun', ...)，**这个类里没有任何
// 删除代码**——2026-08-31 审计 P0：曾经的 reap(dryRun:false) 分支是一条真实可达、
// 无恢复机制的删除路径，即便当时没有调用点传 false，也不该让删除实现待在一个号称
// "只读审计"的服务里。真正的删除功能必须是独立评审的另一个实现。
```

Then replace the `reap` method (currently lines 63–122) with:

```dart
  @override
  Future<OrphanReapReport> reap() async {
    final now = _clock.nowUtc();

    // 节流：距上次成功回收不足阈值直接跳过（免得每次启动刷屏）。
    final last = _readLastReap();
    if (last != null && now.difference(last) < kOrphanReapThrottle) {
      return const OrphanReapReport.skipped();
    }

    // 引用集：节点全量 url（含软删）∪ batch_results.output_url。
    // 构建失败必须中止——拿不到引用集就无法安全判孤儿（否则全部文件误判无引用、
    // 触发大规模误报）。此处不 try：InkError 直接上抛给启动兜底 swallow 成 warn。
    final referenceSet = await _buildReferenceSet();

    final candidates = identifyOrphans(referenceSet: referenceSet, now: now);

    var totalBytes = 0;
    for (final c in candidates) {
      totalBytes += c.sizeBytes;
      _logger?.info(
        kOrphanReapModule,
        kOrphanDryRunMsg,
        extra: <String, Object?>{
          'path': c.relativePath,
          'size_bytes': c.sizeBytes,
          'age_days': c.ageDays,
        },
      );
    }

    _logger?.info(
      kOrphanReapModule,
      'orphan.reap.summary',
      extra: <String, Object?>{
        'orphan_count': candidates.length,
        'total_bytes': totalBytes,
        'dry_run': true,
      },
    );

    _writeLastReap(now);

    return OrphanReapReport(
      throttledSkip: false,
      dryRun: true,
      orphanCount: candidates.length,
      totalBytes: totalBytes,
    );
  }
```

Then delete the `_reapFile` method entirely (currently lines 223–237, including its two `coverage:ignore-start`/`coverage:ignore-end` markers and the two comment lines directly above it) — the class ends right after `_writeLastReap`'s closing brace and the `OrphanCandidate` class declaration.

- [ ] **Step 6: Fix the DI comment that references the now-removed parameter**

In `lib/core/di/orphan_reaper.dart`, replace:

```dart
/// 启动首帧后触发一次孤儿回收（DRY-RUN + 节流）。housekeeping：任何失败只 warn，
/// 绝不阻断启动或其它流程。**刻意不传 dryRun**——保持默认 true（本卡绝不删文件）。
```

with:

```dart
/// 启动首帧后触发一次孤儿回收（只读扫描 + 节流）。housekeeping：任何失败只 warn，
/// 绝不阻断启动或其它流程。DiskOrphanFileReaper 里没有删除实现，reap() 恒只读。
```

- [ ] **Step 7: Run the full test file to verify everything passes**

Run: `flutter test test/services/orphan_file_reaper_test.dart`
Expected: PASS — all existing cases (identification, mtime guard, throttle, dry-run logging, reference-set-build failure) still hold, and the interface no longer has a `dryRun` parameter anywhere.

- [ ] **Step 8: Run the full static analysis to catch any other stale reference**

Run: `flutter analyze lib test`
Expected: `No issues found!` — confirms nothing else in the tree still calls `.reap(dryRun: ...)` or references `_reapFile`.

- [ ] **Step 9: Commit**

```bash
git add lib/core/interfaces/orphan_file_reaper.dart lib/services/orphan_file_reaper.dart lib/core/di/orphan_reaper.dart test/services/orphan_file_reaper_test.dart
git commit -m "fix: remove unreachable real-delete path from OrphanFileReaper

The dry-run-only orphan file reaper had a real File.delete() branch
gated only by a default parameter (reap(dryRun:false)). No caller ever
passed false, but the code compiled and existed in a service that
documents itself as never deleting anything. Removed the parameter and
the delete implementation entirely — a read-only audit service should
not contain delete code at all.

Audit: docs/review/2026-08-31/W12.md P0-1"
```

---

### Task 2: Stop `InspectorSubmitController`'s prompt autosave from losing edits on selection change

**Files:**
- Modify: `lib/features/canvas/providers/inspector_submit_controller.dart`
- Test: `test/features/canvas/providers/inspector_submit_controller_test.dart`

**Interfaces:**
- Consumes: `AutoDisposeFamilyNotifier.ref.keepAlive()` (already used by `submit()` in this same file — no new dependency).
- Produces: `InspectorSubmitController.savePromptDebounced(String prompt)` — same public signature as before; callers (`image_config_inspector.dart:158`, `video_config_inspector.dart:117`) do not change.

- [ ] **Step 1: Write the failing test**

In `test/features/canvas/providers/inspector_submit_controller_test.dart`, add this test right after the existing `'savePromptDebounced：窗口内多次输入只落最后一次'` test (before `'saveConfig：立即落盘一次'`):

```dart
  test(
      'savePromptDebounced：切换选中(无监听器)也不能丢掉挂起的写入——回归 2026-08-31 审计 P0',
      () async {
    final container = makeContainer(_FakeGenerationController());
    // 关键：不调用 container.listen(...)。真实 app 里，切换 Inspector 的
    // 选中节点会让旧的 inspectorSubmitControllerProvider(oldId) 失去最后一个
    // watcher；如果防抖挂起期间没有 keepAlive，autoDispose 会在计时器触发前
    // 就把它回收，onDispose 只 cancel 了计时器，编辑内容直接丢失。
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    ctrl.savePromptDebounced('final draft');

    // 让 autoDispose 有机会在防抖窗口内触发（不保活的话，这里就会被回收）。
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(
      InspectorSubmitController.debounceDuration + const Duration(milliseconds: 100),
    );

    expect(
      repo.patches,
      [
        {'prompt': 'final draft'},
      ],
      reason: 'ref.keepAlive() 应挂起 autoDispose 直到挂起的防抖写入完成',
    );
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/canvas/providers/inspector_submit_controller_test.dart --plain-name "切换选中(无监听器)"`
Expected: FAIL — `repo.patches` is empty because the provider was disposed (no listener) before the 500ms timer fired, and `ref.onDispose` cancelled it.

- [ ] **Step 3: Implement the fix**

In `lib/features/canvas/providers/inspector_submit_controller.dart`, replace:

```dart
class InspectorSubmitController
    extends AutoDisposeFamilyNotifier<InspectorSubmitState, String> {
  Timer? _debounce;

  static const debounceDuration = Duration(milliseconds: 500);

  @override
  InspectorSubmitState build(String configNodeId) {
    ref.onDispose(() => _debounce?.cancel());
    return const InspectorSubmitIdle();
  }
```

with:

```dart
class InspectorSubmitController
    extends AutoDisposeFamilyNotifier<InspectorSubmitState, String> {
  Timer? _debounce;
  KeepAliveLink? _debounceKeepAlive;

  static const debounceDuration = Duration(milliseconds: 500);

  @override
  InspectorSubmitState build(String configNodeId) {
    ref.onDispose(_cancelPendingDebounce);
    return const InspectorSubmitIdle();
  }

  /// 取消挂起的防抖计时器并释放其 keepAlive（不落盘）。
  void _cancelPendingDebounce() {
    _debounce?.cancel();
    _debounce = null;
    _debounceKeepAlive?.close();
    _debounceKeepAlive = null;
  }
```

Then replace:

```dart
  /// prompt 防抖保存：连续输入只落最后一次。
  void savePromptDebounced(String prompt) {
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () {
      unawaited(saveConfig(<String, Object?>{'prompt': prompt}));
    });
  }
```

with:

```dart
  /// prompt 防抖保存：连续输入只落最后一次。
  ///
  /// 挂起期间用 [AutoDisposeRef.keepAlive] 挂起本 provider 的 autoDispose——
  /// 否则切换 Inspector 选中的节点会在计时器触发前就把它回收，onDispose 只
  /// cancel 计时器、不落盘，编辑内容直接丢失（2026-08-31 审计 P0）。
  void savePromptDebounced(String prompt) {
    _cancelPendingDebounce();
    _debounceKeepAlive = ref.keepAlive();
    _debounce = Timer(debounceDuration, () {
      final link = _debounceKeepAlive;
      _debounceKeepAlive = null;
      unawaited(
        saveConfig(<String, Object?>{'prompt': prompt})
            .whenComplete(() => link?.close()),
      );
    });
  }
```

Finally, in `submit()`, replace:

```dart
  Future<void> submit(Map<String, Object?> finalConfig) async {
    if (isBusy) return;
    _debounce?.cancel();
```

with:

```dart
  Future<void> submit(Map<String, Object?> finalConfig) async {
    if (isBusy) return;
    // 即将写完整 finalConfig：丢弃挂起的局部 prompt patch，不需要它再补落一次。
    _cancelPendingDebounce();
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/canvas/providers/inspector_submit_controller_test.dart`
Expected: PASS — all existing tests in the file still pass, plus the new regression test.

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/canvas/providers/inspector_submit_controller.dart test/features/canvas/providers/inspector_submit_controller_test.dart
git commit -m "fix: keep pending prompt autosave alive across selection changes

InspectorSubmitController.savePromptDebounced only cancelled its Timer
on dispose instead of flushing it. Since the controller is
autoDispose-family-scoped per node id, switching the Inspector's
selected node disposes the OLD controller as soon as nothing watches
it anymore — which, within the 500ms debounce window, silently
discarded the user's last edit. Fixed by holding a KeepAliveLink for
the duration of the pending write, so the debounce timer still fires
(and its save still lands) even after the widget stops watching.

Audit: docs/review/2026-08-31/W17.md P0, corroborated by W3.md P1 and
W4.md P1 (same root cause, found independently by three windows)."
```

---

### Task 3: Stop `ShotConfigInspector`'s local notes debounce from losing edits on dispose

**Files:**
- Modify: `lib/features/canvas/widgets/shot_config_inspector.dart`
- Test: `test/features/canvas/widgets/shot_config_inspector_test.dart`

**Interfaces:**
- Consumes: `InspectorSubmitController.saveConfig(Map<String, Object?>)` (unchanged signature, already used by this widget).
- Produces: nothing new — this is a private `State` fix, no public API changes.

- [ ] **Step 1: Write the failing test**

In `test/features/canvas/widgets/shot_config_inspector_test.dart`, add this test inside the existing `group('用本镜备注生成图像', () { ... })` block, after the `'输入备注后按钮从禁用变可用'` test and before `'连线失败 → 节点已创建 + 专用连线失败 snackbar'`:

```dart
    testWidgets(
        '输入备注后立即切换选中(dispose)——挂起的防抖写入仍应落盘(回归 2026-08-31 审计 P0)',
        (tester) async {
      final id = await nodeRepo.create(
        canvasId: canvasId,
        type: 'shot',
        nodeRole: 'config',
      );
      final node = CanvasNode(
        id: id,
        label: '',
        type: CanvasNodeType.shot,
        role: NodeRole.config,
        canvasId: canvasId,
        typeConfig: const <String, Object?>{},
      );
      await pump(tester, node);

      await tester.enterText(find.byType(TextField), 'dolly in on face');
      await tester.pump();

      // 切换选中：把 ShotConfigInspector 从树里换掉，在 500ms 防抖窗口内触发
      // 其 State.dispose()——不能只 cancel 计时器，必须先把最后一次输入落盘。
      await pumpInkApp(
        tester,
        const Scaffold(body: SizedBox.shrink()),
        overrides: [
          nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
          edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        ],
      );

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(
        (nodeRepo.rows[id]!['type_config'] as Map<String, Object?>)[
            'shot_notes'],
        'dolly in on face',
      );
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/canvas/widgets/shot_config_inspector_test.dart --plain-name "切换选中(dispose)"`
Expected: FAIL — `nodeRepo.rows[id]!['type_config']` does not contain `'shot_notes'` because `dispose()` cancelled the pending `Timer` without saving.

- [ ] **Step 3: Implement the fix**

In `lib/features/canvas/widgets/shot_config_inspector.dart`, replace:

```dart
  @override
  void dispose() {
    _debounce?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }
```

with:

```dart
  @override
  void dispose() {
    _flushPendingNotes();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// 切换选中会在 500ms 防抖窗口内 dispose 本 State——不能只 cancel 计时器
  /// 了事，得先把最后一次输入落盘，否则打完字立刻切走就把编辑丢了
  /// （2026-08-31 审计 P0，与 InspectorSubmitController.savePromptDebounced
  /// 同一类问题的本地计时器版本）。fire-and-forget，与 saveConfig 本身的
  /// best-effort 语义一致。
  void _flushPendingNotes() {
    if (_debounce == null) return;
    _debounce!.cancel();
    _debounce = null;
    ref
        .read(inspectorSubmitControllerProvider(widget.node.id).notifier)
        .saveConfig(<String, Object?>{'shot_notes': _notesCtrl.text});
  }
```

Then replace:

```dart
  void _onChanged(String value) {
    setState(() {}); // 备注是否为空 → 生成按钮可用性
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref
          .read(inspectorSubmitControllerProvider(widget.node.id).notifier)
          .saveConfig(<String, Object?>{'shot_notes': value});
    });
  }
```

with:

```dart
  void _onChanged(String value) {
    setState(() {}); // 备注是否为空 → 生成按钮可用性
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _debounce = null;
      ref
          .read(inspectorSubmitControllerProvider(widget.node.id).notifier)
          .saveConfig(<String, Object?>{'shot_notes': value});
    });
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/canvas/widgets/shot_config_inspector_test.dart`
Expected: PASS — all existing tests in the file still pass, plus the new regression test.

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/canvas/widgets/shot_config_inspector.dart test/features/canvas/widgets/shot_config_inspector_test.dart
git commit -m "fix: flush pending shot-notes autosave on dispose instead of discarding it

ShotConfigInspector keeps its own local debounce Timer (separate from
InspectorSubmitController's) for the shot_notes field. Its dispose()
only cancelled the timer, so switching the selected canvas node within
the 500ms debounce window silently discarded the last edit. Now
dispose() flushes the current text before cancelling.

Audit: docs/review/2026-08-31/W4.md P1 (independently corroborates the
same root cause as W17.md's P0 finding fixed for the prompt field in
the prior commit)."
```

---

### Task 4: Extract the import flow and add it to Studio's empty state

**Files:**
- Create: `lib/features/studio/project_import_flow.dart`
- Modify: `lib/features/studio/studio_home_screen.dart`
- Test: `test/features/studio/widgets/studio_import_test.dart`

**Interfaces:**
- Produces: `Future<void> runProjectImportFlow(BuildContext context, WidgetRef ref)` in `lib/features/studio/project_import_flow.dart` — this is what Task 5 (command palette) will also call.
- Consumes (unchanged, just relocated): `openFilePickerProvider`, `projectImportServiceProvider`, `projectImportBusyProvider`, `databaseRestoreBusyProvider`, `projectExportBusyProvider`, `selectedProjectIdProvider`, `workspaceProjectsProvider`, `toastServiceProvider`, `loggerProvider` — all already used by the code being moved, from `lib/core/di/project_archive.dart`, `lib/core/di/database_restore.dart`, `lib/core/di/logger.dart`, `lib/features/studio/controllers/studio_state.dart`, `lib/features/studio/providers/project_export_busy.dart`, `lib/features/studio/providers/workspace_projects_provider.dart`, `lib/features/generation/services/toast_service.dart`.

- [ ] **Step 1: Write the failing test**

In `test/features/studio/widgets/studio_import_test.dart`, add this test after the existing `'还原 busy 时导入禁用（三大重操作互斥）'` test, and change the `pump()` helper's `workspaceProjectsProvider` override to accept an empty-list variant for this one test (add a `projects` parameter to `pump` with a default matching today's single-project list, so the existing 4 tests don't change behavior):

Replace the `pump` helper:

```dart
  Future<ProviderContainer> pump(WidgetTester tester,
      {String? pickedPath}) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        workspaceProjectsProvider.overrideWith(
          (_) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              createdAt: DateTime.utc(2026, 5, 1),
              canvases: const <CanvasRef>[],
            ),
          ],
        ),
        openFilePickerProvider.overrideWithValue(() async => pickedPath),
        projectImportServiceProvider.overrideWith((ref) async => service),
        toastServiceProvider.overrideWithValue(toast),
        loggerProvider.overrideWithValue(RecordingLogger()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StudioHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }
```

with:

```dart
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String? pickedPath,
    List<ProjectWithCanvases> projects = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        workspaceProjectsProvider.overrideWith((_) async => projects),
        openFilePickerProvider.overrideWithValue(() async => pickedPath),
        projectImportServiceProvider.overrideWith((ref) async => service),
        toastServiceProvider.overrideWithValue(toast),
        loggerProvider.overrideWithValue(RecordingLogger()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StudioHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }
```

`_oneProject` must be a **top-level** getter, not declared inside `main()` (Dart does not allow local getter/setter declarations inside a function body). Add it at file scope, right after the `_RecordingToast` class and before `void main() {`:

```dart
List<ProjectWithCanvases> get _oneProject => <ProjectWithCanvases>[
      ProjectWithCanvases(
        id: 'p1',
        name: 'Alpha',
        createdAt: DateTime.utc(2026, 5, 1),
        canvases: const <CanvasRef>[],
      ),
    ];
```

Then update each of the 4 existing calls that build a non-empty-Studio scenario, adding `projects: _oneProject` as the last named argument. All 4 are calls to the `pump` helper inside `testWidgets` bodies — find each by its enclosing test name and change exactly as shown:

In `'导入成功：service 收 path、barrier 在途、选中新项目、成功 toast'`, replace:

```dart
    final container = await pump(tester, pickedPath: 'C:/tmp/p.zip');
```

with:

```dart
    final container = await pump(tester, pickedPath: 'C:/tmp/p.zip', projects: _oneProject);
```

In `'picker 取消 → 零调用零 toast'`, replace:

```dart
    await pump(tester, pickedPath: null);
```

with:

```dart
    await pump(tester, pickedPath: null, projects: _oneProject);
```

In `'outcome 文案：failedFormat / failedCorrupt'`, replace:

```dart
    service.outcome = ImportOutcome.failedFormat;
    await pump(tester, pickedPath: 'C:/tmp/p.zip');
```

with:

```dart
    service.outcome = ImportOutcome.failedFormat;
    await pump(tester, pickedPath: 'C:/tmp/p.zip', projects: _oneProject);
```

In `'还原 busy 时导入禁用（三大重操作互斥）'`, replace:

```dart
    final container = await pump(tester, pickedPath: 'C:/tmp/p.zip');
```

with:

```dart
    final container = await pump(tester, pickedPath: 'C:/tmp/p.zip', projects: _oneProject);
```

Now add the new empty-state test at the end of `main()`, before the closing `}`:

```dart
  testWidgets('零项目空态也能看到并使用 Import project（回归 2026-08-31 审计 P0）',
      (tester) async {
    service.gate = Completer<void>();
    final container = await pump(tester, pickedPath: 'C:/tmp/p.zip');

    expect(find.text('Import project…'), findsOneWidget);
    await tester.tap(find.text('Import project…'));
    await tester.pump();
    expect(find.text('Importing…'), findsOneWidget);

    service.gate!.complete();
    await tester.pumpAndSettle();

    expect(service.paths, <String>['C:/tmp/p.zip']);
    expect(toast.shown.single.message, 'Project imported');
    expect(container.read(selectedProjectIdProvider), 'new-proj');
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/studio/widgets/studio_import_test.dart --plain-name "零项目空态"`
Expected: FAIL — `find.text('Import project…')` finds nothing, because the empty state currently only renders New/Sample/Showcase buttons.

- [ ] **Step 3: Create the extracted flow file**

Create `lib/features/studio/project_import_flow.dart`:

```dart
// runProjectImportFlow：LB-12 项目包导入——picker → barrier 模态 → service →
// 成功选中新项目。三大重操作（导入/还原/导出）互斥；依赖首 await 前 read 持有
// （#188 P1-1）。
//
// 抽成公开顶层函数（而非 studio_home_screen.dart 里的私有方法），因为
// 2026-08-31 审计 P0 发现零项目空态和命令面板都够不到这个入口——两处都要能调用
// 同一份逻辑，不能只挂在 FAB 按钮的私有回调里。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/database_restore.dart';
import '../../core/di/logger.dart';
import '../../core/di/project_archive.dart';
import '../../core/interfaces/project_import_service.dart';
import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../generation/services/toast_service.dart';
import 'controllers/studio_state.dart';
import 'providers/project_export_busy.dart';
import 'providers/workspace_projects_provider.dart';

const String _logModule = 'studio.import';

Future<void> runProjectImportFlow(BuildContext context, WidgetRef ref) async {
  final importBusy = ref.read(projectImportBusyProvider.notifier);
  if (importBusy.state ||
      ref.read(databaseRestoreBusyProvider) ||
      ref.read(projectExportBusyProvider)) {
    return;
  }
  final toast = ref.read(toastServiceProvider);
  final logger = ref.read(loggerProvider);
  final picker = ref.read(openFilePickerProvider);
  final serviceFuture = ref.read(projectImportServiceProvider.future);
  final selected = ref.read(selectedProjectIdProvider.notifier);
  final container = ProviderScope.containerOf(context, listen: false);
  final navigator = Navigator.of(context, rootNavigator: true);
  final l10n = context.l10n;
  final progressMsg = l10n.importInProgress;
  final doneMsg = l10n.importDone;
  importBusy.state = true;
  try {
    final String? path;
    try {
      path = await picker();
    } catch (e, st) {
      // 放行点：平台 picker 异常不得静默（#192 评审 P3-5）。
      logger.error(_logModule, 'import picker failed', cause: e, stackTrace: st);
      toast.show(l10n.importFailed, kind: ToastKind.error);
      return;
    }
    if (path == null || !context.mounted) return;

    // barrier 模态罩全程（导入分钟级；LB-22 同款）。
    BuildContext? barrierCtx;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: context.inkColors.scrim,
      builder: (ctx) {
        barrierCtx = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: InkSpacing.md),
                Text(progressMsg),
              ],
            ),
          ),
        );
      },
    ));
    ImportResult result;
    try {
      final service = await serviceFuture;
      result = await service.importArchive(zipPath: path);
    } catch (e, st) {
      // 放行点：service 已收敛所有已知失败——这里兜装配错误，失败必须可见。
      logger.error(_logModule, 'import unexpected', cause: e, stackTrace: st);
      result = const ImportResult(outcome: ImportOutcome.failed);
    } finally {
      final ctx = barrierCtx;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      } else {
        navigator.pop();
      }
    }

    if (result.outcome == ImportOutcome.imported) {
      container.invalidate(workspaceProjectsProvider);
      selected.state = result.newProjectId;
      toast.show(doneMsg, kind: ToastKind.success);
    } else {
      final String msg = switch (result.outcome) {
        ImportOutcome.failedFormat => l10n.importFailedFormat,
        ImportOutcome.failedVersionNewer => l10n.importFailedVersionNewer,
        ImportOutcome.failedCorrupt => l10n.importFailedCorrupt,
        ImportOutcome.failed || ImportOutcome.imported => l10n.importFailed,
      };
      toast.show(msg, kind: ToastKind.error);
    }
  } finally {
    importBusy.state = false;
  }
}
```

- [ ] **Step 4: Wire the FAB to the extracted function and delete the old private method**

In `lib/features/studio/studio_home_screen.dart`, add the import near the other local imports:

```dart
import 'open_canvas.dart';
```

becomes (insert alphabetically among the existing relative imports):

```dart
import 'open_canvas.dart';
import 'project_import_flow.dart';
```

Replace the FAB's `onPressed`:

```dart
                        : () => _importProject(context, ref),
```

with:

```dart
                        : () => runProjectImportFlow(context, ref),
```

Delete the entire `_importProject` method (the block starting at the comment `/// LB-12：项目包导入……` through its closing `}`, immediately before the `/// ON-2：示例项目入口……` comment for `_createSampleProject`) — that logic now lives entirely in `project_import_flow.dart`.

- [ ] **Step 5: Add the import button to the empty state**

In `lib/features/studio/studio_home_screen.dart`, inside `_StudioMainArea.build`, find where `_StudioEmptyState` is constructed:

```dart
                    data: (projects) => projects.isEmpty
                        ? _StudioEmptyState(
                            onCreate: () =>
                                _showNewProjectDialog(context, ref, const []),
                            onCreateSample: () =>
                                _createSampleProject(context, ref),
                            onOpenShowcase: () => ref
                                .read(currentScreenProvider.notifier)
                                .state = AppScreen.showcase,
                          )
                        : _ProjectGrid(projects: projects),
```

Replace it with (adding a computed `importBusy` guard consistent with the FAB's, and a new `onImport` callback):

```dart
                    data: (projects) {
                      final importBusy =
                          ref.watch(projectImportBusyProvider) ||
                              ref.watch(databaseRestoreBusyProvider) ||
                              ref.watch(projectExportBusyProvider);
                      return projects.isEmpty
                          ? _StudioEmptyState(
                              onCreate: () => _showNewProjectDialog(
                                  context, ref, const []),
                              onCreateSample: () =>
                                  _createSampleProject(context, ref),
                              onOpenShowcase: () => ref
                                  .read(currentScreenProvider.notifier)
                                  .state = AppScreen.showcase,
                              onImport: importBusy
                                  ? null
                                  : () => runProjectImportFlow(context, ref),
                            )
                          : _ProjectGrid(projects: projects);
                    },
```

Add the needed import for `projectImportBusyProvider` (it comes from `../../core/di/project_archive.dart`, already imported in this file for the FAB — no new import needed).

- [ ] **Step 6: Add the `onImport` field and button to `_StudioEmptyState`**

Replace:

```dart
class _StudioEmptyState extends StatelessWidget {
  const _StudioEmptyState({
    required this.onCreate,
    required this.onCreateSample,
    required this.onOpenShowcase,
  });

  final VoidCallback onCreate;
  final VoidCallback onCreateSample;
  final VoidCallback onOpenShowcase;
```

with:

```dart
class _StudioEmptyState extends StatelessWidget {
  const _StudioEmptyState({
    required this.onCreate,
    required this.onImport,
    required this.onCreateSample,
    required this.onOpenShowcase,
  });

  final VoidCallback onCreate;
  final VoidCallback? onImport;
  final VoidCallback onCreateSample;
  final VoidCallback onOpenShowcase;
```

Then, in the same widget's `build`, add the import button right after the "New project" button and before "Sample project" — replace:

```dart
              InkAmberButton(
                label: context.l10n.studioNewProject,
                icon: Icons.add,
                onPressed: onCreate,
              ),
              const SizedBox(height: InkSpacing.sm),
              InkGhostButton(
                label: context.l10n.studioCreateSampleProject,
                icon: Icons.auto_awesome_outlined,
                onPressed: onCreateSample,
              ),
```

with:

```dart
              InkAmberButton(
                label: context.l10n.studioNewProject,
                icon: Icons.add,
                onPressed: onCreate,
              ),
              const SizedBox(height: InkSpacing.sm),
              // 2026-08-31 审计 P0：零项目用户手里只有归档文件时，此前完全没有
              // 入口能导入——项目卡 ⋮ 菜单此时不存在，FAB 也只在非空态渲染。
              InkGhostButton(
                label: context.l10n.studioImportProject,
                icon: Icons.unarchive_outlined,
                onPressed: onImport,
              ),
              const SizedBox(height: InkSpacing.sm),
              InkGhostButton(
                label: context.l10n.studioCreateSampleProject,
                icon: Icons.auto_awesome_outlined,
                onPressed: onCreateSample,
              ),
```

Check `InkGhostButton`'s `onPressed` parameter type before this edit — it must already accept `VoidCallback?` (nullable), since the FAB's existing `InkGhostButton` for import is already wired to a nullable callback (`onPressed: ... ? null : () => ...`). No change needed there.

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/features/studio/widgets/studio_import_test.dart`
Expected: PASS — all 5 existing tests (now passing `projects: _oneProject`) plus the new empty-state test.

- [ ] **Step 8: Run the full studio test directory to catch any other test relying on `_StudioEmptyState`'s constructor**

Run: `flutter test test/features/studio`
Expected: PASS. If `test/features/studio/studio_home_test.dart` or any other file constructs `_StudioEmptyState` directly or asserts on the exact button count/order in the empty state, update it to pass `onImport: () {}` (or the appropriate callback) — check with:

Run: `grep -rn "_StudioEmptyState(" test/`

Expected: only the production call site in `lib/features/studio/studio_home_screen.dart` — `_StudioEmptyState` is a private class, so no test can construct it directly; any affected test instead exercises it indirectly through `StudioHomeScreen`, which is why Step 8's full-directory run is the actual verification step, not the grep.

- [ ] **Step 9: Run static analysis**

Run: `flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/features/studio/project_import_flow.dart lib/features/studio/studio_home_screen.dart test/features/studio/widgets/studio_import_test.dart
git commit -m "fix: make Import project reachable from Studio's zero-project empty state

A user whose only InkFrame content is an archive file had no way to
import it: the Import button lived only in the FAB row, which is
hidden entirely when the project list is empty, and the project
card's ⋮ menu (also a possible import surface) doesn't exist yet
either. Extracted the private _importProject flow into a public
runProjectImportFlow() so it can be reused, and wired it into the
empty state's CTA row.

Audit: docs/review/2026-08-31/W17.md P0"
```

---

### Task 5: Add "Import project" to the Studio command-palette context

**Files:**
- Modify: `lib/features/command_palette/command_actions.dart`
- Test: `test/features/command_palette/command_palette_test.dart`

**Interfaces:**
- Consumes: `runProjectImportFlow(BuildContext, WidgetRef)` from `lib/features/studio/project_import_flow.dart` (produced by Task 4).
- Produces: nothing new downstream — this is the last consumer in this plan.

- [ ] **Step 1: Write the failing test**

In `test/features/command_palette/command_palette_test.dart`, add the import:

```dart
import 'package:inkframe/core/di/project_archive.dart';
```

Then add this test after the existing `'studio 上下文只有 Open settings；执行后导航到设置页'` test:

```dart
  testWidgets('studio 上下文能直接执行 Import project（回归 2026-08-31 审计 P0）',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      openFilePickerProvider.overrideWithValue(() async => null),
    ]);
    await _pressCtrlK(tester);

    expect(find.text('Import project…'), findsOneWidget);
    await tester.tap(find.text('Import project…'));
    await tester.pumpAndSettle();

    // picker 返回 null（用户取消）：面板已经关闭，且没有崩溃/挂起。
    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(container.read(projectImportBusyProvider), isFalse);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/command_palette/command_palette_test.dart --plain-name "Import project"`
Expected: FAIL — `find.text('Import project…')` finds nothing, because the Studio context currently only returns `[_openShowcase(l), _openSettings(l)]`.

- [ ] **Step 3: Implement the fix**

In `lib/features/command_palette/command_actions.dart`, add the import:

```dart
import '../studio/project_import_flow.dart';
```

(insert it alphabetically among the existing relative imports, after `import '../gallery/providers/current_gallery_project.dart';`).

Replace the studio-context branch:

```dart
    // studio：内置示例是全局动作,项目卡菜单在零项目空态下不存在——命令面板
    // 与空态 CTA 一起保证零项目用户也够得到（评审 P1-1）。
    AppScreen.studio => <CommandAction>[_openShowcase(l), _openSettings(l)],
```

with:

```dart
    // studio：内置示例是全局动作,项目卡菜单在零项目空态下不存在——命令面板
    // 与空态 CTA 一起保证零项目用户也够得到（评审 P1-1）。2026-08-31 审计 P0：
    // 导入项目此前在这里完全够不到，见 studio/project_import_flow.dart。
    AppScreen.studio => <CommandAction>[
        _importProject(l),
        _openShowcase(l),
        _openSettings(l),
      ],
```

Then add the new action builder near the other `_open*`/`_back*` builders at the bottom of the file (after `_openShowcase`, before `_openSettings`):

```dart
CommandAction _importProject(AppLocalizations l) => CommandAction(
      id: 'importProject',
      icon: Icons.unarchive_outlined,
      label: l.studioImportProject,
      run: (context, ref) => runProjectImportFlow(context, ref),
    );
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/command_palette/command_palette_test.dart`
Expected: PASS — all existing tests still pass (the "studio 上下文只有 Open settings" test only asserts presence of `'Open settings'` and absence of canvas-specific actions, so adding a third Studio action does not break it), plus the new import-command test.

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Run the full local gate**

Run: `flutter analyze lib test && flutter test --exclude-tags golden`
Expected: `No issues found!` and all tests pass — this is the final confirmation that all 5 tasks compose cleanly together.

- [ ] **Step 7: Commit**

```bash
git add lib/features/command_palette/command_actions.dart test/features/command_palette/command_palette_test.dart
git commit -m "fix: add Import project to the Studio command-palette context

Completes the P0 fix for the missing import entry point: a
keyboard-only user (or anyone who doesn't notice the empty-state
button added in the previous commit) can now reach import via Ctrl/Cmd+K
from Studio as well.

Audit: docs/review/2026-08-31/W17.md P0"
```

---

## Self-Review Notes

- **Spec coverage**: all 3 P0 items from `AUDIT-SUMMARY.md` §一 are covered — P0-1 (Task 1), P0-2 (Tasks 2+3, split because the two debounce mechanisms are independent code paths in different files), P0-3 (Tasks 4+5, split because the empty-state CTA and the command-palette action are independently testable surfaces that both depend on the same extracted function).
- **Type consistency checked**: `runProjectImportFlow(BuildContext, WidgetRef)` signature matches `CommandAction.run`'s `Future<void> Function(BuildContext, WidgetRef)` exactly, and matches the `VoidCallback`-wrapping closures used at both FAB and empty-state call sites (`() => runProjectImportFlow(context, ref)`). `_StudioEmptyState.onImport` is `VoidCallback?` (nullable) to support the busy-disable pattern already used by the FAB's equivalent button.
- **No placeholders**: every step has literal, complete code — no "add appropriate handling" language.
