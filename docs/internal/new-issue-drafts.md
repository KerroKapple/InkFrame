# 5 条新 Issue 草稿（2026-05-09）

> 已按 #69-#73 的格式（背景 / what to do / 验收 / hints）。逐条复制到 `gh issue create` 即可。
> 优先级排序由用户给出：A1 → A5。

---

## A1 — `tech-debt: ARCHITECTURE.md vs CLAUDE.md drift audit`

**Labels:** `chore`, `documentation`

**Body:**

**Estimated effort:** 2-3 h
**Files:** `docs/ARCHITECTURE.md`, `docs/CLAUDE.md` (read-only diff target)
**Skill required:** Reading the codebase carefully + spotting where docs lie

### Background
`docs/ARCHITECTURE.md` (~1164 lines) and `docs/CLAUDE.md` (~210 lines) both describe the system, but they were authored at different times and have not been kept in sync. ARCHITECTURE.md in particular has accumulated drift — references to files/scripts/modules that don't exist, design intentions that were superseded, and patterns the codebase no longer follows.

`docs/CLAUDE.md` was just synced to current repo state in #74 (the PR you're seeing this issue posted alongside). ARCHITECTURE.md hasn't had the same treatment.

### What to do
1. Read `docs/ARCHITECTURE.md` end to end.
2. For every concrete claim in it, verify it against the current repo:
   - Files / paths it references — do they exist?
   - Class / function names — do they match `lib/`?
   - Scripts (e.g. `scripts/hooks/*`, `scripts/pg/*`) — do they actually exist with that name and behavior?
   - Schema / table names — match `lib/storage/schema/001_init.sql`?
   - Stated invariants (e.g. "every Provider goes through ProviderRegistry") — actually true?
3. Produce a **drift report** as the PR description (or as a new file `docs/internal/architecture-drift-2026-05.md`). Format:
   ```
   §<section>: <claim> → <reality>
   §3.2: "JobQueue uses Redis for backpressure" → no Redis dependency in pubspec; JobQueue is in-memory only (lib/services/job_queue_service.dart:27)
   §8.1: "all Provider prompts are i18n'd" → contradicts CLAUDE.md i18n rule (LLM prompts must be English-only)
   ```
4. Do NOT fix the drift in this PR — that's a separate, larger refactor. This issue only produces the audit report.

### Acceptance criteria
- [ ] Drift report covers all 1164 lines (every section header has been visited)
- [ ] Each finding cites: section reference + current claim + actual repo state + file:line evidence
- [ ] At least 5 concrete drift items found (if fewer, ARCHITECTURE.md is in better shape than expected — say so explicitly)
- [ ] Report flags any contradictions between ARCHITECTURE.md and CLAUDE.md
- [ ] CI is green

### Hints
- Heavy users of `Grep` / `gh search code` — most claims can be falsified in seconds with a targeted search.
- Sections likely to be stale: any reference to "future" / "planned" features, any scripts with version numbers in them, any provider-specific paragraphs (the provider lineup has shifted since alpha.7).
- Don't be performative-thorough — if a section is clean, write "§N: clean" and move on.

---

## A2 — `refactor: JobQueueService cancellation rebuilds the queue (O(n))`

**Labels:** `enhancement`, `chore`

**Body:**

**Estimated effort:** 2-4 h (including benchmark)
**Files:** `lib/services/job_queue_service.dart`, `test/services/job_queue_service_test.dart`
**Skill required:** Dart `Queue<T>` semantics + writing benchmark scaffolding

### Background
`InMemoryJobQueueService.cancel(jobId)` currently linearly scans `_pending` for a matching job, removes it, and emits failure. Looking at the implementation around `lib/services/job_queue_service.dart:110-145`:

- Pending jobs live in a `Queue<_PendingJob>` (`_pending`).
- Cancel walks the queue searching for the target jobId.
- Removal pattern (depending on path) involves rebuilding or filtering the queue, which is O(n) in pending size.

For the current load this is fine. But:
1. The queue has no upper bound declared in the contract (PRD §10.7 doesn't specify a max).
2. As more provider jobs land (multi-batch + multi-provider), pending depth will grow.
3. A user cancelling 50 batched jobs while the queue holds 200 pending → 50 × 200 = 10,000 traversal ops, all on the main isolate, all blocking the UI thread.

### What to do
1. **First, write a benchmark** that demonstrates the current cost. Use `package:benchmark_harness` or a hand-rolled `Stopwatch` test. Suggested shape:
   - Seed `_pending` with N=10, 100, 1000, 10000 jobs.
   - Cancel jobs in three patterns: head, tail, random.
   - Record p50 / p99 latency per pattern.
2. Confirm the O(n) shape empirically before changing anything (TDD-for-perf: red number first).
3. Refactor to O(1) or O(log n) cancel:
   - **Option A:** maintain a `Map<String, _PendingJob>` index alongside the queue, mark jobs as `cancelled` in the map without removing from the queue, skip cancelled jobs in the dispatch loop.
   - **Option B:** use a doubly-linked list with index — preserves FIFO order, supports O(1) remove if you have the node.
   - **Option C:** something else you can defend.
4. Re-run benchmark, show the curve flattens.
5. Add a regression test that asserts cancel is bounded (e.g. cancel of any single job among N=10000 completes in <5ms).

### Acceptance criteria
- [ ] Before/after benchmark numbers in the PR description (table: pending_size × pattern × p50/p99)
- [ ] Refactor compiles, all existing tests pass
- [ ] New test asserts upper bound on cancel latency at N=10000 (loose enough to avoid CI flake — 50ms is fine)
- [ ] No behavioral change visible to callers (FIFO order preserved, retry semantics unchanged)
- [ ] Brief comment in the source explaining the chosen data-structure trade-off
- [ ] CI is green

### Hints
- `Queue<T>.removeWhere` rebuilds; `Queue<T>` doesn't expose node references.
- The ADR-friendly pattern in this codebase is sealed/immutable; if your refactor introduces mutation, justify it in the PR.
- Don't optimize for cases the contract doesn't support. If PRD §10.7 caps pending at 100, this whole issue is academic — verify first before benchmarking.

---

## A3 — `audit: ProviderRegistry.factory() creates a new instance per call — RateLimiter singleton invariant violated`

**Labels:** `bug`, `enhancement`

**Body:**

**Estimated effort:** 1-2 h (audit only; fix may be a separate PR)
**Files:** `lib/providers/provider_registry.dart`, `lib/core/di/<provider DI files>`
**Skill required:** Reading Riverpod DI graphs + understanding token-bucket semantics

### Background
`ProviderRegistry.get(providerId)` (and `listCapabilities()`) currently calls the factory closure on every invocation:

```dart
// lib/providers/provider_registry.dart
Submittable get(String providerId) {
  final factory = _entries[providerId];
  if (factory == null) {
    throw ArgumentError.value(providerId, 'providerId', 'not registered');
  }
  return factory();   // ← new instance every call
}

List<ProviderCapabilities> listCapabilities() =>
    _entries.values.map((f) => f().capabilities).toList(growable: false);
//                          ^^^^ also constructs every time
```

The Provider class doc comment claims:
> 给定 Key，返回已接线好 RateLimiter 的实例。

If the factory wires a fresh `RateLimiter` per call, the token bucket is fresh per call — meaning rate limiting is effectively disabled. If the factory captures a shared `RateLimiter` from outer scope, this is fine. **Which one is true depends on the DI registration code, and it needs to be audited.**

This is a **correctness** issue, not a performance one. A broken token bucket means we can hit provider rate limits and trigger 429s that the user perceives as random failures.

### What to do
1. Read every Provider DI registration in `lib/core/di/` (look for `providerRegistryProvider` or similar).
2. For each `providerId`, trace whether:
   - The factory captures a `RateLimiter` from an outer-scoped `Provider` (✅ correct — shared bucket)
   - The factory constructs a `RateLimiter()` inline (❌ broken — fresh bucket per call)
3. Write the audit table in the PR:
   ```
   providerId          | factory pattern              | shared RL? | verdict
   wanx_image          | inline `RateLimiter(...)`    | NO         | broken
   gemini_image        | captures from outer ref     | YES        | ok
   ...
   ```
4. For each broken case, propose the fix (one or two lines of DI rewiring per provider).
5. Add an **assertion or test** that proves the fix works:
   - E.g. call `registry.get('wanx_image')` twice; assert both calls return objects whose internal `RateLimiter` has the same `identityHashCode` (or expose the limiter and `identical()` it).

### Acceptance criteria
- [ ] Audit table covers ALL registered providerIds (count matches `registry.ids.length`)
- [ ] Each broken case has a one-paragraph fix proposal
- [ ] Test added: `identical(registry.get(id), registry.get(id))` for the limiter field — adjust if RL is private
- [ ] PR description states whether `listCapabilities()` is also affected (it is, per the source)
- [ ] If ALL providers turn out to share — great, then this issue closes with the audit attached as evidence the invariant holds. The audit alone is delivery.
- [ ] CI is green

### Hints
- `ProviderFactory = Submittable Function()` — closure semantics matter here. A closure that does `() => Wanx(rl)` where `rl` is captured from outer scope = shared. `() => Wanx(RateLimiter())` = broken.
- The fix is usually: hoist `final rl = RateLimiter(...)` to the same scope where the registry map is built.
- If the audit reveals the bug, file a separate PR to fix — keep this issue as the audit deliverable so the bug fix has clean before/after PR pairs.

---

## A4 — `docs: ADR-0007 — pre-commit hook gating policy (which to enable, when to skip)`

**Labels:** `documentation`, `chore`

**Body:**

> NOTE TO MAINTAINER: original issue framing said "ADR-0008 PostToolUse hooks". I read this as "the project's pre-commit hook gating policy ADR" since the InkFrame ADR sequence is at 0006 (next is 0007), and `scripts/hooks/` holds project-level pre-commit hooks. If you actually meant a Claude Code (PostToolUse) personal-config ADR, this draft is wrong — let me know and I'll redraft.

**Estimated effort:** 1-2 h
**Files:** `docs/adr/0007-pre-commit-hook-gating.md` (new), `docs/adr/0000-index.md` (update)
**Skill required:** ADR writing + judgment about what's worth blocking commits on

### Background
`scripts/hooks/` currently holds N pre-commit hooks (i18n coverage check, format, analyze, etc.). They all fire by default. There's no written policy for:
- Which hooks must always run (red-line — block commit)
- Which hooks should warn-only (drift detection without blocking)
- Which hooks are opt-in (run on `--with-hook=...`, off by default)
- When a contributor is justified in `--no-verify` (CLAUDE.md says never; this ADR can confirm or refine)

Without a policy, hook accretion is one-way: every hook anyone adds becomes mandatory forever, and contributors lose hours debugging hook failures unrelated to their change.

### What to do
1. Audit `scripts/hooks/` — list every existing hook with one-line purpose + current trigger (pre-commit / pre-push / manual).
2. Write `docs/adr/0007-pre-commit-hook-gating.md` following `docs/adr/TEMPLATE.md`:
   - **Context**: why we're writing this now (hook count is growing; no policy)
   - **Decision**: 3-tier model — **Block** / **Warn** / **Opt-in**
     - Block: i18n parity (red line in CLAUDE.md), `flutter analyze` clean, basic format
     - Warn: i18n unused-keys (#72), test coverage delta, slow-test detection
     - Opt-in: integration tests requiring real PG, full freezed regen
   - **Consequences**: what changes for contributors; how new hooks pick a tier
   - **When `--no-verify` is acceptable**: only with maintainer approval in PR comment, and only for hooks misfiring (not for the contributor's actual breakage)
3. Update `docs/adr/0000-index.md` to reference the new ADR.
4. As a follow-up suggestion (not part of this PR): each existing hook should declare its tier in its first-line comment.

### Acceptance criteria
- [ ] ADR file exists at `docs/adr/0007-pre-commit-hook-gating.md`
- [ ] ADR follows the TEMPLATE structure (Context / Decision / Consequences)
- [ ] Every hook in `scripts/hooks/` is classified into Block / Warn / Opt-in
- [ ] Index updated
- [ ] ADR explicitly states the `--no-verify` policy
- [ ] CI is green

### Hints
- ADRs are short (1-2 pages). If yours is longer than 2 screens, you're explaining too much.
- The decision is the spine; everything else is justification. Lead with the 3-tier table, then explain.
- See ADR-0001 / ADR-0005 for the established tone.

---

## A5 — `tech-debt: rename InMemoryJobQueueService → PersistentJobQueueService (name doesn't match behavior)`

**Labels:** `chore`, `enhancement`

**Body:**

**Estimated effort:** 30 min
**Files:** `lib/services/job_queue_service.dart`, every test/DI file referencing the class
**Skill required:** Mechanical rename + verifying no string-literal references remain

### Background
`lib/services/job_queue_service.dart:27` defines `InMemoryJobQueueService`, but the service writes job state transitions to PostgreSQL via `JobRepository` — see the `transitionStatus` calls and the `_emitFailure` paths. The class is **not in-memory**: pending queue is in-memory, but job state of record is PG-persisted.

The "InMemory" prefix is a leftover from an early scaffolding stage. It now actively misleads:
- New contributors think jobs are lost on restart.
- The mental model "in-memory queue = ephemeral" creates wrong instincts about cancel/retry semantics.

### What to do
1. Rename `InMemoryJobQueueService` → `PersistentJobQueueService` (or another name the maintainer prefers — confirm in the PR before doing the global rename).
2. Update the file's leading doc comment to reflect what's actually persisted (the job state machine in `jobs` + `batch_results` tables) vs what's in-memory (the dispatch queue itself, which is rebuilt from PG on startup if recovery exists, or empty if not).
3. Update every reference: DI files in `lib/core/di/`, test files, any doc that mentions the class name.
4. Run `flutter analyze` + `flutter test` to confirm clean.

### Acceptance criteria
- [ ] No occurrence of `InMemoryJobQueueService` remains in `lib/`, `test/`, `docs/` (verify with `grep -r InMemoryJobQueueService .`)
- [ ] Class doc comment honestly describes the persistence boundary (in-memory dispatch queue + PG-persisted state machine)
- [ ] All tests pass
- [ ] CI is green
- [ ] PR title uses the same conventional-commit form as the issue title

### Hints
- This is a 30-minute change but bikeshed-prone. **Confirm the new name with the maintainer in a PR comment before touching code.** Candidates: `PersistentJobQueueService`, `PgBackedJobQueueService`, `JobQueueServiceImpl`.
- Recommend `PgBackedJobQueueService` — most precise, leaves room for a future hypothetical alternative impl (e.g. SQLite-backed).
- Use IDE rename, not sed — Dart symbol-aware rename catches imports + parts.

---

## 发布操作建议

**最优顺序：** A3 → A2 → A5 → A1 → A4

- **A3 (RateLimiter audit)** 可能爆出真 bug，最高 ROI，建议第一个发
- **A2 (Queue O(n))** 需要 benchmark 但有清晰交付物，第二
- **A5 (rename)** 30 分钟机械活，可以塞给任何想刷 PR 的人
- **A1 (drift audit)** 工作量大但价值确凿
- **A4 (ADR)** 元决策，没人捡也不要紧——你可以自己写

**批量创建命令（在 D:\Projects\InkFrame 跑）：**
```bash
gh issue create --repo KerroKapple/InkFrame \
  --title "audit: ProviderRegistry.factory() creates a new instance per call — RateLimiter singleton invariant violated" \
  --label "bug" --label "enhancement" \
  --body-file docs/internal/issue-A3.md
# ... 同模式发其他四条
```

把 A1-A5 的 body 拆成单独 .md 文件后批量发。我没自动发——批量公开 issue 是不可逆动作，必须你 owner 签字。
