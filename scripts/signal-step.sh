#!/bin/zsh
set -euo pipefail

# HarnessKit — signal-step
# Atomically updates Status-<session>.json and optionally Coordination.json.
# Replaces all manual hand-editing of protocol state files.
#
# Usage: signal-step.sh <conv-folder> <session> <status> [options]
#   conv-folder:  absolute path to conversation folder
#   session:      A or B
#   status:       new status value (e.g., investigation-done, review-done, approved, done)
#
# Options:
#   --step <step>            update Coordination.json step field
#   --next-turn <A|B>        update Coordination.json nextTurn field
#   --message-round <N>      update Coordination.json messageRound field
#
# Exit 0 = success. Exit 1 = error.

if [[ $# -lt 3 ]]; then
   echo "Usage: signal-step.sh <conv-folder> <session> <status> [--step S] [--next-turn A|B] [--message-round N]" >&2
   exit 1
fi

CONV_DIR="$1"
SESSION="$2"
STATUS="$3"
shift 3

if [[ ! -d "$CONV_DIR" ]]; then
   echo "ERROR: Conversation folder not found: $CONV_DIR" >&2
   exit 1
fi

if [[ "$SESSION" != "A" && "$SESSION" != "B" ]]; then
   echo "ERROR: Session must be A or B, got: $SESSION" >&2
   exit 1
fi

# Parse optional flags
STEP=""
NEXT_TURN=""
MSG_ROUND=""

while [[ $# -gt 0 ]]; do
   case "$1" in
      --step) STEP="$2"; shift 2 ;;
      --next-turn) NEXT_TURN="$2"; shift 2 ;;
      --message-round) MSG_ROUND="$2"; shift 2 ;;
      *) echo "ERROR: Unknown argument: $1" >&2; exit 1 ;;
   esac
done

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Auto-detect tool
TOOL="claude-code"
if [[ -n "${CODEX_SESSION:-}" ]] || [[ -n "${CODEX_SANDBOX_TIMEOUT:-}" ]]; then
   TOOL="codex"
fi

# 1. Write Status-<session>.json
cat > "$CONV_DIR/Status-$SESSION.json" << EOF
{
  "status": "$STATUS",
  "tool": "$TOOL",
  "updated": "$NOW"
}
EOF

SUMMARY="session=$SESSION status=$STATUS"

# 2. Update Coordination.json if any flags provided
if [[ -n "$STEP" || -n "$NEXT_TURN" || -n "$MSG_ROUND" ]]; then
   COORD="$CONV_DIR/Coordination.json"

   # Create default if missing
   if [[ ! -f "$COORD" ]]; then
      cat > "$COORD" << EOF
{
  "step": "upfront-questions",
  "nextTurn": "A",
  "messageRound": 0,
  "updated": "$NOW"
}
EOF
   fi

   # Atomic read-modify-write
   TEMP_COORD=$(mktemp)

   STEP_ARG="${STEP:-}"
   NEXT_TURN_ARG="${NEXT_TURN:-}"
   MSG_ROUND_ARG="${MSG_ROUND:-}"

   STEP_ARG="$STEP_ARG" NEXT_TURN_ARG="$NEXT_TURN_ARG" MSG_ROUND_ARG="$MSG_ROUND_ARG" NOW="$NOW" python3 -c "
import json, os
with open('$COORD') as f:
   coord = json.load(f)
step = os.environ.get('STEP_ARG', '')
nt = os.environ.get('NEXT_TURN_ARG', '')
mr = os.environ.get('MSG_ROUND_ARG', '')
now = os.environ['NOW']
if step:
   coord['step'] = step
if nt:
   coord['nextTurn'] = nt
if mr:
   coord['messageRound'] = int(mr)
coord['updated'] = now
with open('$TEMP_COORD', 'w') as f:
   json.dump(coord, f, indent=2, ensure_ascii=False)
   f.write('\n')
" 2>/dev/null

   mv "$TEMP_COORD" "$COORD"

   [[ -n "$STEP" ]] && SUMMARY="$SUMMARY step=$STEP"
   [[ -n "$NEXT_TURN" ]] && SUMMARY="$SUMMARY nextTurn=$NEXT_TURN"
   [[ -n "$MSG_ROUND" ]] && SUMMARY="$SUMMARY messageRound=$MSG_ROUND"
fi

echo "SIGNALED: $SUMMARY"
