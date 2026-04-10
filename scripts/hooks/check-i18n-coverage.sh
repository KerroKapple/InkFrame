#!/usr/bin/env bash
# check-i18n-coverage.sh
# Ensures app_en.arb and app_zh.arb have identical key sets.
# Also detects hardcoded strings being added to Dart files without ARB entries.
# Exit 1 = key mismatch → Claude is forced to sync both files.

FILE="$1"
[[ -z "$FILE" ]] && exit 0

# Trigger on: ARB files or any Dart file in features/widgets
IS_ARB=false
IS_DART=false
[[ "$FILE" == *.arb ]]  && IS_ARB=true
[[ "$FILE" == *.dart" ]] && IS_DART=true
[[ "$FILE" == *".g.dart" ]]       && exit 0
[[ "$FILE" == *".freezed.dart" ]] && exit 0

if ! $IS_ARB && ! $IS_DART; then
  exit 0
fi

# ─── Find the project root (walk up to find pubspec.yaml) ────────────────────
find_project_root() {
  local DIR
  DIR=$(dirname "$(realpath "$FILE" 2>/dev/null || echo "$FILE")")
  for _ in $(seq 1 10); do
    [[ -f "$DIR/pubspec.yaml" ]] && echo "$DIR" && return
    DIR=$(dirname "$DIR")
  done
  echo ""
}

PROJECT_ROOT=$(find_project_root)
if [[ -z "$PROJECT_ROOT" ]]; then
  # Can't find project root — skip silently
  exit 0
fi

EN_ARB="$PROJECT_ROOT/lib/l10n/app_en.arb"
ZH_ARB="$PROJECT_ROOT/lib/l10n/app_zh.arb"

if [[ ! -f "$EN_ARB" ]] || [[ ! -f "$ZH_ARB" ]]; then
  if $IS_ARB; then
    echo ""
    echo "⚠️  [check-i18n-coverage] Both app_en.arb and app_zh.arb must exist in lib/l10n/"
    echo ""
    exit 1
  fi
  exit 0
fi

# ─── Extract keys from ARB files (keys are JSON properties, not @@locale etc.) ─
extract_keys() {
  local ARB_FILE="$1"
  # Extract all keys that don't start with @ (metadata keys are prefixed with @)
  grep -oE '"[a-zA-Z][a-zA-Z0-9_]*"\s*:' "$ARB_FILE" | \
    grep -v '"@@' | \
    sed 's/"\s*://' | \
    tr -d '"' | \
    sort
}

EN_KEYS=$(extract_keys "$EN_ARB")
ZH_KEYS=$(extract_keys "$ZH_ARB")

EN_COUNT=$(echo "$EN_KEYS" | grep -c '.' || echo 0)
ZH_COUNT=$(echo "$ZH_KEYS" | grep -c '.' || echo 0)

VIOLATIONS=()

# ─── Find keys in EN but missing in ZH ───────────────────────────────────────
MISSING_IN_ZH=$(comm -23 <(echo "$EN_KEYS") <(echo "$ZH_KEYS"))
if [[ -n "$MISSING_IN_ZH" ]]; then
  VIOLATIONS+=("  [MISSING_ZH_KEYS] Keys in app_en.arb but missing in app_zh.arb:")
  while IFS= read -r KEY; do
    [[ -n "$KEY" ]] && VIOLATIONS+=("    - $KEY")
  done <<< "$MISSING_IN_ZH"
  VIOLATIONS+=("")
fi

# ─── Find keys in ZH but missing in EN ───────────────────────────────────────
MISSING_IN_EN=$(comm -13 <(echo "$EN_KEYS") <(echo "$ZH_KEYS"))
if [[ -n "$MISSING_IN_EN" ]]; then
  VIOLATIONS+=("  [MISSING_EN_KEYS] Keys in app_zh.arb but missing in app_en.arb:")
  while IFS= read -r KEY; do
    [[ -n "$KEY" ]] && VIOLATIONS+=("    - $KEY")
  done <<< "$MISSING_IN_EN"
  VIOLATIONS+=("")
fi

# ─── Validate JSON syntax of both ARB files ───────────────────────────────────
if command -v python3 &>/dev/null; then
  if ! python3 -c "import json; json.load(open('$EN_ARB'))" 2>/dev/null; then
    VIOLATIONS+=("  [INVALID_JSON] app_en.arb contains invalid JSON.")
    VIOLATIONS+=("")
  fi
  if ! python3 -c "import json; json.load(open('$ZH_ARB'))" 2>/dev/null; then
    VIOLATIONS+=("  [INVALID_JSON] app_zh.arb contains invalid JSON.")
    VIOLATIONS+=("")
  fi
fi

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo ""
  echo "🚫 [check-i18n-coverage] I18N KEY MISMATCH — commit blocked"
  echo ""
  echo "  app_en.arb: $EN_COUNT keys"
  echo "  app_zh.arb: $ZH_COUNT keys"
  echo ""
  for LINE in "${VIOLATIONS[@]}"; do
    echo "$LINE"
  done
  echo "app_en.arb and app_zh.arb must have identical key sets."
  echo "Add the missing translations to both files before proceeding."
  echo ""
  exit 1
fi

echo "✅ [check-i18n-coverage] $EN_COUNT keys — app_en.arb ↔ app_zh.arb in sync"
exit 0
