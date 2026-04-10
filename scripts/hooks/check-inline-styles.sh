#!/usr/bin/env bash
# check-inline-styles.sh
# Detects hardcoded colors, font sizes, spacing, and raw style values in Dart files.
# Enforces: all visual properties must come from lib/theme/tokens.dart
# Exit 1 = violation → Claude is forced to fix before proceeding.

FILE="$1"
[[ -z "$FILE" ]] && exit 0

[[ "$FILE" != *.dart ]]           && exit 0
[[ "$FILE" == *".g.dart" ]]       && exit 0
[[ "$FILE" == *".freezed.dart" ]] && exit 0
[[ "$FILE" == *"generated/"* ]]   && exit 0
[[ "$FILE" == *"_test.dart" ]]    && exit 0

# Skip the token/theme definition files themselves — they ARE the source of truth
[[ "$FILE" == *"tokens.dart" ]]    && exit 0
[[ "$FILE" == *"app_theme.dart" ]] && exit 0
[[ "$FILE" == *"typography.dart" ]] && exit 0

# Skip Ink component definitions — they use tokens directly by design
[[ "$FILE" == *"theme/components/"* ]] && exit 0

VIOLATIONS=()
LINENUM=0

while IFS= read -r LINE; do
  LINENUM=$((LINENUM + 1))
  TRIMMED="${LINE#"${LINE%%[![:space:]]*}"}"

  [[ "$TRIMMED" == "//"* ]] && continue
  [[ "$TRIMMED" == "*"*  ]] && continue

  # Rule 1: Hardcoded hex Color values — Color(0xFF...)
  if echo "$LINE" | grep -qE 'Color\s*\(\s*0x[0-9A-Fa-f]{6,8}'; then
    VIOLATIONS+=("  Line $LINENUM: [HARDCODED_HEX_COLOR]")
    VIOLATIONS+=("  → Color(0xFF...) is forbidden. Use context.inkColors.* or InkColors.* token.")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 2: Named color literals — Colors.white, Colors.black, Colors.red, etc.
  if echo "$LINE" | grep -qE 'Colors\.(white|black|grey|red|blue|green|orange|purple|pink|yellow|brown|cyan|teal|amber|lime|indigo)\b'; then
    VIOLATIONS+=("  Line $LINENUM: [RAW_MATERIAL_COLOR]")
    VIOLATIONS+=("  → Colors.* primitives are forbidden. Use context.inkColors.* semantic token.")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 3: Hardcoded fontSize values
  if echo "$LINE" | grep -qE 'fontSize\s*:\s*[0-9]+\.?[0-9]*'; then
    VIOLATIONS+=("  Line $LINENUM: [HARDCODED_FONT_SIZE]")
    VIOLATIONS+=("  → fontSize: N is forbidden. Use context.inkTypography.* or InkTextStyles.*")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 4: Hardcoded EdgeInsets with raw numbers (not token constants)
  # Catches: EdgeInsets.all(16), EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.only(top: 8)
  if echo "$LINE" | grep -qE 'EdgeInsets\.(all|symmetric|only|fromLTRB)\s*\([^)]*[0-9]{1,3}[^)]*\)'; then
    # Allow EdgeInsets.zero
    if ! echo "$LINE" | grep -qE 'EdgeInsets\.zero'; then
      VIOLATIONS+=("  Line $LINENUM: [HARDCODED_SPACING]")
      VIOLATIONS+=("  → EdgeInsets with raw numbers is forbidden. Use InkSpacing.* (e.g. EdgeInsets.all(InkSpacing.md))")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

  # Rule 5: Hardcoded BorderRadius with raw numbers
  if echo "$LINE" | grep -qE 'BorderRadius\.(circular|only|all)\s*\([^)]*[0-9]+[^)]*\)' && \
     ! echo "$LINE" | grep -qE 'BorderRadius\.(circular|only)\s*\(\s*InkRadius'; then
    VIOLATIONS+=("  Line $LINENUM: [HARDCODED_RADIUS]")
    VIOLATIONS+=("  → BorderRadius with raw number is forbidden. Use InkRadius.* (e.g. BorderRadius.circular(InkRadius.lg))")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 6: Raw Container/SizedBox replacing Ink components
  # Catches widgets that should use InkCard / InkButton
  if echo "$LINE" | grep -qE '^\s*Container\s*\(' && \
     echo "$FILE" | grep -qE 'features/|lib/features/'; then
    # Only flag if it has decoration (visual styling intent)
    if grep -A 5 "Container(" "$FILE" 2>/dev/null | grep -q 'BoxDecoration'; then
      VIOLATIONS+=("  Line $LINENUM: [RAW_CONTAINER_WITH_DECORATION]")
      VIOLATIONS+=("  → Container with BoxDecoration in feature code must be replaced with InkCard or appropriate Ink component.")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

  # Rule 7: Hardcoded shadow values
  if echo "$LINE" | grep -qE 'BoxShadow\s*\(\s*color:'; then
    VIOLATIONS+=("  Line $LINENUM: [HARDCODED_SHADOW]")
    VIOLATIONS+=("  → Inline BoxShadow is forbidden. Use InkShadow.* token (e.g. boxShadow: [InkShadow.card])")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

done < "$FILE"

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo ""
  echo "🚫 [check-inline-styles] VIOLATIONS FOUND — commit blocked"
  echo ""
  for LINE in "${VIOLATIONS[@]}"; do
    echo "$LINE"
  done
  echo "Fix all violations before proceeding."
  echo ""
  exit 1
fi

exit 0
