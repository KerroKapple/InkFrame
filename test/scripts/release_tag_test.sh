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

set +e
out="$("$SCRIPT" b41d735 v0.1.0-alpha.7 "msg" 2>&1)"
ec=$?
set -e
[[ $ec -eq 2 ]] && echo "$out" | grep -q "guardrails not yet implemented" && pass "good args → reaches guardrail stub" || fail "good args path broken (ec=$ec)"

exit $FAILURES
