#!/bin/zsh
set -euo pipefail

# HarnessKit — wait-for-turn
# Blocks until it's this session's turn in the dual-session protocol.
#
# Usage: wait-for-turn.sh <conversation-folder> <session-letter> <mode> [options]
#   conversation-folder: absolute path to the Planner-Conversation/ or Round-NN-Conversation/ folder
#   session-letter:      A or B
#   mode:                parallel or sequential
#
# Options:
#   --wait-for <status>  exact status to wait for on the OTHER session (e.g., review-done)
#                        without this, parallel mode uses legacy *-done matching
#   --quiet              suppress all output except final READY line (for Codex)
#
# Exit 0 = it's your turn. Output includes current state summary.
# Exit 1 = error (missing files, bad args).

CONV_DIR="$1"
SESSION="$2"
MODE="$3"
shift 3

# Parse optional flags
WAIT_FOR=""
QUIET=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait-for) WAIT_FOR="$2"; shift 2 ;;
    --quiet) QUIET=true; shift ;;
    *) echo "ERROR: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$CONV_DIR" ]]; then
  echo "ERROR: Conversation folder not found: $CONV_DIR" >&2
  exit 1
fi

if [[ "$SESSION" != "A" && "$SESSION" != "B" ]]; then
  echo "ERROR: Session must be A or B, got: $SESSION" >&2
  exit 1
fi

if [[ "$MODE" != "parallel" && "$MODE" != "sequential" ]]; then
  echo "ERROR: Mode must be parallel or sequential, got: $MODE" >&2
  exit 1
fi

OTHER=$( [[ "$SESSION" == "A" ]] && echo "B" || echo "A" )

check_turn() {
  local status_mine status_other next_turn

  # Read status files
  if [[ -f "$CONV_DIR/Status-$SESSION.json" ]]; then
    status_mine=$(python3 -c "import json; print(json.load(open('$CONV_DIR/Status-$SESSION.json')).get('status','unknown'))" 2>/dev/null || echo "unknown")
  else
    status_mine="missing"
  fi

  if [[ -f "$CONV_DIR/Status-$OTHER.json" ]]; then
    status_other=$(python3 -c "import json; print(json.load(open('$CONV_DIR/Status-$OTHER.json')).get('status','unknown'))" 2>/dev/null || echo "unknown")
  else
    status_other="missing"
  fi

  if [[ "$MODE" == "parallel" ]]; then
    if [[ -n "$WAIT_FOR" ]]; then
      # Exact match mode — only return when other session has this specific status
      if [[ "$status_other" == "$WAIT_FOR" ]]; then
        echo "READY: Mode=parallel, $OTHER status=$status_other (matches --wait-for $WAIT_FOR). Your turn ($SESSION)."
        echo "Your status: $status_mine"
        return 0
      fi
    else
      # Legacy mode (no --wait-for) — any -done suffix or approved
      if [[ "$status_other" == *"-done" || "$status_other" == "approved" ]]; then
        echo "READY: Mode=parallel, $OTHER status=$status_other (done). Your turn ($SESSION)."
        echo "Your status: $status_mine"
        return 0
      fi
    fi
  else
    # In sequential mode: check nextTurn field
    if [[ -f "$CONV_DIR/Coordination.json" ]]; then
      next_turn=$(python3 -c "import json; print(json.load(open('$CONV_DIR/Coordination.json')).get('nextTurn','unknown'))" 2>/dev/null || echo "unknown")
    else
      next_turn="unknown"
    fi

    if [[ "$next_turn" == "$SESSION" ]]; then
      echo "READY: Mode=sequential, nextTurn=$next_turn. Your turn ($SESSION)."
      echo "Your status: $status_mine | $OTHER status: $status_other"
      return 0
    fi
  fi

  return 1
}

# Check immediately first — maybe it's already our turn
if check_turn; then
  exit 0
fi

# Not our turn — enter watch loop
if [[ "$QUIET" != true ]]; then
  echo "WAITING: Not $SESSION's turn yet. Watching $CONV_DIR..."
fi

while true; do
  # Try watchman-wait first
  if command -v watchman-wait &>/dev/null; then
    watchman-wait "$CONV_DIR" \
      -p "Status-A.json" -p "Status-B.json" -p "Coordination.json" \
      --max-events 1 -t 600 2>/dev/null || true
  else
    # Fallback: md5 polling
    _prev=$(cat "$CONV_DIR/Status-$OTHER.json" "$CONV_DIR/Coordination.json" 2>/dev/null | md5 -q 2>/dev/null || echo "none")
    while true; do
      sleep 5
      _curr=$(cat "$CONV_DIR/Status-$OTHER.json" "$CONV_DIR/Coordination.json" 2>/dev/null | md5 -q 2>/dev/null || echo "none")
      if [[ "$_curr" != "$_prev" ]]; then
        break
      fi
    done
  fi

  # Re-check after wake
  if check_turn; then
    exit 0
  fi

  # Only log once, only if not quiet
  if [[ "$QUIET" != true && -z "${_spurious_logged:-}" ]]; then
    echo "STILL WAITING: Woke up but not $SESSION's turn yet. Continuing to watch..."
    _spurious_logged=1
  fi
done
