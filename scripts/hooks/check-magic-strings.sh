#!/usr/bin/env bash
# check-magic-strings.sh
# Detects hardcoded user-facing strings and magic values in Dart files.
# Exit 1 = violation → Claude is forced to fix before proceeding.

FILE="$1"
[[ -z "$FILE" ]] && exit 0

# Only check Dart files
[[ "$FILE" != *.dart ]] && exit 0

# Skip generated files, ARB files, and constants
[[ "$FILE" == *".g.dart" ]]       && exit 0
[[ "$FILE" == *".freezed.dart" ]] && exit 0
[[ "$FILE" == *"l10n/"* ]]        && exit 0
[[ "$FILE" == *"generated/"* ]]   && exit 0
[[ "$FILE" == *"constants"* ]]    && exit 0
[[ "$FILE" == *"tokens.dart" ]]   && exit 0
[[ "$FILE" == *"_test.dart" ]]    && exit 0
[[ "$FILE" == *"features/debug/"* ]] && exit 0

VIOLATIONS=()
LINENUM=0

while IFS= read -r LINE; do
  LINENUM=$((LINENUM + 1))
  TRIMMED="${LINE#"${LINE%%[![:space:]]*}"}"

  # Skip comments
  [[ "$TRIMMED" == "//"* ]] && continue
  [[ "$TRIMMED" == "*"*  ]] && continue

  # Rule 1: Hardcoded Chinese characters in widget Text()
  if echo "$LINE" | grep -qP 'Text\s*\(\s*"[^"]*[\x{4e00}-\x{9fff}][^"]*"' 2>/dev/null || \
     echo "$LINE" | grep -q 'Text("[^"]*[\u4e00-\u9fff]'; then
    VIOLATIONS+=("  Line $LINENUM: [HARDCODED_CHINESE_STRING]")
    VIOLATIONS+=("  → Chinese text in Text() must use context.l10n.yourKey")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 2: Hardcoded English text in Text() widget (quoted string, not a variable)
  if echo "$LINE" | grep -qE 'Text\s*\(\s*"[A-Z][a-zA-Z ]{3,}"'; then
    VIOLATIONS+=("  Line $LINENUM: [HARDCODED_ENGLISH_STRING]")
    VIOLATIONS+=("  → English text in Text() must use context.l10n.yourKey")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 3: Hardcoded strings in ToastService / showSnackBar / showDialog title
  if echo "$LINE" | grep -qE '(ToastService\.show|showSnackBar|title:\s*Text)\s*\(\s*"[^"]{3,}"'; then
    VIOLATIONS+=("  Line $LINENUM: [HARDCODED_UI_STRING]")
    VIOLATIONS+=("  → UI message strings must use context.l10n.yourKey")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 4: String interpolation in UI context (not in service/repo layer)
  if echo "$LINE" | grep -qE 'Text\s*\(\s*"[^"]*\$[a-zA-Z]'; then
    VIOLATIONS+=("  Line $LINENUM: [INTERPOLATED_UI_STRING]")
    VIOLATIONS+=("  → Interpolated strings in Text() must use context.l10n.yourKey(param)")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 5: Magic numbers — common poll/timeout/delay values not in constants
  if echo "$LINE" | grep -qE '\b(1000|2000|3000|5000|10000|30000|60000)\b' && \
     ! echo "$LINE" | grep -q '//' && \
     ! echo "$FILE" | grep -q 'constants'; then
    VIOLATIONS+=("  Line $LINENUM: [MAGIC_NUMBER]")
    VIOLATIONS+=("  → Magic number must be a named constant in lib/core/constants/")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 6: Hardcoded route/path strings
  if echo "$LINE" | grep -qE "context\.go\s*\(\s*'[/][a-z]|Navigator\.pushNamed\s*\(\s*context,\s*'[/]"; then
    VIOLATIONS+=("  Line $LINENUM: [HARDCODED_ROUTE]")
    VIOLATIONS+=("  → Route strings must use AppRoutes constants from lib/core/constants/routes.dart")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 7: Status/type magic strings in comparisons
  if echo "$LINE" | grep -qE "==\s*['\"]+(running|pending|done|failed|success|error|idle|loading)['\"]"; then
    VIOLATIONS+=("  Line $LINENUM: [MAGIC_STATUS_STRING]")
    VIOLATIONS+=("  → Status string must use a Dart enum from lib/core/constants/")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

done < "$FILE"

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo ""
  echo "🚫 [check-magic-strings] VIOLATIONS FOUND — commit blocked"
  echo ""
  for LINE in "${VIOLATIONS[@]}"; do
    echo "$LINE"
  done
  echo "Fix all violations before proceeding."
  echo ""
  exit 1
fi

exit 0
