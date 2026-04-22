#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/../../scripts/release-tag.sh"
FAILURES=0

pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; FAILURES=$((FAILURES + 1)); }

# --- Task 1: --help prints usage ---
echo "=== Task 1: --help ==="
out="$("$SCRIPT" --help 2>&1 || true)"
echo "$out" | grep -q "Usage: release-tag.sh" && pass "--help prints Usage" || fail "--help missing Usage"
echo "$out" | grep -q "expected-merge-sha" && pass "--help mentions expected-merge-sha arg" || fail "--help missing arg doc"
echo "$out" | grep -q "Guardrails:" && pass "--help mentions Guardrails" || fail "--help missing Guardrails section"

# --- Task 2: arg parsing ---
echo "=== Task 2: arg parsing ==="

set +e
"$SCRIPT" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 2 ]] && pass "no args → exit 2" || fail "no args → exit $ec (want 2)"

set +e
"$SCRIPT" b41d735 >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 2 ]] && pass "1 arg → exit 2" || fail "1 arg → exit $ec (want 2)"

set +e
"$SCRIPT" b41d735 v0.1.0-alpha.7 >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 2 ]] && pass "2 args → exit 2" || fail "2 args → exit $ec (want 2)"

set +e
"$SCRIPT" b41d735 0.1.0 "msg" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 2 ]] && pass "bad tag format (no v prefix) → exit 2" || fail "bad tag → exit $ec (want 2)"

# (dropped "reaches guardrail stub" test — guardrails are now wired; covered by Task 3 cases below)

# --- Task 3: guardrail #1 (remote main is release commit) ---
echo "=== Task 3: guardrail #1 ==="

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

# Case B: remote main HEAD IS a release commit, SHA matches → passes both guardrails, exits 2 (stub)
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
  [[ $ec -eq 2 ]] && echo "$out" | grep -q "tag action not yet implemented" && pass "release main + matching SHA → passes both guardrails" || fail "release main flow broken (ec=$ec, out=$out)"
)
rm -rf "$TMPDIR"

# --- Task 4: guardrail #2 negative cases ---
echo "=== Task 4: guardrail #2 negative ==="

# Case C: expected SHA doesn't resolve to a commit → exit 11
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

exit $FAILURES
