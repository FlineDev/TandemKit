#!/usr/bin/env bash
# TandemKit — unstick
#
# Diagnoses the Generator↔Evaluator signal loop when either side has stopped, and optionally re-fires the other
# side's live watcher by refreshing State.json's `updated` timestamp. Designed to be invoked the moment the user
# asks "why did you stop?" / "what are you waiting for?" / "why are both frozen?" — from either chat, without the
# agent needing to know in advance which side is at fault.
#
# Usage:
#   unstick.sh <mission-folder>            # diagnose only
#   unstick.sh <mission-folder> --touch    # refresh State.json's `updated` field to re-fire any live watcher
#
# The script itself takes no action beyond reading State.json and (optionally) touching its timestamp. The agent
# reading the output decides what to do next:
#
#   - If the agent IS the at-fault side, it resumes work immediately per its own SKILL.md. No --touch needed —
#     doing the work IS the fix.
#   - If the OTHER side is at fault, re-run with --touch so any still-alive watcher on that side picks up a fresh
#     file event and wakes. If nothing wakes within a minute, that side's background task has died with its
#     Claude Code session (usage limit / compaction / crash) and only the user can nudge the dead session.
#
# Exit 0 = diagnosis printed successfully. Exit 1 = bad args or missing State.json.

set -euo pipefail

if [[ $# -lt 1 ]]; then
   echo "Usage: unstick.sh <mission-folder> [--touch]" >&2
   exit 1
fi

MISSION="$1"
TOUCH=false
if [[ "${2:-}" == "--touch" ]]; then TOUCH=true; fi

STATE_FILE="$MISSION/State.json"

if [[ ! -f "$STATE_FILE" ]]; then
   echo "ERROR: State.json not found at $STATE_FILE" >&2
   exit 1
fi

read_field() {
   python3 -c "
import json
with open('$STATE_FILE') as f:
   print(json.load(f).get('$1', 'null'))
" 2>/dev/null || echo "null"
}

ROUND=$(read_field round)
PHASE=$(read_field phase)
G_STATUS=$(read_field generatorStatus)
E_STATUS=$(read_field evaluatorStatus)
VERDICT=$(read_field verdict)
UPDATED=$(read_field updated)

# Count live wait-for-state.sh watchers for this mission, grouped by which side they serve, per the canonical
# Signal Protocol in each side's SKILL.md:
#   - Evaluator-side watchers wait for `generatorStatus ready-for-eval` (next Generator round signal).
#   - Generator-side watchers wait for `evaluatorStatus done` (verdict) or `evaluatorStatus watching` (initial
#     Evaluator-ready signal on first mission start).
# Non-canonical watcher patterns (e.g. watching one's own field flip) are deliberately not counted — they mask
# real deadlocks by letting the script report a healthy watcher when the actual protocol-defined watcher is dead.
MISSION_WATCHERS=$(pgrep -fa wait-for-state.sh 2>/dev/null | grep -F "$MISSION" || true)
WATCHERS_EVAL_SIDE=$(echo "$MISSION_WATCHERS" | grep -c -E "generatorStatus ready-for-eval" 2>/dev/null || true)
WATCHERS_GEN_SIDE=$(echo "$MISSION_WATCHERS" | grep -c -E "evaluatorStatus (done|watching)" 2>/dev/null || true)
WATCHERS_COMPLETION=$(echo "$MISSION_WATCHERS" | grep -c "phase complete" 2>/dev/null || true)
WATCHERS_EVAL_SIDE=${WATCHERS_EVAL_SIDE:-0}
WATCHERS_GEN_SIDE=${WATCHERS_GEN_SIDE:-0}
WATCHERS_COMPLETION=${WATCHERS_COMPLETION:-0}

# Diagnose at-fault side from the state combination. "At fault" here means "the side that owes the next write" —
# not a value judgement. Healthy in-flight work (e.g. generatorStatus=working while Generator implements) shows as
# "generator" because the Generator is who will move next; the script cannot distinguish "actively working" from
# "stalled mid-work" without additional signal.
AT_FAULT="unknown"
ACTION=""
case "$G_STATUS/$E_STATUS" in
   "ready-for-eval/pending"|"ready-for-eval/watching")
      AT_FAULT="evaluator"
      ACTION="Evaluator should read Generator/Round-$ROUND.md and evaluate."
      ;;
   "ready-for-eval/evaluating")
      AT_FAULT="evaluator"
      ACTION="Evaluator claimed evaluating but no verdict landed. Resume evaluation or signal done with the atomic template."
      ;;
   "ready-for-eval/done")
      AT_FAULT="generator"
      ACTION="Generator should read Evaluator/Round-$ROUND.md (verdict: $VERDICT) and start the next round."
      ;;
   "working/"*)
      AT_FAULT="generator"
      ACTION="Generator is working (healthy if actively implementing; stalled if no progress for 15+ min). If stalled, resume implementation and signal ready-for-eval when done."
      ;;
   "researching/"*)
      AT_FAULT="generator"
      ACTION="Generator is in research mode. If the Evaluator is already watching, proceed to implementation."
      ;;
   *)
      ACTION="State combination ($G_STATUS/$E_STATUS) does not match a known waiting pattern — investigate manually."
      ;;
esac

# Flag the likely watcher-missing side separately from the at-fault side. The two can diverge: e.g. the Evaluator
# might be at-fault (their turn to act) AND their watcher is dead, which compounds the deadlock because their
# dead watcher means the next Generator signal will also be missed.
WATCHER_NOTE=""
if [[ "$AT_FAULT" == "evaluator" && "$WATCHERS_EVAL_SIDE" == "0" ]]; then
   WATCHER_NOTE="⚠ Evaluator has no live watcher — it will not wake when the Generator signals again."
elif [[ "$AT_FAULT" == "generator" && "$WATCHERS_GEN_SIDE" == "0" ]]; then
   WATCHER_NOTE="⚠ Generator has no live watcher — it will not wake when the Evaluator signals again."
fi

cat <<EOF
═══ TandemKit signal-loop diagnosis ═══
  mission:          $MISSION
  round:            $ROUND  (phase: $PHASE)
  generatorStatus:  $G_STATUS
  evaluatorStatus:  $E_STATUS
  verdict:          $VERDICT
  last updated:     $UPDATED

  evaluator-side watchers (generatorStatus ready-for-eval):          $WATCHERS_EVAL_SIDE
  generator-side watchers (evaluatorStatus done/watching):           $WATCHERS_GEN_SIDE
  completion watchers     (phase complete):                          $WATCHERS_COMPLETION

  at-fault side:    $AT_FAULT
  next action:      $ACTION
EOF

if [[ -n "$WATCHER_NOTE" ]]; then
   echo "  $WATCHER_NOTE"
fi

if [[ "$TOUCH" == true ]]; then
   python3 <<PYEOF
import json, datetime
with open('$STATE_FILE') as f:
   s = json.load(f)
s['updated'] = datetime.datetime.utcnow().isoformat() + 'Z'
with open('$STATE_FILE', 'w') as f:
   json.dump(s, f, indent=2)
   f.write('\n')
PYEOF
   echo
   echo "  ✓ State.json \`updated\` timestamp refreshed — any live watcher on the other side should pick up"
   echo "    the file event and wake. If nothing wakes within a minute, that side's background task is dead"
   echo "    (session reset / usage limit) — only the user can re-arm it by nudging that session directly."
fi
