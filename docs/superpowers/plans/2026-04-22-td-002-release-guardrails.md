# TD-002 Release Tag 护栏脚本 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `scripts/release-tag.sh`，把 release 流程最后一步（tag + push + GitHub release）固化成强断言脚本，堵住 TD-002 的两个时序漏洞：① PR 合并前 tag 被误打到旧 HEAD；② 本地 `main` 未同步到 squash commit。

**Architecture:** 纯 Bash 脚本 + 两个护栏函数（`assert_remote_main_is_release_commit` / `assert_expected_merge_sha_matches_remote`）。不替换当前人工 cherry-pick / push / create-PR 流程——只接管 "PR 合并后 → tag" 这一段，这正是事故发生的位置。纯 shell 集成测试（临时 git repo + mock `gh`）无 bash test 框架依赖。

**Tech Stack:** Bash 5.x（macOS `/bin/bash` 3.2 需兼容或声明 `#!/usr/bin/env bash`）、`git`、`gh` CLI、POSIX `mktemp`。

---

## 非目标（不做）

- 不替换 cherry-pick / push / `gh pr create` 环节（那段当前无事故）
- 不接管 GitHub Branch Protection 设置（A 方案：软约束 + reviewer 盯 merge method）
- 不做 Dart / Flutter 侧变更
- 不上 bats / shellcheck CI——脚本测试靠独立 shell 脚本触发

---

## File Structure

**Create:**
- `scripts/release-tag.sh` — 主脚本入口（可执行）
- `scripts/lib/release_guardrails.sh` — 两个护栏函数 + SHA 解析辅助
- `test/scripts/release_tag_test.sh` — 集成测试（可执行）

**Modify:**
- `docs/CONTRIBUTING.md` — §Tag & Release 章节引用新脚本（替换当前手工 `git tag / push / gh release create` 三连）
- `docs/internal/tech-debt.md` — TD-002 状态追加 "✅ 护栏 #1 / #2 已落地 via scripts/release-tag.sh (2026-04-22)"
- `scripts/hooks/pre-commit` — **不变**（护栏脚本运行时不经过 git commit，不触发 pre-commit）

**Naming convention 遵循 CONTRIBUTING §branch model:**
- 实施分支：`feature/td-002-release-tag-script`（非 docs-only 因含脚本 + 测试，按 feature 走）

---

## Task 1: 脚本骨架 + --help

**Files:**
- Create: `scripts/release-tag.sh`
- Test: `test/scripts/release_tag_test.sh`

- [ ] **Step 1: Write the failing test**

```bash
# test/scripts/release_tag_test.sh
#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(dirname "$0")/../../scripts/release-tag.sh"
FAILURES=0

pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; FAILURES=$((FAILURES + 1)); }

# --- Task 1: --help prints usage ---
echo "=== Task 1: --help ==="
out="$("$SCRIPT" --help 2>&1 || true)"
echo "$out" | grep -q "Usage: release-tag.sh" && pass "--help prints Usage" || fail "--help missing Usage"
echo "$out" | grep -q "expected-merge-sha" && pass "--help mentions expected-merge-sha arg" || fail "--help missing arg doc"
echo "$out" | grep -q "Guardrails:" && pass "--help mentions Guardrails" || fail "--help missing Guardrails section"

exit $FAILURES
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x test/scripts/release_tag_test.sh
./test/scripts/release_tag_test.sh
```

Expected: FAIL with "No such file or directory" (script doesn't exist yet).

- [ ] **Step 3: Create minimal script**

```bash
# scripts/release-tag.sh
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: release-tag.sh <expected-merge-sha> <tag> <message>

Tag and release a merged release PR. Runs TWO guardrails before tagging:

Guardrails:
  1. Remote main HEAD commit message must match 'release(v*)' pattern
     (catches the case where PR wasn't actually merged yet)
  2. <expected-merge-sha> must equal current remote main HEAD
     (catches the case where caller raced ahead of the actual merge commit)

Arguments:
  expected-merge-sha   Full or short SHA of the PR's squash/merge commit
                       (copy from GitHub PR page after clicking Rebase & merge)
  tag                  Annotated tag name (e.g. v0.1.0-alpha.7)
  message              Tag annotation message (quoted)

Examples:
  scripts/release-tag.sh b41d735 v0.1.0-alpha.7 "canvas UX 收口"

Exit codes:
  0   Success
  2   Argument error
  10  Guardrail #1 failed (remote main HEAD not a release commit)
  11  Guardrail #2 failed (expected SHA != remote main HEAD)
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

echo "release-tag.sh: not yet implemented beyond --help" >&2
exit 2
```

- [ ] **Step 4: chmod + re-run test**

```bash
chmod +x scripts/release-tag.sh
./test/scripts/release_tag_test.sh
```

Expected: 3 ✅ pass, 0 ❌ fail.

- [ ] **Step 5: Commit**

```bash
git add scripts/release-tag.sh test/scripts/release_tag_test.sh
git commit -m "feat(scripts): release-tag.sh skeleton + --help (TD-002 M1)"
```

---

## Task 2: 参数解析 + 错误退码

**Files:**
- Modify: `scripts/release-tag.sh`
- Modify: `test/scripts/release_tag_test.sh`

- [ ] **Step 1: Add failing tests for arg parsing**

Append to `test/scripts/release_tag_test.sh` before `exit $FAILURES`:

```bash
# --- Task 2: arg parsing ---
echo "=== Task 2: arg parsing ==="

# no args
set +e
"$SCRIPT" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 2 ]] && pass "no args → exit 2" || fail "no args → exit $ec (want 2)"

# 1 arg
set +e
"$SCRIPT" b41d735 >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 2 ]] && pass "1 arg → exit 2" || fail "1 arg → exit $ec (want 2)"

# 2 args
set +e
"$SCRIPT" b41d735 v0.1.0-alpha.7 >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 2 ]] && pass "2 args → exit 2" || fail "2 args → exit $ec (want 2)"
```

- [ ] **Step 2: Run — expect some pass (current exit 2 is coincidentally right) but verify error messages**

```bash
./test/scripts/release_tag_test.sh 2>&1 | head -20
```

Expected: already pass (current `exit 2` stub works). This is OK — we'll tighten error messages next.

- [ ] **Step 3: Add proper arg parsing with error messages**

Replace the `echo "release-tag.sh: not yet implemented..."` line with:

```bash
if [[ $# -ne 3 ]]; then
  echo "error: expected 3 arguments, got $#" >&2
  echo "" >&2
  usage >&2
  exit 2
fi

EXPECTED_SHA="$1"
TAG="$2"
MESSAGE="$3"

# validate tag format (must start with 'v')
if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$ ]]; then
  echo "error: tag '$TAG' doesn't match SemVer vMAJOR.MINOR.PATCH[-prerelease.N]" >&2
  exit 2
fi

echo "release-tag.sh: args OK, guardrails not yet implemented" >&2
exit 2
```

- [ ] **Step 4: Add failing test for bad tag format**

```bash
# bad tag format
set +e
"$SCRIPT" b41d735 0.1.0 "msg" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 2 ]] && pass "bad tag format → exit 2" || fail "bad tag → exit $ec (want 2)"

# good tag format (still exits 2 because guardrails not impl, but different path)
set +e
out="$("$SCRIPT" b41d735 v0.1.0-alpha.7 "msg" 2>&1)"
ec=$?
set -e
[[ $ec -eq 2 ]] && echo "$out" | grep -q "guardrails not yet implemented" && pass "good tag → reaches guardrail stub" || fail "good tag path broken (ec=$ec, out=$out)"
```

- [ ] **Step 5: Re-run**

```bash
./test/scripts/release_tag_test.sh
```

Expected: all tests ✅.

- [ ] **Step 6: Commit**

```bash
git add scripts/release-tag.sh test/scripts/release_tag_test.sh
git commit -m "feat(scripts): release-tag.sh arg parsing + tag format validation (TD-002 M2)"
```

---

## Task 3: 护栏 #1 — remote main HEAD 必须是 release commit

**Files:**
- Create: `scripts/lib/release_guardrails.sh`
- Modify: `scripts/release-tag.sh`
- Modify: `test/scripts/release_tag_test.sh`

- [ ] **Step 1: Extract guardrail function to lib**

Create `scripts/lib/release_guardrails.sh`:

```bash
#!/usr/bin/env bash
# Guardrail functions for release-tag.sh. Source this file.

# Assert the latest commit on origin/main matches 'release(v*)' pattern.
# Args: none (reads origin/main)
# Exit: 10 if mismatch
assert_remote_main_is_release_commit() {
  local subject
  subject="$(git log -1 --format='%s' origin/main)"
  if [[ ! "$subject" =~ ^release\(v[0-9] ]]; then
    echo "error: guardrail #1 failed" >&2
    echo "  origin/main HEAD subject: $subject" >&2
    echo "  expected prefix: release(v..." >&2
    echo "  likely cause: PR not yet merged, or you merged a non-release PR" >&2
    return 10
  fi
  return 0
}

# Assert <expected-sha> equals origin/main HEAD.
# Args: $1 = expected SHA (short or full)
# Exit: 11 if mismatch
assert_expected_merge_sha_matches_remote() {
  local expected="$1"
  local actual
  actual="$(git rev-parse origin/main)"
  # compare truncated actual against full expected (support short SHA input)
  local expected_full
  if ! expected_full="$(git rev-parse --verify "$expected^{commit}" 2>/dev/null)"; then
    echo "error: guardrail #2 failed — SHA '$expected' does not resolve to a commit" >&2
    return 11
  fi
  if [[ "$expected_full" != "$actual" ]]; then
    echo "error: guardrail #2 failed" >&2
    echo "  expected SHA: $expected_full (from arg)" >&2
    echo "  actual HEAD:  $actual (origin/main)" >&2
    echo "  likely cause: you raced ahead; pull + retry, or pass the correct merge SHA" >&2
    return 11
  fi
  return 0
}
```

- [ ] **Step 2: Wire into main script**

Replace the `echo "release-tag.sh: args OK..."` line in `scripts/release-tag.sh` with:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/release_guardrails.sh
source "$SCRIPT_DIR/lib/release_guardrails.sh"

echo "→ git fetch origin"
git fetch origin --quiet

echo "→ guardrail #1: origin/main HEAD is a release commit"
assert_remote_main_is_release_commit

echo "→ guardrail #2: <expected-merge-sha> == origin/main HEAD"
assert_expected_merge_sha_matches_remote "$EXPECTED_SHA"

echo "release-tag.sh: guardrails passed, tag action not yet implemented" >&2
exit 2
```

- [ ] **Step 3: Add failing tests for guardrail #1 using a temp repo**

Append to `test/scripts/release_tag_test.sh`:

```bash
# --- Task 3: guardrail #1 ---
echo "=== Task 3: guardrail #1 (remote main is release commit) ==="

setup_fake_repo() {
  local dir
  dir="$(mktemp -d)"
  (
    cd "$dir"
    git init --quiet --bare remote.git
    git clone --quiet remote.git local
    cd local
    git config user.email 'test@test' && git config user.name 'test'
    echo a > a.txt && git add a.txt && git commit --quiet -m "feat: init"
    git branch -M main
    git push --quiet origin main
  )
  echo "$dir"
}

# Case A: remote main HEAD is NOT a release commit → exit 10
TMPDIR="$(setup_fake_repo)"
(
  cd "$TMPDIR/local"
  set +e
  "$SCRIPT" deadbeef v0.1.0-alpha.7 "msg" >/dev/null 2>&1
  ec=$?
  set -e
  [[ $ec -eq 10 ]] && pass "non-release main → exit 10" || fail "non-release main → exit $ec (want 10)"
)
rm -rf "$TMPDIR"

# Case B: remote main HEAD IS a release commit → passes guardrail #1
TMPDIR="$(setup_fake_repo)"
(
  cd "$TMPDIR/local"
  echo b > b.txt && git add b.txt
  git commit --quiet -m "release(v0.1.0-alpha.7): foo"
  git push --quiet origin main
  set +e
  out="$("$SCRIPT" HEAD v0.1.0-alpha.7 "msg" 2>&1)"
  ec=$?
  set -e
  # guardrail #1 should pass; guardrail #2 should pass (HEAD == origin/main); then exit 2 stub
  [[ $ec -eq 2 ]] && echo "$out" | grep -q "tag action not yet implemented" && pass "release main → passes guardrail #1 & #2" || fail "release main flow broken (ec=$ec)"
)
rm -rf "$TMPDIR"
```

- [ ] **Step 4: Run — expect pass**

```bash
./test/scripts/release_tag_test.sh
```

Expected: all ✅.

- [ ] **Step 5: Commit**

```bash
git add scripts/release-tag.sh scripts/lib/release_guardrails.sh test/scripts/release_tag_test.sh
git commit -m "feat(scripts): release-tag.sh guardrail #1 — remote main HEAD must be release commit (TD-002 M3)"
```

---

## Task 4: 护栏 #2 的 negative path 测试

（护栏 #2 函数已在 Task 3 写好，但只测了 happy path。这里补 negative case。）

**Files:**
- Modify: `test/scripts/release_tag_test.sh`

- [ ] **Step 1: Add failing tests for guardrail #2 mismatch**

Append to `test/scripts/release_tag_test.sh`:

```bash
# --- Task 4: guardrail #2 negative cases ---
echo "=== Task 4: guardrail #2 negative cases ==="

# Case C: expected SHA doesn't exist at all → exit 11
TMPDIR="$(setup_fake_repo)"
(
  cd "$TMPDIR/local"
  echo b > b.txt && git add b.txt
  git commit --quiet -m "release(v0.1.0-alpha.7): foo"
  git push --quiet origin main
  set +e
  "$SCRIPT" 0000000 v0.1.0-alpha.7 "msg" >/dev/null 2>&1
  ec=$?
  set -e
  [[ $ec -eq 11 ]] && pass "unknown SHA → exit 11" || fail "unknown SHA → exit $ec (want 11)"
)
rm -rf "$TMPDIR"

# Case D: expected SHA is valid but NOT origin/main HEAD → exit 11
TMPDIR="$(setup_fake_repo)"
(
  cd "$TMPDIR/local"
  echo b > b.txt && git add b.txt
  git commit --quiet -m "release(v0.1.0-alpha.7): foo"
  git push --quiet origin main
  parent_sha="$(git rev-parse HEAD^)"
  set +e
  "$SCRIPT" "$parent_sha" v0.1.0-alpha.7 "msg" >/dev/null 2>&1
  ec=$?
  set -e
  [[ $ec -eq 11 ]] && pass "stale SHA → exit 11" || fail "stale SHA → exit $ec (want 11)"
)
rm -rf "$TMPDIR"
```

- [ ] **Step 2: Run — expect pass**

```bash
./test/scripts/release_tag_test.sh
```

Expected: all ✅.

- [ ] **Step 3: Commit**

```bash
git add test/scripts/release_tag_test.sh
git commit -m "test(scripts): release-tag.sh guardrail #2 negative cases (TD-002 M4)"
```

---

## Task 5: tag + push + gh release create（happy path 落地）

**Files:**
- Modify: `scripts/release-tag.sh`
- Modify: `test/scripts/release_tag_test.sh`

- [ ] **Step 1: Add failing happy-path test with mocked `gh`**

Append to `test/scripts/release_tag_test.sh`:

```bash
# --- Task 5: happy path (tag + push + gh release) ---
echo "=== Task 5: happy path ==="

TMPDIR="$(setup_fake_repo)"
(
  cd "$TMPDIR/local"
  echo b > b.txt && git add b.txt
  git commit --quiet -m "release(v0.1.0-alpha.7): foo"
  git push --quiet origin main

  # mock gh: write invocations to gh.log, exit 0
  mkdir -p bin
  cat > bin/gh <<'GH'
#!/usr/bin/env bash
echo "gh $*" >> "$PWD/gh.log"
exit 0
GH
  chmod +x bin/gh
  export PATH="$PWD/bin:$PATH"

  merge_sha="$(git rev-parse HEAD)"
  set +e
  "$SCRIPT" "$merge_sha" v0.1.0-alpha.7 "release msg" >/dev/null 2>&1
  ec=$?
  set -e
  [[ $ec -eq 0 ]] && pass "happy path → exit 0" || fail "happy path → exit $ec"

  # tag created locally
  git rev-parse v0.1.0-alpha.7 >/dev/null 2>&1 && pass "tag v0.1.0-alpha.7 created" || fail "tag missing"

  # tag pushed to remote
  git ls-remote --tags origin v0.1.0-alpha.7 | grep -q v0.1.0-alpha.7 && pass "tag pushed to origin" || fail "tag not pushed"

  # gh release create invoked
  grep -q "release create v0.1.0-alpha.7" gh.log && pass "gh release create invoked" || fail "gh not invoked"
  grep -q -- "--prerelease" gh.log && pass "gh --prerelease flag present" || fail "gh --prerelease missing"
)
rm -rf "$TMPDIR"
```

- [ ] **Step 2: Run — expect FAIL (happy path not implemented)**

```bash
./test/scripts/release_tag_test.sh
```

Expected: ❌ on happy-path assertions.

- [ ] **Step 3: Implement the action in scripts/release-tag.sh**

Replace the `echo "release-tag.sh: guardrails passed..."` line with:

```bash
echo "→ git tag -a $TAG $EXPECTED_SHA -m '$MESSAGE'"
git tag -a "$TAG" "$EXPECTED_SHA" -m "$MESSAGE"

echo "→ git push origin $TAG"
git push origin "$TAG"

# --prerelease only for v*-alpha.N / v*-beta.N / v*-rc.N
PRERELEASE_FLAG=()
if [[ "$TAG" =~ -[a-z]+\.[0-9]+$ ]]; then
  PRERELEASE_FLAG=(--prerelease)
fi

echo "→ gh release create $TAG --generate-notes ${PRERELEASE_FLAG[*]}"
gh release create "$TAG" --generate-notes "${PRERELEASE_FLAG[@]}"

echo "✅ release-tag.sh: $TAG released"
```

- [ ] **Step 4: Re-run — expect all ✅**

```bash
./test/scripts/release_tag_test.sh
```

Expected: all green.

- [ ] **Step 5: Add test for stable (non-prerelease) tag skipping --prerelease**

Append to test:

```bash
# Case: stable tag (no -prerelease suffix) → no --prerelease flag
TMPDIR="$(setup_fake_repo)"
(
  cd "$TMPDIR/local"
  echo b > b.txt && git add b.txt
  git commit --quiet -m "release(v1.0.0): GA"
  git push --quiet origin main
  mkdir -p bin
  cat > bin/gh <<'GH'
#!/usr/bin/env bash
echo "gh $*" >> "$PWD/gh.log"
exit 0
GH
  chmod +x bin/gh
  export PATH="$PWD/bin:$PATH"
  merge_sha="$(git rev-parse HEAD)"
  set +e
  "$SCRIPT" "$merge_sha" v1.0.0 "GA" >/dev/null 2>&1
  set -e
  grep -q -- "--prerelease" gh.log && fail "stable tag should NOT pass --prerelease" || pass "stable tag omits --prerelease"
)
rm -rf "$TMPDIR"
```

- [ ] **Step 6: Re-run**

```bash
./test/scripts/release_tag_test.sh
```

Expected: all ✅.

- [ ] **Step 7: Commit**

```bash
git add scripts/release-tag.sh test/scripts/release_tag_test.sh
git commit -m "feat(scripts): release-tag.sh happy path — tag + push + gh release (TD-002 M5)"
```

---

## Task 6: 文档更新

**Files:**
- Modify: `docs/CONTRIBUTING.md`
- Modify: `docs/internal/tech-debt.md`

- [ ] **Step 1: Replace §Tag & Release manual commands with scripted flow**

Find the section starting `## Tag & Release` in `docs/CONTRIBUTING.md` and replace the content after the bullet list with:

```markdown
### 使用 `scripts/release-tag.sh`（推荐）

合入 `main` 后：

```bash
# 从 GitHub PR 页复制 squash/merge commit 的完整 SHA
scripts/release-tag.sh <merge-sha> v0.1.0-alpha.7 "release 说明"
```

脚本内置两条护栏：
1. `origin/main` HEAD commit 消息必须匹配 `release(v*)` 前缀（防 tag 被误打到非 release commit）
2. `<merge-sha>` 必须等于 `origin/main` HEAD（防本地 main 未同步导致的时序陷阱，见 TD-002）

出错退码：`2` 参数错、`10` 护栏 #1 失败、`11` 护栏 #2 失败。脚本成功后自动：

- `git tag -a <tag> <sha>`
- `git push origin <tag>`
- `gh release create <tag> --generate-notes [--prerelease]`（prerelease 自动基于 SemVer pre-release 段推断）

### 手工兜底（不推荐）

仅在脚本不可用时手工操作。按顺序：

1. `git fetch origin`
2. `git log -1 --format=%s origin/main` 确认是 release 合入 commit
3. `git tag -a v0.1.0-alpha.7 <origin/main HEAD sha> -m "..."`
4. `git push origin v0.1.0-alpha.7`
5. `gh release create v0.1.0-alpha.7 --generate-notes --prerelease`
```

- [ ] **Step 2: Update TD-002 status in tech-debt.md**

Find `TD-002` section in `docs/internal/tech-debt.md` and replace:

```markdown
### TD-002 — release tag 脚本化时序隐患 ⚠️ 已临时修复，护栏未加
```

with:

```markdown
### TD-002 — release tag 脚本化时序隐患 ✅ 已修复（scripts/release-tag.sh, 2026-04-22）
```

And append at the bottom of the TD-002 block:

```markdown
- **修复 (2026-04-22)**：`scripts/release-tag.sh` 落地，护栏 #1 + #2 以 exit 10 / 11 强断言。CONTRIBUTING §Tag & Release 已改为脚本优先。测试 `test/scripts/release_tag_test.sh` 覆盖两个 negative + 两个 happy path。
```

- [ ] **Step 3: Commit**

```bash
git add docs/CONTRIBUTING.md docs/internal/tech-debt.md
git commit -m "docs(release): scripts/release-tag.sh usage + TD-002 → resolved"
```

---

## 总览（PR 切片）

- **M1 (Task 1-2)**：脚本骨架 + --help + arg parsing — 1 PR
- **M2 (Task 3-4)**：两个护栏函数 + 单元测试 — 1 PR
- **M3 (Task 5)**：happy path + 集成测试 — 1 PR
- **M4 (Task 6)**：文档 — 1 PR

**总 PR 数**：4（或合成 2 PR：M1+M2 / M3+M4）
**预估工时**：3-5 小时（单人）
**CI 成本**：每 PR 独立跑 flutter analyze + test + 新增 `test/scripts/release_tag_test.sh` 在 CI workflow 里手动加一步（可选，脚本变更频率低）

---

## Out of Scope

- `scripts/release-cherry-pick.sh`（切分支 + cherry-pick 打包）—— 当前手工流程无事故，不做
- Branch Protection 锁 Rebase-only —— 与 §67 dev Squash 规矩打架，软约束
- `gh` authentication fallback —— 脚本假设 `gh auth status` 已绿，出错直接打回
- `bats` / `shellcheck` CI 集成 —— 脚本依赖极薄，pure shell test 足够

---

## Self-Review

**Spec coverage check** — TD-002 的两个护栏：
- ✅ 护栏 #1 (PR 标题断言) → Task 3 `assert_remote_main_is_release_commit`
- ✅ 护栏 #2 (merge-commit-sha 入参) → Task 3 `assert_expected_merge_sha_matches_remote`（函数在 Task 3 写好，negative 测试在 Task 4 补）

**Placeholder scan** — 搜 "TBD" / "implement later" / "appropriate error" / "similar to task N"：全部命中 0 次 ✅。

**Type consistency**：
- 函数名：`assert_remote_main_is_release_commit` / `assert_expected_merge_sha_matches_remote` — 两处引用统一 ✅
- exit code：2 / 10 / 11 — 在脚本内、测试内、文档内三处一致 ✅
- `EXPECTED_SHA` 变量名：script 内统一 ✅

**Execution risk**：
- Task 3 的临时 repo 测试依赖 `git push --quiet origin main` 到 bare repo —— macOS 默认 `git` 行为 OK，Linux CI 同
- mock `gh` 通过 PATH 劫持 —— macOS 默认 `gh` 在 `/opt/homebrew/bin`，测试 `export PATH=bin:$PATH` 优先级足够
