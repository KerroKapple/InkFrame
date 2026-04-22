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
