#!/usr/bin/env bash
# check-disposable-cleanup.sh
# Detects Dart resources that are created but never disposed.
# Flutter equivalent of React's useEffect cleanup.
# Covers: StreamSubscription, TextEditingController, ScrollController,
#         AnimationController, Timer, FocusNode, ChangeNotifier subclasses.
# Exit 1 = violation → Claude is forced to fix before proceeding.

FILE="$1"
[[ -z "$FILE" ]] && exit 0

[[ "$FILE" != *.dart ]]           && exit 0
[[ "$FILE" == *".g.dart" ]]       && exit 0
[[ "$FILE" == *".freezed.dart" ]] && exit 0
[[ "$FILE" == *"generated/"* ]]   && exit 0
[[ "$FILE" == *"_test.dart" ]]    && exit 0

VIOLATIONS=()
CONTENT=$(cat "$FILE")
LINENUM=0

# ─── Helper: check if file contains a dispose() method ───────────────────────
has_dispose_method() {
  echo "$CONTENT" | grep -q 'void dispose()'
}

# ─── Helper: check if a resource type is cleaned up somewhere in the file ────
is_cleaned_up() {
  local RESOURCE_TYPE="$1"
  case "$RESOURCE_TYPE" in
    StreamSubscription)
      echo "$CONTENT" | grep -qE '\.cancel\(\)' && return 0 ;;
    TextEditingController|ScrollController|AnimationController|FocusNode|PageController|TabController)
      echo "$CONTENT" | grep -qE '\.dispose\(\)' && return 0 ;;
    Timer)
      echo "$CONTENT" | grep -qE '\.cancel\(\)' && return 0 ;;
  esac
  return 1
}

while IFS= read -r LINE; do
  LINENUM=$((LINENUM + 1))
  TRIMMED="${LINE#"${LINE%%[![:space:]]*}"}"

  [[ "$TRIMMED" == "//"* ]] && continue
  [[ "$TRIMMED" == "*"*  ]] && continue

  # Rule 1: StreamSubscription declared but never cancelled
  if echo "$LINE" | grep -qE 'late\s+StreamSubscription|StreamSubscription[<\s].*='; then
    if ! is_cleaned_up "StreamSubscription"; then
      VIOLATIONS+=("  Line $LINENUM: [STREAM_SUBSCRIPTION_LEAK]")
      VIOLATIONS+=("  → StreamSubscription declared but .cancel() not found in this file.")
      VIOLATIONS+=("  → In a StatefulWidget: call _subscription.cancel() in dispose().")
      VIOLATIONS+=("  → In a Riverpod Notifier: use ref.onDispose(() => _subscription.cancel()).")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

  # Rule 2: TextEditingController without dispose
  if echo "$LINE" | grep -qE 'TextEditingController\s*\(\s*\)'; then
    if ! has_dispose_method || ! is_cleaned_up "TextEditingController"; then
      VIOLATIONS+=("  Line $LINENUM: [CONTROLLER_NOT_DISPOSED]")
      VIOLATIONS+=("  → TextEditingController created but .dispose() not found.")
      VIOLATIONS+=("  → Call _controller.dispose() in your State.dispose() override.")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

  # Rule 3: AnimationController without dispose
  if echo "$LINE" | grep -qE 'AnimationController\s*\('; then
    if ! has_dispose_method || ! is_cleaned_up "AnimationController"; then
      VIOLATIONS+=("  Line $LINENUM: [ANIMATION_CONTROLLER_LEAK]")
      VIOLATIONS+=("  → AnimationController created but .dispose() not found.")
      VIOLATIONS+=("  → Call _animationController.dispose() in State.dispose().")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

  # Rule 4: FocusNode without dispose
  if echo "$LINE" | grep -qE 'FocusNode\s*\(\s*\)'; then
    if ! has_dispose_method || ! is_cleaned_up "FocusNode"; then
      VIOLATIONS+=("  Line $LINENUM: [FOCUS_NODE_LEAK]")
      VIOLATIONS+=("  → FocusNode created but .dispose() not found.")
      VIOLATIONS+=("  → Call _focusNode.dispose() in State.dispose().")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

  # Rule 5: Timer.periodic or Timer() without cancel
  if echo "$LINE" | grep -qE 'Timer\.(periodic|new)\s*\(|= Timer\s*\('; then
    if ! is_cleaned_up "Timer"; then
      VIOLATIONS+=("  Line $LINENUM: [TIMER_NOT_CANCELLED]")
      VIOLATIONS+=("  → Timer created but .cancel() not found in this file.")
      VIOLATIONS+=("  → In Riverpod: ref.onDispose(() => _timer.cancel()).")
      VIOLATIONS+=("  → In StatefulWidget: call _timer.cancel() in dispose().")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

  # Rule 6: Riverpod ref.listen without onDispose cancel
  if echo "$LINE" | grep -qE 'ref\.listen\s*[<(]'; then
    if ! echo "$CONTENT" | grep -qE 'ref\.onDispose'; then
      VIOLATIONS+=("  Line $LINENUM: [RIVERPOD_LISTENER_LEAK]")
      VIOLATIONS+=("  → ref.listen() used but ref.onDispose() not found.")
      VIOLATIONS+=("  → ref.listen() returns a ProviderSubscription — cancel it:")
      VIOLATIONS+=("  → final sub = ref.listen(...); ref.onDispose(sub.close);")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

  # Rule 7: StatefulWidget with resources but no dispose() override
  if echo "$LINE" | grep -qE 'class\s+_[A-Z][a-zA-Z]+State\s+extends\s+State'; then
    HAS_CONTROLLERS=$(echo "$CONTENT" | grep -cE 'TextEditingController|AnimationController|ScrollController|FocusNode|StreamSubscription|Timer')
    if [[ "$HAS_CONTROLLERS" -gt 0 ]] && ! has_dispose_method; then
      VIOLATIONS+=("  Line $LINENUM: [STATEFULWIDGET_MISSING_DISPOSE]")
      VIOLATIONS+=("  → State class has disposable resources but no dispose() override.")
      VIOLATIONS+=("  → Add: @override void dispose() { ...dispose resources...; super.dispose(); }")
      VIOLATIONS+=("  → $TRIMMED")
      VIOLATIONS+=("")
    fi
  fi

done < "$FILE"

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo ""
  echo "🚫 [check-disposable-cleanup] VIOLATIONS FOUND — commit blocked"
  echo ""
  for LINE in "${VIOLATIONS[@]}"; do
    echo "$LINE"
  done
  echo "All Dart resources (StreamSubscription, Controllers, Timers) must be explicitly disposed."
  echo ""
  exit 1
fi

exit 0
