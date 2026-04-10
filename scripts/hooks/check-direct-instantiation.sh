#!/usr/bin/env bash
# check-direct-instantiation.sh
# Detects direct instantiation of services/repositories/providers outside of DI wiring.
# Enforces: all injectables must be accessed via Riverpod ref.watch / ref.read.
# Exit 1 = violation → Claude is forced to fix before proceeding.

FILE="$1"
[[ -z "$FILE" ]] && exit 0

[[ "$FILE" != *.dart ]]           && exit 0
[[ "$FILE" == *".g.dart" ]]       && exit 0
[[ "$FILE" == *".freezed.dart" ]] && exit 0
[[ "$FILE" == *"generated/"* ]]   && exit 0
[[ "$FILE" == *"_test.dart" ]]    && exit 0

# DI wiring files are the ONE place direct instantiation is allowed
[[ "$FILE" == *"core/di/"* ]]     && exit 0

# Value objects / infrastructure bootstrapping
[[ "$FILE" == *"main.dart" ]]     && exit 0

VIOLATIONS=()
LINENUM=0

# Classes that are always safe to instantiate directly (value objects, stdlib)
ALLOWED_CLASSES=(
  "DateTime"
  "Duration"
  "Uri"
  "RegExp"
  "StringBuffer"
  "Map"
  "List"
  "Set"
  "File"
  "Directory"
  "Completer"
  "StreamController"
  "StreamSubscription"
  "TextEditingController"
  "ScrollController"
  "FocusNode"
  "GlobalKey"
  "ValueNotifier"
)

is_allowed() {
  local CLASS="$1"
  for ALLOWED in "${ALLOWED_CLASSES[@]}"; do
    [[ "$CLASS" == "$ALLOWED" ]] && return 0
  done
  return 1
}

while IFS= read -r LINE; do
  LINENUM=$((LINENUM + 1))
  TRIMMED="${LINE#"${LINE%%[![:space:]]*}"}"

  [[ "$TRIMMED" == "//"* ]] && continue
  [[ "$TRIMMED" == "*"*  ]] && continue

  # Rule 1: Direct instantiation of service/repository/provider classes
  # Pattern: SomethingService() / SomethingRepository() / SomethingProvider()
  if echo "$LINE" | grep -qE '[A-Z][a-zA-Z]*(Service|Repository|Provider|Client|Manager|Handler)\s*\('; then
    # Extract the class name
    CLASS=$(echo "$LINE" | grep -oE '[A-Z][a-zA-Z]*(Service|Repository|Provider|Client|Manager|Handler)' | head -1)

    # Skip abstract constructor calls that are clearly factory/override patterns
    if echo "$LINE" | grep -qE '^\s*(return|=|final|var)\s+[A-Z].*\(' && \
       ! echo "$LINE" | grep -qE 'ref\.(watch|read|listen)'; then

      is_allowed "$CLASS" && continue

      VIOLATIONS+=("  Line $LINENUM: [DIRECT_INSTANTIATION]")
      VIOLATIONS+=("  → 'new $CLASS(...)' violates DIP.")
      VIOLATIONS+=("  → Services/Repositories/Providers must be accessed via ref.watch(${CLASS,,}Provider)")
      VIOLATIONS+=("  → Move wiring to lib/core/di/ if this is intentional DI setup.")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

  # Rule 2: Static singleton pattern — ClassName.instance / ClassName.shared
  if echo "$LINE" | grep -qE '[A-Z][a-zA-Z]+\.(instance|shared|singleton)\b' && \
     ! echo "$LINE" | grep -q '//'; then
    CLASS=$(echo "$LINE" | grep -oE '[A-Z][a-zA-Z]+\.(instance|shared|singleton)' | head -1)
    VIOLATIONS+=("  Line $LINENUM: [STATIC_SINGLETON_ACCESS]")
    VIOLATIONS+=("  → '$CLASS' is a static singleton — forbidden. Use Riverpod provider with keepAlive.")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 3: ServiceLocator / GetIt / locator pattern
  if echo "$LINE" | grep -qE '(GetIt|ServiceLocator|locator|sl)\s*[<.(]'; then
    VIOLATIONS+=("  Line $LINENUM: [SERVICE_LOCATOR_PATTERN]")
    VIOLATIONS+=("  → ServiceLocator/GetIt pattern is forbidden. Use Riverpod ref.watch() instead.")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

  # Rule 4: Global mutable state
  if echo "$LINE" | grep -qE '^(var|late)\s+[a-z][a-zA-Z]*(Service|Repository|Provider|Client)\s*=' && \
     ! echo "$LINE" | grep -q 'final'; then
    VIOLATIONS+=("  Line $LINENUM: [GLOBAL_MUTABLE_STATE]")
    VIOLATIONS+=("  → Global mutable service variable forbidden. Declare as 'final' provider in lib/core/di/.")
    VIOLATIONS+=("  → $TRIMMED")
    VIOLATIONS+=("")
  fi

done < "$FILE"

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo ""
  echo "🚫 [check-direct-instantiation] VIOLATIONS FOUND — commit blocked"
  echo ""
  for LINE in "${VIOLATIONS[@]}"; do
    echo "$LINE"
  done
  echo "Fix all violations before proceeding."
  echo ""
  exit 1
fi

exit 0
