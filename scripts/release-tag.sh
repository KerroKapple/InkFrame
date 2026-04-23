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

if [[ $# -ne 3 ]]; then
  echo "error: expected 3 arguments, got $#" >&2
  echo "" >&2
  usage >&2
  exit 2
fi

EXPECTED_SHA="$1"
TAG="$2"
MESSAGE="$3"

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$ ]]; then
  echo "error: tag '$TAG' doesn't match SemVer vMAJOR.MINOR.PATCH[-prerelease.N]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/release_guardrails.sh
source "$SCRIPT_DIR/lib/release_guardrails.sh"

echo "→ git fetch origin"
git fetch origin --quiet

echo "→ guardrail #1: origin/main HEAD is a release commit"
assert_remote_main_is_release_commit

echo "→ guardrail #2: <expected-merge-sha> == origin/main HEAD"
assert_expected_merge_sha_matches_remote "$EXPECTED_SHA"

echo "→ git tag -a $TAG $EXPECTED_SHA -m '$MESSAGE'"
git tag -a "$TAG" "$EXPECTED_SHA" -m "$MESSAGE"

echo "→ git push origin $TAG"
git push origin "$TAG"

if [[ "$TAG" =~ -[a-z]+\.[0-9]+$ ]]; then
  echo "→ gh release create $TAG --generate-notes --prerelease"
  gh release create "$TAG" --generate-notes --prerelease
else
  echo "→ gh release create $TAG --generate-notes"
  gh release create "$TAG" --generate-notes
fi

echo "✅ release-tag.sh: $TAG released"
