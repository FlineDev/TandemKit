#!/bin/zsh
set -euo pipefail

# HarnessKit — wait-for-state
# Blocks until a State.json field matches an expected value (or any change occurs).
#
# Usage: wait-for-state.sh <mission-folder> [<field> <value1> [value2 ...]] [--quiet]
#   mission-folder:  absolute path to the HarnessKit/NNN-MissionName/ folder
#   field:           JSON field to check (e.g., evaluatorStatus, generatorStatus)
#   value1..N:       acceptable values — script exits when field matches any of them
#   --quiet:         suppress all output except final READY line (for Codex)
#
# If no field/values given: blocks until State.json content changes (any field).
#
# Exit 0 = condition met. Output includes current state summary.
# Exit 1 = error (missing files, bad args).

MISSION_DIR="$1"
shift

# Check for --quiet flag (can appear anywhere in remaining args)
QUIET=false
_ARGS=()
for _a in "$@"; do
   if [[ "$_a" == "--quiet" ]]; then
      QUIET=true
   else
      _ARGS+=("$_a")
   fi
done
set -- "${_ARGS[@]+"${_ARGS[@]}"}"

STATE_FILE="$MISSION_DIR/State.json"

if [[ ! -d "$MISSION_DIR" ]]; then
   echo "ERROR: Mission folder not found: $MISSION_DIR" >&2
   exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
   echo "ERROR: State.json not found: $STATE_FILE" >&2
   exit 1
fi

# Parse optional field and values
FIELD=""
VALUES=()
if [[ $# -ge 1 ]]; then
   FIELD="$1"
   shift
   VALUES=("$@")
fi

print_state() {
   python3 -c "
import json, sys
with open('$STATE_FILE') as f:
   s = json.load(f)
parts = []
for k in ['phase', 'generatorStatus', 'evaluatorStatus', 'round', 'verdict']:
   if k in s:
      parts.append(f'{k}={s[k]}')
print(' | '.join(parts))
" 2>/dev/null || echo "unknown"
}

read_field() {
   python3 -c "
import json
with open('$STATE_FILE') as f:
   print(json.load(f).get('$FIELD', 'null'))
" 2>/dev/null || echo "unknown"
}

file_hash() {
   md5 -q "$STATE_FILE" 2>/dev/null || md5sum "$STATE_FILE" 2>/dev/null | cut -d' ' -f1 || echo "none"
}

check_condition() {
   if [[ -z "$FIELD" ]]; then
      # No field specified — watching for any change
      # This mode always passes through to the watch loop on first call
      return 1
   fi

   local current
   current=$(read_field)

   if [[ ${#VALUES[@]} -eq 0 ]]; then
      # Field specified but no values — match anything non-null
      if [[ "$current" != "null" && "$current" != "unknown" ]]; then
         echo "READY: $FIELD=$current"
         print_state
         return 0
      fi
   else
      # Field + values — match any value
      for v in "${VALUES[@]}"; do
         if [[ "$current" == "$v" ]]; then
            echo "READY: $FIELD=$current"
            print_state
            return 0
         fi
      done
   fi

   return 1
}

# Check immediately — maybe the condition is already met
if check_condition; then
   exit 0
fi

# Record initial hash for "any change" mode
INITIAL_HASH=$(file_hash)

# Not ready — enter watch loop
if [[ "$QUIET" != true ]]; then
   if [[ -n "$FIELD" ]]; then
      echo "WAITING: $FIELD not yet ${VALUES[*]:-non-null}. Watching $STATE_FILE..."
   else
      echo "WAITING: Watching $STATE_FILE for any change..."
   fi
fi

while true; do
   # Try watchman-wait first (600s = 10 min timeout per chunk)
   if command -v watchman-wait &>/dev/null; then
      watchman-wait "$MISSION_DIR" -p "State.json" --max-events 1 -t 600 2>/dev/null || true
   else
      # Fallback: md5 polling every 5 seconds
      _prev=$(file_hash)
      while true; do
         sleep 5
         _curr=$(file_hash)
         if [[ "$_curr" != "$_prev" ]]; then
            break
         fi
      done
   fi

   # Re-check after wake
   if [[ -n "$FIELD" ]]; then
      # Field mode — check specific condition
      if check_condition; then
         exit 0
      fi
   else
      # Any-change mode — check if hash changed from initial
      now_hash=$(file_hash)
      if [[ "$now_hash" != "$INITIAL_HASH" ]]; then
         echo "READY: State.json changed"
         print_state
         exit 0
      fi
   fi

   # Suppress noise — only log once, only if not quiet
   if [[ "$QUIET" != true && -z "${_spurious_logged:-}" ]]; then
      echo "STILL WAITING: Woke up but condition not met yet. Continuing to watch..."
      _spurious_logged=1
   fi
done
