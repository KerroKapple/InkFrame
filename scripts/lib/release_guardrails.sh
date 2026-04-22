#!/usr/bin/env bash
# Guardrail functions for release-tag.sh. Source this file.

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

assert_expected_merge_sha_matches_remote() {
  local expected="$1"
  local actual
  actual="$(git rev-parse origin/main)"
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
