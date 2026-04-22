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

exit $FAILURES
